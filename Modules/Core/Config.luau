--!strict
--[[
	DEX++ Config Module
	Defines DefaultSettings and handles loading/saving settings.
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
	local rgb = Color3.fromRGB

	local DefaultSettings = {
		Explorer = {
			_Recurse = true,
			Sorting = true,
			TeleportToOffset = Vector3.new(0,0,0),
			ClickToRename = true,
			AutoUpdateSearch = true,
			AutoUpdateMode = 0, -- 0 Default, 1 no tree update, 2 no descendant events, 3 frozen
			PartSelectionBox = true,
			GuiSelectionBox = true,
			CopyPathUseGetChildren = true,
			ViewportContextMenuEnabled = true,
			ViewportContextMenuTrigger = "Middle Click",
			ViewportContextMenuMaxPanels = 10,
			ViewportContextMenuDistanceCloseTime = 10,
			ViewportContextMenuMaxDistance = 50,
			ViewportContextMenu2DFallbackDistance = 50,
			AntiCheatSpoofing = true
		},
		Properties = {
			_Recurse = true,
			MaxConflictCheck = 50,
			ShowDeprecated = true,
			ShowHidden = false,
			ClearOnFocus = false,
			LoadstringInput = true,
			NumberRounding = 3,
			ShowAttributes = true,
			MaxAttributes = 50,
			ScaleType = 0 -- 0 Full Name Shown, 1 Equal Halves
		},
		Theme = {
			_Recurse = true,
			UIRevision = 2,
			Main1 = rgb(24, 27, 32),
			Main2 = rgb(11, 13, 17),
			Outline1 = rgb(42, 48, 58), -- Mainly frames
			Outline2 = rgb(62, 72, 86), -- Mainly button
			Outline3 = rgb(33, 39, 49), -- Mainly textbox
			TextBox = rgb(16, 19, 25),
			Menu = rgb(14, 16, 21),
			ListSelection = rgb(55, 139, 121),
			Button = rgb(29, 34, 42),
			ButtonHover = rgb(43, 91, 83),
			ButtonPress = rgb(35, 74, 69),
			Highlight = rgb(65, 168, 144),
			Text = rgb(237, 241, 245),
			PlaceholderText = rgb(141, 153, 166),
			Important = rgb(232, 89, 102),
			Success = rgb(70, 180, 126),
			Warning = rgb(220, 170, 74),
			AccentSoft = rgb(20, 48, 45),
			ExplorerIconMap = "",
			MiscIconMap = "",
			Syntax = {
				Text = rgb(171, 178, 191),
				Background = rgb(20, 22, 26),
				Selection = rgb(243, 244, 246),
				SelectionBack = rgb(67, 56, 202),
				Operator = rgb(86, 182, 224),
				Number = rgb(209, 154, 102),
				String = rgb(152, 195, 121),
				Comment = rgb(92, 99, 112),
				Keyword = rgb(198, 120, 221),
				Error = rgb(244, 63, 94),
				FindBackground = rgb(234, 179, 8),
				MatchingWord = rgb(75, 85, 99),
				BuiltIn = rgb(229, 192, 123),
				CurrentLine = rgb(31, 41, 55),
				LocalMethod = rgb(97, 175, 239),
				LocalProperty = rgb(224, 108, 117),
				Nil = rgb(209, 154, 102),
				Bool = rgb(209, 154, 102),
				Function = rgb(198, 120, 221),
				Local = rgb(198, 120, 221),
				Self = rgb(224, 108, 117),
				FunctionName = rgb(97, 175, 239),
				Bracket = rgb(171, 178, 191)
			},
		},
		Notepad = {
			ShowMoreInfo = true;
		},
		Window = {
			TitleOnMiddle = false,
			Transparency = .12
		},
		Decompiler = {
			DecompilerFallback = "Konstant",
			PreferDecompilerFallback = false,
			ShinyDecompilerPort = 3000,
			HelperServerPort = 8080,
			UseLocalHelper = false,
			PreferLocalHelperDecompiler = true,
			FastCacheRead = true,
			HelperLogChanges = false,
			HelperLogRateLimit = 5,
			HelperRequestTimeout = 2,
			HelperDecompileTimeout = 15,
			CodeSearchLowImpact = true,
		},
		AutoCheckUpdate = true,
		AutoUpdateRef = "v3.1",
		AutoUpdateAllowBranch = false,
		ClassIcon = "NewDark",
	}

	local function serialize(val: any): any
		if typeof(val) == "Color3" then
			return { R = val.R, G = val.G, B = val.B }
		end
		return val
	end

	local function deserialize(val: any): any
		if type(val) == "table" and val.R and val.G and val.B then
			return Color3.new(val.R, val.G, val.B)
		end
		return val
	end

	Main.ExportSettings = function()
		local rawData = Settings or DefaultSettings
		local function recur(tbl)
			local newTbl = {}
			for i, v in pairs(tbl) do
				if type(v) == "table" then
					newTbl[i] = recur(v)
				else
					newTbl[i] = serialize(v)
				end
			end
			return newTbl
		end
		local serializedData = recur(rawData)
		local s, json = pcall(service.HttpService.JSONEncode, service.HttpService, serializedData)
		if s and json then
			return json
		end
		return "{}"
	end

	Main.LoadSettings = function()
		local function applyModernThemeDefaults()
			if type(Settings.Theme) ~= "table" then
				Settings.Theme = {}
			end
			local defaults = DefaultSettings.Theme
			if Settings.Theme.UIRevision ~= defaults.UIRevision then
				local paletteKeys = {
					"Main1", "Main2", "Outline1", "Outline2", "Outline3", "TextBox", "Menu",
					"ListSelection", "Button", "ButtonHover", "ButtonPress", "Highlight", "Text",
					"PlaceholderText", "Important", "Success", "Warning", "AccentSoft"
				}
				for _, key in ipairs(paletteKeys) do
					Settings.Theme[key] = defaults[key]
				end
				Settings.Theme.UIRevision = defaults.UIRevision
			end
			for key, value in pairs(defaults) do
				if Settings.Theme[key] == nil then
					Settings.Theme[key] = value
				end
			end
		end

		local s, data = pcall(env.readfile or error, "DexPlusPlusSettings.json")
		if s and data and data ~= "" then
			local sDec, decoded = pcall(service.HttpService.JSONDecode, service.HttpService, data)
			if sDec and decoded then
				local function recur(tbl)
					local newTbl = {}
					for i, v in pairs(tbl) do
						if type(v) == "table" then
							newTbl[i] = deserialize(recur(v))
						else
							newTbl[i] = deserialize(v)
						end
					end
					return newTbl
				end
				local deserializedData = recur(decoded)
				local function merge(target, source)
					for k, v in pairs(source) do
						if type(v) == "table" and type(target[k]) == "table" then
							merge(target[k], v)
						else
							target[k] = v
						end
					end
				end
				merge(Settings, deserializedData)
				applyModernThemeDefaults()
			else
				warn("failed to decode settings json")
			end
		else
			Main.ResetSettings()
			applyModernThemeDefaults()
		end
	end

	Main.ResetSettings = function()
		local function recur(t, res)
			for set, val in pairs(t) do
				if type(val) == "table" and val._Recurse then
					if type(res[set]) ~= "table" then
						res[set] = {}
					end
					recur(val, res[set])
				else
					res[set] = val
				end
			end
			return res
		end
		recur(DefaultSettings, Settings)
	end

	Main.SaveCurrentSettings = function()
		if env.writefile then
			pcall(env.writefile, "DexPlusPlusSettings.json", Main.ExportSettings())
		end
	end

	Main.ResetSettings()

	return DefaultSettings
end

return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
