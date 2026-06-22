--[[
	Save Instance App Module
--[[
	Save Instance App Module
	
	Revival of the old dex's Save Instance
]] 

-- Common Locals
local Main,Lib,Apps,Settings -- Main Containers
local Explorer, Properties, Notepad, SettingsWindow -- Major Apps
local API,RMD,env,service,plr,create,createSimple -- Main Locals

local function initDeps(data)
	Main = data.Main
	Lib = data.Lib
	Apps = data.Apps
	Settings = data.Settings

	API = data.API
	RMD = data.RMD
	env = data.env
	service = data.service
	plr = data.plr
	create = data.create
	createSimple = data.createSimple
end

local function initAfterMain()
	Explorer = Apps.Explorer
	Properties = Apps.Properties
	Notepad = Apps.Notepad
	SettingsWindow = Apps.SettingsWindow
	end

local function main()
	local SettingsWindow = {}
	local window, ListFrame
	local fileName = "Place_"..game.PlaceId.."_"..game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name.."_{TIMESTAMP}"
	local Saving = false
	
	local function AddCheckbox(title, default)
		local frame = Lib.Frame.new()
		frame.Gui.Parent = ListFrame
		frame.Gui.Transparency = 1
		frame.Gui.Size = UDim2.new(1,0,0,20)
		
		local listlayout = Instance.new("UIListLayout")
		listlayout.Parent = frame.Gui
		listlayout.FillDirection = Enum.FillDirection.Horizontal
		listlayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		listlayout.VerticalAlignment = Enum.VerticalAlignment.Center
		listlayout.Padding = UDim.new(0, 10)
		
		-- Checkbox
		local checkbox = Lib.Checkbox.new()
		checkbox.Gui.Parent = frame.Gui
		checkbox.Gui.Size = UDim2.new(0,15,0,15)
		
		-- Label
		local label = Lib.Label.new()
		label.Gui.Parent = frame.Gui
		label.Gui.Size = UDim2.new(1, 0,1, -15)
		label.Gui.Text = title
		label.TextTruncate = Enum.TextTruncate.AtEnd
		
		if type(default) == "table" and default.onChange then
			checkbox:SetState(default:get())
			default:onChange(function(val)
				checkbox:SetState(val)
			end)
			checkbox.OnInput:Connect(function()
				default:set(checkbox.Toggled)
			end)
		else
			checkbox:SetState(default or false)
		end
		
		return checkbox
	end
	
	local function AddTextbox(title, default, sizeX)
		local isState = type(default) == "table" and default.onChange
		local defaultVal = isState and tostring(default:get()) or (default and tostring(default) or "")

		local frame = Lib.Frame.new()
		frame.Gui.Parent = ListFrame
		frame.Gui.Transparency = 1
		frame.Gui.Size = UDim2.new(1,0,0,20)

		local listlayout = Instance.new("UIListLayout")
		listlayout.Parent = frame.Gui
		listlayout.FillDirection = Enum.FillDirection.Horizontal
		listlayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		listlayout.VerticalAlignment = Enum.VerticalAlignment.Center
		listlayout.Padding = UDim.new(0, 10)

		-- Textbox
		local textbox = Instance.new("TextBox") -- replaced cuz why Moon make every inputs only work on mouse/pc users >:( 
		textbox.BackgroundColor3 = Settings.Theme.TextBox
		textbox.BorderColor3 = Settings.Theme.Outline3
		textbox.ClearTextOnFocus = false
		textbox.TextColor3 = Settings.Theme.Text
		textbox.Font = Enum.Font.SourceSans
		textbox.TextSize = 14
		textbox.ZIndex = 2

		textbox.Parent = frame.Gui
		if sizeX and type(sizeX) == "number" then
			textbox.Size = UDim2.new(0,sizeX,0,15)
		else
			textbox.Size = UDim2.new(0,45,0,15)
		end
		
		frame.Gui.AutomaticSize = Enum.AutomaticSize.X
		textbox.AutomaticSize = Enum.AutomaticSize.X

		-- Label
		local label = Lib.Label.new()
		label.Parent = frame.Gui
		label.Size = UDim2.new(1, 0,1, -15)
		label.Text = title
		label.TextTruncate = Enum.TextTruncate.AtEnd

		textbox.Text = defaultVal

		if isState then
			default:onChange(function(val)
				textbox.Text = tostring(val)
			end)
			textbox.FocusLost:Connect(function()
				default:set(textbox.Text)
			end)
		end

		return textbox
	end
	
	local function AddDropdown(title, options, default, allowEmpty, sizeX)
		if allowEmpty == nil then allowEmpty = true end
		
		local frame = Lib.Frame.new()
		frame.Gui.Parent = ListFrame
		frame.Gui.Transparency = 1
		frame.Gui.Size = UDim2.new(1,0,0,20)

		local listlayout = Instance.new("UIListLayout")
		listlayout.Parent = frame.Gui
		listlayout.FillDirection = Enum.FillDirection.Horizontal
		listlayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		listlayout.VerticalAlignment = Enum.VerticalAlignment.Center
		listlayout.Padding = UDim.new(0, 10)

		-- Textbox
		local dropdown = Lib.DropDown.new()
		dropdown.CanBeEmpty = allowEmpty
		dropdown.Size = UDim2.new(0,sizeX or 75,0,15)
		dropdown:SetOptions(options)
		if default then dropdown:SetSelected(default) end
		dropdown.Gui.Parent = frame.Gui

		frame.Gui.AutomaticSize = Enum.AutomaticSize.X

		-- Label
		local label = Lib.Label.new()

		label.Parent = frame.Gui
		label.Size = UDim2.new(1, 0,1, -15)
		label.Text = title
		label.TextTruncate = Enum.TextTruncate.AtEnd
		
		return dropdown
	end
	
	local function AddSeperator(title)

		local frame = Lib.Frame.new()
		frame.Gui.Parent = ListFrame
		frame.Gui.Transparency = 1
		frame.Gui.Size = UDim2.new(1,0,0,20)
		
		-- Label
		local label = Lib.Label.new()

		label.Parent = frame.Gui
		--label.AnchorPoint = Vector2.new(0,1)
		--label.Position = UDim2.new(0,0,0,0)
		label.Size = UDim2.new(1, 0,1, 0)
		label.Text = title
		label.TextSize = 16
		label.TextTruncate = Enum.TextTruncate.AtEnd

		return label
	end
	
	local function AddText(text)
		local frame = Lib.Frame.new()
		frame.Gui.Parent = ListFrame
		frame.Gui.Transparency = 1
		frame.Gui.Size = UDim2.new(1,0,0,15)

		-- Label
		local label = Lib.Label.new()

		label.Parent = frame.Gui
		--label.AnchorPoint = Vector2.new(0,1)
		--label.Position = UDim2.new(0,0,0,0)
		label.Size = UDim2.new(1, 0,1, 0)
		label.TextColor3 = Color3.fromRGB(185,185,185)
		label.Text = text
		label.TextSize = 14
		label.TextTruncate = Enum.TextTruncate.AtEnd

		return label
	end
	
	SettingsWindow.ReloadPrompt = function()		
		local win = Notepad.ReloadPromptWindow
		if not win then
			win = Lib.Window.new()
			win.Alignable = false
			win.Resizable = false
			win:SetTitle("Apply Current Settings")
			win:SetSize(300,115)

			local reloadButton = Lib.Button.new()
			local nameLabel = Lib.Label.new()
			nameLabel.Text = "By applying current settings requires reload.\nAny unsaved progress will be lost.\nAre you sure?"
			nameLabel.Position = UDim2.new(0,30,0,20)
			nameLabel.Size = UDim2.new(0,40,0,20)
			win:Add(nameLabel)

			local cancelButton = Lib.Button.new()
			cancelButton.AnchorPoint = Vector2.new(1,1)
			cancelButton.Text = "Apply Later"
			cancelButton.Position = UDim2.new(1,-5,1,-5)
			cancelButton.Size = UDim2.new(0.5,-10,0,20)
			cancelButton.OnClick:Connect(function()
				win:Close()
			end)
			win:Add(cancelButton)

			reloadButton.Text = "Apply Now"
			reloadButton.AnchorPoint = Vector2.new(0,1)
			reloadButton.Position = UDim2.new(0,5,1,-5)
			reloadButton.Size = UDim2.new(0.5,-5,0,20)
			reloadButton.OnClick:Connect(function()
				reloadButton:SetDisabled(true)
				reloadButton.Text = "Restarting"
				cancelButton:SetDisabled(true)
				if Main.Reinit and Main.Reinit() then
					win:Close()
				else
					reloadButton.Text = "Busy"
					task.delay(1, function()
						reloadButton:SetDisabled(false)
						cancelButton:SetDisabled(false)
						reloadButton.Text = "Apply Now"
					end)
				end
			end)

			win:Add(reloadButton,"reloadButton")

			SettingsWindow.ReloadPromptWindow = win
		end
		win:Show()
	end
	
	SettingsWindow.Init = function()
		window = Lib.Window.new()
		window:SetTitle("Settings")
		window:Resize(250,375)
		SettingsWindow.Window = window
		
		-- ListFrame
		
		ListFrame = Instance.new("ScrollingFrame")
		ListFrame.Parent = window.GuiElems.Content
		ListFrame.Size = UDim2.new(1, 0,1, -20)
		ListFrame.Position = UDim2.new(0, 0, 0, 0)
		ListFrame.Transparency = 1
		ListFrame.CanvasSize = UDim2.new(0,0,0,0)
		ListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
		ListFrame.ScrollBarThickness = 16
		ListFrame.BottomImage = ""
		ListFrame.TopImage = ""
		ListFrame.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 70)
		ListFrame.ScrollBarImageTransparency = 0
		ListFrame.ZIndex = 2
		ListFrame.BorderSizePixel = 0
		
		local scrollbar = Lib.ScrollBar.new()
		scrollbar.Gui.Parent = window.GuiElems.Content
		scrollbar.Gui.Size = UDim2.new(1, 0,1, -40)
		scrollbar.Gui.Up.ZIndex = 3
		scrollbar.Gui.Down.ZIndex = 3
		
		ListFrame:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(function()
			if ListFrame.AbsoluteCanvasSize ~= ListFrame.AbsoluteWindowSize then
				scrollbar.Gui.Visible = true
			else
				scrollbar.Gui.Visible = false
			end
		end)
		
		local ListLayout = Instance.new("UIListLayout")
		ListLayout.Parent = ListFrame
		ListLayout.Padding = UDim.new(0, 5)
		
		local Padding = Instance.new("UIPadding")
		Padding.Parent = ListFrame
		Padding.PaddingBottom = UDim.new(0, 5)
		Padding.PaddingLeft = UDim.new(0, 10)
		Padding.PaddingRight = UDim.new(0, 10)
		Padding.PaddingTop = UDim.new(0, 5)
		
		-- Options
		
		AddSeperator("UI")
		
		local titleOnMiddleState = Lib.State(Settings.Window.TitleOnMiddle)
		titleOnMiddleState:onChange(function(val)
			Settings.Window.TitleOnMiddle = val
		end)
		local titleonmiddle = AddCheckbox("Window Title On Middle", titleOnMiddleState)
		
		local autoCheckUpdateState = Lib.State(Settings.AutoCheckUpdate ~= false)
		autoCheckUpdateState:onChange(function(val)
			Settings.AutoCheckUpdate = val
		end)
		local autocheckupdate = AddCheckbox("Auto Check Update", autoCheckUpdateState)

		local updateRefState = Lib.State(Settings.AutoUpdateRef or "v3.1")
		updateRefState:onChange(function(val)
			local ref = tostring(val):gsub("^%s+", ""):gsub("%s+$", "")
			if ref == "" then ref = "v3.1" end
			Settings.AutoUpdateRef = ref
		end)
		local updateRef = AddTextbox("Update Ref (tag recommended)", updateRefState, 120)

		local allowBranchUpdateState = Lib.State(Settings.AutoUpdateAllowBranch == true)
		allowBranchUpdateState:onChange(function(val)
			Settings.AutoUpdateAllowBranch = val
		end)
		local allowBranchUpdate = AddCheckbox("Allow Main/Master Update Ref", allowBranchUpdateState)
		
		local bgTransparencyState = Lib.State(tostring(Settings.Window.Transparency))
		bgTransparencyState:onChange(function(val)
			local num = tonumber(val)
			if num then
				Settings.Window.Transparency = num
			end
		end)
		local bgTransparency = AddTextbox("Background Transparency", bgTransparencyState, 15)
		
		local classIcon = AddDropdown("Class Icons", {"Old", "NewDark", "Vanilla3"}, Settings.ClassIcon, false, 100)
		classIcon.OnSelect:Connect(function()
			Settings.ClassIcon = classIcon.Selected
		end)
		
		AddSeperator("Explorer")
		
		local clickRenameState = Lib.State(Settings.Explorer.ClickToRename)
		clickRenameState:onChange(function(val)
			Settings.Explorer.ClickToRename = val
		end)
		local clickRename = AddCheckbox("Click to Rename", clickRenameState)
		
		local partSelectionBoxState = Lib.State(Settings.Explorer.PartSelectionBox)
		partSelectionBoxState:onChange(function(val)
			Settings.Explorer.PartSelectionBox = val
		end)
		local partSelectionBox = AddCheckbox("Part Selection Box", partSelectionBoxState)
		
		local copypathUseChildrenState = Lib.State(Settings.Explorer.CopyPathUseGetChildren)
		copypathUseChildrenState:onChange(function(val)
			Settings.Explorer.CopyPathUseGetChildren = val
		end)
		local copypathUseChildren = AddCheckbox("Use GetChildren to Copy Path", copypathUseChildrenState)
		
		local spoofAntiCheatState = Lib.State(Settings.Explorer.AntiCheatSpoofing == true)
		spoofAntiCheatState:onChange(function(val)
			Settings.Explorer.AntiCheatSpoofing = val
		end)
		local spoofAntiCheat = AddCheckbox("Anti-Cheat Spoofing (Stealth)", spoofAntiCheatState)

		AddSeperator("Viewport Interaction")

		local viewportMenuEnabledState = Lib.State(Settings.Explorer.ViewportContextMenuEnabled)
		viewportMenuEnabledState:onChange(function(val)
			Settings.Explorer.ViewportContextMenuEnabled = val
			if Explorer and Explorer.UpdateViewportListener then
				Explorer.UpdateViewportListener()
			end
		end)
		local viewportMenuEnabled = AddCheckbox("Viewport Context Menu", viewportMenuEnabledState)

		local viewportMenuTrigger = AddDropdown("Viewport Menu Trigger", {"Right Click", "Middle Click"}, Settings.Explorer.ViewportContextMenuTrigger, false, 100)
		viewportMenuTrigger.OnSelect:Connect(function()
			Settings.Explorer.ViewportContextMenuTrigger = viewportMenuTrigger.Selected
			if Explorer and Explorer.UpdateViewportListener then
				Explorer.UpdateViewportListener()
			end
		end)

		local viewportMaxPanels = AddTextbox("Max 3D Panels (0 = Unlim)", tostring(Settings.Explorer.ViewportContextMenuMaxPanels or 10), 45)
		viewportMaxPanels.FocusLost:Connect(function()
			local num = tonumber(viewportMaxPanels.Text)
			if num then
				Settings.Explorer.ViewportContextMenuMaxPanels = math.max(0, math.floor(num))
				viewportMaxPanels.Text = tostring(Settings.Explorer.ViewportContextMenuMaxPanels)
			else
				viewportMaxPanels.Text = tostring(Settings.Explorer.ViewportContextMenuMaxPanels or 10)
			end
		end)

		local viewportCloseDelay = AddTextbox("3D Panel Close Delay (0 = Perm)", tostring(Settings.Explorer.ViewportContextMenuDistanceCloseTime or 10), 45)
		viewportCloseDelay.FocusLost:Connect(function()
			local num = tonumber(viewportCloseDelay.Text)
			if num then
				Settings.Explorer.ViewportContextMenuDistanceCloseTime = math.max(0, num)
				viewportCloseDelay.Text = tostring(Settings.Explorer.ViewportContextMenuDistanceCloseTime)
			else
				viewportCloseDelay.Text = tostring(Settings.Explorer.ViewportContextMenuDistanceCloseTime or 10)
			end
		end)

		local viewportMaxDist = AddTextbox("3D Panel Max Distance (0 = Inf)", tostring(Settings.Explorer.ViewportContextMenuMaxDistance or 50), 45)
		viewportMaxDist.FocusLost:Connect(function()
			local num = tonumber(viewportMaxDist.Text)
			if num then
				Settings.Explorer.ViewportContextMenuMaxDistance = math.max(0, num)
				viewportMaxDist.Text = tostring(Settings.Explorer.ViewportContextMenuMaxDistance)
			else
				viewportMaxDist.Text = tostring(Settings.Explorer.ViewportContextMenuMaxDistance or 50)
			end
		end)

		local fallbackDist = AddTextbox("2D Fallback Distance (0 = Inf)", tostring(Settings.Explorer.ViewportContextMenu2DFallbackDistance or 50), 45)
		fallbackDist.FocusLost:Connect(function()
			local num = tonumber(fallbackDist.Text)
			if num then
				Settings.Explorer.ViewportContextMenu2DFallbackDistance = math.max(0, num)
				fallbackDist.Text = tostring(Settings.Explorer.ViewportContextMenu2DFallbackDistance)
			else
				fallbackDist.Text = tostring(Settings.Explorer.ViewportContextMenu2DFallbackDistance or 50)
			end
		end)
		
		AddSeperator("Properties")

		local showDeprecated = AddCheckbox("Show Deprecated", Settings.Properties.ShowDeprecated)
		showDeprecated.OnInput:Connect(function()
			Settings.Properties.ShowDeprecated = showDeprecated.Toggled
		end)
		
		local showHidden = AddCheckbox("Show Hidden", Settings.Properties.ShowHidden)
		showHidden.OnInput:Connect(function()
			Settings.Properties.ShowHidden = showHidden.Toggled
		end)
		
		local showAttributes = AddCheckbox("Show Attributes", Settings.Properties.ShowAttributes)
		showAttributes.OnInput:Connect(function()
			Settings.Properties.ShowAttributes = showAttributes.Toggled
		end)
		local clearOnFocus = AddCheckbox("Clear On Focus", Settings.Properties.ClearOnFocus)
		clearOnFocus.OnInput:Connect(function()
			Settings.Properties.ClearOnFocus = clearOnFocus.Toggled
		end)
		
		AddSeperator("Notepad")
		
		local showMoreInfo = AddCheckbox("Show Decompiled Script Info", Settings.Notepad.ShowMoreInfo)
		showMoreInfo.OnInput:Connect(function()
			Settings.Notepad.ShowMoreInfo = showMoreInfo.Toggled
		end)
		
		AddSeperator("Decompiler")
		AddText("If executor does not support decompile, it will use the fallback option.")
		AddText("'getbytecode' is mandatory to use fallback decompilers.")
		AddText("Local C++ Helper handles /script, /normalize-source, /log and persistent source search; it does not decompile bytecode.")
		local useLocalHelper = AddCheckbox("Use Local Helper", Settings.Decompiler.UseLocalHelper == true)
		useLocalHelper.OnInput:Connect(function()
			Settings.Decompiler.UseLocalHelper = useLocalHelper.Toggled == true
		end)
		local helperLogChanges = AddCheckbox("Log Property Changes To Helper", Settings.Decompiler.HelperLogChanges == true)
		helperLogChanges.OnInput:Connect(function()
			Settings.Decompiler.HelperLogChanges = helperLogChanges.Toggled == true
		end)
		AddText("Keep property helper logging OFF during normal play. It is rate-limited, but noisy properties can still cost FPS.")
		local HelperLogLimit = AddTextbox("Helper Property Log Limit/s", tostring(Settings.Decompiler.HelperLogRateLimit or 5), 50)
		HelperLogLimit.FocusLost:Connect(function()
			local limitInput = tonumber(HelperLogLimit.Text)
			if not limitInput then
				HelperLogLimit.Text = tostring(Settings.Decompiler.HelperLogRateLimit or 5)
			else
				Settings.Decompiler.HelperLogRateLimit = math.clamp(math.floor(limitInput), 0, 100)
				HelperLogLimit.Text = tostring(Settings.Decompiler.HelperLogRateLimit)
			end
		end)
		local lowImpactIndex = AddCheckbox("Code Search Low Impact Index", Settings.Decompiler.CodeSearchLowImpact ~= false)
		lowImpactIndex.OnInput:Connect(function()
			Settings.Decompiler.CodeSearchLowImpact = lowImpactIndex.Toggled == true
		end)
		local decompilerOption = {"Executor (Native)", "Konstant", "AdvancedDecompiler", "Shiny"}
		local initialSelected = "Executor (Native)"
		if Settings.Decompiler.PreferDecompilerFallback then
			initialSelected = Settings.Decompiler.DecompilerFallback
		end

		local decompiler = AddDropdown("Active Decompiler", decompilerOption, initialSelected, false, 125)
		decompiler.OnSelect:Connect(function()
			local selected = decompiler.Selected
			if selected == "Executor (Native)" then
				Settings.Decompiler.PreferDecompilerFallback = false
			else
				Settings.Decompiler.PreferDecompilerFallback = true
				Settings.Decompiler.DecompilerFallback = selected
			end
		end)
		
		local ShinyPort = AddTextbox("Shiny Decompiler Port", tostring(Settings.Decompiler.ShinyDecompilerPort), 50)
		ShinyPort.FocusLost:Connect(function()
			local portinput = tonumber(ShinyPort.Text)
			if not portinput then
				ShinyPort.Text = Settings.Decompiler.ShinyDecompilerPort
			else
				if portinput > 0 and portinput <= 65535 then
					Settings.Decompiler.ShinyDecompilerPort = portinput
				else
					ShinyPort.Text = Settings.Decompiler.ShinyDecompilerPort
				end
			end
		end)

		local HelperPort = AddTextbox("Local Helper Port", tostring(Settings.Decompiler.HelperServerPort or 8080), 50)
		HelperPort.FocusLost:Connect(function()
			local portinput = tonumber(HelperPort.Text)
			if not portinput then
				HelperPort.Text = tostring(Settings.Decompiler.HelperServerPort or 8080)
			elseif portinput > 0 and portinput <= 65535 then
				Settings.Decompiler.HelperServerPort = portinput
			else
				HelperPort.Text = tostring(Settings.Decompiler.HelperServerPort or 8080)
			end
		end)
		
		-- Save buttons below
		local BackgroundreloadButton = Lib.Frame.new()
		BackgroundreloadButton.Gui.Parent = window.GuiElems.Content
		BackgroundreloadButton.Size = UDim2.new(1,0, 0,20)
		BackgroundreloadButton.Position = UDim2.new(0,0, 1,-20)
		
		local LabelreloadButton = Lib.Label.new()
		LabelreloadButton.Gui.Parent = window.GuiElems.Content
		LabelreloadButton.Size = UDim2.new(1,0, 0,20)
		LabelreloadButton.Position = UDim2.new(0,0, 1,-20)
		LabelreloadButton.Gui.Text = "Restart"
		LabelreloadButton.Gui.TextXAlignment = Enum.TextXAlignment.Center
		
		local reloadButton = Instance.new("TextButton")
		reloadButton.Parent = BackgroundreloadButton.Gui
		reloadButton.Size = UDim2.new(1,0, 1,0)
		reloadButton.Position = UDim2.new(0,0, 0,0)
		reloadButton.Transparency = 1
		
		local reloadClickBusy = false
		reloadButton.MouseButton1Click:Connect(function()
			if reloadClickBusy then return end
			reloadClickBusy = true
			window:SetTitle("Settings - Saving")
			
			Main.SaveCurrentSettings()
			
			window:SetTitle("Settings - Saved")
			SettingsWindow.ReloadPrompt()
			task.delay(3, function()
				reloadClickBusy = false
				if window and not window.Closed then
					window:SetTitle("Settings")
				end
			end)
		end)
	end

	return SettingsWindow
end

-- TODO: Remove when open source
if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
