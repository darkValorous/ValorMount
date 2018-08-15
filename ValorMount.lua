-------------------------------------------------
-- ValorMount
-------------------------------------------------
-- Global: ValorAddons
-- SavedVariables: ValorMountGlob ValorMountChar
--------------------------------------------------------------------------------------------------
local _G = _G
local addonName, _ = ...
local vmVersion = "1.0"
if not _G.ValorAddons then _G.ValorAddons = {} end
_G.ValorAddons[addonName] = true

-- Locals
-------------------------------------------------
local tempTable, mountList = {}, {}
local tinsert, tremove, sort, wipe, pairs, random, select
	= _G.tinsert, _G.tremove, _G.sort, _G.wipe, _G.pairs, _G.random, _G.select
local playerRace, playerClass, wasMoonkin
	= select(2, _G.UnitRace("player")), select(2, _G.UnitClass("player")), false
local CreateFrame, GetInstanceInfo, GetNumShapeshiftForms, GetShapeshiftFormInfo, GetSpellInfo, GetSubZoneText, C_Map
	= _G.CreateFrame, _G.GetInstanceInfo, _G.GetNumShapeshiftForms, _G.GetShapeshiftFormInfo, _G.GetSpellInfo, _G.GetSubZoneText, _G.C_Map
local InCombatLockdown, IsFalling, IsFlyableArea, IsInInstance, IsOutdoors, IsPlayerMoving, C_MountJournal, GetBindingKey
	= _G.InCombatLockdown, _G.IsFalling, _G.IsFlyableArea, _G.IsInInstance, _G.IsOutdoors, _G.IsPlayerMoving, _G.C_MountJournal, _G.GetBindingKey
local IsPlayerSpell, IsSubmerged, SecureCmdOptionParse, UnitAffectingCombat, SetOverrideBindingClick, ClearOverrideBindings
	= _G.IsPlayerSpell, _G.IsSubmerged, _G.SecureCmdOptionParse, _G.UnitAffectingCombat, _G.SetOverrideBindingClick, _G.ClearOverrideBindings
local GetBestMapForUnit, GetMapInfo, GetMountIDs, GetMountInfoByID, GetMountInfoExtraByID
	= C_Map.GetBestMapForUnit, C_Map.GetMapInfo, C_MountJournal.GetMountIDs, C_MountJournal.GetMountInfoByID, C_MountJournal.GetMountInfoExtraByID
local vmMain = CreateFrame("Frame", nil, _G.UIParent)
local vmButton = CreateFrame("Button", "ValorMountButton", nil, "SecureActionButtonTemplate")
local spellMap = {
	GhostWolf = 2645,
	ZenFlight = 125883,
	FlightForm = 276029,
	TravelForm = 783,
	AquaticForm = 276012,
	MoonkinForm = 24858,
	RunningWild = 87840,
}
local vmInfo = {
	Enabled = {
		name = "ValorMount is Enabled",
		desc = "If disabled the keybind maps to the |cFF69CCF0[Summon Random Favorite Mount]|r button.",
	},
	WorgenMount = {
		name = "|cFFC79C6EWorgen:|r Running Wild as Favorite",
		desc = "Adds |cFF69CCF0[Running Wild]|r as a favorite ground mount.",
		race = "Worgen",
	},
	WorgenHuman = {
		name = "|cFFC79C6EWorgen:|r Return to Human Form",
		desc = "If in Worgen form, returns you to Human form when mounting.",
		race = "Worgen",
		addon = "ValorWorgen",
	},
	DruidMoonkin = {
		name = "|cFFFF7D0ADruid:|r Return to Moonkin Form",
		desc = "When shifting from |cFF69CCF0[Moonkin Form]|r to |cFF69CCF0[Travel Form]|r, this will return you to |cFF69CCF0[Moonkin Form]|r after.",
		class = "DRUID",
	},
	DruidFormRandom = {
		name = "|cFFFF7D0ADruid:|r Flight Form as Favorite",
		desc = "Adds |cFF69CCF0[Travel Form]|r as a favorite flying mount.",
		class = "DRUID",
	},
	DruidFormAlways = {
		name = "|cFFFF7D0ADruid:|r Always Use Flight Form",
		desc = "Ignore favorites whenever |cFF69CCF0[Flight Form]|r is available.",
		class = "DRUID",
	},
	MonkZenFlight = {
		name = "|cFF00FF96Monk:|r Allow Zen Flight",
		desc = "Only used when moving or falling.",
		class = "MONK",
	},
	ShamanGhostWolf = {
		name = "|cFF0070DEShaman:|r Allow Ghost Wolf",
		desc = "Only used when moving or in combat.",
		class = "SHAMAN",
	},
}

-------------------------------------------------
-- Option Defaults
--------------------------------------------------------------------------------------------------
local function vmSetDefaults()
	wipe(tempTable)
	tempTable = {
		Glob = {
			version = vmVersion,
			charFavs = false,
			groundFly = {},
			softOverrides = {},
		},
		Char = {
			version = vmVersion,
			Enabled = true,
			MonkZenFlight = true,
			ShamanGhostWolf = true,
			WorgenMount = false,	WorgenHuman = true,
			DruidMoonkin = true,	DruidFormRandom = false,	DruidFormAlways = false,
		}
	}
	-- Empty
	if not ValorMountGlob then ValorMountGlob = {} end
	if not ValorMountChar then ValorMountChar = {} end
	if not ValorMountFavs then ValorMountFavs = {} end
	-- Newer Version
	if (not ValorMountChar.version or ValorMountChar.version < vmVersion) then
		for k,_ in pairs(tempTable.Char) do
			ValorMountChar[k] = ValorMountChar[k] ~= nil and ValorMountChar[k] or tempTable.Char[k]
		end
		ValorMountChar.version = vmVersion
	end
	if (not ValorMountGlob.version or ValorMountGlob.version < vmVersion) then
		for k,_ in pairs(tempTable.Glob) do
			ValorMountGlob[k] = ValorMountGlob[k] ~= nil and ValorMountGlob[k] or tempTable.Glob[k]
		end
		ValorMountGlob.version = vmVersion
	end
end

-------------------------------------------------
-- Character-Specific Favorites
--------------------------------------------------------------------------------------------------
local vmCharFavs
do
	local vmCharFavsHooked = false
	local GetCollectedFilterSetting, SetCollectedFilterSetting, SetAllSourceFilters
		= C_MountJournal.GetCollectedFilterSetting, C_MountJournal.SetCollectedFilterSetting, C_MountJournal.SetAllSourceFilters
	local GetNumDisplayedMounts, GetDisplayedMountInfo, SetIsFavorite
		= C_MountJournal.GetNumDisplayedMounts, C_MountJournal.GetDisplayedMountInfo, C_MountJournal.SetIsFavorite

	-- Fires from the Options Menu
	-------------------------------------------------
	local function vmCharFavsInit()
		wipe(ValorMountFavs)
		local mountIds = GetMountIDs()
		for i = 1, #mountIds do
			local mountId = mountIds[i]
			local _, _, _, _, _, _, isFavorite, _, _, hideOnChar = GetMountInfoByID(mountId)
			if isFavorite and not hideOnChar then
				ValorMountFavs[mountId] = true
			end
		end
	end

	-- Fires on Login, prepare MountJournal and load favorites
	-------------------------------------------------
	local function vmCharFavsLoad()
		-- Set Filters to Show Everything
		local setCollected = GetCollectedFilterSetting(_G.LE_MOUNT_JOURNAL_FILTER_COLLECTED)
		local setNotCollected = GetCollectedFilterSetting(_G.LE_MOUNT_JOURNAL_FILTER_NOT_COLLECTED)
		local setUnUsable = GetCollectedFilterSetting(_G.LE_MOUNT_JOURNAL_FILTER_UNUSABLE)
		SetCollectedFilterSetting(_G.LE_MOUNT_JOURNAL_FILTER_COLLECTED, true)
		SetCollectedFilterSetting(_G.LE_MOUNT_JOURNAL_FILTER_NOT_COLLECTED, true)
		SetCollectedFilterSetting(_G.LE_MOUNT_JOURNAL_FILTER_UNUSABLE, true)
		SetAllSourceFilters(true)

		-- Loop the Journal
		local i = 0
		while i < GetNumDisplayedMounts() do
			i = i + 1
			local _, _, _, _, _, _, isFavorite, _, _, _, _, mountId = GetDisplayedMountInfo(i)
			local savedFavorite = ValorMountFavs[mountId] or false
			if savedFavorite ~= isFavorite then
				SetIsFavorite(i, savedFavorite)
				i = savedFavorite and i or i - 1
			end
		end

		-- Cleanup
		SetCollectedFilterSetting(_G.LE_MOUNT_JOURNAL_FILTER_COLLECTED, setCollected)
		SetCollectedFilterSetting(_G.LE_MOUNT_JOURNAL_FILTER_NOT_COLLECTED, setNotCollected)
		SetCollectedFilterSetting(_G.LE_MOUNT_JOURNAL_FILTER_UNUSABLE, setUnUsable)
	end

	-- Function Router
	-------------------------------------------------
	function vmCharFavs(action)
		if not ValorMountGlob.charFavs then return end

		-- Incompatible AddOn Warning
		if _G.IsAddOnLoaded("MountJournalEnhanced") then
			local yellColor = _G.ChatTypeInfo.YELL
			_G.DEFAULT_CHAT_FRAME:AddMessage("ValorMount Warning: Mount Journal Enhanced can interfere with Character-Specific Favorites due to its filters!",
				yellColor.r, yellColor.g, yellColor.b, yellColor.id)
		end

		-- Perform Task
		if action then
			vmCharFavsInit()
		else
			vmCharFavsLoad()
		end

		-- Hook SetIsFavorite
		if not vmCharFavsHooked then
			_G.hooksecurefunc(C_MountJournal, "SetIsFavorite", function()
				if not ValorMountGlob.charFavs then return end
					for i = 1, GetNumDisplayedMounts() do
						local _, _, _, _, _, _, isFavorite, _, _, hideOnChar, isCollected, mountId = GetDisplayedMountInfo(i)
						if mountId and not hideOnChar and isCollected then
							if ValorMountFavs[mountId] and not isFavorite then
								ValorMountFavs[mountId] = nil
							elseif isFavorite and not ValorMountFavs[mountId] then
								ValorMountFavs[mountId] = true
							end
						end
					end
				end)
			vmCharFavsHooked = true
		end
	end
end

-------------------------------------------------
-- Various Functions
-------------------------------------------------
local function vmBindings(self)
	if InCombatLockdown() then return end
	ClearOverrideBindings(self)
	local k1, k2 = GetBindingKey("VALORMOUNTBINDING1")
	if k1 then SetOverrideBindingClick(self, true, k1, self:GetName()) end
	if k2 then SetOverrideBindingClick(self, true, k2, self:GetName()) end
end

local function vmZoneInfo()
	return select(8, GetInstanceInfo()), GetBestMapForUnit("player"), GetSubZoneText()
end

local function vmCanRide()
	-- 33388 Apprentice, 33391 Journeyman
	return IsPlayerSpell(33388) or IsPlayerSpell(33391) or IsPlayerSpell(34090) or IsPlayerSpell(34091) or IsPlayerSpell(90265)
end

local function vmVashjir(mapId)
	-- 201 = Kelp'thar Forest, 203 = Vashj'ir, 204 = Abyssal Depths, 205 = Shimmering Expanse
	if not IsSubmerged() then return false end
	mapId = mapId or GetBestMapForUnit("player")
	return mapId == 204 or mapId == 201 or mapId == 205 or mapId == 203
end

-- Flying Area Detection
-------------------------------------------------
local vmCanFly
do
	-- 191645 = WOD Pathfinder, 233368 = Legion Pathfinder
	-- { instanceId, mapId, SubZoneText, reqSpellId = { -1 = NoFlyZone = 0 = FlyZone, #### = Required Spell Id } }
	-- Will simplify if mapId and SubZoneText are never used here.
	local hardOverrides = {
		-- Pathfinder
		{1220,nil,nil,233368},							-- Broken Isles
		{1116,nil,nil,191645}, {1464,nil,nil,191645},	-- Draenor and Tanaan
		{1158,nil,nil,191645}, {1331,nil,nil,191645},	-- Alliance Garrison
		{1159,nil,nil,191645}, {1160,nil,nil,191645},
		{1152,nil,nil,191645}, {1330,nil,nil,191645},	-- Horde Garrison
		{1153,nil,nil,191645}, {1154,nil,nil,191645},
		-- isFlyableArea False Positives
		{1191,nil,nil,-1},	-- Ashran
		{1669,nil,nil,-1},	-- Argus
		{1463,nil,nil,-1},	-- Helheim
		{1107,nil,nil,-1},	-- Dreadscar Rift (Warlock Class Hall)
		{1479,nil,nil,-1},	-- Skyhold (Warrior Class Hall)
		{1519,nil,nil,-1},	-- The Fel Hammer (Demon Hunter Class Hall)
		{1469,nil,nil,-1},	-- The Heart of Azeroth (Shaman Class Hall)
		{1514,nil,nil,-1},	-- The Wandering Isle (Monk Class Hall)
	}

	function vmCanFly()
		-- No Flying Skill
		if not IsPlayerSpell(34090) and not IsPlayerSpell(34091) and not IsPlayerSpell(90265) then
			return false
		end

		-- Prepare
		local iId, mId, sZt = vmZoneInfo()

		-- Loop Soft Overrides
		for i = 1, #ValorMountGlob["softOverrides"] do
			local zR = ValorMountGlob["softOverrides"][i]
			if zR[1] == iId and zR[2] == mId and zR[3] == sZt then
				if zR[4] > 1 then
					return zR[4] == 2 and true or false
				end
				break
			end
		end

		-- Loop Hard Overrides
		for i = 1, #hardOverrides do
			local zR = hardOverrides[i]
			if (not zR[1] or zR[1] == iId) and (not zR[2] or zR[2] == mId) and (not zR[3] or zR[3] == sZt) then
				if zR[4] > 0 then
					return IsPlayerSpell(zR[4])
				else
					return zR[4] == 0 and true or false
				end
			end
		end

		-- Cannot Fly Here
		if not IsFlyableArea() or IsInInstance() then
			return false
		end

		-- To Infinity, and Beyond!
		return true
	end
end

-------------------------------------------------
-- vmGetMount() - Mount Up!
-------------------------------------------------
-- 125 Riding Turtle, 312 Sea Turtle, 373 Vashj'ir Seahorse, 420 Subdued Seahorse
-- 800 Brinedeep Bottom-Feeder, 838 Fathom Dweller
-- 678 Chauffeured Mechano-Hog, 679 Chauffeured Mekgineer's Chopper
--------------------------------------------------------------------------------------------------
local vmGetMount
do
	local mountPool = {}
	local topPriority = 1
	local specialMount = { [678] = true, [679] = true, [373] = true, } -- 2x Heirlooms + Seahorse
	local mountPriority = {
		ground = 20,
		flying = 40,
		[230] = 20,	-- Ground Mount
		[269] = 20,	--	Water Striders
		[241] = 20,	--	Ahn'Qiraj Mounts
		[284] = 10,	--	Heirloom Mounts
		[248] = 40,	-- Flying Mount
		[247] = 40,	--	Red Flying Cloud
		[231] = 30,	-- Aquatic Mounts (Slow on Land)
		[254] = 30,	--	Underwater Mounts
		[232] = 0,	--	Vashj'ir Seahorse
	}

	local function addToPool(myPriority, spellId)
		if myPriority >= topPriority then
			if myPriority > topPriority then
				topPriority = myPriority
				wipe(mountPool)
			end
			tinsert(mountPool, spellId)
		end
	end

	function vmGetMount(canRide, canFly)
		-- Prepare
		topPriority = 1
		wipe(mountPool)
		local mountIds = GetMountIDs()
		local mapId = GetBestMapForUnit("player")
		local inVashjir = vmVashjir(mapId)

		-- Druid: Travel Form
		if playerClass == "DRUID" and IsPlayerSpell(spellMap.TravelForm) then
			-- No Riding Skill: Priority: (Travel > Heirloom) in Water, (Travel < Heirloom) on Land
			if not canRide then
				addToPool((IsSubmerged() and IsPlayerSpell(spellMap.AquaticForm)) and 15 or 5, spellMap.TravelForm)
			-- DruidFormRandom: Treat Flight Form as a Favorite
			elseif canFly and IsPlayerSpell(spellMap.FlightForm) and ValorMountChar.DruidFormRandom then
				addToPool(mountPriority.flying, spellMap.TravelForm)
			end
		end

		-- WorgenMount: Treat Running Wild as a Favorite
		if playerRace == "Worgen" and ValorMountChar.WorgenMount and IsPlayerSpell(spellMap.RunningWild) then
			addToPool(mountPriority.ground, spellMap.RunningWild)
		end

		-- Favorites
		for i = 1, #mountIds do
			local mountId = mountIds[i]
			local _, spellId, _, _, isUsable, _, isFavorite = GetMountInfoByID(mountId)
			if isUsable and (isFavorite or specialMount[mountId]) then
				local mountType = select(5, GetMountInfoExtraByID(mountId))
				local myPriority = mountPriority[mountType]
				-- In Vashj'ir - Seahorse is King
				if inVashjir and myPriority == 0 then
					myPriority = 100
				-- On Land - Remove Swimming Mounts
				elseif not IsSubmerged() and myPriority == 30 then
					myPriority = 0
				-- Water Strider - When Swimming: +5 Priority, This > Ground but This < Swim
				elseif mountType == 269 and IsSubmerged() then
					myPriority = myPriority + 5
				-- Not Flying - Lower Priority for Flying Mounts
				elseif not canFly and myPriority == mountPriority.flying then
					myPriority = ValorMountGlob.groundFly[mountId] and ValorMountGlob.groundFly[mountId] > 1 and mountPriority.ground or 15
				-- Flying Mount set Ground Only
				elseif canFly and myPriority == mountPriority["flying"] and ValorMountGlob.groundFly[mountId] and ValorMountGlob.groundFly[mountId] > 2 then
					myPriority = mountPriority.ground
				end
				addToPool(myPriority, spellId)
			end
		end

		-- *drum roll*
		if #mountPool > 0 then
			return mountPool[random(#mountPool)]
		else
			return false
		end
	end
end


-- Craft the Macro
-------------------------------------------------
local vmSetMacro
do
	local macroFail = "/run C_MountJournal.SummonByID(0)\n"
	local macroCond = "[nocombat,outdoors,nomounted,novehicleui]"
	local macroText = "/leavevehicle [canexitvehicle]\n/dismount [mounted]\n"

	local function vmMakeMacro()

		-- ValorMount is Disabled
		if not ValorMountChar.Enabled then
			return macroFail
		end

		-- Prepare
		local macroPre, macroPost, macroMount, mountCond, spellId = "","","", macroCond, false
		local canRide, canMount, inVashjir = vmCanRide(), SecureCmdOptionParse(macroCond), vmVashjir()
		local canFly = canRide and vmCanFly() or false

		-- Druid & Travel Form
		-- 5487 = Bear, 768 = Cat, 783 = Travel, 24858 = Moonkin, 114282 = Tree, 210053 = Stag
		if playerClass == "DRUID" and IsPlayerSpell(spellMap.TravelForm) and not inVashjir then
			-- Shapeshift Info
			for i = 1, GetNumShapeshiftForms() do
				local _, fActive, _, fSpellId = GetShapeshiftFormInfo(i)
				if fSpellId == spellMap.TravelForm and fActive then
					macroPost = macroPost .. "\n/cancelform [form]"
					-- DruidMoonkinForm: Shift back into Moonkin from Travel Form
					if wasMoonkin and ValorMountChar.DruidMoonkin then
						macroPost = macroPost .. "\n/cast [noform] " .. GetSpellInfo(spellMap.MoonkinForm)
					end
				elseif fSpellId == spellMap.MoonkinForm then
					wasMoonkin = fActive
				end
			end
			-- DruidFormAlways: Ignore Favorites if Flight Form is possible
			if ValorMountChar.DruidFormAlways and canFly and IsPlayerSpell(spellMap.FlightForm) then
				mountCond = "[outdoors,nomounted,novehicleui]"
				spellId = spellMap.TravelForm
			-- In Combat, Falling, Moving
			elseif not canMount or UnitAffectingCombat("player") or IsPlayerMoving() or IsFalling() then
				mountCond = "[outdoors,nomounted,novehicleui]"
				spellId = spellMap.TravelForm
			end
		end

		-- ShamanGhostWolf
		if playerClass == "SHAMAN" and ValorMountChar.ShamanGhostWolf and IsPlayerSpell(spellMap.GhostWolf) and not inVashjir then
			macroPost = macroPost .. "\n/cancelform [form]"
			if not canMount or UnitAffectingCombat("player") or IsPlayerMoving() then
				mountCond = "[nomounted,noform,novehicleui]"
				spellId = spellMap.GhostWolf
			end
		end

		-- MonkZenFlight
		if playerClass == "MONK" and ValorMountChar.MonkZenFlight and IsPlayerSpell(spellMap.ZenFlight) and canFly and IsOutdoors() and not IsSubmerged() and not inVashjir then
			if not canMount or IsPlayerMoving() or IsFalling() then
				mountCond = "[outdoors,nocombat,nomounted,noform,novehicleui]"
				spellId = spellMap.ZenFlight
			end
		end

		-- WorgenHuman: Worgen Two Forms before Mounting
		if _G.ValorAddons.ValorWorgen and ValorMountChar.WorgenHuman and playerRace == "Worgen" and spellId ~= spellMap.RunningWild and spellId ~= spellMap.TravelForm and _G.ValorWorgenForm then
			macroPre = macroPre .. "/cast [nocombat,nomounted,novehicleui,noform] Two Forms\n"
		end

		-- Select a Mount from Favorites
		if not spellId and canMount and not IsPlayerMoving() and not IsFalling() and not UnitAffectingCombat("player") then
			spellId = vmGetMount(canRide, canFly)
			-- Could not find a favorite
			if not spellId then
				macroMount = macroFail
			end
		end

		-- Prepare Macro
		if spellId then
			macroMount = "/use " .. mountCond .. " " .. GetSpellInfo(spellId) .. "\n"
		end

		-- Return Macro
		return macroPre .. macroMount .. macroText .. macroPost
	end

	function vmSetMacro(bFrame)
		if InCombatLockdown() then return end
		local macroString = _G.strtrim(vmMakeMacro() or macroFail)
		bFrame:SetAttribute("macrotext", macroString)
	end
end


-------------------------------------------------
-- Options Interface
--------------------------------------------------------------------------------------------------
local createMountOptions
do
	local UIDropDownMenu_AddButton, UIDropDownMenu_CreateInfo, UIDropDownMenu_Initialize, UIDropDownMenu_SetButtonWidth
		= _G.UIDropDownMenu_AddButton, _G.UIDropDownMenu_CreateInfo, _G.UIDropDownMenu_Initialize, _G.UIDropDownMenu_SetButtonWidth
	local UIDropDownMenu_SetSelectedValue, UIDropDownMenu_SetText, UIDropDownMenu_SetWidth, PlaySound, SOUNDKIT
		= _G.UIDropDownMenu_SetSelectedValue, _G.UIDropDownMenu_SetText, _G.UIDropDownMenu_SetWidth, _G.PlaySound, _G.SOUNDKIT

	local dropChoices = {
		mount = { "Flying Only", "Both", "Ground Only" },
		zone  = { "Default", "Flying Area", "Ground Only" },
	}

	-- Checkbox Functions
	-------------------------------------------------
	local function checkboxGetValue (self)
		local scopeKey = "ValorMount" .. self.scopeId
		return self.catId ~= "" and _G[scopeKey][self.catId][self.varId] or _G[scopeKey][self.varId] or false
	end

	local function checkboxSetValue (self, v)
		local scopeKey = "ValorMount"..self.scopeId
		if self.catId ~= "" then _G[scopeKey][self.catId][self.varId] = v
		else _G[scopeKey][self.varId] = v
		end
		-- CharFavs Special
		if self.scopeId == "Glob" and self.varId == "charFavs" then
			if v then vmCharFavs(true) end
		end
	end

	local function checkboxOnShow (self)
		self:SetChecked(self:GetValue())
	end

	local function checkboxOnClick (self)
		local checked = self:GetChecked()
		PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		self:SetValue(checked)
	end

	local function newCheckbox(parent, scopeId, catId, varId, dispName, dispDesc)
		if not scopeId or not varId then return end
		local chkId = "ValorMountCheckbox"..scopeId..catId..varId
		local chkFrame = CreateFrame("CheckButton", chkId, parent, "InterfaceOptionsCheckButtonTemplate")
		chkFrame.varId, chkFrame.catId, chkFrame.scopeId = varId, catId, scopeId
		chkFrame.GetValue = checkboxGetValue
		chkFrame.SetValue = checkboxSetValue
		chkFrame:SetScript('OnShow', checkboxOnShow)
		chkFrame:SetScript("OnClick", checkboxOnClick)
		chkFrame:SetChecked(chkFrame:GetValue())
		chkFrame.label = _G[chkFrame:GetName() .. "Text"]
		chkFrame.label:SetText(dispName or "Checkbox")
		chkFrame.tooltipText = dispDesc and dispName or ""
		chkFrame.tooltipRequirement = dispDesc or ""
		return chkFrame
	end

	-- Flying Area Override
	-------------------------------------------------
	local function flyingOverride(iId,mId,sZt,val)
		-- Find/Update Current Setting
		for i = 1, #ValorMountGlob.softOverrides do
			local zR = ValorMountGlob.softOverrides[i]
			if zR[1] == iId and zR[2] == mId and zR[3] == sZt then
				if val then
					tremove(ValorMountGlob.softOverrides, i)
					break
				else
					return zR[4]
				end
			end
		end
		-- New Setting
		if val then
			if val ~= 1 then
				tinsert(ValorMountGlob.softOverrides, {iId,mId,sZt,val})
			end
			return true
		end
		return false
	end

	-- Dropdown Functions
	-------------------------------------------------
	local function dropDownSelect(dropDown, dropType, dropVal)
		UIDropDownMenu_SetSelectedValue(dropDown, dropVal)
		UIDropDownMenu_SetText(dropDown, dropChoices[dropType][dropVal])
	end

	-- Initial Frame Creation
	-------------------------------------------------
	local function createMainOptions(mainFrame)
		-- Prepare
		mainFrame.fromTop = 0
		local f = mainFrame.vmFrames

		-- ValorMount Header
		f.titleHeader = f.titleHeader or mainFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
		f.titleHeader:SetPoint("TOPLEFT", 16, mainFrame.fromTop)
		f.titleHeader:SetText("ValorMount")
		mainFrame.fromTop = mainFrame.fromTop - (f.titleHeader:GetHeight() + 4)

		-- Subheader
		f.titleHeaderInfo = f.titleHeaderInfo or mainFrame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
		f.titleHeaderInfo:SetPoint('TOPLEFT', 20, mainFrame.fromTop)
		f.titleHeaderInfo:SetText('The below option(s) apply only to your current character.')
		mainFrame.fromTop = mainFrame.fromTop - (f.titleHeaderInfo:GetHeight() + 4)

		-- Enabled Checkbox
		f.chkCharEnabled = f.chkCharEnabled or newCheckbox(mainFrame,"Char","","Enabled",vmInfo.Enabled.name,vmInfo.Enabled.desc)
		f.chkCharEnabled:SetPoint("TOPLEFT", 24, mainFrame.fromTop)
		mainFrame.fromTop = mainFrame.fromTop - f.chkCharEnabled:GetHeight()

		-- Sort & Validate Dynamic Preferences
		wipe(tempTable)
		for k,_ in pairs(vmInfo) do
			if k ~= "Enabled" and (not vmInfo[k].race or vmInfo[k].race == playerRace) and (not vmInfo[k].class or vmInfo[k].class == playerClass) then
				tempTable[#tempTable+1] = k
			end
		end

		-- Show Valid Dynamic Preferences
		if (#tempTable > 0) then
			sort(tempTable)
			for kId=1,#tempTable do
				local k = tempTable[kId]
				local chkId = "Chk"..k
				if not f[chkId] then
					local tempDesc = vmInfo[k].desc
					if vmInfo[k].addon and not _G.ValorAddons[vmInfo[k].addon] then
						tempDesc = tempDesc .. "\n\n|cFFff728aRequires Addon:|r "..vmInfo[k].addon
					end
					f[chkId] = newCheckbox(mainFrame,"Char","",k,vmInfo[k].name,tempDesc)
				end
				f[chkId]:SetPoint("TOPLEFT", 24, mainFrame.fromTop)
				mainFrame.fromTop = mainFrame.fromTop - f[chkId]:GetHeight()
			end
		end


		-- Character-Specific Favorites
		mainFrame.fromTop = mainFrame.fromTop - 16 -- Padding
		f.titleHeaderFavs = f.titleHeaderFavs or mainFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
		f.titleHeaderFavs:SetPoint("TOPLEFT", 16, mainFrame.fromTop)
		f.titleHeaderFavs:SetText("Character-Specific Favorites")
		mainFrame.fromTop = mainFrame.fromTop - (f.titleHeaderFavs:GetHeight() + 4)

		-- Text for Character-Specific Favorites
		f.titleHeaderFavsInfo1 = f.titleHeaderFavsInfo1 or mainFrame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
		f.titleHeaderFavsInfo1:SetPoint('TOPLEFT', 20, mainFrame.fromTop)
		f.titleHeaderFavsInfo1:SetJustifyH("LEFT")
		f.titleHeaderFavsInfo1:SetText("ValorMount will attempt to keep a separate Favorites list per character.")
		mainFrame.fromTop = mainFrame.fromTop - (f.titleHeaderFavsInfo1:GetHeight() + 4) -- Smaller Padding

		-- Text for Character-Specific Favorites
		f.titleHeaderFavsInfo2 = f.titleHeaderFavsInfo2 or mainFrame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
		f.titleHeaderFavsInfo2:SetPoint('TOPLEFT', 20, mainFrame.fromTop)
		f.titleHeaderFavsInfo2:SetJustifyH("LEFT")
		f.titleHeaderFavsInfo2:SetText("|cFFff8775Warning: May not function properly when using AddOns that manipulate the Mount Journal!|r")
		mainFrame.fromTop = mainFrame.fromTop - (f.titleHeaderFavsInfo2:GetHeight() + 4)

		-- Checkbox for Character-Specific Favorites
		f.chkGlobFavorites = f.chkGlobFavorites or newCheckbox(mainFrame, "Glob", "", "charFavs", "Character-Specific Favorites")
		f.chkGlobFavorites:SetPoint("TOPLEFT", 24, mainFrame.fromTop)
		mainFrame.fromTop = mainFrame.fromTop - f.chkGlobFavorites:GetHeight()


		-- Flyable Area Override
		mainFrame.fromTop = mainFrame.fromTop - 16 -- Padding
		f.titleHeaderFlying = f.titleHeaderFlying or mainFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
		f.titleHeaderFlying:SetPoint("TOPLEFT", 16, mainFrame.fromTop)
		f.titleHeaderFlying:SetText("Flyable Area Override")
		mainFrame.fromTop = mainFrame.fromTop - (f.titleHeaderFlying:GetHeight() + 4)

		-- Flyable Area Override Help
		f.titleHeaderFlyingInfo1 = f.titleHeaderFlyingInfo1 or mainFrame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
		f.titleHeaderFlyingInfo1:SetPoint('TOPLEFT', 20, mainFrame.fromTop)
		f.titleHeaderFlyingInfo1:SetText("Use this to override how mounts are chosen for this specific area.")
		mainFrame.fromTop = mainFrame.fromTop - (f.titleHeaderFlyingInfo1:GetHeight() + 4) -- Smaller padding

		-- Flyable Area Override Debug Information
		f.titleHeaderFlyingInfo2 = f.titleHeaderFlyingInfo2 or mainFrame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
		f.titleHeaderFlyingInfo2:SetPoint('TOPLEFT', 20, mainFrame.fromTop)
		f.titleHeaderFlyingInfo2:SetText("InstanceId: MapId: Area:")
		mainFrame.fromTop = mainFrame.fromTop - (f.titleHeaderFlyingInfo2:GetHeight() + 8)

		-- Flyable Area Override Dropdown
		local iId, mId, sZt = vmZoneInfo()
		local curVal = flyingOverride(iId,mId,sZt)
		f.dropDownFlying = f.dropDownFlying or CreateFrame("Frame", nil, mainFrame, "UIDropDownMenuTemplate")
		f.dropDownFlying.zoneInfo = {iId,mId,sZt}
		f.dropDownFlying.initialize = function()
			for i,n in ipairs(dropChoices.zone) do
				local row = UIDropDownMenu_CreateInfo()
				row.text = n
				row.value = i
				row.checked = curVal == i or false
				row.func = function (self)
					flyingOverride(f.dropDownFlying.zoneInfo[1], f.dropDownFlying.zoneInfo[2], f.dropDownFlying.zoneInfo[3], self.value)
					dropDownSelect(f.dropDownFlying, "zone", self.value)
				end
				UIDropDownMenu_AddButton(row)
			end
		end
		UIDropDownMenu_SetWidth(f.dropDownFlying, 100)
		UIDropDownMenu_SetButtonWidth(f.dropDownFlying, 100)
		UIDropDownMenu_Initialize(f.dropDownFlying, f.dropDownFlying.initialize)
		f.dropDownFlying:SetPoint("TOPLEFT", 12, mainFrame.fromTop)
		mainFrame.fromTop = mainFrame.fromTop - f.dropDownFlying:GetHeight()


		-- Flying Ground Mounts
		mainFrame.fromTop = mainFrame.fromTop - 16 -- Padding
		f.titleHeaderMounts = f.titleHeaderMounts or mainFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
		f.titleHeaderMounts:SetPoint("TOPLEFT", 16, mainFrame.fromTop)
		f.titleHeaderMounts:SetText("Your Favorite Flying Mounts")
		mainFrame.fromTop = mainFrame.fromTop - (f.titleHeaderMounts:GetHeight() + 4)

		-- Text for found Favorites
		f.titleHeaderMountsInfo1 = f.titleHeaderMountsInfo1 or mainFrame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
		f.titleHeaderMountsInfo1:SetPoint('TOPLEFT', 20, mainFrame.fromTop)
		f.titleHeaderMountsInfo1:SetText('Use this to override how specific flying mounts are considered.')

		-- Text for no Favorites
		f.titleHeaderMountsInfo2 = f.titleHeaderMountsInfo2 or mainFrame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
		f.titleHeaderMountsInfo2:SetPoint('TOPLEFT', 20, mainFrame.fromTop)
		f.titleHeaderMountsInfo2:SetText('You have no usable flying mounts set as favorites!')
		mainFrame.fromTop = mainFrame.fromTop - (f.titleHeaderMountsInfo2:GetHeight() + 8)
	end

	-- Main Function - Mount Frames & Refresh Zone
	-------------------------------------------------
	function createMountOptions(parentFrame)
		-- Create the Static Part of the Menu
		if not parentFrame.contentFrame.fromTop then
			createMainOptions(parentFrame.contentFrame)
		end

		-- Prepare
		local mainFrame = parentFrame.contentFrame
		local f = mainFrame.vmFrames
		local mF = mainFrame.vmMounts

		-- Zone Override
		local iId, mId, sZt = vmZoneInfo()
		f.dropDownFlying.zoneInfo = {iId,mId,sZt}
		dropDownSelect(f.dropDownFlying, "zone", flyingOverride(iId,mId,sZt) or 1)

		local mapInfo = GetMapInfo(mId)
		local mapName = mapInfo.name
		local instanceName = select(1, GetInstanceInfo())
		if sZt == "" then sZt = "(blank)" end
		f.titleHeaderFlyingInfo2:SetText(
			"InstanceId: |cFFF58CBA" .. iId .. " (" .. instanceName .. ")|r  " ..
			"MapId: |cFF00FF96" .. mId .. " (" .. mapName .. ")|r  " ..
			"Area: |cFF69CCF0" .. sZt .. "|r"
		)

		-- Hide All Created Checkboxes
		f.titleHeaderMountsInfo1:Hide()
		f.titleHeaderMountsInfo2:Hide()
		for k,_ in pairs(mF) do
			mF[k]:Hide()
		end

		-- Holy Flying Favorites Batman!
		wipe(tempTable)
		wipe(mountList)
		local mountIds = GetMountIDs()
		for i=1,#mountIds do
			local mountId = mountIds[i]
			local mountName, _, _, _, _, _, isFavorite, _, _, hideOnChar = GetMountInfoByID(mountId)
			if isFavorite and not hideOnChar then
				local mountType = select(5, GetMountInfoExtraByID(mountId))
				if mountType == 247 or mountType == 248 then
					mountList[mountName] = mountId
					tempTable[#tempTable+1] = mountName
				end
			end
		end

		-- Are there favorites set?
		local fromTopPos = mainFrame.fromTop
		if (#tempTable > 0) then
			f.titleHeaderMountsInfo1:Show()
			sort(tempTable)
			for i=1,#tempTable do
				local mountName = tempTable[i]
				local mountId = mountList[mountName]
				local mountLbl = "L" .. mountId
				if not mF[mountId] then
					mF[mountId] = { ["d"] = nil, ["l"] = nil }
					mF[mountId] = CreateFrame("Frame", nil, mainFrame, "UIDropDownMenuTemplate")
					mF[mountId].initialize = function()
						for y,n in ipairs(dropChoices.mount) do
							local row = UIDropDownMenu_CreateInfo()
							row.text = n
							row.value = y
							row.func = function(self)
								ValorMountGlob.groundFly[mountId] = self.value > 1 and self.value or nil
								dropDownSelect(mF[mountId], "mount", self.value)
							end
							UIDropDownMenu_AddButton(row)
						end
					end
					UIDropDownMenu_SetWidth(mF[mountId], 100)
					UIDropDownMenu_SetButtonWidth(mF[mountId], 100)
					UIDropDownMenu_Initialize(mF[mountId], mF[mountId].initialize)
					dropDownSelect(mF[mountId], "mount", ValorMountGlob.groundFly[mountId] or 1)
					mF[mountLbl] = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
					mF[mountLbl]:SetText(mountName)
				end
				mF[mountId]:SetPoint("TOPLEFT", 12, fromTopPos)
				mF[mountId]:Show()
				mF[mountLbl]:SetPoint("TOPLEFT", 153, fromTopPos+2)
				mF[mountLbl]:SetHeight(mF[mountId]:GetHeight())
				mF[mountLbl]:Show()
				fromTopPos = fromTopPos - mF[mountId]:GetHeight()
			end
		else
			f.titleHeaderMountsInfo2:Show()	-- No Favorites
		end

		-- Update for Scrollbar
		parentFrame.scrollChild:SetHeight(math.ceil(math.abs(fromTopPos))+10)
	end
end


-- Setup the Macro Frame
-------------------------------------------------
vmButton:SetAttribute("type", "macro")
vmButton:RegisterEvent("PLAYER_LOGIN")
vmButton:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		if not _G.MountJournalSummonRandomFavoriteButton then _G.CollectionsJournal_LoadUI() end

		-- Load Config Defaults if Necessary
		if not ValorMountGlob or not ValorMountGlob.version or ValorMountGlob.version < vmVersion or
		   not ValorMountChar or not ValorMountChar.version or ValorMountChar.version < vmVersion then
			vmSetDefaults()
		end

		-- Set Favorites
		ValorMountFavs = ValorMountFavs or {}
		if ValorMountGlob.charFavs then
			vmCharFavs()
		end

		-- Register for Events
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:RegisterEvent("LEARNED_SPELL_IN_TAB")
		self:RegisterEvent("PLAYER_REGEN_DISABLED")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
		self:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
		self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
		self:RegisterEvent("ZONE_CHANGED")
		self:RegisterEvent("UPDATE_BINDINGS")
		self:SetScript("PreClick", vmSetMacro)
		vmBindings(self)

	-- Keybindings
	elseif event == "UPDATE_BINDINGS" then
		vmBindings(self)

	-- Update Macro
	else
		vmSetMacro(self)
	end
end)


-- Setup the Options Frame
-------------------------------------------------
vmMain.scrollFrame = CreateFrame("ScrollFrame", "ValorMountScroll", vmMain, "UIPanelScrollFrameTemplate")
vmMain.scrollChild = CreateFrame("Frame", nil, vmMain.scrollFrame)
vmMain.scrollUpButton = _G["ValorMountScrollScrollBarScrollUpButton"]
vmMain.scrollUpButton:ClearAllPoints()
vmMain.scrollUpButton:SetPoint("TOPRIGHT", vmMain.scrollFrame, "TOPRIGHT", -8, 6)
vmMain.scrollDownButton = _G["ValorMountScrollScrollBarScrollDownButton"]
vmMain.scrollDownButton:ClearAllPoints()
vmMain.scrollDownButton:SetPoint("BOTTOMRIGHT", vmMain.scrollFrame, "BOTTOMRIGHT", -8, -6)
vmMain.scrollBar = _G["ValorMountScrollScrollBar"]
vmMain.scrollBar:ClearAllPoints()
vmMain.scrollBar:SetPoint("TOP", vmMain.scrollUpButton, "BOTTOM", 0, 0)
vmMain.scrollBar:SetPoint("BOTTOM", vmMain.scrollDownButton, "TOP", 0, 0)
vmMain.scrollFrame:SetScrollChild(vmMain.scrollChild)
vmMain.scrollFrame:SetPoint("TOPLEFT", vmMain, "TOPLEFT", 0, -16)
vmMain.scrollFrame:SetPoint("BOTTOMRIGHT", vmMain, "BOTTOMRIGHT", 0, 16)
vmMain.scrollChild:SetSize(600, 1)
vmMain.contentFrame = CreateFrame("Frame", nil, vmMain.scrollChild)
vmMain.contentFrame:SetAllPoints(vmMain.scrollChild)
vmMain.contentFrame.vmFrames = {}
vmMain.contentFrame.vmMounts = {}
vmMain.refresh = function (self)
	createMountOptions(self)
	self:SetScript("OnShow", createMountOptions)
	self.refresh = function () return end
end
vmMain.name = "ValorMount"
_G.InterfaceOptions_AddCategory(vmMain)



-- Slash Commands and Key Bindings
-------------------------------------------------
_G["BINDING_NAME_VALORMOUNTBINDING1"] = "Mount/Dismount"
_G["BINDING_HEADER_VALORMOUNT"] = "ValorMount"
_G.SLASH_VALORMOUNT1 = "/valormount"
_G.SLASH_VALORMOUNT2 = "/vm"
_G.SlashCmdList.VALORMOUNT = function()
	if not vmMain.contentFrame.fromTop then
		_G.InterfaceOptionsFrame_OpenToCategory(vmMain)
	end
	_G.InterfaceOptionsFrame_OpenToCategory(vmMain)
end