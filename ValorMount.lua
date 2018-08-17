-------------------------------------------------
-- ValorMount
-------------------------------------------------
-- Global: ValorAddons
-- SavedVariables: ValorMountGlobal ValorMountLocal
--------------------------------------------------------------------------------------------------
local _G = _G
local addonName = ...
local vmVersion = "2.1"
if not _G.ValorAddons then _G.ValorAddons = {} end
_G.ValorAddons[addonName] = true

-- Locals
-------------------------------------------------
local tempOne = {}
local tinsert, tremove, sort, wipe, pairs, random, select, format, unpack
	= _G.tinsert, _G.tremove, _G.sort, _G.wipe, _G.pairs, _G.random, _G.select, _G.format, _G.unpack
local CreateFrame, GetInstanceInfo, GetNumShapeshiftForms, GetShapeshiftFormInfo, GetSpellInfo, GetSubZoneText
	= _G.CreateFrame, _G.GetInstanceInfo, _G.GetNumShapeshiftForms, _G.GetShapeshiftFormInfo, _G.GetSpellInfo, _G.GetSubZoneText
local InCombatLockdown, IsFalling, IsFlyableArea, IsInInstance, IsOutdoors, IsPlayerMoving, IsMounted, UnitAura, GetBindingKey
	= _G.InCombatLockdown, _G.IsFalling, _G.IsFlyableArea, _G.IsInInstance, _G.IsOutdoors, _G.IsPlayerMoving, _G.IsMounted, _G.UnitAura, _G.GetBindingKey
local IsPlayerSpell, IsSubmerged, SecureCmdOptionParse, UnitAffectingCombat, SetOverrideBindingClick, ClearOverrideBindings
	= _G.IsPlayerSpell, _G.IsSubmerged, _G.SecureCmdOptionParse, _G.UnitAffectingCombat, _G.SetOverrideBindingClick, _G.ClearOverrideBindings
local GetMountInfoExtraByID, GetNumDisplayedMounts, GetDisplayedMountInfo, GetBestMapForUnit
	= _G.C_MountJournal.GetMountInfoExtraByID, _G.C_MountJournal.GetNumDisplayedMounts, _G.C_MountJournal.GetDisplayedMountInfo, _G.C_Map.GetBestMapForUnit
local GetMapInfo, GetMountIDs, GetMountInfoByID
	=  _G.C_Map.GetMapInfo, _G.C_MountJournal.GetMountIDs, _G.C_MountJournal.GetMountInfoByID
local playerRace, playerClass, playerFaction, playerLevel
	= select(2, _G.UnitRace("player")), select(2, _G.UnitClass("player")), _G.UnitFactionGroup("player"), _G.UnitLevel("player")
local vmPrefs = CreateFrame("Frame", nil, _G.UIParent)
local vmMain = CreateFrame("Button", "ValorMountButton", nil, "SecureActionButtonTemplate")
local spellMap = {
	GhostWolf = { id = 2645 },
	ZenFlight = { id = 125883 },
	FlightForm = { id = 276029 },
	TravelForm = { id = 783 },
	AquaticForm = { id = 276012 },
	MoonkinForm = { id = 24858 },
	RunningWild = { id = 87840 },
	TwoForms = { id = 68996 },
}
for k in pairs(spellMap) do spellMap[k].name = GetSpellInfo(spellMap[k].id) end

-------------------------------------------------
-- Option Defaults
--------------------------------------------------------------------------------------------------
local vmSetDefaults
do
	local vmDefaults = {
		Global = {
			localFavs = false,
			groundFly = {},
			softOverrides = {},
		},
		Local = {
			mountDb = {},
			Enabled = true,
			MonkZenFlight = true,
			ShamanGhostWolf = true,
			WorgenMount = false,	WorgenHuman = true,
			DruidMoonkin = true,	DruidFormRandom = false,	DruidFormAlways = false,
		}
	}

	function vmSetDefaults()
		-- Create Table
		ValorMountGlobal = ValorMountGlobal or {}
		ValorMountLocal = ValorMountLocal or {}
		-- Set Empty Defaults
		if (not ValorMountLocal.version or ValorMountLocal.version < vmVersion) then
			for k in pairs(vmDefaults.Local) do
				ValorMountLocal[k] = ValorMountLocal[k] ~= nil and ValorMountLocal[k] or vmDefaults.Local[k]
			end
			ValorMountLocal.version = vmVersion
		end
		if (not ValorMountGlobal.version or ValorMountGlobal.version < vmVersion) then
			for k in pairs(vmDefaults.Global) do
				ValorMountGlobal[k] = ValorMountGlobal[k] ~= nil and ValorMountGlobal[k] or vmDefaults.Global[k]
			end
			ValorMountGlobal.version = vmVersion
		end
	end
end


-------------------------------------------------
-- Mount DB - Keep table of only favorites, save on calls to GetMountInfo*
--------------------------------------------------------------------------------------------------
-- ValorMountLocal.mountDb = {	{ mountId, mountName, mountType, spellId } }
local function vmMountDb (isFavorite, mountId, mountName, mountType, spellId)
	-- Only isFavorite and mountId are required
	if not mountId then return end

	-- Scan DB for this mountId to remove or do nothing
	for i = 1, #ValorMountLocal.mountDb do
		local row = ValorMountLocal.mountDb[i]
		if row[1] == mountId then
			if not isFavorite then
				tremove(ValorMountLocal.mountDb, i)
				break
			end
			return
		end
	end

	-- Add to DB
	if isFavorite and mountId and mountName and mountType and spellId then
		tinsert(ValorMountLocal.mountDb, { mountId, mountName, mountType, spellId })
	end

	-- Sort, not for fun, for the Options Menu.
	sort(ValorMountLocal.mountDb, function (a,b) return a[2] < b[2] end)
end

-------------------------------------------------
-- Handles the db when Char Specific Favorites is disabled
--------------------------------------------------------------------------------------------------
local vmBuildDb
do
	-- Save Specific Mount
	local function vmSaveMount(mountId)
		local mountName, spellId, _, _, _, _, isFavorite, _, _, hideOnChar, isCollected = GetMountInfoByID(mountId)
		if isFavorite and isCollected and not hideOnChar then
			local _, _, _, _, mountType = GetMountInfoExtraByID(mountId)
			vmMountDb(isFavorite, mountId, mountName, mountType, spellId)
		end
	end

	-- Fresh Build
	local function vmSaveAll()
		wipe(ValorMountLocal.mountDb)
		local mountIds = GetMountIDs()
		for i = 1, #mountIds do
			local mountId = mountIds[i]
			vmSaveMount(mountId)
		end
	end

	-- Function Router
	function vmBuildDb (isFavorite, mountId)
		-- (false,###) - Remove Mount
		if not isFavorite and mountId then
			vmMountDb(isFavorite, mountId)
		-- (true,###) - Add Mount
		elseif isFavorite and mountId then
			vmSaveMount(mountId)
		-- (true) = Fresh Build
		elseif isFavorite and not mountId then
			vmSaveAll()
		end
	end

end

-------------------------------------------------
-- Restore Character-Specific Favorites at Login
--------------------------------------------------------------------------------------------------
local function vmLocalFavs()
	if not ValorMountGlobal.localFavs then return end
	local filterCollected, filterNotCollected, filterUnUsable
		= _G.LE_MOUNT_JOURNAL_FILTER_COLLECTED, _G.LE_MOUNT_JOURNAL_FILTER_NOT_COLLECTED, _G.LE_MOUNT_JOURNAL_FILTER_UNUSABLE
	local GetCollectedFilterSetting, SetCollectedFilterSetting, SetAllSourceFilters, SetIsFavorite
		= _G.C_MountJournal.GetCollectedFilterSetting, _G.C_MountJournal.SetCollectedFilterSetting, _G.C_MountJournal.SetAllSourceFilters, _G.C_MountJournal.SetIsFavorite

	-- Incompatible AddOn Warning
	if _G.IsAddOnLoaded("MountJournalEnhanced") then
		local yellColor = _G.ChatTypeInfo.YELL
		_G.DEFAULT_CHAT_FRAME:AddMessage("ValorMount Warning: Mount Journal Enhanced can interfere with Character-Specific Favorites due to its filters!",
			yellColor.r, yellColor.g, yellColor.b, yellColor.id)
	end

	-- Keep Current Filters
	local setCollected = GetCollectedFilterSetting(filterCollected)
	local setNotCollected = GetCollectedFilterSetting(filterNotCollected)
	local setUnUsable = GetCollectedFilterSetting(filterUnUsable)

	-- Set Filters to Show Everything
	if not setCollected then SetCollectedFilterSetting(filterCollected, true) end
	if not setNotCollected then SetCollectedFilterSetting(filterNotCollected, true) end
	if not setUnUsable then SetCollectedFilterSetting(filterUnUsable, true) end
	SetAllSourceFilters(true)

	-- Load IDs from Favorites
	wipe(tempOne)
	for i = 1, #ValorMountLocal.mountDb do
		tempOne[ValorMountLocal.mountDb[i][1]] = true
	end

	-- Flip through the Journal
	local i = 0
	while i < GetNumDisplayedMounts() do
		i = i + 1
		local _, _, _, _, _, _, isFavorite, _, _, hideOnChar, isCollected, mountId = GetDisplayedMountInfo(i)
		local savedFavorite = (not hideOnChar and isCollected and tempOne[mountId]) or false
		if savedFavorite ~= isFavorite then
			SetIsFavorite(i, savedFavorite)
			i = savedFavorite and i or i - 1
		end
	end

	-- Restore Main Filters
	if not setCollected then SetCollectedFilterSetting(filterCollected, false) end
	if not setNotCollected then SetCollectedFilterSetting(filterNotCollected, false) end
	if not setUnUsable then SetCollectedFilterSetting(filterUnUsable, false) end
end

-------------------------------------------------
-- Various Functions
-------------------------------------------------
local function vmBindings(theButton)
	if InCombatLockdown() then return end
	ClearOverrideBindings(theButton)
	local k1, k2 = GetBindingKey("VALORMOUNTBINDING1")
	if k1 then SetOverrideBindingClick(theButton, true, k1, theButton:GetName()) end
	if k2 then SetOverrideBindingClick(theButton, true, k2, theButton:GetName()) end
end

local vmSetZoneInfo
do
	-- 191645 = WOD Pathfinder, 233368 = Legion Pathfinder
	local hardOverrides = {
		-- Pathfinder
		[1220] = 233368,
		[1116] = 191645, [1464] = 191645,	-- Draenor and Tanaan
		[1158] = 191645, [1331] = 191645,	-- Alliance Garrison
		[1159] = 191645, [1160] = 191645,
		[1152] = 191645, [1330] = 191645,	-- Horde Garrison
		[1153] = 191645, [1154] = 191645,
		-- isFlyableArea False Positives
		[1191] = -1,	-- Ashran
		[1669] = -1,	-- Argus
		[1463] = -1,	-- Helheim
		[1107] = -1,	-- Dreadscar Rift (Warlock Class Hall)
		[1479] = -1,	-- Skyhold (Warrior Class Hall)
		[1519] = -1,	-- The Fel Hammer (Demon Hunter Class Hall)
		[1469] = -1,	-- The Heart of Azeroth (Shaman Class Hall)
		[1514] = -1,	-- The Wandering Isle (Monk Class Hall)
	}

	local function vmGetInstanceInfo()
		local instanceName, _, _, _, _, _, _, instanceId = GetInstanceInfo()
		return instanceName, instanceId
	end

	function vmSetZoneInfo(newValue)
		-- Create Table
		vmMain.zoneInfo = vmMain.zoneInfo or {}

		-- We are not where we once were.
		if vmMain.zoneChanged then
			vmMain.zoneInfo.instanceName, vmMain.zoneInfo.instanceId = vmGetInstanceInfo()
			vmMain.zoneInfo.mapId, vmMain.zoneInfo.areaText = GetBestMapForUnit("player"), GetSubZoneText()
			vmMain.zoneInfo.zoneHard = hardOverrides[vmMain.zoneInfo.instanceId] or false
			vmMain.zoneInfo.zoneSoft = 1
			if vmMain.zoneInfo.mapId then
				local mapInfo = GetMapInfo(vmMain.zoneInfo.mapId)
				vmMain.zoneInfo.mapName = mapInfo.name
			else
				vmMain.zoneInfo.mapId = 0
				vmMain.zoneInfo.mapName = ""
			end
		end

		-- Only loop softOverrides if necessary.
		if newValue or vmMain.zoneChanged then
			for i = 1, #ValorMountGlobal.softOverrides do
				local zoneData = ValorMountGlobal.softOverrides[i]
				if zoneData[1] == vmMain.zoneInfo.instanceId and zoneData[2] == vmMain.zoneInfo.mapId and zoneData[3] == vmMain.zoneInfo.areaText then
					if newValue then
						tremove(ValorMountGlobal.softOverrides, i)
					end
					vmMain.zoneInfo.zoneSoft = newValue or 1
				end
			end
		end

		-- Done
		vmMain.zoneChanged = false
		if newValue then
			if newValue > 1 then
				tinsert(ValorMountGlobal.softOverrides, { vmMain.zoneInfo.instanceId, vmMain.zoneInfo.mapId, vmMain.zoneInfo.areaText, newValue })
			end
			vmMain.zoneInfo.zoneSoft = newValue
		end

		-- Update Options Dropdown
		if vmPrefs.contentFrame.fromTop then
			vmPrefs.contentFrame.vmFrames.dropDownFlying.updateDropDown()
			vmPrefs.contentFrame.vmFrames.titleHeaderFlyingInfo2.updateInfoText()
		end
	end
end

local function vmCanRide()
	-- 33388 Apprentice, 33391 Journeyman, 34090 Expert, 34091 Artisan, 90265 Master
	return IsPlayerSpell(33388) or IsPlayerSpell(33391) or IsPlayerSpell(34090) or IsPlayerSpell(34091) or IsPlayerSpell(90265)
end

local function vmVashjir()
	-- 201 = Kelp'thar Forest, 203 = Vashj'ir, 204 = Abyssal Depths, 205 = Shimmering Expanse
	if not IsSubmerged() then return false end
	return vmMain.zoneInfo.mapId == 204 or vmMain.zoneInfo.mapId == 201 or vmMain.zoneInfo.mapId == 205 or vmMain.zoneInfo.mapId == 203
end

-- Flying Area Detection
-------------------------------------------------
local function vmCanFly()
	-- No Flying Skill
	if not IsPlayerSpell(34090) and not IsPlayerSpell(34091) and not IsPlayerSpell(90265) then
		return false
	end

	-- Overrides
	-- softOverride: 1 = Ignore, 2 = Flying, 3 = Ground
	if vmMain.zoneInfo.zoneSoft > 1 then
		return vmMain.zoneInfo.zoneSoft == 2 and true or false
	end
	-- hardOverride: false = Ignore, -1 = Ground, 0 = Flying, >0 = reqSpellId
	if vmMain.zoneInfo.zoneHard then
		if vmMain.zoneInfo.zoneHard > 0 then
			return IsPlayerSpell(vmMain.zoneInfo.zoneHard)
		else
			return vmMain.zoneInfo.zoneHard == 0 and true or false
		end
	end

	-- Cannot Fly Here
	if not IsFlyableArea() or IsInInstance() then
		return false
	end

	-- To Infinity, and Beyond!
	return true
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
	local topPriority = 1
	local HEIRLOOM, GROUND, AQUATIC, FLYING = 10, 20, 30, 40
	local WATER_STRIDER, VASHJIR_SEAHORSE, HEIRLOOM_ALLIANCE, HEIRLOOM_HORDE
		= 269, 75207, 179245, 179244
	local mountPriority = {
		[230] = GROUND,		-- Ground Mount
		[269] = GROUND,		--	Water Striders
		[241] = GROUND,		--	Ahn'Qiraj Mounts
		[284] = HEIRLOOM,	--	Heirloom Mounts
		[248] = FLYING,		-- Flying Mount
		[247] = FLYING,		--	Red Flying Cloud
		[231] = AQUATIC,	-- Aquatic Mounts (Slow on Land)
		[254] = AQUATIC,	--	Underwater Mounts
		[232] = 0,			--	Vashj'ir Seahorse
	}

	-- In the pool
	local function addToPool(myPriority, spellId)
		if myPriority >= topPriority then
			if myPriority > topPriority then
				topPriority = myPriority
				wipe(tempOne)
			end
			tinsert(tempOne, spellId)
		end
	end

	function vmGetMount(canRide, canFly)
		-- Prepare
		topPriority = 1
		wipe(tempOne)
		local mountDb = ValorMountLocal.mountDb

		-- Vashj'ir Override - Always bet on the Seahorse
		if vmVashjir() and IsPlayerSpell(VASHJIR_SEAHORSE) then
			return VASHJIR_SEAHORSE
		end

		-- Add Heirlooms
		if not canRide or playerLevel < 20 then
			if playerFaction == "Alliance" and IsPlayerSpell(HEIRLOOM_ALLIANCE) then
				addToPool(HEIRLOOM, HEIRLOOM_ALLIANCE)
			elseif playerFaction == "Horde" and IsPlayerSpell(HEIRLOOM_HORDE) then
				addToPool(HEIRLOOM, HEIRLOOM_HORDE)
			end
		end

		-- Druid: Travel Form
		if playerClass == "DRUID" and IsPlayerSpell(spellMap.TravelForm.id) then
			-- No Riding Skill: Priority: (Travel > Heirloom) in Water, (Travel < Heirloom) on Land
			if not canRide then
				addToPool((IsSubmerged() and IsPlayerSpell(spellMap.AquaticForm.id)) and 15 or 5, spellMap.TravelForm.id)
			-- DruidFormRandom: Treat Flight Form as a Favorite
			elseif canFly and IsPlayerSpell(spellMap.FlightForm.id) and ValorMountLocal.DruidFormRandom then
				addToPool(FLYING, spellMap.TravelForm.id)
			end
		end

		-- WorgenMount: Treat Running Wild as a Favorite
		if playerRace == "Worgen" and ValorMountLocal.WorgenMount and IsPlayerSpell(spellMap.RunningWild.id) then
			addToPool(GROUND, spellMap.RunningWild.id)
		end

		-- Favorites
		for i = 1, #mountDb do
			local mountId, _, mountType, spellId = unpack(mountDb[i])
			local _, _, _, _, isUsable = GetMountInfoByID(mountId)
			if isUsable then
				local myPriority = mountPriority[mountType] or 0
				-- On Land - Deprioritize Aquatic Mounts
				if not IsSubmerged() and myPriority == AQUATIC then
					myPriority = 0
				-- Water Strider - +5 Priority When Swimming: This > Ground, This < Aquatic
				elseif mountType == WATER_STRIDER and IsSubmerged() then
					myPriority = myPriority + 5
				-- Not Flying - Lower Priority for Flying Mounts
				elseif not canFly and myPriority == FLYING then
					myPriority = ValorMountGlobal.groundFly[mountId] and ValorMountGlobal.groundFly[mountId] > 1 and GROUND or (HEIRLOOM + 5)
				-- Flying Mount set to Ground Only
				elseif canFly and myPriority == FLYING and ValorMountGlobal.groundFly[mountId] and ValorMountGlobal.groundFly[mountId] > 2 then
					myPriority = GROUND
				end
				addToPool(myPriority, spellId)
			end
		end

		-- *drum roll*
		if #tempOne > 0 then
			return tempOne[random(#tempOne)]
		end
		return false
	end
end


-- Craft the Macro
-------------------------------------------------
local vmSetMacro
do
	local wasMoonkin = false
	local macroFail = "/run C_MountJournal.SummonByID(0)\n"
	local mountCond = "[outdoors,nocombat,nomounted,novehicleui]"
	local mountDismount = "/leavevehicle [canexitvehicle]\n/dismount [mounted]\n"

	local function vmMakeMacro()

		-- ValorMount is Disabled
		if not ValorMountLocal.Enabled then
			return macroFail
		end

		-- Prepare
		vmSetZoneInfo()
		local inTravelForm, spellId = false, false
		local macroPre, macroPost, macroText = "", "", ""
		local macroCond, macroExit = mountCond, mountDismount
		local canRide, inVashjir = vmCanRide(), vmVashjir()
		local canFly = canRide and vmCanFly() or false
		local inCombat = UnitAffectingCombat("player")
		local canMount = SecureCmdOptionParse(mountCond) or false

		-- Druid & Travel Form
		-- 5487 = Bear, 768 = Cat, 783 = Travel, 24858 = Moonkin, 114282 = Tree, 210053 = Stag
		if playerClass == "DRUID" and IsPlayerSpell(spellMap.TravelForm.id) and not inVashjir then
			for i = 1, GetNumShapeshiftForms() do
				local _, fActive, _, fSpellId = GetShapeshiftFormInfo(i)
				-- Special Conditions for Travel Form
				if fSpellId == spellMap.TravelForm.id and fActive then
					canMount = false
					inTravelForm = true
					macroExit = "/cancelform [form]\n"
					-- DruidMoonkinForm: Shift back into Moonkin from Travel Form
					if ValorMountLocal.DruidMoonkin and wasMoonkin then
						macroPost = format("/cast [noform] %s\n", spellMap.MoonkinForm.name)
					end
				-- In Moonkin
				elseif fSpellId == spellMap.MoonkinForm.id then
					wasMoonkin = fActive
				end
			end
			-- Druid Travel Form: If in Combat, Moving, Falling or DruidFormAlways is enabled
			if not inTravelForm and not IsMounted()
			   and ((ValorMountLocal.DruidFormAlways and canFly and IsPlayerSpell(spellMap.FlightForm.id))
			   or (IsOutdoors() and (inCombat or IsPlayerMoving() or (canFly and IsFalling())))) then
				macroCond = "[outdoors,nomounted,novehicleui]"
				spellId = spellMap.TravelForm.id
			end
		end

		-- ShamanGhostWolf
		if playerClass == "SHAMAN" and ValorMountLocal.ShamanGhostWolf and IsPlayerSpell(spellMap.GhostWolf.id) then
			-- Cancel Ghost Wolf
			for i = 1, 40 do
				local _, _, _, _, _, _, _, _, _, auraId = UnitAura("player", i, "HELPFUL|PLAYER")
				if not auraId then break
				elseif auraId == spellMap.GhostWolf.id then
					canMount = false
					inTravelForm = true
					macroExit = "/cancelform [form]\n"
					break
				end
			end
			-- Cast Ghost Wolf
			if not IsSubmerged() and not IsMounted() and not inTravelForm and (not canMount or inCombat or IsPlayerMoving()) then
				macroCond = "[nomounted,novehicleui]"
				spellId = spellMap.GhostWolf.id
			end
		end

		-- MonkZenFlight
		if playerClass == "MONK" and ValorMountLocal.MonkZenFlight and IsPlayerSpell(spellMap.ZenFlight.id) and canFly and IsOutdoors() and not IsSubmerged() then
			if not canMount or IsPlayerMoving() or IsFalling() then
				spellId = spellMap.ZenFlight.id
			end
		end

		-- WorgenHuman: Worgen Two Forms before Mounting
		if playerRace == "Worgen" and ValorMountLocal.WorgenHuman and _G.ValorAddons.ValorWorgen and _G.ValorWorgenForm
		   and canMount and spellId ~= spellMap.RunningWild.id and spellId ~= spellMap.TravelForm.id then
			macroPre = format("/cast [nocombat,nomounted,novehicleui,noform] %s\n", spellMap.TwoForms.name)
		end

		-- Select a Mount from Favorites
		if not spellId and canMount and not IsPlayerMoving() and not IsFalling() and not inCombat and not inTravelForm then
			spellId = vmGetMount(canRide, canFly)
			-- Could not find a favorite
			if not spellId then
				macroText = macroFail
			end
		end

		-- Prepare Macro
		if spellId then
			macroText = format("/use %s %s%s\n", macroCond, GetSpellInfo(spellId), (spellId == spellMap.TravelForm.id and "(Shapeshift)" or ""))
		end

		-- Return Macro
		return macroPre .. macroText .. macroExit .. macroPost
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
	local UIDropDownMenu_SetSelectedValue, UIDropDownMenu_SetText, UIDropDownMenu_SetWidth
		= _G.UIDropDownMenu_SetSelectedValue, _G.UIDropDownMenu_SetText, _G.UIDropDownMenu_SetWidth
	local soundOn, soundOff
		= _G.SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, _G.SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
	local dropChoices = {
		mount = { "Flying Only", "Both", "Ground Only" },
		zone  = { "Default", "Flying Area", "Ground Only" },
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
	end

	local function checkboxOnShow (self)
		self:SetChecked(self:GetValue())
	end

	local function checkboxOnClick (self)
		_G.PlaySound(self:GetChecked() and soundOn or soundOff)
		self:SetValue(self:GetChecked())
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
		f.chkLocalEnabled = f.chkLocalEnabled or newCheckbox(mainFrame, "Local", "", "Enabled", vmInfo.Enabled.name, vmInfo.Enabled.desc)
		f.chkLocalEnabled:SetPoint("TOPLEFT", 24, mainFrame.fromTop)
		mainFrame.fromTop = mainFrame.fromTop - f.chkLocalEnabled:GetHeight()

		-- Sort & Validate Dynamic Preferences
		wipe(tempOne)
		for k in pairs(vmInfo) do
			if k ~= "Enabled" and (not vmInfo[k].race or vmInfo[k].race == playerRace) and (not vmInfo[k].class or vmInfo[k].class == playerClass) then
				tinsert(tempOne, k)
			end
		end

		-- Show Valid Dynamic Preferences
		if (#tempOne > 0) then
			sort(tempOne)
			for kId = 1, #tempOne do
				local k = tempOne[kId]
				local chkId = "Chk"..k
				if not f[chkId] then
					local tempDesc = vmInfo[k].desc
					if vmInfo[k].addon and not _G.ValorAddons[vmInfo[k].addon] then
						tempDesc = tempDesc .. "\n\n|cFFff728aRequires Addon:|r "..vmInfo[k].addon
					end
					f[chkId] = newCheckbox(mainFrame,"Local","",k,vmInfo[k].name,tempDesc)
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
		f.chkGlobalFavorites = f.chkGlobalFavorites or newCheckbox(mainFrame, "Global", "", "localFavs", "Character-Specific Favorites")
		f.chkGlobalFavorites:SetPoint("TOPLEFT", 24, mainFrame.fromTop)
		mainFrame.fromTop = mainFrame.fromTop - f.chkGlobalFavorites:GetHeight()


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
		f.titleHeaderFlyingInfo2.updateInfoText = function()
			local zoneInfo = vmMain.zoneInfo
			f.titleHeaderFlyingInfo2:SetText(format(
			"InstanceId:|cFFF58CBA %d (%s)|r MapId:|cFF00FF96 %d (%s)|r%s|r",
			zoneInfo.instanceId, zoneInfo.instanceName, zoneInfo.mapId, zoneInfo.mapName,
			zoneInfo.areaText == "" and "" or " Area:|cFF69CCF0 "..zoneInfo.areaText.."|r"))
		end
		mainFrame.fromTop = mainFrame.fromTop - (f.titleHeaderFlyingInfo2:GetHeight() + 8)

		-- Flyable Area Override Dropdown
		f.dropDownFlying = f.dropDownFlying or CreateFrame("Frame", nil, mainFrame, "UIDropDownMenuTemplate")
		f.dropDownFlying.updateDropDown = function ()
			local selectThis = vmMain.zoneInfo.zoneSoft or 1
			UIDropDownMenu_SetSelectedValue(f.dropDownFlying, selectThis)
			UIDropDownMenu_SetText(f.dropDownFlying, dropChoices.zone[selectThis])
		end
		f.dropDownFlying.initialize = function()
			for i = 1, #dropChoices.zone do
				local row = UIDropDownMenu_CreateInfo()
				row.text = dropChoices.zone[i]
				row.value = i
				row.func = function (self) vmSetZoneInfo(self.value) end
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
		-- Prepare
		local mainFrame = parentFrame.contentFrame
		local f = mainFrame.vmFrames
		local mF = mainFrame.vmMounts
		local mountDb = ValorMountLocal.mountDb

		-- Create the Static Part of the Panel
		if not parentFrame.contentFrame.fromTop then
			createMainOptions(parentFrame.contentFrame)
		end

		-- Zone Override
		vmSetZoneInfo()
		f.dropDownFlying.updateDropDown()
		f.titleHeaderFlyingInfo2.updateInfoText()

		-- Hide All Created Mount Dropdowns
		f.titleHeaderMountsInfo1:Hide()
		f.titleHeaderMountsInfo2:Hide()
		for k in pairs(mF) do
			mF[k]:Hide()
		end

		-- Loop Database
		local fromTopPos = mainFrame.fromTop
		if #mountDb > 0 then
			f.titleHeaderMountsInfo1:Show()
			for i = 1, #mountDb do
				local mountId, mountName, mountType = unpack(mountDb[i])
				if mountType == 247 or mountType == 248 then
					if not mF[mountId] then
						mF[mountId] = CreateFrame("Frame", nil, mainFrame, "UIDropDownMenuTemplate")
						mF[mountId].initialize = function()
							for n = 1, #dropChoices.mount do
								local row = UIDropDownMenu_CreateInfo()
								row.text = dropChoices.mount[n]
								row.value = n
								row.func = function(self)
									ValorMountGlobal.groundFly[mountId] = self.value > 1 and self.value or nil
									dropDownSelect(mF[mountId], "mount", self.value)
								end
								UIDropDownMenu_AddButton(row)
							end
						end
						UIDropDownMenu_SetWidth(mF[mountId], 100)
						UIDropDownMenu_SetButtonWidth(mF[mountId], 100)
						UIDropDownMenu_Initialize(mF[mountId], mF[mountId].initialize)
						dropDownSelect(mF[mountId], "mount", ValorMountGlobal.groundFly[mountId] or 1)
						mF[mountId.."Label"] = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
						mF[mountId.."Label"]:SetText(mountName)
					end
					mF[mountId]:SetPoint("TOPLEFT", 12, fromTopPos)
					mF[mountId]:Show()
					mF[mountId.."Label"]:SetPoint("TOPLEFT", 153, fromTopPos+2)
					mF[mountId.."Label"]:SetHeight(mF[mountId]:GetHeight())
					mF[mountId.."Label"]:Show()
					fromTopPos = fromTopPos - mF[mountId]:GetHeight()
				end
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
vmMain:SetAttribute("type", "macro")
vmMain:RegisterEvent("PLAYER_LOGIN")
vmMain:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		self.zoneChanged = true
		if not _G.MountJournalSummonRandomFavoriteButton then _G.CollectionsJournal_LoadUI() end

		-- Load Config Defaults if Necessary
		if not ValorMountGlobal or not ValorMountGlobal.version or ValorMountGlobal.version < vmVersion or
		   not ValorMountLocal or not ValorMountLocal.version or ValorMountLocal.version < vmVersion then
			vmSetDefaults()
		end

		-- Set Local Favorites, DB Already Built or New Character
		if ValorMountGlobal.localFavs then
			ValorMountLocal.mountDb = ValorMountLocal.mountDb or {}
			vmLocalFavs()
		-- Refresh the DB
		else
			vmBuildDb(true)
		end

		-- Hook SetIsFavorite to keep track
		_G.hooksecurefunc(_G.C_MountJournal, "SetIsFavorite", function()
			for i = 1, GetNumDisplayedMounts() do
				local mountName, spellId, _, _, _, _, isFavorite, _, _, hideOnChar, isCollected, mountId = GetDisplayedMountInfo(i)
				isFavorite = (isCollected and not hideOnChar) and isFavorite or false
				if isCollected and not hideOnChar then
					if isFavorite then
						local _, _, _, _, mountType = GetMountInfoExtraByID(mountId)
						vmMountDb(isFavorite, mountId, mountName, mountType, spellId)
					else
						vmMountDb(isFavorite, mountId)
					end
				end
			end
		end)

		-- Register for Events
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:RegisterEvent("PLAYER_REGEN_DISABLED")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		self:RegisterEvent("PLAYER_LEVEL_UP")
		self:RegisterEvent("UPDATE_BINDINGS")
		self:RegisterEvent("ZONE_CHANGED")
		self:RegisterEvent("ZONE_CHANGED_INDOORS")
		self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
		self:SetScript("PreClick", vmSetMacro)
		vmBindings(self)

	elseif event == "PLAYER_LEVEL_UP" then
		playerLevel = playerLevel + 1

	-- Manage Bindings
	elseif event == "UPDATE_BINDINGS" then
		vmBindings(self)

	-- Wandered into a new zone
	elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
		self.zoneChanged = true

	-- Update the Macro
	else
		vmSetMacro(self)
	end
end)

-- Setup the Options Frame
-------------------------------------------------
vmPrefs.scrollFrame = CreateFrame("ScrollFrame", "ValorMountScroll", vmPrefs, "UIPanelScrollFrameTemplate")
vmPrefs.scrollChild = CreateFrame("Frame", nil, vmPrefs.scrollFrame)
vmPrefs.scrollUpButton = _G["ValorMountScrollScrollBarScrollUpButton"]
vmPrefs.scrollUpButton:ClearAllPoints()
vmPrefs.scrollUpButton:SetPoint("TOPRIGHT", vmPrefs.scrollFrame, "TOPRIGHT", -8, 6)
vmPrefs.scrollDownButton = _G["ValorMountScrollScrollBarScrollDownButton"]
vmPrefs.scrollDownButton:ClearAllPoints()
vmPrefs.scrollDownButton:SetPoint("BOTTOMRIGHT", vmPrefs.scrollFrame, "BOTTOMRIGHT", -8, -6)
vmPrefs.scrollBar = _G["ValorMountScrollScrollBar"]
vmPrefs.scrollBar:ClearAllPoints()
vmPrefs.scrollBar:SetPoint("TOP", vmPrefs.scrollUpButton, "BOTTOM", 0, 0)
vmPrefs.scrollBar:SetPoint("BOTTOM", vmPrefs.scrollDownButton, "TOP", 0, 0)
vmPrefs.scrollFrame:SetScrollChild(vmPrefs.scrollChild)
vmPrefs.scrollFrame:SetPoint("TOPLEFT", vmPrefs, "TOPLEFT", 0, -16)
vmPrefs.scrollFrame:SetPoint("BOTTOMRIGHT", vmPrefs, "BOTTOMRIGHT", 0, 16)
vmPrefs.scrollChild:SetSize(600, 1)
vmPrefs.contentFrame = CreateFrame("Frame", nil, vmPrefs.scrollChild)
vmPrefs.contentFrame:SetAllPoints(vmPrefs.scrollChild)
vmPrefs.contentFrame.vmFrames = {}
vmPrefs.contentFrame.vmMounts = {}
vmPrefs.refresh = function (self)
	createMountOptions(self)
	self:SetScript("OnShow", createMountOptions)
	self.refresh = function () return end
end
vmPrefs.name = "ValorMount"
_G.InterfaceOptions_AddCategory(vmPrefs)

-- Slash Commands and Key Bindings
-------------------------------------------------
_G["BINDING_NAME_VALORMOUNTBINDING1"] = "Mount/Dismount"
_G["BINDING_HEADER_VALORMOUNT"] = "ValorMount"
_G.SLASH_VALORMOUNT1 = "/valormount"
_G.SLASH_VALORMOUNT2 = "/vm"
_G.SlashCmdList.VALORMOUNT = function()
	if not vmPrefs.contentFrame.fromTop then
		_G.InterfaceOptionsFrame_OpenToCategory(vmPrefs)
	end
	_G.InterfaceOptionsFrame_OpenToCategory(vmPrefs)
end