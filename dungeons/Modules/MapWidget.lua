local FTD = FTD
local MDT = FTD.MDT
local pairs, type = pairs, type

local GRID_COLS = 15
local GRID_ROWS = 10
local BASE_TILE = 840 / GRID_COLS -- 56 world units per tile, matches MDT's own coordinate space

---Builds a self-contained "dungeon floor" display: a clipped viewport sized
---`width`x`height`, filled by a 15x10 tile grid scaled to fit inside it
---(whole floor always visible, letterboxed on whichever axis has slack),
---plus a content frame pull markers can anchor to. Returns a widget table —
---callers use its fields/methods rather than reaching into internals, so the
---single-window and split-window layouts can each own an independent one.
---
---`widget.scale` reflects the *current* fit scale — read it fresh each
---render rather than caching it, since `resize()` changes it in place.
local function create(parent, width, height)
  local widget = { markers = {} }

  local viewport = CreateFrame("Frame", nil, parent)
  viewport:SetClipsChildren(true)
  local bg = viewport:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.02, 0.02, 0.02, 1)

  local content = CreateFrame("Frame", nil, viewport)
  content:SetPoint("CENTER", viewport, "CENTER", 0, 0)

  local tiles = {}
  for i = 1, GRID_ROWS do
    for j = 1, GRID_COLS do
      local tileIndex = (i - 1) * GRID_COLS + j
      tiles[tileIndex] = content:CreateTexture(nil, "ARTWORK")
      tiles[tileIndex]:Hide()
    end
  end

  ---(Re)lays out the viewport/content/tiles for `width`x`height`, recomputing
  ---the fit scale. Existing tile textures are kept (SetTexture persists), only
  ---geometry changes — cheap enough to call live during a resize drag.
  local function resize(newWidth, newHeight)
    viewport:SetSize(newWidth, newHeight)
    local scale = math.min(newWidth / (GRID_COLS * BASE_TILE), newHeight / (GRID_ROWS * BASE_TILE))
    local tileSize = BASE_TILE * scale
    content:SetSize(GRID_COLS * tileSize, GRID_ROWS * tileSize)
    for i = 1, GRID_ROWS do
      for j = 1, GRID_COLS do
        local tile = tiles[(i - 1) * GRID_COLS + j]
        tile:SetSize(tileSize, tileSize)
        tile:ClearAllPoints()
        tile:SetPoint("TOPLEFT", content, "TOPLEFT", (j - 1) * tileSize, -(i - 1) * tileSize)
      end
    end
    widget.scale = scale
  end

  local function hideAllTiles()
    for _, tile in pairs(tiles) do tile:Hide() end
  end

  ---Loads dungeon map textures into the grid tiles for `dungeonIndex`/`sublevel`.
  local function loadTextures(dungeonIndex, sublevel)
    local dungeonMaps = MDT.dungeonMaps and MDT.dungeonMaps[dungeonIndex]
    if not dungeonMaps then hideAllTiles() return end
    local textureInfo = dungeonMaps[sublevel] or dungeonMaps[1]
    if not textureInfo then hideAllTiles() return end

    for i = 1, GRID_ROWS do
      for j = 1, GRID_COLS do
        local tileIndex = (i - 1) * GRID_COLS + j
        local tile = tiles[tileIndex]
        if tile then
          local textureName
          if type(textureInfo) == "string" then
            local mapName = MDT.mapInfo[dungeonIndex] and MDT.mapInfo[dungeonIndex].englishName or ""
            textureName = "Interface\\WorldMap\\"..mapName.."\\"..textureInfo..tileIndex
          elseif type(textureInfo) == "table" and textureInfo.customTextures then
            textureName = textureInfo.customTextures.."\\"..(sublevel or 1).."_"..tileIndex..".png"
          end
          if textureName then
            tile:SetTexture(textureName)
            tile:Show()
          else
            tile:Hide()
          end
        end
      end
    end
  end

  widget.viewport = viewport
  widget.content = content
  widget.resize = resize
  widget.loadTextures = loadTextures

  resize(width, height)
  return widget
end

FTD.MapWidget = {
  create = create,
  GRID_COLS = GRID_COLS,
  GRID_ROWS = GRID_ROWS,
  BASE_TILE = BASE_TILE,
}
