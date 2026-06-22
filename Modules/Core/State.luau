--[[
	Declarative UI State & Reactivity Module
]]

-- Common Locals
local Main, Lib, Apps, Settings -- Main Containers
local API, RMD, env, service, plr, create, createSimple -- Main Locals

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
	local State = {}

	local StateCell = {}
	StateCell.__index = StateCell

	function StateCell.new(initialValue)
		local self = setmetatable({
			_value = initialValue,
			_listeners = {}
		}, StateCell)
		return self
	end

	function StateCell:get()
		return self._value
	end

	function StateCell:set(newValue)
		if self._value == newValue then return end
		self._value = newValue
		for _, listener in ipairs(self._listeners) do
			task.spawn(listener, newValue)
		end
	end

	function StateCell:onChange(callback)
		table.insert(self._listeners, callback)
		return {
			Disconnect = function()
				local pos = table.find(self._listeners, callback)
				if pos then
					table.remove(self._listeners, pos)
				end
			end
		}
	end

	function StateCell:__call()
		return self:get()
	end

	local ComputedCell = {}
	ComputedCell.__index = ComputedCell

	function ComputedCell.new(dependencies, callback)
		local self = setmetatable({
			_callback = callback,
			_dependencies = dependencies,
			_listeners = {},
			_value = nil,
			_connections = {}
		}, ComputedCell)

		local function update()
			local ok, newVal = pcall(self._callback)
			if ok then
				if self._value ~= newVal then
					self._value = newVal
					for _, listener in ipairs(self._listeners) do
						task.spawn(listener, newVal)
					end
				end
			else
				warn("Computed value error: " .. tostring(newVal))
			end
		end

		for _, dep in ipairs(dependencies) do
			if type(dep) == "table" and dep.onChange then
				local conn = dep:onChange(update)
				table.insert(self._connections, conn)
			end
		end

		self._value = callback()
		return self
	end

	function ComputedCell:get()
		return self._value
	end

	function ComputedCell:onChange(callback)
		table.insert(self._listeners, callback)
		return {
			Disconnect = function()
				local pos = table.find(self._listeners, callback)
				if pos then
					table.remove(self._listeners, pos)
				end
			end
		}
	end

	function ComputedCell:__call()
		return self:get()
	end

	local function Bind(instance, properties)
		local connections = {}

		for propName, propValue in pairs(properties) do
			if type(propValue) == "table" and propValue.get and propValue.onChange then
				-- It's a state or computed object
				local function update(val)
					if instance and instance.Parent then
						local ok, err = pcall(function()
							instance[propName] = val
						end)
						if not ok then
							warn("Failed to update bound property " .. propName .. " on " .. tostring(instance) .. ": " .. tostring(err))
						end
					end
				end

				-- Initial update
				update(propValue:get())

				-- Connect listener
				local conn = propValue:onChange(update)
				table.insert(connections, conn)
			else
				-- Standard value assignment
				instance[propName] = propValue
			end
		end

		-- Clean up when the GuiInstance is destroyed
		local destroyConn
		local hasDestroying = pcall(function() return instance.Destroying end)
		if hasDestroying then
			destroyConn = instance.Destroying:Connect(function()
				if destroyConn then destroyConn:Disconnect() end
				for _, conn in ipairs(connections) do
					conn:Disconnect()
				end
			end)
		else
			destroyConn = instance.AncestryChanged:Connect(function(_, parent)
				if parent == nil then
					if destroyConn then destroyConn:Disconnect() end
					for _, conn in ipairs(connections) do
						conn:Disconnect()
					end
				end
			end)
		end

		return {
			Disconnect = function()
				if destroyConn then destroyConn:Disconnect() end
				for _, conn in ipairs(connections) do
					conn:Disconnect()
				end
			end
		}
	end

	State.new = StateCell.new
	State.Computed = ComputedCell.new
	State.Bind = Bind

	return State
end

if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
