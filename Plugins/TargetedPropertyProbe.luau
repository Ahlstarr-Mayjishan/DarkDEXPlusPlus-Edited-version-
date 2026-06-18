--!nocheck

local main_ref, lib_ref, apps_ref, settings_ref, env_ref, theme_ref

local plugin_data = {
	Name = "TargetedPropertyProbe",
	FriendlyName = "Targeted Property Probe",
}

local function initDeps(data)
	main_ref = data.Main
	lib_ref = data.Lib
	apps_ref = data.Apps
	settings_ref = data.Settings
	env_ref = data.env
end

local function initAfterMain(t)
	theme_ref = t.Theme
end

local function env_func(name)
	local env = env_ref
	if env and type(env[name]) == "function" then
		return env[name]
	end
	if type(getfenv) == "function" then
		local ok, value = pcall(function()
			return getfenv()[name]
		end)
		if ok and type(value) == "function" then
			return value
		end
	end
	return nil
end

local function protect_closure(fn)
	local newcclosure_fn = env_func("newcclosure")
	if newcclosure_fn then
		local ok, wrapped = pcall(newcclosure_fn, fn)
		if ok and wrapped then
			return wrapped
		end
	end
	return fn
end

local function inst_path(obj)
	if typeof(obj) ~= "Instance" then return tostring(obj) end
	if main_ref and main_ref.SafeGetInstancePath then
		local ok, path = pcall(main_ref.SafeGetInstancePath, obj)
		if ok and path then return tostring(path) end
	end
	local ok, full = pcall(function()
		return obj:GetFullName()
	end)
	return ok and ("game." .. tostring(full)) or tostring(obj)
end

local function main()
	local probe = {}
	probe.PluginData = plugin_data

	local window, status_label, target_label, key_box, duration_box, cap_box, list_frame
	local active = false
	local capture_reads = false
	local capture_writes = false
	local read_installed = false
	local write_installed = false
	local original_index
	local original_newindex
	local stop_at = 0
	local event_cap = 200
	local event_count = 0
	local flush_scheduled = false
	local rows = {}
	local target_set = setmetatable({}, {__mode = "k"})
	local target_names = setmetatable({}, {__mode = "k"})
	local key_set = {}
	local aggregates = {}

	local function set_status(text)
		if status_label then
			status_label.Text = tostring(text)
		end
	end

	local function parse_keys(text)
		local out = {}
		for token in tostring(text or ""):gmatch("[^,%s]+") do
			out[token] = true
		end
		return out
	end

	local function checkcaller_safe()
		local checkcaller_fn = env_func("checkcaller")
		if not checkcaller_fn then return false end
		local ok, result = pcall(checkcaller_fn)
		return ok and result == true
	end

	local function clear_rows()
		for _, row in ipairs(rows) do
			row:Destroy()
		end
		rows = {}
	end

	local function render()
		if not list_frame then return end
		clear_rows()
		local ordered = {}
		for _, entry in pairs(aggregates) do
			ordered[#ordered + 1] = entry
		end
		table.sort(ordered, function(a, b)
			if a.Count == b.Count then return a.Last > b.Last end
			return a.Count > b.Count
		end)

		for i, entry in ipairs(ordered) do
			if i > 80 then break end
			local row = Instance.new("Frame")
			row.BackgroundColor3 = settings_ref.Theme.Main1
			row.BorderColor3 = settings_ref.Theme.Outline1
			row.Size = UDim2.new(1, -8, 0, 44)
			row.Parent = list_frame

			local title = Instance.new("TextLabel", row)
			title.BackgroundTransparency = 1
			title.Font = Enum.Font.SourceSansBold
			title.Position = UDim2.new(0, 8, 0, 2)
			title.Size = UDim2.new(1, -16, 0, 18)
			title.Text = entry.Kind .. " ." .. entry.Key .. "  x" .. tostring(entry.Count)
			title.TextColor3 = entry.Kind == "read" and Color3.fromRGB(96, 165, 250) or Color3.fromRGB(249, 115, 22)
			title.TextSize = 13
			title.TextXAlignment = Enum.TextXAlignment.Left

			local detail = Instance.new("TextLabel", row)
			detail.BackgroundTransparency = 1
			detail.Font = Enum.Font.Code
			detail.Position = UDim2.new(0, 8, 0, 21)
			detail.Size = UDim2.new(1, -16, 0, 18)
			detail.Text = entry.Path
			detail.TextColor3 = settings_ref.Theme.PlaceholderText
			detail.TextSize = 11
			detail.TextTruncate = Enum.TextTruncate.AtEnd
			detail.TextXAlignment = Enum.TextXAlignment.Left

			rows[#rows + 1] = row
		end
		list_frame.CanvasSize = UDim2.new(0, 0, 0, math.max(44, math.min(#ordered, 80) * 46))
	end

	local function schedule_flush()
		if flush_scheduled then return end
		flush_scheduled = true
		task.delay(0.25, function()
			flush_scheduled = false
			render()
			if active then
				set_status(("Active: %d/%d events, %.1fs left"):format(event_count, event_cap, math.max(0, stop_at - os.clock())))
			end
		end)
	end

	local function note(kind, inst, key)
		if not active then return end
		if event_count >= event_cap or os.clock() >= stop_at then
			active = false
			return
		end
		if checkcaller_safe() then return end
		if typeof(inst) ~= "Instance" or not target_set[inst] then return end
		key = tostring(key)
		if not key_set[key] then return end

		event_count += 1
		local path = target_names[inst] or inst_path(inst)
		local id = kind .. "\n" .. path .. "\n" .. key
		local entry = aggregates[id]
		if not entry then
			entry = {Kind = kind, Path = path, Key = key, Count = 0, Last = 0}
			aggregates[id] = entry
		end
		entry.Count += 1
		entry.Last = os.clock()
		schedule_flush()
	end

	local function install_read_hook()
		if read_installed then return true end
		local hookmetamethod_fn = env_func("hookmetamethod")
		if not hookmetamethod_fn then
			set_status("hookmetamethod unavailable.")
			return false
		end
		local ok, original = pcall(hookmetamethod_fn, game, "__index", protect_closure(function(self, key)
			if active and capture_reads then
				note("read", self, key)
			end
			return original_index(self, key)
		end))
		if ok and original then
			original_index = original
			read_installed = true
			return true
		end
		set_status("Failed to install read probe: " .. tostring(original))
		return false
	end

	local function install_write_hook()
		if write_installed then return true end
		local hookmetamethod_fn = env_func("hookmetamethod")
		if not hookmetamethod_fn then
			set_status("hookmetamethod unavailable.")
			return false
		end
		local ok, original = pcall(hookmetamethod_fn, game, "__newindex", protect_closure(function(self, key, value)
			if active and capture_writes then
				note("write", self, key)
			end
			return original_newindex(self, key, value)
		end))
		if ok and original then
			original_newindex = original
			write_installed = true
			return true
		end
		set_status("Failed to install write probe: " .. tostring(original))
		return false
	end

	local function load_selected_targets()
		table.clear(target_set)
		table.clear(target_names)
		local explorer = apps_ref and apps_ref.Explorer
		local count = 0
		if explorer and explorer.Selection and explorer.Selection.List then
			for _, node in ipairs(explorer.Selection.List) do
				local obj = node.Obj
				if typeof(obj) == "Instance" then
					target_set[obj] = true
					target_names[obj] = inst_path(obj)
					count += 1
				end
			end
		end
		if target_label then
			target_label.Text = count > 0 and (tostring(count) .. " selected target(s)") or "No Explorer selection"
		end
		return count
	end

	local function start_probe(reads, writes)
		if load_selected_targets() <= 0 then
			set_status("Select one or more instances in Explorer first.")
			return
		end
		key_set = parse_keys(key_box and key_box.Text or "")
		if not next(key_set) then
			set_status("Enter at least one property key.")
			return
		end

		local duration = tonumber(duration_box and duration_box.Text) or 5
		duration = math.clamp(duration, 1, 15)
		event_cap = math.clamp(tonumber(cap_box and cap_box.Text) or 200, 25, 1000)
		capture_reads = reads == true
		capture_writes = writes == true

		if capture_reads and not install_read_hook() then return end
		if capture_writes and not install_write_hook() then return end

		table.clear(aggregates)
		clear_rows()
		event_count = 0
		stop_at = os.clock() + duration
		active = true
		set_status(("Active for %.0fs. Capturing %s%s."):format(duration, capture_reads and "reads" or "", capture_writes and " writes" or ""))

		task.delay(duration, function()
			if os.clock() >= stop_at then
				active = false
				set_status(("Stopped: %d/%d events."):format(event_count, event_cap))
				render()
			end
		end)
	end

	local function button(parent, text, pos, size, cb)
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.BackgroundColor3 = settings_ref.Theme.Button
		b.BorderColor3 = settings_ref.Theme.Outline2
		b.Font = Enum.Font.SourceSans
		b.Position = pos
		b.Size = size
		b.Text = text
		b.TextColor3 = settings_ref.Theme.Text
		b.TextSize = 14
		b.Parent = parent
		b.MouseButton1Click:Connect(cb)
		if theme_ref and theme_ref.StyleButton then
			theme_ref.StyleButton(b)
		elseif lib_ref and lib_ref.ButtonAnim then
			lib_ref.ButtonAnim(b, {
				Mode = 2,
				StartColor = settings_ref.Theme.Button,
				HoverColor = settings_ref.Theme.ButtonHover,
				PressColor = settings_ref.Theme.ButtonPress,
				OutlineColor = settings_ref.Theme.Outline2,
			})
		end
		return b
	end

	function probe.Init()
		window = lib_ref.Window.new()
		window:SetTitle("Targeted Property Probe")
		window:Resize(620, 420)
		probe.Window = window

		local content = window.GuiElems.Content
		local theme = settings_ref.Theme

		local toolbar = Instance.new("Frame")
		toolbar.BackgroundColor3 = theme.Main2
		toolbar.BorderSizePixel = 0
		toolbar.Size = UDim2.new(1, 0, 0, 92)
		toolbar.Parent = content

		key_box = Instance.new("TextBox")
		key_box.BackgroundColor3 = theme.TextBox
		key_box.BorderColor3 = theme.Outline3
		key_box.ClearTextOnFocus = false
		key_box.Font = Enum.Font.Code
		key_box.PlaceholderColor3 = theme.PlaceholderText
		key_box.PlaceholderText = "keys: Parent Name CFrame Value Text Enabled Visible"
		key_box.Position = UDim2.new(0, 8, 0, 8)
		key_box.Size = UDim2.new(1, -16, 0, 24)
		key_box.Text = "Parent Name CFrame Position Size Value Text Enabled Visible"
		key_box.TextColor3 = theme.Text
		key_box.TextSize = 13
		key_box.TextXAlignment = Enum.TextXAlignment.Left
		key_box.Parent = toolbar

		duration_box = Instance.new("TextBox")
		duration_box.BackgroundColor3 = theme.TextBox
		duration_box.BorderColor3 = theme.Outline3
		duration_box.ClearTextOnFocus = false
		duration_box.Font = Enum.Font.Code
		duration_box.Position = UDim2.new(0, 8, 0, 38)
		duration_box.Size = UDim2.new(0, 60, 0, 22)
		duration_box.Text = "5"
		duration_box.TextColor3 = theme.Text
		duration_box.TextSize = 13
		duration_box.Parent = toolbar

		cap_box = Instance.new("TextBox")
		cap_box.BackgroundColor3 = theme.TextBox
		cap_box.BorderColor3 = theme.Outline3
		cap_box.ClearTextOnFocus = false
		cap_box.Font = Enum.Font.Code
		cap_box.Position = UDim2.new(0, 74, 0, 38)
		cap_box.Size = UDim2.new(0, 70, 0, 22)
		cap_box.Text = "200"
		cap_box.TextColor3 = theme.Text
		cap_box.TextSize = 13
		cap_box.Parent = toolbar

		button(toolbar, "Use Selected", UDim2.new(0, 152, 0, 38), UDim2.new(0, 94, 0, 22), load_selected_targets)
		button(toolbar, "Start Writes", UDim2.new(0, 252, 0, 38), UDim2.new(0, 92, 0, 22), function() start_probe(false, true) end)
		button(toolbar, "Start Reads", UDim2.new(0, 350, 0, 38), UDim2.new(0, 86, 0, 22), function() start_probe(true, false) end)
		button(toolbar, "Stop", UDim2.new(0, 442, 0, 38), UDim2.new(0, 58, 0, 22), function()
			active = false
			set_status(("Stopped: %d/%d events."):format(event_count, event_cap))
			render()
		end)
		button(toolbar, "Clear", UDim2.new(0, 506, 0, 38), UDim2.new(0, 58, 0, 22), function()
			table.clear(aggregates)
			clear_rows()
			event_count = 0
			set_status("Cleared.")
		end)

		target_label = Instance.new("TextLabel")
		target_label.BackgroundTransparency = 1
		target_label.Font = Enum.Font.SourceSans
		target_label.Position = UDim2.new(0, 8, 0, 64)
		target_label.Size = UDim2.new(0, 180, 0, 20)
		target_label.Text = "No target loaded"
		target_label.TextColor3 = theme.PlaceholderText
		target_label.TextSize = 13
		target_label.TextXAlignment = Enum.TextXAlignment.Left
		target_label.Parent = toolbar

		status_label = Instance.new("TextLabel")
		status_label.BackgroundTransparency = 1
		status_label.Font = Enum.Font.SourceSans
		status_label.Position = UDim2.new(0, 194, 0, 64)
		status_label.Size = UDim2.new(1, -202, 0, 20)
		status_label.Text = "Select object(s), choose keys, then Start Writes or Start Reads."
		status_label.TextColor3 = theme.PlaceholderText
		status_label.TextSize = 13
		status_label.TextXAlignment = Enum.TextXAlignment.Left
		status_label.TextTruncate = Enum.TextTruncate.AtEnd
		status_label.Parent = toolbar

		list_frame = Instance.new("ScrollingFrame")
		list_frame.Active = true
		list_frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
		list_frame.BackgroundColor3 = theme.Main2
		list_frame.BorderSizePixel = 0
		list_frame.Position = UDim2.new(0, 0, 0, 92)
		list_frame.Size = UDim2.new(1, 0, 1, -92)
		list_frame.ScrollBarImageColor3 = theme.Highlight
		list_frame.ScrollBarThickness = 8
		list_frame.Parent = content

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 2)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = list_frame
	end

	return probe
end

return {
	InitDeps = initDeps,
	InitAfterMain = initAfterMain,
	Main = main,
	PluginData = plugin_data,
}
