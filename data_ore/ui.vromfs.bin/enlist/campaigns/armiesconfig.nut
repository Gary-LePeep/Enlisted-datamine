from "%enlSqGlob/ui/ui_library.nut" import *

let { configs } = require("%enlist/meta/configs.nut")
let serverTime = require("%enlSqGlob/userstats/serverTime.nut")
let { curCampaignConfig } = require("%enlist/meta/curCampaign.nut")
let { allArmiesInfo } = require("%enlist/soldiers/model/config/gameProfile.nut")

let curMaxLevel = Computed(@() curCampaignConfig.value?.maxLevel ?? 0)

let armyLevelsData = Computed(function() {
  let maxLevel = curMaxLevel.value
  let { army_levels_data = [] } = configs.value
  return maxLevel > 0
    ? army_levels_data.slice(0, maxLevel)
    : army_levels_data
})

let armiesUnlocks = Computed(@() configs.value?.armies_unlocks ?? [])

let armiesRewards = Computed(@()
  armiesUnlocks.value.reduce(function(res, u) {
    let rewardId = u?.rewardInfo.rewardId ?? ""
    if (rewardId == "")
      return res
    let { armyId } = u
    if (armyId not in res)
      res[armyId] <- {}
    if (rewardId not in res[armyId])
      res[armyId][rewardId] <- []
    res[armyId][rewardId].append(u.level)
    return res
  }, {}))

let armyLevelDiscount = Computed(@() configs.value?.army_levels_discount ?? [])
let curLevelDiscount = Watched(0)
let hasLevelDiscount = Computed(@() curLevelDiscount.value > 0)

function prepareDiscount() {
  let ts = serverTime.value
  local maxDiscount = 0
  local tsClosest = 0
  foreach (discountItem in armyLevelDiscount.value) {
    let { discountInPercent, tsFrom, tsTo } = discountItem
    if (tsFrom < ts && ts < tsTo)
      maxDiscount = max(maxDiscount, discountInPercent)
    if (ts < tsFrom)
      tsClosest = tsClosest == 0 ? tsFrom : min(tsClosest, tsFrom)
    if (ts < tsTo)
      tsClosest = tsClosest == 0 ? tsTo : min(tsClosest, tsTo)
  }
  curLevelDiscount(maxDiscount)
  if (tsClosest > ts)
    gui_scene.setTimeout(tsClosest - ts, prepareDiscount)
}

prepareDiscount()
armyLevelDiscount.subscribe(function(_) {
  gui_scene.clearTimer(prepareDiscount)
  prepareDiscount()
})

console_register_command(@(val)
  curLevelDiscount(type(val) == "integer" ? val : 0), "meta.setArmyLevelDiscount")

let getArmyName = @(armyId) loc($"country/{allArmiesInfo.value[armyId].country}")

return {
  armyLevelsData
  armiesUnlocks
  armiesRewards

  curMaxLevel
  curLevelDiscount = Computed(@() curLevelDiscount.value)
  hasLevelDiscount

  getArmyName
}
