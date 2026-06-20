--[[
	Duplicate Core Module
	Handles duplicating selected instances in the Explorer.
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
	local Duplicate = {}

	Duplicate.Execute = function(selectionList, nodes, selection, ViewNode, MakeNodeVisible)
		local clone = game.Clone
		local newSelection = {}
		local duplicatedInstances = {}
		local count = 1

		for i = 1, #selectionList do
			local node = selectionList[i]
			local inst = node.Obj
			local instPar = node.Parent and node.Parent.Obj
			if MakeNodeVisible then
				MakeNodeVisible(node)
			end
			local s, cloned = pcall(clone, inst)
			if s and cloned then
				cloned.Parent = instPar
				if Apps.Explorer and Apps.Explorer.AddObject then
					pcall(Apps.Explorer.AddObject, cloned)
				end
				table.insert(duplicatedInstances, {
					Obj = cloned,
					OriginalParent = instPar
				})
				local clonedNode = nodes[cloned]
				if clonedNode then
					newSelection[count] = clonedNode
					count = count + 1
				end
			end
		end

		if #duplicatedInstances == 0 then return end

		local function undo()
			for _, item in ipairs(duplicatedInstances) do
				if Apps.Explorer and Apps.Explorer.RemoveObject then
					pcall(Apps.Explorer.RemoveObject, item.Obj)
				end
				pcall(function() item.Obj.Parent = nil end)
			end
			if selection and selection.Clear then
				selection:Clear()
			end
		end

		local function redo()
			for _, item in ipairs(duplicatedInstances) do
				pcall(function() item.Obj.Parent = item.OriginalParent end)
				if Apps.Explorer and Apps.Explorer.AddObject then
					pcall(Apps.Explorer.AddObject, item.Obj)
				end
			end
			local nodesToSelect = {}
			for _, item in ipairs(duplicatedInstances) do
				local node = nodes[item.Obj]
				if node then
					table.insert(nodesToSelect, node)
				end
			end
			if selection and selection.SetTable and #nodesToSelect > 0 then
				selection:SetTable(nodesToSelect)
			end
		end

		local function onDestroy()
			for _, item in ipairs(duplicatedInstances) do
				pcall(game.Destroy, item.Obj)
			end
		end

		if History and History.Add then
			History.Add({
				Name = "Duplicate",
				Undo = undo,
				Redo = redo,
				OnDestroy = onDestroy
			})
		end

		if selection and selection.SetTable then
			selection:SetTable(newSelection)
		end
		if #newSelection > 0 and ViewNode then
			ViewNode(newSelection[1])
		end
	end

	return Duplicate
end

return {
	InitDeps = initDeps,
	InitAfterMain = initAfterMain,
	Main = main
}
