local mocks = require("wow_mocks")

describe("DeviationWarning.lua", function()
  local DeviationWarning

  before_each(function()
    mocks.reset()
    mocks.loadSource("Modules/DeviationWarning.lua")
    DeviationWarning = _G.FTD.DeviationWarning
  end)

  it("returns zeros and no banner when dungeonMax is missing", function()
    local result = DeviationWarning.evaluate({ actualForces = 10, targetForces = 20 }, nil, 5)
    assert.equals(0, result.gap)
    assert.is_nil(result.headline)
  end)

  it("stays quiet when the gap is within threshold", function()
    -- actual 50/100=50%, target 52/100=52% -> 2% gap, under a 5% threshold
    local state = { actualForces = 50, targetForces = 52 }
    local result = DeviationWarning.evaluate(state, 100, 5)
    assert.is_nil(result.headline)
  end)

  it("flags 'behind' once the gap exceeds the threshold", function()
    local state = { actualForces = 40, targetForces = 58 } -- 40% vs 58% = -18% gap
    local result = DeviationWarning.evaluate(state, 100, 5)
    assert.equals("behind", result.direction)
    assert.matches("Behind route by 18%.0%%", result.headline)
    assert.is_nil(result.detail) -- no per-mob detail under forces-delta tracking
  end)

  it("flags 'ahead' once the gap exceeds the threshold", function()
    local state = { actualForces = 70, targetForces = 50 } -- +20% gap
    local result = DeviationWarning.evaluate(state, 100, 5)
    assert.equals("ahead", result.direction)
    assert.matches("Ahead of route by 20%.0%%", result.headline)
  end)

  it("gap sits exactly at the threshold without tripping (strict inequality)", function()
    local state = { actualForces = 45, targetForces = 50 } -- exactly -5%
    local result = DeviationWarning.evaluate(state, 100, 5)
    assert.is_nil(result.headline)
  end)

  it("suppresses the headline while parked on a boss pull, even past threshold", function()
    -- Boss pulls are 0 forces, so the cumulative target has already "caught
    -- up" to the whole route the moment the preceding trash finishes; a gap
    -- here reflects past drift, not the boss pull itself.
    local state = { actualForces = 40, targetForces = 58 }
    local result = DeviationWarning.evaluate(state, 100, 5, true)
    assert.is_nil(result.headline)
    assert.is_nil(result.direction)
    -- The raw numbers are still computed/available for the forces bar itself.
    assert.equals(40, result.actualPct)
    assert.equals(58, result.targetPct)
  end)
end)
