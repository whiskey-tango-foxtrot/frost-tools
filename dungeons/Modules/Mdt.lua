local FTD = FTD
local MDT = FTD.MDT

-- Small fallback for newly released dungeons whose MDT mapInfo may still
-- contain placeholder data. These are challenge map IDs, not UI map IDs.
local knownChallengeMapDungeonIndexes = {
  [586] = 161, -- Den of Nalorakk
  [587] = 160, -- Murder Row
}

local function dungeonIndexForChallengeMap(challengeMapId)
  if not challengeMapId or challengeMapId == 0 then return nil end
  if MDT.mapInfo then
    for dungeonIdx, mapInfo in pairs(MDT.mapInfo) do
      if mapInfo and mapInfo.mapID == challengeMapId then
        return dungeonIdx
      end
    end
  end
  return knownChallengeMapDungeonIndexes[challengeMapId]
end

---Figures out which dungeon the player is currently in, preferring the
---active challenge map (identifies the dungeon directly and is unaffected by
---UI map IDs being shared/changed/wrong) and falling back to the player's
---current zone otherwise.
---@return number|nil dungeonIndex
local function detectCurrentDungeon()
  local challengeMapId = C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID and
    C_ChallengeMode.GetActiveChallengeMapID()
  local dungeonIdx = dungeonIndexForChallengeMap(challengeMapId)
  if dungeonIdx then return dungeonIdx end

  if MDT.zoneIdToDungeonIdx and C_Map and C_Map.GetBestMapForUnit then
    local zoneId = C_Map.GetBestMapForUnit("player")
    return zoneId and MDT.zoneIdToDungeonIdx[zoneId]
  end
  return nil
end

FTD.Mdt = {
  detectCurrentDungeon = detectCurrentDungeon,
}
