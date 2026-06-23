--[[
	Dex++
	Version 3.1

	Developed by Ahlstarr Mayijshan
	Edited by Ahlstarr Mayjishan
	Decompiler fixed + rspy plugin + adonis bypass by mcdaggitt,
	Dex++ is a revival of Moon's Dex, made to fulfill Moon's Dex prophecy.
]]

local selection
local nodes = {}

local oldgame = game
local game = workspace.Parent

cloneref = cloneref or function(ref)
	if not getreg then return ref end

	local InstanceList

	local a = Instance.new("Part")
	for _, c in pairs(getreg()) do
		if type(c) == "table" and #c then
			if rawget(c, "__mode") == "kvs" then
				for d, e in pairs(c) do
					if e == a then
						InstanceList = c
						break
					end
				end
			end
		end
	end
	local f = {}
	function f.invalidate(g)
		if not InstanceList then
			return
		end
		for b, c in pairs(InstanceList) do
			if c == g then
				InstanceList[b] = nil
				return g
			end
		end
	end
	return f.invalidate
end

local EmbeddedModules = {
    -- [[EMBEDDED_MODULES_PLACEHOLDER]]
}

local isFsSupported = readfile and writefile and isfile and isfolder and listfiles and delfile and delfolder

-- Main vars
local Main, Explorer, Properties, Notepad, Console, SaveInstance, ModelViewer, SettingsWindow, CodeSearch, ScriptRelations, RemoteUsageMap, ObjectLinks, ImageViewer, SoundViewer, AnimationViewer, ClientIndex, ActivityMap, DependencyGraph, SmartSearch, SnippetLibrary, RuntimeInspector, ClientIntelligence, InspectorHub, TaskRouter, ControlCenter, Theme, SmartDecompiler, SecurityAuditor, RemoteFuzzer, PropertyTracker, InstanceSerializer, ThreadManager, IDESync, Clipboard, Duplicate, Deletion, PropertyCopier, PropertyRestorer, Rename, History, DefaultSettings, Lib, State, Logger, Config, HookManager, DecompilerService, HelperClient, Bypasses, ReflectionMetadata, Intro, WebSocketClient, MainMenu, LucideDockIcons local ggv = getgenv or nil
local API, RMD

-- Vars
DefaultSettings = {}
local Settings = {}
local Apps = {}
local env = {}

local service = setmetatable({},{__index = function(self,name)
	local serv = cloneref(game:GetService(name))
	self[name] = serv
	return serv
end})
local plr = service.Players.LocalPlayer or service.Players.PlayerAdded:wait()

local mapFont = function(font)
	if font == Enum.Font.SourceSans then
		return Enum.Font.Gotham
	elseif font == Enum.Font.SourceSansBold then
		return Enum.Font.GothamBold
	end
	return font
end

local create = function(data)
	local insts = {}
	for i,v in pairs(data) do insts[v[1]] = Instance.new(v[2]) end

	for _,v in pairs(data) do
		for prop,val in pairs(v[3]) do
			if type(val) == "table" then
				insts[v[1]][prop] = insts[val[1]]
			else
				local actualVal = val
				if prop == "Font" then
					actualVal = mapFont(val)
				end
				insts[v[1]][prop] = actualVal
			end
		end
	end

	return insts[1]
end

local createSimple = function(class,props)
	local inst = Instance.new(class)
	for i,v in next,props do
		local actualVal = v
		if i == "Font" then
			actualVal = mapFont(v)
		end
		inst[i] = actualVal
	end
	return inst
end

Main = (function()
	local Main = {}

	Main.ModuleList = {"Theme","State","Logger","IconData","Lib","Console","SettingsWindow","ControlCenter","TaskRouter","ThreadManager","Config","HookManager","DecompilerService","HelperClient","Bypasses","ReflectionMetadata","Intro","WebSocketClient","MainMenu","LucideDockIcons","Explorer","EditMenu","NavigationMenu","ObjectMenu","ScriptMenu","InteractionMenu","PlayerMenu","NilInstanceMenu","Properties","SaveInstance","ModelViewer","ImageViewer","SoundViewer","AnimationViewer","ObjectLinks","InstanceSerializer","SmartDecompiler","Notepad","ClientIndex","CodeSearch","SmartSearch","SnippetLibrary","DependencyGraph","ScriptRelations","SecurityAuditor","RuntimeInspector","RemoteUsageMap","ActivityMap","PropertyTracker","RemoteFuzzer","ClientIntelligence","InspectorHub","IDESync","Clipboard","Duplicate","Deletion","PropertyCopier","PropertyRestorer","Rename","History"}
	Main.ModulePathMap = {
		Theme = "Core/Theme",
		State = "Core/State",
		Logger = "Core/Logger",
		IconData = "Core/IconData",
		Lib = "Core/Lib",
		Console = "Core/Console",
		SettingsWindow = "Core/SettingsWindow",
		ControlCenter = "Core/ControlCenter",
		TaskRouter = "Core/TaskRouter",
		ThreadManager = "Core/ThreadManager",
		Config = "Core/Config",
		HookManager = "Core/HookManager",
		DecompilerService = "Core/DecompilerService",
		HelperClient = "Core/HelperClient",
		Bypasses = "Core/Bypasses",
		ReflectionMetadata = "Core/ReflectionMetadata",
		Intro = "Core/Intro",
		WebSocketClient = "Core/WebSocketClient",
		MainMenu = "Core/MainMenu",
		LucideDockIcons = "Core/LucideDockIcons",
		Explorer = "Explorer/Explorer",
		EditMenu = "Explorer/ContextMenu/EditMenu",
		NavigationMenu = "Explorer/ContextMenu/NavigationMenu",
		ObjectMenu = "Explorer/ContextMenu/ObjectMenu",
		ScriptMenu = "Explorer/ContextMenu/ScriptMenu",
		InteractionMenu = "Explorer/ContextMenu/InteractionMenu",
		PlayerMenu = "Explorer/ContextMenu/PlayerMenu",
		NilInstanceMenu = "Explorer/ContextMenu/NilInstanceMenu",
		Properties = "Explorer/Properties",
		SaveInstance = "Explorer/SaveInstance",
		ModelViewer = "Explorer/ContextMenu/Roblox Assets Viewer/ModelViewer",
		ImageViewer = "Explorer/ContextMenu/Roblox Assets Viewer/ImageViewer",
		SoundViewer = "Explorer/ContextMenu/Roblox Assets Viewer/SoundViewer",
		AnimationViewer = "Explorer/ContextMenu/Roblox Assets Viewer/AnimationViewer",
		ObjectLinks = "Explorer/ObjectLinks",
		InstanceSerializer = "Explorer/InstanceSerializer",
		SmartDecompiler = "Search/SmartDecompiler",
		Notepad = "Search/Notepad",
		ClientIndex = "Search/ClientIndex",
		CodeSearch = "Search/CodeSearch",
		SmartSearch = "Search/SmartSearch",
		SnippetLibrary = "Search/SnippetLibrary",
		DependencyGraph = "Search/DependencyGraph",
		ScriptRelations = "Search/ScriptRelations",
		SecurityAuditor = "Search/SecurityAuditor",
		RuntimeInspector = "Runtime/RuntimeInspector",
		RemoteUsageMap = "Runtime/RemoteUsageMap",
		ActivityMap = "Runtime/ActivityMap",
		PropertyTracker = "Runtime/PropertyTracker",
		RemoteFuzzer = "Runtime/RemoteFuzzer",
		ClientIntelligence = "Runtime/ClientIntelligence",
		InspectorHub = "Runtime/InspectorHub",
		IDESync = "Tools/IDESync",
		Clipboard = "Explorer/Clipboard",
		Duplicate = "Explorer/Duplicate",
		Deletion = "Explorer/Deletion",
		PropertyCopier = "Explorer/PropertyCopier",
		PropertyRestorer = "Explorer/PropertyRestorer",
		Rename = "Explorer/Rename",
		History = "Explorer/History",
	}
	Main.Elevated = false
	Main.AllowDraggableOnMobile = true
	Main.MissingEnv = {}
	Main.Version = "3.1"
	Main.Mouse = plr:GetMouse()
	Main.AppControls = {}
	Main.Apps = Apps
	Main.MenuApps = {}
	Main.AppCards = {}
	Main.MenuSearchText = ""
	Main.GitName = "Ahlstarr-Mayjishan"
	Main.RepoName = "DarkDEX----edited-version-by-me-"
	Main.GitRepoName = Main.GitName.."/"..Main.RepoName
	Main.UpdateScriptPath = "DEX%2B%2B_compiled.luau"
	Main.DefaultUpdateRef = "v"..Main.Version
	Main.UpdateScriptURL = nil
	Main.UpdateCheckStarted = false
	Main.LatestUpdateSource = nil
	Main.StartedAt = os.time()
	Main.GameContext = {
		PlaceId = tostring(game.PlaceId or ""),
		GameId = tostring(game.GameId or ""),
		JobId = tostring(game.JobId or ""),
		Name = tostring(game.Name or "Roblox session"),
	}

	Main.DisplayOrders = {
		SideWindow = 8,
		Window = 10,
		Menu = 100000,
		Core = 101000
	}

	Main.Plugins = {}

	--[[Main.LoadAdonisBypass = function()
		-- skidded off reddit :pensive:
		local getinfo = getinfo or debug.getinfo
		local DEBUG = false
		local Hooked = {}

		local Detected, Kill

		setthreadidentity(2)

		for i, v in getgc(true) do
			if typeof(v) == "table" then
				local DetectFunc = rawget(v, "Detected")
				local KillFunc = rawget(v, "Kill")

				if typeof(DetectFunc) == "function" and not Detected then
					Detected = DetectFunc

					local Old; Old = hookfunction(Detected, function(Action, Info, NoCrash)
						if Action ~= "_" then
							if DEBUG then
								warn(`Adonis AntiCheat flagged\nMethod: {Action}\nInfo: {Info}`)
							end
						end

						return true
					end)

					table.insert(Hooked, Detected)
				end

				if rawget(v, "Variables") and rawget(v, "Process") and typeof(KillFunc) == "function" and not Kill then
					Kill = KillFunc
					local Old; Old = hookfunction(Kill, function(Info)
						if DEBUG then
							warn(`Adonis AntiCheat tried to kill (fallback): {Info}`)
						end
					end)

					table.insert(Hooked, Kill)
				end
			end
		end

		local Old; Old = hookfunction(getrenv().debug.info, newcclosure(function(...)
			local LevelOrFunc, Info = ...

			if Detected and LevelOrFunc == Detected then
				if DEBUG then
					warn(`Adonis AntiCheat sanity check detected and broken`)
				end

				return coroutine.yield(coroutine.running())
			end

			return Old(...)
		end))
		-- setthreadidentity(9)
		setthreadidentity(7)
	end

	Main.LoadGCBypass = function()
		loadstring(game:HttpGet("https://raw.githubusercontent.com/secretisadev/Babyhamsta_Backup/refs/heads/main/Universal/Bypasses.lua", true))()
	end]]

	Main.GetRandomString = function()
		local output = ""
		for i = 2, 25 do
			output = output .. string.char(math.random(1,250))
		end

		return output
	end

	Main.GetSecureContainer = function()
		return
			syn and syn.protect_gui or
			gethui and gethui() or
			service.CoreGui or
			service.Players.LocalPlayer:WaitForChild("PlayerGui")
	end

	Main.SecureGui = function(gui)
		--warn("Secured: "..gui.Name)
		gui.Name = "_DPP_".. Main.GetRandomString()
		if _G._DEX_VIRTUAL_GUI == true or _G._DEX_HEADLESS == true then
			gui.Parent = nil
			return
		end
		-- service already using cloneref
		if gethui then
			gui.Parent = gethui()
		elseif syn and syn.protect_gui then
			syn.protect_gui(gui)
			gui.Parent = service.CoreGui
		elseif protect_gui then
			protect_gui(gui)
			gui.Parent = service.CoreGui
		elseif protectgui then
			protectgui(gui)
			gui.Parent = service.CoreGui
		else
			if Main.Elevated then
				gui.Parent = service.CoreGui
			else
				gui.Parent = service.Players.LocalPlayer:WaitForChild("PlayerGui")
			end
		end
	end

	Main.GetInitDeps = function()
		return {
			Main = Main,
			Lib = Lib,
			Apps = Apps,
			Settings = Settings,

			API = API,
			RMD = RMD,
			env = env,
			service = service,
			plr = plr,
			create = create,
			createSimple = createSimple
		}
	end

	Main.SafeGetInstancePath = function(obj)
		if not obj then
			return "?"
		end

		local explorerApp = Apps and Apps.Explorer
		if explorerApp and explorerApp.GetInstancePath then
			local ok, path = pcall(explorerApp.GetInstancePath, obj)
			if ok and path ~= nil then
				return tostring(path)
			end
		end

		local okFullName, fullName = pcall(function()
			return obj:GetFullName()
		end)
		if okFullName and fullName and fullName ~= "" then
			return tostring(fullName)
		end

		local okManual, manualPath = pcall(function()
			if typeof(obj) ~= "Instance" then
				return tostring(obj)
			end

			local parts = {}
			local cur = obj
			while cur and cur ~= game do
				table.insert(parts, 1, tostring(cur.Name))
				cur = cur.Parent
			end
			if cur == game then
				table.insert(parts, 1, "game")
			end
			return #parts > 0 and table.concat(parts, ".") or tostring(obj)
		end)
		if okManual and manualPath and manualPath ~= "" then
			return tostring(manualPath)
		end

		return tostring(obj)
	end

	Main.Error = function(str)
		if rconsoleprint then
			rconsoleprint("DEX ERROR: "..tostring(str).."\n")
			wait(9e9)
		else
			error(str)
		end
	end

	Main.LoadModule = function(name)
		if Apps[name] and Main.AppControls[name] then
			return Apps[name]
		end

		if Main.Elevated then -- If you don't have filesystem api then ur outta luck tbh
			local control
			local usedLocalOverride = false

			local function loadEmbeddedControl()
				if not EmbeddedModules then return nil end
				if not EmbeddedModules[name] then Main.Error("Missing Embedded Module: "..name) end
				if gethsfuncs then _G.moduleData = nil end
				local embeddedControl = EmbeddedModules[name]()

				-- TODO: Remove when open source
				if gethsfuncs then
					embeddedControl = _G.moduleData
				end

				if not embeddedControl then Main.Error("Missing Embedded Module: "..name) end
				return embeddedControl
			end

			local function activateControl(selectedControl)
				Main.AppControls[name] = selectedControl
				selectedControl.InitDeps(Main.GetInitDeps())

				local moduleData = selectedControl.Main()
				Apps[name] = moduleData
				return moduleData
			end

			-- Developer Mode: Load directly from local file if exists
			local modulePath = Main.ModulePathMap and Main.ModulePathMap[name] or name
			local localPath = 'dex/Modules/' .. modulePath .. '.luau'
			local localPathFallback = 'dex/Modules/' .. modulePath .. '.lua'
			local flatLocalPath = 'dex/Modules/' .. name .. '.luau'
			local flatLocalPathFallback = 'dex/Modules/' .. name .. '.lua'
			if isFsSupported and (isfile(localPath) or isfile(localPathFallback)) then
				local path = isfile(localPath) and localPath or localPathFallback
				local s, err = pcall(function()
					if gethsfuncs then _G.moduleData = nil end
					control = loadstring(readfile(path))()
					if not control and gethsfuncs then
						control = _G.moduleData
					end
				end)
				if s and control then
					usedLocalOverride = true
				end
				if not s then
					warn('Failed to load local module ' .. name .. ': ' .. tostring(err))
				end
			elseif isFsSupported and (isfile(flatLocalPath) or isfile(flatLocalPathFallback)) then
				local path = isfile(flatLocalPath) and flatLocalPath or flatLocalPathFallback
				local s, err = pcall(function()
					if gethsfuncs then _G.moduleData = nil end
					control = loadstring(readfile(path))()
					if not control and gethsfuncs then
						control = _G.moduleData
					end
				end)
				if s and control then
					usedLocalOverride = true
				end
				if not s then
					warn('Failed to load local flat module ' .. name .. ': ' .. tostring(err))
				end
			end

			if not control then
				if EmbeddedModules and EmbeddedModules[name] then -- Offline Modules
					control = loadEmbeddedControl()
				else
					-- Get hash data
					local hashs = Main.ModuleHashData
					if not hashs then
						local s,hashDataStr = pcall(oldgame.HttpGet, game, "https://api.github.com/repos/"..Main.GitRepoName.."/ModuleHashs.dat")
						if not s then Main.Error("Failed to get module hashs") end

						local s,hashData = pcall(service.HttpService.JSONDecode,service.HttpService,hashDataStr)
						if not s then Main.Error("Failed to decode module hash JSON") end

						hashs = hashData
						Main.ModuleHashData = hashs
					end

					-- Check if local copy exists with matching hashs
					local hashfunc = (syn and syn.crypt.hash) or function() return "" end
					local filePath = "dex/ModuleCache/"..name..".lua"
					local s,moduleStr = pcall(env.readfile,filePath)

					if s and hashfunc(moduleStr) == hashs[name] then
						control = loadstring(moduleStr)()
					else
						-- Download and cache
						local s,moduleStr = pcall(oldgame.HttpGet, game, "https://api.github.com/repos/"..Main.GitRepoName.."/Modules/"..name..".lua")
						if not s then Main.Error("Failed to get external module data of "..name) end

						env.writefile(filePath,moduleStr)
						control = loadstring(moduleStr)()
					end
				end
			end

			if usedLocalOverride then
				local ok, moduleData = pcall(activateControl, control)
				if ok then
					return moduleData
				end
				warn("Local module " .. name .. " failed during init; falling back to embedded: " .. tostring(moduleData))
				Main.AppControls[name] = nil
				Apps[name] = nil
				control = loadEmbeddedControl()
			end

			return activateControl(control)
		else
			local module = script:WaitForChild("Modules"):WaitForChild(name,2)
			if not module then Main.Error("CANNOT FIND MODULE "..name) end

			local control = require(module)
			Main.AppControls[name] = control
			control.InitDeps(Main.GetInitDeps())

			local moduleData = control.Main()
			Apps[name] = moduleData
			return moduleData
		end
	end

	Main.LoadPluginFile = function(pluginDir)
		if env.readfile then
			if isfile(pluginDir) then
				local preloadedPlugin = loadfile and loadfile(pluginDir) or loadstring(env.readfile(pluginDir))
				local loadedPlugin = preloadedPlugin()

				local control = loadedPlugin
				control.InitDeps(Main.GetInitDeps())

				local moduleData = control.Main()
				Apps[pluginDir] = moduleData
				Main.AppControls[pluginDir] = control

				moduleData.PluginData = control.PluginData

				if type(control.InitAfterMain) == "function" then
					pcall(control.InitAfterMain, Apps)
				end

				return moduleData
			else
				Main.Error("CANNOT FIND FILE MODULE "..pluginDir)
			end
		end
	end

	Main.LoadModules = function()
		for i,v in ipairs(Main.ModuleList) do
			local s,e = pcall(Main.LoadModule,v)
			if not s then
				Main.Error("FAILED LOADING " .. v .. " CAUSE " .. e)
			end
		end

		-- Init Major Apps and define them in modules
		Explorer = Apps.Explorer
		Properties = Apps.Properties
		Notepad = Apps.Notepad
		Console = Apps.Console
		SaveInstance = Apps.SaveInstance
		ModelViewer = Apps.ModelViewer

		SettingsWindow = Apps.SettingsWindow
		CodeSearch = Apps.CodeSearch
		ScriptRelations = Apps.ScriptRelations
		RemoteUsageMap = Apps.RemoteUsageMap
		ObjectLinks = Apps.ObjectLinks
		ImageViewer = Apps.ImageViewer
		SoundViewer = Apps.SoundViewer
		AnimationViewer = Apps.AnimationViewer
		ClientIndex = Apps.ClientIndex
		ActivityMap = Apps.ActivityMap
		DependencyGraph = Apps.DependencyGraph
		SmartSearch = Apps.SmartSearch
		SnippetLibrary = Apps.SnippetLibrary
		RuntimeInspector = Apps.RuntimeInspector
		ClientIntelligence = Apps.ClientIntelligence
		InspectorHub = Apps.InspectorHub
		TaskRouter = Apps.TaskRouter
		ControlCenter = Apps.ControlCenter
		Theme = Apps.Theme
		SmartDecompiler = Apps.SmartDecompiler
		SecurityAuditor = Apps.SecurityAuditor
		RemoteFuzzer = Apps.RemoteFuzzer
		PropertyTracker = Apps.PropertyTracker
		InstanceSerializer = Apps.InstanceSerializer
		ThreadManager = Apps.ThreadManager
		IDESync = Apps.IDESync
		Clipboard = Apps.Clipboard
		Duplicate = Apps.Duplicate
		Deletion = Apps.Deletion
		PropertyCopier = Apps.PropertyCopier
		PropertyRestorer = Apps.PropertyRestorer
		Rename = Apps.Rename
		History = Apps.History
		State = Apps.State

		Config = Apps.Config
		HookManager = Apps.HookManager
		DecompilerService = Apps.DecompilerService
		HelperClient = Apps.HelperClient
		Bypasses = Apps.Bypasses
		ReflectionMetadata = Apps.ReflectionMetadata
		Intro = Apps.Intro
		WebSocketClient = Apps.WebSocketClient
		MainMenu = Apps.MainMenu

		local appTable = {
			Theme = Theme,
			State = State,
			SmartDecompiler = SmartDecompiler,
			Explorer = Explorer,
			Properties = Properties,
			Notepad = Notepad,
			Console = Console,
			SaveInstance = SaveInstance,
			ModelViewer = ModelViewer,

			SettingsWindow = SettingsWindow,
			CodeSearch = CodeSearch,
			ScriptRelations = ScriptRelations,
			RemoteUsageMap = RemoteUsageMap,
			ObjectLinks = ObjectLinks,
			ImageViewer = ImageViewer,
			SoundViewer = SoundViewer,
			AnimationViewer = AnimationViewer,
			ClientIndex = ClientIndex,
			ActivityMap = ActivityMap,
			DependencyGraph = DependencyGraph,
			SmartSearch = SmartSearch,
			SnippetLibrary = SnippetLibrary,
			RuntimeInspector = RuntimeInspector,
			ClientIntelligence = ClientIntelligence,
			InspectorHub = InspectorHub,
			TaskRouter = TaskRouter,
			ControlCenter = ControlCenter,
			SecurityAuditor = SecurityAuditor,
			RemoteFuzzer = RemoteFuzzer,
			PropertyTracker = PropertyTracker,
			InstanceSerializer = InstanceSerializer,
			ThreadManager = ThreadManager,
			IDESync = IDESync,
			Clipboard = Clipboard,
			Duplicate = Duplicate,
			Deletion = Deletion,
			PropertyCopier = PropertyCopier,
			PropertyRestorer = PropertyRestorer,
			Rename = Rename,
			History = History,

			Config = Config,
			HookManager = HookManager,
			DecompilerService = DecompilerService,
			HelperClient = HelperClient,
			Bypasses = Bypasses,
			ReflectionMetadata = ReflectionMetadata,
			Intro = Intro,
			WebSocketClient = WebSocketClient,
			MainMenu = MainMenu
		}

		Main.AppControls.Lib.InitAfterMain(appTable)
		for i,v in ipairs(Main.ModuleList) do
			local control = Main.AppControls[v]
			if control then
				control.InitAfterMain(appTable)
			end
		end
	end

	Main.InitEnv = function()
		setmetatable(env,{__newindex = function(self,name,func)
			if not func then Main.MissingEnv[#Main.MissingEnv+1] = name return end
			rawset(self,name,func)
		end})

		env.isonmobile = game:GetService("UserInputService").TouchEnabled

		env.loadstring = (pcall(loadstring,"local a = 1") and loadstring) or (game:GetService("RunService"):IsStudio() and script.Modules:FindFirstChild("Loadstring") and require(script.Modules:FindFirstChild("Loadstring")))

		-- file
		env.isfile = isfile
		env.isfolder = isfolder
		env.readfile = readfile
		env.writefile = writefile
		env.appendfile = appendfile
		env.makefolder = makefolder
		env.listfiles = listfiles
		env.loadfile = loadfile
		env.saveinstance = (function()
	if game:GetService("RunService"):IsStudio() then
		return function() error("Cannot run in Roblox Studio!") end
	end

	local Params = {
		RepoURL = "https://raw.githubusercontent.com/luau/SynSaveInstance/main/",
		SSI = "saveinstance",
	}
	local synsaveinstance = loadstring(oldgame:HttpGet(Params.RepoURL .. Params.SSI .. ".luau", true), Params.SSI)()

	    local function wrappedsaveinstance(obj, filepath, options)
		            options["FilePath"] = filepath
		            options["Object"] = obj
		            return synsaveinstance(options)
	            end
	        getgenv().saveinstance = wrappedsaveinstance
	        return wrappedsaveinstance
        end)()

		env.parsefile = function(name)
			return tostring(name):gsub("[*\\?:<>|]+", ""):sub(1, 175)
		end

		-- debug
		env.getupvalues = debug.getupvalues or getupvalues or getupvals
		env.getconstants = debug.getconstants or getconstants or getconsts
		env.islclosure = islclosure or is_l_closure
		env.checkcaller = checkcaller
		env.getreg = getreg
		env.getgc = getgc

		-- hooks
		env.hookfunction = hookfunction
		env.hookmetamethod = hookmetamethod

		-- other
		env.getscriptbytecode = getscriptbytecode
		env.setfflag = setfflag
		env.protectgui = protect_gui or (syn and syn.protect_gui)
		env.gethui = gethui
		env.setclipboard = setclipboard
		env.getnilinstances = getnilinstances or get_nil_instances
		env.getloadedmodules = getloadedmodules
		env.getconnections = getconnections

		env.isViableDecompileScript = function(obj)
			if obj:IsA("ModuleScript") then
				return true
			elseif obj:IsA("LocalScript") and (obj.RunContext == Enum.RunContext.Client or obj.RunContext == Enum.RunContext.Legacy) then
				return true
			elseif obj:IsA("Script") and obj.RunContext == Enum.RunContext.Client then
				return true
			end
			return false
		end

		local remoteClassMap = {
			RemoteEvent = true,
			RemoteFunction = true,
			UnreliableRemoteEvent = true,
			BindableEvent = true,
			BindableFunction = true,
		}

		local function addUniqueInstance(list, seen, obj)
			if typeof(obj) == "Instance" and not seen[obj] then
				seen[obj] = true
				list[#list+1] = obj
				return true
			end
			return false
		end

		local clientSurfaceTtl = 4
		local clientSurfaceStamp = 0
		local clientSurface = {
			AllInstances = {},
			AllScripts = {},
			ViableScripts = {},
			Remotes = {},
		}

		local function addGcScriptRefs(list, seen, allowNonViable)
			if not env.getgc then return end
			local success, gcObjects = pcall(env.getgc)
			if not success or type(gcObjects) ~= "table" then return end

			local count = 0
			for _, value in pairs(gcObjects) do
				if typeof(value) == "function" then
					local envSuccess, fnEnv = pcall(getfenv, value)
					local scr = envSuccess and type(fnEnv) == "table" and rawget(fnEnv, "script")
					if typeof(scr) == "Instance" and scr:IsA("LuaSourceContainer") then
						if allowNonViable or env.isViableDecompileScript(scr) then
							if typeof(scr) == "Instance" and not seen[scr] then
								seen[scr] = true
								table.insert(list, scr)
							end
						end
					end
				end
				count = count + 1
				if count % 350 == 0 then task.wait() end
			end
		end

		env.RefreshClientSurface = function(force, includeGcScripts)
			local now = os.clock()
			if not force and now - clientSurfaceStamp < clientSurfaceTtl then
				return clientSurface
			end

			clientSurfaceStamp = now
			local allInstances, seen = {}, {}
			local allScripts, viableScripts, remotes = {}, {}, {}
			local scriptSeen, viableSeen, remoteSeen = {}, {}, {}

			local count = 0
			local function processInstance(obj)
				if typeof(obj) ~= "Instance" then return end
				if not seen[obj] then
					seen[obj] = true
					table.insert(allInstances, obj)
					if obj:IsA("LuaSourceContainer") then
						if not scriptSeen[obj] then
							scriptSeen[obj] = true
							table.insert(allScripts, obj)
							if env.isViableDecompileScript(obj) then
								viableSeen[obj] = true
								table.insert(viableScripts, obj)
							end
						end
					elseif remoteClassMap[obj.ClassName] then
						if not remoteSeen[obj] then
							remoteSeen[obj] = true
							table.insert(remotes, obj)
						end
					end
				end
				count = count + 1
				if count % 400 == 0 then
					task.wait()
				end
			end

			-- 1. Descendants
			local ok, descendants = pcall(game.GetDescendants, game)
			if ok and type(descendants) == "table" then
				for _, obj in ipairs(descendants) do
					processInstance(obj)
				end
			end

			-- 2. Nil Instances
			if env.getnilinstances then
				local success, nilInstances = pcall(env.getnilinstances)
				if success and type(nilInstances) == "table" then
					for _, obj in pairs(nilInstances) do
						processInstance(obj)
					end
				end
			end

			-- 3. Loaded Modules
			if env.getloadedmodules then
				local success, loadedModules = pcall(env.getloadedmodules)
				if success and type(loadedModules) == "table" then
					for _, obj in pairs(loadedModules) do
						processInstance(obj)
					end
				end
			end

			-- 4. GC scripts (optional)
			if includeGcScripts == true then
				addGcScriptRefs(allScripts, scriptSeen, true)
				-- Also update viableScripts from the newly added ones
				for _, scr in ipairs(allScripts) do
					if env.isViableDecompileScript(scr) and not viableSeen[scr] then
						viableSeen[scr] = true
						table.insert(viableScripts, scr)
					end
				end
			end

			clientSurface = {
				AllInstances = allInstances,
				AllScripts = allScripts,
				ViableScripts = viableScripts,
				Remotes = remotes,
				UpdatedAt = now,
			}
			return clientSurface
		end

		env.GetClientScripts = function(allowNonViable, forceDeep)
			local surface = env.RefreshClientSurface(forceDeep == true, forceDeep == true)
			return allowNonViable and surface.AllScripts or surface.ViableScripts
		end

		env.GetClientRemotes = function(force)
			return env.RefreshClientSurface(force == true, false).Remotes
		end

		env.GetClientSurfaceCoverage = function()
			local surface = env.RefreshClientSurface(false, false)
			local allScripts = surface.AllScripts
			local viableScripts = surface.ViableScripts
			local remotes = surface.Remotes
			local cached = 0

			if env.DecompileCache and env.DecompileCache.GetEntries then
				local entries = env.DecompileCache.GetEntries()
				for _ in pairs(entries) do
					cached += 1
				end
			end

			return {
				AllScripts = #allScripts,
				ViableScripts = #viableScripts,
				Remotes = #remotes,
				CachedScripts = cached,
				HasNilInstances = env.getnilinstances ~= nil,
				HasLoadedModules = env.getloadedmodules ~= nil,
				HasGc = env.getgc ~= nil,
				HasConnections = env.getconnections ~= nil,
			}
		end

		env.GetScriptConstants = function(scriptInstance)
			local constants, seen = {}, {}
			if not env.getgc or not env.getconstants then return constants end

			local success, gcObjects = pcall(env.getgc)
			if not success or type(gcObjects) ~= "table" then return constants end

			for _, value in pairs(gcObjects) do
				if typeof(value) == "function" then
					local envSuccess, fnEnv = pcall(getfenv, value)
					if envSuccess and type(fnEnv) == "table" and rawget(fnEnv, "script") == scriptInstance then
						local constSuccess, constList = pcall(env.getconstants, value)
						if constSuccess and type(constList) == "table" then
							for _, constant in pairs(constList) do
								local key = tostring(constant)
								if not seen[key] then
									seen[key] = true
									constants[#constants+1] = constant
								end
							end
						end
					end
				end
			end

			return constants
		end
		env.request = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

		env.isdecompile = function()
			return typeof(decompile) == "function" or typeof(getscriptbytecode) == "function" or false
		end

		env.isdecompilefallback = function()
			return typeof(decompile) ~= "function" or typeof(getscriptbytecode) == "function" or false
		end


		if identifyexecutor then
			Main.Executor = identifyexecutor()
		end

		Main.GuiHolder = Main.Elevated and service.CoreGui or plr:FindFirstChildOfClass("PlayerGui")

		setmetatable(env,nil)
	end

	Main.IncompatibleTest = function()
		--[[local function incompatibleMessage(reason, tolerated)
			local msg = Instance.new("ScreenGui")
			msg.IgnoreGuiInset = true
			local t = Instance.new("TextLabel",msg)
			t.BackgroundColor3 = Color3.fromRGB(50,50,50)
			t.Position = UDim2.new(0,0,0,0)
			t.Size = UDim2.new(1,0,1,0)
			t.TextColor3 = Color3.new(1,1,1)
			t.TextWrapped = true
			t.TextScaled = true
			t.Text = "\n\n\n\n\n\n\n\nHello Skidsploit user,\nZinnia, Chillz and the Secret Service does not approve of Dex being used on your skidsploit.\nPlease consider getting something better.\n\nIncompatible Reason: "..reason.."\n\n\n\n\n\n\n\n"

			-- This sound wont work!!!
			local sound = Instance.new("Sound",msg)
			sound.SoundId = "rbxassetid://175964948"
			sound.Volume = 1
			sound.Looped = true
			sound.Playing = true

			if not tolerated then
				Lib.ShowGui(msg)

				if os and os.execute then pcall(os.execute,'explorer "https://weao.xyz"') end
				if pcall(game.GetService, game,"MessageBusService") and game:GetService("MessageBusService").Publish then pcall(game:GetService("MessageBusService").Publish, game:GetService("MessageBusService"), game:GetService("MessageBusService"):GetMessageId("Linking", "openURLRequest"), {url = 'explorer "https://weao.xyz"'}) end
			else
				warn(msg)
			end
		end

																																													local yummy, evilList = "\105\100\101\110\116\105\102\121\101\120\101\99\117\116\111\114", { "\120\101\110\111", "\115\111\108\97\114\97", "\119\97\118\101" }
																																													if ggv and ggv()[yummy] then local wow = ggv()[yummy] if table.find(evilList, string.lower(wow)) then incompatibleMessage("\83\72\73\84\84\89\32\69\88\69\67\85\84\79\82") end end

		local t = {}
		t[1] = t
		local x = unpack(t) or incompatibleMessage("WRAPPER FAILED TO CYCLIC #1")
		if x[1] ~= t then incompatibleMessage("WRAPPER FAILED TO CYCLIC #2") end

		if game ~= workspace.Parent then
			incompatibleMessage("WRAPPER NO CACHE (game â‰  workspace.Parent)", true)
			game = workspace.Parent
		end

		if Main.Elevated and not loadstring("for i = 1,1 do continue end") then incompatibleMessage("CAN'T CONTINUE OR NO LOADSTRING")end

		local obj = newproxy(true)
		local mt = getmetatable(obj)
		mt.__index = function() incompatibleMessage("CAN'T NAMECALL (__index triggered instead of __namecall)") end
		mt.__namecall = function() end
		obj:No()

		local fEnv = setmetatable({zin = 5},{__index = getfenv()})
		local caller = function(f) f() end
		setfenv(caller,fEnv)
		caller(function() if not getfenv(2).zin then incompatibleMessage("RERU WILL BE FILING A LAWSUIT AGAINST YOU SOON") end end)

		local second = false
		coroutine.wrap(function() local start = tick() wait(5) if tick() - start < 0.1 or not second then incompatibleMessage("SKIDDED YIELDING") end end)()
		second = true]]
	end

	local function serialize(val)
		if typeof(val) == "Color3" then
			local serializedColor = {}
			serializedColor.R = val.R
			serializedColor.G = val.G
			serializedColor.B = val.B
			return serializedColor
		else
			return val
		end
	end

	local function deserialize(val)
		if typeof(val) == "table" then
			if val.R and val.G and val.B then
				return Color3.new(val.R, val.G, val.B)
			else
				return val
			end
		else
			return val
		end
	end

	Main.ShowGui = Main.SecureGui

	Main.CompareVersions = function(current, latest)
		local function nums(version)
			local out = {}
			for n in tostring(version or ""):gmatch("%d+") do
				out[#out + 1] = tonumber(n) or 0
			end
			return out
		end

		local a, b = nums(current), nums(latest)
		for i = 1, math.max(#a, #b) do
			local av, bv = a[i] or 0, b[i] or 0
			if bv > av then return 1 end
			if bv < av then return -1 end
		end
		return 0
	end

	Main.GetRemoteScriptVersion = function(source)
		if type(source) ~= "string" then return nil end
		return source:match('Main%.Version%s*=%s*"([^"]+)"')
			or source:match("Main%.Version%s*=%s*'([^']+)'")
			or source:match("Version%s+([%d%.]+)")
	end

	Main.GetUpdateRef = function()
		local settings = Settings or DefaultSettings or {}
		local ref = tostring(settings.AutoUpdateRef or Main.DefaultUpdateRef or "")
		ref = ref:gsub("^%s+", ""):gsub("%s+$", "")
		if ref == "" then return nil end

		local lowerRef = ref:lower()
		local isBranchRef = lowerRef == "main" or lowerRef == "master" or lowerRef:match("^refs/heads/")
		if isBranchRef and settings.AutoUpdateAllowBranch ~= true then
			return nil
		end
		return ref
	end

	Main.GetUpdateScriptURL = function()
		local ref = Main.GetUpdateRef()
		if not ref then return nil end
		return "https://raw.githubusercontent.com/"..Main.GitRepoName.."/"..ref.."/"..Main.UpdateScriptPath
	end

	Main.RestartFromLatest = function()
		if Main.Restarting then return true end
		local source = Main.LatestUpdateSource
		if not source or source == "" then
			local updateUrl = Main.GetUpdateScriptURL()
			if not updateUrl then return false end
			local ok, result = pcall(oldgame.HttpGet, game, updateUrl, true)
			if ok then source = result end
		end
		if type(source) ~= "string" or source == "" then return false end

		local loader = env and env.loadstring or loadstring
		if not loader then return false end

		Main.Restarting = true
		task.spawn(function()
			local restarted = false
			local okRestart, restartErr = pcall(function()
				Main.Uninit()
				task.wait(0.2)
				local ok, fn = pcall(loader, source, "DEX++ Latest")
				if ok and type(fn) == "function" then
					restarted = true
					task.spawn(fn)
				elseif not ok then
					warn("DEX++ latest restart load failed: " .. tostring(fn))
				end
			end)
			if not okRestart then
				warn("DEX++ latest restart failed: " .. tostring(restartErr))
			end
			if not restarted then
				Main.Restarting = false
			end
		end)
		return true
	end

	Main.ShowUpdatePrompt = function(latestVersion)
		local gui = create({
			{1,"ScreenGui",{IgnoreGuiInset=true,Name="UpdatePrompt",ResetOnSpawn=false,}},
			{2,"Frame",{BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=0.35,BorderSizePixel=0,Name="Dim",Parent={1},Size=UDim2.new(1,0,1,0),}},
			{3,"Frame",{AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=Settings.Theme.Main2,BorderSizePixel=0,Name="Card",Parent={2},Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(0,360,0,156),}},
			{4,"UICorner",{CornerRadius=UDim.new(0,6),Parent={3},}},
			{5,"Frame",{BackgroundColor3=Settings.Theme.ListSelection,BorderSizePixel=0,Name="Accent",Parent={3},Size=UDim2.new(1,0,0,3),}},
			{6,"TextLabel",{BackgroundTransparency=1,Font=4,Name="Title",Parent={3},Position=UDim2.new(0,18,0,16),Size=UDim2.new(1,-36,0,24),Text="New DEX++ version detected",TextColor3=Settings.Theme.Text,TextSize=18,TextXAlignment=0,}},
			{7,"TextLabel",{BackgroundTransparency=1,Font=3,Name="Body",Parent={3},Position=UDim2.new(0,18,0,46),Size=UDim2.new(1,-36,0,44),Text="Current: "..tostring(Main.Version).."  |  Latest: "..tostring(latestVersion).."\nRestart now to load the latest script?",TextColor3=Settings.Theme.PlaceholderText,TextSize=14,TextWrapped=true,TextXAlignment=0,TextYAlignment=0,}},
			{8,"TextButton",{AutoButtonColor=false,BackgroundColor3=Settings.Theme.ListSelection,BorderSizePixel=0,Font=4,Name="Restart",Parent={3},Position=UDim2.new(1,-174,1,-46),Size=UDim2.new(0,78,0,28),Text="Restart",TextColor3=Settings.Theme.Text,TextSize=14,}},
			{9,"UICorner",{CornerRadius=UDim.new(0,4),Parent={8},}},
			{10,"TextButton",{AutoButtonColor=false,BackgroundColor3=Settings.Theme.Button,BorderSizePixel=0,Font=4,Name="Later",Parent={3},Position=UDim2.new(1,-88,1,-46),Size=UDim2.new(0,70,0,28),Text="Later",TextColor3=Settings.Theme.Text,TextSize=14,}},
			{11,"UICorner",{CornerRadius=UDim.new(0,4),Parent={10},}},
		})

		Main.SecureGui(gui)

		local card = gui.Dim.Card
		card.Restart.MouseEnter:Connect(function() card.Restart.BackgroundColor3 = Settings.Theme.ButtonHover end)
		card.Restart.MouseLeave:Connect(function() card.Restart.BackgroundColor3 = Settings.Theme.ListSelection end)
		card.Later.MouseEnter:Connect(function() card.Later.BackgroundColor3 = Settings.Theme.ButtonHover end)
		card.Later.MouseLeave:Connect(function() card.Later.BackgroundColor3 = Settings.Theme.Button end)
		card.Later.MouseButton1Click:Connect(function()
			gui:Destroy()
		end)
		card.Restart.MouseButton1Click:Connect(function()
			card.Restart.Text = "Loading"
			card.Restart.Active = false
			card.Later.Active = false
			if not Main.RestartFromLatest() then
				card.Restart.Text = "Failed"
				task.wait(1.5)
				if gui.Parent then gui:Destroy() end
			end
		end)
	end

	Main.CheckForUpdatesAsync = function()
		if Settings.AutoCheckUpdate == false then return end
		if Main.UpdateCheckStarted then return end
		Main.UpdateCheckStarted = true
		coroutine.wrap(function()
			task.wait(1)
			local updateUrl = Main.GetUpdateScriptURL()
			if not updateUrl then return end
			Main.UpdateScriptURL = updateUrl
			local ok, source = pcall(function() return game:HttpGet(updateUrl, true) end)
			if not ok or type(source) ~= "string" or source == "" then return end
			local latestVersion = Main.GetRemoteScriptVersion(source)
			if not latestVersion then return end
			if Main.CompareVersions(Main.Version, latestVersion) <= 0 then return end
			Main.LatestUpdateSource = source
			Main.ShowUpdatePrompt(latestVersion)
		end)()
	end

	Main.SetupFilesystem = function()
		if not env.writefile or not env.makefolder then return end

		local writefile,makefolder = env.writefile,env.makefolder
		local function safeMakeFolder(path)
			if not env.isfolder or not env.isfolder(path) then
				makefolder(path)
			end
		end

		safeMakeFolder("dex")
		safeMakeFolder("dex/assets")
		safeMakeFolder("dex/saved")
		safeMakeFolder("dex/plugins")
		safeMakeFolder("dex/ModuleCache")
		safeMakeFolder("dex/DecompileCache")
		local gameIdStr = (game.GameId and game.GameId ~= 0) and tostring(game.GameId) or "UnknownGame"
		safeMakeFolder("dex/DecompileCache/" .. gameIdStr)
		safeMakeFolder("dex/DecompileCache/" .. gameIdStr .. "/shared_sources")
		safeMakeFolder("dex/DecompileCache/" .. gameIdStr .. "/" .. tostring(game.PlaceId))
	end



	Main.LocalDepsUpToDate = function()
		return Main.DepsVersionData and Main.ClientVersion == Main.DepsVersionData[1]
	end

	Main.Init = function()
		Main.Elevated = pcall(function() local a = game:GetService("CoreGui"):GetFullName() end)

		Main.InitEnv()

		-- Load Config early to load settings
		Config = Main.LoadModule("Config")

		-- Setup settings file if it doesn't exist
		if env.isfile and not env.isfile("DexPlusPlusSettings.json") then
			Main.SaveCurrentSettings()
		end

		Main.LoadSettings() -- Now safe because Config is loaded

		-- Load other early bootstrap modules
		HookManager = Main.LoadModule("HookManager")
		Bypasses = Main.LoadModule("Bypasses")
		Intro = Main.LoadModule("Intro")

		Main.SetupFilesystem()

		-- Load Lib
		local intro = Main.CreateIntro("Initializing Library")
		Main.LoadModule("IconData")
		Lib = Main.LoadModule("Lib")
		Lib.FastWait()

		-- Inject Lib into the early modules now that Lib is loaded
		Main.AppControls.Config.InitDeps(Main.GetInitDeps())
		Main.AppControls.HookManager.InitDeps(Main.GetInitDeps())
		Main.AppControls.Bypasses.InitDeps(Main.GetInitDeps())
		Main.AppControls.Intro.InitDeps(Main.GetInitDeps())

		-- Init other stuff
		Main.IncompatibleTest()

		-- Init icons
		Main.MiscIcons = Lib.IconMap.new("rbxassetid://6511490623",256,256,16,16)
		Main.MiscIcons:SetDict({
			Reference = 0,             Cut = 1,                         Cut_Disabled = 2,      Copy = 3,               Copy_Disabled = 4,    Paste = 5,                Paste_Disabled = 6,
			Delete = 7,                Delete_Disabled = 8,             Group = 9,             Group_Disabled = 10,    Ungroup = 11,         Ungroup_Disabled = 12,    TeleportTo = 13,
			Rename = 14,               JumpToParent = 15,               ExploreData = 16,      Save = 17,              CallFunction = 18,    CallRemote = 19,          Undo = 20,
			Undo_Disabled = 21,        Redo = 22,                       Redo_Disabled = 23,    Expand_Over = 24,       Expand = 25,          Collapse_Over = 26,       Collapse = 27,
			SelectChildren = 28,       SelectChildren_Disabled = 29,    InsertObject = 30,     ViewScript = 31,        AddStar = 32,         RemoveStar = 33,          Script_Disabled = 34,
			LocalScript_Disabled = 35, Play = 36,                       Pause = 37,            Rename_Disabled = 38,   Empty = 1000
		})
		Main.LargeIcons = Lib.IconMap.new("rbxassetid://129589545519436",256,256,32,32)
		Main.LargeIcons:SetDict({
			Explorer = 0, Properties = 1, Script_Viewer = 2, Watcher = 3, Output = 4, ScriptEdit = 5, Book = 6, Executor = 7, Object = 8, Honey = 9
		})

		-- Fetch version if needed
		intro.SetProgress("Fetching Roblox Version",0.3)
		if Main.Elevated then
			local fileVer = Lib.ReadFile("dex/deps_version.dat")
			Main.ClientVersion = Version()
			if fileVer then
				Main.DepsVersionData = string.split(fileVer,"\n")
				if Main.LocalDepsUpToDate() then
					Main.RobloxVersion = Main.DepsVersionData[2]
				end
			end

			Main.RobloxVersion = Main.RobloxVersion or oldgame:HttpGet("https://clientsettings.roblox.com/v2/client-version/WindowsStudio64/channel/LIVE"):match("(version%-[%w]+)")
		end

		-- Load/Fetch ReflectionMetadata & API dump
		intro.SetProgress("Loading Reflection Metadata",0.35)
		ReflectionMetadata = Main.LoadModule("ReflectionMetadata")

		intro.SetProgress("Fetching API",0.4)
		API = Main.FetchAPI(
			function()
				intro.SetProgress("Fetching API, Please Wait.",0.42)
			end,
			function()
				intro.SetProgress("Fetching API, Please Wait Due To Huge API File To Download.",0.45)
			end,
			function()
				intro.SetProgress("Fetching API, LOL STILL DOWNlOADING? bad wifi xD",0.475)
			end
		)
		Lib.FastWait()
		intro.SetProgress("Fetching RMD",0.5)
		RMD = Main.FetchRMD()
		Lib.FastWait()

		-- Save external deps locally if needed
		if Main.Elevated and env.writefile and not Main.LocalDepsUpToDate() then
			env.writefile("dex/deps_version.dat",Main.ClientVersion.."\n"..Main.RobloxVersion)
			env.writefile("dex/rbx_api.dat",Main.RawAPI)
			env.writefile("dex/rbx_rmd.dat",Main.RawRMD)
		end

		-- Load other modules
		intro.SetProgress("Loading Modules",0.75)
		Main.AppControls.Lib.InitDeps(Main.GetInitDeps()) -- Missing deps now available
		Main.LoadModules()
		Lib.FastWait()

		-- Init other modules
		intro.SetProgress("Initializing Modules",0.8)
		Explorer.Init()
		selection = Explorer.Selection
		Properties.Init()
		Notepad.Init()
		Console.Init()
		SettingsWindow.Init()

		if env.readfile and listfiles then
			if #listfiles("dex/plugins") > 0 then
				intro.SetProgress("Loading Plugin Files",0.8)
				for _, pluginDir in pairs(listfiles("dex/plugins")) do
					local moduleData = Main.LoadPluginFile(pluginDir)
					moduleData.PluginData = moduleData.PluginData or {}

					local pluginFriendlyName = moduleData.PluginData.FriendlyName or moduleData.PluginData.Name or tostring(pluginDir):match("[^/\\]+$") or "Unnamed Plugin"
					local pluginName = moduleData.PluginData.Name or tostring(pluginFriendlyName):gsub(" ", "") or "unnamedPlugin"

					intro.SetProgress("Initializing Plugin: ".. pluginFriendlyName,0.9)

					moduleData.PluginData.Name = pluginName
					moduleData.PluginData.FriendlyName = pluginFriendlyName

					table.insert(Main.Plugins, moduleData)
				end
			end
		end

		Lib.FastWait()

		-- Done
		intro.SetProgress("Complete",1)
		coroutine.wrap(function()
			Lib.FastWait(1.25)
			intro.Close()
		end)()

		-- Init window system, create main menu, show explorer and properties
		Lib.Window.Init()
		Main.CreateMainGui()
		Explorer.Window:Show({Align = "right", Pos = 1, Size = 0.5, Silent = true})
		Properties.Window:Show({Align = "right", Pos = 2, Size = 0.5, Silent = true})
		Main.CheckForUpdatesAsync()

		Lib.DeferFunc(function() Lib.Window.ToggleSide("right") end)
	end

	Main.Uninit = function()
		-- Call Uninit/CleanUp on all active module and plugin instances
		if Apps then
			for name, app in pairs(Apps) do
				if type(app) == "table" then
					if type(app.Uninit) == "function" then
						pcall(app.Uninit)
					elseif type(app.CleanUp) == "function" then
						pcall(app.CleanUp)
					end
				end
			end
		end

		-- Disconnect connections and clear hook chains
		if Main.CleanHooksAndConnections then
			pcall(Main.CleanHooksAndConnections)
		end

		-- Restore getgenv globals to original functions
		if Main.RestoreGlobals then
			pcall(Main.RestoreGlobals)
		end

		if Main.MainGuiMouseEvent then
			pcall(function() Main.MainGuiMouseEvent:Disconnect() end)
			Main.MainGuiMouseEvent = nil
		end
		Main.MenuApps = {}
		Main.AppCards = {}
		Main.MenuSearchText = ""
		Main.MenuSearchBox = nil
		Main.MenuCountLabel = nil
		Main.HiddenAppsContainer = nil
		Main.AppControls = {}
		Main.Plugins = {}
		for _, gui in pairs(Main.GetSecureContainer():GetChildren()) do
			if string.sub(gui.Name,1,5) == "_DPP_" then -- DPP stands for DexPlusPlus
				gui:Destroy()
			end
		end
	end

	Main.Reinit = function()
		if Main.Restarting then return false end
		Main.Restarting = true
		task.spawn(function()
			local ok, err = pcall(function()
				Main.Uninit()
				task.wait(0.2)
				Main.Init()
			end)
			Main.Restarting = false
			if not ok then
				warn("DEX++ restart failed: " .. tostring(err))
			end
		end)
		return true
	end

	return Main
end)()

-- Bundled Plugins
local bundled_plugins = {
	-- [[PLUGIN_SOURCES_PLACEHOLDER]]
}

if writefile and isfolder and makefolder then
	if not isfolder("dex") then makefolder("dex") end
	if not isfolder("dex/plugins") then makefolder("dex/plugins") end
	for pluginName, pluginSource in pairs(bundled_plugins) do
		writefile("dex/plugins/" .. pluginName, pluginSource)
	end
end

-- Start
Main.Init()

--for i,v in pairs(Main.MissingEnv) do print(i,v) end


