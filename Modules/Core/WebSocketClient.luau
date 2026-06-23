--!strict
--[[
	DEX++ WebSocket Client Module
	Establishes WebSocket connection with C++ Helper Server to listen to remote control API commands.
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
	local function getWebSocketConnect()
		local ws = env.WebSocket or env.websocket
		if ws then
			if type(ws.connect) == "function" then
				return ws.connect
			elseif type(ws.Connect) == "function" then
				return ws.Connect
			end
		end
		local syn_ws = env.syn
		if syn_ws and syn_ws.websocket then
			if type(syn_ws.websocket.connect) == "function" then
				return syn_ws.websocket.connect
			elseif type(syn_ws.websocket.Connect) == "function" then
				return syn_ws.websocket.Connect
			end
		end
		return nil
	end

	local function connectSignal(signal, callback)
		if not signal then return nil end
		if type(signal.Connect) == "function" then
			return signal:Connect(callback)
		elseif type(signal.connect) == "function" then
			return signal:connect(callback)
		end
		return nil
	end

	local function resolveInstance(path)
		if path == "game" then
			return game
		end
		local parts = string.split(path, ".")
		if parts[1] == "game" then
			table.remove(parts, 1)
		end
		local current = game
		for _, part in ipairs(parts) do
			local found = current:FindFirstChild(part)
			if not found then
				local ok, res = pcall(function() return (current :: any)[part] end)
				if ok and typeof(res) == "Instance" then
					current = res
				else
					return nil
				end
			else
				current = found
			end
		end
		return current
	end

	local function getPropertiesForInstance(inst)
		local propsList = {}
		local seen = {}
		local className = inst.ClassName
		local apiClass = API and API.Classes and API.Classes[className]
		while apiClass do
			if apiClass.Properties then
				for _, prop in ipairs(apiClass.Properties) do
					if not seen[prop.Name] then
						seen[prop.Name] = true
						local s, val = pcall(function() return inst[prop.Name] end)
						if s and (not prop.Tags or not prop.Tags.ReadOnly) then
							table.insert(propsList, {Name = prop.Name, Value = tostring(val), Type = typeof(val)})
						end
					end
				end
			end
			apiClass = apiClass.Superclass
		end
		table.sort(propsList, function(a, b) return a.Name < b.Name end)
		return propsList
	end

	local function parsePropertyValue(valueStr, valueType)
		if valueType == "boolean" then
			return valueStr == "true" or valueStr == "1"
		elseif valueType == "number" then
			return tonumber(valueStr)
		elseif valueType == "string" then
			return valueStr
		elseif valueType == "Vector3" then
			local coords = string.split(valueStr, ",")
			return Vector3.new(tonumber(coords[1]) or 0, tonumber(coords[2]) or 0, tonumber(coords[3]) or 0)
		elseif valueType == "Vector2" then
			local coords = string.split(valueStr, ",")
			return Vector2.new(tonumber(coords[1]) or 0, tonumber(coords[2]) or 0)
		elseif valueType == "Color3" then
			local rgb = string.split(valueStr, ",")
			return Color3.fromRGB(tonumber(rgb[1]) or 255, tonumber(rgb[2]) or 255, tonumber(rgb[3]) or 255)
		elseif valueType == "UDim2" then
			local cleaned = valueStr:gsub("[{}%s]", "")
			local parts = string.split(cleaned, ",")
			return UDim2.new(tonumber(parts[1]) or 0, tonumber(parts[2]) or 0, tonumber(parts[3]) or 0, tonumber(parts[4]) or 0)
		elseif valueType == "UDim" then
			local parts = string.split(valueStr, ",")
			return UDim.new(tonumber(parts[1]) or 0, tonumber(parts[2]) or 0)
		end
		return nil
	end

	local function handleGetChildren(path)
		local inst = resolveInstance(path)
		if not inst then return {ok = false, error = "Instance not found"} end
		local children = {}
		for _, child in ipairs(inst:GetChildren()) do
			local ok, name = pcall(function() return child.Name end)
			if ok and not name:match("^_DPP_") then
				local okClass, className = pcall(function() return child.ClassName end)
				if okClass then
					local hasChildren = false
					pcall(function() hasChildren = #child:GetChildren() > 0 end)
					table.insert(children, {
						Name = name,
						ClassName = className,
						Path = child:GetFullName(),
						HasChildren = hasChildren
					})
				end
			end
		end
		return {ok = true, children = children}
	end

	local function handleGetProperties(path)
		local inst = resolveInstance(path)
		if not inst then return {ok = false, error = "Instance not found"} end
		local props = getPropertiesForInstance(inst)
		return {ok = true, properties = props}
	end

	local function handleSetProperty(path, name, value, valueType)
		local inst = resolveInstance(path)
		if not inst then return {ok = false, error = "Instance not found"} end
		local parsedVal = parsePropertyValue(value, valueType)
		if parsedVal == nil and valueType ~= "string" then
			return {ok = false, error = "Failed to parse value for type: " .. tostring(valueType)}
		end
		local ok, err = pcall(function()
			(inst :: any)[name] = parsedVal
		end)
		if not ok then
			return {ok = false, error = tostring(err)}
		end
		return {ok = true}
	end

	local function handleRunScript(source, path)
		local contextInst = path and resolveInstance(path) or nil
		local fn, err = env.loadstring(source)
		if not fn then
			return {ok = false, error = "Compile error: " .. tostring(err)}
		end
		if contextInst then
			local fnEnv = getfenv(fn)
			fnEnv.owner = contextInst
			fnEnv.context = contextInst
		end
		task.spawn(fn)
		return {ok = true}
	end

	local function setupClientWebSocket()
		local ws_connect = getWebSocketConnect()
		if not ws_connect then
			warn("DEX++ WS Client: Executor does not support WebSockets.")
			return
		end

		task.spawn(function()
			local serviceInst = game:GetService("HttpService")
			local port = Settings.Decompiler.HelperServerPort or 8080
			local url = "ws://localhost:" .. tostring(port) .. "/client-ws?placeId=" .. tostring(game.PlaceId)

			local socket = nil
			local function connect()
				local ok, res = pcall(ws_connect, url)
				if ok and res then
					socket = res
					print("DEX++ WS Client: Connected to Helper Server.")

					if env.HelperServer then
						env.HelperServer.SendWSMessage = function(msgTable)
							if socket then
								local okEnc, enc = pcall(serviceInst.JSONEncode, serviceInst, msgTable)
								if okEnc then
									local sent = pcall(function() socket:Send(enc) end)
									if not sent then
										pcall(function() socket.Send(socket, enc) end)
									end
									return true
								end
							end
							return false
						end
					end

					local conn1, conn2, conn3
					local function disconnect()
						if conn1 then pcall(function() conn1:Disconnect() end) pcall(function() conn1:disconnect() end) end
						if conn2 then pcall(function() conn2:Disconnect() end) pcall(function() conn2:disconnect() end) end
						if conn3 then pcall(function() conn3:Disconnect() end) pcall(function() conn3:disconnect() end) end
						socket = nil
						if env.HelperServer then
							env.HelperServer.SendWSMessage = nil
						end
						task.wait(5)
						connect()
					end

					conn1 = connectSignal(socket.OnClose, disconnect)
					conn2 = connectSignal(socket.OnError, disconnect)
					conn3 = connectSignal(socket.OnMessage, function(msg)
						local okMsg, data = pcall(serviceInst.JSONDecode, serviceInst, msg)
						if okMsg and data and data.action then
							local response = { id = data.id }
							if data.action == "get_children" then
								local res = handleGetChildren(data.path)
								for k, v in pairs(res) do response[k] = v end
							elseif data.action == "get_properties" then
								local res = handleGetProperties(data.path)
								for k, v in pairs(res) do response[k] = v end
							elseif data.action == "set_property" then
								local res = handleSetProperty(data.path, data.name, data.value, data.valueType)
								for k, v in pairs(res) do response[k] = v end
							elseif data.action == "run_script" then
								local res = handleRunScript(data.source, data.path)
								for k, v in pairs(res) do response[k] = v end
							end

							local okEnc, enc = pcall(serviceInst.JSONEncode, serviceInst, response)
							if okEnc then
								pcall(function() socket:Send(enc) end)
								pcall(function() socket.Send(socket, enc) end)
							end
						end
					end)
				else
					task.wait(5)
					connect()
				end
			end

			connect()
		end)
	end

	setupClientWebSocket()
end

return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
