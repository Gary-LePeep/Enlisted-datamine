from "%enlSqGlob/ui_library.nut" import *

let { pPointsBaseParams } = require("%enlist/meta/perks/perksPoints.nut")
let colorize = require("%ui/components/colorize.nut")
let { titleTxtColor, attentionTxtColor, smallPadding } = require("%enlSqGlob/ui/designConst.nut")
let { levelBlock } = require("%enlSqGlob/ui/soldiersUiComps.nut")
let { fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")

enum PerkState {
  LOCKED    // can not obtain
  UNLOCKED_PART  // obtained
  UNLOCKED_FULL  // obtained
  AVAILABLE // can obtain
  UNDEFINED // no soldier
}

const POINTS_SPENT = 6
const MAX_LEVEL = 5

// locked state is intentionally checked last
// for some legacy premium perk schemes may include 5th level perks for the 4th level soldiers
let stateForPerk = @(isLocked, points, unlocked)
  points == unlocked ? PerkState.UNLOCKED_FULL
    : unlocked > 0 ? PerkState.UNLOCKED_PART
    : isLocked ? PerkState.LOCKED
    : PerkState.AVAILABLE

let statForPerk = @(perkData) perkData?.cost.findindex(@(_) true) ?? ""

let priceForPerk = function(perkData) {
  let stat = statForPerk(perkData)
  return perkData?.cost[stat] ?? 0
}

let hasEnoughPoints = function(pointInfo, perkData) {
  let stat = statForPerk(perkData)
  return (perkData?.cost[stat] ?? 0) + (pointInfo.used?[stat] ?? 0) <= pointInfo.total[stat]
}

let statIconForPerk = @(perkData)
  pPointsBaseParams?[statForPerk(perkData)] ?? {
    icon = "remove"
    color = Color(80,80,80)
  }

let iconForPerk = @(perkData) perkData.perkId.startswith("starter_")
  ? statIconForPerk(perkData)
  : {
      icon = $"ui/skin#perks/{perkData.perkId}_icon.svg"
      color = pPointsBaseParams?[statForPerk(perkData)].color ?? Color(80,80,80)
    }

let mkHeaderText = @(text) {
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  text
  color = titleTxtColor
}.__update(fontSub)

let requiredLevelHeader = {
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  gap = smallPadding
  children = [
    mkHeaderText(loc("perks/soldier"))
    levelBlock({level = MAX_LEVEL, maxLevel = MAX_LEVEL})
  ]
}

let thirdTierHint = loc("perks/obtain/tier3/hint", { level = colorize(titleTxtColor,
  loc("perks/level", { level = MAX_LEVEL }))
})

let tiersAvailable = function(level, used, showAll = false) {
  let usedPoints = used.reduce(@(sum, val) sum + val, 0)
  let pointsToSpend = POINTS_SPENT - usedPoints
  let hasSecondTier = showAll || usedPoints >= POINTS_SPENT
  let pointsLoc =  loc("perks/points", { count = pointsToSpend })
  let secondTierCondition = mkHeaderText(loc("perks/obtain/tier2",
    { points = colorize(attentionTxtColor, pointsLoc) }))
  let secondTierHint = loc("perks/obtain/tier2/hint",
    { points = colorize(titleTxtColor, pointsLoc) })
  return {
    [1] = { available = true },
    [2] = {
      available = hasSecondTier
      header = secondTierCondition
      hint = secondTierHint
    },
    [3] = {
      available = hasSecondTier && (showAll || level >= MAX_LEVEL)
      header = hasSecondTier ? requiredLevelHeader : secondTierCondition
      hint = hasSecondTier ? thirdTierHint : secondTierHint
    }
  }
}

let treeIdForSoldier = function(perkTreeCfg, perkTreesSpecial, soldier) {
  let className = perkTreesSpecial?[soldier?.sClass ?? ""] ?? soldier?.sKind
  return className in perkTreeCfg ? className : "common"
}

let treeForSoldier = @(perkTreeCfg, perkTreesSpecial, soldier)
  perkTreeCfg[treeIdForSoldier(perkTreeCfg, perkTreesSpecial, soldier)]

let function getPerkPointsInfo(perkListVal, soldierPerks, exclude = {}) {
  let res = {
    used = {}
    total = { speed = 0, vitality = 0, weapon = 0 }
    bonus = {}
  }

  if (soldierPerks?.points == null)
    return res

  res.total = clone soldierPerks.points

  foreach (perkId, count in soldierPerks.perks) {
    let perkCfg = perkListVal?[perkId]
    if (perkCfg == null || perkId in exclude)
      continue
    // starter perk has cost = 0, available = null
    let statId = statForPerk(perkCfg)
    res.used[statId] <- (res.used?[statId] ?? 0)
      + (perkCfg?.cost[statId] ?? 0) * min(count, perkCfg?.available ?? 1)
  }

  return res
}

let function canDiscardPerk(perkListVal, soldierPerks, perkData) {
  if (perkData.tier > 1)
    return true

  let exclude = {}
  foreach (perkId, _ in soldierPerks.perks) {
    if ((perkListVal?[perkId].tier ?? 1) > 1)
      exclude[perkId] <- true
  }
  if (exclude.len() == 0)
    return true

  let info = getPerkPointsInfo(perkListVal, soldierPerks, exclude)
  let usedPoints = info.used.reduce(@(sum, val) sum + val, 0)
  return (usedPoints - priceForPerk(perkData) >= POINTS_SPENT)
}

return {
  PerkState
  priceForPerk
  statForPerk
  iconForPerk
  statIconForPerk
  stateForPerk
  hasEnoughPoints
  tiersAvailable
  treeForSoldier
  treeIdForSoldier
  getPerkPointsInfo
  canDiscardPerk
  MAX_LEVEL
}
