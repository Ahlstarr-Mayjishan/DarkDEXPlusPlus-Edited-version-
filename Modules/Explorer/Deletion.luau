--[[
	Deletion Core Module
	Handles deleting instances and clearing instance children.
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

local History

local function initAfterMain()
	History = Apps.History
end

local function main()
	local Deletion = {}

	Deletion.Delete = function(selectionList, selection)
		local deletedInstances = {}
		for i = 1, #selectionList do
			local node = selectionList[i]
			if node and node.Obj then
				local obj = node.Obj
				local success, parent = pcall(function() return obj.Parent end)
				if success and parent then
					table.insert(deletedInstances, {
						Obj = obj,
						OriginalParent = parent
					})
				end
			end
		end

		if #deletedInstances == 0 then return end

		local function undo()
			for _, item in ipairs(deletedInstances) do
				pcall(function() item.Obj.Parent = item.OriginalParent end)
				if Apps.Explorer and Apps.Explorer.AddObject then
					pcall(Apps.Explorer.AddObject, item.Obj)
				end
			end
		end

		local function redo()
			for _, item in ipairs(deletedInstances) do
				if Apps.Explorer and Apps.Explorer.RemoveObject then
					pcall(Apps.Explorer.RemoveObject, item.Obj)
				end
				pcall(function() item.Obj.Parent = nil end)
			end
		end

		local function onDestroy()
			for _, item in ipairs(deletedInstances) do
				pcall(game.Destroy, item.Obj)
			end
		end

		redo()

		if History and History.Add then
			History.Add({
				Name = "Delete",
				Undo = undo,
				Redo = redo,
				OnDestroy = onDestroy
			})
		else
			onDestroy()
		end

		if selection and selection.Clear then
			selection:Clear()
		end
	end

	Deletion.DeleteChildren = function(selectionList)
		local deletedInstances = {}
		for i = 1, #selectionList do
			local node = selectionList[i]
			if node and node.Obj then
				local children = node.Obj:GetChildren()
				for _, child in ipairs(children) do
					table.insert(deletedInstances, {
						Obj = child,
						OriginalParent = node.Obj
					})
				end
			end
		end

		if #deletedInstances == 0 then return end

		local function undo()
			for _, item in ipairs(deletedInstances) do
				pcall(function() item.Obj.Parent = item.OriginalParent end)
				if Apps.Explorer and Apps.Explorer.AddObject then
					pcall(Apps.Explorer.AddObject, item.Obj)
				end
			end
		end

		local function redo()
			for _, item in ipairs(deletedInstances) do
				if Apps.Explorer and Apps.Explorer.RemoveObject then
					pcall(Apps.Explorer.RemoveObject, item.Obj)
				end
				pcall(function() item.Obj.Parent = nil end)
			end
		end

		local function onDestroy()
			for _, item in ipairs(deletedInstances) do
				pcall(game.Destroy, item.Obj)
			end
		end

		redo()

		if History and History.Add then
			History.Add({
				Name = "Delete Children",
				Undo = undo,
				Redo = redo,
				OnDestroy = onDestroy
			})
		else
			onDestroy()
		end
	end

	return Deletion
end

return {
	InitDeps = initDeps,
	InitAfterMain = initAfterMain,
	Main = main
}
