local mocks = require("wow_mocks")

describe("RouteIndex.lua", function()
  local RouteIndex, enemies, pulls

  before_each(function()
    mocks.reset()
    mocks.loadSource("Modules/RouteIndex.lua")
    RouteIndex = _G.FTD.RouteIndex

    enemies = {
      [1] = { id = 100, name = "Alpha", count = 5, clones = {} },
      [2] = { id = 200, name = "Beta", count = 10, clones = {} },
      [3] = { id = 300, name = "Boss", count = 0, isBoss = true, clones = {} },
    }
    -- Pull 1: 2x Alpha. Pull 2: 1 more Alpha + first Beta. Pull 3: 2 more Beta + the boss.
    pulls = {
      [1] = { [1] = { 1, 2 } },
      [2] = { [1] = { 3 }, [2] = { 1 } },
      [3] = { [2] = { 2, 3 }, [3] = { 1 } },
    }
  end)

  it("returns an empty-but-valid index for nil input", function()
    local index = RouteIndex.build(nil, nil)
    assert.equals(0, index.pullCount)
    assert.same({}, index.pulls)
  end)

  it("aggregates clone counts and force values per pull", function()
    local index = RouteIndex.build(pulls, enemies)
    assert.equals(3, index.pullCount)
    assert.same({ [100] = 2 }, index.pulls[1].npcs)
    assert.equals(2 * 5, index.pulls[1].totalForces)
    assert.same({ [100] = 1, [200] = 1 }, index.pulls[2].npcs)
    assert.equals(1 * 5 + 1 * 10, index.pulls[2].totalForces)
    assert.same({ [200] = 2, [300] = 1 }, index.pulls[3].npcs)
    assert.equals(2 * 10 + 1 * 0, index.pulls[3].totalForces)
  end)

  it("flags a pull as hasBoss only when one of its enemies is isBoss", function()
    local index = RouteIndex.build(pulls, enemies)
    assert.is_false(index.pulls[1].hasBoss)
    assert.is_false(index.pulls[2].hasBoss)
    assert.is_true(index.pulls[3].hasBoss)
  end)

  it("records the display name per NPC", function()
    local index = RouteIndex.build(pulls, enemies)
    assert.equals("Alpha", index.npcNames[100])
    assert.equals("Beta", index.npcNames[200])
    assert.equals("Boss", index.npcNames[300])
  end)

  it("ignores enemy entries with no id and pull entries with zero clones", function()
    enemies[4] = { name = "NoID", count = 1, clones = {} } -- missing `id`
    pulls[1][4] = {} -- zero clones
    local index = RouteIndex.build(pulls, enemies)
    assert.same({ [100] = 2 }, index.pulls[1].npcs) -- unchanged
  end)
end)
