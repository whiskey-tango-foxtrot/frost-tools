local FTD = FTD

local function parseNum(value)
  if type(value) == "number" then return value end
  if type(value) == "string" then
    local n = tonumber(value:match("(%d+%.?%d*)"))
    return n or 0
  end
  return 0
end

---Formats whole seconds as "m:ss". Returns nil for zero/negative (i.e. "not counting down").
local function formatCountdown(remainingSeconds)
  if not remainingSeconds or remainingSeconds <= 0 then return nil end
  remainingSeconds = math.floor(remainingSeconds + 0.5)
  local m = math.floor(remainingSeconds / 60)
  local s = remainingSeconds % 60
  return string.format("%d:%02d", m, s)
end

---Clamps `value` into [lo, hi].
local function clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

FTD.Utils = {
  parseNum = parseNum,
  formatCountdown = formatCountdown,
  clamp = clamp,
}
