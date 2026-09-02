local mocks = require("wow_mocks")

describe("BloodlustTracker.lua", function()
  local BloodlustTracker

  before_each(function()
    mocks.reset()
    mocks.loadSource("Modules/BloodlustTracker.lua")
    BloodlustTracker = _G.FTD.BloodlustTracker
  end)

  describe("scanActiveDebuff", function()
    it("returns nil when C_UnitAuras is unavailable", function()
      _G.C_UnitAuras = nil
      assert.is_nil(BloodlustTracker.scanActiveDebuff())
    end)

    it("returns nil when none of the known debuffs are present", function()
      _G.C_UnitAuras = { GetPlayerAuraBySpellID = function() return nil end }
      assert.is_nil(BloodlustTracker.scanActiveDebuff())
    end)

    it("returns the expiration time and spellId of whichever known debuff is active", function()
      _G.C_UnitAuras = {
        GetPlayerAuraBySpellID = function(spellId)
          if spellId == 57724 then return { expirationTime = 12345 } end
          return nil
        end,
      }
      local expirationTime, spellId = BloodlustTracker.scanActiveDebuff()
      assert.equals(12345, expirationTime)
      assert.equals(57724, spellId)
    end)
  end)

  describe("detectRisingEdge", function()
    it("is true only when going from not-active to active", function()
      assert.is_true(BloodlustTracker.detectRisingEdge(false, 100))
      assert.is_false(BloodlustTracker.detectRisingEdge(true, 100))
      assert.is_false(BloodlustTracker.detectRisingEdge(false, nil))
      assert.is_false(BloodlustTracker.detectRisingEdge(true, nil))
    end)
  end)

  describe("poll (stateful)", function()
    local expirationTime

    before_each(function()
      expirationTime = nil
      _G.C_UnitAuras = { GetPlayerAuraBySpellID = function(spellId)
        if spellId == 57723 and expirationTime then return { expirationTime = expirationTime } end
        return nil
      end }
    end)

    it("records nothing while the debuff is absent", function()
      local record = BloodlustTracker.poll(3)
      assert.is_nil(record)
      assert.is_nil(BloodlustTracker.getRecord())
    end)

    it("records the pull and expiration on the debuff's rising edge", function()
      expirationTime = 600
      local record = BloodlustTracker.poll(4)
      assert.is_not_nil(record)
      assert.equals(4, record.pullAtCast)
      assert.equals(600, record.availableAt)
    end)

    it("does not overwrite the record on subsequent polls while still active", function()
      expirationTime = 600
      BloodlustTracker.poll(4)
      local record = BloodlustTracker.poll(7) -- currentPull moved on, debuff still up
      assert.equals(4, record.pullAtCast) -- unchanged: this was the pull it was cast on
    end)

    it("creates a new record on a second rising edge after the debuff expires and reappears", function()
      expirationTime = 600
      BloodlustTracker.poll(4)
      expirationTime = nil -- debuff falls off
      BloodlustTracker.poll(9)
      expirationTime = 1300 -- lust used again, later in the run
      local record = BloodlustTracker.poll(9)
      assert.equals(9, record.pullAtCast)
      assert.equals(1300, record.availableAt)
    end)

    it("reset clears the record and the active flag", function()
      expirationTime = 600
      BloodlustTracker.poll(4)
      BloodlustTracker.reset()
      assert.is_nil(BloodlustTracker.getRecord())
      -- and the "was active" flag is cleared too, so the same still-active debuff
      -- reads as a fresh rising edge after a reset (e.g. re-selecting a route mid-buff)
      local record = BloodlustTracker.poll(1)
      assert.is_not_nil(record)
      assert.equals(1, record.pullAtCast)
    end)
  end)
end)
