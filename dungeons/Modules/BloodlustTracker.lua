local FTD = FTD
local ipairs = ipairs

-- The shared "can't be re-lusted" debuff — one entry per class-side effect,
-- not one per spell/item that can grant it (Bloodlust, Heroism, Time Warp,
-- a Hunter pet, Drums of Rage, etc. all land one of *these* on the player).
-- Verify against a fresh in-game cast if a source doesn't register; these are
-- long-standing IDs but should be confirmed for the current game version.
local LUST_DEBUFF_IDS = {
  57723,  -- Exhaustion (Bloodlust)
  57724,  -- Sated (Heroism)
  80354,  -- Temporal Displacement (Time Warp)
  95809,  -- Insanity (Ancient Hysteria)
  390435, -- Fatigued (Fury of the Aspects)
}

-- The shared debuff's duration is fixed at 10 minutes regardless of source/
-- talents/haste — used as a fallback when its real expirationTime can't be
-- trusted (see scanActiveDebuff).
local LUST_DURATION = 600

-- Midnight's restricted-content "secret values" system (the same mechanism
-- that broke combat-log access) can also apply to aura fields: a debuff not
-- on Blizzard's small non-secret whitelist can come back from
-- GetPlayerAuraBySpellID with a present-but-unreadable expirationTime inside
-- a Mythic+ instance — exactly where this addon runs. These lust debuffs
-- aren't on that whitelist. issecretvalue (added alongside the same system)
-- is how a proven-working Midnight addon (EllesmereUIAuraBuffReminders)
-- detects this rather than letting arithmetic on the value error out.
local isSecret = issecretvalue or function() return false end

---Scans the player's own auras for the shared debuff, pcall-guarded since
---the restricted-content aura API can hard-error rather than just returning
---secret values. Returns its expiration time (per `GetTime()`) and spellId,
---or nil if not currently active. If the real expirationTime isn't safely
---readable, the aura's mere presence still is, so a synthetic expiration
---(now + the debuff's fixed duration) is returned instead of losing the
---detection entirely.
local function scanActiveDebuff()
  if not C_UnitAuras or not C_UnitAuras.GetPlayerAuraBySpellID then return nil end
  for _, spellId in ipairs(LUST_DEBUFF_IDS) do
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellId)
    if ok and aura then
      local expirationTime = aura.expirationTime
      if expirationTime == nil or isSecret(expirationTime) then
        expirationTime = (GetTime and GetTime() or 0) + LUST_DURATION
      end
      return expirationTime, spellId
    end
  end
  return nil
end

---Pure: true only on the transition from "not active" to "active" this poll.
local function detectRisingEdge(wasActive, expirationTime)
  return (expirationTime ~= nil) and not wasActive
end

local wasActive = false
local record = nil -- { pullAtCast = number|nil, availableAt = number }

local function reset()
  wasActive = false
  record = nil
end

---Call on a timer (e.g. the existing 1s ticker). `currentPull` is whichever
---pull ForcesTracker currently considers "current" at the moment lust lands.
local function poll(currentPull)
  local expirationTime = scanActiveDebuff()
  if detectRisingEdge(wasActive, expirationTime) then
    record = { pullAtCast = currentPull, availableAt = expirationTime }
  end
  wasActive = expirationTime ~= nil
  return record
end

local function getRecord() return record end

-- =====================================================================
-- Planned bloodlust pulls -- which pull(s) *this saved route* should pop
-- lust on, set by hand on the map (distinct from `record` above, which is
-- runtime detection of where lust actually got cast this run). A route can
-- call for more than one lust (e.g. a long dungeon or a heavy trash pull
-- plus a boss), so this is a set of pull indexes, not a single one.
-- =====================================================================

local function getDB() return FTD:GetDB() end

---Stable key for "this saved route": dungeon + the preset's own index in
---MDT's per-dungeon preset table (the index RenderContext.gather resolves
---and hands back as `presetIndex`). preset.uid exists but MDT itself doesn't
---keep it reliably present (cleared on duplicate/import in MDT's own
---Presets.lua), so it isn't a safe identity to persist against.
local function routeKey(dungeonIndex, presetIndex)
  if not dungeonIndex or not presetIndex then return nil end
  return dungeonIndex..":"..presetIndex
end

---The set of pulls (pullIndex -> true) this route is marked to lust on.
---Always returns a table (empty if none), so callers can index it directly.
local function getPlannedPulls(dungeonIndex, presetIndex)
  local db = getDB()
  local key = routeKey(dungeonIndex, presetIndex)
  return (db and db.plannedLustPulls and key and db.plannedLustPulls[key]) or {}
end

local function isPullPlanned(dungeonIndex, presetIndex, pullIndex)
  return getPlannedPulls(dungeonIndex, presetIndex)[pullIndex] == true
end

---Flips whether `pullIndex` is marked, for this route only.
local function togglePlannedPull(dungeonIndex, presetIndex, pullIndex)
  local db = getDB()
  local key = routeKey(dungeonIndex, presetIndex)
  if not db or not key then return end
  db.plannedLustPulls = db.plannedLustPulls or {}
  local set = db.plannedLustPulls[key]
  if not set then
    set = {}
    db.plannedLustPulls[key] = set
  end
  set[pullIndex] = (not set[pullIndex]) or nil
end

FTD.BloodlustTracker = {
  LUST_DEBUFF_IDS = LUST_DEBUFF_IDS,
  scanActiveDebuff = scanActiveDebuff,
  detectRisingEdge = detectRisingEdge,
  reset = reset,
  poll = poll,
  getRecord = getRecord,
  getPlannedPulls = getPlannedPulls,
  isPullPlanned = isPullPlanned,
  togglePlannedPull = togglePlannedPull,
}
