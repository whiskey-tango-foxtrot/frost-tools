local FTD = FTD
local PullState = FTD.PullState
local L = FTD.L
local pairs, ipairs = pairs, ipairs

local ROW_MIN_HEIGHT = 30
local ROW_TOP_PAD = 6
local ROW_BOTTOM_PAD = 8
local MOB_LINE_GAP = 2
local MOB_INDENT = 14

local STATE_LABEL_COLOR = {
  [PullState.NEXT]      = "|cFF35E0A1",
  [PullState.ACTIVE]    = "|cFFFF8A3D",
  [PullState.COMPLETED] = "|cFF6B7280",
  [PullState.UPCOMING]  = "|cFFF0C419",
}

---Builds a { {name=, count=}, ... } list from a pull's per-npc counts,
---sorted by count descending. Different npc ids sharing the same display
---name (MDT sometimes has more than one entry for what reads as "the same"
---mob) are merged by name so they don't show up as separate, identical-
---looking entries.
local function summarizePullNpcs(pull, npcNames)
  local byName = {}
  local order = {}
  for npcID, count in pairs(pull.npcs) do
    local name = npcNames[npcID] or ("NPC "..npcID)
    if not byName[name] then
      order[#order + 1] = name
      byName[name] = 0
    end
    byName[name] = byName[name] + count
  end
  table.sort(order, function(a, b) return byName[a] > byName[b] end)
  local list = {}
  for _, name in ipairs(order) do
    list[#list + 1] = { name = name, count = byName[name] }
  end
  return list
end

local function getMobLine(row, i)
  local line = row.mobLines[i]
  if not line then
    line = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line:SetJustifyH("LEFT")
    row.mobLines[i] = line
  end
  return line
end

local function getRow(content, rows, pullIndex)
  local row = rows[pullIndex]
  if not row then
    row = CreateFrame("Frame", nil, content)
    row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0) -- re-anchored per-render in update()
    row:SetPoint("RIGHT", content, "RIGHT", 0, 0)

    row.divider = row:CreateTexture(nil, "BACKGROUND")
    row.divider:SetPoint("BOTTOMLEFT")
    row.divider:SetPoint("BOTTOMRIGHT")
    row.divider:SetHeight(1)
    row.divider:SetColorTexture(1, 1, 1, 0.06)

    -- Planned-bloodlust highlight: a full-row wash plus a left-edge accent
    -- bar, mirroring the same red highlight the map gives that pull's hull.
    row.markTint = row:CreateTexture(nil, "BACKGROUND", nil, -1)
    row.markTint:SetAllPoints()
    row.markTint:SetColorTexture(1, 0.30, 0.30, 0.07)
    row.markTint:Hide()

    row.markBar = row:CreateTexture(nil, "ARTWORK")
    row.markBar:SetPoint("TOPLEFT")
    row.markBar:SetPoint("BOTTOMLEFT")
    row.markBar:SetWidth(3)
    row.markBar:SetColorTexture(1, 0.30, 0.30, 0.9)
    row.markBar:Hide()

    row.dot = row:CreateTexture(nil, "ARTWORK")
    row.dot:SetSize(8, 8)
    row.dot:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -6)
    row.dot:SetTexture("Interface\\AddOns\\MythicDungeonTools\\Textures\\Circle_White")

    -- Just "Pull N (X.X%)" now — the mob breakdown moved to its own indented
    -- lines below, so this never needs to wrap.
    row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.title:SetPoint("TOPLEFT", row.dot, "TOPRIGHT", 6, 2)
    row.title:SetPoint("RIGHT", row, "RIGHT", -46, 0)
    row.title:SetJustifyH("LEFT")
    row.title:SetWordWrap(false)

    row.stateLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.stateLabel:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -6)

    -- One line per distinct mob type, pooled and grown as needed.
    row.mobLines = {}

    -- Live progress ("42% of this pull's forces") for the active pull, below
    -- the mob lines. Anchored fresh each render since its position depends
    -- on how many mob lines came before it.
    row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.detail:SetJustifyH("LEFT")
    row.detail:SetWordWrap(true)

    rows[pullIndex] = row
  end
  return row
end

---Rebuilds the pull list from scratch. `pulls`/`enemies` are the raw MDT
---route/enemy tables (for names+counts), `routeIndex` comes from RouteIndex,
---`pullForcesKilled` (from ForcesTracker's state) gives each pull's forces
---progress — per-mob "2 of 4 killed" detail isn't available under
---forces-delta tracking, so the active pull shows a % of its own forces
---instead. `dungeonMax` (MDT.dungeonTotalCount[dungeonIndex].normal) is used
---to show what % of the whole dungeon's forces each pull is worth, alongside
---the cumulative % the route should be at once that pull is dead.
---`plannedLustPulls` (a pullIndex -> true set, optional) highlights this
---route's planned bloodlust pull(s) with a red row accent, mirroring the map.
local function update(content, rows, pulls, routeIndex, pullForcesKilled, pullStates, lustPullIndex, plannedLustPulls, dungeonMax)
  for _, row in pairs(rows) do
    row:Hide()
    for _, line in ipairs(row.mobLines) do line:Hide() end
  end
  if not pulls then content:SetHeight(1) return end

  local yOffset = 0
  local cumulativeForces = 0

  for pullIndex, pull in ipairs(pulls) do
    local indexed = routeIndex.pulls[pullIndex]
    if indexed then
      local row = getRow(content, rows, pullIndex)
      local state = pullStates and pullStates[pullIndex] or PullState.UPCOMING
      local color = STATE_LABEL_COLOR[state] or STATE_LABEL_COLOR[PullState.UPCOMING]

      local mobList = summarizePullNpcs(indexed, routeIndex.npcNames)
      local isPlanned = plannedLustPulls and plannedLustPulls[pullIndex]
      -- Planned pulls get the red row highlight below instead of an inline
      -- tag; the actual-cast pull gets a text tag rather than an icon (an
      -- emoji lightning bolt doesn't exist in WoW's UI font and rendered as
      -- a blank box).
      local lustTag = (pullIndex == lustPullIndex) and " |cFFFFD76A"..L["LUST"].."|r" or ""
      local bossTag = indexed.hasBoss and ("|cFFFF6A6A"..L["BOSS"].."|r ") or ""
      local pctTag = ""
      if dungeonMax and dungeonMax > 0 then
        cumulativeForces = cumulativeForces + indexed.totalForces
        pctTag = string.format("  |cFF8B91A0(%.1f%% / %.1f%%)|r",
          (indexed.totalForces / dungeonMax) * 100, (cumulativeForces / dungeonMax) * 100)
      end
      row.title:SetText(bossTag.."Pull "..pullIndex..pctTag..lustTag)
      row.stateLabel:SetText(color..state:upper().."|r")
      row.dot:SetVertexColor(unpack(FTD.PullMarkers.colorForState(state)))
      row.markBar:SetShown(isPlanned)
      row.markTint:SetShown(isPlanned)

      local lastAnchor = row.title
      for i, entry in ipairs(mobList) do
        local line = getMobLine(row, i)
        line:SetText((entry.count > 1 and (entry.count.."x ") or "")..entry.name)
        line:ClearAllPoints()
        -- Only the first line needs the explicit indent; each later line
        -- chains to the previous one's already-indented left edge.
        line:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", (i == 1) and MOB_INDENT or 0, -MOB_LINE_GAP)
        line:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        line:Show()
        lastAnchor = line
      end
      for i = #mobList + 1, #row.mobLines do
        row.mobLines[i]:Hide()
      end

      local detailText = ""
      if state == PullState.ACTIVE and indexed.totalForces > 0 then
        local killed = (pullForcesKilled and pullForcesKilled[pullIndex]) or 0
        if killed < indexed.totalForces then
          local pct = math.floor((killed / indexed.totalForces) * 100)
          detailText = pct.."% of this pull's forces"
        end
      end
      row.detail:SetText(detailText)
      row.detail:ClearAllPoints()
      row.detail:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", (#mobList == 0) and MOB_INDENT or 0, -MOB_LINE_GAP)
      row.detail:SetPoint("RIGHT", row, "RIGHT", -4, 0)

      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
      row:SetPoint("RIGHT", content, "RIGHT", 0, 0)

      -- GetStringHeight reflects each FontString's actual (already anchor-
      -- resolved) height, so the row always fits its content exactly.
      local titleHeight = row.title:GetStringHeight() or 14
      local mobLinesHeight = 0
      for i = 1, #mobList do
        mobLinesHeight = mobLinesHeight + (row.mobLines[i]:GetStringHeight() or 12) + MOB_LINE_GAP
      end
      local detailHeight = (detailText ~= "") and ((row.detail:GetStringHeight() or 12) + MOB_LINE_GAP) or 0
      local rowHeight = math.max(ROW_MIN_HEIGHT, ROW_TOP_PAD + titleHeight + mobLinesHeight + detailHeight + ROW_BOTTOM_PAD)
      row:SetHeight(rowHeight)

      yOffset = yOffset + rowHeight
      row:Show()
    end
  end

  content:SetHeight(math.max(1, yOffset))
end

FTD.PullList = {
  ROW_MIN_HEIGHT = ROW_MIN_HEIGHT,
  summarizePullNpcs = summarizePullNpcs,
  update = update,
}
