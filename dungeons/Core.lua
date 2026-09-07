local AddonName = ...
local FTD = FTD
local MDT = FTD.MDT
local Mdt = FTD.Mdt
local L = FTD.L

local db
local sessionTicker
local wasChallengeActive = false
local eventFrame = CreateFrame("Frame")

local defaultSavedVars = {
  global = {
    warnEnabled = true,
    warnThresholdPct = FTD.DeviationWarning and FTD.DeviationWarning.DEFAULT_THRESHOLD_PCT or 5.0,
    windowPos = nil,
    windowScale = 1.0,
    windowOpacity = 90,
    layoutMode = "single",
    splitLayout = {},
    minimap = { hide = false },
    autoOpenEnabled = true,
    autoCloseEnabled = true,
    plannedLustPulls = {}, -- [dungeonIndex..":"..presetIndex] = { [pullIndex] = true, ... }
  },
}

function FTD:GetDB() return db end

-- C_Map.GetBestMapForUnit / C_ChallengeMode.GetActiveChallengeMapID can both
-- return nothing for a brief window right after PLAYER_ENTERING_WORLD fires,
-- before the map/instance system has caught up — MythicDungeonTools_NextPullTracker
-- hit the same race and fixed it with a short retry-with-backoff; same fix here.
local detectGeneration = 0

local function dungeonHasRoutes(dungeonIndex)
  if not dungeonIndex then return false end
  return #MDT:ListPresets(dungeonIndex) > 0
end

---Any 5-player dungeon instance, at any difficulty -- not just an active
---Mythic Keystone. Auto show/hide keys off dungeon identity (see
---dungeonHasRoutes below), not the keystone timer, so this is just as happy
---opening for a normal/heroic run or a plain level-up clear as it is for a key.
local function isInDungeonInstance()
  if not IsInInstance then return false end
  local inInstance, instanceType = IsInInstance()
  return inInstance and instanceType == "party"
end

---Auto-selects whatever dungeon MDT/the player is currently in (and, via
---MDT:GetCurrentPreset's own fallback, whatever route MDT currently has
---selected for it), retrying briefly if detection isn't ready yet. Also
---drives auto show/hide: opens the window on joining any dungeon instance
---MDT has routes for (whatever the difficulty), closes it on leaving (or if
---it never had routes) -- gated on the matching db toggle so users can turn
---either direction off in the options menu.
local function autoDetectDungeon(retryCount, generation)
  retryCount = retryCount or 0
  if not generation then
    detectGeneration = detectGeneration + 1
    generation = detectGeneration
  end

  if not isInDungeonInstance() then
    if FTD.LayoutManager and (not db or db.autoCloseEnabled ~= false) then
      FTD.LayoutManager.Hide()
    end
    return
  end

  local dungeonIndex = Mdt.detectCurrentDungeon()
  if dungeonIndex then
    FTD.RenderContext.selectDungeon(dungeonIndex)
    if FTD.LayoutManager then FTD.LayoutManager.Render() end
    if dungeonHasRoutes(dungeonIndex) then
      if FTD.LayoutManager and (not db or db.autoOpenEnabled ~= false) then
        FTD.LayoutManager.Show()
      end
    elseif FTD.LayoutManager and (not db or db.autoCloseEnabled ~= false) then
      FTD.LayoutManager.Hide()
    end
    return
  end

  if retryCount < 10 and C_Timer and C_Timer.After then
    C_Timer.After(0.2, function()
      if generation == detectGeneration then
        autoDetectDungeon(retryCount + 1, generation)
      end
    end)
  end
end

---Ticks every second for the whole session. Forces-delta tracking (see
---ForcesTracker.lua) needs no explicit start/stop — ForcesTracker.poll() is
---a harmless no-op outside an active scenario — so this just re-detects the
---dungeon the moment a key becomes active (PLAYER_ENTERING_WORLD/joining the
---instance already handles auto show/hide; this is a fast-path safety net
---for the case where the challenge starts without a fresh zone transition),
---and otherwise drives the regular render/poll cycle (both layouts' Tick()
---already no-op while hidden, so this is cheap even outside a key).
local function sessionTick()
  local isActive = C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive()

  if isActive and not wasChallengeActive then
    autoDetectDungeon()
  end
  wasChallengeActive = isActive

  if FTD.LayoutManager then FTD.LayoutManager.Tick() end
end

local function startSessionTicker()
  if sessionTicker then return end
  sessionTicker = C_Timer.NewTicker(1.0, sessionTick)
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("CHALLENGE_MODE_START")

eventFrame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    local addon = ...
    if addon == AddonName then
      local childDB = LibStub("AceDB-3.0"):New("FrostToolsDungeonsDB", defaultSavedVars, true)
      db = childDB.global
      if FTD.Minimap then FTD.Minimap.init() end
      startSessionTicker()
      eventFrame:UnregisterEvent("ADDON_LOADED")
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    autoDetectDungeon()
  elseif event == "CHALLENGE_MODE_START" then
    -- Fast-path: react immediately rather than waiting up to 1s for the
    -- ticker to notice. Deferred a frame since this fires inside a moment
    -- tied to Blizzard's secure UI (loading transitions).
    C_Timer.After(0, sessionTick)
  end
end)

SLASH_FROSTTOOLSDUNGEONS1 = "/ftd"
SLASH_FROSTTOOLSDUNGEONS2 = "/fdt"
SlashCmdList["FROSTTOOLSDUNGEONS"] = function(msg)
  msg = strtrim(msg or ""):lower()
  if msg == "reset" then
    autoDetectDungeon()
    if FTD.RenderContext then FTD.RenderContext.resetProgress() end
    if FTD.LayoutManager then FTD.LayoutManager.Render() end
  elseif msg == "settings" then
    if FTD.Settings then FTD.Settings:Open() end
  elseif msg == "debug" then
    print("|cFF4FC3FFFrost Tools: Dungeons|r diagnostics:")
    print("challenge active: "..tostring(C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive()))
    local dungeonIndex = FTD.RenderContext.getSelection()
    print("selected dungeon: "..tostring(dungeonIndex).." ("..tostring(dungeonIndex and MDT.dungeonList[dungeonIndex]).." )")
    local state = FTD.ForcesTracker.getState()
    if not state then
      print("no route indexed yet")
    else
      print("currentPull: "..tostring(state.currentPull)..
        ", actualForces: "..string.format("%.1f", state.actualForces)..
        ", targetForces: "..string.format("%.1f", state.targetForces))
      for i, s in pairs(state.pullStates) do
        print("  pull "..i..": "..s..(state.pullForcesKilled[i] and (" ("..string.format("%.1f", state.pullForcesKilled[i]).." forces)") or ""))
      end
    end
    local routeIndex = FTD.ForcesTracker.getRouteIndex()
    if routeIndex then
      for i = 1, routeIndex.pullCount do
        local pull = routeIndex.pulls[i]
        if pull and pull.hasBoss and pull.bossNames then
          for _, name in ipairs(pull.bossNames) do
            local hasTips = FTD.TacticsData[name] and #FTD.TacticsData[name] > 0
            print("  boss pull "..i..": \""..name.."\" -- tactics data: "..(hasTips and "yes" or "none (add it to TacticsData.lua)"))
          end
        end
      end
    end
    local lustExpiration, lustSpellId = FTD.BloodlustTracker.scanActiveDebuff()
    print("bloodlust debuff active now: "..tostring(lustExpiration ~= nil)..
      (lustSpellId and (" (spellId "..lustSpellId..", expires in "..string.format("%.0f", lustExpiration - GetTime()).."s)") or ""))
    local lustRecord = FTD.BloodlustTracker.getRecord()
    if lustRecord then
      print("bloodlust record: cast on pull "..tostring(lustRecord.pullAtCast)..
        ", available again in "..string.format("%.0f", lustRecord.availableAt - GetTime()).."s")
    else
      print("bloodlust record: none yet")
    end
  else
    if FTD.LayoutManager then FTD.LayoutManager.Toggle() end
  end
end
