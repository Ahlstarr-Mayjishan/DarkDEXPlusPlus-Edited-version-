--!strict
--[[
	DEX++ Helper Client Module
	Manages interface and communication with local C++ Helper Server.
	Includes tool state reporting and status polling.
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
	Main.ToolState = {}
	Main.ToolStatePostQueued = false
	Main.ToolStateLastPost = 0

	Main.ReportToolState = function(name, state)
		if type(name) ~= "string" or type(state) ~= "table" then return end
		local old = Main.ToolState[name] or {}
		for k, v in pairs(state) do
			old[k] = v
		end
		old.UpdatedAt = os.clock()
		old.UpdatedWallAt = os.time()
		Main.ToolState[name] = old
		if Main.ScheduleToolStatePost then
			Main.ScheduleToolStatePost()
		end
	end

	Main.GetToolStates = function()
		return Main.ToolState
	end

	env.HelperServer = (function()
		local helper = {
			LastStatus = "unknown",
			LastChecked = 0,
			FailCount = 0,
			DisabledUntil = 0,
			SendWSMessage = nil :: ((msgTable: any) -> boolean)?
		}

		local function getBaseUrl()
			local port = Settings.Decompiler.HelperServerPort or 8080
			return "http://localhost:" .. tostring(port)
		end

		local function helperEnabled()
			return Settings
				and Settings.Decompiler
				and Settings.Decompiler.UseLocalHelper == true
		end

		function helper.Request(path, method, body, contentType, timeoutSeconds, allowWhenDisabled)
			if not helperEnabled() and not allowWhenDisabled then return nil, "local helper disabled" end
			local now = os.clock()
			if helper.DisabledUntil > now then
				return nil, "local helper temporarily disabled"
			end
			local req = env.request or (syn and syn.request) or (http and http.request) or http_request or request
			if not req then return nil, "request API unavailable" end

			local ok, result = pcall(req, {
				Url = getBaseUrl() .. path,
				Method = method or "GET",
				Headers = {
					["Content-Type"] = contentType or "text/plain",
					["X-Place-ID"] = tostring(game.PlaceId)
				},
				Body = body,
				Timeout = timeoutSeconds or Settings.Decompiler.HelperRequestTimeout or 2,
			})
			if not ok or not result then
				helper.FailCount += 1
				if helper.FailCount >= 3 then
					helper.DisabledUntil = os.clock() + 10
					helper.LastStatus = "offline"
				end
				return nil, tostring(result)
			end
			helper.FailCount = 0
			return result, nil
		end

		function helper.IsActive(force)
			if not helperEnabled() then
				helper.LastStatus = "disabled"
				return false
			end
			if not force and os.clock() - helper.LastChecked < 5 then
				return helper.LastStatus == "active"
			end
			helper.LastChecked = os.clock()
			local result = helper.Request("/status", "GET")
			helper.LastStatus = (result and result.StatusCode == 200) and "active" or "offline"
			return helper.LastStatus == "active"
		end

		function helper.NormalizeSource(source)
			local result = helper.Request("/normalize-source", "POST", source, "text/plain")
			if result and result.StatusCode == 200 and type(result.Body) == "string" then
				return result.Body
			end
			return nil
		end

		function helper.Deobfuscate(source)
			return helper.NormalizeSource(source)
		end

		function helper.AnalyzeSource(source)
			local result = helper.Request("/analyze-source", "POST", source, "text/plain")
			if result and result.StatusCode == 200 and type(result.Body) == "string" then
				return result.Body
			end
			return nil
		end

		function helper.IndexSource(key, path, name, className, source)
			local body = table.concat({
				tostring(key or ""),
				tostring(path or ""),
				tostring(name or ""),
				tostring(className or ""),
				tostring(source or "")
			}, "\n")
			local result = helper.Request("/index-source", "POST", body, "text/plain")
			if result and result.StatusCode == 200 and type(result.Body) == "string" then
				return result.Body
			end
			return nil
		end

		function helper.SearchSource(query, limit)
			local body = tostring(limit or 80) .. "\n" .. tostring(query or "")
			local result = helper.Request("/search-source", "POST", body, "text/plain")
			if result and result.StatusCode == 200 and type(result.Body) == "string" then
				return result.Body
			end
			return nil
		end

		function helper.IndexStatus()
			local result = helper.Request("/index-status", "GET")
			if result and result.StatusCode == 200 and type(result.Body) == "string" then
				return result.Body
			end
			return nil
		end

		function helper.ClearSourceIndex()
			local result = helper.Request("/index-clear", "POST", "", "text/plain")
			return result and result.StatusCode == 200
		end

		function helper.SaveSourceIndex()
			local result = helper.Request("/index-save", "POST", "", "text/plain")
			if result and result.StatusCode == 200 and type(result.Body) == "string" then
				return result.Body
			end
			return nil
		end

		function helper.LoadSourceIndex()
			local result = helper.Request("/index-load", "POST", "", "text/plain")
			if result and result.StatusCode == 200 and type(result.Body) == "string" then
				return result.Body
			end
			return nil
		end

		function helper.AssignRole(task)
			local result = helper.Request("/assign-role", "POST", tostring(task or ""), "text/plain")
			if result and result.StatusCode == 200 and type(result.Body) == "string" then
				return result.Body
			end
			return nil
		end

		function helper.Decompile(bytecode)
			local timeout = Settings.Decompiler.HelperDecompileTimeout or 15
			local result = helper.Request("/decompile", "POST", bytecode, "application/octet-stream", timeout)
			if result and result.StatusCode == 200 and type(result.Body) == "string" then
				return result.Body
			end
			return nil
		end

		function helper.PostToolState(json)
			local result = helper.Request("/tool-state", "POST", tostring(json or "{}"), "application/json", 1, true)
			return result and result.StatusCode == 200
		end

		function helper.Log(line)
			local result = helper.Request("/log", "POST", tostring(line), "text/plain")
			return result and result.StatusCode == 200
		end

		return helper
	end)()

	task.spawn(function()
		local ok, info = pcall(function()
			local marketplace = service.MarketplaceService or game:GetService("MarketplaceService")
			return marketplace:GetProductInfo(game.PlaceId)
		end)
		if ok and type(info) == "table" then
			local resolvedName = info.Name or info.AssetName
			if type(resolvedName) == "string" and resolvedName ~= "" then
				Main.GameContext.Name = resolvedName
			end
			Main.GameContext.Creator = info.Creator and info.Creator.Name or nil
		end
		if Main.ScheduleToolStatePost then
			Main.ScheduleToolStatePost()
		end
	end)

	Main.BuildHelperToolState = function()
		local payload = {
			ok = true,
			updatedAt = os.time(),
			version = Main.Version,
			session = {
				state = "connected",
				startedAt = Main.StartedAt or os.time(),
				executor = Main.Executor or "unknown",
			},
			game = Main.GameContext,
			settings = {
				useLocalHelper = Settings.Decompiler and Settings.Decompiler.UseLocalHelper == true,
				lowImpact = Settings.Decompiler and Settings.Decompiler.CodeSearchLowImpact ~= false,
				fastCacheRead = Settings.Decompiler and Settings.Decompiler.FastCacheRead == true,
			},
			tools = Main.ToolState or {},
		}
		local ok, encoded = pcall(service.HttpService.JSONEncode, service.HttpService, payload)
		return ok and encoded or nil
	end

	Main.PushToolStateToHelper = function()
		if not env.HelperServer or not env.HelperServer.PostToolState then return false end
		local encoded = Main.BuildHelperToolState and Main.BuildHelperToolState()
		if not encoded then return false end
		return env.HelperServer.PostToolState(encoded)
	end

	Main.ScheduleToolStatePost = function()
		if Main.ToolStatePostQueued then return end
		Main.ToolStatePostQueued = true
		local delayTime = math.max(0, 0.5 - (os.clock() - (Main.ToolStateLastPost or 0)))
		task.delay(delayTime, function()
			Main.ToolStatePostQueued = false
			Main.ToolStateLastPost = os.clock()
			pcall(Main.PushToolStateToHelper)
		end)
	end

	Main.ReportToolState("DEX Session", {
		State = "connected",
		Load = "low",
		Version = Main.Version,
		PlaceId = tostring(game.PlaceId or ""),
		GameId = tostring(game.GameId or ""),
		JobId = tostring(game.JobId or ""),
	})
end

return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
