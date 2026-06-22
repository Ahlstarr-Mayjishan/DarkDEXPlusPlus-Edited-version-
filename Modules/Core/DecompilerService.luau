--!strict
--[[
	DEX++ Decompiler Service Module
	Manages the script decompiler fallback queue, decompile cache, and expert API requests.
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
	local luaexpert_last_call = 0

	local function LuaExpertDec(script_instance)
		local success, bytecode = pcall(env.getscriptbytecode, script_instance)

		if (not success) then
			return "-- Failed to get script bytecode, error:\n\n--[[\n" .. tostring(bytecode) .. "\n--]]"
		end

		local time_elapsed = os.clock() - luaexpert_last_call
		if time_elapsed <= 0.6 then
			task.wait(0.6 - time_elapsed)
		end

		local encoder = getgenv().base64_encode or (getgenv().crypt and getgenv().crypt.base64encode) or (getgenv().crypt and getgenv().crypt.base64 and getgenv().crypt.base64.encode)
		if not encoder then
			encoder = function(data)
				local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
				return ((data:gsub('.', function(x)
					local r,byte = '',x:byte()
					for i=8,1,-1 do r = r .. (byte % 2^i - byte % 2^(i-1) > 0 and '1' or '0') end
					return r
				end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
					if #x < 6 then return '' end
					local c = 0
					for i=1,6 do c = c + (x:sub(i,i) == '1' and 2^(6-i) or 0) end
					return b:sub(c+1,c+1)
				end)..({ '', '==', '=' })[#data % 3 + 1])
			end
		end

		local HttpService = game:GetService("HttpService")
		local req = env.request or (syn and syn.request) or (http and http.request) or http_request or request

		local httpResult = req({
			Url = "https://api.lua.expert/decompile",
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json"
			},
			Body = HttpService:JSONEncode({
				script = encoder(bytecode)
			})
		})

		luaexpert_last_call = os.clock()

		if (not httpResult or httpResult.StatusCode ~= 200) then
			return "-- Error occurred while requesting lua.expert API, error:\n\n--[[\n" .. tostring(httpResult and httpResult.Body or "No response") .. "\n--]]"
		else
			return httpResult.Body
		end
	end

	local nativeDecompile = getgenv().decompile or (getgenv().syn and getgenv().syn.decompile)

	local function hashString(data: string): string
		if type(data) ~= "string" then return "" end

		local crypt = getgenv().crypt or (getgenv().syn and getgenv().syn.crypt)
		if crypt and type(crypt.hash) == "function" then
			local success, result = pcall(crypt.hash, data, "sha1")
			if success and result then
				return result
			end
		end

		-- Fast sample-based hashing in Luau
		local hash = 2166136261
		local len = #data
		if len > 2000 then
			for i = 1, 500 do
				hash = (hash * 131 + data:byte(i)) % 4294967296
			end
			local mid = math.floor(len / 2)
			for i = mid - 250, mid + 250 do
				hash = (hash * 131 + data:byte(i)) % 4294967296
			end
			for i = len - 500, len do
				hash = (hash * 131 + data:byte(i)) % 4294967296
			end
			hash = (hash * 131 + len) % 4294967296
		else
			for i = 1, len do
				hash = (hash * 131 + data:byte(i)) % 4294967296
			end
		end
		return ("%08x"):format(hash)
	end

	local decompileFailures = {
		{Code = "empty_source", Text = "empty source", Patterns = {"empty bytecode", "empty bytecode payload", "empty response"}},
		{Code = "deserialization", Text = "bytecode deserialization or parsing failed", Patterns = {"deserialization failed", "parsing error", "code: eof", "unexpected end of file"}},
		{Code = "unsupported_version", Text = "unsupported Luau bytecode version", Patterns = {"unsupported bytecode version"}},
		{Code = "bytecode_unavailable", Text = "executor could not extract script bytecode", Patterns = {"getscriptbytecode is not supported", "failed to get script bytecode"}},
		{Code = "transport", Text = "decompiler connection or HTTP request failed", Patterns = {"error occurred while requesting", "could not connect to potassium decompiler", "failed to send request", "incomplete request send", "invalid http response", "non-200 status"}},
		{Code = "decompiler_error", Text = "decompiler rejected the bytecode", Patterns = {"failed to decompile", "decompile failed:", "-- error:"}},
	}

	local function getDecompileFailure(source: string)
		if type(source) ~= "string" or source:match("%S") == nil then
			return {Code = "empty_source", Text = "decompiler returned no source"}
		end
		local lowered = source:lower()
		for _, failure in ipairs(decompileFailures) do
			for _, pattern in ipairs(failure.Patterns) do
				if lowered:find(pattern, 1, true) then
					return {Code = failure.Code, Text = failure.Text, Raw = source}
				end
			end
		end
		return nil
	end

	local function isCacheableSource(source: string)
		return getDecompileFailure(source) == nil
	end

	env.GetDecompileFailure = getDecompileFailure
	env.IsValidDecompileSource = isCacheableSource

	local function createDecompileCache()
		local cache = {}
		local HttpService = game:GetService("HttpService")
		local rootDir = "dex/DecompileCache"
		local gameIdStr = (game.GameId and game.GameId ~= 0) and tostring(game.GameId) or "UnknownGame"
		local sharedSourcesDir = rootDir .. "/" .. gameIdStr .. "/shared_sources"
		local placeDir = rootDir .. "/" .. gameIdStr .. "/" .. tostring(game.PlaceId)
		local metadataPath = placeDir .. "/metadata.json"
		local metadataLoaded = false
		local metadata = {PlaceId = tostring(game.PlaceId), Scripts = {}}

		local function isReady()
			return env.readfile and env.writefile and env.isfile and env.isfolder and env.makefolder
		end

		local function ensureFolder(path)
			if env.isfolder and not env.isfolder(path) then
				pcall(env.makefolder, path)
			end
		end

		local function ensureCacheFolders()
			if not isReady() then return false end
			ensureFolder("dex")
			ensureFolder(rootDir)
			ensureFolder(rootDir .. "/" .. gameIdStr)
			ensureFolder(sharedSourcesDir)
			ensureFolder(placeDir)
			return true
		end

		local function loadMetadata()
			if metadataLoaded then return end
			metadataLoaded = true
			metadata = {PlaceId = tostring(game.PlaceId), Scripts = {}}
			if not ensureCacheFolders() or not env.isfile(metadataPath) then return end

			local success, raw = pcall(env.readfile, metadataPath)
			if not success or type(raw) ~= "string" or raw == "" then return end

			local decodedSuccess, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
			if decodedSuccess and type(decoded) == "table" then
				metadata = decoded
				metadata.PlaceId = metadata.PlaceId or tostring(game.PlaceId)
				metadata.Scripts = metadata.Scripts or {}
			end
		end

		local function saveMetadata()
			loadMetadata()
			if not ensureCacheFolders() then return false end
			(metadata :: any).UpdatedAt = os.time()

			local encodedSuccess, encoded = pcall(HttpService.JSONEncode, HttpService, metadata)
			if not encodedSuccess then return false end

			local writeSuccess = pcall(env.writefile, metadataPath, encoded)
			return writeSuccess
		end

		local function getScriptPath(script_instance)
			local success, path = pcall(function()
				local parts = {}
				local current = script_instance
				while current and current ~= game do
					local name = current.Name
					local parent = current.Parent
					if parent then
						local dupIndex = 1
						local hasDups = false
						for _, sibling in ipairs(parent:GetChildren()) do
							if sibling.Name == name and sibling.ClassName == current.ClassName then
								if sibling == current then
									hasDups = true
									break
								end
								dupIndex += 1
							end
						end
						if hasDups then
							local totalDups = 0
							for _, sibling in ipairs(parent:GetChildren()) do
								if sibling.Name == name and sibling.ClassName == current.ClassName then
									totalDups += 1
								end
							end
							if totalDups > 1 then
								name = name .. "[" .. tostring(dupIndex) .. "]"
							end
						end
					end
					table.insert(parts, 1, name)
					current = parent
				end
				return table.concat(parts, ".")
			end)
			return success and path or tostring(script_instance)
		end

		local function getScriptKey(script_instance)
			local path = getScriptPath(script_instance)
			return hashString(tostring(script_instance.ClassName) .. "|" .. path)
		end

		local function getBytecodeHash(script_instance)
			if typeof(env.getscriptbytecode) ~= "function" then return nil end
			local success, bytecode = pcall(env.getscriptbytecode, script_instance)
			if not success or type(bytecode) ~= "string" or bytecode == "" then return nil end
			return hashString(bytecode)
		end

		local function getInfo(script_instance, skipHash)
			if typeof(script_instance) ~= "Instance" then return nil end
			local key = getScriptKey(script_instance)
			return {
				Key = key,
				Hash = skipHash and nil or getBytecodeHash(script_instance),
				File = key .. ".lua",
				Path = getScriptPath(script_instance),
				Name = script_instance.Name,
				ClassName = script_instance.ClassName
			}
		end

		cache.IsReady = isReady
		cache.GetDirectory = function()
			ensureCacheFolders()
			return placeDir
		end
		cache.GetMetadataPath = function()
			ensureCacheFolders()
			return metadataPath
		end
		cache.GetScriptKey = getScriptKey
		cache.GetInfo = getInfo
		cache.GetEntries = function()
			loadMetadata()
			return metadata.Scripts, placeDir
		end
		cache.HasCachedFile = function(script_instance)
			loadMetadata()
			if not ensureCacheFolders() then return false end
			local info = getInfo(script_instance, true)
			if not info then return false end
			local entry = metadata.Scripts[info.Key]
			if not entry then return false end
			local path = placeDir .. "/" .. tostring(entry.File or info.File)
			return env.isfile(path)
		end
		cache.HasFresh = function(script_instance)
			loadMetadata()
			if not ensureCacheFolders() then return false end

			local info = getInfo(script_instance)
			if not info then return false end

			local entry = metadata.Scripts[info.Key]
			if not entry then
				if info.Hash then
					local sharedPath = sharedSourcesDir .. "/" .. info.Hash .. ".lua"
					return env.isfile(sharedPath)
				end
				return false
			end
			if info.Hash and entry.Hash and entry.Hash ~= info.Hash then
				local sharedPath = sharedSourcesDir .. "/" .. info.Hash .. ".lua"
				return env.isfile(sharedPath)
			end

			local path = placeDir .. "/" .. tostring(entry.File or info.File)
			return env.isfile(path)
		end
		cache.HasFreshFast = function(script_instance)
			loadMetadata()
			if not ensureCacheFolders() then return false end

			local info = getInfo(script_instance, true)
			if not info then return false end

			local entry = metadata.Scripts[info.Key]
			if not entry then return false end

			local path = placeDir .. "/" .. tostring(entry.File or info.File)
			return env.isfile(path)
		end
		cache.Read = function(script_instance)
			loadMetadata()
			if not ensureCacheFolders() then return nil, "Filesystem APIs are unavailable." end

			local info = getInfo(script_instance, Settings.Decompiler and Settings.Decompiler.FastCacheRead == true)
			if not info then return nil, "Script cache info is unavailable." end

			local entry = metadata.Scripts[info.Key]
			local sharedPath = info.Hash and (sharedSourcesDir .. "/" .. info.Hash .. ".lua") or nil

			if entry then
				if info.Hash and entry.Hash and entry.Hash ~= info.Hash then
					if sharedPath and env.isfile(sharedPath) then
						local success, source = pcall(env.readfile, sharedPath)
						if success and isCacheableSource(source) then
							metadata.Scripts[info.Key] = {
								Hash = info.Hash,
								File = "../shared_sources/" .. info.Hash .. ".lua",
								Path = info.Path,
								Name = info.Name,
								ClassName = info.ClassName,
								UpdatedAt = os.time()
							}
							saveMetadata()
							return source, metadata.Scripts[info.Key]
						end
					end
				else
					local path = placeDir .. "/" .. tostring(entry.File or info.File)
					if env.isfile(path) then
						local success, source = pcall(env.readfile, path)
						if success and isCacheableSource(source) then
							return source, entry
						end
					end
				end
			end

			if sharedPath and env.isfile(sharedPath) then
				local success, source = pcall(env.readfile, sharedPath)
				if success and isCacheableSource(source) then
					metadata.Scripts[info.Key] = {
						Hash = info.Hash,
						File = "../shared_sources/" .. info.Hash .. ".lua",
						Path = info.Path,
						Name = info.Name,
						ClassName = info.ClassName,
						UpdatedAt = os.time()
					}
					saveMetadata()
					return source, metadata.Scripts[info.Key]
				end
			end

			return nil, "Cached source is empty or contains a decompiler failure."
		end
		cache.Write = function(script_instance, source)
			if not isCacheableSource(source) then return false end
			if not ensureCacheFolders() then return false end

			local info = getInfo(script_instance)
			if not info then return false end

			local fileRef
			if info.Hash then
				local path = sharedSourcesDir .. "/" .. info.Hash .. ".lua"
				local writeSuccess = pcall(env.writefile, path, source)
				if not writeSuccess then return false end
				fileRef = "../shared_sources/" .. info.Hash .. ".lua"
			else
				local path = placeDir .. "/" .. info.File
				local writeSuccess = pcall(env.writefile, path, source)
				if not writeSuccess then return false end
				fileRef = info.File
			end

			loadMetadata()
			metadata.Scripts[info.Key] = {
				Hash = info.Hash,
				File = fileRef,
				Path = info.Path,
				Name = info.Name,
				ClassName = info.ClassName,
				UpdatedAt = os.time()
			}
			return saveMetadata()
		end

		return cache
	end

	env.DecompileCache = createDecompileCache()

	local function decompileUncached(script_instance, ...)
		local helperPreferred = Settings.Decompiler.UseLocalHelper == true
			and Settings.Decompiler.PreferLocalHelperDecompiler ~= false
			and env.HelperServer
			and env.HelperServer.Decompile
			and typeof(env.getscriptbytecode) == "function"

		if helperPreferred then
			local success, bytecode = pcall(env.getscriptbytecode, script_instance)
			if success and type(bytecode) == "string" and bytecode ~= "" then
				local decompiled = env.HelperServer.Decompile(bytecode)
				if isCacheableSource(decompiled) then
					return decompiled
				end
			end
		end

		local tryNative = not Settings.Decompiler.PreferDecompilerFallback

		if nativeDecompile and tryNative then
			local success, result = pcall(nativeDecompile, script_instance, ...)
			if success and isCacheableSource(result) then
				return tostring(result)
			end
		end

		if typeof(env.getscriptbytecode) == "function" then
			if not helperPreferred and Settings.Decompiler.UseLocalHelper == true and env.HelperServer and env.HelperServer.Decompile then
				local success, bytecode = pcall(env.getscriptbytecode, script_instance)
				if success and bytecode then
					local decompiled = env.HelperServer.Decompile(bytecode)
					if isCacheableSource(decompiled) then
						return decompiled
					end
				end
			end
			if Settings.Decompiler.DecompilerFallback == "Shiny" then
				local success, bytecode = pcall(env.getscriptbytecode, script_instance)
				if success and bytecode then
					local encoder = getgenv().base64_encode or (getgenv().crypt and getgenv().crypt.base64encode) or (getgenv().crypt and getgenv().crypt.base64 and getgenv().crypt.base64.encode)
					local encodedBytecode = encoder and encoder(bytecode) or bytecode

					local req = env.request or request
					local s, res = pcall(req, {
						Url = "http://localhost:" .. tostring(Settings.Decompiler.ShinyDecompilerPort) .. "/decompile",
						Method = "POST",
						Headers = {
							["Content-Type"] = "application/json"
						},
						Body = game:GetService("HttpService"):JSONEncode({
							script = encodedBytecode
						})
					})
					if s and res and res.StatusCode == 200 and isCacheableSource(res.Body) then
						return res.Body
					end
				end
			end

			return LuaExpertDec(script_instance)
		else
			if nativeDecompile then
				local success, result = pcall(nativeDecompile, script_instance, ...)
				if success and isCacheableSource(result) then
					return tostring(result)
				end
			end
			return "-- getscriptbytecode is not supported by your executor and native decompiler failed."
		end
	end

	local function decompileWithCache(script_instance, ...)
		local cache = env.DecompileCache
		if cache then
			local cachedSource = cache.Read(script_instance)
			if cachedSource then
				return cachedSource
			end
		end

		local source = decompileUncached(script_instance, ...)
		if cache then
			pcall(cache.Write, script_instance, source)
		end
		return source
	end

	local function createDecompileQueue()
		local queue = {
			Jobs = {} :: {any},
			Running = false,
			Paused = false,
			ActiveJob = nil :: any,
			LastRun = 0,
			Completed = 0,
			Failed = 0,
		}

		local function getMinDelay()
			local tryNative = not Settings.Decompiler.PreferDecompilerFallback
			if nativeDecompile and tryNative then
				return 0.002
			elseif Settings.Decompiler.DecompilerFallback == "Shiny" then
				return 0.02
			else
				return 0.15
			end
		end

		local function sortJobs()
			table.sort(queue.Jobs, function(a, b)
				if a.Priority == b.Priority then
					return a.CreatedAt < b.CreatedAt
				end
				return a.Priority > b.Priority
			end)
		end

		local function startWorker()
			if queue.Running then return end
			queue.Running = true
			task.spawn(function()
				while #queue.Jobs > 0 do
					if queue.Paused then
						task.wait(0.2)
						continue
					end

					sortJobs()
					local job = table.remove(queue.Jobs, 1)
					queue.ActiveJob = job

					local waitTime = getMinDelay() - (os.clock() - queue.LastRun)
					if waitTime > 0 then task.wait(waitTime) end

					local success, result = pcall(decompileWithCache, job.Script, table.unpack(job.Args))
					job.Success = success
					job.Result = result
					job.Done = true
					queue.LastRun = os.clock()
					queue.ActiveJob = nil

					if success then
						queue.Completed += 1
					else
						queue.Failed += 1
					end

					if job.Callback then
						pcall(job.Callback, success, result, job.Script)
					end

					task.wait()
				end
				queue.Running = false
			end)
		end

		queue.Submit = function(script_instance, options, ...)
			options = options or {}
			local job = {
				Script = script_instance,
				Args = {...},
				Priority = options.Priority or 50,
				CreatedAt = os.clock(),
				Callback = options.Callback,
				Done = false,
				Success = false,
				Result = nil :: any,
			}

			table.insert(queue.Jobs, job)
			startWorker()

			if options.Async then
				return job
			end

			while not job.Done do
				task.wait()
			end

			if not job.Success then
				error(job.Result)
			end
			return job.Result
		end

		queue.GetStatus = function()
			return {
				Queued = #queue.Jobs,
				Running = queue.Running,
				Paused = queue.Paused,
				Active = queue.ActiveJob and queue.ActiveJob.Script or nil,
				Completed = queue.Completed,
				Failed = queue.Failed,
			}
		end

		queue.SetPaused = function(paused)
			queue.Paused = paused and true or false
			if not queue.Paused then startWorker() end
		end

		queue.CancelQueued = function()
			for _, job in pairs(queue.Jobs) do
				job.Done = true
				job.Success = false
				job.Result = "Cancelled"
			end
			table.clear(queue.Jobs)
		end

		return queue
	end

	env.DecompileQueue = createDecompileQueue()

	env.decompile = function(script_instance, ...)
		return env.DecompileQueue.Submit(script_instance, {Priority = 50}, ...)
	end

	env.decompilebackground = function(script_instance, callback, priority, ...)
		return env.DecompileQueue.Submit(script_instance, {Priority = priority or 10, Callback = callback, Async = true}, ...)
	end

	if Main.Elevated then
		getgenv().decompile = env.decompile
	end
end

return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
