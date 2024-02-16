from "%enlSqGlob/ui_library.nut" import *

let perksList = require("%enlist/meta/perks/perksList.nut")
let { fontBody, fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let { withTooltip } = require("%ui/style/cursors.nut")
let { perksData } = require("%enlist/soldiers/model/soldierPerks.nut")
let armyEffects = require("%enlist/soldiers/model/armyEffects.nut")
let { getLinkedArmyName } = require("%enlSqGlob/ui/metalink.nut")
let {
  kindIcon, classIcon, levelBlock, experienceTooltip,
  classTooltip, mkSoldierMedalIcon, calcExperienceData
} = require("%enlSqGlob/ui/soldiersUiComps.nut")
let { gap, bigPadding, smallPadding, noteTxtColor, defTxtColor, msgHighlightedTxtColor
} = require("%enlSqGlob/ui/viewConst.nut")
let { panelBgColor } = require("%enlSqGlob/ui/designConst.nut")
let { getObjectName } = require("%enlSqGlob/ui/itemsInfo.nut")
let { mkSoldiersData } = require("%enlist/soldiers/model/curSoldiersState.nut")
let { campPresentation, needFreemiumStatus } = require("%enlist/campaigns/campaignConfig.nut")
let { perkLevelsGrid } = require("%enlist/meta/perks/perksExp.nut")
let { getClassCfg } = require("%enlSqGlob/ui/soldierClasses.nut")
let { getSoldierBR } = require("%enlist/soldiers/armySquadTier.nut")
let { mkBattleRating } = require("%enlSqGlob/ui/battleRatingPkg.nut")
let { getPerkPointsInfo } = require("%enlist/meta/perks/perkTreePkg.nut")
let { pPointsList, pPointsBaseParams } = require("%enlist/meta/perks/perksPoints.nut")


let hdrAnimations = [
  { prop = AnimProp.opacity, from = 0, to = 1, duration = 0.3, easing = OutCubic, trigger = "hdrAnim"}
  { prop = AnimProp.translate, from =[-hdpx(70), 0], to = [0, 0], duration = 0.15, easing = OutQuad, trigger = "hdrAnim"}
]

let mkClassBonus = @(classBonusWatch) function() {
  let res = { watch = classBonusWatch }
  let bonus = 100 * classBonusWatch.value
  if (bonus == 0)
    return res
  return withTooltip(res.__update({
      rendObj = ROBJ_TEXT
      color = msgHighlightedTxtColor
      text = loc("bonusExp/short", { value = $"+{bonus}" })
    }, fontSub),
    @() loc("tooltip/soldierExpBonus"))
}

let callnameBlock = @(callname) {
  size = [flex(), SIZE_TO_CONTENT]
  behavior = Behaviors.Marquee
  delay = 1
  speed = 50
  rendObj = ROBJ_TEXT
  text = callname
  color = noteTxtColor
}.__update(fontBody)

let nameField = function(soldierWatch) {
  return function(){
    let { callname = "" } = soldierWatch.value
    return {
      flow = FLOW_HORIZONTAL
      watch = soldierWatch
      size = [flex(2), SIZE_TO_CONTENT]
      gap
      children = [
        callname != "" ? callnameBlock(callname)
        : {
            size = [flex(), SIZE_TO_CONTENT]
            key = "soldierName_big"
            rendObj = ROBJ_TEXT
            text = getObjectName(soldierWatch.value)
            color = noteTxtColor
          }.__update(fontBody)
      ]
    }
  }
}

let levelBlockWithProgress = @(
  soldierWatch, perksWatch, _isFreemiumMode = false, _thresholdColor = 0, override = {}
) function() {
  let res = { watch = [soldierWatch, perksWatch, perkLevelsGrid] }
  let { guid = null, level = 1, maxLevel = 1 } = soldierWatch.value
  if (guid == null)
    return res
  let levelData = calcExperienceData(soldierWatch.value, perkLevelsGrid.value.expToLevel)
  let { exp, expToNextLevel } = levelData
  let expProgress = expToNextLevel > 0 ? 100.0 * exp / expToNextLevel : 0
  let isMaxed = maxLevel == level
  return withTooltip(res.__update({
      key = guid
      size = SIZE_TO_CONTENT
      flow = FLOW_VERTICAL
      halign = ALIGN_CENTER
      gap
      children = [
        levelBlock({
          level
          maxLevel
          fontSize = hdpx(14)
        }).__update({minWidth = hdpx(120), halign = ALIGN_CENTER})
        isMaxed ? null : {
          size = [flex(), hdpx(5)]
          minWidth = hdpx(120)
          children = [
            { size = flex(), rendObj = ROBJ_SOLID, color = Color(154, 158, 177) }
            { size = [pw(expProgress), flex()], rendObj = ROBJ_SOLID,  color = Color(47, 137, 211) }
          ]
        }
      ]
    }, override),
    @() experienceTooltip(levelData))
}

let mkSoldierNameSmall = @(soldier)
  (soldier?.callname ?? "") == "" ? null : {
    size = SIZE_TO_CONTENT
    key = "soldierName_small"
    rendObj = ROBJ_TEXT
    text = getObjectName(soldier)
    color = defTxtColor
    padding = [0, smallPadding * 2]
  }.__update(fontSub)


let iconSize = hdpxi(26)
let medalSize = hdpxi(24)

let function mkNameBlock(soldier) {
  let soldierWatch = mkSoldiersData(soldier)
  let perksWatch = Computed(@() clone perksData.value?[soldier.value?.guid])
  let classBonusWatch = Computed(function() {
    let soldierV = soldier.value
    if (soldierV == null)
      return 0
    return armyEffects.value?[getLinkedArmyName(soldierV)].class_xp_boost[soldierV.sClass] ?? 0
  })
  return function() {
    let {armyId = null, sClass = null, sKind = null, sClassRare = 0} = soldierWatch.value
    let medal = mkSoldierMedalIcon(soldierWatch.value, medalSize)
    let isPremium = getClassCfg(sClass)?.isPremium ?? false
    let classTooltipCb = @() classTooltip(armyId, sClass, sKind,
      mkBattleRating(getSoldierBR(soldierWatch.value.guid)))

    let function perkPointsUi() {
      let { total } = getPerkPointsInfo(perksList.value, perksWatch.value)
      return {
        watch = [perksList, perksWatch]
        flow = FLOW_HORIZONTAL
        gap = smallPadding
        margin = [0,0,0,bigPadding]
        children = pPointsList.map(function(statId) {
          let { icon } = pPointsBaseParams[statId]
          let totalPoints = total?[statId] ?? 0
          return {
            flow = FLOW_HORIZONTAL
            valign = ALIGN_CENTER
            children = [
              {
                rendObj = ROBJ_TEXT
                color = defTxtColor
                text = totalPoints
              }.__update(fontSub)
              {
                rendObj = ROBJ_IMAGE
                size = [iconSize, iconSize]
                image = Picture("{0}:{1}:{1}:K".subst(icon, iconSize))
                color = defTxtColor
              }
            ]
          }
        })
      }
    }

    return {
      watch = [soldierWatch, campPresentation, needFreemiumStatus]
      size = [flex(), hdpx(70)]
      animations = hdrAnimations
      transform = {}
      rendObj = ROBJ_SOLID
      color = panelBgColor
      children = [
        isPremium ? classIcon(armyId, sClass, iconSize) : null
        {
          size = flex()
          flow = FLOW_HORIZONTAL
          padding = [0, bigPadding]
          children = [
            {
              size = flex()
              flow = FLOW_VERTICAL
              children = [
                {
                  size = [flex(), ph(40)]
                  flow = FLOW_HORIZONTAL
                  gap
                  padding = [0, 0, 0, isPremium ? iconSize : 0]
                  valign = ALIGN_CENTER
                  children = [
                    withTooltip(kindIcon(sKind, medalSize, sClassRare), classTooltipCb)
                    perkPointsUi
                    mkSoldierNameSmall(soldierWatch.value)
                  ]
                }
                {
                  size = flex()
                  flow = FLOW_HORIZONTAL
                  gap
                  valign = ALIGN_CENTER
                  children = [
                    isPremium ? null : classIcon(armyId, sClass, hdpx(30))
                    nameField(soldierWatch)
                    medal == null ? null : withTooltip(medal, @() loc("hero/medal"))
                  ]
                }
              ]
            }
            {
              size = [SIZE_TO_CONTENT, flex()]
              flow = FLOW_VERTICAL
              halign = ALIGN_RIGHT
              children = [
                {
                  size = [SIZE_TO_CONTENT, ph(40)]
                  valign = ALIGN_CENTER
                  children = mkClassBonus(classBonusWatch)
                }
                {
                  size = [SIZE_TO_CONTENT, flex()]
                  valign = ALIGN_CENTER
                  children = levelBlockWithProgress(
                    soldierWatch,
                    perksWatch,
                    needFreemiumStatus.value,
                    campPresentation.value?.color
                  )
                }
              ]
            }
          ]
        }
      ]
    }
  }
}

return mkNameBlock