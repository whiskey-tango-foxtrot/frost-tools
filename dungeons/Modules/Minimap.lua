local FTD = FTD
local L = FTD.L

-- Unlike .blp/.tga, a .png path needs its extension spelled out — WoW's
-- extension-guessing fallback doesn't cover it (see MapWidget.lua's own PNG
-- paths, which do the same).
local ICON_PATH = "Interface\\AddOns\\Frost_Tools_Dungeons\\Textures\\MinimapIcon.png"

local ldb = LibStub("LibDataBroker-1.1"):NewDataObject("FrostToolsDungeons", {
  type = "launcher",
  text = "Frost Tools: Dungeons",
  icon = ICON_PATH,
  OnClick = function(_, button)
    if button == "LeftButton" then
      if FTD.LayoutManager then FTD.LayoutManager.Toggle() end
    elseif button == "RightButton" then
      if FTD.Settings then FTD.Settings:Open() end
    end
  end,
  OnTooltipShow = function(tooltip)
    tooltip:AddLine(L["Frost Tools: Dungeons"])
    tooltip:AddLine("|cFFFFFFFF"..L["Left-click"]..":|r "..L["Toggle the map window"])
    tooltip:AddLine("|cFFFFFFFF"..L["Right-click"]..":|r "..L["Open settings"])
  end,
})

---Registers the minimap button. Call once `FTD:GetDB()` is available.
local function init()
  local db = FTD:GetDB()
  if not db then return end
  db.minimap = db.minimap or { hide = false }
  LibStub("LibDBIcon-1.0"):Register("FrostToolsDungeons", ldb, db.minimap)
end

local function setShown(shown)
  local icon = LibStub("LibDBIcon-1.0")
  if shown then icon:Show("FrostToolsDungeons") else icon:Hide("FrostToolsDungeons") end
  local db = FTD:GetDB()
  if db and db.minimap then db.minimap.hide = not shown end
end

FTD.Minimap = {
  ICON_PATH = ICON_PATH,
  init = init,
  setShown = setShown,
}
