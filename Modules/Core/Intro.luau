--strict
--[[
	DEX++ Intro Module
	Manages the Splash Screen / Intro UI shown when launching DEX++.
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
	Main.CreateIntro = function(initStatus)
		local gui = create({
			{1,"ScreenGui",{Name="Intro",}},
			{2,"Frame",{Active=true,BackgroundColor3=Color3.new(0.20392157137394,0.20392157137394,0.20392157137394),BorderSizePixel=0,Name="Main",Parent={1},Position=UDim2.new(0.5,-175,0.5,-100),Size=UDim2.new(0,350,0,200),}},
			{3,"Frame",{BackgroundColor3=Color3.new(0.17647059261799,0.17647059261799,0.17647059261799),BorderSizePixel=0,ClipsDescendants=true,Name="Holder",Parent={2},Size=UDim2.new(1,0,1,0),}},
			{4,"UIGradient",{Parent={3},Rotation=30,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1,0),NumberSequenceKeypoint.new(1,1,0),}),}},
			{5,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=4,Name="Title",Parent={3},Position=UDim2.new(0,-190,0,15),Size=UDim2.new(0,100,0,50),Text="Dex++",TextColor3=Color3.new(1,1,1),TextSize=50,TextTransparency=1,}},
			{6,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="Desc",Parent={3},Position=UDim2.new(0,-230,0,60),Size=UDim2.new(0,180,0,25),Text="Ultimate Debugging Suite",TextColor3=Color3.new(1,1,1),TextSize=18,TextTransparency=1,}},
			{7,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="StatusText",Parent={3},Position=UDim2.new(0,20,0,110),Size=UDim2.new(0,180,0,25),Text="Fetching API",TextColor3=Color3.new(1,1,1),TextSize=14,TextTransparency=1,}},
			{8,"Frame",{BackgroundColor3=Color3.new(0.20392157137394,0.20392157137394,0.20392157137394),BorderSizePixel=0,Name="ProgressBar",Parent={3},Position=UDim2.new(0,110,0,145),Size=UDim2.new(0,0,0,4),}},
			{9,"Frame",{BackgroundColor3=Color3.new(0.2392156869173,0.56078433990479,0.86274510622025),BorderSizePixel=0,Name="Bar",Parent={8},Size=UDim2.new(0,0,1,0),}},
			{10,"ImageLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Image="rbxassetid://2764171053",ImageColor3=Color3.new(0.17647059261799,0.17647059261799,0.17647059261799),Parent={8},ScaleType=1,Size=UDim2.new(1,0,1,0),SliceCenter=Rect.new(2,2,254,254),}},
			{11,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="Creator",Parent={2},Position=UDim2.new(0,10,1,-20),Size=UDim2.new(1,-20,0,20),Text="Developed by Ahlstarr Mayijshan. Edited by Ahlstarr Mayjishan.",TextColor3=Color3.new(1,1,1),TextSize=11,TextXAlignment=1,}},
			{12,"UIGradient",{Parent={11},Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1,0),NumberSequenceKeypoint.new(1,1,0),}),}},
			{13,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="Version",Parent={2},Position=UDim2.new(1,-110,1,-35),Size=UDim2.new(0,105,0,20),Text=Main.Version,TextColor3=Color3.new(1,1,1),TextSize=14,TextXAlignment=1,}},
			{14,"UIGradient",{Parent={13},Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1,0),NumberSequenceKeypoint.new(1,1,0),}),}},
			{15,"ImageLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Image="rbxassetid://1427967925",Name="Outlines",Parent={2},Position=UDim2.new(0,-5,0,-5),ScaleType=1,Size=UDim2.new(1,10,1,10),SliceCenter=Rect.new(6,6,25,25),TileSize=UDim2.new(0,20,0,20),}},
			{16,"UIGradient",{Parent={15},Rotation=-30,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1,0),NumberSequenceKeypoint.new(1,1,0),}),}},
			{17,"UIGradient",{Parent={2},Rotation=-30,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1,0),NumberSequenceKeypoint.new(1,1,0),}),}},
			{18,"UIDragDetector", {Parent={2}}}
		})
		Main.ShowGui(gui)
		local backGradient = gui.Main.UIGradient
		local outlinesGradient = gui.Main.Outlines.UIGradient
		local holderGradient = gui.Main.Holder.UIGradient
		local titleText = gui.Main.Holder.Title
		local descText = gui.Main.Holder.Desc
		local versionText = gui.Main.Version
		local versionGradient = versionText.UIGradient
		local creatorText = gui.Main.Creator
		local creatorGradient = creatorText.UIGradient
		local statusText = gui.Main.Holder.StatusText
		local progressBar = gui.Main.Holder.ProgressBar
		local tweenS = service.TweenService

		local renderStepped = service.RunService.RenderStepped
		local signalWait = renderStepped.wait
		local fastwait = function(s)
			if not s then return signalWait(renderStepped) end
			local start = tick()
			while tick() - start < s do signalWait(renderStepped) end
		end

		statusText.Text = initStatus

		local function tweenNumber(n, ti, func)
			local tweenVal = Instance.new("IntValue")
			tweenVal.Value = 0
			tweenVal.Changed:Connect(func)
			local tween = tweenS:Create(tweenVal, ti, {Value = n})
			tween:Play()
			tween.Completed:Connect(function()
				tweenVal:Destroy()
			end)
		end

		local ti = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		tweenNumber(100, ti, function(val)
			val = val / 200
			local start = NumberSequenceKeypoint.new(0, 0)
			local a1 = NumberSequenceKeypoint.new(val, 0)
			local a2 = NumberSequenceKeypoint.new(math.min(0.5, val + math.min(0.05, val)), 1)
			if a1.Time == a2.Time then a2 = a1 end
			local b1 = NumberSequenceKeypoint.new(1 - val, 0)
			local b2 = NumberSequenceKeypoint.new(math.max(0.5, 1 - val - math.min(0.05, val)), 1)
			if b1.Time == b2.Time then b2 = b1 end
			local goal = NumberSequenceKeypoint.new(1, 0)
			backGradient.Transparency = NumberSequence.new({start, a1, a2, b2, b1, goal})
			outlinesGradient.Transparency = NumberSequence.new({start, a1, a2, b2, b1, goal})
		end)

		fastwait(0.4)

		tweenNumber(100, ti, function(val)
			val = val / 166.66
			local start = NumberSequenceKeypoint.new(0, 0)
			local a1 = NumberSequenceKeypoint.new(val, 0)
			local a2 = NumberSequenceKeypoint.new(val + 0.01, 1)
			local goal = NumberSequenceKeypoint.new(1, 1)
			holderGradient.Transparency = NumberSequence.new({start, a1, a2, goal})
		end)

		tweenS:Create(titleText, ti, {Position = UDim2.new(0, 60, 0, 15), TextTransparency = 0}):Play()
		tweenS:Create(descText, ti, {Position = UDim2.new(0, 20, 0, 60), TextTransparency = 0}):Play()

		local function rightTextTransparency(obj)
			tweenNumber(100, ti, function(val)
				val = val / 100
				local a1 = NumberSequenceKeypoint.new(1 - val, 0)
				local a2 = NumberSequenceKeypoint.new(math.max(0, 1 - val - 0.01), 1)
				if a1.Time == a2.Time then a2 = a1 end
				local start = NumberSequenceKeypoint.new(0, a1 == a2 and 0 or 1)
				local goal = NumberSequenceKeypoint.new(1, 0)
				obj.Transparency = NumberSequence.new({start, a2, a1, goal})
			end)
		end
		rightTextTransparency(versionGradient)
		rightTextTransparency(creatorGradient)

		fastwait(0.9)

		local progressTI = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		tweenS:Create(statusText, progressTI, {Position = UDim2.new(0, 20, 0, 120), TextTransparency = 0}):Play()
		tweenS:Create(progressBar, progressTI, {Position = UDim2.new(0, 60, 0, 145), Size = UDim2.new(0, 100, 0, 4)}):Play()

		fastwait(0.25)

		local function setProgress(text, n)
			statusText.Text = text
			tweenS:Create(progressBar.Bar, progressTI, {Size = UDim2.new(n, 0, 1, 0)}):Play()
		end

		local function close()
			tweenS:Create(titleText, progressTI, {TextTransparency = 1}):Play()
			tweenS:Create(descText, progressTI, {TextTransparency = 1}):Play()
			tweenS:Create(versionText, progressTI, {TextTransparency = 1}):Play()
			tweenS:Create(creatorText, progressTI, {TextTransparency = 1}):Play()
			tweenS:Create(statusText, progressTI, {TextTransparency = 1}):Play()
			tweenS:Create(progressBar, progressTI, {BackgroundTransparency = 1}):Play()
			tweenS:Create(progressBar.Bar, progressTI, {BackgroundTransparency = 1}):Play()
			tweenS:Create(progressBar.ImageLabel, progressTI, {ImageTransparency = 1}):Play()

			tweenNumber(100, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), function(val)
				val = val / 250
				local start = NumberSequenceKeypoint.new(0, 0)
				local a1 = NumberSequenceKeypoint.new(0.6 + val, 0)
				local a2 = NumberSequenceKeypoint.new(math.min(1, 0.601 + val), 1)
				if a1.Time == a2.Time then a2 = a1 end
				local goal = NumberSequenceKeypoint.new(1, a1 == a2 and 0 or 1)
				holderGradient.Transparency = NumberSequence.new({start, a1, a2, goal})
			end)

			fastwait(0.5)
			gui.Main.BackgroundTransparency = 1
			outlinesGradient.Rotation = 30

			tweenNumber(100, ti, function(val)
				val = val / 100
				local start = NumberSequenceKeypoint.new(0, 1)
				local a1 = NumberSequenceKeypoint.new(val, 1)
				local a2 = NumberSequenceKeypoint.new(math.min(1, val + math.min(0.05, val)), 0)
				if a1.Time == a2.Time then a2 = a1 end
				local goal = NumberSequenceKeypoint.new(1, a1 == a2 and 1 or 0)
				outlinesGradient.Transparency = NumberSequence.new({start, a1, a2, goal})
				holderGradient.Transparency = NumberSequence.new({start, a1, a2, goal})
			end)

			fastwait(0.45)
			gui:Destroy()
		end

		return {SetProgress = setProgress, Close = close, Object = gui}
	end
end

return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
