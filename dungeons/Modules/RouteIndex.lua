local FTD = FTD
local pairs, ipairs, tonumber, type = pairs, ipairs, tonumber, type

---Builds a lookup from an MDT preset's `pulls` + that dungeon's `dungeonEnemies`
---table. Progress tracking is forces-delta based (see ForcesTracker.lua) since
---Midnight restricted per-kill combat-log access for addons — this index exists
---to give each pull its total forces value, whether it contains a boss (which
---needs scenario-criteria confirmation rather than forces, since bosses are
---usually 0-forces), and a human-readable roster for the pull list UI.
---
---Returned shape:
---  pulls[pullIndex] = { npcs = { [npcID] = cloneCountInThisPull }, totalForces = number,
---    hasBoss = boolean, bossNames = { displayName, ... } (only present when hasBoss) }
---  npcNames[npcID] = display name
---  pullCount = number of pulls
---
---@param pulls table preset.value.pulls
---@param enemies table MDT.dungeonEnemies[dungeonIndex]
local function build(pulls, enemies)
  local index = {
    pulls = {},
    npcNames = {},
    pullCount = 0,
  }

  if type(pulls) ~= "table" or type(enemies) ~= "table" then return index end

  local pullCount = #pulls
  index.pullCount = pullCount

  for pullIndex = 1, pullCount do
    local pull = pulls[pullIndex]
    local npcs = {}
    local totalForces = 0
    local hasBoss = false
    local bossNames = nil

    if type(pull) == "table" then
      for enemyIndex, clones in pairs(pull) do
        local idx = tonumber(enemyIndex)
        local enemyData = idx and enemies[idx]
        if enemyData and enemyData.id and type(clones) == "table" then
          local cloneCount = #clones
          if cloneCount > 0 then
            local npcID = enemyData.id
            npcs[npcID] = (npcs[npcID] or 0) + cloneCount
            totalForces = totalForces + (enemyData.count or 0) * cloneCount
            index.npcNames[npcID] = enemyData.name
            if enemyData.isBoss then
              hasBoss = true
              bossNames = bossNames or {}
              local already = false
              for _, name in ipairs(bossNames) do
                if name == enemyData.name then already = true break end
              end
              if not already then bossNames[#bossNames + 1] = enemyData.name end
            end
          end
        end
      end
    end

    index.pulls[pullIndex] = { npcs = npcs, totalForces = totalForces, hasBoss = hasBoss, bossNames = bossNames }
  end

  return index
end

FTD.RouteIndex = {
  build = build,
}
