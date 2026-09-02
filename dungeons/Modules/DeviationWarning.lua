local FTD = FTD

local DEFAULT_THRESHOLD_PCT = 5.0

---Pure: turns ForcesTracker's derived state into display numbers + banner
---text. `dungeonMax` is MDT.dungeonTotalCount[dungeonIndex].normal.
---`currentPullHasBoss` suppresses the behind/ahead headline while parked on
---a boss pull: since boss pulls are 0 trash-forces, the cumulative target
---has effectively already caught up to "the whole route" the moment the
---preceding trash finishes, so any residual gap reads as "behind the total"
---rather than reflecting the boss pull itself — there's no more trash to
---catch up on, only the boss kill, which forces% can't measure anyway.
---
---Forces-delta tracking (see ForcesTracker.lua — combat log per-mob
---confirmation isn't available to addons in Midnight) can only say "how far
---off the planned %", not which specific mob is missing/extra — so unlike an
---earlier combat-log-based design, there is no per-mob detail line here,
---matching MythicDungeonTools_NextPullTracker's own %-only framing.
local function evaluate(state, dungeonMax, thresholdPct, currentPullHasBoss)
  thresholdPct = thresholdPct or DEFAULT_THRESHOLD_PCT
  if not state or not dungeonMax or dungeonMax <= 0 then
    return { actualPct = 0, targetPct = 0, gap = 0 }
  end

  local actualPct = (state.actualForces / dungeonMax) * 100
  local targetPct = (state.targetForces / dungeonMax) * 100
  local gap = actualPct - targetPct

  local result = { actualPct = actualPct, targetPct = targetPct, gap = gap }

  if not currentPullHasBoss then
    if gap < -thresholdPct then
      result.direction = "behind"
      result.headline = string.format("Behind route by %.1f%%", -gap)
    elseif gap > thresholdPct then
      result.direction = "ahead"
      result.headline = string.format("Ahead of route by %.1f%%", gap)
    end
  end

  return result
end

FTD.DeviationWarning = {
  DEFAULT_THRESHOLD_PCT = DEFAULT_THRESHOLD_PCT,
  evaluate = evaluate,
}
