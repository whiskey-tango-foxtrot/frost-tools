local FTD = FTD
local L = FTD.L

local Settings_API = _G.Settings

local M = {}
FTD.Settings = M

local categoryRef

local function getDB() return FTD:GetDB() end

local function refreshMap()
  if FTD.LayoutManager then FTD.LayoutManager.Render() end
end

local function buildPanel()
  local category, layout = Settings_API.RegisterVerticalLayoutCategory(L["Frost Tools: Dungeons"])
  categoryRef = category

  layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["General"]))

  local layoutSetting = Settings_API.RegisterProxySetting(
    category, "FTD_LAYOUT_MODE", "string", L["Window Layout"], "single",
    function() return FTD.LayoutManager and FTD.LayoutManager.GetMode() or "single" end,
    function(value)
      if FTD.LayoutManager then FTD.LayoutManager.SetMode(value) end
    end
  )
  local function layoutOptions()
    local container = Settings_API.CreateControlTextContainer()
    container:Add("single", L["Single Window"])
    container:Add("split", L["Split Windows"])
    return container:GetData()
  end
  Settings_API.CreateDropdown(category, layoutSetting, layoutOptions,
    L["Single Window keeps the map, pull list, forces and bloodlust together. Split Windows makes each one its own independently movable and resizable window."])

  local autoOpenSetting = Settings_API.RegisterProxySetting(
    category, "FTD_AUTO_OPEN", "boolean", L["Auto Open"], true,
    function()
      local db = getDB()
      return db == nil or db.autoOpenEnabled ~= false
    end,
    function(value)
      local db = getDB()
      if db then db.autoOpenEnabled = value end
    end
  )
  Settings_API.CreateCheckbox(category, autoOpenSetting, L["Automatically open the window when you join a dungeon instance that has saved routes."])

  local autoCloseSetting = Settings_API.RegisterProxySetting(
    category, "FTD_AUTO_CLOSE", "boolean", L["Auto Close"], true,
    function()
      local db = getDB()
      return db == nil or db.autoCloseEnabled ~= false
    end,
    function(value)
      local db = getDB()
      if db then db.autoCloseEnabled = value end
    end
  )
  Settings_API.CreateCheckbox(category, autoCloseSetting, L["Automatically close the window when you leave the dungeon."])

  local warnSetting = Settings_API.RegisterProxySetting(
    category, "FTD_WARN_ENABLED", "boolean", L["Route Drift Warning"], true,
    function()
      local db = getDB()
      return db == nil or db.warnEnabled ~= false
    end,
    function(value)
      local db = getDB()
      if db then db.warnEnabled = value end
      refreshMap()
    end
  )
  Settings_API.CreateCheckbox(category, warnSetting, L["Show a banner when your kills drift from the planned route."])

  local thresholdSetting = Settings_API.RegisterProxySetting(
    category, "FTD_WARN_THRESHOLD", "number", L["Drift Threshold"], FTD.DeviationWarning.DEFAULT_THRESHOLD_PCT,
    function()
      local db = getDB()
      return (db and db.warnThresholdPct) or FTD.DeviationWarning.DEFAULT_THRESHOLD_PCT
    end,
    function(value)
      local db = getDB()
      if db then db.warnThresholdPct = value end
      refreshMap()
    end
  )
  local thresholdOptions = Settings_API.CreateSliderOptions(1, 20, 1)
  thresholdOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,
    function(value) return string.format("%d%%", value) end)
  Settings_API.CreateSlider(category, thresholdSetting, thresholdOptions,
    L["How far your forces % has to drift from plan before the banner appears."])

  local opacitySetting = Settings_API.RegisterProxySetting(
    category, "FTD_WINDOW_OPACITY", "number", L["Window Opacity"], 90,
    function()
      local db = getDB()
      return (db and db.windowOpacity) or 90
    end,
    function(value)
      local db = getDB()
      if db then db.windowOpacity = value end
      if FTD.LayoutManager then FTD.LayoutManager.ApplyOpacity() end
    end
  )
  local opacityOptions = Settings_API.CreateSliderOptions(20, 100, 5)
  opacityOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,
    function(value) return string.format("%d%%", value) end)
  Settings_API.CreateSlider(category, opacitySetting, opacityOptions,
    L["How see-through the map/pull/forces windows are."])

  local minimapSetting = Settings_API.RegisterProxySetting(
    category, "FTD_MINIMAP_SHOWN", "boolean", L["Show Minimap Icon"], true,
    function()
      local db = getDB()
      return db == nil or not (db.minimap and db.minimap.hide)
    end,
    function(value)
      if FTD.Minimap then FTD.Minimap.setShown(value) end
    end
  )
  Settings_API.CreateCheckbox(category, minimapSetting, L["Show or hide the minimap button."])

  Settings_API.RegisterAddOnCategory(category)
end

function M:Open()
  if not categoryRef then return end
  Settings_API.OpenToCategory(categoryRef:GetID())
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
  if Settings_API and Settings_API.RegisterVerticalLayoutCategory then
    buildPanel()
  end
  self:UnregisterAllEvents()
end)
