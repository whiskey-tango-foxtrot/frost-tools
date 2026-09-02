local mocks = require("wow_mocks")

describe("FloorSelector.lua", function()
  local FloorSelector
  local enemies, pulls

  before_each(function()
    mocks.reset()
    mocks.loadSource("Modules/FloorSelector.lua")
    FloorSelector = _G.FTD.FloorSelector

    enemies = {
      [1] = { clones = { [1] = { x = 0, y = 0, sublevel = 1 } } },
      [2] = { clones = { [1] = { x = 0, y = 0, sublevel = 2 } } },
    }
    pulls = {
      [1] = { [1] = { 1 } }, -- floor 1
      [2] = { [2] = { 1 } }, -- floor 2
    }
  end)

  it("a manual override always wins", function()
    assert.equals(3, FloorSelector.resolveSublevel(pulls, enemies, 1, 3))
  end)

  it("follows the current pull's floor when there's no override", function()
    assert.equals(1, FloorSelector.resolveSublevel(pulls, enemies, 1, nil))
    assert.equals(2, FloorSelector.resolveSublevel(pulls, enemies, 2, nil))
  end)

  it("falls back to floor 1 when there is no current pull index", function()
    assert.equals(1, FloorSelector.resolveSublevel(pulls, enemies, nil, nil))
  end)

  it("falls back to floor 1 when the data is missing entirely", function()
    assert.equals(1, FloorSelector.resolveSublevel(nil, nil, 1, nil))
  end)
end)
