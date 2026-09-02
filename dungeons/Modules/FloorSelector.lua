local FTD = FTD
local pairs, ipairs, tonumber = pairs, ipairs, tonumber

---Picks the sublevel to display: the floor of whichever pull is "current"
---(falls back to the first pull's floor, then 1), unless `manualOverride` is
---set, in which case that wins. Pure — takes the raw pulls/enemies tables.
local function resolveSublevel(pulls, enemies, currentPullIndex, manualOverride)
  if manualOverride then return manualOverride end

  local pullIndex = currentPullIndex or 1
  local pull = pulls and pulls[pullIndex]
  if pull then
    for enemyIndex, clones in pairs(pull) do
      local idx = tonumber(enemyIndex)
      local enemyData = idx and enemies and enemies[idx]
      if enemyData and enemyData.clones then
        for _, cloneIndex in ipairs(clones) do
          local clone = enemyData.clones[cloneIndex]
          if clone and clone.sublevel then return clone.sublevel end
        end
      end
    end
  end
  return 1
end

FTD.FloorSelector = {
  resolveSublevel = resolveSublevel,
}
