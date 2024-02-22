from "%enlSqGlob/ui/ui_library.nut" import *

let colorize = require("%ui/components/colorize.nut")
let { utf8ToUpper } = require("%sqstd/string.nut")
let { withTooltip } = require("%ui/style/cursors.nut")
let { getItemName } = require("%enlSqGlob/ui/itemsInfo.nut")
let { fontSub, fontBody, fontHeading2 } = require("%enlSqGlob/ui/fontsStyle.nut")
let { elemBarSize, mkGrowthSlotElems } = require("%enlist/growth/growthPkg.nut")
let { getCurrencyPresentation } = require("%enlist/shop/currencyPresentation.nut")
let { mkCurrencyImage } = require("%enlist/shop/currencyComp.nut")
let { mkXpBooster } = require("%enlist/components/mkXpBooster.nut")
let {
  doubleSideHighlightLine, doubleSideHighlightLineBottom, doubleSideBg
} = require("%enlSqGlob/ui/defComponents.nut")
let {
  mkWinXpImage, mkBattleHeroAwardXpImage, mkPremiumAccountXpImage,
  mkBoosterXpImage, mkFreemiumXpImage
} = require("%enlist/debriefing/components/mkXpImage.nut")
let {
  mkArmyBaseExpTooltip, mkArmyPremiumExpTooltip, mkArmyResultExpTooltip, mkPremSquadXpImage
} = require("%enlist/debriefing/components/mkArmyExpTooltip.nut")
let {
  smallPadding, midPadding, bigPadding, largePadding, defItemBlur,
  brightAccentColor, titleTxtColor, defTxtColor, totalBlack
} = require("%enlSqGlob/ui/designConst.nut")
let { mkExpIcon } = require("%enlist/shop/armyCurrencyUi.nut")


const trigger = "content_anim"
const playerCountMultTooltipText = "debriefing/playerCountMultArmyExpTooltip"
const notEnoughPlayersShortText = "debriefing/playerCountMultArmyExpTooltipShort"

let REWARD_ICON_SIZE = hdpxi(30)
let xpIconSize = hdpxi(34)


let awardPositiveColor = Color(252, 186, 3, 255)
let awardNegativeColor = Color(252, 0, 0, 255)
let growthBgColor = 0xFF58603A


let mkText = @(text, override = {}) {
  rendObj = ROBJ_TEXT
  color = defTxtColor
  text
}.__update(fontSub, override)


let mkSign = @(text) mkText(text, { padding = hdpx(5) })
let multiplySign = mkSign("\u00D7")
let addingSign = mkSign("+")
let freemiumResultImage = mkFreemiumXpImage(xpIconSize)


let silverGainText = utf8ToUpper(loc("ui/textColon", { text = loc("debriefing/silverAdded") }))
let expHeader = mkText(utf8ToUpper(loc("ui/textColon", { text = loc("debriefing/expAdded") })))
let silverHeader = mkText(silverGainText, { size = [flex(), SIZE_TO_CONTENT] })


let mkGrowthProgress = @(wasProgress, addProgress, animDelay) {
  size = [flex(), midPadding]
  flow = FLOW_HORIZONTAL
  rendObj = ROBJ_SOLID
  color = totalBlack
  children = [
    {
      size = [pw(wasProgress), flex()]
      rendObj = ROBJ_SOLID
      color = growthBgColor
    }
    {
      size = [pw(addProgress), flex()]
      rendObj = ROBJ_SOLID
      color = brightAccentColor
      transform = { pivot = [0, 0] }
      animations = [
        { prop = AnimProp.scale, from = [0,1], to = [0,1], duration = animDelay,
          play = true, trigger }
        { prop = AnimProp.scale, from = [0,1], to = [1,1], duration = 1,
          play = true, delay = animDelay, trigger }
      ]
    }
  ]
}


let getGlobalGiftGuid = @(gift, campaignId = null) (campaignId ?? "") != ""
  ? $"progress_gift_{campaignId}_{gift.basetpl}"
  : $"progress_gift_{gift.army}_{gift.basetpl}"

let getNextGlobalGiftRequire = @(gift, cycle)
  cycle > 0 ? gift.loopExp : gift.startExp

let getNextGlobalGiftCount = @(gift, cycle)
  cycle > 0 ? gift.loopCount : gift.startCount


function mkGiftView(giftCfg) {
  let itemCurrency = getCurrencyPresentation(giftCfg.basetpl)
  return itemCurrency == null ? null
    : mkCurrencyImage(itemCurrency.icon, [REWARD_ICON_SIZE, REWARD_ICON_SIZE])
}

function mkSilverReward(giftsConfig, curGifts, campaignId, armyAddExp) {
  let giftCfg = giftsConfig?[0]
  let giftObj = curGifts?[[getGlobalGiftGuid(giftCfg, campaignId)]]
  let wasExp = giftObj?.exp ?? 0
  local cycle = giftObj?.cycle ?? 0
  local exp = wasExp + armyAddExp
  local nextGiftCount = 0
  while (true) {
    nextGiftCount += getNextGlobalGiftCount(giftCfg, cycle)
    let nextReq = getNextGlobalGiftRequire(giftCfg, cycle)
    if (nextReq > exp)
      break
    exp -= nextReq
    cycle++
  }

  return {
    size = [flex(), hdpxi(50)]
    children = [
      doubleSideHighlightLine
      doubleSideBg({
        size = flex()
        flow = FLOW_HORIZONTAL
        gap = smallPadding
        valign = ALIGN_CENTER
        padding = [0, bigPadding]
        children = [
          silverHeader
          mkGiftView(giftCfg)
          mkText(nextGiftCount, { color = titleTxtColor }.__update(fontBody))
        ]
      })
      doubleSideHighlightLineBottom
    ]
  }
}


let premiumAccAndSquadIcon = @(size) {
  size = [size * 1.5, size]
  children = [
    mkPremSquadXpImage(size, { pos = [size * 0.5, 0] })
    mkPremiumAccountXpImage(size)
  ]
}

let premiumIcon = @(size, isPremiumAccount, isPremiumSquad)
  isPremiumAccount && isPremiumSquad ? premiumAccAndSquadIcon(size)
    : isPremiumAccount ? mkPremiumAccountXpImage(size)
    : isPremiumSquad ? mkPremSquadXpImage(size)
    : null

let mkValueWithIcon = @(value, txtStyle, icon) {
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  children = [
    mkText(value, txtStyle)
    icon
  ]
}

let mkValueWithIconArmyExp = @(value, icon, textLocId = null)
  mkValueWithIcon(textLocId == null ? value : $"{value} {loc(textLocId)}",
    { color = value >= 1.0 ? awardPositiveColor : awardNegativeColor },
    icon)

let horFlow = @(children) {
  flow = FLOW_HORIZONTAL
  size = [SIZE_TO_CONTENT, xpIconSize]
  valign = ALIGN_CENTER
  children
}

let wrapParams = {
  width = fsh(50)
  valign = ALIGN_CENTER
}

function mkPointsReward(result, details, armyAddExp, squads, armyId) {
  if (armyAddExp <= 0)
    return null

  let isSuccess = (result?.success ?? false)
  let isDeserter = (result?.deserter ?? false)
  let {
    baseArmyExp = 0, boostedExp = 0, premiumExp = 0, noviceBonus = 0,
    battleResultMult = 1.0, anyTeamMult = 1.0, lastGameDeserterMult = 1.0,
    battleHeroAwardsMult = 1.0, playerCountMult = 1.0, armyExpBoost = 0,
    isBattleResultMultDisabled = false, isArmyBoostDisabled = false,
    isBattleHeroMultDisabled = false, freemiumExpMult = 1.0
  } = details

  let battleResultLocId = isSuccess ? "debriefing/battleResultWinMult"
    : isDeserter ? "debriefing/battleResultDeserterMult"
    : "debriefing/battleResultMult"

  let battleResultText = isDeserter ? "debriefing/battleResultDeserterMultShort" : null
  let battleResultImage = isSuccess ? mkWinXpImage(xpIconSize) : null
  let anyTeamMultText = "debriefing/anyTeamMultShort"
  let anyTeamMultImage = null
  let anyTeamMultLocId = "debriefing/anyTeamMultTooltip"
  let lastGameDeserterMultText = "debriefing/lastGameDeserterMultShort"
  let lastGameDeserterMultImage = null
  let lastGameDeserterMultLocId = "debriefing/lastGameDeserterMultTooltip"

  let hasBoostBonus = boostedExp > 0
  let hasPremBonus = premiumExp > 0
  let hasPremiumAccount = (details?.premiumExpMul ?? 1.0) > 1.0
  let hasPremiumSquad = squads.findvalue(@(squad) (squad?.premSquadExpBonus ?? 0) > 0) != null
  let hasBattleResultMult = battleResultMult != 1.0
  let hasAnyTeamMult = anyTeamMult != 1.0
  let hasLastGameDeserterMult = lastGameDeserterMult != 1.0
  let hasBattleHeroMult = battleHeroAwardsMult != 1.0
  let hasPlayerCountMultIcon = playerCountMult != 1.0
  let hasFreemiumMult = freemiumExpMult != 1.0
  let needsParentheses = (hasBoostBonus || hasPremBonus)
    && (hasBattleResultMult || hasAnyTeamMult || hasLastGameDeserterMult || hasBattleHeroMult || hasFreemiumMult)
  let showNotEnoughPlayersNotice = hasPlayerCountMultIcon || isBattleResultMultDisabled
    || isArmyBoostDisabled || isBattleHeroMultDisabled
  let showDetailed = hasBattleHeroMult || hasBattleResultMult || hasAnyTeamMult
    || hasLastGameDeserterMult || showNotEnoughPlayersNotice || hasPremBonus
    || hasBoostBonus || hasFreemiumMult || noviceBonus > 0

  let baseExp = showDetailed
    ? withTooltip(mkText(baseArmyExp), @() mkArmyBaseExpTooltip(squads, baseArmyExp))
    : null
  let boostExp = !hasBoostBonus ? null
    : horFlow([
        addingSign
        withTooltip(mkValueWithIconArmyExp(boostedExp, mkBoosterXpImage(xpIconSize)),
          @() loc("debriefing/boosterBonusExp", {
            percent = colorize(awardPositiveColor, 100 * armyExpBoost)
          }))
      ])
  let premExp = !hasPremBonus ? null
    : horFlow([
        addingSign
        withTooltip(
          mkValueWithIconArmyExp(premiumExp, premiumIcon(xpIconSize, hasPremiumAccount, hasPremiumSquad))
          @() mkArmyPremiumExpTooltip(squads, premiumExp, details, armyId, hasPremiumAccount, hasPremiumSquad))
      ])
  let battleResultMultIcon = !hasBattleResultMult ? null
    : horFlow([
        multiplySign
        withTooltip(
          mkValueWithIconArmyExp(battleResultMult, battleResultImage, battleResultText)
          @() loc(battleResultLocId))
      ])
  let lastGameDeserterMultIcon = !hasLastGameDeserterMult ? null
    : horFlow([
        multiplySign
        withTooltip(
          mkValueWithIconArmyExp(lastGameDeserterMult, lastGameDeserterMultImage, lastGameDeserterMultText)
          @() loc(lastGameDeserterMultLocId))
      ])
  let anyTeamMultIcon = !hasAnyTeamMult ? null
    : horFlow([
        multiplySign
        withTooltip(
          mkValueWithIconArmyExp(anyTeamMult, anyTeamMultImage, anyTeamMultText)
          @() loc(anyTeamMultLocId))
      ])
  let freemiumResultMultIcon = !hasFreemiumMult ? null
    : horFlow([
        multiplySign
        withTooltip(
          mkValueWithIconArmyExp(freemiumExpMult, freemiumResultImage)
          @() loc("debriefing/freemExpBonus"))
      ])
  let battleHeroMultIcon = !hasBattleHeroMult ? null
    : horFlow([
        multiplySign
        withTooltip(
          mkValueWithIconArmyExp(battleHeroAwardsMult, mkBattleHeroAwardXpImage(xpIconSize))
          @() loc("debriefing/battleHeroAwardsMult"))
      ])
  let playerCountMultIcon = !showNotEnoughPlayersNotice ? null
    : horFlow([
        hasPlayerCountMultIcon ? multiplySign : null
        withTooltip(hasPlayerCountMultIcon
            ? mkValueWithIconArmyExp(playerCountMult, null, notEnoughPlayersShortText)
            : mkText(loc(notEnoughPlayersShortText), { color = awardNegativeColor }),
          @() loc(playerCountMultTooltipText))
      ])
  let noviceBonusExp = noviceBonus <= 0 ? null
    : horFlow([ addingSign, withTooltip(mkText(noviceBonus), @() loc("debriefing/noviceExpBonus")) ])
  let resultExp = withTooltip(
    mkText(armyAddExp, { color = titleTxtColor }.__update(fontBody)),
    @() mkArmyResultExpTooltip(squads, armyAddExp, details, isDeserter, armyId)
  )

  return {
    size = [flex(), SIZE_TO_CONTENT]
    children = [
      doubleSideHighlightLine
      doubleSideBg({
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        gap = smallPadding
        valign = ALIGN_CENTER
        padding = [midPadding, bigPadding]
        children = [
          {
            size = [flex(), SIZE_TO_CONTENT]
            flow = FLOW_VERTICAL
            valign = ALIGN_CENTER
            children = !showDetailed
              ? expHeader
              : [
                  wrap([
                    horFlow([
                      expHeader
                      needsParentheses ? mkText("(") : null
                      baseExp
                      boostExp
                      premExp
                      needsParentheses ? mkText(")") : null
                    ])
                    battleResultMultIcon
                    lastGameDeserterMultIcon
                    anyTeamMultIcon
                    freemiumResultMultIcon
                    battleHeroMultIcon
                    playerCountMultIcon
                    noviceBonusExp
                  ], wrapParams)
              ]
          }
          mkExpIcon([REWARD_ICON_SIZE, REWARD_ICON_SIZE])
          resultExp
        ]
      }).__update({ size = [flex(), SIZE_TO_CONTENT] })
      doubleSideHighlightLineBottom
    ]
  }
}


let mkExpBoosterWithTooltip = @(value) withTooltip({
  flow = FLOW_VERTICAL
  gap = smallPadding
  halign = ALIGN_CENTER
  margin = [0, 0, 0, largePadding]
  children = [
    mkXpBooster({ size = [hdpx(70), hdpx(86)] })
    {
      rendObj = ROBJ_TEXT
      text = loc("expBoost", { boost = (100.0 * value + 0.5).tointeger() })
    }
  ]
}, @() loc("boostTotal/global", { percent = colorize(awardPositiveColor, 100 * value) }))


function mkArmyProgress(
  armyId, armyAddExp, growthProgress, result, onFinish,
  giftsConfig = null, curGifts = null, campaignId = "",
  armyExpDetailed = {}, boosts = null, squads = {}
) {
  let resultHeader = mkText(utf8ToUpper(loc("lb/battleResults")), {
      color = brightAccentColor
    }.__update(fontHeading2))

  let resultObject = {
    size = [fsh(75), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = midPadding
    margin = [largePadding, 0]
    children = [
      mkSilverReward(giftsConfig, curGifts, campaignId, armyAddExp)
      mkPointsReward(result, armyExpDetailed, armyAddExp, squads, armyId)
    ]
    animations = [
      { prop = AnimProp.scale, from = [1,1], to = [1,1], duration = 2,
        play = true, trigger, onFinish }
    ]
  }

  let { exp = 0, status = 0, growthCfg = null, item = null } = growthProgress
  let { expRequired = 0, reward = null } = growthCfg
  let { squadId = null } = reward
  let wasProgress = expRequired == 0 ? 0 : 100 * exp / expRequired
  let addProgress = expRequired == 0 ? 0 : min(100 - wasProgress, 100 * armyAddExp / expRequired)
  let growthObject = growthCfg == null || item == null
    ? null
    : {
        flow = FLOW_VERTICAL
        size = [elemBarSize[0], SIZE_TO_CONTENT]
        gap = midPadding
        children = [
          {
            flow = FLOW_VERTICAL
            children = [
              {
                rendObj = ROBJ_TEXT
                behavior = [Behaviors.Marquee]
                size = [elemBarSize[0], SIZE_TO_CONTENT]
                text = getItemName(item)
                color = titleTxtColor
              }
              {
                size = elemBarSize
                rendObj = ROBJ_WORLD_BLUR_PANEL
                fillColor = 0XFF1E272E
                color = defItemBlur
                children = mkGrowthSlotElems(0xFFB3BDC1, status, item, squadId)
              }
            ]
          }
          mkGrowthProgress(wasProgress, addProgress, 0.8)
          mkText(loc("debriefing/growthHeader"), {
            color = brightAccentColor
            vplace = ALIGN_CENTER
          })
        ]
      }

  let { positive = 0 } = boosts
  let boostsObject = positive <= 0 ? null : mkExpBoosterWithTooltip(positive)

  return {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    halign = ALIGN_CENTER
    children = [
      resultHeader
      {
        flow = FLOW_HORIZONTAL
        gap = largePadding
        valign = ALIGN_CENTER
        padding = [0, 0, bigPadding, 0]
        children = [
          resultObject
          growthObject
          boostsObject
        ]
      }
    ]
  }
}

return kwarg(mkArmyProgress)
