--!strict
--[[
	DEX++ Hook Manager Module
	Manages metamethod/function hooking and Roblox connection tracking.
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
	local raw_hookmetamethod = getgenv().hookmetamethod
	local raw_hookfunction = getgenv().hookfunction

	Main.HookRegistry = {
		Metatable = {},
		Functions = {},
		Connections = {}
	}

	local function table_clear(t)
		for k in pairs(t) do
			t[k] = nil
		end
	end

	local function rebuildMetatableChain(metamethod)
		local reg = Main.HookRegistry.Metatable[metamethod]
		if not reg then return end

		if #reg.hooks > 0 then
			reg.active_hook = reg.hooks[#reg.hooks].hook_fn
		else
			reg.active_hook = reg.original
		end
	end

	local function rebuildFunctionChain(target)
		local reg = Main.HookRegistry.Functions[target]
		if not reg then return end

		if #reg.hooks > 0 then
			reg.active_hook = reg.hooks[#reg.hooks].hook_fn
		else
			reg.active_hook = reg.original
		end
	end

	Main.HookMetamethod = function(target, metamethod, key, hook_fn)
		local reg = Main.HookRegistry.Metatable[metamethod]
		if not reg then
			local original
			local master_hook = function(...)
				local r = Main.HookRegistry.Metatable[metamethod]
				if r and r.active_hook then
					return r.active_hook(...)
				end
				return original(...)
			end

			if not raw_hookmetamethod then
				warn("Failed to hook metamethod: hookmetamethod is nil")
				return nil
			end

			local ok, result = pcall(raw_hookmetamethod, target, metamethod, master_hook)
			if ok and result then
				original = result
				reg = {
					original = original,
					hooks = {},
					active_hook = original
				}
				Main.HookRegistry.Metatable[metamethod] = reg
			else
				warn("Failed to hook metamethod " .. tostring(metamethod) .. ": " .. tostring(result))
				return nil
			end
		end

		local found = false
		for _, hookData in ipairs(reg.hooks) do
			if hookData.key == key then
				hookData.hook_fn = hook_fn
				found = true
				break
			end
		end
		if not found then
			table.insert(reg.hooks, { key = key, hook_fn = hook_fn })
		end

		rebuildMetatableChain(metamethod)

		local proxy = function(...)
			local r = Main.HookRegistry.Metatable[metamethod]
			if not r then return reg.original(...) end
			local idx
			for i, h in ipairs(r.hooks) do
				if h.key == key then
					idx = i
					break
				end
			end
			if idx and idx > 1 then
				return r.hooks[idx - 1].hook_fn(...)
			else
				return r.original(...)
			end
		end

		return proxy
	end

	Main.UnhookMetamethod = function(metamethod, key)
		local reg = Main.HookRegistry.Metatable[metamethod]
		if not reg then return end

		for i = #reg.hooks, 1, -1 do
			if reg.hooks[i].key == key then
				table.remove(reg.hooks, i)
			end
		end

		rebuildMetatableChain(metamethod)
	end

	Main.HookFunction = function(target, key, hook_fn)
		if not target then return nil end
		local reg = Main.HookRegistry.Functions[target]
		if not reg then
			local original
			local master_hook = function(...)
				local r = Main.HookRegistry.Functions[target]
				if r and r.active_hook then
					return r.active_hook(...)
				end
				return original(...)
			end

			if not raw_hookfunction then
				warn("Failed to hook function: hookfunction is nil")
				return nil
			end

			local ok, result = pcall(raw_hookfunction, target, master_hook)
			if ok and result then
				original = result
				reg = {
					original = original,
					hooks = {},
					active_hook = original
				}
				Main.HookRegistry.Functions[target] = reg
			else
				warn("Failed to hook function: " .. tostring(result))
				return nil
			end
		end

		local found = false
		for _, hookData in ipairs(reg.hooks) do
			if hookData.key == key then
				hookData.hook_fn = hook_fn
				found = true
				break
			end
		end
		if not found then
			table.insert(reg.hooks, { key = key, hook_fn = hook_fn })
		end

		rebuildFunctionChain(target)

		local proxy = function(...)
			local r = Main.HookRegistry.Functions[target]
			if not r then return reg.original(...) end
			local idx
			for i, h in ipairs(r.hooks) do
				if h.key == key then
					idx = i
					break
				end
			end
			if idx and idx > 1 then
				return r.hooks[idx - 1].hook_fn(...)
			else
				return r.original(...)
			end
		end

		return proxy
	end

	Main.UnhookFunction = function(target, key)
		local reg = Main.HookRegistry.Functions[target]
		if not reg then return end

		for i = #reg.hooks, 1, -1 do
			if reg.hooks[i].key == key then
				table.remove(reg.hooks, i)
			end
		end

		rebuildFunctionChain(target)
	end

	Main.RegisterConnection = function(conn)
		if conn then
			table.insert(Main.HookRegistry.Connections, conn)
		end
		return conn
	end

	Main.CleanHooksAndConnections = function()
		for _, conn in ipairs(Main.HookRegistry.Connections) do
			pcall(function() conn:Disconnect() end)
		end
		table_clear(Main.HookRegistry.Connections)

		for metamethod, reg in pairs(Main.HookRegistry.Metatable) do
			table_clear(reg.hooks)
			rebuildMetatableChain(metamethod)
		end

		for target, reg in pairs(Main.HookRegistry.Functions) do
			table_clear(reg.hooks)
			rebuildFunctionChain(target)
			if raw_hookfunction then
				pcall(raw_hookfunction, target, reg.original)
			end
		end
	end

	if raw_hookmetamethod then
		getgenv().hookmetamethod = function(target, metamethod, hook_fn)
			return Main.HookMetamethod(target, metamethod, tostring(hook_fn), hook_fn)
		end
	end

	if raw_hookfunction then
		getgenv().hookfunction = function(target, hook_fn)
			return Main.HookFunction(target, tostring(hook_fn), hook_fn)
		end
	end

	Main.RestoreGlobals = function()
		if raw_hookmetamethod then
			getgenv().hookmetamethod = raw_hookmetamethod
		end
		if raw_hookfunction then
			getgenv().hookfunction = raw_hookfunction
		end
	end
end

return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
