local FTD = FTD
local MDT = FTD.MDT
local L = FTD.L

---Opens a context menu (anchored to `owner`) listing every dungeon MDT ships.
---Picking one calls `onSelect(dungeonIndex)`.
local function openDungeonMenu(owner, onSelect)
  local dungeons = MDT:ListDungeons()
  MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
    rootDescription:CreateTitle(L["Dungeon"])
    for _, entry in ipairs(dungeons) do
      rootDescription:CreateButton(entry.name, function() onSelect(entry.index) end)
    end
  end)
end

---Points the user at MDT's own route picker instead of offering one here --
---MDT's saved-preset bookkeeping isn't reliably enumerable from this addon's
---side, so rather than a switcher that sometimes can't find routes that are
---clearly loaded, this just says where to actually change one.
local function openRouteMenu(owner)
  MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
    rootDescription:CreateTitle(L["Route"])
    rootDescription:CreateTitle(L["Select route in MDT"])
  end)
end

---Opens a small context menu (anchored to `owner`) for one pull on the map,
---offering to mark/unmark it as one of this route's planned bloodlust pulls.
---A route can have more than one, so this is a plain toggle, not a picker.
local function openPullMenu(owner, pullIndex, isPlanned, onToggle)
  MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
    rootDescription:CreateTitle(L["Pull"].." "..pullIndex)
    local label = isPlanned and L["Clear Bloodlust Mark"] or L["Mark for Bloodlust"]
    rootDescription:CreateButton(label, onToggle)
  end)
end

FTD.DungeonSelector = {
  openDungeonMenu = openDungeonMenu,
  openRouteMenu = openRouteMenu,
  openPullMenu = openPullMenu,
}
