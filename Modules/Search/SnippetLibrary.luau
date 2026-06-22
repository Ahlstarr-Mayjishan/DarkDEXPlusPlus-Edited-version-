--!strict
--[[
	Snippet Library App Module
	Manages saving, editing, searching, and deleting custom Luau snippets.
	Integrates with Notepad for code insertion and selection importing.
]]
local Main, Lib, Apps, Settings
local Notepad, SnippetLibrary
local API, RMD, env, service, plr, create, createSimple

local function initDeps(data)
	Main, Lib, Apps, Settings = data.Main, data.Lib, data.Apps, data.Settings
	API, RMD, env, service, plr = data.API, data.RMD, data.env, data.service, data.plr
	create, createSimple = data.create, data.createSimple
end

local function initAfterMain()
	Notepad = Apps.Notepad
	SnippetLibrary = Apps.SnippetLibrary
end

type Snippet = {
	title: string,
	description: string,
	code: string
}

local function main()
	local SnippetLibrary = {}
	local window
	local toolbar
	local searchBox
	local resultsFrame
	local editorFrame
	
	local titleInput
	local descInput
	local codeInput
	
	local currentEditingIndex: number? = nil
	local snippets: {Snippet} = {}

	local function loadSnippets(): {Snippet}
		local path = "dex/snippets.json"
		if env.isfile and env.isfile(path) then
			local ok, data = pcall(env.readfile, path)
			if ok and data then
				local decodeOk, decoded = pcall(service.HttpService.JSONDecode, service.HttpService, data)
				if decodeOk and type(decoded) == "table" then
					return decoded :: {Snippet}
				end
			end
		end

		-- Default snippets when snippets.json doesn't exist
		local defaults: {Snippet} = {
			{
				title = "Simple ESP",
				description = "Highlights all players with highlights and name tags",
				code = "-- Simple ESP\nlocal Players = game:GetService(\"Players\")\nlocal function createESP(player)\n    if player == Players.LocalPlayer then return end\n    local function onChar(char)\n        local highlight = Instance.new(\"Highlight\")\n        highlight.FillColor = Color3.fromRGB(255, 0, 0)\n        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)\n        highlight.FillTransparency = 0.5\n        highlight.Parent = char\n\n        local billboard = Instance.new(\"BillboardGui\")\n        billboard.Size = UDim2.new(0, 200, 0, 50)\n        billboard.Adornee = char:WaitForChild(\"Head\")\n        billboard.AlwaysOnTop = true\n        billboard.StudsOffset = Vector3.new(0, 3, 0)\n\n        local label = Instance.new(\"TextLabel\")\n        label.Size = UDim2.new(1, 0, 1, 0)\n        label.BackgroundTransparency = 1\n        label.Text = player.Name\n        label.TextColor3 = Color3.fromRGB(255, 255, 255)\n        label.TextSize = 14\n        label.Font = Enum.Font.SourceSansBold\n        label.Parent = billboard\n        billboard.Parent = char\n    end\n    if player.Character then onChar(player.Character) end\n    player.CharacterAdded:Connect(onChar)\nend\nfor _, player in ipairs(Players:GetPlayers()) do createESP(player) end\nPlayers.PlayerAdded:Connect(createESP)"
			},
			{
				title = "HttpSpy",
				description = "Logs all HttpGet, HttpPost and request calls made by scripts",
				code = "-- HttpSpy (Hooks request/HttpGet/HttpPost to print outgoing network requests)\nlocal function hook(name, parent, original)\n    local old\n    old = hookfunction(parent[original], function(self, ...)\n        local args = {...}\n        print(\"[HttpSpy] \" .. name .. \" called:\", service.HttpService:JSONEncode(args))\n        return old(self, ...)\n    end)\nend\nlocal function hookGlobal(name, fn)\n    local old\n    old = hookfunction(fn, function(...)\n        local args = {...}\n        print(\"[HttpSpy] \" .. name .. \" called:\", service.HttpService:JSONEncode(args))\n        return old(...)\n    end)\nend\nif request then hookGlobal(\"request\", request) end\nif game.HttpGet then hook(\"HttpGet\", game, \"HttpGet\") end\nif game.HttpPost then hook(\"HttpPost\", game, \"HttpPost\") end"
			},
			{
				title = "Aimbot Template",
				description = "Basic aimbot template utilizing camera lookVector towards closest player",
				code = "-- Aimbot Template\nlocal Players = game:GetService(\"Players\")\nlocal LocalPlayer = Players.LocalPlayer\nlocal Camera = workspace.CurrentCamera\nlocal function getClosestPlayer()\n    local closest, maxDist = nil, math.huge\n    for _, plr in ipairs(Players:GetPlayers()) do\n        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild(\"HumanoidRootPart\") then\n            local screenPos, onScreen = Camera:WorldToViewportPoint(plr.Character.HumanoidRootPart.Position)\n            if onScreen then\n                local mousePos = Vector2.new(LocalPlayer:GetMouse().X, LocalPlayer:GetMouse().Y)\n                local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude\n                if dist < maxDist then\n                    closest = plr\n                    maxDist = dist\n                end\n            end\n        end\n    end\n    return closest\nend\ngame:GetService(\"RunService\").RenderStepped:Connect(function()\n    local target = getClosestPlayer()\n    if target and target.Character and target.Character:FindFirstChild(\"HumanoidRootPart\") then\n        Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Character.HumanoidRootPart.Position)\n    end\nend)"
			}
		}

		if env.writefile then
			pcall(env.writefile, path, service.HttpService:JSONEncode(defaults))
		end
		return defaults
	end

	local function saveSnippets(list: {Snippet})
		local path = "dex/snippets.json"
		if env.writefile then
			pcall(env.writefile, path, service.HttpService:JSONEncode(list))
		end
	end

	local function openEditor(idx: number?)
		currentEditingIndex = idx
		if idx then
			local snip = snippets[idx]
			titleInput.Text = snip.title
			descInput.Text = snip.description
			codeInput.Text = snip.code
		else
			titleInput.Text = ""
			descInput.Text = ""
			codeInput.Text = ""
		end
		editorFrame.Visible = true
	end

	local function refreshList()
		for _, child in pairs(resultsFrame:GetChildren()) do
			if child:IsA("GuiButton") then child:Destroy() end
		end

		local filter = searchBox.Text:lower()

		for idx, snip in ipairs(snippets) do
			if filter == "" or snip.title:lower():find(filter, 1, true) or snip.description:lower():find(filter, 1, true) then
				local row = createSimple("TextButton",{
					AutoButtonColor = false,
					BackgroundColor3 = Settings.Theme.Main1,
					BorderColor3 = Settings.Theme.Outline1,
					BorderSizePixel = 1,
					Font = Enum.Font.SourceSans,
					Size = UDim2.new(1, -8, 0, 46),
					Text = "",
					Parent = resultsFrame
				})

				createSimple("TextLabel",{
					BackgroundTransparency = 1,
					Font = Enum.Font.SourceSansBold,
					Position = UDim2.new(0, 8, 0, 3),
					Size = UDim2.new(1, -16, 0, 18),
					Text = snip.title,
					TextColor3 = Settings.Theme.Text,
					TextSize = 14,
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = row
				})

				local descText = snip.description
				if descText == "" then
					descText = snip.code:sub(1, 100):gsub("[\r\n]+", " ")
				end
				createSimple("TextLabel",{
					BackgroundTransparency = 1,
					Font = Enum.Font.SourceSans,
					Position = UDim2.new(0, 8, 0, 23),
					Size = UDim2.new(1, -16, 0, 18),
					Text = descText,
					TextColor3 = Settings.Theme.PlaceholderText,
					TextSize = 13,
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = row
				})

				Lib.ButtonAnim(row,{
					Mode = 2,
					StartColor = Settings.Theme.Main1,
					HoverColor = Settings.Theme.ButtonHover,
					PressColor = Settings.Theme.ButtonPress,
					OutlineColor = Settings.Theme.Outline1
				})

				row.MouseButton1Click:Connect(function()
					openEditor(idx)
				end)

				row.MouseButton2Click:Connect(function()
					local menu = Lib.ContextMenu.new()

					menu:Add({
						Name = "Insert into Notepad",
						IconMap = Main.MiscIcons,
						Icon = "ViewScript",
						OnClick = function()
							if Notepad and Notepad.InsertCode then
								Notepad.InsertCode(snip.code)
							end
						end
					})

					menu:Add({
						Name = "Copy to Clipboard",
						IconMap = Main.MiscIcons,
						Icon = "Copy",
						OnClick = function()
							if env.setclipboard then
								env.setclipboard(snip.code)
							end
						end
					})

					menu:Add({
						Name = "Edit",
						IconMap = Main.MiscIcons,
						Icon = "Rename",
						OnClick = function()
							openEditor(idx)
						end
					})

					menu:Add({
						Name = "Delete",
						IconMap = Main.MiscIcons,
						Icon = "Delete",
						OnClick = function()
							table.remove(snippets, idx)
							saveSnippets(snippets)
							refreshList()
						end
					})

					menu:Show()
				end)
			end
		end
	end

	local function createEditor(parent)
		local editor = createSimple("Frame",{
			BackgroundColor3 = Settings.Theme.Main2,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0),
			Visible = false,
			ZIndex = 10,
			Parent = parent
		})

		local banner = createSimple("Frame",{
			BackgroundColor3 = Settings.Theme.Main1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 30),
			Parent = editor
		})
		createSimple("TextLabel",{
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSansBold,
			Position = UDim2.new(0, 10, 0, 0),
			Size = UDim2.new(1, -20, 1, 0),
			Text = "Snippet Editor",
			TextColor3 = Settings.Theme.Text,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = banner
		})

		createSimple("TextLabel",{
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSansBold,
			Position = UDim2.new(0, 10, 0, 40),
			Size = UDim2.new(0, 80, 0, 20),
			Text = "Title:",
			TextColor3 = Settings.Theme.PlaceholderText,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = editor
		})
		titleInput = createSimple("TextBox",{
			BackgroundColor3 = Settings.Theme.TextBox,
			BorderColor3 = Settings.Theme.Outline3,
			ClearTextOnFocus = false,
			Font = Enum.Font.SourceSans,
			PlaceholderColor3 = Settings.Theme.PlaceholderText,
			PlaceholderText = "Snippet title",
			Position = UDim2.new(0, 90, 0, 40),
			Size = UDim2.new(1, -100, 0, 22),
			Text = "",
			TextColor3 = Settings.Theme.Text,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = editor
		})

		createSimple("TextLabel",{
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSansBold,
			Position = UDim2.new(0, 10, 0, 70),
			Size = UDim2.new(0, 80, 0, 20),
			Text = "Description:",
			TextColor3 = Settings.Theme.PlaceholderText,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = editor
		})
		descInput = createSimple("TextBox",{
			BackgroundColor3 = Settings.Theme.TextBox,
			BorderColor3 = Settings.Theme.Outline3,
			ClearTextOnFocus = false,
			Font = Enum.Font.SourceSans,
			PlaceholderColor3 = Settings.Theme.PlaceholderText,
			PlaceholderText = "Tags or brief description",
			Position = UDim2.new(0, 90, 0, 70),
			Size = UDim2.new(1, -100, 0, 22),
			Text = "",
			TextColor3 = Settings.Theme.Text,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = editor
		})

		createSimple("TextLabel",{
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSansBold,
			Position = UDim2.new(0, 10, 0, 100),
			Size = UDim2.new(0, 80, 0, 20),
			Text = "Code:",
			TextColor3 = Settings.Theme.PlaceholderText,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = editor
		})

		local codeScroll = createSimple("ScrollingFrame",{
			Active = true,
			BackgroundColor3 = Settings.Theme.TextBox,
			BorderColor3 = Settings.Theme.Outline3,
			Position = UDim2.new(0, 90, 0, 100),
			Size = UDim2.new(1, -100, 1, -145),
			ScrollBarThickness = 8,
			Parent = editor
		})

		codeInput = createSimple("TextBox",{
			BackgroundTransparency = 1,
			ClearTextOnFocus = false,
			MultiLine = true,
			TextWrapped = false,
			Font = Enum.Font.RobotoMono,
			Size = UDim2.new(1, 0, 1, 0),
			Text = "",
			TextColor3 = Settings.Theme.Text,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = codeScroll
		})

		codeInput:GetPropertyChangedSignal("Text"):Connect(function()
			local lines = select(2, codeInput.Text:gsub("\n", "\n")) + 1
			local width = 0
			for line in codeInput.Text:gmatch("[^\r\n]+") do
				width = math.max(width, #line * 8)
			end
			codeScroll.CanvasSize = UDim2.new(0, math.max(0, width), 0, math.max(0, lines * 16))
			codeInput.Size = UDim2.new(0, math.max(codeScroll.AbsoluteSize.X, width), 0, math.max(codeScroll.AbsoluteSize.Y, lines * 16))
		end)

		local function button(text, color, x, w, cb)
			local b = createSimple("TextButton",{
				AutoButtonColor = false,
				BackgroundColor3 = color,
				BorderColor3 = Settings.Theme.Outline2,
				Font = Enum.Font.SourceSansBold,
				Position = UDim2.new(1, x, 1, -34),
				Size = UDim2.new(0, w, 0, 26),
				Text = text,
				TextColor3 = Settings.Theme.Text,
				TextSize = 14,
				Parent = editor
			})
			b.MouseButton1Click:Connect(cb)
			Lib.ButtonAnim(b,{
				Mode = 2,
				StartColor = color,
				HoverColor = Settings.Theme.ButtonHover,
				PressColor = Settings.Theme.ButtonPress,
				OutlineColor = Settings.Theme.Outline2
			})
		end

		button("Save", Settings.Theme.Success, -170, 75, function()
			if titleInput.Text == "" then return end
			local snip: Snippet = {
				title = titleInput.Text,
				description = descInput.Text,
				code = codeInput.Text
			}
			if currentEditingIndex then
				snippets[currentEditingIndex] = snip
			else
				table.insert(snippets, snip)
			end
			saveSnippets(snippets)
			editor.Visible = false
			refreshList()
		end)

		button("Cancel", Settings.Theme.Button, -85, 75, function()
			editor.Visible = false
		end)

		return editor
	end

	local function button(parent, text, x, w, cb)
		local b = createSimple("TextButton",{
			AutoButtonColor = false,
			BackgroundColor3 = Settings.Theme.Button,
			BorderColor3 = Settings.Theme.Outline2,
			Font = Enum.Font.SourceSans,
			Position = UDim2.new(0, x, 0, 4),
			Size = UDim2.new(0, w, 0, 22),
			Text = text,
			TextColor3 = Settings.Theme.Text,
			TextSize = 14,
			Parent = parent
		})
		b.MouseButton1Click:Connect(cb)
		Lib.ButtonAnim(b,{
			Mode = 2,
			StartColor = Settings.Theme.Button,
			HoverColor = Settings.Theme.ButtonHover,
			PressColor = Settings.Theme.ButtonPress,
			OutlineColor = Settings.Theme.Outline2
		})
	end

	SnippetLibrary.Init = function()
		window = Lib.Window.new()
		window:SetTitle("Snippet Library")
		window:Resize(640, 430)
		SnippetLibrary.Window = window

		local content = window.GuiElems.Content
		toolbar = createSimple("Frame",{
			BackgroundColor3 = Settings.Theme.Main2,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 60),
			Parent = content
		})

		searchBox = createSimple("TextBox",{
			BackgroundColor3 = Settings.Theme.TextBox,
			BorderColor3 = Settings.Theme.Outline3,
			ClearTextOnFocus = false,
			Font = Enum.Font.SourceSans,
			PlaceholderColor3 = Settings.Theme.PlaceholderText,
			PlaceholderText = "Search snippets by title or description",
			Position = UDim2.new(0, 6, 0, 32),
			Size = UDim2.new(1, -12, 0, 22),
			Text = "",
			TextColor3 = Settings.Theme.Text,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = toolbar
		})

		button(toolbar, "New", 6, 50, function()
			openEditor(nil)
		end)

		button(toolbar, "Import Selection", 62, 110, function()
			if Notepad and Notepad.GetSelectionText then
				local text = Notepad.GetSelectionText()
				if text and text ~= "" then
					openEditor(nil)
					codeInput.Text = text
					titleInput.Text = "Imported Snippet"
				else
					openEditor(nil)
				end
			else
				openEditor(nil)
			end
		end)

		button(toolbar, "Clear Search", 178, 90, function()
			searchBox.Text = ""
			refreshList()
		end)

		resultsFrame = createSimple("ScrollingFrame",{
			Active = true,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Settings.Theme.Main2,
			BorderSizePixel = 0,
			BottomImage = "",
			CanvasSize = UDim2.new(0, 0, 0, 0),
			Position = UDim2.new(0, 0, 0, 60),
			ScrollBarImageColor3 = Color3.fromRGB(70, 70, 70),
			ScrollBarThickness = 10,
			Size = UDim2.new(1, 0, 1, -60),
			TopImage = "",
			Parent = content
		})

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = resultsFrame

		local pad = Instance.new("UIPadding")
		pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop = UDim.new(0, 6), UDim.new(0, 4), UDim.new(0, 4), UDim.new(0, 4)
		pad.Parent = resultsFrame

		searchBox.FocusLost:Connect(function(enterPressed)
			refreshList()
		end)
		searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			refreshList()
		end)

		editorFrame = createEditor(content)
		snippets = loadSnippets()
		refreshList()
	end

	return SnippetLibrary
end

if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
