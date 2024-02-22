from "%enlSqGlob/ui/ui_library.nut" import *

let { fontSub, fontawesome } = require("%enlSqGlob/ui/fontsStyle.nut")
let { doesLocTextExist } = require("dagor.localize")
let { setTooltip } = require("%ui/style/cursors.nut")
let tooltipBox = require("%ui/style/tooltipBox.nut")
let math = require("%sqstd/math.nut")
let {
  smallPadding, bigPadding, defTxtColor, msgHighlightedTxtColor
} = require("%enlSqGlob/ui/viewConst.nut")
let colors = require("%ui/style/colors.nut")
let {
  allItemTemplates, findItemTemplate
} = require("%enlist/soldiers/model/all_items_templates.nut")
let { getItemName } = require("%enlSqGlob/ui/itemsInfo.nut")
let colorize = require("%ui/components/colorize.nut")
let { pPointsBaseParams, pPointsList } = require("%enlist/meta/perks/perksPoints.nut")
let fa = require("%ui/components/fontawesome.map.nut")
let { soldierPerks } = require("%enlist/meta/servProfile.nut")
let sClassesCfg = require("%enlist/soldiers/model/config/sClassesConfig.nut")
let { MAX_LEVEL } = require("%enlist/meta/perks/perkTreePkg.nut")

let mkText = @(txt) {
  rendObj = ROBJ_TEXT
  text = txt
}.__update(fontSub)

let flexTextArea = @(params) {
  size = [flex(), SIZE_TO_CONTENT]
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  color = defTxtColor
  vplace = ALIGN_CENTER
  halign = ALIGN_LEFT
}.__update(fontSub, params)


let perkPointIcon = @(icon, color = defTxtColor, pPointSize = hdpxi(32)) {
  rendObj = ROBJ_IMAGE
  size = [pPointSize, pPointSize]
  image = Picture("{0}:{1}:{1}:K".subst(icon, pPointSize))
  color
}

let maxedStatIcon = @(color, fontSize = hdpxi(8)) {
  rendObj = ROBJ_INSCRIPTION
  validateStaticText = false
  text = fa["star"]
  font = fontawesome.font
  color
  fontSize
}

let maxStatAnimation = {
  transform = { scale = [0.25, 0.25], pivot = [0.5, 0.5] }
  animations = [{
      prop = AnimProp.scale, from = [0.25, 0.25], to = [1.0, 1.0],
      duration = 0.7, delay = 0.2, play = true, easing = CosineFull
    }]
  }

function getStatDescList(perkStatsTable, perk, isUnavailable = false) {
  let res = []
  let stats = perk?.stats ?? {}
  foreach (statId, statValue in stats) {
    let locId = $"stat/{statId}/desc"
    if (!doesLocTextExist(locId))
      continue
    let value = statValue * (perkStatsTable?[statId].base_power ?? 0.0)
    let statValueText = math.round_by_value(value, 0.1)
      + (perkStatsTable?[statId].power_type ?? "")
    res.append(loc(locId, {
      value = isUnavailable ? statValueText : colorize(colors.MsgMarkedText, statValueText)
    }))
  }
  return res
}

function getPerkItems(armyId, items) {
  let res = []
  foreach (itemTpl in items) {
    let item = findItemTemplate(allItemTemplates, armyId, itemTpl)
    if (item == null)
      continue

    res.append(colorize(colors.MsgMarkedText, getItemName(item)))
  }
  return res
}

let getPerkItemsText = @(armyId, items)
  items.len() == 0 ? ""
    : $" {loc("perks/itemsInfo", { items = ", ".join(getPerkItems(armyId, items)) })}"

let mkPerkDesc = @(perksStatsTable, armyId, perk, separator = ", ") "{0}{1}"
  .subst(separator.join(getStatDescList(perksStatsTable, perk)),
    getPerkItemsText(armyId, perk?.items ?? []))

let perkPointsInfoTooltip = {
  size = [hdpx(400), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  gap = smallPadding
  children = [
    mkText(loc("perkPointsTitle")).__update({ color = msgHighlightedTxtColor })
    flexTextArea({ text = loc("perkPointsDesc") })
  ]
}


function getPossibleStats(content, sClassesCfgVal) {
  let {
    soldierClasses, soldierTierMax, soldierTierMin, soldierRareMax,
    soldierRareMin, soldierHasMaxStats
  } = content
  let {
    pointsByTiers = [], perkPointsModifications = []
  } = sClassesCfgVal?[soldierClasses[0]] ?? {}

  let stats = {}
  let statsMax = pointsByTiers[min(soldierTierMax, pointsByTiers.len() - 1)]
  let maxRareModifications = min(soldierRareMax, perkPointsModifications.len() - 1)
  foreach (statId in pPointsList) {
    let maxVal = statsMax[statId].max
      + (perkPointsModifications[maxRareModifications]?[statId] ?? 0)
    stats[statId] <- {
      maxVal
      minVal = soldierHasMaxStats ? maxVal
        : pointsByTiers[soldierTierMin][statId].min +
          (perkPointsModifications[max(soldierRareMin, 0)]?[statId] ?? 0)
    }
  }
  return stats
}

function possibleStatsForSoldier(sClass, sTier, hasMaxStats, sClassesCfgVal) {
  let tier = min(sTier, MAX_LEVEL)
  let soldierParams = {
    soldierClasses = [sClass]
    soldierTierMax = tier
    soldierTierMin = tier
    soldierRareMax = 0
    soldierRareMin = 0
    soldierHasMaxStats = hasMaxStats
  }
  return getPossibleStats(soldierParams, sClassesCfgVal)
}

function mkPerksPointsBlock(soldier) {
  if (soldier?.guid == null)
    return null

  return function() {
    let res = { watch = [soldierPerks, sClassesCfg] }

    let { points = {}, sTier = 0 } = soldierPerks.value?[soldier.guid] ?? {}
    if (points.len() == 0)
      return res

    let { sClass, hasMaxStats } = soldier
    let statsForSoldier = possibleStatsForSoldier(sClass, sTier, hasMaxStats, sClassesCfg.value)

    let children = []
    foreach (pPointId, value in points) {
      if (pPointId not in pPointsBaseParams)
        continue

      let { icon, color } = pPointsBaseParams[pPointId]
      let maxedIcon = (statsForSoldier?[pPointId].maxVal ?? 0) != value ? null
        : {
            vplace = ALIGN_TOP
            valign = ALIGN_CENTER
            halign = ALIGN_CENTER
            pos = [smallPadding, bigPadding]
            size = [hdpxi(8), hdpxi(8)]
            children = maxedStatIcon(color, hdpx(32)).__update(maxStatAnimation)
          } // the star needs a container otherwise it takes up as much space as its largest size

      children.append(
        {
          rendObj = ROBJ_TEXT
          text = value
          color
        },
        maxedIcon,
        perkPointIcon(icon, color)
      )
    }

    return res.__update({
      behavior = Behaviors.Button
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      onHover = @(on) setTooltip(on ? tooltipBox(perkPointsInfoTooltip) : null)
      skipDirPadNav = true
      children
    })
  }
}

function hasStatsMaxed(soldier) {
  if (soldier?.itemtype != "soldier" || soldier?.guid == null)
    return false

  let { points = {}, sTier = 0 } = soldierPerks.value?[soldier.guid] ?? {}
  if (points.len() == 0)
    return false

  let { sClass, hasMaxStats } = soldier
  let statsForSoldier = possibleStatsForSoldier(sClass, sTier, hasMaxStats, sClassesCfg.value)

  foreach (pPointId, value in points) {
    if (value != (statsForSoldier?[pPointId].maxVal ?? 0))
      return false
  }
  return true
}

function statsRange(statsTable, stat, isLocked) {
  let { icon, color } = pPointsBaseParams[stat]
  let { minVal, maxVal } = statsTable[stat]
  return {
    flow = FLOW_HORIZONTAL
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = [
      perkPointIcon(icon, isLocked ? defTxtColor : color)
      {
        rendObj = ROBJ_TEXT
        color = defTxtColor
        text = minVal == maxVal ? maxVal : $"{minVal}-{maxVal}"
      }
    ]
  }
}

function mkStatList(content, sClassesCfgVal, isLocked = false) {
  let stats = getPossibleStats(content, sClassesCfgVal)
  return {
    flow = FLOW_HORIZONTAL
    halign = ALIGN_LEFT
    size = [SIZE_TO_CONTENT, hdpx(32)]
    gap = bigPadding
    children = pPointsList.map(@(x) statsRange(stats, x, isLocked))
  }
}

return {
  flexTextArea
  getStatDescList
  perkPointIcon
  mkPerksPointsBlock
  mkPerkDesc
  mkStatList
  possibleStatsForSoldier
  maxedStatIcon
  hasStatsMaxed
}
