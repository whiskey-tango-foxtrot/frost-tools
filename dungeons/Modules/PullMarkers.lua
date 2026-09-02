local FTD = FTD
local PullState = FTD.PullState
local pairs, ipairs, tonumber, tostring = pairs, ipairs, tonumber, tostring

-- Same fallback palette convention as MythicDungeonTools_NextPullTracker's
-- BeaconMinimap, kept independent so this addon's colors can be restyled
-- without touching NPT.
local DEFAULT_PULL_COLORS = {
  [PullState.NEXT]      = { 0, 1, 0.5, 1 },
  [PullState.ACTIVE]    = { 1, 0.5, 0, 1 },
  [PullState.COMPLETED] = { 0.4, 0.4, 0.4, 0.6 },
  [PullState.UPCOMING]  = { 1, 1, 0, 0.7 },
}
local function colorForState(state)
  return DEFAULT_PULL_COLORS[state] or DEFAULT_PULL_COLORS[PullState.UPCOMING]
end

-- Dots for mobs the route doesn't touch at all — dim/neutral regardless of
-- any pull's color so they read as "leave these" rather than as a pull.
local SKIP_COLOR = { 0.4, 0.42, 0.47, 0.55 }

local DOT_SIZE = 7
local BOSS_DOT_SIZE = 11
local HALO_RADIUS = 18   -- world units: padding disc around each clone so the hull wraps with slack
local HALO_SEGMENTS = 10 -- points sampled around each halo; more = rounder outline
local OUTLINE_THICKNESS = 2

-- Bloodlust pulls get a glow ring in addition to their normal state-colored
-- outline -- drawn as a second, thicker line underneath it (same vertices,
-- more thickness) so the state color still reads on top and the glow only
-- shows as a ring poking out either side. Red for this route's planned
-- pull(s), amber for wherever lust actually got cast this run (an emoji
-- lightning-bolt badge was tried for both originally, but WoW's UI font
-- doesn't have that glyph and rendered a blank box instead).
local LUST_PLANNED_COLOR = { 1, 0.30, 0.30 }
local LUST_ACTUAL_COLOR = { 1, 0.84, 0.42 }
local LUST_GLOW_EXTRA_THICKNESS = 5

---Draws a glow ring for one pull's hull: same vertices as its main outline,
---just thicker and pooled separately so it renders underneath (lower
---sublevel) rather than replacing the state-colored line.
local function drawGlowRing(container, pool, pullIndex, hull, hullSize, scale, color)
  local lines = pool[pullIndex]
  if not lines then
    lines = {}
    pool[pullIndex] = lines
  end
  for i = 1, hullSize do
    local line = lines[i]
    if not line then
      line = container:CreateLine(nil, "OVERLAY", nil, -2)
      lines[i] = line
    end
    line:SetThickness(OUTLINE_THICKNESS + LUST_GLOW_EXTRA_THICKNESS)
    line:SetColorTexture(color[1], color[2], color[3], 0.85)
    local va, vb = hull[i], hull[(i % hullSize) + 1]
    line:ClearAllPoints()
    line:SetStartPoint("TOPLEFT", container, va[1] * scale, va[2] * scale)
    line:SetEndPoint("TOPLEFT", container, vb[1] * scale, vb[2] * scale)
    line:Show()
  end
end

---Andrew's monotone chain convex hull (ported from MythicDungeonTools_NextPullTracker's
---BeaconMinimap.lua, itself the same technique MythicDungeonTools' own
---Modules/PullOutlines.lua uses for pull grouping). Points are {x, y} pairs;
---returns hull vertices in order, stripping collinear points.
local function convexHull(points)
  local n = #points
  if n < 3 then return points end

  table.sort(points, function(a, b)
    if a[1] ~= b[1] then return a[1] < b[1] end
    return a[2] < b[2]
  end)

  local function cross(o, a, b)
    return (a[1] - o[1]) * (b[2] - o[2]) - (a[2] - o[2]) * (b[1] - o[1])
  end

  local hull = {}
  for i = 1, n do
    while #hull >= 2 and cross(hull[#hull - 1], hull[#hull], points[i]) <= 0 do
      hull[#hull] = nil
    end
    hull[#hull + 1] = points[i]
  end

  local lowerSize = #hull + 1
  for i = n - 1, 1, -1 do
    while #hull >= lowerSize and cross(hull[#hull - 1], hull[#hull], points[i]) <= 0 do
      hull[#hull] = nil
    end
    hull[#hull + 1] = points[i]
  end

  hull[#hull] = nil -- last point == first point (start of lower chain), drop the dupe
  return hull
end

---Pads each position by a ring of points at HALO_RADIUS so even a 1-2 clone
---pull hulls into a rounded blob instead of degenerating to a line/point.
local function haloPoints(positions)
  local points = {}
  for _, pos in ipairs(positions) do
    for s = 0, HALO_SEGMENTS - 1 do
      local angle = (s / HALO_SEGMENTS) * 2 * math.pi
      points[#points + 1] = { pos[1] + math.cos(angle) * HALO_RADIUS, pos[2] + math.sin(angle) * HALO_RADIUS }
    end
  end
  return points
end

local function centroidOf(positions)
  local sx, sy = 0, 0
  for _, pos in ipairs(positions) do
    sx = sx + pos[1]
    sy = sy + pos[2]
  end
  local n = #positions
  return sx / n, sy / n
end

---For every pull, collects the {x, y, isBoss} of each of its clones that's on
---`sublevel`, keyed by pullIndex (pulls with nothing on this floor are
---omitted). Also returns a set of "enemyIndex_cloneIndex" keys so the caller
---can tell which clones are spoken for and which are left to the route.
local function collectPullClones(pulls, enemies, sublevel)
  local byPull = {}
  local claimed = {}
  for pullIndex, pull in ipairs(pulls) do
    local clonesHere = {}
    for enemyIndex, cloneIndices in pairs(pull) do
      local idx = tonumber(enemyIndex)
      local enemyData = idx and enemies[idx]
      if enemyData and enemyData.clones then
        for _, cloneIndex in ipairs(cloneIndices) do
          local clone = enemyData.clones[cloneIndex]
          if clone and (clone.sublevel == sublevel or not clone.sublevel) then
            clonesHere[#clonesHere + 1] = { clone.x, clone.y, isBoss = enemyData.isBoss }
            claimed[idx.."_"..cloneIndex] = true
          end
        end
      end
    end
    if #clonesHere > 0 then
      byPull[pullIndex] = clonesHere
    end
  end
  return byPull, claimed
end

---Every clone on `sublevel` the route never assigns to a pull — mobs the
---planned route means to skip.
local function collectSkipClones(enemies, sublevel, claimed)
  local skips = {}
  for enemyIndex, enemyData in pairs(enemies) do
    if enemyData.clones then
      for cloneIndex, clone in pairs(enemyData.clones) do
        if (clone.sublevel == sublevel or not clone.sublevel) and not claimed[enemyIndex.."_"..cloneIndex] then
          skips[#skips + 1] = { clone.x, clone.y, isBoss = enemyData.isBoss }
        end
      end
    end
  end
  return skips
end

local function styleDot(dot, r, g, b, a, isBoss)
  if isBoss then
    dot:SetTexture("Interface\\AddOns\\MythicDungeonTools\\Textures\\Square_White")
    dot:SetRotation(math.rad(45))
    dot:SetSize(BOSS_DOT_SIZE, BOSS_DOT_SIZE)
  else
    dot:SetTexture("Interface\\AddOns\\MythicDungeonTools\\Textures\\Circle_White")
    dot:SetRotation(0)
    dot:SetSize(DOT_SIZE, DOT_SIZE)
  end
  dot:SetVertexColor(r, g, b, a)
end

local function getDot(container, dots, dotIndex)
  local dot = dots[dotIndex]
  if not dot then
    dot = container:CreateTexture(nil, "OVERLAY", nil, 0)
    dots[dotIndex] = dot
  end
  return dot
end

---Draws the full mob layout for the current floor: an MDT-style convex-hull
---outline + centered pull number per pull (ported from NPT's BeaconMinimap,
---which itself mirrors MythicDungeonTools' own Modules/PullOutlines.lua
---technique), a small dot per clone assigned to a pull (colored by that
---pull's state, diamond-shaped for bosses), and dimmed dots for clones the
---route leaves alone. `lustPullIndex` (optional) glows whichever pull's hull
---that bloodlust actually landed on, in amber. `plannedLustPulls` (optional,
---a pullIndex -> true set) glows this route's planned lust pull(s) in red,
---and its number becomes clickable (`onPullClick(pullIndex, buttonFrame)`,
---optional) so the caller can pop a menu to mark/unmark it.
local function update(container, markers, pulls, enemies, sublevel, pullStates, scale, lustPullIndex, plannedLustPulls, onPullClick)
  markers.dots = markers.dots or {}
  markers.hullLines = markers.hullLines or {}
  markers.plannedGlowLines = markers.plannedGlowLines or {}
  markers.actualGlowLines = markers.actualGlowLines or {}
  markers.hullLabels = markers.hullLabels or {}
  markers.clickTargets = markers.clickTargets or {}

  local dots, hullLines, plannedGlowLines, actualGlowLines, hullLabels, clickTargets =
    markers.dots, markers.hullLines, markers.plannedGlowLines, markers.actualGlowLines, markers.hullLabels,
    markers.clickTargets

  for _, dot in ipairs(dots) do dot:Hide() end
  for _, lines in pairs(hullLines) do
    for _, line in ipairs(lines) do line:Hide() end
  end
  for _, lines in pairs(plannedGlowLines) do
    for _, line in ipairs(lines) do line:Hide() end
  end
  for _, lines in pairs(actualGlowLines) do
    for _, line in ipairs(lines) do line:Hide() end
  end
  for _, label in pairs(hullLabels) do label:Hide() end
  for _, target in pairs(clickTargets) do target:Hide() end

  if not pulls or not enemies then return end

  local pullClones, claimed = collectPullClones(pulls, enemies, sublevel)
  local skipClones = collectSkipClones(enemies, sublevel, claimed)

  -- Pass 1: hull outline + centroid pull-number label per pull, drawn first
  -- (lower draw-layer sublevel) so the per-clone dots layer visibly above them.
  for pullIndex, positions in pairs(pullClones) do
    local state = pullStates and pullStates[pullIndex] or PullState.UPCOMING
    local color = colorForState(state)
    local isCurrent = state == PullState.ACTIVE or state == PullState.NEXT

    local hull = convexHull(haloPoints(positions))
    local hullSize = #hull

    local lines = hullLines[pullIndex]
    if not lines then
      lines = {}
      hullLines[pullIndex] = lines
    end

    if hullSize >= 3 then
      local isPlanned = plannedLustPulls and plannedLustPulls[pullIndex]

      if isPlanned then
        drawGlowRing(container, plannedGlowLines, pullIndex, hull, hullSize, scale, LUST_PLANNED_COLOR)
      end
      if pullIndex == lustPullIndex then
        drawGlowRing(container, actualGlowLines, pullIndex, hull, hullSize, scale, LUST_ACTUAL_COLOR)
      end

      local strokeAlpha = (color[4] or 1) * (isCurrent and 1 or 0.55)
      for i = 1, hullSize do
        local line = lines[i]
        if not line then
          line = container:CreateLine(nil, "OVERLAY", nil, -1)
          line:SetThickness(OUTLINE_THICKNESS)
          lines[i] = line
        end
        line:SetColorTexture(color[1], color[2], color[3], strokeAlpha)
        local va, vb = hull[i], hull[(i % hullSize) + 1]
        line:ClearAllPoints()
        line:SetStartPoint("TOPLEFT", container, va[1] * scale, va[2] * scale)
        line:SetEndPoint("TOPLEFT", container, vb[1] * scale, vb[2] * scale)
        line:Show()
      end

      local cx, cy = centroidOf(positions)
      local label = hullLabels[pullIndex]
      if not label then
        label = container:CreateFontString(nil, "OVERLAY", nil)
        label:SetDrawLayer("OVERLAY", 1)
        -- Plain small fonts wash out against a cluster of same-colored dots;
        -- OUTLINE gives every digit a dark border so it reads at any zoom.
        label:SetFont("Fonts\\FRIZQT__.ttf", 13, "OUTLINE")
        label:SetTextColor(1, 1, 1, 1)
        hullLabels[pullIndex] = label
      end
      label:SetText(tostring(pullIndex))
      label:ClearAllPoints()
      label:SetPoint("CENTER", container, "TOPLEFT", cx * scale, cy * scale)
      label:SetAlpha(isCurrent and 1 or 0.75)
      label:Show()

      if onPullClick then
        local clickTarget = clickTargets[pullIndex]
        if not clickTarget then
          clickTarget = CreateFrame("Button", nil, container)
          clickTarget:SetSize(22, 22)
          clickTarget:RegisterForClicks("AnyUp")
          clickTargets[pullIndex] = clickTarget
        end
        clickTarget:SetScript("OnClick", function(self) onPullClick(pullIndex, self) end)
        clickTarget:ClearAllPoints()
        clickTarget:SetPoint("CENTER", container, "TOPLEFT", cx * scale, cy * scale)
        clickTarget:Show()
      end
    end
  end

  -- Pass 2: per-clone dots, pull-assigned first (colored by pull state),
  -- then unrouted "skip" clones (dimmed neutral), boss clones as diamonds.
  local dotIndex = 0
  for pullIndex, positions in pairs(pullClones) do
    local state = pullStates and pullStates[pullIndex] or PullState.UPCOMING
    local color = colorForState(state)
    for _, pos in ipairs(positions) do
      dotIndex = dotIndex + 1
      local dot = getDot(container, dots, dotIndex)
      styleDot(dot, color[1], color[2], color[3], color[4] or 1, pos.isBoss)
      dot:ClearAllPoints()
      dot:SetPoint("CENTER", container, "TOPLEFT", pos[1] * scale, pos[2] * scale)
      dot:Show()
    end
  end
  for _, pos in ipairs(skipClones) do
    dotIndex = dotIndex + 1
    local dot = getDot(container, dots, dotIndex)
    styleDot(dot, SKIP_COLOR[1], SKIP_COLOR[2], SKIP_COLOR[3], SKIP_COLOR[4], pos.isBoss)
    dot:ClearAllPoints()
    dot:SetPoint("CENTER", container, "TOPLEFT", pos[1] * scale, pos[2] * scale)
    dot:Show()
  end
end

FTD.PullMarkers = {
  convexHull = convexHull,
  haloPoints = haloPoints,
  centroidOf = centroidOf,
  colorForState = colorForState,
  update = update,
  DEFAULT_PULL_COLORS = DEFAULT_PULL_COLORS,
}
