local mocks = require("wow_mocks")

-- MDTAdapter.lua *is* the table MDT's Midnight dungeon files write into when
-- the TOC loads them, so it's exercised here the way those files call it
-- (see the `local _, MDT = ...` header of any Midnight/<Dungeon>.lua in MDT).
describe("MDTAdapter", function()
  local FTD

  before_each(function()
    mocks.reset()
    FTD = _G.FTD
    _G.C_Map = nil
    _G.GetSubZoneText = nil
    _G.C_AddOns = nil
    _G.MythicDungeonToolsDB = nil
    _G.MythicDungeonToolsAPI = nil
    mocks.loadSource("Modules/MDTAdapter.lua", "Frost_Tools_Dungeons", FTD)
  end)

  describe("RegisterDungeonLocation", function()
    it("maps every registered zone to the dungeon", function()
      FTD:RegisterDungeonLocation(153, { zoneIds = { 2511, 2515 }, subzoneAreaIDs = { 16814 } })
      assert.equals(153, FTD.zoneIdToDungeonIdx[2511])
      assert.equals(153, FTD.zoneIdToDungeonIdx[2515])
    end)

    it("lets a current-season dungeon take over a zone a past-season one registered first", function()
      FTD:RegisterDungeonLocation(153, { zoneIds = { 2424 } }) -- Magisters' Terrace (season 1)
      FTD:RegisterDungeonLocation(160, { zoneIds = { 2424 } }) -- Murder Row (season 2)
      assert.equals(160, FTD.zoneIdToDungeonIdx[2424])
    end)

    it("keeps a current-season dungeon when a past-season one registers later", function()
      FTD:RegisterDungeonLocation(160, { zoneIds = { 2424 } })
      FTD:RegisterDungeonLocation(153, { zoneIds = { 2424 } })
      assert.equals(160, FTD.zoneIdToDungeonIdx[2424])
    end)

    it("ranks dungeons of the same season by MDT's season-list order, not load order", function()
      FTD:RegisterDungeonLocation(161, { zoneIds = { 2424 } }) -- Den of Nalorakk (2nd in season 2)
      FTD:RegisterDungeonLocation(160, { zoneIds = { 2424 } }) -- Murder Row (1st in season 2)
      assert.equals(160, FTD.zoneIdToDungeonIdx[2424])
      FTD:RegisterDungeonLocation(162, { zoneIds = { 2424 } }) -- The Blinding Vale (3rd)
      assert.equals(160, FTD.zoneIdToDungeonIdx[2424])
    end)

    it("lets any listed dungeon beat one that is in no season list", function()
      FTD:RegisterDungeonLocation(999, { zoneIds = { 2424 } })
      FTD:RegisterDungeonLocation(153, { zoneIds = { 2424 } })
      assert.equals(153, FTD.zoneIdToDungeonIdx[2424])
    end)

    it("tolerates a location table without zoneIds", function()
      assert.has_no_error(function() FTD:RegisterDungeonLocation(1, {}) end)
      assert.has_no_error(function() FTD:RegisterDungeonLocation(1, nil) end)
    end)
  end)

  describe("GetDungeonIdxForZone", function()
    it("returns nil for an unknown zone", function()
      local idx, isSubzone = FTD:GetDungeonIdxForZone(99999)
      assert.is_nil(idx)
      assert.is_false(isSubzone)
    end)

    it("falls back to the zone's priority dungeon without subzone text", function()
      FTD:RegisterDungeonLocation(153, { zoneIds = { 2424 }, subzoneAreaIDs = { 16814 } })
      FTD:RegisterDungeonLocation(160, { zoneIds = { 2424 } })
      local idx, isSubzone = FTD:GetDungeonIdxForZone(2424)
      assert.equals(160, idx)
      assert.is_false(isSubzone)
    end)

    it("prefers the dungeon whose entrance subzone the player is standing in", function()
      _G.C_Map = { GetAreaInfo = function(areaID) return ({ [16814] = "Magisters' Terrace" })[areaID] end }
      FTD:RegisterDungeonLocation(160, { zoneIds = { 2424 } })
      FTD:RegisterDungeonLocation(153, { zoneIds = { 2424 }, subzoneAreaIDs = { 16814 } })

      local idx, isSubzone = FTD:GetDungeonIdxForZone(2424, "Magisters' Terrace")
      assert.equals(153, idx)
      assert.is_true(isSubzone)

      idx, isSubzone = FTD:GetDungeonIdxForZone(2424, "Sunstrider Isle")
      assert.equals(160, idx)
      assert.is_false(isSubzone)
    end)
  end)

  describe("GetDungeonIdxForCurrentLocation", function()
    it("returns nil when the map API is unavailable", function()
      assert.is_nil(FTD:GetDungeonIdxForCurrentLocation())
    end)

    it("resolves the player's current map", function()
      _G.C_Map = { GetBestMapForUnit = function() return 2516 end, GetAreaInfo = function() return nil end }
      _G.GetSubZoneText = function() return "" end
      FTD:RegisterDungeonLocation(153, { zoneIds = { 2516 } })
      local idx, zoneId, isSubzone = FTD:GetDungeonIdxForCurrentLocation()
      assert.equals(153, idx)
      assert.equals(2516, zoneId)
      assert.is_false(isSubzone)
    end)
  end)

  it("loads an MDT 6.2.17+ style dungeon file without error and keeps its data", function()
    local load = loadstring or load
    -- The exact statement shape and order of MDT's Midnight/<Dungeon>.lua
    -- files: RegisterDungeonLocation runs *before* the map/total/enemy tables
    -- are assigned, so an error there would lose all of them.
    local chunk = assert(load([[
      local _, MDT = ...
      local addonName = MDT.AddonName
      local L = MDT.L
      local dungeonIndex = 153
      MDT.dungeonList[dungeonIndex] = L["MagistersTerrace"]
      MDT.mapInfo[dungeonIndex] = { mapID = 558, englishName = "Magisters Terrace" }
      MDT:RegisterDungeonLocation(dungeonIndex, {
        zoneIds = { 2424, 2511 },
        subzoneAreaIDs = { 16814 },
      })
      MDT.dungeonMaps[dungeonIndex] = {
        [0] = "",
        [1] = { customTextures = 'Interface\\AddOns\\'..addonName..'\\Midnight\\Textures\\MagistersTerrace' },
      }
      MDT.dungeonSubLevels[dungeonIndex] = { [1] = L["MagistersTerrace"] }
      MDT.dungeonTotalCount[dungeonIndex] = { normal = 585 }
      MDT.mapPOIs[dungeonIndex] = {}
      MDT.dungeonEnemies[dungeonIndex] = { { name = "Arcane Magister", id = 1, count = 4, clones = {} } }
    ]]))
    chunk("Frost_Tools_Dungeons", FTD)

    assert.equals("MagistersTerrace", FTD.dungeonList[153])
    assert.equals(585, FTD.dungeonTotalCount[153].normal)
    assert.equals(1, #FTD.dungeonEnemies[153])
    assert.equals("Interface\\AddOns\\MythicDungeonTools\\Midnight\\Textures\\MagistersTerrace",
      FTD.dungeonMaps[153][1].customTextures)
    assert.equals(153, FTD.zoneIdToDungeonIdx[2424])
    assert.equals(153, FTD.zoneIdToDungeonIdx[2511])
  end)
end)
