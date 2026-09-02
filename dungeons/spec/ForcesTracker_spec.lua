local mocks = require("wow_mocks")

describe("ForcesTracker.lua", function()
  local RouteIndex, ForcesTracker, PullState
  local enemies, pulls, routeIndex
  local DUNGEON_MAX = 100

  -- Controls what FTD.Wow.getScenarioStepInfo/getScenarioCriteriaInfo report,
  -- so tests can simulate the scenario API tick by tick.
  local criteria

  local function setCriteria(list)
    criteria = list
    _G.FTD.Wow.getScenarioStepInfo = function() return #criteria end
    _G.FTD.Wow.getScenarioCriteriaInfo = function(i) return criteria[i] end
  end

  before_each(function()
    mocks.reset()
    mocks.loadSource("Modules/RouteIndex.lua")
    mocks.loadSource("Modules/ForcesTracker.lua")
    RouteIndex = _G.FTD.RouteIndex
    ForcesTracker = _G.FTD.ForcesTracker
    PullState = _G.FTD.PullState
    setCriteria({})

    enemies = {
      [1] = { id = 100, name = "Alpha", count = 5, clones = {} },
      [2] = { id = 200, name = "Beta", count = 10, clones = {} },
      [3] = { id = 300, name = "Boss", count = 0, isBoss = true, clones = {} },
    }
    -- Pull 1: 2x Alpha (10 forces). Pull 2: Alpha + Beta (15 forces).
    -- Pull 3: boss (0 forces). Pull 4: 2x Beta (20 forces).
    pulls = {
      [1] = { [1] = { 1, 2 } },
      [2] = { [1] = { 3 }, [2] = { 1 } },
      [3] = { [3] = { 1 } },
      [4] = { [2] = { 2, 3 } },
    }
    routeIndex = RouteIndex.build(pulls, enemies)
  end)

  describe("reset", function()
    it("starts pull 1 as NEXT and the rest UPCOMING", function()
      ForcesTracker.reset(routeIndex, DUNGEON_MAX)
      local state = ForcesTracker.getState()
      assert.equals(1, state.currentPull)
      assert.equals(PullState.NEXT, state.pullStates[1])
      assert.equals(PullState.UPCOMING, state.pullStates[2])
      assert.equals(10, state.targetForces) -- pull 1's own total
    end)
  end)

  describe("poll (weighted forces progress)", function()
    before_each(function()
      ForcesTracker.reset(routeIndex, DUNGEON_MAX)
    end)

    it("does nothing when there's no scenario (numCriteria 0)", function()
      local changed = ForcesTracker.poll()
      assert.is_false(changed)
      assert.equals(1, ForcesTracker.getState().currentPull)
    end)

    it("attributes partial forces to the current pull and flips it to ACTIVE", function()
      setCriteria({ { isWeightedProgress = true, quantity = 5, totalQuantity = 100 } }) -- 5% of 100 = 5 forces
      ForcesTracker.poll()
      local state = ForcesTracker.getState()
      assert.equals(PullState.ACTIVE, state.pullStates[1])
      assert.equals(1, state.currentPull)
      assert.equals(5, state.pullForcesKilled[1])
      assert.equals(5, state.actualForces)
    end)

    it("completes pull 1 and rolls the remainder into pull 2 once forces cross the boundary", function()
      setCriteria({ { isWeightedProgress = true, quantity = 5, totalQuantity = 100 } })
      ForcesTracker.poll()
      setCriteria({ { isWeightedProgress = true, quantity = 12, totalQuantity = 100 } }) -- +7 forces
      ForcesTracker.poll()
      local state = ForcesTracker.getState()
      assert.equals(PullState.COMPLETED, state.pullStates[1])
      assert.equals(PullState.ACTIVE, state.pullStates[2])
      assert.equals(2, state.currentPull)
      assert.equals(10, state.pullForcesKilled[1]) -- clamped to the pull's own total, not overshot
      assert.equals(2, state.pullForcesKilled[2])  -- the 2 leftover forces after pull 1 finished
      assert.equals(25, state.targetForces)        -- pull 1 + pull 2
    end)

    it("a small overshoot within tolerance still completes the pull instead of leaving a sliver", function()
      -- Pull 1 needs 10; landing at 9.95 (within the 1% tolerance for dungeonMax=100)
      -- should still read as complete rather than stuck at 99.5%.
      setCriteria({ { isWeightedProgress = true, quantity = 9.95, totalQuantity = 100 } })
      ForcesTracker.poll()
      assert.equals(PullState.COMPLETED, ForcesTracker.getState().pullStates[1])
    end)
  end)

  describe("boss pulls", function()
    before_each(function()
      ForcesTracker.reset(routeIndex, DUNGEON_MAX)
      -- Clear pulls 1+2 (25 forces) in one jump, landing exactly on the boss pull.
      setCriteria({ { isWeightedProgress = true, quantity = 25, totalQuantity = 100 } })
      ForcesTracker.poll()
    end)

    it("does not auto-complete a boss pull from forces alone", function()
      local state = ForcesTracker.getState()
      assert.equals(PullState.COMPLETED, state.pullStates[1])
      assert.equals(PullState.COMPLETED, state.pullStates[2])
      assert.equals(3, state.currentPull) -- stuck on the boss pull, not skipped
      assert.equals(PullState.NEXT, state.pullStates[3])
    end)

    it("completes the boss pull once its non-weighted scenario criterion fires", function()
      setCriteria({
        { isWeightedProgress = true, quantity = 25, totalQuantity = 100 }, -- unchanged, boss is 0 forces
        { isWeightedProgress = false, completed = true },                  -- boss-kill criterion
      })
      local changed = ForcesTracker.poll()
      local state = ForcesTracker.getState()
      assert.is_true(changed)
      assert.equals(PullState.COMPLETED, state.pullStates[3])
      assert.equals(4, state.currentPull) -- advances past the boss to the next pull
    end)

    it("does not double-count a boss criterion that was already completed before tracking started", function()
      -- Fresh route where the boss criterion is *already* completed on the very
      -- first poll (e.g. tracking started mid-key, after the boss already died).
      ForcesTracker.reset(routeIndex, DUNGEON_MAX)
      setCriteria({
        { isWeightedProgress = true, quantity = 25, totalQuantity = 100 },
        { isWeightedProgress = false, completed = true },
      })
      ForcesTracker.poll() -- seeding pass: records the criterion as seen, does NOT queue a pending kill
      local state = ForcesTracker.getState()
      -- Forces alone (25) still clears pulls 1+2 and parks on the boss pull;
      -- the already-completed criterion must not have been (mis)consumed as a
      -- fresh kill against pull 1 or 2.
      assert.equals(3, state.currentPull)
      assert.equals(PullState.NEXT, state.pullStates[3])
    end)
  end)

  describe("forces capped at dungeonMax", function()
    it("auto-completes queued non-boss pulls but still stops at a boss pull", function()
      ForcesTracker.reset(routeIndex, DUNGEON_MAX)
      setCriteria({ { isWeightedProgress = true, quantity = 100, totalQuantity = 100 } })
      ForcesTracker.poll()
      local state = ForcesTracker.getState()
      assert.equals(PullState.COMPLETED, state.pullStates[1])
      assert.equals(PullState.COMPLETED, state.pullStates[2])
      assert.equals(3, state.currentPull)
      assert.equals(PullState.NEXT, state.pullStates[3]) -- boss pull, not auto-completed
      assert.equals(PullState.UPCOMING, state.pullStates[4]) -- never reached past the boss
    end)
  end)

  describe("route change", function()
    it("reset() against a new routeIndex starts over cleanly", function()
      ForcesTracker.reset(routeIndex, DUNGEON_MAX)
      setCriteria({ { isWeightedProgress = true, quantity = 25, totalQuantity = 100 } })
      ForcesTracker.poll()
      assert.equals(3, ForcesTracker.getState().currentPull)

      local otherRoute = RouteIndex.build({ [1] = { [1] = { 1 } } }, enemies) -- 1x Alpha, 5 forces
      ForcesTracker.reset(otherRoute, DUNGEON_MAX)
      local state = ForcesTracker.getState()
      assert.equals(1, state.currentPull)
      assert.equals(PullState.NEXT, state.pullStates[1])
      assert.equals(0, state.actualForces)
    end)
  end)
end)
