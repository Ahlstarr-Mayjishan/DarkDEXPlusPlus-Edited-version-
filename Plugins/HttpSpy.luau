local _main_ref, lib_ref, apps_ref, settings_ref, theme_ref

local plugin_data = {
	name         = "HttpSpy",
	FriendlyName = "HTTP Spy",
}

local function initDeps(data)
	_main_ref    = data.Main
	lib_ref      = data.Lib
	apps_ref     = data.Apps
	settings_ref = data.Settings
end

local function initAfterMain(t)
	theme_ref    = t.Theme
end

local function get_theme()
	return theme_ref or (apps_ref and apps_ref.Theme)
end

-- Fallback utilities for safety on different executors
local table_clear = table.clear or function(t)
	for k in pairs(t) do t[k] = nil end
end

local table_pack = table.pack or function(...)
	return { n = select("#", ...), ... }
end

local function is_binary(str)
	for i = 1, string.len(str) do
		local c = string.byte(str, i)
		if (c < 32 or c > 126) and c ~= 10 and c ~= 13 and c ~= 9 then
			return true
		end
	end
	return false
end

local function format_body(body)
	if not body or body == "" then return "Empty" end
	if is_binary(body) then
		return "[Binary Data: " .. #body .. " bytes]"
	end
	return body
end

local function format_headers(headers)
	if not headers or typeof(headers) ~= "table" then return "None" end
	local lines = {}
	for k, v in pairs(headers) do
		table.insert(lines, tostring(k) .. ": " .. tostring(v))
	end
	table.sort(lines)
	return table.concat(lines, "\n")
end

local function main()
	local spy = {}
	spy.PluginData = plugin_data

	local logs = {}
	local log_frames = {}
	local row_entry_map = {}
	local pending_rows = {}
	local selected_entry = nil
	local filter_text = ""
	local active = false
	local paused = false
	local log_limit = 200
	local visible_log_limit = 90
	local running_hooks = {}

	local hooked_functions = {}
	local namecall_hook = nil

	local colors = {
		GET     = Color3.fromRGB(34, 197, 94),
		POST    = Color3.fromRGB(59, 130, 246),
		PUT     = Color3.fromRGB(249, 115, 22),
		PATCH   = Color3.fromRGB(217, 119, 6),
		DELETE  = Color3.fromRGB(239, 68, 68),
		OTHER   = Color3.fromRGB(163, 163, 163),
		PENDING = Color3.fromRGB(234, 179, 8),
		ERROR   = Color3.fromRGB(239, 68, 68),
	}

	local window, list_frame, scroll_v, status_label, empty_label, inspector_scroll
	local rebuild_list

	local function matches(entry)
		if filter_text == "" then return true end
		local low = filter_text:lower()
		return entry.url:lower():find(low, 1, true)
			or entry.method:lower():find(low, 1, true)
			or entry.source:lower():find(low, 1, true)
			or (entry.request_body and entry.request_body:lower():find(low, 1, true))
			or (entry.response_body and entry.response_body:lower():find(low, 1, true))
	end

	local function update_scroll()
		if scroll_v then
			scroll_v.TotalSpace = #log_frames
			scroll_v.Index = math.max(0, #log_frames - scroll_v.VisibleSpace)
			scroll_v:Update()
		end
	end

	local function trim_visible_rows()
		while #log_frames > visible_log_limit do
			local old = table.remove(log_frames, 1)
			if old then
				row_entry_map[old] = nil
				old:Destroy()
			end
		end
		for i, row in ipairs(log_frames) do
			row.LayoutOrder = i
		end
	end

	local function rebuild_list_highlights()
		for _, row in ipairs(log_frames) do
			local entry = row_entry_map[row]
			if entry == selected_entry then
				row.BackgroundColor3 = settings_ref.Theme.ListSelection
			else
				row.BackgroundColor3 = settings_ref.Theme.Main1
			end
		end
	end

	local function update_status_label()
		if status_label then
			status_label.Text = #logs .. " requests logged"
		end
	end

	local function create_detail_block(title, text, layout_order)
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.new(1, 0, 0, 0)
		frame.AutomaticSize = Enum.AutomaticSize.Y
		frame.LayoutOrder = layout_order
		frame.Parent = inspector_scroll

		local lbl = Instance.new("TextLabel", frame)
		lbl.BackgroundTransparency = 1
		lbl.Size = UDim2.new(1, -60, 0, 20)
		lbl.Font = Enum.Font.SourceSansBold
		lbl.TextSize = 13
		lbl.TextColor3 = settings_ref.Theme.PlaceholderText
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Text = title

		local copy_btn = Instance.new("TextButton", frame)
		copy_btn.Size = UDim2.new(0, 50, 0, 18)
		copy_btn.Position = UDim2.new(1, -52, 0, 1)
		copy_btn.Text = "Copy"
		copy_btn.Font = Enum.Font.SourceSans
		copy_btn.TextSize = 12
		copy_btn.AutoButtonColor = false
		if get_theme() then
			get_theme().StyleButton(copy_btn)
		else
			copy_btn.BackgroundColor3 = settings_ref.Theme.Button
			copy_btn.TextColor3 = settings_ref.Theme.Text
			local c = Instance.new("UICorner", copy_btn)
			c.CornerRadius = UDim.new(0, 3)
		end

		local box = Instance.new("TextBox", frame)
		box.BackgroundColor3 = settings_ref.Theme.Main1
		box.BorderSizePixel = 0
		box.Position = UDim2.new(0, 0, 0, 22)
		box.Size = UDim2.new(1, 0, 0, 0)
		box.AutomaticSize = Enum.AutomaticSize.Y
		box.Font = Enum.Font.Code
		box.TextSize = 11
		box.TextColor3 = settings_ref.Theme.Text
		box.TextEditable = false
		box.ClearTextOnFocus = false
		box.MultiLine = true
		box.TextWrapped = true
		box.Text = text
		box.TextXAlignment = Enum.TextXAlignment.Left
		box.TextYAlignment = Enum.TextYAlignment.Top

		local pad = Instance.new("UIPadding", box)
		pad.PaddingLeft = UDim.new(0, 6)
		pad.PaddingRight = UDim.new(0, 6)
		pad.PaddingTop = UDim.new(0, 6)
		pad.PaddingBottom = UDim.new(0, 6)

		if get_theme() then
			get_theme().ApplyRounding(box, 4)
		end

		copy_btn.MouseButton1Click:Connect(function()
			if setclipboard then
				setclipboard(text)
				copy_btn.Text = "Copied!"
				task.delay(1, function()
					copy_btn.Text = "Copy"
				end)
			end
		end)
	end

	local function show_details(entry)
		selected_entry = entry

		-- Clear old children
		for _, child in ipairs(inspector_scroll:GetChildren()) do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end

		if not entry then
			local placeholder = Instance.new("TextLabel", inspector_scroll)
			placeholder.BackgroundTransparency = 1
			placeholder.Size = UDim2.new(1, 0, 0, 48)
			placeholder.Font = get_theme() and get_theme().MapFont(Enum.Font.SourceSans) or Enum.Font.SourceSans
			placeholder.TextSize = 14
			placeholder.TextColor3 = settings_ref.Theme.PlaceholderText
			placeholder.Text = "Select a request to view details"
			return
		end

		local order = 1

		-- URL
		create_detail_block("URL", entry.url, order)
		order += 1

		-- General Info
		local metadata_lines = {
			"Method: " .. tostring(entry.method),
			"Source: " .. tostring(entry.source),
			"Status: " .. tostring(entry.response_status),
			"Time: " .. tostring(entry.time)
		}
		create_detail_block("General Info", table.concat(metadata_lines, "\n"), order)
		order += 1

		-- Request Headers
		if entry.request_headers then
			create_detail_block("Request Headers", format_headers(entry.request_headers), order)
			order += 1
		end

		-- Request Body
		if entry.request_body and entry.request_body ~= "" then
			create_detail_block("Request Body", format_body(entry.request_body), order)
			order += 1
		end

		-- Response Headers
		if entry.response_headers then
			create_detail_block("Response Headers", format_headers(entry.response_headers), order)
			order += 1
		end

		-- Response Body
		if entry.completed then
			create_detail_block("Response Body", format_body(entry.response_body), order)
			order += 1
		else
			create_detail_block("Response Body", "Request pending...", order)
			order += 1
		end
	end

	local function push_row(entry)
		if not list_frame then return end
		if empty_label then empty_label.Visible = false end

		local col = colors[entry.method] or colors.OTHER

		local row = Instance.new("Frame")
		row.BackgroundColor3 = settings_ref.Theme.Main1
		row.BorderSizePixel  = 0
		row.Size             = UDim2.new(1, 0, 0, 36)
		row.ClipsDescendants = true

		local badge = Instance.new("Frame", row)
		badge.BackgroundColor3 = col
		badge.BorderSizePixel  = 0
		badge.Size             = UDim2.new(0, 3, 1, 0)

		local time_lbl = Instance.new("TextLabel", row)
		time_lbl.BackgroundTransparency = 1
		time_lbl.Position  = UDim2.new(0, 8, 0, 0)
		time_lbl.Size      = UDim2.new(0, 55, 0, 18)
		time_lbl.Font      = Enum.Font.Code
		time_lbl.TextSize  = 11
		time_lbl.TextColor3 = settings_ref.Theme.PlaceholderText
		time_lbl.TextXAlignment = Enum.TextXAlignment.Left
		time_lbl.Text = entry.time

		local method_lbl = Instance.new("TextLabel", row)
		method_lbl.BackgroundTransparency = 1
		method_lbl.Position  = UDim2.new(0, 66, 0, 0)
		method_lbl.Size      = UDim2.new(1, -72, 0, 18)
		method_lbl.Font      = get_theme() and get_theme().MapFont(Enum.Font.SourceSansBold) or Enum.Font.SourceSansBold
		method_lbl.TextSize  = 13
		method_lbl.TextColor3 = col
		method_lbl.TextXAlignment = Enum.TextXAlignment.Left

		local function update_status_text()
			local status_str = tostring(entry.response_status)
			method_lbl.Text = entry.method .. "  |  Status: " .. status_str .. "  [" .. entry.source .. "]"
			if status_str == "Pending" then
				method_lbl.TextColor3 = colors.PENDING
			elseif status_str == "Error" or (tonumber(status_str) and tonumber(status_str) >= 400) then
				method_lbl.TextColor3 = colors.ERROR
			else
				method_lbl.TextColor3 = col
			end
		end
		update_status_text()
		entry.update_ui = update_status_text

		local url_lbl = Instance.new("TextLabel", row)
		url_lbl.BackgroundTransparency = 1
		url_lbl.Position  = UDim2.new(0, 8, 0, 18)
		url_lbl.Size      = UDim2.new(1, -16, 0, 18)
		url_lbl.Font      = Enum.Font.Code
		url_lbl.TextSize  = 11
		url_lbl.TextColor3 = settings_ref.Theme.PlaceholderText
		url_lbl.TextXAlignment = Enum.TextXAlignment.Left
		url_lbl.TextTruncate = Enum.TextTruncate.AtEnd
		url_lbl.Text = entry.url

		local separator = Instance.new("Frame", row)
		separator.BackgroundColor3 = settings_ref.Theme.Outline1
		separator.BorderSizePixel = 0
		separator.Size = UDim2.new(1, 0, 0, 1)
		separator.Position = UDim2.new(0, 0, 1, -1)

		row.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseMovement then
				row.BackgroundColor3 = selected_entry == entry and settings_ref.Theme.ListSelection or settings_ref.Theme.ButtonHover
			elseif i.UserInputType == Enum.UserInputType.MouseButton1 then
				selected_entry = entry
				show_details(entry)
				rebuild_list_highlights()
			elseif i.UserInputType == Enum.UserInputType.MouseButton2 and setclipboard then
				setclipboard(entry.url)
			end
		end)

		row.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseMovement then
				row.BackgroundColor3 = selected_entry == entry and settings_ref.Theme.ListSelection or settings_ref.Theme.Main1
			end
		end)

		row.LayoutOrder = #log_frames + 1
		row.Parent = list_frame
		table.insert(log_frames, row)
		row_entry_map[row] = entry
	end

	rebuild_list = function()
		for _, f in ipairs(log_frames) do f:Destroy() end
		log_frames = {}
		table_clear(row_entry_map)
		table_clear(pending_rows)

		local visible_count = 0
		local matched = {}
		for i = #logs, 1, -1 do
			local e = logs[i]
			if matches(e) then
				table.insert(matched, 1, e)
				if #matched >= visible_log_limit then break end
			end
		end

		for _, e in ipairs(matched) do
			visible_count += 1
			push_row(e)
		end

		trim_visible_rows()

		if empty_label then
			empty_label.Visible = visible_count == 0
			if filter_text ~= "" then
				empty_label.Text = "No requests match filter"
			else
				empty_label.Text = "Start spy to capture HTTP traffic"
			end
		end

		if scroll_v then
			scroll_v.TotalSpace = #log_frames
			scroll_v.Index = math.max(0, #log_frames - scroll_v.VisibleSpace)
			scroll_v:Update()
		end

		rebuild_list_highlights()
	end

	local function log_request(source, method, url, headers, body)
		local entry = {
			time = os.date("%H:%M:%S"),
			source = source,
			method = method:upper(),
			url = url,
			request_headers = headers,
			request_body = body,
			completed = false,
			response_status = "Pending",
			response_headers = nil,
			response_body = nil,
		}

		table.insert(logs, entry)
		if #logs > log_limit then
			table.remove(logs, 1)
		end

		if window and not window.Closed and matches(entry) then
			pending_rows[#pending_rows + 1] = entry
			if #pending_rows > visible_log_limit then table.remove(pending_rows, 1) end

			task.spawn(function()
				push_row(entry)
				trim_visible_rows()
				update_scroll()
			end)
		end

		update_status_label()
		return entry
	end

	local function log_response(entry, status, headers, body)
		entry.completed = true
		entry.response_status = status or 200
		entry.response_headers = headers
		entry.response_body = body

		if selected_entry == entry then
			task.spawn(show_details, entry)
		end

		if entry.update_ui then
			task.spawn(entry.update_ui)
		end
	end

	-- Hooking Functions
	local function hook_request_func(req_name, req_func)
		if typeof(req_func) ~= "function" then return end
		if hooked_functions[req_name] then return end
		if not hookfunction then return end

		local orig
		orig = hookfunction(req_func, function(options)
			if not active or paused then
				return orig(options)
			end
			if checkcaller and checkcaller() then
				return orig(options)
			end

			local thread = coroutine.running()
			if running_hooks[thread] then
				return orig(options)
			end

			running_hooks[thread] = true

			local method = options.Method or "GET"
			local url = options.Url or ""
			local headers = options.Headers
			local body = options.Body

			local entry = log_request(req_name, method, url, headers, body)

			local success, response = pcall(orig, options)

			running_hooks[thread] = nil

			if not success then
				log_response(entry, "Error", nil, tostring(response))
				error(response)
			end

			if response and typeof(response) == "table" then
				log_response(entry, response.StatusCode, response.Headers, response.Body)
			else
				log_response(entry, "Unknown", nil, tostring(response))
			end

			return response
		end)

		hooked_functions[req_name] = orig
	end

	local function hook_roblox_method(method_name, method_func, method_type)
		if typeof(method_func) ~= "function" then return end
		if hooked_functions[method_name] then return end
		if not hookfunction then return end

		local orig
		orig = hookfunction(method_func, function(self, url, arg3, arg4)
			if not active or paused then
				return orig(self, url, arg3, arg4)
			end
			if typeof(self) ~= "Instance" or self ~= game then
				return orig(self, url, arg3, arg4)
			end
			if checkcaller and checkcaller() then
				return orig(self, url, arg3, arg4)
			end

			local thread = coroutine.running()
			if running_hooks[thread] then
				return orig(self, url, arg3, arg4)
			end

			running_hooks[thread] = true

			local method = (method_type == "POST") and "POST" or "GET"
			local body = (method_type == "POST") and arg3 or nil
			local headers = (method_type == "POST" and arg4) and { ["Content-Type"] = arg4 } or nil

			local entry = log_request(method_name, method, url, headers, body)

			local success, response = pcall(orig, self, url, arg3, arg4)

			running_hooks[thread] = nil

			if not success then
				log_response(entry, "Error", nil, tostring(response))
				error(response)
			end

			log_response(entry, 200, nil, response)
			return response
		end)

		hooked_functions[method_name] = orig
	end

	local function start_namecall_hook()
		if not hookmetamethod or namecall_hook then return end

		local ok, orig = pcall(hookmetamethod, game, "__namecall", function(self, ...)
			if not active or paused then
				return namecall_hook(self, ...)
			end
			if typeof(self) ~= "Instance" or self ~= game then
				return namecall_hook(self, ...)
			end
			if checkcaller and checkcaller() then
				return namecall_hook(self, ...)
			end

			local method = getnamecallmethod and getnamecallmethod() or ""
			if method == "HttpGet" or method == "HttpGetAsync" or method == "HttpPost" or method == "HttpPostAsync" then
				local thread = coroutine.running()
				if running_hooks[thread] then
					return namecall_hook(self, ...)
				end

				running_hooks[thread] = true

				local url = ...
				local is_post = method:find("HttpPost")
				local req_method = is_post and "POST" or "GET"
				local body = is_post and select(2, ...) or nil
				local content_type = is_post and select(3, ...) or nil
				local headers = content_type and { ["Content-Type"] = content_type } or nil

				local entry = log_request(method, req_method, url, headers, body)

				local results = table_pack(pcall(namecall_hook, self, ...))

				running_hooks[thread] = nil

				if not results[1] then
					log_response(entry, "Error", nil, tostring(results[2]))
					error(results[2])
				end

				log_response(entry, 200, nil, results[2])
				return table.unpack(results, 2, results.n)
			end

			return namecall_hook(self, ...)
		end)

		if ok then
			namecall_hook = orig
		end
	end

	local function start()
		if active then return end
		active = true

		-- Hook request variant closures
		hook_request_func("request", request or (getgenv and getgenv().request))
		hook_request_func("http_request", http_request or (getgenv and getgenv().http_request))
		if syn and syn.request then
			hook_request_func("syn.request", syn.request)
		end
		if http and http.request then
			hook_request_func("http.request", http.request)
		end

		-- Hook Roblox HTTP methods
		hook_roblox_method("HttpGet", game.HttpGet, "GET")
		hook_roblox_method("HttpGetAsync", game.HttpGetAsync, "GET")
		hook_roblox_method("HttpPost", game.HttpPost, "POST")
		hook_roblox_method("HttpPostAsync", game.HttpPostAsync, "POST")

		-- Metatable fallback hook
		start_namecall_hook()

		rebuild_list()
	end

	local function stop()
		if not active then return end
		active = false
		rebuild_list()
	end

	local function make_btn(parent, text, x, w)
		local btn = Instance.new("TextButton")
		btn.BorderSizePixel  = 0
		btn.Font             = Enum.Font.SourceSans
		btn.TextSize         = 13
		btn.Text             = text
		btn.AutoButtonColor  = false
		btn.Size             = UDim2.new(0, w, 0, 18)
		btn.Position         = UDim2.new(0, x, 0, 2)
		btn.Parent           = parent
		if get_theme() then
			get_theme().StyleButton(btn)
		else
			btn.BackgroundColor3 = Color3.fromRGB(43, 49, 58)
			btn.TextColor3       = Color3.fromRGB(238, 242, 247)
			local c = Instance.new("UICorner", btn)
			c.CornerRadius = UDim.new(0, 3)
			btn.MouseEnter:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(55, 63, 75) end)
			btn.MouseLeave:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(43, 49, 58) end)
		end
		return btn
	end

	spy.Init = function()
		window = lib_ref.Window.new()
		window:SetTitle("HTTP Spy")
		window:Resize(760, 460)
		spy.Window = window

		local toolbar = Instance.new("Frame")
		toolbar.BackgroundColor3 = settings_ref.Theme.Menu
		toolbar.BorderSizePixel  = 0
		toolbar.Size             = UDim2.new(1, 0, 0, 26)
		toolbar.Parent           = window.GuiElems.Content

		local start_btn = make_btn(toolbar, "Start",  4,  58)
		local stop_btn  = make_btn(toolbar, "Stop",   66, 50)
		local clear_btn = make_btn(toolbar, "Clear",  122, 48)
		local pause_btn = make_btn(toolbar, "Pause",  174, 50)
		local copy_btn  = make_btn(toolbar, "Copy All", 228, 58)

		status_label = Instance.new("TextLabel")
		status_label.BackgroundTransparency = 1
		status_label.Font       = get_theme() and get_theme().MapFont(Enum.Font.SourceSans) or Enum.Font.SourceSans
		status_label.TextSize   = 12
		status_label.TextColor3 = settings_ref.Theme.PlaceholderText
		status_label.TextXAlignment = Enum.TextXAlignment.Right
		status_label.Size       = UDim2.new(1, -300, 1, 0)
		status_label.Position   = UDim2.new(0, 292, 0, 0)
		status_label.Text       = "0 requests logged"
		status_label.Parent     = toolbar

		local search_bar = Instance.new("Frame")
		search_bar.BackgroundColor3 = settings_ref.Theme.Main1
		search_bar.BorderSizePixel  = 0
		search_bar.Size             = UDim2.new(1, 0, 0, 26)
		search_bar.Position         = UDim2.new(0, 0, 0, 26)
		search_bar.Parent           = window.GuiElems.Content

		local search_box = Instance.new("TextBox", search_bar)
		search_box.BackgroundTransparency = 1
		search_box.PlaceholderText  = "Filter path, method, or payload..."
		search_box.PlaceholderColor3 = settings_ref.Theme.PlaceholderText
		search_box.Text             = ""
		search_box.Font             = Enum.Font.Code
		search_box.TextSize         = 13
		search_box.TextColor3       = settings_ref.Theme.Text
		search_box.TextXAlignment   = Enum.TextXAlignment.Left
		search_box.ClearTextOnFocus = false
		search_box.Size             = UDim2.new(1, -14, 1, 0)
		search_box.Position         = UDim2.new(0, 8, 0, 0)
		search_box:GetPropertyChangedSignal("Text"):Connect(function()
			filter_text = search_box.Text
			rebuild_list()
		end)

		local body = Instance.new("Frame")
		body.BackgroundColor3 = settings_ref.Theme.Main2
		body.BorderSizePixel = 0
		body.Position = UDim2.new(0, 0, 0, 52)
		body.Size = UDim2.new(1, 0, 1, -52)
		body.Parent = window.GuiElems.Content

		local left_panel = Instance.new("Frame")
		left_panel.BackgroundColor3 = settings_ref.Theme.Main1
		left_panel.BorderSizePixel = 0
		left_panel.Size = UDim2.new(0, 320, 1, 0)
		left_panel.Parent = body

		local list_container = Instance.new("Frame")
		list_container.BackgroundColor3 = settings_ref.Theme.Main2
		list_container.BorderSizePixel  = 0
		list_container.Size             = UDim2.new(1, -16, 1, 0)
		list_container.ClipsDescendants = true
		list_container.Parent           = left_panel

		list_frame = Instance.new("Frame")
		list_frame.BackgroundTransparency = 1
		list_frame.Size         = UDim2.new(1, 0, 0, 0)
		list_frame.AutomaticSize = Enum.AutomaticSize.Y
		list_frame.Parent       = list_container

		local layout = Instance.new("UIListLayout", list_frame)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding   = UDim.new(0, 1)

		empty_label = Instance.new("TextLabel", list_container)
		empty_label.BackgroundTransparency = 1
		empty_label.Size = UDim2.new(1, 0, 0, 48)
		empty_label.Position = UDim2.new(0, 0, 0.5, -24)
		empty_label.Font = get_theme() and get_theme().MapFont(Enum.Font.SourceSans) or Enum.Font.SourceSans
		empty_label.TextSize = 14
		empty_label.TextColor3 = settings_ref.Theme.PlaceholderText
		empty_label.Text = "Start spy to capture HTTP traffic"
		empty_label.Visible = true

		scroll_v = lib_ref.ScrollBar.new()
		scroll_v.WheelIncrement  = 3
		scroll_v.Gui.Position    = UDim2.new(1, -16, 0, 0)
		scroll_v.Gui.Size        = UDim2.new(0, 16, 1, 0)
		scroll_v.Gui.Parent      = left_panel
		scroll_v:SetScrollFrame(list_container)
		scroll_v.Scrolled:Connect(function()
			list_frame.Position = UDim2.new(0, 0, 0, -scroll_v.Index * 37)
		end)

		local split_line = Instance.new("Frame", body)
		split_line.BackgroundColor3 = settings_ref.Theme.Outline1
		split_line.BorderSizePixel = 0
		split_line.Position = UDim2.new(0, 320, 0, 0)
		split_line.Size = UDim2.new(0, 1, 1, 0)

		local right_panel = Instance.new("Frame")
		right_panel.BackgroundColor3 = settings_ref.Theme.Main2
		right_panel.BorderSizePixel = 0
		right_panel.Position = UDim2.new(0, 321, 0, 0)
		right_panel.Size = UDim2.new(1, -321, 1, 0)
		right_panel.Parent = body

		inspector_scroll = Instance.new("ScrollingFrame")
		inspector_scroll.Active = true
		inspector_scroll.BackgroundTransparency = 1
		inspector_scroll.BorderSizePixel = 0
		inspector_scroll.Size = UDim2.new(1, -10, 1, -10)
		inspector_scroll.Position = UDim2.new(0, 5, 0, 5)
		inspector_scroll.ScrollBarImageColor3 = settings_ref.Theme.Highlight
		inspector_scroll.ScrollBarThickness = 4
		inspector_scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		inspector_scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		inspector_scroll.Parent = right_panel

		local inspector_layout = Instance.new("UIListLayout", inspector_scroll)
		inspector_layout.SortOrder = Enum.SortOrder.LayoutOrder
		inspector_layout.Padding = UDim.new(0, 10)

		local function update_button_states()
			if not start_btn then return end
			local theme = settings_ref.Theme

			if active then
				start_btn.Text = paused and "Paused" or "Active"
				start_btn.BackgroundColor3 = paused and Color3.fromRGB(234, 179, 8) or theme.ListSelection
				stop_btn.Text = "Stop"
				stop_btn.BackgroundColor3 = theme.Button
			else
				start_btn.Text = "Start"
				start_btn.BackgroundColor3 = theme.Button
				stop_btn.Text = "Stopped"
				stop_btn.BackgroundColor3 = Color3.fromRGB(244, 63, 94)
			end

			pause_btn.Text = paused and "Resume" or "Pause"
			pause_btn.BackgroundColor3 = paused and Color3.fromRGB(234, 179, 8) or theme.Button
		end

		start_btn.MouseButton1Click:Connect(function()
			if not active then
				start()
				paused = false
				update_button_states()
			end
		end)

		stop_btn.MouseButton1Click:Connect(function()
			if active then
				stop()
				paused = false
				update_button_states()
			end
		end)

		clear_btn.MouseButton1Click:Connect(function()
			logs = {}
			for _, f in ipairs(log_frames) do f:Destroy() end
			log_frames = {}
			table_clear(row_entry_map)
			table_clear(pending_rows)
			selected_entry = nil
			update_status_label()
			rebuild_list()
			show_details(nil)
		end)

		pause_btn.MouseButton1Click:Connect(function()
			if active then
				paused = not paused
				update_button_states()
			end
		end)

		copy_btn.MouseButton1Click:Connect(function()
			if not setclipboard then return end
			local lines = {}
			for _, e in ipairs(logs) do
				lines[#lines + 1] = string.format("[%s] %s | %s %s | Status: %s",
					e.time, e.source, e.method, e.url, tostring(e.response_status))
			end
			setclipboard(table.concat(lines, "\n"))
		end)

		update_button_states()
		rebuild_list()
		show_details(nil)

		window.OnActivate:Connect(function()
			if scroll_v then
				scroll_v.TotalSpace   = #log_frames
				scroll_v.VisibleSpace = math.floor(list_container.AbsoluteSize.Y / 37)
				scroll_v:Update()
			end
		end)
	end

	spy.Uninit = function()
		stop()
	end
	return spy
end

return {
	InitDeps      = initDeps,
	InitAfterMain = initAfterMain,
	Main          = main,
	CleanUp       = function() pcall(stop) end,
	PluginData    = plugin_data,
}
