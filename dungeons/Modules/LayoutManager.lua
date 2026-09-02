local FTD = FTD

---Both layouts share one live tracking engine (via RenderContext/ForcesTracker);
---this just decides which set of frames is currently on screen, so Core.lua
---and Settings.lua have one thing to call regardless of which layout is active.

local function getDB() return FTD:GetDB() end

local function active()
  local db = getDB()
  if db and db.layoutMode == "split" then return FTD.SplitView end
  return FTD.MapView
end

local function Show() active():Show() end
local function Hide() active():Hide() end
local function Toggle() active():Toggle() end
local function Render() active():Render() end
local function Tick() active():Tick() end
local function IsShown() return active():IsShown() end

---Switches layouts live: hides whichever is showing, flips the saved mode,
---and shows the other one in the same state (open or not) if it was open.
local function SetMode(mode)
  local db = getDB()
  if not db or db.layoutMode == mode then return end

  local wasShown = IsShown()
  if wasShown then Hide() end
  db.layoutMode = mode
  if wasShown then Show() end
end

local function GetMode()
  local db = getDB()
  return (db and db.layoutMode) or "single"
end

---Applies the saved window opacity to both layouts (not just the active
---one), so switching layouts later doesn't need this re-applied.
local function ApplyOpacity()
  FTD.MapView.ApplyOpacity()
  FTD.SplitView.ApplyOpacity()
end

FTD.LayoutManager = {
  Show = Show,
  Hide = Hide,
  Toggle = Toggle,
  Render = Render,
  Tick = Tick,
  IsShown = IsShown,
  SetMode = SetMode,
  GetMode = GetMode,
  ApplyOpacity = ApplyOpacity,
}
