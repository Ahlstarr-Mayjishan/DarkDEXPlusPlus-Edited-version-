--[[
	Notepad App Module
	
	A script viewer that is basically a notepad
]]
-- Common Locals
local Main,Lib,Apps,Settings -- Main Containers
local Explorer, Properties, Notepad, SmartDecompiler -- Major Apps
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
	SmartDecompiler = Apps.SmartDecompiler
end

local executorName = "Unknown"
local executorVersion = "???"
if identifyexecutor then
	local name,ver = identifyexecutor()
	executorName = name
	executorVersion = ver
elseif game:GetService("RunService"):IsStudio() then
	executorName = "Studio"
	executorVersion = version()
end

local function getPath(obj)
    return Lib.getSafePath(obj)
end

local function main()
	local searchBox, searchStatus
	local CodeFrame = (function()
			local funcs = {}

			local typeMap = {
				[1] = "String",
				[2] = "String",
				[3] = "String",
				[4] = "Comment",
				[5] = "Operator",
				[6] = "Number",
				[7] = "Keyword",
				[8] = "BuiltIn",
				[9] = "LocalMethod",
				[10] = "LocalProperty",
				[11] = "Nil",
				[12] = "Bool",
				[13] = "Function",
				[14] = "Local",
				[15] = "Self",
				[16] = "FunctionName",
				[17] = "Bracket"
			}

			local specialKeywordsTypes = {
				["nil"] = 11,
				["true"] = 12,
				["false"] = 12,
				["function"] = 13,
				["local"] = 14,
				["self"] = 15
			}

			local keywords = {
				["and"] = true,
				["break"] = true, 
				["do"] = true,
				["else"] = true,
				["elseif"] = true,
				["end"] = true,
				["false"] = true,
				["for"] = true,
				["function"] = true,
				["if"] = true,
				["in"] = true,
				["local"] = true,
				["nil"] = true,
				["not"] = true,
				["or"] = true,
				["repeat"] = true,
				["return"] = true,
				["then"] = true,
				["true"] = true,
				["until"] = true,
				["while"] = true,
				["plugin"] = true
			}

			local builtIns = {
				["delay"] = true,
				["elapsedTime"] = true,
				["require"] = true,
				["spawn"] = true,
				["tick"] = true,
				["time"] = true,
				["typeof"] = true,
				["UserSettings"] = true,
				["wait"] = true,
				["warn"] = true,
				["game"] = true,
				["shared"] = true,
				["script"] = true,
				["workspace"] = true,
				["assert"] = true,
				["collectgarbage"] = true,
				["error"] = true,
				["getfenv"] = true,
				["getmetatable"] = true,
				["ipairs"] = true,
				["loadstring"] = true,
				["newproxy"] = true,
				["next"] = true,
				["pairs"] = true,
				["pcall"] = true,
				["print"] = true,
				["rawequal"] = true,
				["rawget"] = true,
				["rawset"] = true,
				["select"] = true,
				["setfenv"] = true,
				["setmetatable"] = true,
				["tonumber"] = true,
				["tostring"] = true,
				["type"] = true,
				["unpack"] = true,
				["xpcall"] = true,
				["_G"] = true,
				["_VERSION"] = true,
				["coroutine"] = true,
				["debug"] = true,
				["math"] = true,
				["os"] = true,
				["string"] = true,
				["table"] = true,
				["bit32"] = true,
				["utf8"] = true,
				["Axes"] = true,
				["BrickColor"] = true,
				["CFrame"] = true,
				["Color3"] = true,
				["ColorSequence"] = true,
				["ColorSequenceKeypoint"] = true,
				["DockWidgetPluginGuiInfo"] = true,
				["Enum"] = true,
				["Faces"] = true,
				["Instance"] = true,
				["NumberRange"] = true,
				["NumberSequence"] = true,
				["NumberSequenceKeypoint"] = true,
				["PathWaypoint"] = true,
				["PhysicalProperties"] = true,
				["Random"] = true,
				["Ray"] = true,
				["Rect"] = true,
				["Region3"] = true,
				["Region3int16"] = true,
				["TweenInfo"] = true,
				["UDim"] = true,
				["UDim2"] = true,
				["Vector2"] = true,
				["Vector2int16"] = true,
				["Vector3"] = true,
				["Vector3int16"] = true,

				["getgenv"] = true,
				["getrenv"] = true,
				["getsenv"] = true,
				["getgc"] = true,
				["getreg"] = true,
				["filtergc"] = true,
				["saveinstave"] = true,
				["decompile"] = true,
				["syn"] = true,
				["getupvalue"] = true,
				["getupvalues"] = true,
				["setupvalue"] = true,
				["getstack"] = true,
				["setstack"] = true,
				["getconstants"] = true,
				["getconstant"] = true,
				["setconstant"] = true,
				["getproto"] = true,
				["getprotos"] = true,
				["checkcaller"] = true,
				["clonefunction"] = true,
				["cloneref"] = true,
				["getfunctionhash"] = true,
				["gethwid"] = true,
				["hookfunction"] = true,
				["hookmetamethod"] = true,
				["iscclosure"] = true,
				["islclosure"] = true,
				["newcclosure"] = true,
				["isexecutorclosure"] = true,
				["restorefunction"] = true,
				["crypt"] = true,
				["Drawing"] = true,

			}

			local builtInInited = false

			local richReplace = {
				["'"] = "&apos;",
				["\""] = "&quot;",
				["<"] = "&lt;",
				[">"] = "&gt;",
				["&"] = "&amp;"
			}

			local tabSub = "\205"
			local tabReplacement = (" %s%s "):format(tabSub,tabSub)

			local tabJumps = {
				[("[^%s] %s"):format(tabSub,tabSub)] = 0,
				[(" %s%s"):format(tabSub,tabSub)] = -1,
				[("%s%s "):format(tabSub,tabSub)] = 2,
				[("%s [^%s]"):format(tabSub,tabSub)] = 1,
			}

			local tweenService = service.TweenService
			local lineTweens = {}

			local function initBuiltIn()
				local env = getfenv()
				local type = type
				local tostring = tostring
				for name,_ in next,builtIns do
					local envVal = env[name]
					if type(envVal) == "table" then
						local items = {}
						for i,v in next,envVal do
							items[i] = true
						end
						builtIns[name] = items
					end
				end

				local enumEntries = {}
				local enums = Enum:GetEnums()
				for i = 1,#enums do
					enumEntries[tostring(enums[i])] = true
				end
				builtIns["Enum"] = enumEntries

				builtInInited = true
			end

			local function setupEditBox(obj)
				local editBox = obj.GuiElems.EditBox

				editBox.Focused:Connect(function()
					obj:ConnectEditBoxEvent()
					obj.Editing = true
				end)

				editBox.FocusLost:Connect(function()
					obj:DisconnectEditBoxEvent()
					obj.Editing = false
				end)

				editBox:GetPropertyChangedSignal("Text"):Connect(function()
					local text = editBox.Text
					if #text == 0 or obj.EditBoxCopying then return end
					editBox.Text = ""
					obj:AppendText(text)
				end)
			end

			local function setupMouseSelection(obj)
				local mouse = plr:GetMouse()
				local codeFrame = obj.GuiElems.LinesFrame
				local lines = obj.Lines

				codeFrame.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						local fontSizeX,fontSizeY = math.ceil(obj.FontSize/2),obj.FontSize

						local relX = mouse.X - codeFrame.AbsolutePosition.X
						local relY = mouse.Y - codeFrame.AbsolutePosition.Y
						local selX = math.round(relX / fontSizeX) + obj.ViewX
						local selY = math.floor(relY / fontSizeY) + obj.ViewY
						local releaseEvent,mouseEvent,scrollEvent
						local scrollPowerV,scrollPowerH = 0,0
						selY = math.min(#lines-1,selY)
						local relativeLine = lines[selY+1] or ""
						selX = math.min(#relativeLine, selX + obj:TabAdjust(selX,selY))

						obj.SelectionRange = {{-1,-1},{-1,-1}}
						if obj.OnSelectionChanged then obj.OnSelectionChanged:Fire("") end
						obj:MoveCursor(selX,selY)
						obj.FloatCursorX = selX

						local function updateSelection()
							local relX = mouse.X - codeFrame.AbsolutePosition.X
							local relY = mouse.Y - codeFrame.AbsolutePosition.Y
							local sel2X = math.max(0,math.round(relX / fontSizeX) + obj.ViewX)
							local sel2Y = math.max(0,math.floor(relY / fontSizeY) + obj.ViewY)

							sel2Y = math.min(#lines-1,sel2Y)
							local relativeLine = lines[sel2Y+1] or ""
							sel2X = math.min(#relativeLine, sel2X + obj:TabAdjust(sel2X,sel2Y))

							if sel2Y < selY or (sel2Y == selY and sel2X < selX) then
								obj.SelectionRange = {{sel2X,sel2Y},{selX,selY}}
							else						
								obj.SelectionRange = {{selX,selY},{sel2X,sel2Y}}
							end

							obj:MoveCursor(sel2X,sel2Y)
							obj.FloatCursorX = sel2X
							if obj.OnSelectionChanged then obj.OnSelectionChanged:Fire(obj:GetSelectionText()) end
							obj:Refresh()
						end

						releaseEvent = service.UserInputService.InputEnded:Connect(function(input)
							if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
								releaseEvent:Disconnect()
								mouseEvent:Disconnect()
								scrollEvent:Disconnect()
								obj:SetCopyableSelection()
								if obj.OnSelectionChanged then obj.OnSelectionChanged:Fire(obj:GetSelectionText()) end
								if obj.OnSelectionFinished then obj.OnSelectionFinished:Fire(obj:GetSelectionText(), mouse.X, mouse.Y) end
								--updateSelection()
							end
						end)

						mouseEvent = service.UserInputService.InputChanged:Connect(function(input)
							if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
								local upDelta = mouse.Y - codeFrame.AbsolutePosition.Y
								local downDelta = mouse.Y - codeFrame.AbsolutePosition.Y - codeFrame.AbsoluteSize.Y
								local leftDelta = mouse.X - codeFrame.AbsolutePosition.X
								local rightDelta = mouse.X - codeFrame.AbsolutePosition.X - codeFrame.AbsoluteSize.X
								scrollPowerV = 0
								scrollPowerH = 0
								if downDelta > 0 then
									scrollPowerV = math.floor(downDelta*0.05) + 1
								elseif upDelta < 0 then
									scrollPowerV = math.ceil(upDelta*0.05) - 1
								end
								if rightDelta > 0 then
									scrollPowerH = math.floor(rightDelta*0.05) + 1
								elseif leftDelta < 0 then
									scrollPowerH = math.ceil(leftDelta*0.05) - 1
								end
								updateSelection()
							end
						end)

						scrollEvent = game:GetService("RunService").RenderStepped:Connect(function()
							if scrollPowerV ~= 0 or scrollPowerH ~= 0 then
								obj:ScrollDelta(scrollPowerH,scrollPowerV)
								updateSelection()
							end
						end)

						obj:Refresh()
					end
				end)
			end

			local function makeFrame(obj)
				local frame = create({
					{1,"Frame",{BackgroundColor3=Color3.new(0.15686275064945,0.15686275064945,0.15686275064945),BorderSizePixel = 0,Position=UDim2.new(0.5,-300,0.5,-200),Size=UDim2.new(0,600,0,400),}},
				})

				if Settings.Window.Transparency and Settings.Window.Transparency > 0 then
					frame.BackgroundTransparency = 0.5
				end

				local elems = {}

				local linesFrame = Instance.new("Frame")
				linesFrame.Name = "Lines"
				linesFrame.BackgroundTransparency = 1
				linesFrame.Size = UDim2.new(1,0,1,0)
				linesFrame.ClipsDescendants = true
				linesFrame.Parent = frame

				local lineNumbersLabel = Instance.new("TextLabel")
				lineNumbersLabel.Name = "LineNumbers"
				lineNumbersLabel.BackgroundTransparency = 1
				lineNumbersLabel.Font = Enum.Font.Code
				lineNumbersLabel.TextXAlignment = Enum.TextXAlignment.Right
				lineNumbersLabel.TextYAlignment = Enum.TextYAlignment.Top
				lineNumbersLabel.ClipsDescendants = true
				lineNumbersLabel.RichText = true
				lineNumbersLabel.Parent = frame

				local cursor = Instance.new("Frame")
				cursor.Name = "Cursor"
				cursor.BackgroundColor3 = Color3.fromRGB(220,220,220)
				cursor.BorderSizePixel = 0
				cursor.Parent = frame

				local editBox = Instance.new("TextBox")
				editBox.Name = "EditBox"
				editBox.MultiLine = true
				editBox.Visible = true
				editBox.BackgroundTransparency = 1
				editBox.TextTransparency = 1
				editBox.TextColor3 = Color3.new(1,1,1)
				editBox.BorderSizePixel = 0
				editBox.ClearTextOnFocus = false
				editBox.Position = UDim2.new(0,0,0,0)
				editBox.Size = UDim2.new(0,1,0,1)
				editBox.ZIndex = 0
				editBox.Parent = frame

				lineTweens.Invis = tweenService:Create(cursor,TweenInfo.new(0.4,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{BackgroundTransparency = 1})
				lineTweens.Vis = tweenService:Create(cursor,TweenInfo.new(0.2,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{BackgroundTransparency = 0})

				elems.LinesFrame = linesFrame
				elems.LineNumbersLabel = lineNumbersLabel
				elems.Cursor = cursor
				elems.EditBox = editBox
				elems.ScrollCorner = create({{1,"Frame",{BackgroundColor3=Color3.new(0.15686275064945,0.15686275064945,0.15686275064945),BorderSizePixel=0,Name="ScrollCorner",Position=UDim2.new(1,-16,1,-16),Size=UDim2.new(0,16,0,16),Visible=false,}}})

				elems.ScrollCorner.Parent = frame
				linesFrame.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						obj:SetEditing(true,input)
					elseif input.UserInputType == Enum.UserInputType.MouseButton2 and obj.OnRightClick then
						obj.OnRightClick:Fire(input.Position.X, input.Position.Y)
					end
				end)

				obj.Frame = frame
				obj.Gui = frame
				obj.GuiElems = elems
				setupEditBox(obj)
				setupMouseSelection(obj)

				return frame
			end

			funcs.GetSelectionText = function(self)
				if not self:IsValidRange() then return "" end

				local selectionRange = self.SelectionRange
				local selX,selY = selectionRange[1][1], selectionRange[1][2]
				local sel2X,sel2Y = selectionRange[2][1], selectionRange[2][2]
				local deltaLines = sel2Y-selY
				local lines = self.Lines

				if not lines[selY+1] or not lines[sel2Y+1] then return "" end

				if deltaLines == 0 then
					return self:ConvertText(lines[selY+1]:sub(selX+1,sel2X), false)
				end

				local leftSub = lines[selY+1]:sub(selX+1)
				local rightSub = lines[sel2Y+1]:sub(1,sel2X)

				local result = leftSub.."\n" 
				for i = selY+1,sel2Y-1 do
					result = result..lines[i+1].."\n"
				end
				result = result..rightSub

				return self:ConvertText(result,false)
			end

			funcs.SetCopyableSelection = function(self)
				local text = self:GetSelectionText()
				local editBox = self.GuiElems.EditBox

				self.EditBoxCopying = true
				editBox.Text = text
				editBox.SelectionStart = 1
				editBox.CursorPosition = #editBox.Text + 1
				if #text > 0 and not (searchBox and searchBox:IsFocused()) then
					editBox:CaptureFocus()
				end
				task.defer(function()
					self.EditBoxCopying = false
				end)
				if self.OnSelectionChanged then self.OnSelectionChanged:Fire(text) end
			end

			funcs.ConnectEditBoxEvent = function(self)
				if self.EditBoxEvent then
					self.EditBoxEvent:Disconnect()
				end

				self.EditBoxEvent = service.UserInputService.InputBegan:Connect(function(input)
					if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

					local keycodes = Enum.KeyCode
					local keycode = input.KeyCode

					local function setupMove(key,func)
						local endCon,finished
						endCon = service.UserInputService.InputEnded:Connect(function(input)
							if input.KeyCode ~= key then return end
							endCon:Disconnect()
							finished = true
						end)
						func()
						Lib.FastWait(0.5)
						while not finished do func() Lib.FastWait(0.03) end
					end

					if keycode == keycodes.Down then
						setupMove(keycodes.Down,function()
							self.CursorX = self.FloatCursorX
							self.CursorY = self.CursorY + 1
							self:UpdateCursor()
							self:JumpToCursor()
						end)
					elseif keycode == keycodes.Up then
						setupMove(keycodes.Up,function()
							self.CursorX = self.FloatCursorX
							self.CursorY = self.CursorY - 1
							self:UpdateCursor()
							self:JumpToCursor()
						end)
					elseif keycode == keycodes.Left then
						setupMove(keycodes.Left,function()
							local line = self.Lines[self.CursorY+1] or ""
							self.CursorX = self.CursorX - 1 - (line:sub(self.CursorX-3,self.CursorX) == tabReplacement and 3 or 0)
							if self.CursorX < 0 then
								self.CursorY = self.CursorY - 1
								local line2 = self.Lines[self.CursorY+1] or ""
								self.CursorX = #line2
							end
							self.FloatCursorX = self.CursorX
							self:UpdateCursor()
							self:JumpToCursor()
						end)
					elseif keycode == keycodes.Right then
						setupMove(keycodes.Right,function()
							local line = self.Lines[self.CursorY+1] or ""
							self.CursorX = self.CursorX + 1 + (line:sub(self.CursorX+1,self.CursorX+4) == tabReplacement and 3 or 0)
							if self.CursorX > #line then
								self.CursorY = self.CursorY + 1
								self.CursorX = 0
							end
							self.FloatCursorX = self.CursorX
							self:UpdateCursor()
							self:JumpToCursor()
						end)
					elseif keycode == keycodes.Backspace then
						setupMove(keycodes.Backspace,function()
							local startRange,endRange
							if self:IsValidRange() then
								startRange = self.SelectionRange[1]
								endRange = self.SelectionRange[2]
							else
								endRange = {self.CursorX,self.CursorY}
							end

							if not startRange then
								local line = self.Lines[self.CursorY+1] or ""
								self.CursorX = self.CursorX - 1 - (line:sub(self.CursorX-3,self.CursorX) == tabReplacement and 3 or 0)
								if self.CursorX < 0 then
									self.CursorY = self.CursorY - 1
									local line2 = self.Lines[self.CursorY+1] or ""
									self.CursorX = #line2
								end
								self.FloatCursorX = self.CursorX
								self:UpdateCursor()

								startRange = startRange or {self.CursorX,self.CursorY}
							end

							self:DeleteRange({startRange,endRange},false,true)
							self:ResetSelection(true)
							self:JumpToCursor()
						end)
					elseif keycode == keycodes.Delete then
						setupMove(keycodes.Delete,function()
							local startRange,endRange
							if self:IsValidRange() then
								startRange = self.SelectionRange[1]
								endRange = self.SelectionRange[2]
							else
								startRange = {self.CursorX,self.CursorY}
							end

							if not endRange then
								local line = self.Lines[self.CursorY+1] or ""
								local endCursorX = self.CursorX + 1 + (line:sub(self.CursorX+1,self.CursorX+4) == tabReplacement and 3 or 0)
								local endCursorY = self.CursorY
								if endCursorX > #line then
									endCursorY = endCursorY + 1
									endCursorX = 0
								end
								self:UpdateCursor()

								endRange = endRange or {endCursorX,endCursorY}
							end

							self:DeleteRange({startRange,endRange},false,true)
							self:ResetSelection(true)
							self:JumpToCursor()
						end)
					elseif service.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
						if keycode == keycodes.A then
							self.SelectionRange = {{0,0},{#self.Lines[#self.Lines],#self.Lines-1}}
							self:SetCopyableSelection()
							self:Refresh()
						end
					end
				end)
			end

			funcs.DisconnectEditBoxEvent = function(self)
				if self.EditBoxEvent then
					self.EditBoxEvent:Disconnect()
				end
			end

			funcs.ResetSelection = function(self,norefresh)
				self.SelectionRange = {{-1,-1},{-1,-1}}
				if self.OnSelectionChanged then self.OnSelectionChanged:Fire("") end
				if not norefresh then self:Refresh() end
			end

			funcs.IsValidRange = function(self,range)
				local selectionRange = range or self.SelectionRange
				local selX,selY = selectionRange[1][1], selectionRange[1][2]
				local sel2X,sel2Y = selectionRange[2][1], selectionRange[2][2]

				if selX == -1 or (selX == sel2X and selY == sel2Y) then return false end

				return true
			end

			funcs.DeleteRange = function(self,range,noprocess,updatemouse)
				range = range or self.SelectionRange
				if not self:IsValidRange(range) then return end

				local lines = self.Lines
				local selX,selY = range[1][1], range[1][2]
				local sel2X,sel2Y = range[2][1], range[2][2]
				local deltaLines = sel2Y-selY

				if not lines[selY+1] or not lines[sel2Y+1] then return end

				local leftSub = lines[selY+1]:sub(1,selX)
				local rightSub = lines[sel2Y+1]:sub(sel2X+1)
				lines[selY+1] = leftSub..rightSub

				local remove = table.remove
				for i = 1,deltaLines do
					remove(lines,selY+2)
				end

				local deletingSelection = range == self.SelectionRange
				if deletingSelection then
					self.SelectionRange = {{-1,-1},{-1,-1}}
					if self.OnSelectionChanged then self.OnSelectionChanged:Fire("") end
				end
				if updatemouse then
					self.CursorX = selX
					self.CursorY = selY
					self:UpdateCursor()
				end

				if not noprocess then
					self:ProcessTextChange()
				end
			end

			funcs.AppendText = function(self,text)
				self:DeleteRange(nil,true,true)
				local lines,cursorX,cursorY = self.Lines,self.CursorX,self.CursorY
				local line = lines[cursorY+1]
				local before = line:sub(1,cursorX)
				local after = line:sub(cursorX+1)

				text = text:gsub("\r\n","\n")
				text = self:ConvertText(text,true) -- Tab Convert

				local textLines = text:split("\n")
				local insert = table.insert

				for i = 1,#textLines do
					local linePos = cursorY+i
					if i > 1 then insert(lines,linePos,"") end

					local textLine = textLines[i]
					local newBefore = (i == 1 and before or "")
					local newAfter = (i == #textLines and after or "")

					lines[linePos] = newBefore..textLine..newAfter
				end

				if #textLines > 1 then cursorX = 0 end

				self:ProcessTextChange()
				self.CursorX = cursorX + #textLines[#textLines]
				self.CursorY = cursorY + #textLines-1
				self:UpdateCursor()
			end

			funcs.ScrollDelta = function(self,x,y)
				self.ScrollV:ScrollTo(self.ScrollV.Index + y)
				self.ScrollH:ScrollTo(self.ScrollH.Index + x)
			end

			-- x and y starts at 0
			funcs.TabAdjust = function(self,x,y)
				local lines = self.Lines
				local line = lines[y+1]
				x=x+1

				if line then
					local left = line:sub(x-1,x-1)
					local middle = line:sub(x,x)
					local right = line:sub(x+1,x+1)
					local selRange = (#left > 0 and left or " ") .. (#middle > 0 and middle or " ") .. (#right > 0 and right or " ")

					for i,v in pairs(tabJumps) do
						if selRange:find(i) then
							return v
						end
					end
				end
				return 0
			end

			funcs.SetEditing = function(self,on,input)			
				self:UpdateCursor(input)

				if on then
					if self.Editable then
						self.GuiElems.EditBox.Text = ""
						self.GuiElems.EditBox:CaptureFocus()
					end
				else
					self.GuiElems.EditBox:ReleaseFocus()
				end
			end

			funcs.CursorAnim = function(self,on)
				local cursor = self.GuiElems.Cursor
				local animTime = tick()
				self.LastAnimTime = animTime

				if not on then return end

				lineTweens.Invis:Cancel()
				lineTweens.Vis:Cancel()
				cursor.BackgroundTransparency = 0

				coroutine.wrap(function()
					while self.Editable do
						Lib.FastWait(0.5)
						if self.LastAnimTime ~= animTime then return end
						lineTweens.Invis:Play()
						Lib.FastWait(0.4)
						if self.LastAnimTime ~= animTime then return end
						lineTweens.Vis:Play()
						Lib.FastWait(0.2)
					end
				end)()
			end

			funcs.MoveCursor = function(self,x,y)
				self.CursorX = x
				self.CursorY = y
				self:UpdateCursor()
				self:JumpToCursor()
			end

			funcs.JumpToCursor = function(self)
				local linesFrame = self.GuiElems.LinesFrame
				if not linesFrame then self:Refresh() return end
				local vSize = math.max(0, linesFrame.AbsoluteSize.Y)
				local hSize = math.max(0, linesFrame.AbsoluteSize.X)
				local maxLines = math.floor(vSize / self.FontSize)
				local maxCols = math.floor(hSize / math.ceil(self.FontSize/2))

				if maxLines > 0 then
					if self.CursorY < self.ViewY then
						self.ViewY = self.CursorY
					elseif self.CursorY >= self.ViewY + maxLines then
						self.ViewY = math.max(0, self.CursorY - maxLines + 3)
					end
				end

				if maxCols > 0 then
					if self.CursorX < self.ViewX then
						self.ViewX = math.max(0, self.CursorX - 2)
					elseif self.CursorX >= self.ViewX + maxCols then
						self.ViewX = math.max(0, self.CursorX - maxCols + 5)
					end
				end

				self.ScrollV:ScrollTo(self.ViewY, true)
				self.ScrollH:ScrollTo(self.ViewX, true)
				self:Refresh()
			end

			funcs.UpdateCursor = function(self,input)
				local linesFrame = self.GuiElems.LinesFrame
				local cursor = self.GuiElems.Cursor			
				local hSize = math.max(0,linesFrame.AbsoluteSize.X)
				local vSize = math.max(0,linesFrame.AbsoluteSize.Y)
				local maxLines = math.ceil(vSize / self.FontSize)
				local maxCols = math.ceil(hSize / math.ceil(self.FontSize/2))
				local viewX,viewY = self.ViewX,self.ViewY
				local totalLinesStr = tostring(#self.Lines)
				local fontWidth = math.ceil(self.FontSize / 2)
				local linesOffset = #totalLinesStr*fontWidth + 4*fontWidth

				if input then
					local linesFrame = self.GuiElems.LinesFrame
					local frameX,frameY = linesFrame.AbsolutePosition.X,linesFrame.AbsolutePosition.Y
					local mouseX,mouseY = input.Position.X,input.Position.Y
					local fontSizeX,fontSizeY = math.ceil(self.FontSize/2),self.FontSize

					self.CursorX = self.ViewX + math.round((mouseX - frameX) / fontSizeX)
					self.CursorY = self.ViewY + math.floor((mouseY - frameY) / fontSizeY)
				end

				local cursorX,cursorY = self.CursorX,self.CursorY

				local line = self.Lines[cursorY+1] or ""
				if cursorX > #line then cursorX = #line
				elseif cursorX < 0 then cursorX = 0 end

				if cursorY >= #self.Lines then
					cursorY = math.max(0,#self.Lines-1)
				elseif cursorY < 0 then
					cursorY = 0
				end

				cursorX = cursorX + self:TabAdjust(cursorX,cursorY)

				-- Update modified
				self.CursorX = cursorX
				self.CursorY = cursorY

				local cursorVisible = (cursorX >= viewX) and (cursorY >= viewY) and (cursorX <= viewX + maxCols) and (cursorY <= viewY + maxLines)
				if cursorVisible then
					local offX = (cursorX - viewX)
					local offY = (cursorY - viewY)
					cursor.Position = UDim2.new(0,linesOffset + offX*math.ceil(self.FontSize/2) - 1,0,offY*self.FontSize)
					cursor.Size = UDim2.new(0,1,0,self.FontSize+2)
					cursor.Visible = true
					self:CursorAnim(true)
				else
					cursor.Visible = false
				end
			end

			funcs.MapNewLines = function(self)
				local newLines = {}
				local count = 1
				local text = self.Text
				local find = string.find
				local init = 1

				local pos = find(text,"\n",init,true)
				while pos do
					newLines[count] = pos
					count = count + 1
					init = pos + 1
					pos = find(text,"\n",init,true)
				end

				self.NewLines = newLines
			end

			funcs.PreHighlight = function(self)
				local start = tick()
				local text = self.Text:gsub("\\\\","  ")
				--print("BACKSLASH SUB",tick()-start)
				local textLen = #text
				local found = {}
				local foundMap = {}
				local extras = {}
				local find = string.find
				local sub = string.sub
				self.ColoredLines = {}

				local function findAll(str,pattern,typ,raw)
					local count = #found+1
					local init = 1
					local x,y,extra = find(str,pattern,init,raw)
					while x do
						found[count] = x
						foundMap[x] = typ
						if extra then
							extras[x] = extra
						end

						count = count+1
						init = y+1
						x,y,extra = find(str,pattern,init,raw)
					end
				end
				local start = tick()
				findAll(text,'"',1,true)
				findAll(text,"'",2,true)
				findAll(text,"%[(=*)%[",3)
				findAll(text,"--",4,true)
				table.sort(found)

				local newLines = self.NewLines
				local curLine = 0
				local lineTableCount = 1
				local lineStart = 0
				local lineEnd = 0
				local lastEnding = 0
				local foundHighlights = {}

				for i = 1,#found do
					local pos = found[i]
					if pos <= lastEnding then continue end

					local ending = pos
					local typ = foundMap[pos]
					if typ == 1 then
						ending = find(text,'"',pos+1,true)
						while ending and sub(text,ending-1,ending-1) == "\\" do
							ending = find(text,'"',ending+1,true)
						end
						if not ending then ending = textLen end
					elseif typ == 2 then
						ending = find(text,"'",pos+1,true)
						while ending and sub(text,ending-1,ending-1) == "\\" do
							ending = find(text,"'",ending+1,true)
						end
						if not ending then ending = textLen end
					elseif typ == 3 then
						_,ending = find(text,"]"..extras[pos].."]",pos+1,true)
						if not ending then ending = textLen end
					elseif typ == 4 then
						local ahead = foundMap[pos+2]

						if ahead == 3 then
							_,ending = find(text,"]"..extras[pos+2].."]",pos+1,true)
							if not ending then ending = textLen end
						else
							ending = find(text,"\n",pos+1,true) or textLen
						end
					end

					while pos > lineEnd do
						curLine = curLine + 1
						--lineTableCount = 1
						lineEnd = newLines[curLine] or textLen+1
					end
					while true do
						local lineTable = foundHighlights[curLine]
						if not lineTable then lineTable = {} foundHighlights[curLine] = lineTable end
						lineTable[pos] = {typ,ending}
						--lineTableCount = lineTableCount + 1

						if ending > lineEnd then
							curLine = curLine + 1
							lineEnd = newLines[curLine] or textLen+1
						else
							break
						end
					end

					lastEnding = ending
					--if i < 200 then print(curLine) end
				end
				self.PreHighlights = foundHighlights
				--print(tick()-start)
				--print(#found,curLine)
			end

			funcs.HighlightLine = function(self,line)
				local cached = self.ColoredLines[line]
				if cached then return cached end

				local sub = string.sub
				local find = string.find
				local match = string.match
				local highlights = {}
				local preHighlights = self.PreHighlights[line] or {}
				local lineText = self.Lines[line] or ""
				local lineLen = #lineText
				local lastEnding = 0
				local currentType = 0
				local lastWord = nil
				local wordBeginsDotted = false
				local funcStatus = 0
				local lineStart = self.NewLines[line-1] or 0

				local preHighlightMap = {}
				for pos,data in next,preHighlights do
					local relativePos = pos-lineStart
					if relativePos < 1 then
						currentType = data[1]
						lastEnding = data[2] - lineStart
						--warn(pos,data[2])
					else
						preHighlightMap[relativePos] = {data[1],data[2]-lineStart}
					end
				end

				for col = 1,#lineText do
					if col <= lastEnding then highlights[col] = currentType continue end

					local pre = preHighlightMap[col]
					if pre then
						currentType = pre[1]
						lastEnding = pre[2]
						highlights[col] = currentType
						wordBeginsDotted = false
						lastWord = nil
						funcStatus = 0
					else
						local char = sub(lineText,col,col)
						if find(char,"[%a_]") then
							local word = match(lineText,"[%a%d_]+",col)
							local wordType = (keywords[word] and 7) or (builtIns[word] and 8)

							lastEnding = col+#word-1

							if wordType ~= 7 then
								if wordBeginsDotted then
									local prevBuiltIn = lastWord and builtIns[lastWord]
									wordType = (prevBuiltIn and type(prevBuiltIn) == "table" and prevBuiltIn[word] and 8) or 10
								end

								if wordType ~= 8 then
									local x,y,br = find(lineText,"^%s*([%({\"'])",lastEnding+1)
									if x then
										wordType = (funcStatus > 0 and br == "(" and 16) or 9
										funcStatus = 0
									end
								end
							else
								wordType = specialKeywordsTypes[word] or wordType
								funcStatus = (word == "function" and 1 or 0)
							end

							lastWord = word
							wordBeginsDotted = false
							if funcStatus > 0 then funcStatus = 1 end

							if wordType then
								currentType = wordType
								highlights[col] = currentType
							else
								currentType = nil
							end
						elseif find(char,"%p") then
							local isDot = (char == ".")
							local isNum = isDot and find(sub(lineText,col+1,col+1),"%d")
							highlights[col] = (isNum and 6 or 5)

							if not isNum then
								local dotStr = isDot and match(lineText,"%.%.?%.?",col)
								if dotStr and #dotStr > 1 then
									currentType = 5
									lastEnding = col+#dotStr-1
									wordBeginsDotted = false
									lastWord = nil
									funcStatus = 0
								else
									if isDot then
										if wordBeginsDotted then
											lastWord = nil
										else
											wordBeginsDotted = true
										end
									else
										wordBeginsDotted = false
										lastWord = nil
									end

									funcStatus = ((isDot or char == ":") and funcStatus == 1 and 2) or 0
								end
							end
						elseif find(char,"%d") then
							local _,endPos = find(lineText,"%x+",col)
							local endPart = sub(lineText,endPos,endPos+1)
							if (endPart == "e+" or endPart == "e-") and find(sub(lineText,endPos+2,endPos+2),"%d") then
								endPos = endPos + 1
							end
							currentType = 6
							lastEnding = endPos
							highlights[col] = 6
							wordBeginsDotted = false
							lastWord = nil
							funcStatus = 0
						else
							highlights[col] = currentType
							local _,endPos = find(lineText,"%s+",col)
							if endPos then
								lastEnding = endPos
							end
						end
					end
				end

				self.ColoredLines[line] = highlights
				return highlights
			end

			funcs.Refresh = function(self)
				local start = tick()

				local linesFrame = self.Frame.Lines
				local hSize = math.max(0,linesFrame.AbsoluteSize.X)
				local vSize = math.max(0,linesFrame.AbsoluteSize.Y)
				local maxLines = math.ceil(vSize / self.FontSize)
				local maxCols = math.ceil(hSize / math.ceil(self.FontSize/2))
				local gsub = string.gsub
				local sub = string.sub

				local viewX,viewY = self.ViewX,self.ViewY

				local lineNumberStr = ""

				for row = 1,maxLines do
					local lineFrame = self.LineFrames[row]
					if not lineFrame then
						lineFrame = Instance.new("Frame")
						lineFrame.Name = "Line"
						lineFrame.Position = UDim2.new(0,0,0,(row-1)*self.FontSize)
						lineFrame.Size = UDim2.new(1,0,0,self.FontSize)
						lineFrame.BorderSizePixel = 0
						lineFrame.BackgroundTransparency = 1

						local selectionHighlight = Instance.new("Frame")
						selectionHighlight.Name = "SelectionHighlight"
						selectionHighlight.BorderSizePixel = 0
						selectionHighlight.BackgroundColor3 = Settings.Theme.Syntax.SelectionBack
						selectionHighlight.Parent = lineFrame

						local label = Instance.new("TextLabel")
						label.Name = "Label"
						label.BackgroundTransparency = 1
						label.Font = Enum.Font.Code
						label.TextSize = self.FontSize
						label.Size = UDim2.new(1,0,0,self.FontSize)
						label.RichText = true
						label.TextXAlignment = Enum.TextXAlignment.Left
						label.TextColor3 = self.Colors.Text
						label.ZIndex = 2
						label.Parent = lineFrame

						lineFrame.Parent = linesFrame
						self.LineFrames[row] = lineFrame
					end

					local relaY = viewY + row
					local lineText = self.Lines[relaY] or ""
					local resText = ""
					local highlights = self:HighlightLine(relaY)
					local colStart = viewX + 1

					local richTemplates = self.RichTemplates
					local textTemplate = richTemplates.Text
					local selectionTemplate = richTemplates.Selection
					local curType = highlights[colStart]
					local curTemplate = richTemplates[typeMap[curType]] or textTemplate

					-- Selection Highlight
					local selectionRange = self.SelectionRange
					local selPos1 = selectionRange[1]
					local selPos2 = selectionRange[2]
					local selRow,selColumn = selPos1[2],selPos1[1]
					local sel2Row,sel2Column = selPos2[2],selPos2[1]
					local selRelaX,selRelaY = viewX,relaY-1

					if selRelaY >= selPos1[2] and selRelaY <= selPos2[2] then
						local fontSizeX = math.ceil(self.FontSize/2)
						local posX = (selRelaY == selPos1[2] and selPos1[1] or 0) - viewX
						local sizeX = (selRelaY == selPos2[2] and selPos2[1]-posX-viewX or maxCols+viewX)

						lineFrame.SelectionHighlight.Position = UDim2.new(0,posX*fontSizeX,0,0)
						lineFrame.SelectionHighlight.Size = UDim2.new(0,sizeX*fontSizeX,1,0)
						lineFrame.SelectionHighlight.Visible = true
					else
						lineFrame.SelectionHighlight.Visible = false
					end

					-- Selection Text Color for first char
					local inSelection = selRelaY >= selRow and selRelaY <= sel2Row and (selRelaY == selRow and viewX >= selColumn or selRelaY ~= selRow) and (selRelaY == sel2Row and viewX < sel2Column or selRelaY ~= sel2Row)
					if inSelection then
						curType = -999
						curTemplate = selectionTemplate
					end

					for col = 2,maxCols do
						local relaX = viewX + col
						local selRelaX = relaX-1
						local posType = highlights[relaX]

						-- Selection Text Color
						local inSelection = selRelaY >= selRow and selRelaY <= sel2Row and (selRelaY == selRow and selRelaX >= selColumn or selRelaY ~= selRow) and (selRelaY == sel2Row and selRelaX < sel2Column or selRelaY ~= sel2Row)
						if inSelection then
							posType = -999
						end

						if posType ~= curType then
							local template = (inSelection and selectionTemplate) or richTemplates[typeMap[posType]] or textTemplate

							if template ~= curTemplate then
								local nextText = gsub(sub(lineText,colStart,relaX-1),"['\"<>&]",richReplace)
								resText = resText .. (curTemplate ~= textTemplate and (curTemplate .. nextText .. "</font>") or nextText)
								colStart = relaX
								curTemplate = template
							end
							curType = posType
						end
					end

					local lastText = gsub(sub(lineText,colStart,viewX+maxCols),"['\"<>&]",richReplace)
					--warn("SUB",colStart,viewX+maxCols-1)
					if #lastText > 0 then
						resText = resText .. (curTemplate ~= textTemplate and (curTemplate .. lastText .. "</font>") or lastText)
					end

					if self.Lines[relaY] then

						-- REMOVED LINE HIGHLIGHT DUE TO BUG OFFSET
						lineNumberStr = lineNumberStr .. (relaY == self.CursorY and ("<b>"..relaY.."</b>\n") or relaY .. "\n")
						--lineNumberStr = lineNumberStr .. (relaY == self.CursorY and (relaY.."\n") or relaY .. "\n")
					end

					lineFrame.Label.Text = resText
				end

				for i = maxLines+1,#self.LineFrames do
					self.LineFrames[i]:Destroy()
					self.LineFrames[i] = nil
				end

				self.Frame.LineNumbers.Text = lineNumberStr
				self:UpdateCursor()

				--print("REFRESH TIME",tick()-start)
			end

			funcs.UpdateView = function(self)
				local totalLinesStr = tostring(#self.Lines)
				local fontWidth = math.ceil(self.FontSize / 2)
				local linesOffset = #totalLinesStr*fontWidth + 4*fontWidth

				local linesFrame = self.Frame.Lines
				local hSize = linesFrame.AbsoluteSize.X
				local vSize = linesFrame.AbsoluteSize.Y
				local maxLines = math.ceil(vSize / self.FontSize)
				local totalWidth = self.MaxTextCols*fontWidth
				local scrollV = self.ScrollV
				local scrollH = self.ScrollH

				scrollV.VisibleSpace = maxLines
				scrollV.TotalSpace = #self.Lines + 1
				scrollH.VisibleSpace = math.ceil(hSize/fontWidth)
				scrollH.TotalSpace = self.MaxTextCols + 1

				scrollV.Gui.Visible = #self.Lines + 1 > maxLines
				scrollH.Gui.Visible = totalWidth > hSize

				local oldOffsets = self.FrameOffsets
				self.FrameOffsets = Vector2.new(scrollV.Gui.Visible and -16 or 0, scrollH.Gui.Visible and -16 or 0)
				if oldOffsets ~= self.FrameOffsets then
					self:UpdateView()
				else
					scrollV:ScrollTo(self.ViewY,true)
					scrollH:ScrollTo(self.ViewX,true)

					if scrollV.Gui.Visible and scrollH.Gui.Visible then
						scrollV.Gui.Size = UDim2.new(0,16,1,-16)
						scrollH.Gui.Size = UDim2.new(1,-16,0,16)
						self.GuiElems.ScrollCorner.Visible = true
					else
						scrollV.Gui.Size = UDim2.new(0,16,1,0)
						scrollH.Gui.Size = UDim2.new(1,0,0,16)
						self.GuiElems.ScrollCorner.Visible = false
					end

					self.ViewY = math.round(scrollV.Index)
					self.ViewX = math.round(scrollH.Index)
					self.Frame.Lines.Position = UDim2.new(0,linesOffset,0,0)
					self.Frame.Lines.Size = UDim2.new(1,-linesOffset+oldOffsets.X,1,oldOffsets.Y)
					self.Frame.LineNumbers.Position = UDim2.new(0,fontWidth,0,0)
					self.Frame.LineNumbers.Size = UDim2.new(0,#totalLinesStr*fontWidth,1,oldOffsets.Y)
					self.Frame.LineNumbers.TextSize = self.FontSize
				end
			end

			funcs.ProcessTextChange = function(self)
				local maxCols = 0
				local lines = self.Lines

				for i = 1,#lines do
					local lineLen = #lines[i]
					if lineLen > maxCols then
						maxCols = lineLen
					end
				end

				self.MaxTextCols = maxCols
				self:UpdateView()	
				self.Text = table.concat(self.Lines,"\n")
				self:MapNewLines()
				self:PreHighlight()
				self:Refresh()
				--self.TextChanged:Fire()
			end

			funcs.ConvertText = function(self,text,toEditor)
				if toEditor then
					--return text:gsub("\t",(" %s%s "):format(tabSub,tabSub))
					return text:gsub("\t","    ") -- Fixed unknown unicode showing when pressing TAB
				else
					return text:gsub((" %s%s "):format(tabSub,tabSub),"\t")
				end
			end

			funcs.GetText = function(self) -- TODO: better (use new tab format)
				local source = table.concat(self.Lines,"\n")
				return self:ConvertText(source,false) -- Tab Convert
			end

			funcs.SetText = function(self,txt)
				txt = self:ConvertText(txt,true) -- Tab Convert
				local lines = self.Lines
				table.clear(lines)
				self.SelectionRange = {{-1,-1},{-1,-1}}
				if self.OnSelectionChanged then self.OnSelectionChanged:Fire("") end
				local count = 1

				for line in txt:gmatch("([^\n\r]*)[\n\r]?") do
					local len = #line
					lines[count] = line
					count = count + 1
				end

				self:ProcessTextChange()
			end

			funcs.MakeRichTemplates = function(self)
				local floor = math.floor
				local templates = {}

				for name,color in pairs(self.Colors) do
					templates[name] = ('<font color="rgb(%s,%s,%s)">'):format(floor(color.r*255),floor(color.g*255),floor(color.b*255))
				end

				self.RichTemplates = templates
			end

			funcs.ApplyTheme = function(self)
				local colors = Settings.Theme.Syntax
				self.Colors = colors
				self.Frame.LineNumbers.TextColor3 = colors.Text
				self.Frame.BackgroundColor3 = colors.Background
			end

			local mt = {__index = funcs}

			local function new()
				if not builtInInited then initBuiltIn() end

				local scrollV = Lib.ScrollBar.new()
				local scrollH = Lib.ScrollBar.new(true)
				scrollH.Gui.Position = UDim2.new(0,0,1,-16)
				local obj = setmetatable({
					FontSize = 16,
					ViewX = 0,
					ViewY = 0,
					Colors = Settings.Theme.Syntax,
					ColoredLines = {},
					Lines = {""},
					LineFrames = {},
					Editable = true,
					Editing = false,
					CursorX = 0,
					CursorY = 0,
					FloatCursorX = 0,
					Text = "",
					PreHighlights = {},
					SelectionRange = {{-1,-1},{-1,-1}},
					NewLines = {},
					FrameOffsets = Vector2.new(0,0),
					MaxTextCols = 0,
					ScrollV = scrollV,
					ScrollH = scrollH,
					OnSelectionChanged = Lib.Signal.new(),
					OnSelectionFinished = Lib.Signal.new(),
					OnRightClick = Lib.Signal.new()
				},mt)

				scrollV.WheelIncrement = 3
				scrollH.Increment = 2
				scrollH.WheelIncrement = 7

				scrollV.Scrolled:Connect(function()
					obj.ViewY = math.round(scrollV.Index)
					obj:Refresh()
				end)

				scrollH.Scrolled:Connect(function()
					obj.ViewX = math.round(scrollH.Index)
					obj:Refresh()
				end)

				makeFrame(obj)
				obj:MakeRichTemplates()
				obj:ApplyTheme()
				scrollV:SetScrollFrame(obj.Frame.Lines)
				scrollV.Gui.Parent = obj.Frame
				scrollH.Gui.Parent = obj.Frame

				obj:UpdateView()
				obj.Frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
					obj:UpdateView()
					obj:Refresh()
				end)

				return obj
			end

			return {new = new}
	end)()

	local Notepad = {}
	local window, codeFrame
	local selectionMenu
	local searchMatches = {}
	local searchIndex = 0
	
	local execute, clear, dumpbtn, smartViewBtn
	
	local PreviousScr = nil
	local rawSourceCache = ""
	local smartViewActive = false
	local lastSelectionText = ""
	
	Notepad.DumpFunctions = function(scr)
		-- thanks King.Kevin#6025 you'll obviously be credited (no discord tag since that can easily be impersonated)
		local getgc = getgc or get_gc_objects
		local getupvalues = (debug and debug.getupvalues) or getupvalues or getupvals
		local getconstants = (debug and debug.getconstants) or getconstants or getconsts
		local getinfo = (debug and (debug.getinfo or debug.info)) or getinfo
		local original = ("\n-- // Function Dumper made by King.Kevin\n-- // Script Path: %s\n\n--[["):format(getPath(scr))
		local dump = original
		local functions, function_count, data_base = {}, 0, {}
		function functions:add_to_dump(str, indentation, new_line)
			local new_line = new_line or true
			dump = dump .. ("%s%s%s"):format(string.rep("		", indentation), tostring(str), new_line and "\n" or "")
		end
		function functions:get_function_name(func)
			local n = getinfo(func).name
			return n ~= "" and n or "Unknown Name"
		end
		function functions:dump_table(input, indent, index)
			local indent = indent < 0 and 0 or indent
			functions:add_to_dump(("%s [%s] %s"):format(tostring(index), tostring(typeof(input)), tostring(input)), indent - 1)
			local count = 0
			for index, value in pairs(input) do
				count = count + 1
				if type(value) == "function" then
					functions:add_to_dump(("%d [function] = %s"):format(count, functions:get_function_name(value)), indent)
				elseif type(value) == "table" then
					if not data_base[value] then
						data_base[value] = true
						functions:add_to_dump(("%d [table]:"):format(count), indent)
						functions:dump_table(value, indent + 1, index)
					else
						functions:add_to_dump(("%d [table] (Recursive table detected)"):format(count), indent)
					end
				else
					functions:add_to_dump(("%d [%s] = %s"):format(count, tostring(typeof(value)), tostring(value)), indent)
				end
			end
		end
		function functions:dump_function(input, indent)
			functions:add_to_dump(("\nFunction Dump: %s"):format(functions:get_function_name(input)), indent)
			functions:add_to_dump(("\nFunction Upvalues: %s"):format(functions:get_function_name(input)), indent)
			for index, upvalue in pairs(getupvalues(input)) do
				if type(upvalue) == "function" then
					functions:add_to_dump(("%d [function] = %s"):format(index, functions:get_function_name(upvalue)), indent + 1)
				elseif type(upvalue) == "table" then
					if not data_base[upvalue] then
						data_base[upvalue] = true
						functions:add_to_dump(("%d [table]:"):format(index), indent + 1)
						functions:dump_table(upvalue, indent + 2, index)
					else
						functions:add_to_dump(("%d [table] (Recursive table detected)"):format(index), indent + 1)
					end
				else
					functions:add_to_dump(("%d [%s] = %s"):format(index, tostring(typeof(upvalue)), tostring(upvalue)), indent + 1)
				end
			end
			functions:add_to_dump(("\nFunction Constants: %s"):format(functions:get_function_name(input)), indent)
			for index, constant in pairs(getconstants(input)) do
				if type(constant) == "function" then
					functions:add_to_dump(("%d [function] = %s"):format(index, functions:get_function_name(constant)), indent + 1)
				elseif type(constant) == "table" then
					if not data_base[constant] then
						data_base[constant] = true
						functions:add_to_dump(("%d [table]:"):format(index), indent + 1)
						functions:dump_table(constant, indent + 2, index)
					else
						functions:add_to_dump(("%d [table] (Recursive table detected)"):format(index), indent + 1)
					end
				else
					functions:add_to_dump(("%d [%s] = %s"):format(index, tostring(typeof(constant)), tostring(constant)), indent + 1)
				end
			end
		end
		for _, _function in pairs(env.getgc()) do
			if typeof(_function) == "function" and getfenv(_function).script and getfenv(_function).script == scr then
				functions:dump_function(_function, 0)
				functions:add_to_dump("\n" .. ("="):rep(100), 0, false)
			end
		end
		local source = codeFrame:GetText()

		if dump ~= original then source = source .. dump .. "]]" end
		codeFrame:SetText(source)
		
		window:Show()
	end

	local function setSearchStatus(text, color)
		if not searchStatus then return end
		searchStatus.Text = text
		searchStatus.TextColor3 = color or Settings.Theme.PlaceholderText
	end

	local function rebuildSearch()
		searchMatches = {}
		searchIndex = 0

		if not searchBox or not codeFrame then return end
		local keyword = searchBox.Text
		if keyword == "" then
			codeFrame:ResetSelection()
			setSearchStatus("0")
			return
		end

		local loweredKeyword = keyword:lower()
		for lineIndex, line in ipairs(codeFrame.Lines) do
			local loweredLine = line:lower()
			local startAt = 1
			while true do
				local first, last = loweredLine:find(loweredKeyword, startAt, true)
				if not first then break end
				searchMatches[#searchMatches + 1] = {
					line = lineIndex - 1,
					first = first - 1,
					last = last,
				}
				startAt = math.max(last + 1, first + 1)
			end
		end

		if #searchMatches == 0 then
			codeFrame:ResetSelection()
			setSearchStatus("0", Settings.Theme.Important)
		else
			searchIndex = 1
			setSearchStatus("1/" .. #searchMatches)
		end
	end

	local function jumpSearch(delta)
		if not codeFrame then return end
		if #searchMatches == 0 then
			rebuildSearch()
		end
		if #searchMatches == 0 then return end

		searchIndex = ((searchIndex - 1 + delta) % #searchMatches) + 1
		local match = searchMatches[searchIndex]
		codeFrame.SelectionRange = {{match.first, match.line}, {match.last, match.line}}
		codeFrame:MoveCursor(match.first, match.line)
		codeFrame:SetCopyableSelection()
		codeFrame:Refresh()
		setSearchStatus(searchIndex .. "/" .. #searchMatches)
	end

	local function getSelectionText()
		if not codeFrame or not codeFrame.GetSelectionText then return "" end
		local ok, text = pcall(function()
			return codeFrame:GetSelectionText()
		end)
		return ok and tostring(text or "") or ""
	end

	local function copySelected()
		local text = getSelectionText()
		if text == "" then return end
		if env.setclipboard then
			env.setclipboard(text)
		end
	end

	local function searchSelected()
		local text = getSelectionText()
		if text == "" or not searchBox then return end
		local oneLine = text:gsub("[\r\n]+", " ")
		if #oneLine > 120 then oneLine = oneLine:sub(1, 120) end
		searchBox.Text = oneLine
		rebuildSearch()
		jumpSearch(0)
	end

	local function copySelectedAI()
		local text = getSelectionText()
		if text == "" or not env.setclipboard then return end
		local lines = {
			"DEX++ selected code context",
			"Script: " .. (PreviousScr and getPath(PreviousScr) or "Generated/Notepad source"),
			"",
			"Selected code:",
			text,
			"",
			"Task for AI:",
			"Explain this selected block, identify important calls/remotes/services, and suggest what I should inspect next.",
		}
		env.setclipboard(table.concat(lines, "\n"))
	end

	local function saveSelected()
		local text = getSelectionText()
		if text == "" then return end
		Lib.SaveAsPrompt("Selected_Code_" .. os.time() .. ".luau", text)
	end

	local function copyScriptPath()
		if not env.setclipboard then return end
		env.setclipboard(PreviousScr and getPath(PreviousScr) or "Generated/Notepad source")
	end

	local function selectAllCode()
		if not codeFrame or not codeFrame.Lines or #codeFrame.Lines == 0 then return end
		codeFrame.SelectionRange = {{0, 0}, {#codeFrame.Lines[#codeFrame.Lines], #codeFrame.Lines - 1}}
		codeFrame:SetCopyableSelection()
		codeFrame:Refresh()
	end

	local function clearSelection()
		if selectionMenu then selectionMenu:Hide() end
		if codeFrame and codeFrame.ResetSelection then
			codeFrame:ResetSelection()
		end
	end

	local function buildSelectionMenu()
		if not selectionMenu then
			selectionMenu = Lib.ContextMenu.new()
			selectionMenu.Width = 210
			selectionMenu.MaxHeight = 260
			selectionMenu.Iconless = true
			selectionMenu.SearchEnabled = false
			selectionMenu.ReverseYOffset = 4
			selectionMenu:ApplyTheme({
				ContentColor = Settings.Theme.Main1,
				OutlineColor = Settings.Theme.Outline1,
				DividerColor = Settings.Theme.Outline2,
				TextColor = Settings.Theme.Text,
				HighlightColor = Settings.Theme.ButtonHover,
			})
		end

		local hasClipboard = env.setclipboard ~= nil
		local hasSelection = getSelectionText() ~= ""

		selectionMenu:Clear()
		selectionMenu:Add({
			Name = "Copy",
			Shortcut = "Ctrl+C",
			Disabled = not hasClipboard or not hasSelection,
			OnClick = copySelected,
		})
		selectionMenu:Add({
			Name = "Search Selection",
			Shortcut = "Ctrl+F",
			Disabled = not hasSelection,
			OnClick = searchSelected,
		})
		selectionMenu:Add({
			Name = "Copy AI Context",
			Disabled = not hasClipboard or not hasSelection,
			OnClick = copySelectedAI,
		})
		selectionMenu:Add({
			Name = "Save Selection",
			Disabled = not hasSelection,
			OnClick = saveSelected,
		})
		selectionMenu:AddDivider()
		selectionMenu:Add({
			Name = "Copy Script Path",
			Disabled = not hasClipboard,
			OnClick = copyScriptPath,
		})
		selectionMenu:Add({
			Name = "Select All",
			Shortcut = "Ctrl+A",
			OnClick = selectAllCode,
		})
		selectionMenu:Add({
			Name = "Clear Selection",
			Disabled = not hasSelection,
			OnClick = clearSelection,
		})
	end

	local function showSelectionMenu(x, y)
		if not codeFrame then return end
		local text = getSelectionText()
		if text == "" then return end
		buildSelectionMenu()
		selectionMenu:Show(x, y)
	end

	local function updateSelectionMenu(text)
		text = tostring(text or "")
		lastSelectionText = text
		if text == "" and selectionMenu then
			selectionMenu:Hide()
		end
	end

	Notepad.Init = function()
		window = Lib.Window.new()
		window:SetTitle("Notepad")
		window:Resize(500,400)
		Notepad.Window = window

		codeFrame = CodeFrame.new()
		codeFrame.Frame.Position = UDim2.new(0,0,0,44)
		codeFrame.Frame.Size = UDim2.new(1,0,1,-64)
		codeFrame.Frame.Parent = window.GuiElems.Content

		if codeFrame.OnSelectionChanged then
			codeFrame.OnSelectionChanged:Connect(updateSelectionMenu)
		end
		if codeFrame.OnSelectionFinished then
			codeFrame.OnSelectionFinished:Connect(function(text, x, y)
				if tostring(text or "") ~= "" then
					showSelectionMenu(x, y)
				end
			end)
		end
		if codeFrame.OnRightClick then
			codeFrame.OnRightClick:Connect(function(x, y)
				if lastSelectionText == "" then
					local ok, current = pcall(function()
						return codeFrame:GetSelectionText()
					end)
					lastSelectionText = ok and tostring(current or "") or ""
				end
				if lastSelectionText ~= "" then
					showSelectionMenu(x, y)
				end
			end)
		end
		
		local copy = Instance.new("TextButton",window.GuiElems.Content)
		copy.BackgroundTransparency = 1
		copy.Size = UDim2.new(0.25,0,0,20)
		copy.Position = UDim2.new(0,0,0,0)
		copy.Text = "Copy to Clipboard"
		
		if env.setclipboard then
			copy.TextColor3 = Color3.new(1,1,1)
			copy.Interactable = true
		else
			copy.TextColor3 = Color3.new(0.5,0.5,0.5)
			copy.Interactable = false
		end

		copy.MouseButton1Click:Connect(function()
			local source = codeFrame:GetText()
			env.setclipboard(source)
		end)

		local save = Instance.new("TextButton",window.GuiElems.Content)
		save.BackgroundTransparency = 1
		save.Size = UDim2.new(0.25,0,0,20)
		save.Position = UDim2.new(0.25,0,0,0)
		save.Text = "Save to File"
		save.TextColor3 = Color3.new(1,1,1)
		
		if env.writefile then
			save.TextColor3 = Color3.new(1,1,1)
			save.Interactable = true
		else
			save.TextColor3 = Color3.new(0.5,0.5,0.5)
			--save.Interactable = false
		end

		save.MouseButton1Click:Connect(function()
			local source = codeFrame:GetText()
			local filename = "Place_"..game.PlaceId.."_Script_"..os.time()..".txt"

			Lib.SaveAsPrompt(filename,source)
			--env.writefile(filename,source)
		end)
		
		dumpbtn = Instance.new("TextButton",window.GuiElems.Content)
		dumpbtn.BackgroundTransparency = 1
		dumpbtn.Position = UDim2.new(0.5,0,0,0)
		dumpbtn.Size = UDim2.new(0.25,0,0,20)
		dumpbtn.Text = "Dump Functions"
		
		if env.getgc then
			dumpbtn.TextColor3 = Color3.new(1,1,1)
			dumpbtn.Interactable = true
		else
			dumpbtn.TextColor3 = Color3.new(0.5,0.5,0.5)
			dumpbtn.Interactable = false
		end

		dumpbtn.MouseButton1Click:Connect(function()
			if PreviousScr ~= nil then
				pcall(Notepad.DumpFunctions, PreviousScr)
			end
		end)

		smartViewBtn = Instance.new("TextButton",window.GuiElems.Content)
		smartViewBtn.BackgroundTransparency = 1
		smartViewBtn.Position = UDim2.new(0.75,0,0,0)
		smartViewBtn.Size = UDim2.new(0.25,0,0,20)
		smartViewBtn.Text = "Smart View: OFF"
		smartViewBtn.TextColor3 = Color3.new(0.5,0.5,0.5)
		
		smartViewBtn.MouseButton1Click:Connect(function()
			smartViewActive = not smartViewActive
			if smartViewActive then
				smartViewBtn.Text = "Smart View: ON"
				smartViewBtn.TextColor3 = Settings.Theme.ListSelection
			else
				smartViewBtn.Text = "Smart View: OFF"
				smartViewBtn.TextColor3 = Color3.new(0.5,0.5,0.5)
			end
			if PreviousScr ~= nil then
				Notepad.ViewScript(PreviousScr)
			end
		end)

		local searchBar = Instance.new("Frame", window.GuiElems.Content)
		searchBar.BackgroundColor3 = Settings.Theme.TextBox
		searchBar.BorderSizePixel = 0
		searchBar.Position = UDim2.new(0, 0, 0, 21)
		searchBar.Size = UDim2.new(1, 0, 0, 22)

		searchBox = Instance.new("TextBox", searchBar)
		searchBox.BackgroundTransparency = 1
		searchBox.ClearTextOnFocus = false
		searchBox.Font = Enum.Font.Code
		searchBox.PlaceholderColor3 = Settings.Theme.PlaceholderText
		searchBox.PlaceholderText = "Search keywords..."
		searchBox.Position = UDim2.new(0, 8, 0, 0)
		searchBox.Size = UDim2.new(1, -138, 1, 0)
		searchBox.Text = ""
		searchBox.TextColor3 = Settings.Theme.Text
		searchBox.TextSize = 13
		searchBox.TextXAlignment = Enum.TextXAlignment.Left

		local prevBtn = Instance.new("TextButton", searchBar)
		prevBtn.AutoButtonColor = false
		prevBtn.BackgroundColor3 = Settings.Theme.Button
		prevBtn.BorderSizePixel = 0
		prevBtn.Font = Enum.Font.SourceSansBold
		prevBtn.Position = UDim2.new(1, -128, 0, 2)
		prevBtn.Size = UDim2.new(0, 28, 0, 18)
		prevBtn.Text = "<"
		prevBtn.TextColor3 = Settings.Theme.Text
		prevBtn.TextSize = 14

		local nextBtn = Instance.new("TextButton", searchBar)
		nextBtn.AutoButtonColor = false
		nextBtn.BackgroundColor3 = Settings.Theme.Button
		nextBtn.BorderSizePixel = 0
		nextBtn.Font = Enum.Font.SourceSansBold
		nextBtn.Position = UDim2.new(1, -96, 0, 2)
		nextBtn.Size = UDim2.new(0, 28, 0, 18)
		nextBtn.Text = ">"
		nextBtn.TextColor3 = Settings.Theme.Text
		nextBtn.TextSize = 14

		searchStatus = Instance.new("TextLabel", searchBar)
		searchStatus.BackgroundTransparency = 1
		searchStatus.Font = Enum.Font.Code
		searchStatus.Position = UDim2.new(1, -64, 0, 0)
		searchStatus.Size = UDim2.new(0, 58, 1, 0)
		searchStatus.Text = "0"
		searchStatus.TextColor3 = Settings.Theme.PlaceholderText
		searchStatus.TextSize = 12
		searchStatus.TextXAlignment = Enum.TextXAlignment.Right

		local function hoverButton(btn)
			btn.MouseEnter:Connect(function() btn.BackgroundColor3 = Settings.Theme.ButtonHover end)
			btn.MouseLeave:Connect(function() btn.BackgroundColor3 = Settings.Theme.Button end)
		end
		hoverButton(prevBtn)
		hoverButton(nextBtn)

		searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			rebuildSearch()
			if #searchMatches > 0 then
				jumpSearch(0)
			end
		end)
		searchBox.FocusLost:Connect(function(enterPressed)
			if enterPressed then jumpSearch(1) end
		end)
		prevBtn.MouseButton1Click:Connect(function()
			jumpSearch(-1)
		end)
		nextBtn.MouseButton1Click:Connect(function()
			jumpSearch(1)
		end)
		
		-- Buttons below the editor
		
		
		execute = Instance.new("TextButton",window.GuiElems.Content)
		execute.BackgroundTransparency = 1
		execute.Size = UDim2.new(0.5,0,0,20)
		execute.Position = UDim2.new(0,0,1,-20)
		execute.Text = "Execute"
		execute.TextColor3 = Color3.new(1,1,1)
		
		if env.loadstring then
			execute.TextColor3 = Color3.new(1,1,1)
			execute.Interactable = true
		else
			execute.TextColor3 = Color3.new(0.5,0.5,0.5)
			execute.Interactable = false
		end

		execute.MouseButton1Click:Connect(function()
			local source = codeFrame:GetText()
			env.loadstring(source)()
		end)

		clear = Instance.new("TextButton",window.GuiElems.Content)
		clear.BackgroundTransparency = 1
		clear.Size = UDim2.new(0.5,0,0,20)
		clear.Position = UDim2.new(0.5,0,1,-20)
		clear.Text = "Clear"
		clear.TextColor3 = Color3.new(1,1,1)

		clear.MouseButton1Click:Connect(function()
			codeFrame:SetText("")
			rebuildSearch()
		end)
	end
	
	Notepad.ViewScript = function(scr)
		local s,source
		local cacheHit = (PreviousScr == scr and rawSourceCache ~= "")
		
		if cacheHit then
			s = true
			source = rawSourceCache
		else
			local oldtick = tick()
			s,source = pcall(env.decompile or function() end,scr)
			if s and type(source) == "string" and (not env.IsValidDecompileSource or env.IsValidDecompileSource(source)) then
				rawSourceCache = source
			else
				rawSourceCache = ""
			end
		end

		local failure
		if env.GetDecompileFailure then
			local ok, result = pcall(env.GetDecompileFailure, source)
			if ok then failure = result end
		end
		local validSource = s and type(source) == "string" and source ~= ""
			and failure == nil
			and (not env.IsValidDecompileSource or env.IsValidDecompileSource(source))
		if not validSource then
			local failureDetail = type(source) == "string" and source:match("%S") and source or nil
			PreviousScr = nil
			rawSourceCache = ""
			dumpbtn.TextColor3 = Color3.new(0.5,0.5,0.5)
			source = "-- Decompile failed.\n"
			
			if Settings.Notepad.ShowMoreInfo then
				source = source .. "-- Script Path: "..getPath(scr).."\n"
				if (scr.ClassName == "Script" and (scr.RunContext == Enum.RunContext.Legacy or scr.RunContext == Enum.RunContext.Server)) or not scr:IsA("LocalScript") then
					source = source .. "-- Reason: The script is not running on client. (attempt to decompile ServerScript or 'Script' with RunContext Server)\n"
				elseif not env.isdecompile() then
					source = source .. "-- Reason: Your executor does not support decompiler. (missing 'decompile' function and 'getscriptbytecode' function as fallback)\n"
				elseif failure then
					source = source .. "-- Reason [" .. tostring(failure.Code or "decompiler_error") .. "]: " .. tostring(failure.Text or "Decompiler failed.") .. "\n"
				else
					source = source .. "-- Reason: The decompiler rejected or could not deserialize this bytecode.\n"
				end
				source = source .. "-- Executor: "..executorName.." ("..executorVersion..")"
				if failureDetail then
					source = source .. "\n\n-- Raw decompiler response:\n--[[\n" .. failureDetail .. "\n--]]"
				end
			end
		else
			PreviousScr = scr
			dumpbtn.TextColor3 = Color3.new(1,1,1)

			local decompiled = source
			if smartViewActive and SmartDecompiler then
				decompiled = SmartDecompiler.Process(decompiled)
			end

			source = "-- Script Path: "..getPath(scr).."\n"
			
			if Settings.Notepad.ShowMoreInfo and not cacheHit then
				source = source .. "-- Executor: "..executorName.." ("..executorVersion..")\n\n"
			end
			
			source = source .. decompiled
		end

		codeFrame:SetText(source)
		rebuildSearch()
		window:Show()
	end

	Notepad.ViewRawCode = function(code, title)
		PreviousScr = nil
		rawSourceCache = ""
		dumpbtn.TextColor3 = Color3.fromRGB(127,127,127)

		local header = "-- Generated Code: " .. (title or "Source") .. "\n"
		header = header .. "-- Time: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n"

		codeFrame:SetText(header .. code)
		rebuildSearch()
		window:Show()
	end

	return Notepad
end

-- TODO: Remove when open source
if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
