local FTD = FTD
local MDT = FTD.MDT

-- Single source of truth for "what dungeon/route/floor are we looking at" and
-- "what does the tracking engine currently say" — shared by both the
-- single-window and split-window layouts, so switching between them doesn't
-- lose your selection, and the forces tracker never gets reset twice for the
-- same route change just because two layouts each noticed it independently.

local selectedDungeonIndex = nil
local lastPreset = nil -- the actual preset table, not its .uid (not reliably stable)

local function selectDungeon(dungeonIndex)
  selectedDungeonIndex = dungeonIndex
end

---Returns the dungeon actually being shown right now — `selectedDungeonIndex`
---when the user (or auto-detect) has explicitly picked one, otherwise the
---same MDT-current-dungeon fallback `gather()` uses. The Dungeon button wants
---*this*, not the raw override: under auto-detect, selectedDungeonIndex can
---stay nil while gather() still resolves and shows a dungeon via the
---fallback, and a button using the raw value would open an empty menu for a
---dungeon that's clearly on screen.
local function getSelection()
  return selectedDungeonIndex or (MDT:GetDB() and MDT:GetDB().currentDungeonIdx)
end

---Resolves the current dungeon/route, (re)indexing the forces tracker if the
---route changed since the last call, polling it once, and assembling
---everything a layout needs to render a frame. Returns nil + a reason string
---("no-dungeon"/"no-route"/"no-enemy-data") when there's nothing to show yet.
---The route itself always follows whatever MDT currently has selected --
---this addon doesn't offer its own route switcher (see DungeonSelector's
---Route menu), just the dungeon and floor.
local function gather(warnThresholdPct)
  local dungeonIndex = selectedDungeonIndex or (MDT:GetDB() and MDT:GetDB().currentDungeonIdx)
  if not dungeonIndex then return nil, "no-dungeon" end

  local preset, presetIndex = MDT:GetCurrentPreset(dungeonIndex)
  if not preset then return nil, "no-route", dungeonIndex end

  local pulls = preset.value.pulls
  local enemies = MDT.dungeonEnemies[dungeonIndex]
  if not enemies then return nil, "no-enemy-data", dungeonIndex end

  local dungeonMax = MDT.dungeonTotalCount[dungeonIndex] and MDT.dungeonTotalCount[dungeonIndex].normal

  if preset ~= lastPreset then
    lastPreset = preset
    local routeIndex = FTD.RouteIndex.build(pulls, enemies)
    FTD.ForcesTracker.reset(routeIndex, dungeonMax)
    FTD.BloodlustTracker.reset()
  end

  FTD.ForcesTracker.poll()

  local routeIndex = FTD.ForcesTracker.getRouteIndex()
  local state = FTD.ForcesTracker.getState()
  local sublevel = FTD.FloorSelector.resolveSublevel(pulls, enemies, state and state.currentPull)

  -- Polled here (not by each layout's own Tick) so it always sees *this*
  -- tick's currentPull rather than whatever ForcesTracker held before this
  -- gather ran — a cast landing the same tick forces advance a pull would
  -- otherwise get attributed to the pull that just finished.
  FTD.BloodlustTracker.poll(state and state.currentPull)
  local lustRecord = FTD.BloodlustTracker.getRecord()
  local plannedLustPulls = FTD.BloodlustTracker.getPlannedPulls(dungeonIndex, presetIndex)

  local currentPullHasBoss = state and state.currentPull and routeIndex.pulls[state.currentPull]
    and routeIndex.pulls[state.currentPull].hasBoss
  local evalResult = FTD.DeviationWarning.evaluate(
    state, dungeonMax, warnThresholdPct or FTD.DeviationWarning.DEFAULT_THRESHOLD_PCT, currentPullHasBoss
  )

  return {
    dungeonIndex = dungeonIndex,
    presetIndex = presetIndex,
    preset = preset,
    pulls = pulls,
    enemies = enemies,
    routeIndex = routeIndex,
    state = state,
    sublevel = sublevel,
    lustRecord = lustRecord,
    plannedLustPulls = plannedLustPulls,
    dungeonMax = dungeonMax,
    evalResult = evalResult,
  }
end

---Clears tracked progress (pull states, forces baseline, bloodlust record)
---for whatever route is currently loaded, without changing the dungeon/
---route/floor selection. For rerunning the same dungeon back-to-back, where
---the selection hasn't changed but progress needs to start over.
local function resetProgress()
  FTD.ForcesTracker.resetCurrent()
  FTD.BloodlustTracker.reset()
end

FTD.RenderContext = {
  selectDungeon = selectDungeon,
  getSelection = getSelection,
  gather = gather,
  resetProgress = resetProgress,
}
