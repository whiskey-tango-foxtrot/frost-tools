local AddonName, FTD = ...
_G["FTD"] = FTD
FTD.L = {}

FTD.PullState = {
  COMPLETED = "completed",
  ACTIVE    = "active",
  NEXT      = "next",
  UPCOMING  = "upcoming",
}
