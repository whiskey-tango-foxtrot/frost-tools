-- Minimal stubs for the slice of the WoW runtime + parent-MDT surface that the
-- pure-Lua modules (RouteIndex, ForcesTracker, BloodlustTracker, DeviationWarning,
-- FloorSelector, PullMarkers' pure bits) actually touch. Extend as more modules
-- come under test. Modeled on MythicDungeonTools_NextPullTracker/spec/helpers.

local M = {}

---Faithful-enough pure-Lua re-implementation of WoW's `strsplit(sep, str)` for
---a single-character separator (all this addon ever uses it for: GUID parsing).
local function strsplit(sep, str)
  if not str then return end
  local parts = {}
  for part in (str..sep):gmatch("(.-)"..sep) do
    parts[#parts + 1] = part
  end
  return unpack(parts)
end

local function installGlobals()
  _G.GetTime = function() return 0 end
  _G.strsplit = strsplit
  _G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
  _G.CreateFrame = nil -- pure-logic specs never touch the UI layer
  _G.CombatLogGetCurrentEventInfo = nil
  _G.C_UnitAuras = nil

  _G.FTD = {
    L = setmetatable({}, { __index = function(_, k) return k end }),
    PullState = {
      COMPLETED = "completed",
      ACTIVE    = "active",
      NEXT      = "next",
      UPCOMING  = "upcoming",
    },
    Utils = {
      parseNum = function(value)
        if type(value) == "number" then return value end
        if type(value) == "string" then return tonumber(value:match("(%d+%.?%d*)")) or 0 end
        return 0
      end,
    },
    -- ForcesTracker reads scenario data through FTD.Wow; tests set
    -- _G.FTD.Wow.getScenarioStepInfo/getScenarioCriteriaInfo directly rather
    -- than simulating real C_ScenarioInfo, since only the shape matters.
    Wow = {
      getScenarioStepInfo = function() return 0 end,
      getScenarioCriteriaInfo = function() return nil end,
    },
  }
  function _G.FTD:GetDB() return {} end
end

---Builds a realistic "Creature-..." GUID embedding `npcID`, matching the
---format WoW actually uses (Creature-0-serverID-instanceID-zoneUID-npcID-spawnUID).
function M.makeCreatureGUID(npcID, spawnSuffix)
  return string.format("Creature-0-3661-2222-12345-%d-%s", npcID, spawnSuffix or "000042C3C7")
end

---Fresh mock state. Call in `before_each` so every test starts from a known baseline.
function M.reset()
  installGlobals()
end

---Executes a source file (repo-relative path) in the current globals.
---Re-executing is cheap and gives tests a fresh FTD.<Module> each call.
function M.loadSource(relPath)
  local chunk, err = loadfile(relPath)
  assert(chunk, err)
  return chunk()
end

return M
