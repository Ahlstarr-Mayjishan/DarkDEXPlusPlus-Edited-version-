--!strict
--[[
	Lib Module
	
	Container for functions and classes
]]

-- CLI Mocks for unit tests
local Color3 = (Color3 :: any) or {
	fromRGB = function(r, g, b) return {r=r, g=g, b=b} end,
	new = function(r, g, b) return {r=r, g=g, b=b} end
}
local Vector2 = (Vector2 :: any) or {
	new = function(x, y) return {x=x, y=y} end
}
local UDim2 = (UDim2 :: any) or {
	fromScale = function(x, y) return {X = {Scale = x, Offset = 0}, Y = {Scale = y, Offset = 0}} end,
	fromOffset = function(x, y) return {X = {Scale = 0, Offset = x}, Y = {Scale = 0, Offset = y}} end,
	new = function(xs, xo, ys, yo) return {X = {Scale = xs, Offset = xo}, Y = {Scale = ys, Offset = yo}} end
}
local UDim = (UDim :: any) or {
	new = function(s, o) return {Scale = s, Offset = o} end
}
local Instance = (Instance :: any) or {
	new = function(className)
		return {
			TweenSize = function(...) end,
			GetChildren = function() return {} end,
			GetDescendants = function() return {} end,
		}
	end
}
local TweenInfo = (TweenInfo :: any) or {
	new = function(...) return {} end
}

-- Common Locals
local Main: any, Lib: any, Apps: any, Settings: any -- Main Containers
local Explorer: any, Properties: any, Notepad: any -- Major Apps
local API: any, RMD: any, env: any, service: any, plr: any, create: any, createSimple: any -- Main Locals

local function initDeps(data: any)
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

	local stateModule = Apps.State
	if stateModule then
		Lib.State = stateModule.new
		Lib.Computed = stateModule.Computed
		Lib.Bind = stateModule.Bind
	end
end

local function main()
	local Lib = {}
	Lib.create = create
	Lib.createSimple = createSimple

	local renderStepped = service.RunService.RenderStepped
	local signalWait = renderStepped.wait
	local PH = newproxy() -- Placeholder, must be replaced in constructor
	local SIGNAL = newproxy()

	-- Usually for classes that work with a Roblox Object
	local function initObj(props,mt)
		local type = type
		local function copy(t)
			local res = {}
			for i,v in pairs(t) do
				if v == SIGNAL then
					res[i] = Lib.Signal.new()
				elseif type(v) == "table" then
					res[i] = copy(v)
				else
					res[i] = v
				end
			end		
			return res
		end

		local newObj = copy(props)
		return setmetatable(newObj,mt)
	end

	local function getGuiMT(props,funcs)
		return {__index = function(self,ind) if not props[ind] then return funcs[ind] or self.Gui[ind] end end,
		__newindex = function(self,ind,val) if not props[ind] then self.Gui[ind] = val else rawset(self,ind,val) end end}
	end

	-- Functions

	Lib.FormatLuaString = (function()
		local string = string
		local gsub = string.gsub
		local format = string.format
		local char = string.char
		local cleanTable = {['"'] = '\\"', ['\\'] = '\\\\'}
		for i = 0,31 do
			cleanTable[char(i)] = "\\"..format("%03d",i)
		end
		for i = 127,255 do
			cleanTable[char(i)] = "\\"..format("%03d",i)
		end

		return function(str: string): string
			return gsub(str,"[\"\\\0-\31\127-\255]",cleanTable)
		end
	end)()

	Lib.getSafePath = function(obj: any): string
		if not obj then return "?" end
		if obj.Parent == nil then return "Nil parented" end
		local ok, path = pcall(function()
			if _G.Main and _G.Main.SafeGetInstancePath then return _G.Main.SafeGetInstancePath(obj) end
			if _G.Apps and _G.Apps.Explorer and _G.Apps.Explorer.GetInstancePath then return _G.Apps.Explorer.GetInstancePath(obj) end
			return obj:GetFullName()
		end)
		return ok and tostring(path) or tostring(obj)
	end

	Lib.CheckMouseInGui = function(gui: any): boolean
		if gui == nil then return false end
		
		-- Support SurfaceGui coordinates by raycasting to the Adornee part
		local surfaceGui = gui:FindFirstAncestorOfClass("SurfaceGui")
		if surfaceGui then
			local part = surfaceGui.Adornee or surfaceGui.Parent
			if part and part:IsA("BasePart") then
				local camera = workspace.CurrentCamera
				local pos = service.UserInputService:GetMouseLocation()
				local mouseRay = camera:ViewportPointToRay(pos.X, pos.Y)
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Include
				params.FilterDescendantsInstances = {part}
				params.IgnoreWater = true
				local result = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 1000, params)
				if result then
					return true
				end
			end
			return false
		end

		local mouse = Main.Mouse
		local guiPosition = gui.AbsolutePosition
		local guiSize = gui.AbsoluteSize	

		return mouse.X >= guiPosition.X and mouse.X < guiPosition.X + guiSize.X and mouse.Y >= guiPosition.Y and mouse.Y < guiPosition.Y + guiSize.Y
	end

	Lib.IsShiftDown = function(): boolean
		return service.UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or service.UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
	end

	Lib.IsCtrlDown = function(): boolean
		return service.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or service.UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
	end

	Lib.CreateArrow = function(size: number, num: number, dir: string): any
		local max = num
		local arrowFrame = createSimple("Frame",{
			BackgroundTransparency = 1,
			Name = "Arrow",
			Size = UDim2.new(0,size,0,size)
		})
		if dir == "up" then
			for i = 1,num do
				local newLine = createSimple("Frame",{
					BackgroundColor3 = Color3.new(220/255,220/255,220/255),
					BorderSizePixel = 0,
					Position = UDim2.new(0,math.floor(size/2)-(i-1),0,math.floor(size/2)+i-math.floor(max/2)-1),
					Size = UDim2.new(0,i+(i-1),0,1),
					Parent = arrowFrame
				})
			end
			return arrowFrame
		elseif dir == "down" then
			for i = 1,num do
				local newLine = createSimple("Frame",{
					BackgroundColor3 = Color3.new(220/255,220/255,220/255),
					BorderSizePixel = 0,
					Position = UDim2.new(0,math.floor(size/2)-(i-1),0,math.floor(size/2)-i+math.floor(max/2)+1),
					Size = UDim2.new(0,i+(i-1),0,1),
					Parent = arrowFrame
				})
			end
			return arrowFrame
		elseif dir == "left" then
			for i = 1,num do
				local newLine = createSimple("Frame",{
					BackgroundColor3 = Color3.new(220/255,220/255,220/255),
					BorderSizePixel = 0,
					Position = UDim2.new(0,math.floor(size/2)+i-math.floor(max/2)-1,0,math.floor(size/2)-(i-1)),
					Size = UDim2.new(0,1,0,i+(i-1)),
					Parent = arrowFrame
				})
			end
			return arrowFrame
		elseif dir == "right" then
			for i = 1,num do
				local newLine = createSimple("Frame",{
					BackgroundColor3 = Color3.new(220/255,220/255,220/255),
					BorderSizePixel = 0,
					Position = UDim2.new(0,math.floor(size/2)-i+math.floor(max/2)+1,0,math.floor(size/2)-(i-1)),
					Size = UDim2.new(0,1,0,i+(i-1)),
					Parent = arrowFrame
				})
			end
			return arrowFrame
		end
		error("r u ok")
	end

	Lib.ParseXML = (function()
		local func = function()
			-- Only exists to parse RMD
			-- from https://github.com/jonathanpoelen/xmlparser

			local string, print, pairs = string, print, pairs

			-- http://lua-users.org/wiki/StringTrim
			local trim = function(s)
				local from = s:match"^%s*()"
				return from > #s and "" or s:match(".*%S", from)
			end

			local gtchar = string.byte('>', 1)
			local slashchar = string.byte('/', 1)
			local D = string.byte('D', 1)
			local E = string.byte('E', 1)

			local parse: (s: string, evalEntities: boolean?) -> any
			function parse(s, evalEntities)
				-- remove comments
				s = s:gsub('<!%-%-(.-)%-%->', '')

				local entities, tentities = {}

				if evalEntities then
					local pos = s:find('<[_%w]')
					if pos then
						s:sub(1, pos):gsub('<!ENTITY%s+([_%w]+)%s+(.)(.-)%2', function(name, q, entity)
							entities[#entities+1] = {name=name, value=entity}
						end)
						tentities = createEntityTable(entities)
						s = replaceEntities(s:sub(pos), tentities)
					end
				end

				local t, l = {}, {}

				local addtext = function(txt)
					txt = txt:match'^%s*(.*%S)' or ''
					if #txt ~= 0 then
						t[#t+1] = {text=txt}
					end		
				end

				s:gsub('<([?!/]?)([-:_%w]+)%s*(/?>?)([^<]*)', function(type, name, closed, txt)
					-- open
					if #type == 0 then
						local a = {}
						if #closed == 0 then
							local len = 0
							for all,aname,_,value,starttxt in string.gmatch(txt, "(.-([-_%w]+)%s*=%s*(.)(.-)%3%s*(/?>?))") do
								len = len + #all
								a[aname] = value
								if #starttxt ~= 0 then
									txt = txt:sub(len+1)
									closed = starttxt
									break
								end
							end
						end
						t[#t+1] = {tag=name, attrs=a, children={}}

						if closed:byte(1) ~= slashchar then
							l[#l+1] = t
							t = t[#t].children
						end

						addtext(txt)
						-- close
					elseif '/' == type then
						t = l[#l]
						l[#l] = nil

						addtext(txt)
						-- ENTITY
					elseif '!' == type then
						if E == name:byte(1) then
							txt:gsub('([_%w]+)%s+(.)(.-)%2', function(name, q, entity)
								entities[#entities+1] = {name=name, value=entity}
							end, 1)
						end
						-- elseif '?' == type then
						--	 print('?	' .. name .. ' // ' .. attrs .. '$$')
						-- elseif '-' == type then
						--	 print('comment	' .. name .. ' // ' .. attrs .. '$$')
						-- else
						--	 print('o	' .. #p .. ' // ' .. name .. ' // ' .. attrs .. '$$')
					end
				end)

				return {children=t, entities=entities, tentities=tentities}
			end

			local function parseText(txt: string): any
				return parse(txt)
			end

			function defaultEntityTable()
				return { quot='"', apos='\'', lt='<', gt='>', amp='&', tab='\t', nbsp=' ', }
			end

			function replaceEntities(s, entities)
				return s:gsub('&([^;]+);', entities)
			end

			function createEntityTable(docEntities, resultEntities)
				entities = resultEntities or defaultEntityTable()
				for _,e in pairs(docEntities) do
					e.value = replaceEntities(e.value, entities)
					entities[e.name] = e.value
				end
				return entities
			end

			return parseText
		end
		local newEnv = setmetatable({},{__index = getfenv()})
		setfenv(func,newEnv)
		return func()
	end)()

	Lib.FastWait = function(s: number?)
		if not s then return signalWait(renderStepped) end
		local start = tick()
		while tick() - start < s do signalWait(renderStepped) end
	end

	Lib.ButtonAnim = function(button: any, data: any?): any
		local holding = false
		local disabled = false
		local mode = data and data.Mode or 1
		local control = {}

		if mode == 2 then
			local lerpTo = data.LerpTo or Color3.new(0,0,0)
			local delta = data.LerpDelta or 0.2
			control.StartColor = data.StartColor or button.BackgroundColor3
			control.PressColor = data.PressColor or control.StartColor:lerp(lerpTo,delta)
			control.HoverColor = data.HoverColor or control.StartColor:lerp(control.PressColor,0.6)
			control.OutlineColor = data.OutlineColor
		end

		button.InputBegan:Connect(function(input)
			if disabled then return end

			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				if not holding then
					if mode == 1 then
						button.BackgroundTransparency = 0.4
					elseif mode == 2 then
						button.BackgroundColor3 = control.HoverColor
					end
				end
			elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				holding = true
				if mode == 1 then
					button.BackgroundTransparency = 0
				elseif mode == 2 then
					button.BackgroundColor3 = control.PressColor
					if control.OutlineColor then button.BorderColor3 = control.PressColor end
				end
			end
		end)

		button.InputEnded:Connect(function(input)
			if disabled then return end

			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				if not holding then
					if mode == 1 then
						button.BackgroundTransparency = 1
					elseif mode == 2 then
						button.BackgroundColor3 = control.StartColor
					end
				end
			elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				holding = false
				if mode == 1 then
					button.BackgroundTransparency = Lib.CheckMouseInGui(button) and 0.4 or 1
				elseif mode == 2 then
					button.BackgroundColor3 = Lib.CheckMouseInGui(button) and control.HoverColor or control.StartColor
					if control.OutlineColor then button.BorderColor3 = control.OutlineColor end
				end
			end
		end)

		control.Disable = function()
			disabled = true
			holding = false

			if mode == 1 then
				button.BackgroundTransparency = 1
			elseif mode == 2 then
				button.BackgroundColor3 = control.StartColor
			end
		end

		control.Enable = function()
			disabled = false
		end

		return control
	end

	Lib.FindAndRemove = function(t: { any }, item: any)
		local pos = table.find(t,item)
		if pos then table.remove(t,pos) end
	end

	Lib.AttachTo = function(obj: any, data: any?): any
		local target,posOffX,posOffY,sizeOffX,sizeOffY,resize,con
		local disabled = false

		local function update()
			if not obj or not target then return end

			local targetPos = target.AbsolutePosition
			local targetSize = target.AbsoluteSize
			obj.Position = UDim2.new(0,targetPos.X + posOffX,0,targetPos.Y + posOffY)
			if resize then obj.Size = UDim2.new(0,targetSize.X + sizeOffX,0,targetSize.Y + sizeOffY) end
		end

		local function setup(o,data)
			obj = o
			data = data or {}
			target = data.Target
			posOffX = data.PosOffX or 0
			posOffY = data.PosOffY or 0
			sizeOffX = data.SizeOffX or 0
			sizeOffY = data.SizeOffY or 0
			resize = data.Resize or false

			if con then con:Disconnect() con = nil end
			if target then
				con = target.Changed:Connect(function(prop)
					if not disabled and prop == "AbsolutePosition" or prop == "AbsoluteSize" then
						update()
					end
				end)
			end

			update()
		end
		setup(obj,data)

		return {
			SetData = function(obj,data)
				setup(obj,data)
			end,
			Enable = function()
				disabled = false
				update()
			end,
			Disable = function()
				disabled = true
			end,
			Destroy = function()
				con:Disconnect()
				con = nil
			end,
		}
	end

	Lib.ProtectedGuis = {}

	Lib.ShowGui = Main.SecureGui

	Lib.applySafeAsset = function(uiElement: any, assetString: string)
		local assetId = string.match(assetString, "%d+")
		local customAssetFunc = getcustomasset or (env and env.getcustomasset)
		local writefile = env and env.writefile
		local isfile = env and env.isfile
		local isfolder = env and env.isfolder
		local makefolder = env and env.makefolder

		if not assetId or not writefile or not isfile or not isfolder or not makefolder or not customAssetFunc or not pcall(function() return game.HttpGet end) then
			uiElement.Image = assetString
			return
		end

		local cacheFolder = "DexPlusPlus_Assets"
		if not isfolder(cacheFolder) then
			pcall(makefolder, cacheFolder)
		end

		local filePath = cacheFolder .. "/icon_" .. assetId .. ".png"
		if isfile(filePath) then
			local success, customAsset = pcall(customAssetFunc, filePath)
			if success then
				uiElement.Image = customAsset
				return
			end
		end

		uiElement.Image = assetString
		task.spawn(function()
			local proxy = "https://roproxy.com/asset/?id=%s"
			local fetchUrl = string.format(proxy, assetId)
			local success, imageData = pcall(game.HttpGet, game, fetchUrl)
			if success and imageData and #imageData > 0 then
				local writeSuccess = pcall(writefile, filePath, imageData)
				if writeSuccess then
					local assetSuccess, customAsset = pcall(customAssetFunc, filePath)
					if assetSuccess then
						uiElement.Image = customAsset
					end
				end
			end
		end)
	end

	Lib.ColorToBytes = function(col: any): string
		local round = math.round
		return string.format("%d, %d, %d",round(col.r*255),round(col.g*255),round(col.b*255))
	end

	Lib.ReadFile = function(filename: string): string?
		if not env.readfile then return end

		local s,contents = pcall(env.readfile,filename)
		if s and contents then return contents end
	end

	Lib.DeferFunc = function(f: (...any) -> ...any, ...: any): any
		signalWait(renderStepped)
		return f(...)
	end

	Lib.LoadCustomAsset = function(filepath: string): string?
		if not env.getcustomasset or not env.isfile or not env.isfile(filepath) then return nil end

		return env.getcustomasset(filepath)
	end

	Lib.FetchCustomAsset = function(url: string, filepath: string): string?
		if not env.writefile then return end

		local data
		if oldgame and oldgame.HttpGet then
			local s, result = pcall(oldgame.HttpGet, game, url)
			if not s then return end
			data = result
		elseif env.HttpGet then
			local s, result = pcall(env.HttpGet, url)
			if not s then return end
			data = result
		else
			return
		end

		env.writefile(filepath,data)
		return Lib.LoadCustomAsset(filepath)
	end
	
	local currentfilename, currentextension, currentclickhandler
	currentclickhandler = function() end
	Lib.SaveAsPrompt = function(filename: string, codeToSave: any, ext: string?)		
		local win = Notepad.SaveAsWindow
		if not win then
			win = Lib.Window.new()
			win.Alignable = false
			win.Resizable = false
			win:SetTitle("Save As")
			win:SetSize(300,95)

			local saveButton = Lib.Button.new()
			local nameLabel = Lib.Label.new()
			nameLabel.Text = "Name"
			nameLabel.Position = UDim2.new(0,30,0,10)
			nameLabel.Size = UDim2.new(0,40,0,20)
			win:Add(nameLabel)

			local nameBox = Lib.ViewportTextBox.new()
			nameBox.Position = UDim2.new(0,75,0,10)
			nameBox.Size = UDim2.new(0,220,0,20)
			win:Add(nameBox,"NameBox")

			--nameBox.TextBox.Text = filename or ""

			nameBox.TextBox:GetPropertyChangedSignal("Text"):Connect(function()
				saveButton:SetDisabled(#nameBox:GetText() == 0)
			end)

			local errorLabel = Lib.Label.new()
			errorLabel.Text = ""
			errorLabel.Position = UDim2.new(0,5,1,-45)
			errorLabel.Size = UDim2.new(1,-10,0,20)
			errorLabel.TextColor3 = Settings.Theme.Important
			win.ErrorLabel = errorLabel
			win:Add(errorLabel,"Error")

			local cancelButton = Lib.Button.new()
			cancelButton.AnchorPoint = Vector2.new(1,1)
			cancelButton.Text = "Cancel"
			cancelButton.Position = UDim2.new(1,-5,1,-5)
			cancelButton.Size = UDim2.new(0.5,-10,0,20)
			cancelButton.OnClick:Connect(function()
				win:Close()
			end)
			win:Add(cancelButton)

			saveButton.Text = "Save"
			saveButton.AnchorPoint = Vector2.new(0,1)
			saveButton.Position = UDim2.new(0,5,1,-5)
			saveButton.Size = UDim2.new(0.5,-5,0,20)
			saveButton.OnClick:Connect(function()
				currentclickhandler()
			end)

			win:Add(saveButton,"SaveButton")

			Notepad.SaveAsWindow = win
		end

		currentclickhandler = function()
			if type(codeToSave) == "string" then
				filename = (win.Elements.NameBox.TextBox.Text ~= "" and win.Elements.NameBox.TextBox.Text) or filename
				currentextension = ext or filename:match("%.([^%.]+)$") or "txt"
				filename = filename:gsub("%.[^.]+$", "") .. "." .. currentextension

				local codeText = codeToSave or ""
				if env.writefile then
					local s, msg = pcall(env.writefile, filename, codeText)
					if not s then
						win.Elements.Error.Text = "Error: " .. msg
						task.spawn(error, msg)
						task.wait(1)
					end
				else
					win.Elements.Error.Text = "Your executor does not support 'writefile'"
					task.wait(1)
				end
			elseif type(codeToSave) == "function" then
				filename = (win.Elements.NameBox.TextBox.Text ~= "" and win.Elements.NameBox.TextBox.Text) or filename
				currentextension = ext or filename:match("%.([^%.]+)$") or "txt"
				filename = filename:gsub("%.[^.]+$", "") .. "." .. currentextension

				local s, msg = pcall(codeToSave,filename) -- callback
				if not s then
					win.Elements.Error.Text = "Error: " .. msg
					task.spawn(error, msg)
					Lib.FastWait(1)
				end
			end
			win:Close()
		end

		win:SetTitle("Save As")
		win.Elements.Error.Text = ""
		win.Elements.NameBox:SetText(filename or "")
		
		win.Elements.SaveButton:SetDisabled(win.Elements.NameBox:GetText() == 0)
		
		win:Show()
	end
	
	-- Classes

	-- Signal + Set live in Modules/Core/Lib/SignalSet.luau (merged at build time)
	
	Lib.IconMap = (function()
		local funcs = {}
		local IconList = Apps.IconData
		if Settings.ClassIcon and IconList[Settings.ClassIcon] then
			funcs.ExplorerIcons = {
				["MapId"] = IconList[Settings.ClassIcon].MapId,
				["Icons"] = IconList[Settings.ClassIcon].Icons,
				["IconSize"] = IconList[Settings.ClassIcon].IconSize,
				["Witdh"] = IconList[Settings.ClassIcon].Witdh,
				["Height"] = IconList[Settings.ClassIcon].Height}
		else
			funcs.ExplorerIcons = { ["MapId"] = IconList.Old.MapId, ["Icons"] = IconList.Old.Icons, ["IconSize"] = IconList.Old.IconSize }
		end
		
		

		funcs.GetLabel = function(self)
			local label = Instance.new("ImageLabel")
			self:SetupLabel(label)
			return label
		end

		funcs.SetupLabel = function(self,obj)
			obj.BackgroundTransparency = 1
			obj.ImageRectOffset = Vector2.new(0, 0)
			obj.ImageRectSize = Vector2.new(self.IconSizeX, self.IconSizeY)
			obj.ScaleType = Enum.ScaleType.Crop
			obj.Size = UDim2.new(0, self.IconSizeX, 0, self.IconSizeY)
		end

		funcs.Display = function(self,obj,index)
			obj.Image = self.MapId
			obj.ImageRectSize = Vector2.new(self.IconSizeX, self.IconSizeY)
			if not self.NumX then
				obj.ImageRectOffset = Vector2.new(self.IconSizeX*index, 0)
			else
				obj.ImageRectOffset = Vector2.new(self.IconSizeX*(index % self.NumX), self.IconSizeY*math.floor(index / self.NumX))
			end
		end

		funcs.DisplayByKey = function(self, obj, key)
			if self.IndexDict[key] then
				self:Display(obj, self.IndexDict[key])
			else
				local rmdEntry = RMD.Classes[obj.ClassName]
				local explorerApp = Apps.Explorer or Explorer
				if explorerApp and explorerApp.ClassIcons then
					explorerApp.ClassIcons:Display(obj, rmdEntry and rmdEntry.ExplorerImageIndex or 0)
				end
			end
		end

		funcs.IconDehash = function(self, _id)
			return math.floor(_id / 14 % 14), math.floor(_id % 14)
		end
		
		local ClassNameNoImage = {}
		funcs.GetExplorerIcon = function(self, obj, index)
			if Settings.ClassIcon == "Vanilla3" then
				obj.Size = UDim2.fromOffset(16, 16)

				index = (self.ExplorerIcons.Icons[index] or 250) - 1
				obj.ImageRectOffset = Vector2.new(funcs.ExplorerIcons.IconSize * (index % funcs.ExplorerIcons.Height), funcs.ExplorerIcons.IconSize * math.floor(index / funcs.ExplorerIcons.Height))
				obj.ImageRectSize = Vector2.new(funcs.ExplorerIcons.IconSize, funcs.ExplorerIcons.IconSize)
			elseif Settings.ClassIcon == "NewLight" or Settings.ClassIcon == "NewDark" then
				local isService = string.find(index, "Service") and game:GetService(index)
				
				obj.Size = UDim2.fromOffset(16, 16)
				index = (self.ExplorerIcons.Icons[index] or (isService and self.ExplorerIcons.Icons.Service) or self.ExplorerIcons.Icons.Placeholder) - 1
				obj.ImageRectOffset = Vector2.new(funcs.ExplorerIcons.IconSize * (index % funcs.ExplorerIcons.Height), funcs.ExplorerIcons.IconSize * math.floor(index / funcs.ExplorerIcons.Height))
				obj.ImageRectSize = Vector2.new(funcs.ExplorerIcons.IconSize, funcs.ExplorerIcons.IconSize)
			else
				index = (self.ExplorerIcons.Icons[index] or 0)
				local row, col = self:IconDehash(index)
				local MapSize = Vector2.new(256, 256)
				local pad, border = 2, 1

				obj.Position = UDim2.new(-col - (pad * (col + 1) + border) / funcs.ExplorerIcons.IconSize, 0, -row - (pad * (row + 1) + border) / funcs.ExplorerIcons.IconSize, 0)
				obj.Size = UDim2.new(MapSize.X / funcs.ExplorerIcons.IconSize, 0, MapSize.Y / funcs.ExplorerIcons.IconSize, 0)
			end
			
		end

		funcs.DisplayExplorerIcons = function(self, Frame, index)
			if Frame:FindFirstChild("IconMap") then
				self:GetExplorerIcon(Frame.IconMap, index)
			else
				Frame.ClipsDescendants = true

				local obj = Instance.new("ImageLabel", Frame)
				obj.BackgroundTransparency = 1
				obj.Image = ("http://www.roblox.com/asset/?id=" .. (self.ExplorerIcons.MapId))
				obj.Name = "IconMap"
				self:GetExplorerIcon(obj, index)
			end
		end

		funcs.SetDict = function(self,dict)
			self.IndexDict = dict
		end

		local mt = {}
		mt.__index = funcs

		local function new(mapId,mapSizeX,mapSizeY,iconSizeX,iconSizeY)
			local obj = setmetatable({
				MapId = mapId,
				MapSizeX = mapSizeX,
				MapSizeY = mapSizeY,
				IconSizeX = iconSizeX,
				IconSizeY = iconSizeY,
				NumX = mapSizeX/iconSizeX,
				IndexDict = {}
			}, mt)
			return obj
		end

		local function newLinear(mapId,iconSizeX,iconSizeY)
			local obj = setmetatable({
				MapId = mapId,
				IconSizeX = iconSizeX,
				IconSizeY = iconSizeY,
				IndexDict = {}
			},mt)
			return obj
		end
		
		local function getIconDataFromName(name)
			return IconList[name] or error("Name not found")
		end

		return {new = new, newLinear = newLinear, getIconDataFromName = getIconDataFromName}
	end)()

	-- ScrollBar lives in Modules/Core/Lib/ScrollBar.luau (merged at build time)

	-- Window lives in Modules/Core/Lib/Window.luau (merged at build time)

	-- ContextMenu lives in Modules/Core/Lib/ContextMenu.luau (merged at build time)


	-- Checkbox lives in Modules/Core/LibParts/Checkbox.luau (merged at build time)

	-- ColorPicker lives in Modules/Core/LibParts/ColorPicker.luau (merged at build time)

	-- SequenceEditors lives in Modules/Core/LibParts/SequenceEditors.luau (merged at build time)

	-- BasicUI lives in Modules/Core/LibParts/BasicUI.luau (merged at build time)

	-- DropDown lives in Modules/Core/LibParts/DropDown.luau (merged at build time)

	-- ClickSystem lives in Modules/Core/LibParts/ClickSystem.luau (merged at build time)

	Lib.GetDescendantsParallel = function(root: any): { any }
		local descs = {}
		local ok = pcall(function()
			task.desynchronize()
			descs = root:GetDescendants()
			task.synchronize()
		end)
		if not ok then
			descs = root:GetDescendants()
		end
		return descs
	end

	return Lib
end

return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
