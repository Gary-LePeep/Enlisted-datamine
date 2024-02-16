from "%enlSqGlob/ui_library.nut" import *

let { fontHeading2, fontBody, fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let JB = require("%ui/control/gui_buttons.nut")
let faComp = require("%ui/components/faComp.nut")
let currenciesWidgetUi = require("%enlist/currency/currenciesWidgetUi.nut")
let textButtonTextCtor = require("%ui/components/textButtonTextCtor.nut")
let { Horiz } = require("%ui/components/slider.nut")
let mkGlare = require("%enlist/components/mkGlareAnim.nut")
let getPayItemsData = require("%enlist/soldiers/model/getPayItemsData.nut")
let sClassesCfg = require("%enlist/soldiers/model/config/sClassesConfig.nut")
let { squadsCfgById } = require("%enlist/soldiers/model/config/squadsConfig.nut")
let { sidePadding, largePadding, smallPadding, titleTxtColor, defTxtColor, midPadding, accentColor,
  brightAccentColor, darkTxtColor, panelBgColor, defBdColor, squadSlotBgHoverColor,
  defItemBlur, inventoryItemDetailsWidth, commonBtnHeight,
  hoverSlotBgColor, contentOffset, positiveTxtColor
} = require("%enlSqGlob/ui/designConst.nut")
let { currenciesBalance } = require("%enlist/currency/currencies.nut")
let { purchaseMsgBox } = require("%enlist/currency/purchaseMsgBox.nut")
let { safeAreaSize, safeAreaBorders } = require("%enlist/options/safeAreaState.nut")
let { curArmy, curCampItems } = require("%enlist/soldiers/model/state.nut")
let { GrowthStatus, curGrowthId, curGrowthConfig, curGrowthState, curGrowthSelected,
  callGrowthSelect, callGrowthPurchase, curSquads, curTemplates, mkGrowthData,
  curGrowthTiers, curGrowthProgress, curGrowthFreeExp, callGrowthExp, callGrowthBuyExp,
  reqGrowthId, growthTierToScroll, isGrowthVisible
} = require("growthState.nut")
let shopItemClick = require("%enlist/shop/shopItemClick.nut")
let { mkColoredGradientX } = require("%enlSqGlob/ui/gradients.nut")
let { makeHorizScroll } = require("%ui/components/scrollbar.nut")
let { gradientProgressBar } = require("%enlSqGlob/ui/defComponents.nut")
let { splitThousands, round_by_value, floor } = require("%sqstd/math.nut")
let { getItemName } = require("%enlSqGlob/ui/itemsInfo.nut")
let { itemTypeIcon } = require("%enlist/soldiers/components/itemTypesData.nut")
let { PrimaryFlat, Flat, smallStyle } = require("%ui/components/textButton.nut")
let { Bordered } = require("%ui/components/txtButton.nut")
let { currencyBtn, mkCurrencyImg } = require("%enlist/currency/currenciesComp.nut")
let { mkSquadDetails, mkItemDetails, mkGrowthRewardsText, mkGrowthSlotElems
} = require("%enlist/growth/growthPkg.nut")
let { utf8ToUpper } = require("%sqstd/string.nut")
let { addModalWindow, removeModalWindow } = require("%ui/components/modalWindows.nut")
let { mkCurrencyImage } = require("%enlist/shop/currencyComp.nut")
let { getCurrencyPresentation } = require("%enlist/shop/currencyPresentation.nut")
let { progressContainerCtor, gradientProgressLine, completedProgressLine
} = require("%enlist/components/mkProgressBar.nut")
let { TextActive, textColor } = require("%ui/style/colors.nut")
let { mkFireParticles, mkAshes, mkSparks } = require("%enlist/components/mkFireParticles.nut")
let { enlistedGold } = require("%enlist/currency/currenciesList.nut")
let { mkPremiumSquadXpImage } = require("%enlist/debriefing/components/mkXpImage.nut")
let { showMsgbox, styling } = require("%enlist/components/msgbox.nut")
let { mkPrice } = require("%enlist/shop/mkShopItemPrice.nut")
let { freeExpUi, mkExpIcon } = require("%enlist/shop/armyCurrencyUi.nut")
let { shopItems } = require("%enlist/shop/shopItems.nut")
let { mkHotkey } = require("%ui/components/uiHotkeysHint.nut")
let { isGamepad } = require("%ui/control/active_controls.nut")
let { sound_play } = require("%dngscripts/sound_system.nut")
let { mkDiscountBar } = require("%enlist/shop/shopPackage.nut")


const RELATIONS_WND_UID = "growth_relations_list"
const BOOST_WND_UID = "growth_boost"

let GOLD_CURRENCY_ID = "EnlistedGold"
let SILVER_ID = "enlisted_silver"

let tblScrollHandler = ScrollHandler()

let scrollBarsWidth = hdpxi(150)
let elemSize = [hdpxi(218), hdpxi(100)]
let elemNoNameSize = [hdpxi(218), hdpxi(80)]
let gapSize = [hdpxi(30), hdpxi(12)]
let headerSize = hdpxi(20)
let tierHeight = hdpxi(26)
let blocksGap = hdpxi(40)
let scrollAreaWidth = safeAreaSize.value[0] - (inventoryItemDetailsWidth + blocksGap)

let progressTitleStyle = freeze({ color = titleTxtColor }.__update(fontSub))
let progressValueStyle = freeze({ color = titleTxtColor }.__update(fontSub))
let alertStyle = freeze({ color = brightAccentColor }.__update(fontSub))

let expValueStyle = freeze({ color = brightAccentColor }.__update(fontBody))
let headerTxtStyle = freeze({ color = brightAccentColor }.__update(fontHeading2))

let infoTextStyle = freeze({ color = titleTxtColor }.__update(fontBody))


let selectedWithBorder = hdpx(2)

let activeIdleProgColor = 0XFF3B4334
let activeHoverProgColor = 0xFF58603A
let progressColor = 0xFF667079
let unavailableIdleBgColor = 0xFF621D1D
let unavailableSelectedBgColor = 0xFF905D5D
let activeElemsColor = 0xFF313841
let defElemsColor = 0xFFB3BDC1
let activeIdleBgColor = 0XFF414D5B
let premBgSelectedColor = 0xFF3C4050
let premBgIdleColor = 0xFF3C4050
let currentIdleBgColor = 0XFF1E272E
let currentHoverBgColor = 0xFFA0A2A3
let currentSelectedBgColor = 0XFF1E272E

let isBoostWndOpen = Watched(false)
let curGrowthRelations = Watched(null)
let curInfoTabId = Watched(null)
local scrollXPos = null


let sliderWidth = hdpxi(540)
let progBarHeight = hdpxi(28)
let mkTierCtor = @(w) progressContainerCtor(
  $"ui/uiskin/campaign/Campaign_progress_bar_mask.svg",
  $"ui/uiskin/campaign/Campaign_progress_bar_border.svg",
  [w, progBarHeight]
)

let btnHotkey = {
  hotkeys = [[$"^J:Y | Space"]]
}

let mkBgParticles = @(effectSize) {
  children = [
    mkFireParticles(24, effectSize, mkAshes)
    mkFireParticles(8, effectSize, mkSparks)
  ]
}


let function tabInteriorCb() {
  scrollXPos = tblScrollHandler.elem.getScrollOffsX()
  curGrowthRelations(null)
}

let infoTabs = {
  item = {
    locId = "weaponry"
    uiCtor = @(data) mkItemDetails(data, tabInteriorCb)
  }
  squad = {
    locId = "squad"
    uiCtor = @(data) @() {
      watch = [sClassesCfg, squadsCfgById]
      size = flex()
      children = mkSquadDetails(data, sClassesCfg.value, squadsCfgById.value, tabInteriorCb)
    }
  }
}


let tabsToShow = Computed(function() {
  let { itemTemplate = null, squadId = null, armyId = null
    } = curGrowthConfig.value?[curGrowthId.value].reward
  let res = []
  let item = curTemplates.value?[itemTemplate]
  if (item != null)
    res.append({
      tabId = "item"
      data = {
        item
        itemTemplate
        armyId
      }
    })

  let squad = curSquads.value?[squadId]
  if (squad != null)
    res.append({
      tabId = "squad"
      data = {
        squad
        armyId
      }
    })
  return res
})

tabsToShow.subscribe(function(v) {
  if (v.len() == 0)
    return
  if (curInfoTabId.value == null){
    curInfoTabId(v[0].tabId)
    return
  }
  let idxToSet = v.findindex(@(val) val.tabId == curInfoTabId.value)
  if (idxToSet == null)
    curInfoTabId(v[0].tabId)
  else
    curInfoTabId(v[idxToSet].tabId)
  })

let progressBarStyle = freeze({
  size = [flex(), hdpx(22)]
  bgImage = mkColoredGradientX({ colorLeft = 0xFF993333, colorRight = brightAccentColor })
  emptyColor = panelBgColor
})

let elemInactive = @(_isPrem, isSelected, ...) {
  rendObj = ROBJ_BOX
  size = [elemSize[0], flex()]
  borderWidth = isSelected ? selectedWithBorder : 0
  borderColor = defBdColor
}

let elemRewarded = elemInactive

let elemCompleted = @(_isPrem, isSelected, ...) {
  rendObj = ROBJ_BOX
  size = [elemSize[0], flex()]
  borderWidth = isSelected ? selectedWithBorder : 0
  borderColor = accentColor
}

let elemActive = @(_isPrem, isSelected, progress, isCurrent, sf) {
  size = [elemSize[0], flex()]
  children = [
    progress == 0 ? null : {
      size = [pw(progress), flex()]
      rendObj = ROBJ_SOLID
      color = !isCurrent ? progressColor
        : (sf & S_HOVER) != 0 || isSelected ? activeHoverProgColor
        : activeIdleProgColor
    }
    {
      size = flex()
      rendObj = ROBJ_BOX
      borderWidth = isSelected ? selectedWithBorder : 0
      borderColor = isSelected ? defBdColor : 0
    }
  ]
}

let lineDashSize = hdpx(5)
let lineStyle = freeze({
  [GrowthStatus.UNAVAILABLE] = @(pos, size, data) {
    rendObj = ROBJ_VECTOR_CANVAS
    pos
    size
    color = 0x66666666
    lineWidth = hdpx(2)
    commands = [[VECTOR_LINE_DASHED].extend(data, [lineDashSize, lineDashSize])]
  },
  [GrowthStatus.ACTIVE] = @(pos, size, data) {
    rendObj = ROBJ_VECTOR_CANVAS
    pos
    size
    color = 0x55445533
    lineWidth = hdpx(2)
    commands = [[VECTOR_LINE].extend(data)]
  },
  [GrowthStatus.COMPLETED] = @(pos, size, data) {
    rendObj = ROBJ_VECTOR_CANVAS
    pos
    size
    color = 0xFFFFCC33
    lineWidth = hdpx(3)
    commands = [[VECTOR_LINE].extend(data)]
  },
  [GrowthStatus.PURCHASABLE] = @(pos, size, data) {
    rendObj = ROBJ_VECTOR_CANVAS
    pos
    size
    color = 0x66666666
    lineWidth = hdpx(3)
    commands = [[VECTOR_LINE].extend(data)]
  },
  [GrowthStatus.REWARDED] = @(pos, size, data) {
    rendObj = ROBJ_VECTOR_CANVAS
    pos
    size
    color = 0x66666666
    lineWidth = hdpx(3)
    commands = [[VECTOR_LINE].extend(data)]
  },
})

let lineHor = freeze([0, 50, 100, 50])
let lineVer = freeze([50, 0, 50, 100])


enum LineDir {
  NONE
  LESS
  MORE
}

let coordHor = @(index, dir = LineDir.NONE) (elemSize[0] + gapSize[0]) * index
  + (dir == LineDir.LESS ? 0 : dir == LineDir.MORE ? elemSize[0] : elemSize[0] * 0.5)

let coordVer = @(index, dir = LineDir.NONE) (elemSize[1] + gapSize[1]) * index
  + (dir == LineDir.LESS ? 0 : dir == LineDir.MORE ? elemSize[1] : elemSize[1] * 0.5)

let function mkGrowthLines(colFrom, lineFrom, colTo, lineTo) {
  let res = []
  local horPos, verPos

  // vertical lines
  if (colFrom == colTo) {
    horPos = coordHor(colFrom, LineDir.LESS)
    if (lineFrom > lineTo) {
      verPos = coordVer(lineTo, LineDir.MORE)
      res.append({
        pos = [horPos, verPos]
        size = [elemSize[0], coordVer(lineFrom, LineDir.LESS) - verPos]
        draw = lineVer
      })
    }
    if (lineFrom < lineTo) {
      verPos = coordVer(lineFrom, LineDir.MORE)
      res.append({
        pos = [horPos, verPos]
        size = [elemSize[0], coordVer(lineTo, LineDir.LESS) - verPos]
        draw = lineVer
      })
    }
    return res
  }

  // horizontal lines
  if (lineFrom == lineTo) {
    verPos = coordVer(lineFrom, LineDir.LESS) + headerSize * 0.5
    if (colFrom > colTo) {
      horPos = coordHor(colTo, LineDir.MORE)
      res.append({
        pos = [horPos, verPos]
        size = [coordHor(colFrom, LineDir.LESS) - horPos, elemSize[1]]
        draw = lineHor
      })
    }
    if (colFrom < colTo) {
      horPos = coordHor(colFrom, LineDir.MORE) + headerSize * 0.5
      res.append({
        pos = [horPos, verPos]
        size = [coordHor(colTo, LineDir.LESS) - horPos, elemSize[1]]
        draw = lineHor
      })
    }
    return res
  }

  // angled lines vertical
  horPos = coordHor(colTo, LineDir.LESS)
  if (lineFrom > lineTo) {
    verPos = coordVer(lineTo, LineDir.MORE)
    res.append({
      pos = [horPos, verPos],
      size = [elemSize[0], coordVer(lineFrom) - verPos + headerSize * 0.5]
      draw = lineVer
    })
  }
  if (lineFrom < lineTo) {
    verPos = coordVer(lineFrom)
    res.append({
      pos = [horPos, verPos + headerSize * 0.5],
      size = [elemSize[0], coordVer(lineTo, LineDir.LESS) - verPos]
      draw = lineVer
    })
  }

  // angled lines horizontal
  verPos = coordVer(lineFrom, LineDir.LESS) + headerSize * 0.5
  if (colFrom > colTo) {
    horPos = coordHor(colTo)
    res.append({
      pos = [horPos, verPos]
      size = [coordHor(colFrom, LineDir.LESS) - horPos, elemSize[1]]
      draw = lineHor
    })
  }
  if (colFrom < colTo) {
    horPos = coordHor(colFrom, LineDir.MORE) + headerSize * 0.5
    res.append({
      pos = [horPos, verPos]
      size = [coordHor(colTo) - horPos, elemSize[1]]
      draw = lineHor
    })
  }
  return res
}

let mkLabel = @(text, style) {
  rendObj = ROBJ_TEXT
  text
}.__update(style)

let mkText = @(text, style) {
  rendObj = ROBJ_TEXTAREA
  size = [flex(), SIZE_TO_CONTENT]
  behavior = Behaviors.TextArea
  text
}.__update(style)

let emptyCell = @(size = elemSize) { size }

let premBgColor = @(sf, isSelected) sf & S_HOVER ? squadSlotBgHoverColor
  : isSelected || (sf & S_ACTIVE) != 0 ? premBgSelectedColor
  : premBgIdleColor

let baseCompletedBgColor = @(sf, isSelected) sf & S_HOVER ? brightAccentColor
  : isSelected || (sf & S_ACTIVE) != 0 ? activeHoverProgColor
  : activeIdleProgColor

let completedBgColor = @(sf, isSelected, isPrem) isPrem
  ? premBgColor(sf, isSelected)
  : baseCompletedBgColor(sf, isSelected)

let activeBgColor = @(sf, isSelected, _isPrem)
  sf & S_HOVER ? currentHoverBgColor
    : isSelected || (sf & S_ACTIVE) != 0 ? currentSelectedBgColor
    : currentIdleBgColor

let currentBgColor = @(sf, isSelected)
  sf & S_HOVER ? currentHoverBgColor
    : isSelected || (sf & S_ACTIVE) != 0 ? currentSelectedBgColor
    : currentIdleBgColor

let unavailableBgColor = @(sf, isSelected, _isPrem)
  sf & S_HOVER ? squadSlotBgHoverColor
    : isSelected || (sf & S_ACTIVE) != 0 ? unavailableSelectedBgColor
    : unavailableIdleBgColor

let rewardedBgColor = @(sf, _isSelected, _isPrem) sf & S_HOVER
  ? squadSlotBgHoverColor
  : activeIdleBgColor


let slotBgColorMap = freeze({
  [GrowthStatus.UNAVAILABLE] = unavailableBgColor,
  [GrowthStatus.ACTIVE] = activeBgColor,
  [GrowthStatus.COMPLETED] = completedBgColor,
  [GrowthStatus.PURCHASABLE] = completedBgColor,
  [GrowthStatus.REWARDED] = rewardedBgColor,
})

let defChColor = @(sf = 0) sf & S_HOVER ? activeElemsColor : defElemsColor

let elemColorMap = freeze({
  [GrowthStatus.UNAVAILABLE] = @(_sf = 0) defBdColor,
  [GrowthStatus.COMPLETED] = @(sf = 0) sf & S_HOVER ? activeElemsColor : brightAccentColor
})


let elemBgMap = freeze({
  [GrowthStatus.UNAVAILABLE] = elemInactive,
  [GrowthStatus.ACTIVE] = elemActive,
  [GrowthStatus.COMPLETED] = elemCompleted,
  [GrowthStatus.PURCHASABLE] = elemCompleted,
  [GrowthStatus.REWARDED] = elemRewarded,
})

let mkGrowthName = @(txt, group, status, isCurrent, isSelected, sf) {
  rendObj = ROBJ_TEXT
  size = [flex(), headerSize]
  text = txt
  group
  behavior = Behaviors.Marquee
  clipChildren = true
  scrollOnHover = true
  color = isCurrent || status == GrowthStatus.COMPLETED ? brightAccentColor
    : isSelected || (sf & S_ACTIVE) ? titleTxtColor
    : defTxtColor
}.__update(fontSub)

let mkGrowthSlotBar = @(isPrem, status, isCurrent, isSelected, sf) {
  rendObj = ROBJ_WORLD_BLUR_PANEL
  size = flex()
  fillColor = isCurrent ? currentBgColor(sf, isSelected)
    : slotBgColorMap[status](sf, isSelected, isPrem)
  color = defItemBlur
  opacity = status == GrowthStatus.UNAVAILABLE ? 0.4 : 1
}


let priceIconSize = [hdpxi(22), hdpxi(22)]
let bigPriceIconSize = [hdpxi(30), hdpxi(30)]

let priceIconExp = mkExpIcon(priceIconSize)
let bigPriceIconExp = mkExpIcon(bigPriceIconSize)

let priceIconGold = mkCurrencyImg(enlistedGold, priceIconSize[0])
let priceIconSilver = mkCurrencyImage(getCurrencyPresentation(SILVER_ID)?.icon,
  priceIconSize)

let mkGrowthPrice = @(icon, price, color) {
  flow = FLOW_HORIZONTAL
  gap = smallPadding
  margin = smallPadding
  valign = ALIGN_CENTER
  vplace = ALIGN_BOTTOM
  children = [ icon, mkLabel(price, { color }.__update(fontSub)) ]
}

let mkEffects = @(stats, isCur) {
  size = flex()
  children = [
    stats != GrowthStatus.PURCHASABLE ? null
      : mkGlare({
          nestWidth = elemSize[0]
          glareWidth = elemSize[0]
          glareDuration = 1
          glareDelay = 1
          glareOpacity = 0.7
          hasMask = true
        })
    isCur ? mkBgParticles([elemSize[0], elemSize[1] - hdpxi(20)]) : null
  ]
}


let curGrowthTitleText = Computed(function() {
  let { reward = null } = curGrowthConfig.value?[curGrowthId.value]
  let templates = curTemplates.value
  let squads = curSquads.value
  return "\n".join(mkGrowthRewardsText(reward, templates, squads))
})


let function getGrowthSelectError(growthCfg, grState, grProgres, growthData) {
  if ((grState?[growthCfg.id].status ?? GrowthStatus.UNAVAILABLE) == GrowthStatus.ACTIVE)
    return null

  let growths = []
  local tier = null

  let { id, requirements = [] } = growthCfg
  foreach (reqId in requirements) {
    let status = grState?[reqId].status ?? GrowthStatus.UNAVAILABLE
    if (status != GrowthStatus.COMPLETED
        && status != GrowthStatus.PURCHASABLE
        && status != GrowthStatus.REWARDED)
      growths.append(reqId)
  }

  let { tierId, tierIdx } = growthData.growthLinks[id]
  let tierStatus = grProgres?[tierId].status ?? GrowthStatus.UNAVAILABLE
  if (tierStatus == GrowthStatus.UNAVAILABLE)
    tier = tierIdx

  return growths.len() == 0 && tier == null ? null : { growths, tier }
}


let function selectAction(growthCfg, growthData) {
  let grState = curGrowthState.value
  let grProgres = curGrowthProgress.value
  let err = getGrowthSelectError(growthCfg, grState, grProgres, growthData)
  if (err == null) {
    callGrowthSelect(curArmy.value, curGrowthId.value)
    return
  }

  let { growths, tier } = err
  showMsgbox({
    text = "\n\n".join([
      (tier == null ? null : loc("growthTier/reqToSelectGrowth", { reqText = tier })),
      (growths.len() == 0 ? null : loc("growth/reqToCompletePrev"))
    ], true)
  })
}


let isShopItemSuitable = @(item) (item?.can_be_bought ?? true)
  || (item?.curShopItemPrice.price ?? 0) > 0
  || (item?.price ?? 0) > 0
  || (item?.itemCost.len() ?? 0) > 0


let function findGrowthShopItem(shopItemsGuids, availShopItems) {
  if (shopItemsGuids.len() == 0)
    return null

  let guid = shopItemsGuids.findvalue(@(v) v in availShopItems
    && isShopItemSuitable(availShopItems[v]))
  return guid == null ? null : availShopItems[guid]
}


let function growthAction(growthItem, growthData) {
  let { id, expRequired = 0, shopItemsGuids = [], rewardCost = 0 } = growthItem
  let { status = GrowthStatus.UNAVAILABLE } = curGrowthState.value?[id]
  let isPrem = expRequired == 0
  let isCompleted = status == GrowthStatus.COMPLETED
  let isRewarded = status == GrowthStatus.REWARDED
  let isPurchasable = status == GrowthStatus.PURCHASABLE
  let isCurrent = curGrowthSelected.value == id && !isCompleted && !isRewarded && !isPurchasable

  if (isPrem) {
    let shopItem = findGrowthShopItem(shopItemsGuids, shopItems.value)
    if (!isRewarded && shopItem != null)
      shopItemClick(shopItem)
  }
  else if (isCompleted)
    showMsgbox({ text = loc("growth/notPurchasable") })
  else if (isPurchasable) {
    let buyInfo = getPayItemsData({ [SILVER_ID] = rewardCost }, curCampItems.value)
    if (buyInfo != null) {
      callGrowthPurchase(curArmy.value, id, buyInfo)
      curGrowthRelations(null)
    }
    else
      showMsgbox({ text = loc("shop/noSilverToPayRequired", { required = rewardCost}) })
  }
  else if (isRewarded) {
    let shopItem = findGrowthShopItem(shopItemsGuids, shopItems.value)
    if (shopItem != null)
      shopItemClick(shopItem)
  }
  else if (isCurrent)
    isBoostWndOpen(true)
  else
    selectAction(growthItem, growthData)
}


let reqGrowthObject = {
  size = [flex(), 0]
  halign = ALIGN_CENTER
  children = {
    size = [elemSize[0] + hdpxi(8), elemSize[1] + hdpxi(8)]
    pos = [0, -hdpxi(4)]
    rendObj = ROBJ_BOX
    borderWidth = hdpxi(2)
    borderColor = accentColor
    fillColor = hoverSlotBgColor
    animations = [{ prop = AnimProp.opacity, from = 0.2, to = 0.5,
      duration = 1, play = true, loop = true, easing = Blink }]
  }
}


let function mkDiscountPercBar(shopItem) {
  let { isPriceHidden = false, discountInPercent = 0 } = shopItem
  return isPriceHidden || discountInPercent <= 0 ? null
    : {
        vplace = ALIGN_CENTER
        children = mkDiscountBar({
          rendObj = ROBJ_TEXT
          text = $"-{discountInPercent}%"
        }.__update(fontSub), false, brightAccentColor, hdpxi(2))
      }
}


let discountStyle = {
  color = positiveTxtColor
  fontFx = FFT_SHADOW
  fontFxColor = 0xFF000000
  fontFxFactor = hdpx(64)
}.__update(fontSub)

let mkGrowthSlotPrice = @(elemsColor, priceCount, priceIcon, shItem) {
  size = flex()
  children = [
    priceCount > 0 ? mkGrowthPrice(priceIcon, priceCount, elemsColor) : null
    shItem.value == null ? null : {
      flow = FLOW_HORIZONTAL
      gap = midPadding
      margin = smallPadding
      vplace = ALIGN_BOTTOM
      children = [
        mkPrice({
          shopItem = shItem.value
          needPriceText = false
          discountStyle
          styleOverride = { color = elemsColor }.__update(fontSub)
          dimStyle = { color = elemsColor }.__update(fontSub)
          iconSize = priceIconSize
        })
        mkDiscountPercBar(shItem.value)
      ]
    }
  ]
}

let mkGrowthSlotBack = @(isPrem, status, progress, isCurrent, isSelected = true, sf = 0) {
  size = flex()
  children = [
    mkGrowthSlotBar(isPrem, status, isCurrent, isSelected, sf)
    elemBgMap[status](isPrem, isSelected, progress, isCurrent, sf)
    mkEffects(status, isCurrent)
    !isPrem ? null
      : @() {
          watch = curArmy
          children = mkPremiumSquadXpImage(hdpxi(32), curArmy.value)
        }
  ]
}

let calcProgress = @(exp, expRequired)
  expRequired == 0 ? 0 : ((exp).tofloat() / expRequired.tofloat()) * 100.0

let function mkGrowthSlot(growthItem, tmplsCfg, squadsCfg) {
  let { id = null, expRequired = 0, reward = null } = growthItem
  let { itemTemplate = null, squadId = null } = reward
  let item = tmplsCfg?[itemTemplate]
  let squad = squadsCfg?[squadId]
  if (item == null && squad == null)
    return emptyCell(elemNoNameSize)

  let isPrem = expRequired == 0
  let elemStatus = Computed(@() curGrowthState.value?[id].status ?? GrowthStatus.UNAVAILABLE)
  let isElemCurrent = Computed(@() curGrowthSelected.value == id
    && elemStatus.value != GrowthStatus.REWARDED)
  let elemProgress = Computed(@() calcProgress(curGrowthState.value?[id].exp ?? 0,
    curGrowthConfig.value?[id].expRequired ?? 0))

  return function() {
    let status = elemStatus.value
    let isCurrent = isElemCurrent.value
    let progress = elemProgress.value
    let elemsColor = elemColorMap?[status]() ?? defChColor()
    return {
      watch = [elemStatus, isElemCurrent, elemProgress]
      size = elemNoNameSize
      children = [
        mkGrowthSlotBack(isPrem, status, progress, isCurrent)
        mkGrowthSlotElems(elemsColor, status, item, squad)
      ]
    }
  }
}


let mkShopSign = @(color) faComp("shopping-basket", {
  fontSize = hdpxi(16)
  padding = smallPadding
  vplace = ALIGN_BOTTOM
  color
})

let function mkGrowthElement(growthItem, tmplsCfg, squadsCfg, growthData = null) {
  let {
    id = null, expRequired = 0, reward = null, rewardCost = 0, shopItemsGuids = []
  } = growthItem
  let { itemTemplate = null, squadId = null } = reward
  let item = tmplsCfg?[itemTemplate]
  let squad = squadsCfg?[squadId]
  if (item == null && squad == null)
    return emptyCell()

  let isPrem = expRequired == 0
  let curRelations = growthData?.growthRelations[id]

  let elemStatus = Computed(@() curGrowthState.value?[id].status ?? GrowthStatus.UNAVAILABLE)
  let isElemSelected = Computed(@() curGrowthId.value == id)
  let isElemAnimated = Computed(@() reqGrowthId.value == id)
  let isElemCurrent = Computed(@() curGrowthSelected.value == id
    && elemStatus.value != GrowthStatus.REWARDED)
  let elemOwnedExp = Computed(@() curGrowthState.value?[id].exp ?? 0)
  let elemProgress = Computed(@() calcProgress(elemOwnedExp.value,
    curGrowthConfig.value?[id].expRequired ?? 0))

  let shItem = Computed(@() isPrem || elemStatus.value == GrowthStatus.REWARDED
    ? findGrowthShopItem(shopItemsGuids, shopItems.value) : null)

  let itemName = getItemName(item)
  let group = ElemGroup()
  return watchElemState(function(sf) {
    let status = elemStatus.value
    let progress = elemProgress.value
    let isSelected = isElemSelected.value
    let isCurrent = isElemCurrent.value
    let ownedExp = elemOwnedExp.value
    let isCompleted = status == GrowthStatus.COMPLETED
    let isPurchasable = status == GrowthStatus.PURCHASABLE
    let isRewarded = status == GrowthStatus.REWARDED

    let priceIcon = isRewarded ? null
      : isPrem ? priceIconGold
      : isCompleted || isPurchasable ? priceIconSilver
      : priceIconExp

    let priceCount = isRewarded ? 0
      : isPrem ? rewardCost
      : isCompleted || isPurchasable ? rewardCost
      : expRequired - ownedExp

    let elemsColor = elemColorMap?[status](sf) ?? defChColor(sf)
    let hasShopSign = !isPrem && status == GrowthStatus.REWARDED && shItem.value != null
    let hasPrice = !isPrem || status == GrowthStatus.ACTIVE

    return {
      watch = [isElemSelected, isElemCurrent, elemStatus,
        elemProgress, shItem, elemOwnedExp]
      key = $"growth_{id}"
      size = elemSize
      flow = FLOW_VERTICAL
      group
      behavior = Behaviors.Button
      function onClick() {
        curGrowthId(id)
        if (curRelations != null)
          curGrowthRelations(curRelations)
      }
      onDoubleClick = @() growthAction(growthItem, growthData)
      children = [
        @() {
          watch = [isGrowthVisible, isElemAnimated]
          key = $"growth_{id}_{isElemAnimated.value}"
          size = [flex(), 0]
          children = isGrowthVisible.value && isElemAnimated.value
            ? reqGrowthObject
            : null
        }
        {
          size = [flex(), SIZE_TO_CONTENT]
          flow = FLOW_HORIZONTAL
          gap = smallPadding
          valign = ALIGN_CENTER
          children = [
            itemTypeIcon(item?.itemtype, item?.itemsubtype, { size = [hdpxi(18), hdpxi(18)] })
            mkGrowthName(itemName, group, status, isCurrent, isSelected, sf)
          ]
        }
        {
          size = flex()
          children = [
            mkGrowthSlotBack(isPrem, status, progress, isCurrent, isSelected, sf)
            mkGrowthSlotElems(elemsColor, status, item, squad, curRelations)
            hasShopSign ? mkShopSign(elemsColor)
              : hasPrice ? mkGrowthSlotPrice(elemsColor, priceCount, priceIcon, shItem)
              : null
          ]
        }
      ]
    }
  })
}

let treeScrollHandler = ScrollHandler()
let hasLeftScroll = Watched(false)
let hasRightScroll = Watched(true)

let function updateArrowButtons(elem) {
  hasLeftScroll(elem.getScrollOffsX() > 0)
  hasRightScroll(elem.getContentWidth() - elem.getScrollOffsX() > safeAreaSize.value[0])
}

treeScrollHandler.subscribe(function(_) {
  let { elem = null } = treeScrollHandler
  if (elem == null)
    return
  updateArrowButtons(elem)
})

let leftScroll = freeze({
  rendObj = ROBJ_IMAGE
  size = [scrollBarsWidth, flex()]
  image = mkColoredGradientX({colorLeft=0xFF060C12, colorRight=0x00000000})
})

let rightScroll = freeze({
  rendObj = ROBJ_IMAGE
  size = [scrollBarsWidth, flex()]
  image = mkColoredGradientX({colorLeft=0x00000000, colorRight=0xFF03090C})
})

let mkGrowthTree = @(growthData) function() {
  local maxCol = 0
  let growthLines = curGrowthConfig.value
    .reduce(function(res, growth, _, tbl) {
      let { id, col = 0, line = 0, requirements = [] } = growth
      foreach (reqId in requirements) {
        let reqGrowth = tbl[reqId]
        let capturedId = reqId // in order to pass iterator to lambda function
        let status = Computed(@() curGrowthState.value?[capturedId].status != GrowthStatus.REWARDED
          ? GrowthStatus.UNAVAILABLE
          : curGrowthState.value?[id].status ?? GrowthStatus.UNAVAILABLE)
        let lines = mkGrowthLines(col, line, reqGrowth?.col ?? 0, reqGrowth?.line ?? 0)
        res.append(@() {
          watch = status
          children = lines.map(function(data) {
            let comp = lineStyle?[status.value] ?? lineStyle[3]
            return comp(data.pos, data.size, data.draw)
          })
        })
      }
      return res
    }, [])

  let { growthRelations = {} } = growthData
  let growthElements = curGrowthConfig.value
    // TODO create computed status and data for every element and keep subscriptions inside elements rather than for all list
    .reduce(function(res, growth, _, tbl) {
      let { id, col = 0, line = 0 } = growth
      maxCol = max(col, maxCol)
      while (res.len() <= line)
        res.append([])
      let arr = res[line]
      if (arr.len() <= col)
        arr.resize(col + 1, null)
      if (arr?[col] == null)
        arr[col] = growth
      else if (id in growthRelations) {
        let relations = growthRelations[id]
        let unrewardedId = relations.findvalue(@(relId)
          curGrowthState.value?[relId].status != GrowthStatus.REWARDED) ?? id
        arr[col] = tbl[unrewardedId]
      }
      return res
    }, [])
    .map(@(growthLine) {
      flow = FLOW_HORIZONTAL
      gap = gapSize[0]
      children = growthLine.map(@(growthItem)
        mkGrowthElement(growthItem, curTemplates.value, curSquads.value, growthData))
    })

  let maxLine = growthElements.len() - 1
  return {
    watch = [curGrowthConfig, curGrowthState, curTemplates, curSquads]
    size = [SIZE_TO_CONTENT, flex()]
    children = [
      {
        size = [
          (elemSize[0] + gapSize[0]) * maxCol - gapSize[0],
          (elemSize[1] + gapSize[1]) * maxLine - gapSize[1]
        ]
        children = growthLines
      }
      {
        flow = FLOW_VERTICAL
        gap = gapSize[1]
        children = growthElements
      }
      @() {
        watch = hasLeftScroll
        size = [SIZE_TO_CONTENT, flex()]
        children = hasLeftScroll.value ? leftScroll : null
        hplace = ALIGN_LEFT
      }
      @() {
        watch = hasRightScroll
        size = [SIZE_TO_CONTENT, flex()]
        children = hasRightScroll.value ? rightScroll : null
        hplace = ALIGN_RIGHT
      }
    ]
  }
}

let mkContentHeaderUi = @(style) @() {
  watch = curGrowthTitleText
  size = [flex(), SIZE_TO_CONTENT]
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  text = curGrowthTitleText.value
}.__update(style)

let function gotoNextPage(delta) {
  let total = tabsToShow.value.len()
  if (total > 1) {
    let curIndex = tabsToShow.value
      .findindex(@(item) item.tabId == curInfoTabId.value) ?? 0
    curInfoTabId(tabsToShow.value[(curIndex + total + delta) % total].tabId)
  }
}

let switchPageKey = @() {
  size = [0, SIZE_TO_CONTENT]
  padding = smallPadding
  vplace = ALIGN_CENTER
  children = mkHotkey("J:X", @() gotoNextPage(1))
}

let function mkInfoTab(tab) {
  let { tabId } = tab
  let isSelected = Computed(@() tabId == curInfoTabId.value)
  return watchElemState(@(sf) {
    watch = isSelected
    rendObj = ROBJ_BOX
    size = [flex(), commonBtnHeight]
    fillColor = isSelected.value || (sf & S_HOVER) ? hoverSlotBgColor : panelBgColor
    borderWidth = isSelected.value ? [0, 0, hdpx(4), 0] : 0
    borderColor = accentColor
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    behavior = Behaviors.Button
    onClick = @() curInfoTabId(tabId)
    children = {
      rendObj = ROBJ_TEXT
      size = [flex(), SIZE_TO_CONTENT]
      halign = ALIGN_CENTER
      color = isSelected.value ? titleTxtColor
        : (sf & S_HOVER) ? darkTxtColor
        : defTxtColor
      text = loc(infoTabs[tabId].locId)
    }
  })
}

let function infoTabsBlock() {
  let res = { watch = tabsToShow }
  if (tabsToShow.value.len() <= 0)
    return res

  let tabs = tabsToShow.value
  return res.__update({
    watch = [tabsToShow, isGamepad]
    size = [inventoryItemDetailsWidth, flex()]
    flow = FLOW_VERTICAL
    gap = midPadding
    children = [
      tabs.len() <= 1 ? null : {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        children = tabs.map(mkInfoTab).append(isGamepad.value ? switchPageKey : null)
      }
      function() {
        let curId = curInfoTabId.value
        let curIdx = tabs.findindex(@(v) v.tabId == curId)
        return {
          watch = [curInfoTabId, sClassesCfg]
          size = flex()
          children = curIdx != null
            ? infoTabs[curId].uiCtor(tabs[curIdx].data)
            : null
        }
      }
    ]
  })
}

let itemProgressUi = @(growthData) function () {
  let res = { watch = [curGrowthId, curGrowthConfig, curGrowthState, curGrowthSelected, curGrowthProgress] }
  let growthCfg = curGrowthConfig.value?[curGrowthId.value]
  let { expRequired = 0 } = growthCfg
  if (expRequired <= 0)
    return res

  let grState = curGrowthState.value
  let { exp = 0, status = GrowthStatus.UNAVAILABLE } = grState?[curGrowthId.value]
  let isResearching = curGrowthId.value == curGrowthSelected.value
  let statusLocId = isResearching ? "growth/statusGrowthing"
    : status == GrowthStatus.ACTIVE ? "growth/statusActive"
    : status == GrowthStatus.COMPLETED ? "growth/statusCompleted"
    : status == GrowthStatus.PURCHASABLE ? "growth/statusPurchasable"
    : status == GrowthStatus.REWARDED ? "growth/statusRewarded"
    : "growth/statusUnavailable"

  let grProgres = curGrowthProgress.value
  local alertText = ""
  if (status == GrowthStatus.UNAVAILABLE) {
    let err = getGrowthSelectError(growthCfg, grState, grProgres, growthData)
    if (err != null) {
      let { growths, tier } = err
      alertText = "\n".join([
        (tier == null ? null : loc("growthTier/reqToSelectGrowth", { reqText = tier })),
        (growths.len() == 0 ? null : loc("growth/reqToCompletePrev"))
      ], true)
    }
  }

  let progressObject = status == GrowthStatus.UNAVAILABLE
      ? mkText(alertText, alertStyle)
    : status == GrowthStatus.ACTIVE
      ? {
          size = [flex(), SIZE_TO_CONTENT]
          valign = ALIGN_CENTER
          children = [
            gradientProgressBar(exp.tofloat() / expRequired.tofloat(), progressBarStyle)
            mkLabel($"{splitThousands(exp)} / {splitThousands(expRequired)}", {
              padding = [0, smallPadding]
            }.__update(progressValueStyle))
          ]
        }
    : null
  return res.__update({
    size = [flex(), SIZE_TO_CONTENT]
    gap = midPadding
    flow = FLOW_VERTICAL
    valign = ALIGN_BOTTOM
    children = [
      mkText(loc(statusLocId), infoTextStyle)
      progressObject
    ]
  })
}

let mkBtnReward = @(price, action, btnCtor) price == 0 ? null
  : btnCtor("", action, {
      size = [flex(), commonBtnHeight]
      margin = 0
      textCtor = @(_textComp, params, handler, group, sf) textButtonTextCtor({
        flow = FLOW_HORIZONTAL
        valign = ALIGN_CENTER
        gap = midPadding
        children = [
          mkLabel(loc("growth/btnTakeReward"),
            { color = textColor(sf, false, TextActive) }.__update(fontBody))
          priceIconSilver
          mkLabel(price, { color = textColor(sf, false, TextActive) }.__update(fontBody))
        ]
      }, params, handler, group, sf)
    }.__update(btnHotkey))

let function mkBtnPurchase(shopItemsGuids, action) {
  let shItem = Computed(@() findGrowthShopItem(shopItemsGuids, shopItems.value))
  return @() {
    watch = shItem
    size = [flex(), SIZE_TO_CONTENT]
    children = shItem.value == null ? null
      : PrimaryFlat("", action, {
          size = [flex(), commonBtnHeight]
          margin = 0
          textCtor = @(_textComp, params, handler, group, sf) textButtonTextCtor({
            flow = FLOW_HORIZONTAL
            valign = ALIGN_CENTER
            gap = midPadding
            children = [
              mkLabel(loc("shop/purchase"),
                { color = textColor(sf, false, TextActive) }.__update(fontBody))
              mkPrice({
                shopItem = shItem.value
                needPriceText = false
                styleOverride = { color = textColor(sf, false, TextActive) }.__update(fontBody)
                iconSize = priceIconSize
              })
            ]
          }, params, handler, group, sf)
        }.__update(btnHotkey))
  }
}

let mkBtnSelect = @(action) Bordered(loc("growth/btnSelectCurrent"), action,
  { size = [flex(), commonBtnHeight] }.__update(btnHotkey))

let mkBtnBoostExp = @(action) PrimaryFlat(loc("growth/аccelerated"), action,
  {
    size = [flex(), commonBtnHeight]
    margin = 0
  }.__update(btnHotkey))


let function updateSliders(sliderGold, sliderExp) {
  let growthId = curGrowthId.value
  let growthItem = curGrowthConfig.value?[growthId]
  let freeExp = curGrowthFreeExp.value
  let { exp = 0 } = curGrowthState.value?[growthId]
  let { expRequired = 0, expCost = 0 } = growthItem

  let rate = expRequired.tofloat() / expCost.tofloat()
  let needExp = expRequired - exp
  let freeExpCount = min(freeExp, needExp)

  sliderGold(exp + rate)
  sliderExp(exp + freeExpCount)
}


let buyCb = function(res) {
  if ("error" not in res)
    sound_play("ui/purchase_level_squad")
}

let mkBtnUseExp = @(growthId, boostSliderExp, exp, boostSliderGold) function() {
  let count = boostSliderExp.value - exp
  return {
    watch = boostSliderExp
    size = [flex(), hdpxi(70)]
    halign = ALIGN_RIGHT
    children = count <= 0 ? null
      : PrimaryFlat("", @() callGrowthExp(curArmy.value, growthId, count, function(res) {
          updateSliders(boostSliderGold, boostSliderExp)
          buyCb(res)
        }), {
          textCtor = @(_textComp, params, handler, group, sf) textButtonTextCtor({
            flow = FLOW_HORIZONTAL
            valign = ALIGN_CENTER
            gap = midPadding
            children = [ bigPriceIconExp, mkLabel(count, infoTextStyle) ]
          }, params, handler, group, sf)
          size = [pw(40), commonBtnHeight]
          margin = 0
        })
  }
}


let mkGrowthControlsUi = @(growthDataVal) function () {
  let growthId = curGrowthId.value
  let growth = curGrowthState.value?[growthId]
  let growthItem = curGrowthConfig.value?[growthId]
  let isInResearch = curGrowthSelected.value == growthId
  let { status = GrowthStatus.UNAVAILABLE } = growth
  let { rewardCost = 0, expRequired = 0, shopItemsGuids = [] } = growthItem

  let isActive      = status == GrowthStatus.ACTIVE
  let isCompleted   = status == GrowthStatus.COMPLETED
  let isPurchasable = status == GrowthStatus.PURCHASABLE
  let isRewarded    = status == GrowthStatus.REWARDED

  let isPrem = expRequired == 0
  let hasShopItems = shopItemsGuids.len() > 0
  let reqBaseReward = (isCompleted || isPurchasable) && !isPrem
  let reqPurchase = hasShopItems && ((isPrem && !isRewarded) || (isRewarded && !isPrem))
  let reqBoost = !isPrem && isActive && isInResearch
  let reqSelect = !isPrem && isActive && !isInResearch

  let action = @() growthAction(growthItem, growthDataVal)
  return {
    watch = [curGrowthId, curGrowthState, curGrowthConfig, curGrowthSelected, curGrowthProgress]
    key = "growth_action_button"
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = smallPadding
    children = reqSelect ? mkBtnSelect(action)
      : reqBoost ? mkBtnBoostExp(action)
      : reqBaseReward ? mkBtnReward(rewardCost, action, isPurchasable ? PrimaryFlat : Flat)
      : reqPurchase ? mkBtnPurchase(shopItemsGuids, action)
      : null
  }
}

let mkInfoBlock = @(growthData) @() {
  watch = growthData
  size = [inventoryItemDetailsWidth, flex()]
  flow = FLOW_VERTICAL
  gap = midPadding
  padding = [smallPadding, 0]
  children = [
    infoTabsBlock
    itemProgressUi(growthData.value)
    mkGrowthControlsUi(growthData.value)
  ]
}


let function mkTier(tierData) {
  let { id, from, to, required, index } = tierData
  let tierLength = to - from + 1
  let tierWidth = elemSize[0] * tierLength + gapSize[0] * (tierLength - 1)
  let tierState = Computed(@() curGrowthProgress.value?[id] ?? {})
  let tierCtor = mkTierCtor(tierWidth)

  return function() {
    let { current = 0 } = tierState.value
    let progress = required == 0 ? 1 : current.tofloat() / required
    let progressObj = progress < 1
      ? gradientProgressLine(progress)
      : completedProgressLine(1, [], brightAccentColor)

    return {
      watch = tierState
      size = [tierWidth, flex()]
      children = tierCtor(progressObj, {
        size = flex()
        padding = [0, tierHeight]
        valign = ALIGN_CENTER
        children = [
          mkLabel(loc("growth/tier", { tier = index + 1 }), progressTitleStyle)
          mkLabel($"{current}/{required}", { hplace = ALIGN_RIGHT }.__update(progressTitleStyle))
        ]
      })
    }
  }
}

let mkTiersHeader = @(tiersData) {
  size = [flex(), tierHeight]
  flow = FLOW_HORIZONTAL
  children = tiersData.map(mkTier)
  gap = gapSize[0]
}

let relationsLineSize = [gapSize[0], elemNoNameSize[1]]

let function mkGrowthChain(growthElements, growthData) {
  let function mkGrowths() {
    let growths = []
    growthElements.value.each(function(growthItem) {
      if (growths.len() > 0) {
        growths.append(function() {
          let elemStatus = Computed(@() curGrowthState.value?[growthItem.id].status
            ?? GrowthStatus.UNAVAILABLE)
          return {
            watch = elemStatus
          }.__update(lineStyle[elemStatus.value](null, relationsLineSize, lineHor))
        })
      }
      growths.append(mkGrowthElement(growthItem, curTemplates.value, curSquads.value,
        growthData.value))
    })
    return growths
  }

  return @() {
    watch = [growthElements, curTemplates, curSquads, growthData]
    flow = FLOW_HORIZONTAL
    valign = ALIGN_BOTTOM
    children = mkGrowths()
  }
}

let mkCurRelationsUi = @(growthElements, growthData) @() {
  watch = [safeAreaBorders]
  size = flex()
  flow = FLOW_HORIZONTAL
  gap = largePadding
  padding = safeAreaBorders.value
  children = [
    mkInfoBlock(growthData)
    {
      size = flex()
      flow = FLOW_VERTICAL
      gap = sidePadding
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children = [
        mkGrowthChain(growthElements, growthData)
        Bordered(loc("mainmenu/btnBack"), @() curGrowthRelations(null), {
          hplace = ALIGN_CENTER
          hotkeys = [[$"^{JB.B} | Esc", { description = { skip = true }}]]
        })
      ]
    }
  ]
}

let function curGrowthViewUi() {
  let growthItem = curGrowthConfig.value?[curGrowthId.value]
  return {
    watch = [curGrowthId, curGrowthConfig, curTemplates, curSquads]
    padding = largePadding
    hplace = ALIGN_CENTER
    children = mkGrowthSlot(growthItem, curTemplates.value, curSquads.value)
  }
}

let function changeSliderExp(delta, curExp, curPos, canBuy) {
  let maxExp = curExp + canBuy
  let step = (delta * canBuy * 0.1).tointeger()
  let nexExpValue = max(curExp, curPos) + step
  let res = nexExpValue <= curExp ? curExp
    : nexExpValue >= maxExp ? maxExp
    : nexExpValue
  return res
}

let mkSliderUi = kwarg(function(sliderWatch, exp, expRequired, canBuyCount, unit, info) {
  let gainObjectWidth = expRequired == 0 ? 0 : sliderWidth * exp / expRequired
  return {
    flow = FLOW_VERTICAL
    padding = largePadding
    rendObj = ROBJ_SOLID
    color = panelBgColor
    children = [
      function() {
        let addExp = round_by_value(sliderWatch.value - exp, 1)
        let sliderTxt = $"{exp + addExp}/{expRequired}"
        return {
          watch = sliderWatch
          size = [flex(), SIZE_TO_CONTENT]
          flow = FLOW_VERTICAL
          children = [
            {
              size = [flex(), SIZE_TO_CONTENT]
              flow = FLOW_HORIZONTAL
              gap = smallPadding
              valign = ALIGN_CENTER
              children = [
                bigPriceIconExp
                mkLabel(sliderTxt, expValueStyle)
                { size = flex() }
                info
              ]
            }
            {
              size = [flex(), SIZE_TO_CONTENT]
              flow = FLOW_HORIZONTAL
              gap = smallPadding
              valign = ALIGN_CENTER
              halign = ALIGN_CENTER
              children = [
                priceIconExp
                mkLabel($"+{addExp}", progressValueStyle)
              ]
            }
          ]
        }
      }
      {
        flow = FLOW_HORIZONTAL
        gap = midPadding
        valign = ALIGN_CENTER
        children = [
          Bordered(loc("-"), @() sliderWatch(
            changeSliderExp(-1, exp, sliderWatch.value, canBuyCount)),
              smallStyle.__merge({hotkeys = [["^J:LB"]]}))
          {
            size = [sliderWidth, hdpxi(30)]
            children = Horiz(sliderWatch, {
              min = 0
              max = expRequired
              unit
              step = expRequired * 0.1
              setValue = @(v) sliderWatch(clamp(floor(v), exp, exp + canBuyCount))
              gainObject = gainObjectWidth == 0 ? null : {
                size = [gainObjectWidth, flex()]
                rendObj = ROBJ_SOLID
                color = brightAccentColor
              }
            })
          }
          Bordered(loc("+"), @() sliderWatch(
            changeSliderExp(1, exp, sliderWatch.value, canBuyCount)),
              smallStyle.__merge({hotkeys = [["^J:RB"]]}))
          Bordered(loc("growth/maxBoost"), @() sliderWatch(exp + canBuyCount),
            smallStyle.__merge({hotkeys = [["^J:X | Space"]]}))
        ]
      }
    ]
  }
})


let function scrollToSelected(growthId) {
  if (growthId != null) {
    let { col = 0 } = curGrowthConfig.value?[growthId]
    let xPos = elemSize[0] * col + gapSize[0] * col + elemSize[0] / 2 - scrollAreaWidth / 2
    tblScrollHandler.scrollToX(xPos)
  }
}

let function scrollToTier(tier) {
  if (tier != null) {
    let tierToScroll = curGrowthTiers.value[tier]
    let {from, to} = tierToScroll
    let col = from + (to - from) / 2
    let xPos = elemSize[0] * col + gapSize[0] * col + elemSize[0] / 2 - scrollAreaWidth / 2
    tblScrollHandler.scrollToX(xPos)
  }
}

let mkBuyForGoldBthUi = @(growthId, boostSlider, exp, rate)
  function() {
    let expToBuy = boostSlider.value - exp
    let spendGold = round_by_value(expToBuy.tofloat() / rate, 1)
    return {
      watch = boostSlider
      size = [flex(), hdpxi(70)]
      halign = ALIGN_RIGHT
      children = spendGold <= 0 ? null
        : currencyBtn({
            currencyId = GOLD_CURRENCY_ID
            price = spendGold
            btnText = ""
            cb = @() purchaseMsgBox({
              currencyId = GOLD_CURRENCY_ID
              price = spendGold
              title = curGrowthTitleText.value
              description = loc("growth/investGold")
              purchase = @() callGrowthBuyExp(curArmy.value, growthId, expToBuy, spendGold, buyCb)
              srcComponent = "buy_army_growth"
              alwaysShowCancel = true
            })
            style = {
              size = [pw(30), SIZE_TO_CONTENT]
              margin = 0
              padding = 0
              hotkeys = [["^J:Y | Enter"]]
            }
          })
    }
  }


let function mkCurBoostUi() {
  let boostSliderGold = Watched(0)
  let boostSliderExp = Watched(0)
  return function() {
    let res = {
      watch = [safeAreaBorders, curGrowthConfig, curGrowthState,
        curGrowthId, currenciesBalance, curGrowthFreeExp]
    }
    let growthId = curGrowthId.value
    let growthItem = curGrowthConfig.value?[growthId]
    let { exp = 0 } = curGrowthState.value?[growthId]
    let { expRequired = 0, expCost = 0 } = growthItem

    let needExp = expRequired - exp
    if (needExp <= 0 || expCost <= 0)
      return res

    let freeExp = curGrowthFreeExp.value
    let rate = expRequired.tofloat() / expCost.tofloat()
    let balance = currenciesBalance.value?[GOLD_CURRENCY_ID] ?? 0
    let canBuyCount = min(rate * balance, needExp)
    let freeExpCount = min(freeExp, needExp)
    return res.__update(
    {
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      gap = largePadding
      padding = safeAreaBorders.value
      halign = ALIGN_CENTER
      vplace = ALIGN_CENTER
      onAttach = @() updateSliders(boostSliderGold, boostSliderExp)
      children = [
        styling?.rootUpperDecor
        {
          size = [flex(), SIZE_TO_CONTENT]
          valign = ALIGN_CENTER
          children = [
            Bordered(loc("mainmenu/btnBack"), @() isBoostWndOpen(false), {
              hotkeys = [[$"^{JB.B} | Esc", { description = { skip = true }}]]
            })
            mkLabel(utf8ToUpper(loc("growth/аccelerated")),
              { hplace = ALIGN_CENTER }.__update(headerTxtStyle))
            {
              flow = FLOW_HORIZONTAL
              gap = largePadding
              hplace = ALIGN_RIGHT
              children = [ freeExpUi, currenciesWidgetUi ]
            }
          ]
        }
        mkContentHeaderUi(infoTextStyle)
        curGrowthViewUi
        {
          flow = FLOW_VERTICAL
          gap = largePadding
          children = freeExpCount > 0
            ? [
                mkSliderUi({ exp, expRequired,
                  sliderWatch = boostSliderExp,
                  canBuyCount = freeExpCount,
                  unit = 1.0 / expRequired,
                  info = freeExpUi
                })
                mkBtnUseExp(growthId, boostSliderExp, exp, boostSliderGold)
              ]
            : [
                mkSliderUi({ exp, expRequired, canBuyCount,
                  sliderWatch = boostSliderGold,
                  unit = rate / expRequired,
                  info = currenciesWidgetUi
                })
                mkBuyForGoldBthUi(growthId, boostSliderGold, exp, rate)
              ]
        }
        styling?.rootLowerDecor
      ]
    })
  }
}


let additionalWndStyle = {
  size = flex()
  rendObj = ROBJ_WORLD_BLUR_PANEL
  color = defItemBlur
}
let boostWndStyle = {
  size = flex()
  rendObj = styling.Root.rendObj
  fillColor = styling.Root.fillColor
}

curGrowthSelected.subscribe(@(v) scrollToSelected(v))


let function mkGrowthUi() {
  let growthData = mkGrowthData()

  let function checkAdditionalWnd(_v) {
    let isBoostOpen = isBoostWndOpen.value
    let relations = curGrowthRelations.value

    if (isBoostOpen) {
      removeModalWindow(RELATIONS_WND_UID)
      addModalWindow({
        key = BOOST_WND_UID
        onClick = @() null
        children = mkCurBoostUi()
      }.__update(boostWndStyle))
    }
    else if (relations != null) {
      removeModalWindow(BOOST_WND_UID)
      let growthElements = Computed(function() {
        let configs = curGrowthConfig.value
        return relations.map(@(id) configs[id])
      })
      addModalWindow({
        key = RELATIONS_WND_UID
        onClick = @() null
        children = mkCurRelationsUi(growthElements, growthData)
      }.__update(additionalWndStyle))
    }
    else {
      removeModalWindow(BOOST_WND_UID)
      removeModalWindow(RELATIONS_WND_UID)
    }
  }

  foreach (v in [curGrowthRelations, isBoostWndOpen])
    v.subscribe(checkAdditionalWnd)


  let function checkBoostStatus(_v) {
    let status = curGrowthState.value?[curGrowthId.value].status ?? GrowthStatus.UNAVAILABLE
    if (status != GrowthStatus.ACTIVE)
      isBoostWndOpen(false)
  }

  foreach (v in [curGrowthState, curGrowthId])
    v.subscribe(checkBoostStatus)


  return {
    size = flex()
    padding = [contentOffset,0,0,0]
    onAttach = function() {
      let autoSelect = reqGrowthId.value
        ?? curGrowthSelected.value
        ?? curGrowthState.value.findvalue(@(v) v.status == GrowthStatus.ACTIVE)?.id
      curGrowthId(autoSelect)
      if (scrollXPos != null) {
        tblScrollHandler.scrollToX(scrollXPos)
        scrollXPos = null
      }
      else if (growthTierToScroll.value != null) {
        scrollToTier(growthTierToScroll.value)
        growthTierToScroll(null)
      }
      else
        scrollToSelected(curGrowthId.value)
      if (reqGrowthId.value != null)
        gui_scene.resetTimeout(5, @() reqGrowthId(null))
      gui_scene.resetTimeout(0.5, @() isGrowthVisible(true))
    }
    onDetach = @() isGrowthVisible(false)
    children = {
      size = flex()
      flow = FLOW_HORIZONTAL
      gap = blocksGap
      children = [
        {
          size = [SIZE_TO_CONTENT, flex()]
          children = mkInfoBlock(growthData)
        }
        makeHorizScroll(@() {
          watch = [growthData, curGrowthTiers]
          flow = FLOW_VERTICAL
          gap = midPadding
          children = [
            mkTiersHeader(curGrowthTiers.value)
            mkGrowthTree(growthData.value)
          ]
        }, {
          size = flex()
          scrollHandler = tblScrollHandler
          rootBase = {
            behavior = Behaviors.Pannable
            wheelStep = 1
          }
        })
      ]
    }
  }
}

let function resetCurrent(_ = null) {
  if (curGrowthId.value in curGrowthConfig.value)
    return
  local growthId = curGrowthSelected.value
  if (growthId not in curGrowthConfig.value)
    growthId = curGrowthConfig.value.findindex(@(_) true)
  curGrowthId(growthId)
}

foreach (v in [curGrowthSelected, curGrowthConfig])
  v.subscribe(resetCurrent)
resetCurrent()

return mkGrowthUi