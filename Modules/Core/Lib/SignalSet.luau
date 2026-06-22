	Lib.Signal = (function()
		local funcs = {}

		local disconnect = function(con)
			local pos = table.find(con.Signal.Connections,con)
			if pos then table.remove(con.Signal.Connections,pos) end
		end

		funcs.Connect = function(self,func)
			if type(func) ~= "function" then error("Attempt to connect a non-function") end		
			local con = {
				Signal = self,
				Func = func,
				Disconnect = disconnect
			}
			self.Connections[#self.Connections+1] = con
			return con
		end

		funcs.Fire = function(self,...)
			for i,v in next,self.Connections do
				xpcall(coroutine.wrap(v.Func),function(e) warn(e.."\n"..debug.traceback()) end,...)
			end
		end

		local mt = {
			__index = funcs,
			__tostring = function(self)
				return "Signal: " .. tostring(#self.Connections) .. " Connections"
			end
		}

		local function new()
			local obj = {}
			obj.Connections = {}

			return setmetatable(obj,mt)
		end

		return {new = new}
	end)()

	Lib.Set = (function()
		local funcs = {}

		funcs.Add = function(self,obj)
			if self.Map[obj] then return end

			local list = self.List
			list[#list+1] = obj
			self.Map[obj] = true
			self.Changed:Fire()
		end

		funcs.AddTable = function(self,t)
			local changed
			local list,map = self.List,self.Map
			for i = 1,#t do
				local elem = t[i]
				if not map[elem] then
					list[#list+1] = elem
					map[elem] = true
					changed = true
				end
			end
			if changed then self.Changed:Fire() end
		end

		funcs.Remove = function(self,obj)
			if not self.Map[obj] then return end

			local list = self.List
			local pos = table.find(list,obj)
			if pos then table.remove(list,pos) end
			self.Map[obj] = nil
			self.Changed:Fire()
		end

		funcs.RemoveTable = function(self,t)
			local changed
			local list,map = self.List,self.Map
			local removeSet = {}
			for i = 1,#t do
				local elem = t[i]
				map[elem] = nil
				removeSet[elem] = true
			end

			for i = #list,1,-1 do
				local elem = list[i]
				if removeSet[elem] then
					table.remove(list,i)
					changed = true
				end
			end
			if changed then self.Changed:Fire() end
		end

		funcs.Set = function(self,obj)
			if #self.List == 1 and self.List[1] == obj then return end

			self.List = {obj}
			self.Map = {[obj] = true}
			self.Changed:Fire()
		end

		funcs.SetTable = function(self,t)
			local newList,newMap = {},{}
			self.List,self.Map = newList,newMap
			table.move(t,1,#t,1,newList)
			for i = 1,#t do
				newMap[t[i]] = true
			end
			self.Changed:Fire()
		end

		funcs.Clear = function(self)
			if #self.List == 0 then return end
			self.List = {}
			self.Map = {}
			self.Changed:Fire()
		end

		local mt = {__index = funcs}

		local function new()
			local obj = setmetatable({
				List = {},
				Map = {},
				Changed = Lib.Signal.new()
			},mt)

			return obj
		end

		return {new = new}
	end)()
