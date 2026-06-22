--!strict
--[[
	DEX++ Bypasses Module
	Includes bypassing systems for Adonis and Stealth Explorer spoofers.
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
	local function InitAdonisBypass()
		if not getreg or not getgc or not isfunctionhooked then
			warn("Executor does not support Adonis bypass functions.")
			return false
		end

		local AdonisAnticheatThreads = {}
		for _, thread in getreg() do
			if typeof(thread) ~= "thread" then continue end
			local Source = debug.info(thread, 1, "s")
			if Source and (Source:match(".Core.Anti") or Source:match(".Plugins.Anti_Cheat")) then
				table.insert(AdonisAnticheatThreads, thread)
			end
		end

		for _, thread in AdonisAnticheatThreads do
			pcall(coroutine.close, thread)
		end

		local AdonisTables = {}
		if filtergc then
			local ContendorAdonisTables = filtergc("table", { Keys = { "Detected", "RLocked" } }, false)
			for _, AdonisTable in ContendorAdonisTables do
				if typeof(rawget(AdonisTable, "Detected")) == "function" then
					table.insert(AdonisTables, AdonisTable)
				end
			end
		else
			for _, Table in getgc(true) do
				if typeof(Table) == "table" and typeof(rawget(Table, "Detected")) == "function" and rawget(Table, "RLocked") then
					table.insert(AdonisTables, Table)
				end
			end
		end

		for _, AdonisTable in AdonisTables do
			for _, DetectionFunc in AdonisTable do
				if typeof(DetectionFunc) == "function" and not isfunctionhooked(DetectionFunc) then
					hookfunction(DetectionFunc, function()
						coroutine.yield()
						return task.wait(9e9)
					end)
				end
			end
		end
		return true
	end

	local function setupStealthBypass()
		local spoofEnabled = Settings and Settings.Explorer and Settings.Explorer.AntiCheatSpoofing == true
		if not spoofEnabled then return end
		if not hookmetamethod and not hookfunction then return end

		local secureContainer = Main.GetSecureContainer()
		local function isDexObject(obj)
			local ok, name = pcall(function() return obj.Name end)
			if not ok or type(name) ~= "string" then return false end
			return string.sub(name, 1, 5) == "_DPP_"
		end

		-- 1. Hook __namecall
		if hookmetamethod then
			local oldNamecall
			oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
				local method = getnamecallmethod()
				if not checkcaller() then
					if self == secureContainer or self == game or self == workspace then
						if method == "GetChildren" or method == "getChildren" then
							local realChildren = oldNamecall(self, ...)
							local filtered = {}
							for _, child in ipairs(realChildren) do
								if not isDexObject(child) then
									table.insert(filtered, child)
								end
							end
							return filtered
						elseif method == "GetDescendants" or method == "getDescendants" then
							local realDescendants = oldNamecall(self, ...)
							local filtered = {}
							for _, desc in ipairs(realDescendants) do
								if not isDexObject(desc) then
									table.insert(filtered, desc)
								end
							end
							return filtered
						end
					end
					if method == "FindFirstChild" or method == "findFirstChild" then
						local name = ...
						if type(name) == "string" and string.sub(name, 1, 5) == "_DPP_" then
							return nil
						end
					end
				end
				return oldNamecall(self, ...)
			end)
		end

		-- 2. Hook Instance.GetChildren / Instance.GetDescendants / Instance.FindFirstChild
		if hookfunction then
			local folder = Instance.new("Folder")
			local oldGetChildren
			oldGetChildren = hookfunction(folder.GetChildren, function(self, ...)
				local children = oldGetChildren(self, ...)
				if not checkcaller() and (self == secureContainer or self == game or self == workspace) then
					local filtered = {}
					for _, child in ipairs(children) do
						if not isDexObject(child) then
							table.insert(filtered, child)
						end
					end
					return filtered
				end
				return children
			end)

			local oldGetDescendants
			oldGetDescendants = hookfunction(folder.GetDescendants, function(self, ...)
				local descendants = oldGetDescendants(self, ...)
				if not checkcaller() and (self == secureContainer or self == game or self == workspace) then
					local filtered = {}
					for _, desc in ipairs(descendants) do
						if not isDexObject(desc) then
							table.insert(filtered, desc)
						end
					end
					return filtered
				end
				return descendants
			end)

			local oldFindFirstChild
			oldFindFirstChild = hookfunction(folder.FindFirstChild, function(self, name, ...)
				if not checkcaller() and type(name) == "string" and string.sub(name, 1, 5) == "_DPP_" then
					return nil
				end
				return oldFindFirstChild(self, name, ...)
			end)
		end
	end

	InitAdonisBypass()
	setupStealthBypass()
end

return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
