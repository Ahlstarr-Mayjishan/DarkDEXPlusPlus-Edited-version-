--!strict
--[[
	DEX++ Main Menu GUI Module
	Handles creation of the main DEX++ tool selector menu, category tabs, lazy loading window apps.
]]
local Main, Lib, Apps, Settings
local API, RMD, env, service, plr, create, createSimple

local function initDeps(data)
	Main, Lib, Apps, Settings = data.Main, data.Lib, data.Apps, data.Settings
	API, RMD, env, service, plr = data.API, data.RMD, data.env, data.service, data.plr
	create, createSimple = data.create, data.createSimple
end

local function initAfterMain()
end

local function main()
	local appCategories = {
		["Explorer"] = "Core",
		["Properties"] = "Core",
		["Click part to select"] = "Core",
		["Notepad"] = "Core",
		["Console"] = "Core",
		["Save Instance"] = "Core",
		["Settings"] = "Core",

		["Runtime Monitor"] = "Spy & Hook",
		["Remote Usage"] = "Spy & Hook",
		["Runtime Inspector"] = "Spy & Hook",
		["Activity Map"] = "Spy & Hook",

		["Search Center"] = "Search & Info",
		["Code Search"] = "Search & Info",
		["Script Relations"] = "Search & Info",
		["Object Links"] = "Search & Info",
		["Dependency Graph"] = "Search & Info",
		["Smart Search"] = "Search & Info",
		["Snippet Library"] = "Search & Info",
		["Client Intelligence"] = "Search & Info",
		["Inspector Hub"] = "Search & Info",

		["3D Viewer"] = "Advanced",
		["Image Viewer"] = "Advanced",
		["Task Router"] = "Advanced",
		["Control Center"] = "Advanced",
		["Security Auditor"] = "Advanced",
		["Property Tracker"] = "Advanced",
		["Thread Manager"] = "Advanced",
		["Serialize Inst"] = "Advanced",
		["Memory Forensics"] = "Advanced",
		["Runtime Debugger"] = "Advanced",
		["IDE Sync"] = "Advanced",
	}

	local currentCategory = "All"

	Main.UpdateMenuCanvas = function()
		if not Main.AppsFrame or not Main.AppsContainerGrid then return end
		task.defer(function()
			if not Main.AppsFrame or not Main.AppsContainerGrid then return end
			local height = math.max(Main.AppsContainerGrid.AbsoluteContentSize.Y + 20, Main.AppsFrame.AbsoluteSize.Y)
			Main.AppsFrame.CanvasSize = UDim2.new(0,0,0,height)
		end)
	end

	Main.ApplyMenuFilter = function()
		local query = string.lower(Main.MenuSearchText or "")
		local visible = 0
		local total = 0
		for _, card in ipairs(Main.AppCards) do
			total = total + 1
			local category = appCategories[card.Name] or "Advanced"
			local categoryMatch = (currentCategory == "All") or 
								  (currentCategory == "Core" and category == "Core") or
								  (currentCategory == "Spy" and category == "Spy & Hook") or
								  (currentCategory == "Search" and category == "Search & Info") or
								  (currentCategory == "Advanced" and category == "Advanced")

			local isVisible = categoryMatch and (query == "" or string.find(card.SearchText, query, 1, true) ~= nil)
			if Main.HiddenAppsContainer and Main.AppsContainer then
				card.Gui.Parent = isVisible and Main.AppsContainer or Main.HiddenAppsContainer
				card.Gui.Visible = true
			else
				card.Gui.Visible = isVisible
			end
			if isVisible then visible = visible + 1 end
		end
		if Main.MenuCountLabel then
			Main.MenuCountLabel.Text = query == "" and (visible .. " tools") or (visible .. " / " .. total .. " tools")
		end
		Main.UpdateMenuCanvas()
	end

	Main.SmoothScrollingFrame = function(frame, step)
		local targetY = 0
		local tween
		local suppressCanvasSync = false
		local disabledNativeScroll = pcall(function()
			frame.ScrollingEnabled = false
		end)
		if not disabledNativeScroll then
			return
		end

		local function clampTarget()
			local maxY = math.max(0, frame.AbsoluteCanvasSize.Y - frame.AbsoluteWindowSize.Y)
			targetY = math.clamp(targetY, 0, maxY)
			return maxY
		end

		frame:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
			if suppressCanvasSync then return end
			local currentY = frame.CanvasPosition.Y
			if math.abs(currentY - targetY) > 2 and (not tween or tween.PlaybackState ~= Enum.PlaybackState.Playing) then
				targetY = currentY
				clampTarget()
			end
		end)

		local function scrollByInput(input)
			if not tween or tween.PlaybackState ~= Enum.PlaybackState.Playing then
				targetY = frame.CanvasPosition.Y
			end
			local direction = input.Position.Z > 0 and -1 or 1
			targetY = targetY + direction * (step or 96)
			clampTarget()
			suppressCanvasSync = true
			if tween then tween:Cancel() end
			tween = service.TweenService:Create(frame, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CanvasPosition = Vector2.new(frame.CanvasPosition.X, targetY)
			})
			suppressCanvasSync = false
			tween:Play()
		end

		return scrollByInput
	end

	Main.CreateApp = function(data)
		if Main.MenuApps[data.Name] then return end
		local control = {}

		local app = Main.AppTemplate:Clone()

		local iconIndex = data.Icon
		if data.IconMap and iconIndex then
			if type(iconIndex) == "number" then
				data.IconMap:Display(app.Main.Icon,iconIndex)
			elseif type(iconIndex) == "string" then
				data.IconMap:DisplayByKey(app.Main.Icon,iconIndex)
			end
		elseif type(iconIndex) == "string" then
			app.Main.Icon.Image = iconIndex
		else
			app.Main.Icon.Image = ""
		end

		local stroke = app.Main:FindFirstChildOfClass("UIStroke")
		local function updateState()
			local hovering = Lib.CheckMouseInGui(app.Main)
			app.Main.BackgroundTransparency = 0
			app.Main.BackgroundColor3 = data.Open and (Settings.Theme.AccentSoft or Settings.Theme.Main1) or (hovering and Settings.Theme.Main1 or Settings.Theme.Button)
			app.Main.Highlight.Visible = data.Open
			if app.Main:FindFirstChild("ActiveMarker") then
				app.Main.ActiveMarker.Visible = data.Open
			end
			if stroke then
				stroke.Color = data.Open and Settings.Theme.Highlight or Settings.Theme.Outline1
				stroke.Transparency = data.Open and 0.05 or (hovering and 0.18 or 0.48)
			end
		end

		local function enable(silent)
			if data.Open then return end
			data.Open = true
			updateState()
			if not silent then
				if data.Window then data.Window:Show() end
				if data.OnClick then data.OnClick(data.Open) end
			end
		end

		local function disable(silent)
			if not data.Open then return end
			data.Open = false
			updateState()
			if not silent then
				if data.Window then data.Window:Hide() end
				if data.OnClick then data.OnClick(data.Open) end
			end
		end

		updateState()

		app.Main.Size = UDim2.new(1,0,0,68)
		app.Main.AppName.Text = data.Name
		app.Main.AppName.Font = Enum.Font.GothamBold
		app.Main.AppName.TextXAlignment = Enum.TextXAlignment.Left

		local categoryLabel = app.Main:FindFirstChild("CategoryLabel")
		if not categoryLabel then
			categoryLabel = Instance.new("TextLabel")
			categoryLabel.Name = "CategoryLabel"
			categoryLabel.BackgroundTransparency = 1
			categoryLabel.Font = Enum.Font.Gotham
			categoryLabel.Position = UDim2.new(0,58,0,34)
			categoryLabel.Size = UDim2.new(1,-72,0,18)
			categoryLabel.TextColor3 = Settings.Theme.PlaceholderText
			categoryLabel.TextSize = 11
			categoryLabel.TextTruncate = Enum.TextTruncate.AtEnd
			categoryLabel.TextXAlignment = Enum.TextXAlignment.Left
			categoryLabel.Parent = app.Main
		end
		categoryLabel.Text = appCategories[data.Name] or "Advanced"
		categoryLabel.Visible = true

		if app.Main.Icon then
			app.Main.Icon.BackgroundTransparency = 1
			app.Main.Icon.ImageColor3 = Settings.Theme.Text
			app.Main.Icon.ImageTransparency = 0
		end

		app.Main.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				app.Main.BackgroundColor3 = data.Open and (Settings.Theme.AccentSoft or Settings.Theme.Main1) or Settings.Theme.Main1
				if stroke then stroke.Transparency = data.Open and 0.05 or 0.18 end
			end
		end)

		app.Main.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				updateState()
			end
		end)

		app.Main.MouseButton1Click:Connect(function()
			if data.Open then disable() else enable() end
		end)

		local window = data.Window
		if window then
			window.OnActivate:Connect(function() enable(true) end)
			window.OnDeactivate:Connect(function() disable(true) end)
		end

		app.Visible = true
		app.Parent = Main.AppsContainer
		table.insert(Main.AppCards, {
			Gui = app,
			Name = data.Name,
			SearchText = string.lower(data.Name .. " " .. tostring(data.Icon or "") .. " " .. tostring(appCategories[data.Name] or "Advanced"))
		})
		Main.ApplyMenuFilter()

		control.Enable = enable
		control.Disable = disable
		Main.MenuApps[data.Name] = control
		return control
	end

	Main.CreateLazyWindowApp = function(data)
		local initialized = false
		local control
		local moduleData = data.Module
		local ensureInit

		ensureInit = function()
			if not moduleData then
				if data.GetModule then
					moduleData = data.GetModule()
				end
				if not moduleData then
					warn("Lazy app module unavailable: " .. tostring(data.Name))
					if control then control.Disable(true) end
					return false
				end
				moduleData.EnsureInit = ensureInit
			end

			if initialized then return true end
			if moduleData.Init then
				local ok, err = pcall(moduleData.Init)
				if not ok then
					warn("Failed to lazy init " .. tostring(data.Name) .. ": " .. tostring(err))
					if control then control.Disable(true) end
					return false
				end
			end
			initialized = true
			if moduleData.Window then
				moduleData.Window.OnActivate:Connect(function()
					if control then control.Enable(true) end
				end)
				moduleData.Window.OnDeactivate:Connect(function()
					if control then control.Disable(true) end
				end)
			end
			return true
		end

		if moduleData then
			moduleData.EnsureInit = ensureInit
		end

		if data.Hidden then
			control = {
				Enable = function(silent)
					if not ensureInit() then return end
					if not silent and moduleData and moduleData.Window then
						moduleData.Window:Show()
					end
				end,
				Disable = function(silent)
					if not silent and initialized and moduleData and moduleData.Window then
						moduleData.Window:Hide()
					end
				end,
			}
			Main.MenuApps[data.Name] = control
			return control
		end

		control = Main.CreateApp({
			Name = data.Name,
			IconMap = data.IconMap,
			Icon = data.Icon,
			OnClick = function(open)
				if open then
					if not ensureInit() then return end
					if moduleData.Window then
						moduleData.Window:Show()
					else
						warn("Lazy app has no window: " .. tostring(data.Name))
						if control then control.Disable(true) end
					end
				elseif initialized and moduleData and moduleData.Window then
					moduleData.Window:Hide()
				end
			end
		})

		return control
	end

	Main.SetMainGuiOpen = function(val)
		Main.MainGuiOpen = val

		Main.MainGui.OpenButton.Text = "DEX++"
		if val then Main.MainGui.OpenButton.MainFrame.Visible = true end
		Main.MainGui.OpenButton.MainFrame:TweenSize(val and UDim2.new(0,500,0,560) or UDim2.new(0,0,0,0),Enum.EasingDirection.Out,Enum.EasingStyle.Quart,0.22,true)
		service.TweenService:Create(Main.MainGui.OpenButton,TweenInfo.new(0.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundTransparency = val and 0 or (Lib.CheckMouseInGui(Main.MainGui.OpenButton) and 0 or 0.2)}):Play()

		if Main.MainGuiMouseEvent then Main.MainGuiMouseEvent:Disconnect() end
		service.ContextActionService:UnbindAction("DEXPP_MenuWheel")

		if not val then
			local startTime = tick()
			Main.MainGuiCloseTime = startTime
			coroutine.wrap(function()
				Lib.FastWait(0.2)
				if not Main.MainGuiOpen and startTime == Main.MainGuiCloseTime then Main.MainGui.OpenButton.MainFrame.Visible = false end
			end)()
		else
			service.ContextActionService:BindActionAtPriority("DEXPP_MenuWheel", function(_, inputState, input)
				if inputState ~= Enum.UserInputState.Change then
					return Enum.ContextActionResult.Pass
				end
				if input.UserInputType == Enum.UserInputType.MouseWheel
					and Main.ScrollMenuBy
					and Lib.CheckMouseInGui(Main.MainGui.OpenButton.MainFrame)
				then
					Main.ScrollMenuBy(input)
					return Enum.ContextActionResult.Sink
				end
				return Enum.ContextActionResult.Pass
			end, false, Enum.ContextActionPriority.High.Value + 100, Enum.UserInputType.MouseWheel)

			Main.MainGuiMouseEvent = service.UserInputService.InputBegan:Connect(function(input)
				if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not Lib.CheckMouseInGui(Main.MainGui.OpenButton) and not Lib.CheckMouseInGui(Main.MainGui.OpenButton.MainFrame) then
					Main.SetMainGuiOpen(false)
				end
			end)
		end
	end

	Main.CreateMainGui = function()
		local gui = create({
			{1,"ScreenGui",{IgnoreGuiInset=true,Name="MainMenu",}},
			{2,"TextButton",{AnchorPoint=Vector2.new(0.5,0),AutoButtonColor=false,BackgroundColor3=Settings.Theme.Menu,BorderSizePixel=0,Font=Enum.Font.GothamBold,Name="OpenButton",Parent={1},Position=UDim2.new(0.5,0,0,6),Size=UDim2.new(0,96,0,34),Text="DEX++",TextColor3=Settings.Theme.Text,TextSize=14,TextTransparency=0.02,}},
			{3,"UICorner",{CornerRadius=UDim.new(0,10),Parent={2},}},
			{4,"Frame",{AnchorPoint=Vector2.new(0.5,0),BackgroundColor3=Settings.Theme.Main2,ClipsDescendants=true,Name="MainFrame",Parent={2},Position=UDim2.new(0.5,0,1,8),Size=UDim2.new(0,500,0,560),}},
			{5,"UICorner",{CornerRadius=UDim.new(0,8),Parent={4},}},
			{6,"Frame",{BackgroundColor3=Settings.Theme.Menu,Name="BottomFrame",Parent={4},Position=UDim2.new(0,0,1,-46),Size=UDim2.new(1,0,0,46),}},
			{7,"UICorner",{CornerRadius=UDim.new(0,8),Parent={6},}},
			{8,"Frame",{BackgroundColor3=Settings.Theme.Main1,BorderSizePixel=0,Name="CoverFrame",Parent={6},Size=UDim2.new(1,0,0,6),}},
			{9,"Frame",{BackgroundColor3=Settings.Theme.Outline1,BorderSizePixel=0,Name="Line",Parent={8},Position=UDim2.new(0,0,0,-1),Size=UDim2.new(1,0,0,1),}},
			{10,"TextButton",{BackgroundColor3=Settings.Theme.Button,BackgroundTransparency=0,BorderSizePixel=0,Font=3,Name="Settings",Parent={6},Position=UDim2.new(1,-86,0,8),Size=UDim2.new(0,32,0,28),Text="",TextColor3=Color3.new(1,1,1),TextSize=14,}},
			{11,"ImageLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Image="rbxassetid://6578871732",ImageColor3=Settings.Theme.Text,ImageTransparency=0.05,Name="Icon",Parent={10},Position=UDim2.new(0.5,-8,0.5,-8),Size=UDim2.new(0,16,0,16),}},
			{12,"TextButton",{BackgroundColor3=Settings.Theme.Button,BackgroundTransparency=0,BorderSizePixel=0,Font=3,Name="Information",Parent={6},Position=UDim2.new(1,-46,0,8),Size=UDim2.new(0,32,0,28),Text="",TextColor3=Color3.new(1,1,1),TextSize=14,}},
			{13,"ImageLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Image="rbxassetid://6578933307",ImageColor3=Settings.Theme.Text,ImageTransparency=0.05,Name="Icon",Parent={12},Position=UDim2.new(0.5,-8,0.5,-8),Size=UDim2.new(0,16,0,16),}},
			{14,"ScrollingFrame",{Active=true,AnchorPoint=Vector2.new(0.5,0),BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderColor3=Settings.Theme.Outline1,BorderSizePixel=0,Name="AppsFrame",Parent={4},Position=UDim2.new(0.5,0,0,120),ScrollBarImageColor3=Settings.Theme.Highlight,ScrollBarImageTransparency=0.15,ScrollBarThickness=4,Size=UDim2.new(1,-20,1,-174),}},
			{15,"Frame",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Name="Container",Parent={14},Position=UDim2.new(0,8,0,8),Size=UDim2.new(1,-24,0,2),}},
			{16,"UIGridLayout",{CellPadding=UDim2.new(0,8,0,8),CellSize=UDim2.new(0,224,0,68),Parent={15},SortOrder=2,}},
			{17,"Frame",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Name="App",Parent={1},Size=UDim2.new(0,100,0,100),Visible=false,}},
			{18,"TextButton",{AutoButtonColor=false,BackgroundColor3=Settings.Theme.Button,BorderSizePixel=0,Font=Enum.Font.GothamBold,Name="Main",Parent={17},Size=UDim2.new(1,0,0,68),Text="",TextColor3=Color3.new(0,0,0),TextSize=14,}},
			{19,"ImageLabel",{BackgroundTransparency=1,Image="rbxassetid://129589545519436",ImageColor3=Settings.Theme.Text,ImageTransparency=0,ImageRectSize=Vector2.new(32,32),Name="Icon",Parent={18},Position=UDim2.new(0,14,0.5,-16),ScaleType=4,Size=UDim2.new(0,32,0,32),}},
			{20,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Font=Enum.Font.GothamBold,Name="AppName",Parent={18},Position=UDim2.new(0,58,0,10),Size=UDim2.new(1,-72,0,20),Text="Explorer",TextColor3=Settings.Theme.Text,TextSize=13,TextTransparency=0,TextTruncate=1,TextWrapped=false,TextXAlignment=0,}},
			{21,"Frame",{BackgroundColor3=Settings.Theme.ListSelection,BorderSizePixel=0,Name="Highlight",Parent={18},Position=UDim2.new(0,0,0,0),Size=UDim2.new(0,3,1,0),}},
			{22,"UIStroke",{ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Color=Settings.Theme.Outline1,Thickness=1,Transparency=0.2,Parent={2},}},
			{23,"UIStroke",{ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Color=Settings.Theme.Outline1,Thickness=1,Transparency=0.25,Parent={4},}},
			{24,"Frame",{BackgroundColor3=Settings.Theme.Main1,BorderSizePixel=0,Name="Header",Parent={4},Position=UDim2.new(0,0,0,0),Size=UDim2.new(1,0,0,116),}},
			{25,"TextLabel",{BackgroundTransparency=1,Font=Enum.Font.GothamBold,Name="Title",Parent={24},Position=UDim2.new(0,18,0,12),Size=UDim2.new(1,-36,0,22),Text="DEX++ Tools",TextColor3=Settings.Theme.Text,TextSize=17,TextXAlignment=0,}},
			{26,"TextLabel",{BackgroundTransparency=1,Font=Enum.Font.Gotham,Name="Subtitle",Parent={24},Position=UDim2.new(0,18,0,35),Size=UDim2.new(1,-36,0,18),Text="Open, search, and manage client tools",TextColor3=Settings.Theme.PlaceholderText,TextSize=12,TextXAlignment=0,}},
			{27,"TextBox",{BackgroundColor3=Settings.Theme.TextBox,BorderSizePixel=0,ClearTextOnFocus=false,Font=Enum.Font.RobotoMono,Name="SearchBox",Parent={24},PlaceholderColor3=Settings.Theme.PlaceholderText,PlaceholderText="Search tools by name or category",Position=UDim2.new(0,16,0,64),Size=UDim2.new(1,-32,0,30),Text="",TextColor3=Settings.Theme.Text,TextSize=12,TextXAlignment=0,}},
			{28,"UICorner",{CornerRadius=UDim.new(0,6),Parent={27},}},
			{29,"UIStroke",{ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Color=Settings.Theme.Outline1,Thickness=1,Transparency=0.35,Parent={27},}},
			{30,"TextLabel",{BackgroundTransparency=1,Font=Enum.Font.Gotham,Name="AppCount",Parent={6},Position=UDim2.new(0,12,0,0),Size=UDim2.new(1,-98,1,0),Text="0 tools",TextColor3=Settings.Theme.PlaceholderText,TextSize=12,TextXAlignment=0,}},
			{31,"UICorner",{CornerRadius=UDim.new(0,6),Parent={10},}},
			{32,"UICorner",{CornerRadius=UDim.new(0,6),Parent={12},}},
			{33,"UICorner",{CornerRadius=UDim.new(0,6),Parent={18},}},
			{34,"UIStroke",{ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Color=Settings.Theme.Outline1,Thickness=1,Transparency=0.55,Parent={18},}},
			{35,"Frame",{BackgroundColor3=Settings.Theme.Highlight,BorderSizePixel=0,Name="ActiveMarker",Parent={18},Position=UDim2.new(0,0,0,0),Size=UDim2.new(0,3,1,0),Visible=false,}},
		})
		Main.MainGui = gui
		Main.AppsFrame = gui.OpenButton.MainFrame.AppsFrame
		Main.AppsContainer = Main.AppsFrame.Container
		Main.AppsContainerGrid = Main.AppsContainer.UIGridLayout
		Main.AppTemplate = gui.App
		Main.HiddenAppsContainer = Instance.new("Frame")
		Main.HiddenAppsContainer.Name = "HiddenApps"
		Main.HiddenAppsContainer.Visible = false
		Main.HiddenAppsContainer.Parent = gui
		Main.MenuSearchBox = gui.OpenButton.MainFrame.Header.SearchBox
		Main.MenuCountLabel = gui.OpenButton.MainFrame.BottomFrame.AppCount
		Main.MainGuiOpen = false

		-- Dynamically modify dimensions to make space for category tabs
		local mainFrame = gui.OpenButton.MainFrame
		local header = mainFrame.Header
		header.Size = UDim2.new(1, 0, 0, 142)
		mainFrame.AppsFrame.Position = UDim2.new(0.5, 0, 0, 148)
		mainFrame.AppsFrame.Size = UDim2.new(1, -16, 1, -196)

		-- Create tabs container
		local tabContainer = Instance.new("Frame")
		tabContainer.Name = "CategoryTabs"
		tabContainer.BackgroundTransparency = 1
		tabContainer.Position = UDim2.new(0, 14, 0, 104)
		tabContainer.Size = UDim2.new(1, -28, 0, 28)
		tabContainer.Parent = header

		local tabLayout = Instance.new("UIListLayout")
		tabLayout.FillDirection = Enum.FillDirection.Horizontal
		tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		tabLayout.Padding = UDim.new(0, 6)
		tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
		tabLayout.Parent = tabContainer

		local categories = {"All", "Core", "Spy", "Search", "Advanced"}
		local tabButtons = {}

		local function updateTabVisuals()
			for cat, btn in pairs(tabButtons) do
				local active = (cat == currentCategory)
				btn.BackgroundColor3 = active and (Settings.Theme.AccentSoft or Settings.Theme.Main1) or Settings.Theme.Button
				btn.TextColor3 = active and Settings.Theme.Text or Settings.Theme.PlaceholderText
				local stroke = btn:FindFirstChild("UIStroke")
				if stroke then
					stroke.Color = active and Settings.Theme.Highlight or Settings.Theme.Outline1
					stroke.Transparency = active and 0.08 or 0.42
				end
			end
		end

		for i, cat in ipairs(categories) do
			local btn = Instance.new("TextButton")
			btn.Name = cat .. "Tab"
			btn.AutoButtonColor = false
			btn.BackgroundColor3 = Settings.Theme.Button
			btn.BorderSizePixel = 0
			btn.Font = Enum.Font.GothamBold
			btn.Size = UDim2.new(0, cat == "Advanced" and 78 or (cat == "Search" and 68 or (cat == "Spy" and 84 or 58)), 1, 0)
			btn.Text = cat == "Spy" and "Spy & Hook" or (cat == "Search" and "Search" or cat)
			btn.TextColor3 = Settings.Theme.PlaceholderText
			btn.TextSize = 11
			btn.LayoutOrder = i
			btn.Parent = tabContainer

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 6)
			corner.Parent = btn

			local stroke = Instance.new("UIStroke")
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Color = Settings.Theme.Outline1
			stroke.Thickness = 1
			stroke.Transparency = 0.35
			stroke.Parent = btn

			tabButtons[cat] = btn

			btn.MouseButton1Click:Connect(function()
				currentCategory = cat
				updateTabVisuals()
				Main.ApplyMenuFilter()
			end)

			btn.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
					if cat ~= currentCategory then
						btn.BackgroundColor3 = Settings.Theme.Main1
					end
				end
			end)

			btn.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
					updateTabVisuals()
				end
			end)
		end

		updateTabVisuals()

		local openButton = gui.OpenButton
		openButton.BackgroundTransparency = 0.2
		openButton.MainFrame.Size = UDim2.new(0,0,0,0)
		openButton.MainFrame.Visible = false
		Main.MenuSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
			Main.MenuSearchText = Main.MenuSearchBox.Text
			Main.ApplyMenuFilter()
		end)
		Main.AppsContainerGrid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(Main.UpdateMenuCanvas)
		Main.ScrollMenuBy = Main.SmoothScrollingFrame(Main.AppsFrame, 76)
		openButton.MouseButton1Click:Connect(function()
			Main.SetMainGuiOpen(not Main.MainGuiOpen)
		end)

		openButton.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				service.TweenService:Create(Main.MainGui.OpenButton,TweenInfo.new(0,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundTransparency = 0}):Play()
			end
		end)

		openButton.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				service.TweenService:Create(Main.MainGui.OpenButton,TweenInfo.new(0,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundTransparency = Main.MainGuiOpen and 0 or 0.2}):Play()
			end
		end)
	end
end

return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
