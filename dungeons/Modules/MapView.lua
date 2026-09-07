local FTD = FTD
local MDT = FTD.MDT
local L = FTD.L
local Utils = FTD.Utils
local RenderContext = FTD.RenderContext

local MAP_W, MAP_H = 390, 260
local SIDEBAR_W = 246
local TITLEBAR_H = 28
local FOOTER_H = 188
local PADDING = 8
local FRAME_W = MAP_W + SIDEBAR_W + PADDING * 3
local FRAME_H = TITLEBAR_H + MAP_H + FOOTER_H + PADDING * 3

-- The overall window is fixed-pixel (map + sidebar are laid out for this
-- exact size); "resize" here means uniform SetScale on the whole window,
-- dragged from a corner grip — same technique NPT's beacon uses. The pull
-- list inside reflows on its own (auto-height rows via PullList.lua).
local WINDOW_SCALE_MIN, WINDOW_SCALE_MAX = 0.6, 1.8

local frame
local rows = {}

local function getDB() return FTD:GetDB() end

local function getOpacity()
  local db = getDB()
  return ((db and db.windowOpacity) or 90) / 100
end

---Called at window creation and whenever the Settings slider changes.
local function ApplyOpacity()
  if frame then frame:SetAlpha(getOpacity()) end
end

local function createChrome(f)
  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.058, 0.058, 0.058, 0.92)

  local function edge(p1, p2, thickness, horizontal)
    local e = f:CreateTexture(nil, "BORDER")
    e:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    e:SetPoint(p1)
    e:SetPoint(p2)
    if horizontal then e:SetHeight(thickness) else e:SetWidth(thickness) end
  end
  edge("TOPLEFT", "TOPRIGHT", 1, true)
  edge("BOTTOMLEFT", "BOTTOMRIGHT", 1, true)
  edge("TOPLEFT", "BOTTOMLEFT", 1, false)
  edge("TOPRIGHT", "BOTTOMRIGHT", 1, false)
end

---Corner drag grip that uniformly scales `parent`, persisting the result to
---`db.windowScale`. Ported from NPT's BeaconFrame.createResizeGrip.
local function createResizeGrip(parent)
  local grip = CreateFrame("Button", nil, parent)
  grip:SetSize(16, 16)
  grip:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
  grip:SetFrameLevel(parent:GetFrameLevel() + 5)
  grip:SetAlpha(0.35)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

  local function applyScaleFromDrag(self)
    local nx, ny = GetCursorPosition()
    local dx = nx - self.startX
    local dy = self.startY - ny
    local denom = FRAME_W * self.uiScale
    local dsX = dx / denom
    local dsY = dy / (FRAME_H * self.uiScale)
    local ds = (math.abs(dsX) > math.abs(dsY)) and dsX or dsY
    local newScale = Utils.clamp(self.startScale + ds, WINDOW_SCALE_MIN, WINDOW_SCALE_MAX)
    parent:SetScale(newScale)
  end

  grip:SetScript("OnMouseDown", function(self, button)
    if button ~= "LeftButton" then return end
    self.dragging = true
    self.startX, self.startY = GetCursorPosition()
    self.startScale = parent:GetScale()
    self.uiScale = UIParent:GetEffectiveScale()
    self:SetScript("OnUpdate", applyScaleFromDrag)
  end)

  grip:SetScript("OnMouseUp", function(self, button)
    if button ~= "LeftButton" or not self.dragging then return end
    self.dragging = false
    self:SetScript("OnUpdate", nil)
    local db = getDB()
    if db then db.windowScale = parent:GetScale() end
    if not self.hovering then self:SetAlpha(0.35) end
  end)

  grip:SetScript("OnEnter", function(self) self.hovering = true self:SetAlpha(1) end)
  grip:SetScript("OnLeave", function(self)
    self.hovering = false
    if not self.dragging then self:SetAlpha(0.35) end
  end)

  return grip
end

local function createTitleButton(parent, anchorPoint, xOff)
  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(90, TITLEBAR_H - 6)
  btn:SetPoint(anchorPoint, parent, anchorPoint, xOff, 0)
  -- The Route label shows the route's saved name from MDT, which can run
  -- well past a 90px chip -- clip it to the button instead of letting it
  -- bleed into the neighboring chip.
  btn:SetClipsChildren(true)
  local bg = btn:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.12, 0.14, 0.18, 1)
  btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  btn.text:SetPoint("LEFT", btn, "LEFT", 4, 0)
  btn.text:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
  btn.text:SetJustifyH("CENTER")
  btn.text:SetWordWrap(false)
  btn:SetScript("OnEnter", function(self)
    bg:SetColorTexture(0.18, 0.21, 0.27, 1)
    local text = self.text:GetText()
    if text and text ~= "" then
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
      GameTooltip:SetText(text, 1, 1, 1, 1, true)
      GameTooltip:Show()
    end
  end)
  btn:SetScript("OnLeave", function(self)
    bg:SetColorTexture(0.12, 0.14, 0.18, 1)
    GameTooltip:Hide()
  end)
  return btn
end

local function create()
  local f = CreateFrame("Frame", "FTDMapWindow", UIParent)
  f:SetSize(FRAME_W, FRAME_H)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    local db = getDB()
    if db then db.windowPos = { point = point, relPoint = relPoint, x = x, y = y } end
  end)
  createChrome(f)

  -- Titlebar
  f.titleText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.titleText:SetPoint("LEFT", f, "TOPLEFT", 10, -TITLEBAR_H / 2)
  f.titleText:SetText(L["Frost Tools: Dungeons"])

  f.closeButton = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  f.closeButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
  f.closeButton:SetScript("OnClick", function() f:Hide() end)

  f.routeButton = createTitleButton(f, "TOPRIGHT", -30)
  f.routeButton.text:SetText(L["Route"])
  f.routeButton:SetScript("OnClick", function(self)
    FTD.DungeonSelector.openRouteMenu(self)
  end)

  f.dungeonButton = createTitleButton(f, "TOPRIGHT", -124)
  f.dungeonButton.text:SetText(L["Dungeon"])
  f.dungeonButton:SetScript("OnClick", function(self)
    FTD.DungeonSelector.openDungeonMenu(self, function(dungeonIndex)
      RenderContext.selectDungeon(dungeonIndex)
      FTD.MapView.Render()
    end)
  end)

  f.resetButton = createTitleButton(f, "TOPRIGHT", -218)
  f.resetButton.text:SetText(L["Reset"])
  f.resetButton:SetScript("OnClick", function()
    RenderContext.resetProgress()
    FTD.MapView.Render()
  end)

  -- Map area
  f.mapWidget = FTD.MapWidget.create(f, MAP_W, MAP_H)
  f.mapWidget.viewport:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, -(TITLEBAR_H + PADDING))

  -- Sidebar: scrollable pull list + footer stats panel
  f.sidebar = CreateFrame("Frame", nil, f)
  f.sidebar:SetSize(SIDEBAR_W, MAP_H)
  f.sidebar:SetPoint("TOPLEFT", f.mapWidget.viewport, "TOPRIGHT", PADDING, 0)

  f.listScroll = CreateFrame("ScrollFrame", nil, f.sidebar, "UIPanelScrollFrameTemplate")
  f.listScroll:SetPoint("TOPLEFT", f.sidebar, "TOPLEFT", 0, 0)
  f.listScroll:SetPoint("BOTTOMRIGHT", f.sidebar, "BOTTOMRIGHT", -20, 0)
  f.listContent = CreateFrame("Frame", nil, f.listScroll)
  f.listContent:SetSize(SIDEBAR_W - 20, 1)
  f.listScroll:SetScrollChild(f.listContent)

  -- Footer: forces bar + bloodlust status + drift warning banner
  f.footer = CreateFrame("Frame", nil, f)
  f.footer:SetSize(MAP_W + SIDEBAR_W + PADDING, FOOTER_H)
  f.footer:SetPoint("TOPLEFT", f.mapWidget.viewport, "BOTTOMLEFT", 0, -PADDING)
  local footerBg = f.footer:CreateTexture(nil, "BACKGROUND")
  footerBg:SetAllPoints()
  footerBg:SetColorTexture(0.09, 0.1, 0.13, 1)

  f.forcesLabel = f.footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.forcesLabel:SetPoint("TOPLEFT", f.footer, "TOPLEFT", 8, -6)
  f.forcesLabel:SetText(L["Forces"])

  f.forcesValue = f.footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.forcesValue:SetPoint("TOPRIGHT", f.footer, "TOPRIGHT", -8, -6)

  f.barTrack = CreateFrame("Frame", nil, f.footer)
  f.barTrack:SetPoint("TOPLEFT", f.forcesLabel, "BOTTOMLEFT", 0, -4)
  f.barTrack:SetPoint("RIGHT", f.footer, "RIGHT", -8, 0)
  f.barTrack:SetHeight(8)
  local trackBg = f.barTrack:CreateTexture(nil, "BACKGROUND")
  trackBg:SetAllPoints()
  trackBg:SetColorTexture(0.16, 0.18, 0.22, 1)
  f.barFill = f.barTrack:CreateTexture(nil, "ARTWORK")
  f.barFill:SetPoint("TOPLEFT")
  f.barFill:SetPoint("BOTTOMLEFT")
  f.barFill:SetColorTexture(0.31, 0.76, 1, 1)
  f.barTarget = f.barTrack:CreateTexture(nil, "OVERLAY")
  f.barTarget:SetWidth(2)
  f.barTarget:SetColorTexture(0.88, 0.71, 0.39, 1)

  f.lustStatus = f.footer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.lustStatus:SetPoint("TOPLEFT", f.barTrack, "BOTTOMLEFT", 0, -8)
  f.lustStatus:SetPoint("RIGHT", f.footer, "RIGHT", -8, 0)
  f.lustStatus:SetJustifyH("LEFT")

  f.warnBanner = CreateFrame("Frame", nil, f.footer)
  f.warnBanner:SetPoint("TOPLEFT", f.lustStatus, "BOTTOMLEFT", 0, -6)
  f.warnBanner:SetPoint("RIGHT", f.footer, "RIGHT", -8, 0)
  f.warnBanner:SetHeight(30)
  local warnBg = f.warnBanner:CreateTexture(nil, "BACKGROUND")
  warnBg:SetAllPoints()
  warnBg:SetColorTexture(0.23, 0.08, 0.08, 1)
  f.warnText = f.warnBanner:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.warnText:SetPoint("LEFT", f.warnBanner, "LEFT", 6, 0)
  f.warnText:SetPoint("RIGHT", f.warnBanner, "RIGHT", -6, 0)
  f.warnText:SetJustifyH("LEFT")
  f.warnBanner:Hide()

  f.tacticsPanel = FTD.TacticsPanel.create(f.footer)
  f.tacticsPanel:SetPoint("TOPLEFT", f.warnBanner, "BOTTOMLEFT", 0, -8)
  f.tacticsPanel:SetPoint("RIGHT", f.footer, "RIGHT", -8, 0)

  f.emptyText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.emptyText:SetPoint("CENTER", f.mapWidget.viewport, "CENTER")
  f.emptyText:SetText(L["No route selected. Click Dungeon/Route above to pick one."])
  f.emptyText:Hide()

  f.resizeGrip = createResizeGrip(f)

  f:Hide()
  frame = f
  ApplyOpacity()
  return f
end

local function updateForcesPanel(evalResult, db)
  local warnEnabled = db == nil or db.warnEnabled ~= false
  frame.forcesValue:SetText(string.format("%.1f%%  |cFF8B91A0/ %.1f%% planned|r", evalResult.actualPct, evalResult.targetPct))
  frame.barFill:SetWidth(math.max(1, frame.barTrack:GetWidth() * Utils.clamp(evalResult.actualPct / 100, 0, 1)))
  frame.barTarget:ClearAllPoints()
  frame.barTarget:SetPoint("TOP", frame.barTrack, "TOPLEFT", frame.barTrack:GetWidth() * Utils.clamp(evalResult.targetPct / 100, 0, 1), 0)
  frame.barTarget:SetPoint("BOTTOM", frame.barTrack, "BOTTOMLEFT", frame.barTrack:GetWidth() * Utils.clamp(evalResult.targetPct / 100, 0, 1), 0)

  if warnEnabled and evalResult.headline then
    local line = evalResult.headline
    if evalResult.detail then line = line.."\n|cFFE8A7A7"..evalResult.detail.."|r" end
    frame.warnText:SetText(line)
    frame.warnBanner:SetHeight(evalResult.detail and 38 or 24)
    frame.warnBanner:Show()
  else
    frame.warnBanner:Hide()
  end
end

local function updateLustStatus(record)
  if not record then
    frame.lustStatus:SetText(L["Bloodlust not yet used"])
    return
  end
  local remaining = record.availableAt and (record.availableAt - GetTime()) or 0
  local countdown = Utils.formatCountdown(remaining)
  if countdown then
    local pullText = record.pullAtCast and (L["pull"].." "..record.pullAtCast) or L["this run"]
    frame.lustStatus:SetText(string.format("|cFFFFD76A\226\154\161 %s|r %s %s \226\128\148 %s %s",
      L["Bloodlust"], L["used on"], pullText, L["ready again in"], countdown))
  else
    frame.lustStatus:SetText("|cFFFFD76A\226\154\161 "..L["Bloodlust ready"].."|r")
  end
end

---How much vertical room is left in the footer, below whatever the tactics
---panel is anchored under. The footer is a fixed size (only the window's
---overall uiScale changes it, uniformly) -- this addon never resizes it on
---its own. The panel uses this to decide how many upcoming bosses it can
---stack in, always showing at least the next one even past this budget.
local function footerTacticsAvailableHeight()
  if not frame then return 0 end
  local top = frame.tacticsPanel and frame.tacticsPanel:GetTop()
  local bottom = frame.footer:GetBottom()
  if not top or not bottom then return 0 end
  return math.max(0, top - bottom)
end

local function Render()
  if not frame then return end
  local db = getDB()
  local thresholdPct = (db and db.warnThresholdPct) or FTD.DeviationWarning.DEFAULT_THRESHOLD_PCT
  local ctx, reason, dungeonIndex = RenderContext.gather(thresholdPct)

  if not ctx then
    frame.emptyText:Show()
    if dungeonIndex then
      frame.titleText:SetText(MDT.dungeonList[dungeonIndex] or L["Frost Tools: Dungeons"])
    end
    return
  end
  frame.emptyText:Hide()

  frame.mapWidget.loadTextures(ctx.dungeonIndex, ctx.sublevel)

  frame.titleText:SetText(MDT.dungeonList[ctx.dungeonIndex] or "?")
  frame.routeButton.text:SetText(ctx.preset.text or L["Route"])

  FTD.PullMarkers.update(
    frame.mapWidget.content, frame.mapWidget.markers, ctx.pulls, ctx.enemies, ctx.sublevel,
    ctx.state and ctx.state.pullStates,
    frame.mapWidget.scale,
    ctx.lustRecord and ctx.lustRecord.pullAtCast,
    ctx.plannedLustPulls,
    function(pullIndex, owner)
      local isPlanned = ctx.plannedLustPulls and ctx.plannedLustPulls[pullIndex]
      FTD.DungeonSelector.openPullMenu(owner, pullIndex, isPlanned, function()
        FTD.BloodlustTracker.togglePlannedPull(ctx.dungeonIndex, ctx.presetIndex, pullIndex)
        FTD.MapView.Render()
      end)
    end
  )

  FTD.PullList.update(
    frame.listContent, rows, ctx.pulls, ctx.routeIndex,
    ctx.state and ctx.state.pullForcesKilled,
    ctx.state and ctx.state.pullStates,
    ctx.lustRecord and ctx.lustRecord.pullAtCast,
    ctx.plannedLustPulls,
    ctx.dungeonMax
  )

  updateForcesPanel(ctx.evalResult, db)
  updateLustStatus(ctx.lustRecord)
  FTD.TacticsPanel.update(frame.tacticsPanel, ctx.nextBosses, footerTacticsAvailableHeight())
end

local function Tick()
  if not frame or not frame:IsShown() then return end
  -- ForcesTracker.poll() and BloodlustTracker.poll() both happen inside
  -- Render -> RenderContext.gather, so a plain Render() here is what
  -- actually advances tracking each second.
  Render()
end

local function GetFrame()
  if not frame then
    create()
    local db = getDB()
    local pos = db and db.windowPos
    if pos then
      frame:ClearAllPoints()
      frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    end
    frame:SetScale(Utils.clamp((db and db.windowScale) or 1.0, WINDOW_SCALE_MIN, WINDOW_SCALE_MAX))
  end
  return frame
end

local function Show()
  GetFrame():Show()
  Render()
end

local function Hide()
  if frame then frame:Hide() end
end

local function Toggle()
  local f = GetFrame()
  if f:IsShown() then f:Hide() else Show() end
end

local function IsShown()
  return frame ~= nil and frame:IsShown()
end

FTD.MapView = {
  GetFrame = GetFrame,
  Show = Show,
  Hide = Hide,
  Toggle = Toggle,
  Render = Render,
  Tick = Tick,
  IsShown = IsShown,
  ApplyOpacity = ApplyOpacity,
}
