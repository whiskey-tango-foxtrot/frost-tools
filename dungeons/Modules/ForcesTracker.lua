local FTD = FTD
local PullState = FTD.PullState
local math_max = math.max

-- =====================================================================
-- Pure logic — ported from MythicDungeonTools_NextPullTracker's
-- Modules/Scenario.lua + State.lua (the proven, working approach: infer
-- pull completion from enemy-forces delta, since Midnight restricted
-- per-kill combat-log access for addons). Adapted onto this addon's
-- routeIndex.pulls shape instead of NPT's embedded pull-state objects.
-- =====================================================================

---Finds the first pull that isn't COMPLETED/ACTIVE, marks it NEXT (demoting
---any previous NEXT to UPCOMING), leaves the rest UPCOMING. Mutates
---trackerState.pullStates in place; returns true if currentPull changed.
local function recomputeNextPull(routeIndex, trackerState)
  local previous = trackerState.currentPull
  trackerState.currentPull = nil

  for i = 1, routeIndex.pullCount do
    if trackerState.pullStates[i] == PullState.NEXT then
      trackerState.pullStates[i] = PullState.UPCOMING
    end
  end
  for i = 1, routeIndex.pullCount do
    if trackerState.pullStates[i] ~= PullState.COMPLETED and trackerState.pullStates[i] ~= PullState.ACTIVE then
      trackerState.pullStates[i] = PullState.NEXT
      trackerState.currentPull = i
      break
    end
  end

  return trackerState.currentPull ~= previous
end

---If the current pull is a boss pull and a boss-kill is pending (a
---non-weighted scenario criterion completed that hasn't been matched to a
---pull yet), marks the pull complete and returns true. Consumes one pending
---kill. Bosses are usually 0-forces, so without this the forces-delta path
---can never tell a boss died.
local function tryConsumeBossKill(routeIndex, trackerState)
  if (trackerState.pendingBossKills or 0) <= 0 then return false end
  local pullIndex = trackerState.currentPull
  local pull = pullIndex and routeIndex.pulls[pullIndex]
  if not (pull and pull.hasBoss) then return false end

  trackerState.pullForcesKilled[pullIndex] = pull.totalForces
  trackerState.pullStates[pullIndex] = PullState.COMPLETED
  recomputeNextPull(routeIndex, trackerState)
  trackerState.pendingBossKills = trackerState.pendingBossKills - 1
  return true
end

---Checks non-weighted scenario criteria (boss-kill criteria), increments the
---pending-boss-kill counter on each new completion, and tries to consume
---against the current pull. On first call, seeds the "already seen" set so
---criteria completed before tracking started don't count as pending.
---@return boolean stateChanged
local function checkBossCriteriaAdvance(routeIndex, trackerState, numCriteria, getCriteriaInfo)
  if numCriteria == 0 then return false end

  local seedPass = trackerState.completedBossCriteria == nil
  if seedPass then
    trackerState.completedBossCriteria = {}
    trackerState.pendingBossKills = 0
  end

  for i = 1, numCriteria do
    local info = getCriteriaInfo(i)
    if info and not info.isWeightedProgress and info.completed then
      if not trackerState.completedBossCriteria[i] then
        trackerState.completedBossCriteria[i] = true
        if not seedPass then
          trackerState.pendingBossKills = (trackerState.pendingBossKills or 0) + 1
        end
      end
    end
  end

  return tryConsumeBossKill(routeIndex, trackerState)
end

---Consumes a forces increase by marking pulls complete in route order.
---@return boolean stateChanged
local function consumeForces(routeIndex, trackerState, currentForces, dungeonMax)
  local stateChanged = false

  -- Unseeded baseline: treat as 0 so the first poll attributes any
  -- pre-existing forces across the route (catches up when tracking starts
  -- mid-key, e.g. after a reload).
  if trackerState.lastForces == nil then trackerState.lastForces = 0 end

  local forcesDelta = currentForces - trackerState.lastForces
  if forcesDelta > 0 then
    -- Scenario rounding tolerance: weighted progress is a floored integer
    -- percentage, so the absolute-count estimate lags real kills by
    -- strictly less than 1% of dungeonMax.
    local tolerance = (dungeonMax or 0) * 0.01
    local remainingForces = forcesDelta

    while remainingForces > 0 do
      local nextPull = trackerState.currentPull
      if not nextPull then break end
      local pull = routeIndex.pulls[nextPull]
      if not pull then break end

      local killedSoFar = trackerState.pullForcesKilled[nextPull] or 0
      local remainingInPull = pull.totalForces - killedSoFar

      if remainingInPull <= 0 then
        if pull.hasBoss then
          if tryConsumeBossKill(routeIndex, trackerState) then
            stateChanged = true
          else
            break -- waiting for the boss criterion instead of auto-skipping
          end
        else
          trackerState.pullStates[nextPull] = PullState.COMPLETED
          recomputeNextPull(routeIndex, trackerState)
          stateChanged = true
          if not trackerState.currentPull or trackerState.currentPull == nextPull then break end
        end
      else
        if trackerState.pullStates[nextPull] == PullState.NEXT then
          trackerState.pullStates[nextPull] = PullState.ACTIVE
          stateChanged = true
        end

        if remainingForces + tolerance > remainingInPull then
          trackerState.pullForcesKilled[nextPull] = pull.totalForces
          trackerState.pullStates[nextPull] = PullState.COMPLETED
          remainingForces = math_max(0, remainingForces - remainingInPull)
          recomputeNextPull(routeIndex, trackerState)
          stateChanged = true
        else
          trackerState.pullForcesKilled[nextPull] = killedSoFar + remainingForces
          remainingForces = 0
          stateChanged = true
        end
      end
    end
  end

  -- Forces capped at 100%: the scenario won't report further kills once the
  -- dungeon max is reached, so advance through any remaining non-boss pulls
  -- the route still has queued (typically over-planned trash before the
  -- last boss) — the player has killed enough, whatever the route claims.
  if dungeonMax and dungeonMax > 0 and currentForces >= dungeonMax then
    while trackerState.currentPull do
      local idx = trackerState.currentPull
      local pull = routeIndex.pulls[idx]
      if pull.hasBoss then break end
      trackerState.pullForcesKilled[idx] = pull.totalForces
      trackerState.pullStates[idx] = PullState.COMPLETED
      recomputeNextPull(routeIndex, trackerState)
      stateChanged = true
      if trackerState.currentPull == idx then break end
    end
  end

  trackerState.lastForces = currentForces
  return stateChanged
end

---Reads the scenario's current absolute enemy-forces count (not a
---percentage), converting from whichever form the API gives (weighted % of
---dungeonMax, or a raw quantity/totalQuantity pair).
local function getScenarioCurrentForces(dungeonMax)
  local numCriteria = FTD.Wow.getScenarioStepInfo()
  if numCriteria == 0 or not dungeonMax or dungeonMax <= 0 then return nil end

  local bestAbsolute, bestTotal = nil, 0
  for i = 1, numCriteria do
    local info = FTD.Wow.getScenarioCriteriaInfo(i)
    if info then
      local quantity = FTD.Utils.parseNum(info.quantity)
      local totalQuantity = FTD.Utils.parseNum(info.totalQuantity)
      if info.isWeightedProgress and totalQuantity > 0 then
        return (quantity / 100) * dungeonMax
      end
      if totalQuantity > bestTotal and totalQuantity > 10 then
        bestTotal = totalQuantity
        bestAbsolute = (quantity / totalQuantity) * dungeonMax
      end
    end
  end
  return bestAbsolute
end

-- =====================================================================
-- Stateful wrapper
-- =====================================================================

local routeIndex = nil
local dungeonMax = nil
local trackerState = nil

local function newTrackerState()
  return {
    pullStates = {},
    pullForcesKilled = {},
    currentPull = nil,
    lastForces = nil,
    completedBossCriteria = nil,
    pendingBossKills = 0,
  }
end

---Starts a new tracking pass against `newRouteIndex`/`newDungeonMax`.
local function reset(newRouteIndex, newDungeonMax)
  routeIndex = newRouteIndex
  dungeonMax = newDungeonMax
  trackerState = newTrackerState()
  if routeIndex then
    for i = 1, routeIndex.pullCount do
      trackerState.pullStates[i] = PullState.UPCOMING
    end
    recomputeNextPull(routeIndex, trackerState)
  end
end

---Polls the scenario API once and advances tracking. Safe to call even when
---not actively in a scenario (getScenarioCurrentForces returns nil then).
---@return boolean stateChanged
local function poll()
  if not routeIndex or not trackerState then return false end

  local numCriteria = FTD.Wow.getScenarioStepInfo()
  local stateChanged = checkBossCriteriaAdvance(routeIndex, trackerState, numCriteria, FTD.Wow.getScenarioCriteriaInfo)

  local currentForces = getScenarioCurrentForces(dungeonMax)
  if currentForces then
    if consumeForces(routeIndex, trackerState, currentForces, dungeonMax) then
      stateChanged = true
    end
  end

  return stateChanged
end

---Public state snapshot for the UI layer: pullStates/currentPull plus
---actual/target forces for the drift banner. No per-mob detail is available
---under forces-delta tracking (see DeviationWarning.lua for the plainer
---%-only framing this implies).
local function getState()
  if not routeIndex or not trackerState then return nil end

  local targetPull = trackerState.currentPull or routeIndex.pullCount
  local targetForces = 0
  for i = 1, targetPull do
    local pull = routeIndex.pulls[i]
    if pull then targetForces = targetForces + pull.totalForces end
  end

  return {
    pullStates = trackerState.pullStates,
    currentPull = trackerState.currentPull,
    pullForcesKilled = trackerState.pullForcesKilled,
    actualForces = trackerState.lastForces or 0,
    targetForces = targetForces,
  }
end

local function getRouteIndex() return routeIndex end

---Re-runs `reset` against whatever route/dungeonMax is already loaded, without
---needing the caller to have either on hand. For rerunning a dungeon you just
---finished: the scenario's own forces count restarts at 0, but this addon's
---`lastForces` baseline is still sitting at the previous run's final value,
---so without this the next poll reads as a big negative delta and no pulls
---advance until forces climb back past that old baseline.
local function resetCurrent()
  reset(routeIndex, dungeonMax)
end

FTD.ForcesTracker = {
  -- pure
  recomputeNextPull = recomputeNextPull,
  tryConsumeBossKill = tryConsumeBossKill,
  checkBossCriteriaAdvance = checkBossCriteriaAdvance,
  consumeForces = consumeForces,
  getScenarioCurrentForces = getScenarioCurrentForces,
  newTrackerState = newTrackerState,
  -- stateful
  reset = reset,
  resetCurrent = resetCurrent,
  poll = poll,
  getState = getState,
  getRouteIndex = getRouteIndex,
}
