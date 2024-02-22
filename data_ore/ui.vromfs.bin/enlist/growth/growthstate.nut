from "%enlSqGlob/ui/ui_library.nut" import *

let { configs } = require("%enlist/meta/configs.nut")
let { growthState, growthProgress } = require("%enlist/meta/servProfile.nut")
let {
  growth_select, growth_select_forced, growth_purchase, growth_reward_take_forced,
  growth_state_set, growth_tier_set, growth_use_army_exp, growth_buy_exp,
  growth_army_unlock, growth_reset
} = require("%enlist/meta/clientApi.nut")
let { armies, curArmy } = require("%enlist/soldiers/model/state.nut")
let { squadsCfgById } = require("%enlist/soldiers/model/config/squadsConfig.nut")
let { allItemTemplates } = require("%enlist/soldiers/model/all_items_templates.nut")


enum GrowthStatus {
  UNAVAILABLE = 0
  ACTIVE = 1
  COMPLETED = 2
  PURCHASABLE = 3
  REWARDED = 4
}

let isGrowthVisible = Watched(false)
let curGrowthId = Watched(null)
let reqGrowthId = Watched(null)
let growthTierToScroll = Watched(null)
let defaultTier = freeze({ index = 0, from = 0, to = 0, required = 1 })

let growthConfig = Computed(@() configs.value?.growthConfig ?? {})

let growthSquadsByArmy = Computed(@()
  growthConfig.value.map(function(growths) {
    let res = {}
    foreach (growth in growths) {
      let { id, reward } = growth
      let { squadId = null } = reward
      if (squadId != null)
        res[squadId] <- id
    }
    return res
  }))

let curGrowthConfig = Computed(@() growthConfig.value?[curArmy.value] ?? {})
let curGrowthByItem = Computed(function() {
  let growthByItem = curGrowthConfig.value.reduce(@(res, val)
    res.rawset(val.reward.itemTemplate, val.id), {})
  return growthByItem
})

let growthTiers = Computed(@() configs.value?.growthTiers
  .map(@(tiers) tiers.map(@(t) defaultTier.__merge(t))) ?? {})

let curGrowthTiers = Computed(@() growthTiers.value?[curArmy.value] ?? [])

let setCurGrowthTier = @(tier) growthTierToScroll(tier)

let mkGrowthData = @() Computed(function() {
  let growthRelations = curGrowthConfig.value.reduce(function(res, val, _, tbl) {
    let { id, col = 0, line = 0, requirements = [] } = val
    if (requirements.len() > 0) {
      let ancestor = tbl[requirements[0]]
      if (col == (ancestor?.col ?? 0) && line == (ancestor?.line ?? 0)) {
        let ancestorRelations = res?[ancestor.id] ?? [ancestor.id]
        let inheritorRelations = res?[id] ?? [id]
        ancestorRelations.extend(inheritorRelations)
        res[ancestor.id] <- ancestorRelations
        foreach(updateId in inheritorRelations)
          res[updateId] <- ancestorRelations
      }
    }
    return res
  }, {})

  let tiersByCol = {}
  foreach (tier in curGrowthTiers.value) {
    let tierData = { tierIdx = tier.index, tierId = tier.id }
    for (local i = tier.from; i <= tier.to; i++)
      tiersByCol[i] <- tierData
  }

  let growthLinks = {}
  foreach (growthId, growth in curGrowthConfig.value)
    growthLinks[growthId] <- { isPrem = (growth?.expRequired ?? 0) == 0 }
      .__update(tiersByCol[growth?.col ?? 0])

  return { growthRelations, growthLinks }
})


let curGrowthSelected = Computed(@() armies.value?[curArmy.value].growthSelected)
let curGrowthFreeExp = Computed(@() armies.value?[curArmy.value].growthExp ?? 0)

let curSquads = Computed(function() {
  let armyId = curArmy.value
  return squadsCfgById.value?[armyId] ?? {}
})
let curTemplates = Computed(@() allItemTemplates.value?[curArmy.value] ?? {})

function getGrowthBySquadId(armyId, squadId) {
  let configByArmy = growthConfig.value?[armyId] ?? {}
  return configByArmy.findvalue(@(g) g.reward?.squadId == squadId)
}

function getGrowthToFocus(armyId, researchData) {
  let { squadIdList = {} } = researchData
  let configByArmy = growthConfig.value?[armyId] ?? {}
  return configByArmy.findvalue(@(g) g.reward?.squadId in squadIdList)
}

function getSortedGrowthsByResearch(army, research) {
  let { squadIdList = {} } = research
  let sortedGrowths = squadIdList.keys()
    .map(@(squadId) getGrowthBySquadId(army, squadId))
    .filter(@(growth) growth != null)
    .sort(@(a, b) (a?.col ?? 0) <=> (b?.col ?? 0))
  return sortedGrowths
}

console_register_command(@(growthId) growth_select(curArmy.value, growthId),
  "meta.growthSelect")
console_register_command(@() growth_select_forced(curArmy.value, curGrowthId.value),
  "meta.growthSelectCurrent")
console_register_command(@() growth_reward_take_forced(curArmy.value, curGrowthId.value),
  "meta.growthTakeCurrent")
console_register_command(@(exp) growth_state_set(curArmy.value, curGrowthId.value, exp, -1),
  "meta.setCurGrowthExp")
  console_register_command(@(status) growth_state_set(curArmy.value, curGrowthId.value, -1, status),
  "meta.setCurGrowthStatus")
console_register_command(@(index, progress) growth_tier_set(curArmy.value, index, progress, -1),
  "meta.setGrowthTierProgress")
console_register_command(@(index, status) growth_tier_set(curArmy.value, index, -1, status),
  "meta.setGrowthTierStatus")
console_register_command(@() growth_army_unlock(curArmy.value), "meta.growthArmyUnlock")
console_register_command(@() growth_reset(), "meta.growthReset")

return {
  isGrowthVisible
  GrowthStatus
  curGrowthId
  reqGrowthId
  growthConfig
  curGrowthConfig
  curGrowthByItem
  curGrowthTiers
  curGrowthState = growthState
  curGrowthProgress = growthProgress
  curGrowthSelected
  curGrowthFreeExp
  curSquads
  curTemplates
  mkGrowthData
  setCurGrowthTier
  growthTierToScroll
  growthSquadsByArmy
  getGrowthToFocus
  getSortedGrowthsByResearch

  callGrowthExp = growth_use_army_exp
  callGrowthBuyExp = growth_buy_exp
  callGrowthSelect = growth_select
  callGrowthPurchase = growth_purchase
}
