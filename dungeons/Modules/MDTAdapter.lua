local _, FTD = ...

-- MDT 6.2 (WoW 12.1) intentionally removed the legacy `_G.MDT` table. Its
-- public API exposes the saved-variable database, but not the selected preset
-- or the enemy/clone data this addon needs. The TOC therefore loads MDT's
-- static Midnight dungeon files into this addon's own private table (`...`
-- inside those files resolves to *this* addon's vararg, not MDT's) — so
-- `Adapter` must be `FTD` itself, not a sub-table, for the Midnight files'
-- `MDT.dungeonList[...] = ...` writes to land somewhere this addon can read.
-- (Same technique as MythicDungeonTools_NextPullTracker's MDTAdapter.lua.)
local Adapter = FTD
local PublicAPI = _G.MythicDungeonToolsAPI
local UI_ADDON_NAME = "MythicDungeonTools_UI"

-- Every Midnight dungeon file builds its texture path as
-- 'Interface\AddOns\'..MDT.AddonName..'\Midnight\Textures\<Dungeon>' — since
-- those files execute inside *this* addon's namespace, MDT.AddonName must be
-- set here to the real MythicDungeonTools folder name, or every one of those
-- concatenations throws (and, critically, aborts that dungeon's whole
-- `dungeonMaps[...] = {...}` assignment, leaving the map texture data unset).
Adapter.AddonName = "MythicDungeonTools"

Adapter.dungeonEnemies = Adapter.dungeonEnemies or {}
Adapter.dungeonList = Adapter.dungeonList or {}
Adapter.dungeonMaps = Adapter.dungeonMaps or {}
Adapter.dungeonSubLevels = Adapter.dungeonSubLevels or {}
Adapter.dungeonTotalCount = Adapter.dungeonTotalCount or {}
Adapter.mapInfo = Adapter.mapInfo or {}
Adapter.mapPOIs = Adapter.mapPOIs or {}
Adapter.zoneIdToDungeonIdx = Adapter.zoneIdToDungeonIdx or {}
-- Not written by the current Midnight files, but part of the dungeon-data
-- field set MDT's own UI bootstrap expects (MythicDungeonTools_UI/Bootstrap.lua,
-- `dungeonDataFields`), and older-expansion files did assign into it -- so
-- keep the slot so a future data file can't error out on a nil table.
Adapter.scaleMultiplier = Adapter.scaleMultiplier or {}

-- MDT dungeon files look localized names up through MDT.L (== FTD.L, already
-- created by init.lua). This addon doesn't ship its own translations for
-- MDT-owned strings (dungeon names, etc.), so fall back to echoing the key —
-- without this, e.g. `L["AltarOfFangs"]` would resolve to nil and blank out
-- the dungeon list. Preserves this addon's own translations either way.
local localeMeta = getmetatable(Adapter.L) or {}
if localeMeta.__index == nil then
  localeMeta.__index = function(_, key) return key end
  setmetatable(Adapter.L, localeMeta)
end

function Adapter:GetDB()
  local saved = _G.MythicDungeonToolsDB
  if saved and type(saved.global) == "table" then
    return saved.global
  end
  if PublicAPI and PublicAPI.GetDB then
    return PublicAPI:GetDB()
  end
  return nil
end

local function tableValue(tbl, key)
  if type(tbl) ~= "table" or key == nil then return nil end
  return tbl[key] or tbl[tostring(key)] or (tonumber(key) and tbl[tonumber(key)])
end

local function isUsablePreset(preset)
  return type(preset) == "table" and type(preset.value) == "table" and
    type(preset.value.pulls) == "table" and #preset.value.pulls > 0
end

---Returns the resolved preset plus the index it actually lives at in
---`db.presets[dungeonIndex]` -- callers that only had a display-facing preset
---table before (e.g. to key per-route saved data) can now do so without
---re-deriving the index themselves.
local function resolvePreset(db, dungeonIndex, presetIndexOverride)
  if type(db) ~= "table" then return nil end
  dungeonIndex = dungeonIndex or db.currentDungeonIdx
  local dungeonPresets = tableValue(db.presets, dungeonIndex)
  local presetIndex = presetIndexOverride or tableValue(db.currentPreset, dungeonIndex)
  local selected = tableValue(dungeonPresets, presetIndex)
  if isUsablePreset(selected) then return selected, presetIndex end

  if type(dungeonPresets) == "table" then
    for idx, preset in pairs(dungeonPresets) do
      if isUsablePreset(preset) then return preset, idx end
    end
  end
  return nil
end

local function isUIAddonLoaded()
  if not C_AddOns or not C_AddOns.IsAddOnLoaded then return true end
  local loadedOrLoading, loaded = C_AddOns.IsAddOnLoaded(UI_ADDON_NAME)
  return loaded == nil and loadedOrLoading or loaded
end

---MDT 6.2 keeps presets in its load-on-demand UI addon. Loading it directly
---initializes the route database without opening MDT's window.
function Adapter:EnsureUIReady()
  if isUIAddonLoaded() then return true end
  if not C_AddOns or not C_AddOns.LoadAddOn then return false, "API unavailable" end

  local loaded, reason = C_AddOns.LoadAddOn(UI_ADDON_NAME)
  if loaded or isUIAddonLoaded() then return true end
  return false, reason or "unknown error"
end

---@return table|nil preset, number|nil presetIndex
function Adapter:GetCurrentPreset(dungeonIndex, presetIndexOverride)
  local ready = self:EnsureUIReady()
  if not ready then return nil end

  local saved = _G.MythicDungeonToolsDB
  local savedDB = saved and saved.global
  local preset, presetIndex = resolvePreset(savedDB, dungeonIndex, presetIndexOverride)
  if preset then return preset, presetIndex end

  local apiDB = PublicAPI and PublicAPI.GetDB and PublicAPI:GetDB() or nil
  if apiDB ~= savedDB then return resolvePreset(apiDB, dungeonIndex, presetIndexOverride) end
  return nil
end

---Lists the saved presets for a dungeon as {index=..., name=...} entries, in
---MDT's own index order, for the route dropdown.
function Adapter:ListPresets(dungeonIndex)
  local db = self:GetDB()
  local dungeonPresets = db and tableValue(db.presets, dungeonIndex)
  local list = {}
  if type(dungeonPresets) ~= "table" then return list end
  for index, preset in pairs(dungeonPresets) do
    if isUsablePreset(preset) then
      list[#list + 1] = { index = index, name = preset.text or ("Route "..tostring(index)) }
    end
  end
  table.sort(list, function(a, b) return tostring(a.index) < tostring(b.index) end)
  return list
end

-- Midnight season lineups, newest first, each in MDT's own display order.
-- Mirrors MythicDungeonTools's MDT.dungeonSelectionToIndex
-- (Modules/DungeonSelect.lua) -- that table lives in MDT's private per-addon
-- namespace (local `_, MDT = ...`), not the shared Adapter table this file
-- writes into, so it isn't reachable from here and this addon keeps its own
-- copy. Order matters: besides driving the dungeon picker, it is the ranking
-- MDT uses when several dungeons register the same zone (see
-- RegisterDungeonLocation below). Update when a new season ships.
local DUNGEON_SEASONS = {
  -- Season 2: Murder Row, Den of Nalorakk, The Blinding Vale, Voidscar Arena,
  -- Altar of Fangs, Ruby Life Pools, Temple of Sethraliss, King's Rest
  { 160, 161, 162, 163, 164, 42, 20, 17 },
  -- Season 1: Algeth'ar Academy, Seat of the Triumvirate, Pit of Saron,
  -- Skyreach, Windrunner Spire, Magisters' Terrace, Maisara Caverns,
  -- Nexus-Point Xenas
  { 45, 11, 150, 151, 152, 153, 154, 155 },
}

local CURRENT_SEASON_DUNGEON_INDEXES = {}
for _, dungeonIdx in ipairs(DUNGEON_SEASONS[1]) do CURRENT_SEASON_DUNGEON_INDEXES[dungeonIdx] = true end

---Lists the current season's dungeons (past seasons hidden by request) as
---{index=, name=} entries for the dungeon-picker menu.
function Adapter:ListDungeons()
  local list = {}
  for index, name in pairs(self.dungeonList) do
    if CURRENT_SEASON_DUNGEON_INDEXES[index] then
      list[#list + 1] = { index = index, name = name }
    end
  end
  table.sort(list, function(a, b) return tostring(a.name) < tostring(b.name) end)
  return list
end

-- =====================================================================
-- Dungeon location registration (MDT 6.2.17+, September 2026)
-- =====================================================================
-- MDT 6.2.17 ("Fix dungeon selection in shared zones") replaced the dungeon
-- files' direct `MDT.zoneIdToDungeonIdx[zone] = idx` loop with a call to
-- `MDT:RegisterDungeonLocation(idx, { zoneIds = {...}, subzoneAreaIDs = {...} })`
-- (implemented in MDT's Modules/MapView.lua). Those files execute inside
-- *this* addon's namespace, so the method has to exist on this table: without
-- it every one of the 16 Midnight files throws on that line -- which comes
-- *before* its dungeonMaps/dungeonSubLevels/dungeonTotalCount/mapPOIs/
-- dungeonEnemies assignments -- leaving this addon with 16 load errors and no
-- enemy or map data at all.
--
-- Semantics mirror MDT's: a zone several dungeons share resolves to whichever
-- dungeon ranks first in the season lists (newest season first, then MDT's
-- display order within it -- DUNGEON_SEASONS above), and a dungeon's entrance
-- subzone (`subzoneAreaIDs`) can override that when the player is standing in
-- it.

---@type table<number, { dungeonIdx: number, subzoneAreaIDs: number[]|nil }[]>
local dungeonLocationsByZone = {}

---@return number seasonRank, number orderInSeason (both math.huge when unlisted)
local function dungeonPriority(dungeonIdx)
  for seasonRank, season in ipairs(DUNGEON_SEASONS) do
    for order, idx in ipairs(season) do
      if idx == dungeonIdx then return seasonRank, order end
    end
  end
  return math.huge, math.huge
end

local function hasHigherPriority(candidateIdx, currentIdx)
  local candidateSeason, candidateOrder = dungeonPriority(candidateIdx)
  local currentSeason, currentOrder = dungeonPriority(currentIdx)
  return candidateSeason < currentSeason or (candidateSeason == currentSeason and candidateOrder < currentOrder)
end

---Called by each MDT Midnight dungeon file as it loads.
---@param dungeonIdx number
---@param location { zoneIds: number[], subzoneAreaIDs: number[]|nil }
function Adapter:RegisterDungeonLocation(dungeonIdx, location)
  if type(location) ~= "table" then return end
  local registered = { dungeonIdx = dungeonIdx, subzoneAreaIDs = location.subzoneAreaIDs }
  for _, zoneId in ipairs(location.zoneIds or {}) do
    dungeonLocationsByZone[zoneId] = dungeonLocationsByZone[zoneId] or {}
    table.insert(dungeonLocationsByZone[zoneId], registered)
    local currentIdx = self.zoneIdToDungeonIdx[zoneId]
    if currentIdx == nil or hasHigherPriority(dungeonIdx, currentIdx) then
      self.zoneIdToDungeonIdx[zoneId] = dungeonIdx
    end
  end
end

---Resolves a UiMapID (plus, optionally, the player's current subzone text) to
---a dungeon index, preferring a dungeon whose registered entrance subzone the
---player is standing in, then the zone's priority dungeon.
---@param zoneId number|nil C_Map.GetBestMapForUnit("player")
---@param subzoneText string|nil GetSubZoneText()
---@return number|nil dungeonIdx
---@return boolean isSubzoneMatch
function Adapter:GetDungeonIdxForZone(zoneId, subzoneText)
  if zoneId == nil then return nil, false end
  local locations = dungeonLocationsByZone[zoneId]
  if locations and subzoneText and subzoneText ~= "" and C_Map and C_Map.GetAreaInfo then
    for _, location in ipairs(locations) do
      for _, areaID in ipairs(location.subzoneAreaIDs or {}) do
        if subzoneText == C_Map.GetAreaInfo(areaID) then return location.dungeonIdx, true end
      end
    end
  end
  return self.zoneIdToDungeonIdx[zoneId], false
end

---Same lookup for wherever the player is right now.
---@return number|nil dungeonIdx
---@return number|nil zoneId
---@return boolean|nil isSubzoneMatch
function Adapter:GetDungeonIdxForCurrentLocation()
  if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
  local zoneId = C_Map.GetBestMapForUnit("player")
  if not zoneId then return nil end
  local subzoneText = GetSubZoneText and GetSubZoneText() or nil
  local dungeonIdx, isSubzoneMatch = self:GetDungeonIdxForZone(zoneId, subzoneText)
  return dungeonIdx, zoneId, isSubzoneMatch
end

function Adapter:GetPresetDiagnostics()
  local db = self:GetDB()
  local dungeonIndex = db and db.currentDungeonIdx
  local presetIndex = db and tableValue(db.currentPreset, dungeonIndex)
  local dungeonPresets = db and tableValue(db.presets, dungeonIndex)
  local presetCount = 0
  if type(dungeonPresets) == "table" then
    for _ in pairs(dungeonPresets) do presetCount = presetCount + 1 end
  end
  return "dungeon="..tostring(dungeonIndex)..
    ", selection="..tostring(presetIndex)..
    ", presets="..tostring(type(db and db.presets) == "table")..
    ", dungeonPresets="..tostring(presetCount)..
    ", uiLoaded="..tostring(isUIAddonLoaded())
end

FTD.MDT = Adapter
