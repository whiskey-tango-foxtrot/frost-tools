local FTD = FTD
local select = select

---Gets scenario step info, trying both legacy C_Scenario and modern C_ScenarioInfo
---APIs. Ported from MythicDungeonTools_NextPullTracker's Utils/Wow.lua.
local function getScenarioStepInfo()
  if C_ScenarioInfo and C_ScenarioInfo.GetScenarioStepInfo then
    local info = C_ScenarioInfo.GetScenarioStepInfo()
    if info then return info.numCriteria or 0 end
  end
  if C_Scenario and C_Scenario.GetStepInfo then
    return select(3, C_Scenario.GetStepInfo()) or 0
  end
  return 0
end

---Gets criteria info, trying modern then legacy APIs.
local function getScenarioCriteriaInfo(index)
  if C_ScenarioInfo and C_ScenarioInfo.GetCriteriaInfo then
    return C_ScenarioInfo.GetCriteriaInfo(index)
  end
  if C_Scenario and C_Scenario.GetCriteriaInfo then
    return C_Scenario.GetCriteriaInfo(index)
  end
  return nil
end

FTD.Wow = {
  getScenarioStepInfo = getScenarioStepInfo,
  getScenarioCriteriaInfo = getScenarioCriteriaInfo,
}
