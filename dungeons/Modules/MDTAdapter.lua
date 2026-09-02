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

-- Midnight Season 2 lineup. Mirrors the season-2 entry of MythicDungeonTools's
-- own MDT.dungeonSelectionToIndex (Modules/DungeonSelect.lua) -- that table
-- lives in MDT's private per-addon namespace (local `_, MDT = ...`), not the
-- shared Adapter table this file writes into, so it isn't reachable from here
-- and this addon keeps its own copy. Update this list when a new season ships.
local SEASON_2_DUNGEON_INDEXES = {
  [160] = true, -- Murder Row
  [161] = true, -- Den of Nalorakk
  [162] = true, -- The Blinding Vale
  [163] = true, -- Voidscar Arena
  [164] = true, -- Altar of Fangs
  [42]  = true, -- Ruby Life Pools
  [20]  = true, -- Temple of Sethraliss
  [17]  = true, -- King's Rest
}

---Lists the current season's dungeons (Season 1 hidden by request) as
---{index=, name=} entries for the dungeon-picker menu.
function Adapter:ListDungeons()
  local list = {}
  for index, name in pairs(self.dungeonList) do
    if SEASON_2_DUNGEON_INDEXES[index] then
      list[#list + 1] = { index = index, name = name }
    end
  end
  table.sort(list, function(a, b) return tostring(a.name) < tostring(b.name) end)
  return list
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
