--[[
	History Manager Module
	Handles general action history (Undo / Redo) for DEX++.
]]

-- Common Locals
local Main, Lib, Apps, Settings
local API, RMD, env, service, plr, create, createSimple

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
end

local function main()
	local History = {}
	local undoStack = {}
	local redoStack = {}
	local maxHistorySize = 50

	History.Add = function(action)
		table.insert(undoStack, action)
		if #undoStack > maxHistorySize then
			local evicted = table.remove(undoStack, 1)
			if evicted and evicted.OnDestroy then
				pcall(evicted.OnDestroy)
			end
		end
		-- Clear redo stack whenever a new action is performed
		for _, action in ipairs(redoStack) do
			if action.OnDestroy then
				pcall(action.OnDestroy)
			end
		end
		table.clear(redoStack)
	end

	History.Undo = function()
		if #undoStack == 0 then return end
		local action = table.remove(undoStack)
		local ok, err = pcall(action.Undo)
		if ok then
			table.insert(redoStack, action)
		else
			warn("Undo failed: " .. tostring(err))
		end
		if Apps.Explorer then
			if Apps.Explorer.ForceUpdate then
				Apps.Explorer.ForceUpdate()
			elseif Apps.Explorer.Refresh then
				Apps.Explorer.Refresh()
			end
		end
		if Apps.Properties and Apps.Properties.Update then
			Apps.Properties.Update()
		end
	end

	History.Redo = function()
		if #redoStack == 0 then return end
		local action = table.remove(redoStack)
		local ok, err = pcall(action.Redo)
		if ok then
			table.insert(undoStack, action)
		else
			warn("Redo failed: " .. tostring(err))
		end
		if Apps.Explorer then
			if Apps.Explorer.ForceUpdate then
				Apps.Explorer.ForceUpdate()
			elseif Apps.Explorer.Refresh then
				Apps.Explorer.Refresh()
			end
		end
		if Apps.Properties and Apps.Properties.Update then
			Apps.Properties.Update()
		end
	end

	History.Clear = function()
		for _, action in ipairs(undoStack) do
			if action.OnDestroy then
				pcall(action.OnDestroy)
			end
		end
		for _, action in ipairs(redoStack) do
			if action.OnDestroy then
				pcall(action.OnDestroy)
			end
		end
		table.clear(undoStack)
		table.clear(redoStack)
	end

	return History
end

return {
	InitDeps = initDeps,
	InitAfterMain = initAfterMain,
	Main = main
}
