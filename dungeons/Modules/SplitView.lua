local FTD = FTD
local MDT = FTD.MDT
local L = FTD.L
local Utils = FTD.Utils
local RenderContext = FTD.RenderContext

local INNER_PAD = 8
local TITLEBAR_H = 20
local CONTROL_BAR_H = 26

-- First-run default positions/sizes (dx/dy relative to UIParent CENTER, so
-- the cluster appears docked together without actually being one frame).
-- Left column: Map (with the Dungeon/Route/Floor control strip built in),
-- then Forces (with Bloodlust built in) below it. Right column: Pulls,
-- matching the left column's total height so both bottoms line up.
local WINDOW_DEFS = {
  map    = { w = 360, h = 314, dx = -324, dy = 210,  minW = 240, minH = 200 },
  forces = { w = 360, h = 240, dx = -324, dy = -112, minW = 240, minH = 140 },
  pulls  = { w = 280, h = 530, dx = 44,   dy = 210,  minW = 180, minH = 120 },
}

local windows = {}
local rows = {}
local lastCtx = nil

local function getDB() return FTD:GetDB() end

local function getOpacity()
  local db = getDB()
  return ((db and db.windowOpacity) or 90) / 100
end

---Applies the current opacity to all three mini windows (called at creation
---and whenever the Settings slider changes).
local function ApplyOpacity()
  local opacity = getOpacity()
  for _, f in pairs(windows) do f:SetAlpha(opacity) end
end

local function getSavedRect(key)
  local db = getDB()
  return db and db.splitLayout and db.splitLayout[key]
end

local function saveRect(key, f)
  local db = getDB()
  if not db then return end
  db.splitLayout = db.splitLayout or {}
  local point, _, relPoint, x, y = f:GetPoint()
  -- While minimized, f's live height is just the titlebar — persist the
  -- pre-minimize height instead so restoring next session doesn't collapse
  -- the window's remembered size down to the titlebar too.
  local h = f.minimized and (f.normalHeight or f:GetHeight()) or f:GetHeight()
  db.splitLayout[key] = { point = point, relPoint = relPoint, x = x, y = y, w = f:GetWidth(), h = h, minimized = f.minimized or nil }
end

---Collapses `f` to just its titlebar (or restores it), used by each mini
---window's own minimize button. `f.body`/`f.grip`/`f.minimizeBtn` are all
---already set by the time this can be called (button clicks only happen
---after createMiniWindow finishes building the window).
local function setMinimized(f, key, minimized)
  f.minimized = minimized
  if minimized then
    f.normalHeight = f:GetHeight()
    f.body:Hide()
    f.grip:Hide()
    f:SetResizable(false)
    f:SetHeight(TITLEBAR_H)
    f.minimizeBtn.text:SetText("+")
  else
    f.body:Show()
    f.grip:Show()
    f:SetResizable(true)
    f:SetHeight(f.normalHeight or f:GetHeight())
    f.minimizeBtn.text:SetText("\226\136\146") -- minus sign
  end
  saveRect(key, f)
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

---Builds one docked, independently movable/resizable window. `key` is its
---saved-layout id; `def` is a WINDOW_DEFS entry.
local function createMiniWindow(key, title, def)
  local f = CreateFrame("Frame", "FTDSplit_"..key, UIParent)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:SetResizable(true)
  -- SetResizeBounds' exact signature has shifted across WoW versions (some
  -- take width/height numbers, some tables); try it, fall back to the older
  -- SetMinResize, and never let either break the rest of the window setup.
  if f.SetResizeBounds then
    local ok = pcall(f.SetResizeBounds, f, def.minW, def.minH)
    if not ok and f.SetMinResize then
      pcall(f.SetMinResize, f, def.minW, def.minH)
    end
  elseif f.SetMinResize then
    f:SetMinResize(def.minW, def.minH)
  end
  f:EnableMouse(true)
  createChrome(f)

  local titlebar = CreateFrame("Frame", nil, f)
  titlebar:SetPoint("TOPLEFT")
  titlebar:SetPoint("TOPRIGHT")
  titlebar:SetHeight(TITLEBAR_H)
  titlebar:EnableMouse(true)
  titlebar:RegisterForDrag("LeftButton")
  titlebar:SetScript("OnDragStart", function() f:StartMoving() end)
  titlebar:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    saveRect(key, f)
  end)
  local titleBg = titlebar:CreateTexture(nil, "ARTWORK")
  titleBg:SetAllPoints()
  titleBg:SetColorTexture(1, 1, 1, 0.03)
  f.minimizeBtn = CreateFrame("Button", nil, titlebar)
  f.minimizeBtn:SetSize(16, 16)
  f.minimizeBtn:SetPoint("RIGHT", titlebar, "RIGHT", -4, 0)
  local mbBg = f.minimizeBtn:CreateTexture(nil, "ARTWORK")
  mbBg:SetAllPoints()
  mbBg:SetColorTexture(1, 1, 1, 0.06)
  f.minimizeBtn.text = f.minimizeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.minimizeBtn.text:SetPoint("CENTER", 0, 1)
  f.minimizeBtn.text:SetText("\226\136\146") -- minus sign
  f.minimizeBtn:SetScript("OnEnter", function() mbBg:SetColorTexture(1, 1, 1, 0.14) end)
  f.minimizeBtn:SetScript("OnLeave", function() mbBg:SetColorTexture(1, 1, 1, 0.06) end)
  f.minimizeBtn:SetScript("OnClick", function() setMinimized(f, key, not f.minimized) end)

  f.titleText = titlebar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.titleText:SetPoint("LEFT", titlebar, "LEFT", 6, 0)
  f.titleText:SetPoint("RIGHT", f.minimizeBtn, "LEFT", -4, 0)
  f.titleText:SetJustifyH("LEFT")
  f.titleText:SetText(title)

  f.body = CreateFrame("Frame", nil, f)
  f.body:SetPoint("TOPLEFT", titlebar, "BOTTOMLEFT", INNER_PAD, -INNER_PAD)
  f.body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -INNER_PAD, INNER_PAD)

  local grip = CreateFrame("Button", nil, f)
  f.grip = grip
  grip:SetSize(14, 14)
  grip:SetPoint("BOTTOMRIGHT", 0, 0)
  grip:SetFrameLevel(f:GetFrameLevel() + 5)
  grip:SetAlpha(0.35)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  grip:SetScript("OnMouseDown", function(self, button)
    if button ~= "LeftButton" then return end
    f:StartSizing("BOTTOMRIGHT")
  end)
  grip:SetScript("OnMouseUp", function(self, button)
    if button ~= "LeftButton" then return end
    f:StopMovingOrSizing()
    f.normalHeight = f:GetHeight()
    saveRect(key, f)
  end)
  grip:SetScript("OnEnter", function(self) self:SetAlpha(1) end)
  grip:SetScript("OnLeave", function(self) self:SetAlpha(0.35) end)

  f:SetSize(def.w, def.h)
  f:SetPoint("TOPLEFT", UIParent, "CENTER", def.dx, def.dy)

  local saved = getSavedRect(key)
  if saved then
    -- Clamp against this window's *current* minimums — a saved rect from
    -- before a layout change (e.g. controls merging into this window) could
    -- otherwise be smaller than what the new content needs.
    f:SetSize(math.max(saved.w or def.w, def.minW), math.max(saved.h or def.h, def.minH))
    if saved.point then
      f:ClearAllPoints()
      f:SetPoint(saved.point, UIParent, saved.relPoint, saved.x, saved.y)
    end
    f.normalHeight = f:GetHeight()
    if saved.minimized then
      setMinimized(f, key, true)
    end
  end

  f:SetAlpha(getOpacity())
  f:Hide()
  windows[key] = f
  return f
end

local function createMapWindow()
  local f = createMiniWindow("map", L["Map"], WINDOW_DEFS.map)

  -- Dungeon/Route/Floor control strip, pinned to the top of this window's body.
  f.controlBar = CreateFrame("Frame", nil, f.body)
  f.controlBar:SetPoint("TOPLEFT")
  f.controlBar:SetPoint("TOPRIGHT")
  f.controlBar:SetHeight(CONTROL_BAR_H)

  local function ctlButton(xOff, width)
    local btn = CreateFrame("Button", nil, f.controlBar)
    btn:SetPoint("LEFT", f.controlBar, "LEFT", xOff, 0)
    btn:SetPoint("TOP")
    btn:SetPoint("BOTTOM")
    btn:SetWidth(width)
    -- The Route label shows the route's saved name from MDT, which can run
    -- well past this chip's width -- clip it instead of letting it bleed
    -- into the neighboring chip.
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
    btn:SetScript("OnLeave", function()
      bg:SetColorTexture(0.12, 0.14, 0.18, 1)
      GameTooltip:Hide()
    end)
    return btn
  end

  f.dungeonBtn = ctlButton(0, 90)
  f.dungeonBtn.text:SetText(L["Dungeon"])
  f.dungeonBtn:SetScript("OnClick", function(self)
    FTD.DungeonSelector.openDungeonMenu(self, function(dungeonIndex)
      RenderContext.selectDungeon(dungeonIndex)
      FTD.SplitView.Render()
    end)
  end)

  f.routeBtn = ctlButton(96, 90)
  f.routeBtn.text:SetText(L["Route"])
  f.routeBtn:SetScript("OnClick", function(self)
    FTD.DungeonSelector.openRouteMenu(self)
  end)

  f.resetBtn = ctlButton(192, 90)
  f.resetBtn.text:SetText(L["Reset"])
  f.resetBtn:SetScript("OnClick", function()
    RenderContext.resetProgress()
    FTD.SplitView.Render()
  end)

  -- Map area, filling the rest of the body below the control strip.
  local mapArea = CreateFrame("Frame", nil, f.body)
  mapArea:SetPoint("TOPLEFT", f.controlBar, "BOTTOMLEFT", 0, -6)
  mapArea:SetPoint("BOTTOMRIGHT", f.body, "BOTTOMRIGHT", 0, 0)

  f.mapWidget = FTD.MapWidget.create(mapArea, mapArea:GetWidth(), mapArea:GetHeight())
  f.mapWidget.viewport:SetAllPoints(mapArea)

  mapArea:SetScript("OnSizeChanged", function(_, w, h)
    if w < 10 or h < 10 then return end
    f.mapWidget.resize(w, h)
    if lastCtx then
      FTD.PullMarkers.update(
        f.mapWidget.content, f.mapWidget.markers, lastCtx.pulls, lastCtx.enemies, lastCtx.sublevel,
        lastCtx.state and lastCtx.state.pullStates,
        f.mapWidget.scale,
        lastCtx.lustRecord and lastCtx.lustRecord.pullAtCast,
        lastCtx.plannedLustPulls,
        function(pullIndex, owner)
          local isPlanned = lastCtx.plannedLustPulls and lastCtx.plannedLustPulls[pullIndex]
          FTD.DungeonSelector.openPullMenu(owner, pullIndex, isPlanned, function()
            FTD.BloodlustTracker.togglePlannedPull(lastCtx.dungeonIndex, lastCtx.presetIndex, pullIndex)
            FTD.SplitView.Render()
          end)
        end
      )
      f.mapWidget.loadTextures(lastCtx.dungeonIndex, lastCtx.sublevel)
    end
  end)
  return f
end

local function createForcesWindow()
  local f = createMiniWindow("forces", L["Forces & Bloodlust"], WINDOW_DEFS.forces)

  f.forcesValue = f.body:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.forcesValue:SetPoint("TOPLEFT", f.body, "TOPLEFT", 0, 0)
  f.forcesValue:SetPoint("TOPRIGHT", f.body, "TOPRIGHT", 0, 0)
  f.forcesValue:SetJustifyH("LEFT")

  f.barTrack = CreateFrame("Frame", nil, f.body)
  f.barTrack:SetPoint("TOPLEFT", f.forcesValue, "BOTTOMLEFT", 0, -4)
  f.barTrack:SetPoint("RIGHT", f.body, "RIGHT", 0, 0)
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

  f.warnBanner = CreateFrame("Frame", nil, f.body)
  f.warnBanner:SetPoint("TOPLEFT", f.barTrack, "BOTTOMLEFT", 0, -8)
  f.warnBanner:SetPoint("RIGHT", f.body, "RIGHT", 0, 0)
  f.warnBanner:SetHeight(30)
  local warnBg = f.warnBanner:CreateTexture(nil, "BACKGROUND")
  warnBg:SetAllPoints()
  warnBg:SetColorTexture(0.23, 0.08, 0.08, 1)
  f.warnText = f.warnBanner:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.warnText:SetPoint("LEFT", f.warnBanner, "LEFT", 6, 0)
  f.warnText:SetPoint("RIGHT", f.warnBanner, "RIGHT", -6, 0)
  f.warnText:SetJustifyH("LEFT")
  f.warnBanner:Hide()

  -- Bloodlust readout, always anchored below the (fixed-height, hide/show
  -- only) warn banner slot — a hidden banner still holds its geometry, so
  -- this doesn't jump around when the banner appears/disappears.
  f.lustStatus = f.body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.lustStatus:SetPoint("TOPLEFT", f.warnBanner, "BOTTOMLEFT", 0, -8)
  f.lustStatus:SetPoint("RIGHT", f.body, "RIGHT", 0, 0)
  f.lustStatus:SetJustifyH("LEFT")
  f.lustStatus:SetWordWrap(true)

  f.tacticsPanel = FTD.TacticsPanel.create(f.body)
  f.tacticsPanel:SetPoint("TOPLEFT", f.lustStatus, "BOTTOMLEFT", 0, -8)
  f.tacticsPanel:SetPoint("RIGHT", f.body, "RIGHT", 0, 0)

  return f
end

local function createPullsWindow()
  local f = createMiniWindow("pulls", L["Pulls"], WINDOW_DEFS.pulls)
  f.listScroll = CreateFrame("ScrollFrame", nil, f.body, "UIPanelScrollFrameTemplate")
  f.listScroll:SetPoint("TOPLEFT", f.body, "TOPLEFT", 0, 0)
  f.listScroll:SetPoint("BOTTOMRIGHT", f.body, "BOTTOMRIGHT", -20, 0)
  f.listContent = CreateFrame("Frame", nil, f.listScroll)
  f.listContent:SetSize(WINDOW_DEFS.pulls.w - 20 - INNER_PAD * 2, 1)
  f.listScroll:SetScrollChild(f.listContent)
  f.body:SetScript("OnSizeChanged", function(_, w)
    if w > 30 then f.listContent:SetWidth(w - 20) end
  end)
  return f
end

local function updateForcesPanel(evalResult, db)
  local f = windows.forces
  local warnEnabled = db == nil or db.warnEnabled ~= false
  f.forcesValue:SetText(string.format("%.1f%%  |cFF8B91A0/ %.1f%% planned|r", evalResult.actualPct, evalResult.targetPct))
  f.barFill:SetWidth(math.max(1, f.barTrack:GetWidth() * Utils.clamp(evalResult.actualPct / 100, 0, 1)))
  f.barTarget:ClearAllPoints()
  f.barTarget:SetPoint("TOP", f.barTrack, "TOPLEFT", f.barTrack:GetWidth() * Utils.clamp(evalResult.targetPct / 100, 0, 1), 0)
  f.barTarget:SetPoint("BOTTOM", f.barTrack, "BOTTOMLEFT", f.barTrack:GetWidth() * Utils.clamp(evalResult.targetPct / 100, 0, 1), 0)

  if warnEnabled and evalResult.headline then
    local line = evalResult.headline
    if evalResult.detail then line = line.."\n|cFFE8A7A7"..evalResult.detail.."|r" end
    f.warnText:SetText(line)
    f.warnBanner:SetHeight(evalResult.detail and 38 or 24)
    f.warnBanner:Show()
  else
    f.warnBanner:Hide()
  end
end

local function updateLustStatus(record)
  local f = windows.forces
  if not record then
    f.lustStatus:SetText(L["Bloodlust not yet used"])
    return
  end
  local remaining = record.availableAt and (record.availableAt - GetTime()) or 0
  local countdown = Utils.formatCountdown(remaining)
  if countdown then
    local pullText = record.pullAtCast and (L["pull"].." "..record.pullAtCast) or L["this run"]
    f.lustStatus:SetText(string.format("|cFFFFD76A\226\154\161 %s|r %s %s \226\128\148 %s %s",
      L["Bloodlust"], L["used on"], pullText, L["ready again in"], countdown))
  else
    f.lustStatus:SetText("|cFFFFD76A\226\154\161 "..L["Bloodlust ready"].."|r")
  end
end

local function ensureCreated()
  if windows.map then return end
  createMapWindow()
  createForcesWindow()
  createPullsWindow()
end

---How much vertical room is left in the Forces window, below whatever the
---tactics panel is anchored under, given the window's *current* size (never
---resized by this addon -- only ever by the player's own drag). The panel
---uses this to decide how many upcoming bosses it can stack in, always
---showing at least the next one even past this budget.
local function forcesTacticsAvailableHeight()
  local f = windows.forces
  if not f or f.minimized then return 0 end
  local top = f.tacticsPanel and f.tacticsPanel:GetTop()
  local bottom = f.body:GetBottom()
  if not top or not bottom then return 0 end
  return math.max(0, top - bottom)
end

local function Render()
  -- A background auto-detect (e.g. walking into a dungeon) shouldn't conjure
  -- windows onto the screen on its own — only re-render if already shown.
  if not windows.map then return end
  local db = getDB()
  local thresholdPct = (db and db.warnThresholdPct) or FTD.DeviationWarning.DEFAULT_THRESHOLD_PCT
  local ctx, reason, dungeonIndex = RenderContext.gather(thresholdPct)
  lastCtx = ctx

  local mapTitle = ctx and (MDT.dungeonList[ctx.dungeonIndex] or "?")
    or (dungeonIndex and MDT.dungeonList[dungeonIndex]) or L["Map"]
  windows.map.titleText:SetText(mapTitle)

  if not ctx then
    windows.map.mapWidget.loadTextures(nil, nil)
    return
  end

  windows.map.mapWidget.loadTextures(ctx.dungeonIndex, ctx.sublevel)
  windows.map.routeBtn.text:SetText(ctx.preset.text or L["Route"])

  FTD.PullMarkers.update(
    windows.map.mapWidget.content, windows.map.mapWidget.markers, ctx.pulls, ctx.enemies, ctx.sublevel,
    ctx.state and ctx.state.pullStates,
    windows.map.mapWidget.scale,
    ctx.lustRecord and ctx.lustRecord.pullAtCast,
    ctx.plannedLustPulls,
    function(pullIndex, owner)
      local isPlanned = ctx.plannedLustPulls and ctx.plannedLustPulls[pullIndex]
      FTD.DungeonSelector.openPullMenu(owner, pullIndex, isPlanned, function()
        FTD.BloodlustTracker.togglePlannedPull(ctx.dungeonIndex, ctx.presetIndex, pullIndex)
        FTD.SplitView.Render()
      end)
    end
  )

  FTD.PullList.update(
    windows.pulls.listContent, rows, ctx.pulls, ctx.routeIndex,
    ctx.state and ctx.state.pullForcesKilled,
    ctx.state and ctx.state.pullStates,
    ctx.lustRecord and ctx.lustRecord.pullAtCast,
    ctx.plannedLustPulls,
    ctx.dungeonMax
  )

  updateForcesPanel(ctx.evalResult, db)
  updateLustStatus(ctx.lustRecord)
  FTD.TacticsPanel.update(windows.forces.tacticsPanel, ctx.nextBosses, forcesTacticsAvailableHeight())
end

local function Tick()
  if not windows.map or not windows.map:IsShown() then return end
  -- ForcesTracker.poll() and BloodlustTracker.poll() both happen inside
  -- Render -> RenderContext.gather, so a plain Render() here is what
  -- actually advances tracking each second.
  Render()
end

local function Show()
  ensureCreated()
  for _, f in pairs(windows) do f:Show() end
  Render()
end

local function Hide()
  for _, f in pairs(windows) do f:Hide() end
end

local function Toggle()
  ensureCreated()
  if windows.map:IsShown() then Hide() else Show() end
end

local function IsShown()
  return windows.map ~= nil and windows.map:IsShown()
end

FTD.SplitView = {
  Show = Show,
  Hide = Hide,
  Toggle = Toggle,
  Render = Render,
  Tick = Tick,
  IsShown = IsShown,
  ApplyOpacity = ApplyOpacity,
}
