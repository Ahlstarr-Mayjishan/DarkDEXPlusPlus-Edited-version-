--[[
	Clipboard Core Module
	Handles copying, cutting, and pasting of instances.
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
	local Clipboard = {
		List = {}
	}

	Clipboard.Copy = function(selectionList)
		local clone = game.Clone
		local newClipboard = {}
		local count = 1
		for i = 1, #selectionList do
			local node = selectionList[i]
			if node and node.Obj then
				local inst = node.Obj
				local s, cloned = pcall(clone, inst)
				if s and cloned then
					newClipboard[count] = cloned
					count = count + 1
				end
			end
		end
		table.clear(Clipboard.List)
		for _, v in ipairs(newClipboard) do
			table.insert(Clipboard.List, v)
		end
	end

	Clipboard.Cut = function(selectionList, selection)
		local clone = game.Clone
		local newClipboard = {}
		local count = 1
		local cutInstances = {}

		for i = 1, #selectionList do
			local node = selectionList[i]
			if node and node.Obj then
				local inst = node.Obj
				local s, cloned = pcall(clone, inst)
				if s and cloned then
					newClipboard[count] = cloned
					count = count + 1
				end
				local success, parent = pcall(function() return inst.Parent end)
				if success and parent then
					table.insert(cutInstances, {
						Obj = inst,
						OriginalParent = parent
					})
				end
			end
		end

		if #cutInstances == 0 then return end

		table.clear(Clipboard.List)
		for _, v in ipairs(newClipboard) do
			table.insert(Clipboard.List, v)
		end

		local function undo()
			for _, item in ipairs(cutInstances) do
				pcall(function() item.Obj.Parent = item.OriginalParent end)
				if Apps.Explorer and Apps.Explorer.AddObject then
					pcall(Apps.Explorer.AddObject, item.Obj)
				end
			end
		end

		local function redo()
			for _, item in ipairs(cutInstances) do
				if Apps.Explorer and Apps.Explorer.RemoveObject then
					pcall(Apps.Explorer.RemoveObject, item.Obj)
				end
				pcall(function() item.Obj.Parent = nil end)
			end
		end

		local function onDestroy()
			for _, item in ipairs(cutInstances) do
				pcall(game.Destroy, item.Obj)
			end
		end

		redo()

		if History and History.Add then
			History.Add({
				Name = "Cut",
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

	Clipboard.Paste = function(selectionList, nodes, selection, ViewNode, MakeNodeVisible)
		if #Clipboard.List == 0 then return end
		local newSelection = {}
		local pastedInstances = {}
		local count = 1

		for i = 1, #selectionList do
			local node = selectionList[i]
			local inst = node.Obj
			if MakeNodeVisible then
				MakeNodeVisible(node, true)
			end
			for c = 1, #Clipboard.List do
				local cloned = Clipboard.List[c]:Clone()
				if cloned then
					cloned.Parent = inst
					if Apps.Explorer and Apps.Explorer.AddObject then
						pcall(Apps.Explorer.AddObject, cloned)
					end
					table.insert(pastedInstances, {
						Obj = cloned,
						OriginalParent = inst
					})
					local clonedNode = nodes[cloned]
					if clonedNode then
						newSelection[count] = clonedNode
						count = count + 1
					end
				end
			end
		end

		if #pastedInstances == 0 then return end

		local function undo()
			for _, item in ipairs(pastedInstances) do
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
			for _, item in ipairs(pastedInstances) do
				pcall(function() item.Obj.Parent = item.OriginalParent end)
				if Apps.Explorer and Apps.Explorer.AddObject then
					pcall(Apps.Explorer.AddObject, item.Obj)
				end
			end
			local nodesToSelect = {}
			for _, item in ipairs(pastedInstances) do
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
			for _, item in ipairs(pastedInstances) do
				pcall(game.Destroy, item.Obj)
			end
		end

		if History and History.Add then
			History.Add({
				Name = "Paste",
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

	Clipboard.HasItems = function()
		return #Clipboard.List > 0
	end

	return Clipboard
end

return {
	InitDeps = initDeps,
	InitAfterMain = initAfterMain,
	Main = main
}
