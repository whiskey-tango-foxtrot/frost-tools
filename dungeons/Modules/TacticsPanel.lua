local FTD = FTD
local L = FTD.L

-- Shared "Next Boss" callout, used by both the Split Windows' Forces &
-- Bloodlust window and the Single Window layout's footer. Auto-surfaces
-- whichever upcoming boss pulls have tips in FTD.TacticsData (see that
-- file), looking ahead through trash pulls rather than only lighting up on
-- a boss's own pull -- see RenderContext.findUpcomingBossTactics.
--
-- The window/footer itself is never resized by this panel -- its size is
-- whatever the player set (or the default). Instead the panel is handed the
-- vertical space it has to work with each update and stacks in as many
-- upcoming bosses as fit, always showing at least the next one even if it
-- doesn't fully fit, and adding "Then: <boss>" cards below it while there's
-- room for a full one.

local PAD = 7
local GAP = 4
local BLOCK_GAP = 8
local ACCENT = { 0.94, 0.77, 0.10 } -- matches the UPCOMING pull-state gold used elsewhere in this addon
local MUTED = { 0.65, 0.62, 0.50 }

local ROLE_PREFIXES = {
  { prefix = "TANK:", color = "|cFFFF8A3D" },
  { prefix = "HEAL:", color = "|cFF35E0A1" },
  { prefix = "DPS:",  color = "|cFFF0C419" },
}

local function formatTip(text)
  for _, role in ipairs(ROLE_PREFIXES) do
    if text:sub(1, #role.prefix) == role.prefix then
      return role.color..role.prefix.."|r"..text:sub(#role.prefix + 1)
    end
  end
  return text
end

---One boss card: diamond + header label + boss name + up to 2 tips.
local function createBlock(panel)
  local block = CreateFrame("Frame", nil, panel)

  local bg = block:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.06)
  block.bg = bg

  local function edge(p1, p2, horizontal)
    local e = block:CreateTexture(nil, "BORDER")
    e:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.35)
    e:SetPoint(p1)
    e:SetPoint(p2)
    if horizontal then e:SetHeight(1) else e:SetWidth(1) end
  end
  edge("TOPLEFT", "TOPRIGHT", true)
  edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
  edge("TOPLEFT", "BOTTOMLEFT", false)
  edge("TOPRIGHT", "BOTTOMRIGHT", false)

  block.diamond = block:CreateTexture(nil, "ARTWORK")
  block.diamond:SetSize(7, 7)
  block.diamond:SetPoint("TOPLEFT", block, "TOPLEFT", PAD, -PAD - 1)
  block.diamond:SetRotation(math.rad(45))
  block.diamond:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)

  block.header = block:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  block.header:SetPoint("LEFT", block.diamond, "RIGHT", 5, 0)

  block.name = block:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  block.name:SetPoint("TOPLEFT", block.diamond, "BOTTOMLEFT", -1, -GAP)
  block.name:SetPoint("RIGHT", block, "RIGHT", -PAD, 0)
  block.name:SetJustifyH("LEFT")
  block.name:SetWordWrap(false)

  block.tip1 = block:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  block.tip1:SetPoint("TOPLEFT", block.name, "BOTTOMLEFT", 0, -GAP)
  block.tip1:SetPoint("RIGHT", block, "RIGHT", -PAD, 0)
  block.tip1:SetJustifyH("LEFT")
  block.tip1:SetWordWrap(true)

  block.tip2 = block:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  block.tip2:SetPoint("TOPLEFT", block.tip1, "BOTTOMLEFT", 0, -2)
  block.tip2:SetPoint("RIGHT", block, "RIGHT", -PAD, 0)
  block.tip2:SetJustifyH("LEFT")
  block.tip2:SetWordWrap(true)

  return block
end

---Fills in `block`'s text and returns its natural height (does not show or
---position it -- the caller decides whether it fits before doing either).
local function layoutBlock(block, entry, isFirst)
  block.header:SetText(isFirst and L["Next Boss"] or L["Then"])
  block.header:SetTextColor(isFirst and ACCENT[1] or MUTED[1], isFirst and ACCENT[2] or MUTED[2], isFirst and ACCENT[3] or MUTED[3])
  block.diamond:SetVertexColor(isFirst and ACCENT[1] or MUTED[1], isFirst and ACCENT[2] or MUTED[2], isFirst and ACCENT[3] or MUTED[3])
  block.name:SetText(entry.name or "?")

  local tip1Text, tip2Text = entry.tips[1], entry.tips[2]
  block.tip1:SetShown(tip1Text ~= nil)
  block.tip2:SetShown(tip2Text ~= nil)
  if tip1Text then block.tip1:SetText(formatTip(tip1Text)) end
  if tip2Text then block.tip2:SetText(formatTip(tip2Text)) end

  local headerH = block.header:GetStringHeight()
  if not headerH or headerH < 1 then headerH = 11 end
  local nameH = block.name:GetStringHeight()
  if not nameH or nameH < 1 then nameH = 13 end

  local h = PAD + headerH + GAP + nameH
  if tip1Text then
    local tip1H = block.tip1:GetStringHeight()
    h = h + GAP + (tip1H and tip1H > 0 and tip1H or 13)
  end
  if tip2Text then
    local tip2H = block.tip2:GetStringHeight()
    h = h + 2 + (tip2H and tip2H > 0 and tip2H or 13)
  end
  h = h + PAD

  return h
end

---Builds the (initially collapsed/hidden) callout container. Caller anchors
---it with SetPoint immediately after -- this only builds its internal
---layout, and lazily grows a pool of boss-card blocks as update() needs them.
local function create(parent)
  local panel = CreateFrame("Frame", nil, parent)
  panel:Hide()
  panel:SetHeight(0.01)
  panel.blocks = {}
  return panel
end

local function getBlock(panel, index)
  local block = panel.blocks[index]
  if not block then
    block = createBlock(panel)
    panel.blocks[index] = block
  end
  return block
end

---`entries` is RenderContext's ordered nextBosses array (possibly empty).
---`availableHeight` is how much vertical room the caller's layout actually
---has for this panel right now (it never resizes the window/footer itself
---to make more). The first upcoming boss always shows in full even if it
---doesn't fit -- only additional bosses beyond it are gated on space.
local function update(panel, entries, availableHeight)
  if not panel then return end
  if not entries or #entries == 0 then
    for _, block in ipairs(panel.blocks) do block:Hide() end
    panel:Hide()
    panel:SetHeight(0.01)
    return
  end

  availableHeight = availableHeight or 0
  local usedHeight = 0
  local shown = 0
  local previous = nil

  for i, entry in ipairs(entries) do
    local block = getBlock(panel, i)
    local blockH = layoutBlock(block, entry, i == 1)
    local extra = (i == 1) and 0 or BLOCK_GAP
    local fits = (i == 1) or (usedHeight + extra + blockH <= availableHeight)
    if not fits then break end

    block:ClearAllPoints()
    if previous then
      block:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -BLOCK_GAP)
      block:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
    else
      block:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
      block:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
    end
    block:SetHeight(blockH)
    block:Show()

    usedHeight = usedHeight + extra + blockH
    previous = block
    shown = i
  end

  for i = shown + 1, #panel.blocks do
    panel.blocks[i]:Hide()
  end

  panel:SetHeight(usedHeight)
  panel:Show()
end

FTD.TacticsPanel = {
  create = create,
  update = update,
}
