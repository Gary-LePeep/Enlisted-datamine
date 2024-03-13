from "%enlSqGlob/ui/ui_library.nut" import *

let { defTxtColor, attentionTxtColor, titleTxtColor, panelBgColor, darkPanelBgColor, darkTxtColor,
  smallPadding, midPadding, largePadding, bigPadding, sidePadding, unitSize, blockedTxtColor, isWide
} = require("%enlSqGlob/ui/designConst.nut")
let { getColorTbl, NodeElements, darkColor, lightColor, treeBgColor } = require("treeDesign.nut")
let { fontSub, fontBody, fontHeading2, fontawesome } = require("%enlSqGlob/ui/fontsStyle.nut")
let faComp = require("%ui/components/faComp.nut")
let fa = require("%ui/components/fontawesome.map.nut")
let { normal, withTooltip } = require("%ui/style/cursors.nut")
let colorize = require("%ui/components/colorize.nut")
let { addModalWindow, removeModalWindow } = require("%ui/components/modalWindows.nut")
let msgbox = require("%enlist/components/msgbox.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { Bordered, Accented } = require("%ui/components/txtButton.nut")
let mkTextRow = require("%darg/helpers/mkTextRow.nut")
let textButtonTextCtor = require("%ui/components/textButtonTextCtor.nut")
let { mkItemCurrency, mkCurrencyUi } = require("%enlist/shop/currencyComp.nut")
let { utf8ToUpper } = require("%sqstd/string.nut")
let { pPointsBaseParams, pPointsList } = require("%enlist/meta/perks/perksPoints.nut")
let { perkPointIcon, getStatDescList } = require("%enlist/soldiers/components/perksPackage.nut")
let { perksStatsCfg } = require("%enlist/meta/perks/perksStats.nut")
let perksList = require("%enlist/meta/perks/perksList.nut")
let { soldierPerks } = require("%enlist/meta/servProfile.nut")
let { curSoldierInfo } = require("%enlist/soldiers/model/curSoldiersState.nut")
let { PerkState, priceForPerk, statForPerk, hasEnoughPoints, iconForPerk, statIconForPerk,
  stateForPerk, tiersAvailable, treeForSoldier, getPerkPointsInfo, canDiscardPerk, MAX_LEVEL
} = require("perkTreePkg.nut")
let { add_perk, remove_perk, buy_soldier_exp, reset_perks, free_reroll_perks
} = require("%enlist/meta/clientApi.nut")
let { getNextLevelData, perkLevelsGrid } = require("%enlist/meta/perks/perksExp.nut")
let { txt } = require("%enlSqGlob/ui/defcomps.nut")
let mkSoldierCard = require("%enlSqGlob/ui/mkSoldierCard.nut")
let { mkColoredGradientX, mkTwoSidesGradientX } = require("%enlSqGlob/ui/gradients.nut")
let { configs } = require("%enlist/meta/configs.nut")
let { gameProfile } = require("%enlist/soldiers/model/config/gameProfile.nut")
let getPayItemsData = require("%enlist/soldiers/model/getPayItemsData.nut")
let { curCampItems, armyItemCountByTpl, curVehicle, objInfoByGuid, curSquadSoldiersInfo
} = require("%enlist/soldiers/model/state.nut")
let logPerks = require("%enlSqGlob/library_logs.nut").with_prefix("[PerksConfig] ")
let { logerr } = require("dagor.debug")
let { enlistedGold } = require("%enlist/currency/currenciesList.nut")
let { mkCurrency } = require("%enlist/currency/currenciesComp.nut")
let { maxTrainByClass } = require("%enlist/soldiers/model/config/soldierTrainingConfig.nut")
let { showTrainResearchMsg } = require("%enlist/soldiers/soldierPerksPkg.nut")
let { useSoldierLevelupOrders } = require("%enlist/soldiers/model/soldierPerks.nut")
let { getClassCfg } = require("%enlSqGlob/ui/soldierClasses.nut")
let { sound_play } = require("%dngscripts/sound_system.nut")
let { isGamepad } = require("%ui/control/active_controls.nut")
let { soundActive } = require("%ui/components/textButton.nut")
let { currencySilverUi } = require("%enlist/shop/armyCurrencyUi.nut")
let currenciesWidgetUi = require("%enlist/currency/currenciesWidgetUi.nut")
let { currenciesBalance } = require("%enlist/currency/currencies.nut")
let { mkImageCompByDargKey } = require("%ui/components/gamepadImgByKey.nut")
let mkVehicleSeats = require("%enlSqGlob/squad_vehicle_seats.nut")
let modalPopupWnd = require("%ui/components/modalPopupWnd.nut")

const WND_UID = "perkTree"
const POPUP_UID = "perkList"
let close = @() removeModalWindow(WND_UID)

let defTxtStyle     = { color = defTxtColor       }.__update(fontSub)
let priceTxtStyle   = { color = attentionTxtColor }.__update(fontSub)
let titleTxtStyle   = { color = titleTxtColor     }.__update(fontHeading2)
let lineColor       = mul_color(lightColor, 0.4)

let textButtonColorStyle = @(sf)
  (sf & S_ACTIVE) ? defTxtColor
  : (sf & S_HOVER) ? darkTxtColor
  : defTxtColor

let msgBoxTextColorStyle = @(sf) sf & S_HOVER ? darkTxtColor : defTxtColor

const PERK_CHANGE_CURRENCY = "enlisted_silver"
const LEVEL_UP_ORDER = "soldier_levelup_order"

let PERK_ICON_SIZE = isWide ? unitSize * 2 : unitSize * 1.8
let COLUMN_GAP = largePadding
let VERTICAL_GAP = isWide ? largePadding : midPadding
let BIGGER_GAP = unitSize * 0.8
let MEDIUM_GAP = unitSize * (isWide ? 0.5 : 0.2)

let COLUMN_WIDTH = (unitSize * 8).tointeger()
let soldierCardSize = [(8 * unitSize).tointeger(), (1.8 * unitSize).tointeger()]

let separatorBgColor = Color(88, 39, 39)
let tooltipHeaderColor = Color(36, 40, 46)
let tooltipBodyColor = Color(43, 50, 56)

let perkSchemes = Computed(@() configs.value?.perkSchemes ?? {})
let perkCancelCost = Computed(@() gameProfile.value?.perkCancelCost ?? 0)

let selectedPerk = Watched(null)


const NUM_TIERS = 3
let perkTreeTbl = @(configsVal) (configsVal?.perkTrees ?? {}).map(function(perkIdList) {
  let res = []
  for (local tier = 1; tier <= NUM_TIERS; ++tier)
    res.append({
      tier
      perks = pPointsList.reduce(@(tbl, slotName) tbl.rawset(slotName, []), {})
    })

  foreach (perkId in perkIdList) {
    if (perkId not in perksList.value) {
      logerr($"Perk {perkId} not found in perk_list config")
      continue
    }
    if (perksList.value[perkId].cost.len() == 0)
      continue // starter perk with cost == 0

    let perkDesc = clone perksList.value[perkId]
    perkDesc.tier <- perkDesc.tier ?? 1
    perkDesc.perkId <- perkId
    let stat = statForPerk(perkDesc)
    let perksByTierList = res[perkDesc.tier - 1].perks[stat]

    if (perksByTierList.findindex(@(v) v.perkId == perkId) != null) {
      logerr($"Duplicated {perkId} in the tree")
      continue
    }
    perksByTierList.append(perkDesc)
  }
  return res
})


let soundAddPerk = @(isMaximum)
  @(_) sound_play(isMaximum ? "ui/perk_max" : "ui/perk_add")

let soundBuyLevel = @(_) sound_play("ui/debriefing/squad_star")

let btnParams = {
  size = [flex(), SIZE_TO_CONTENT]
}

let buyLevelMsgBox = @(content) {
  size = [sw(90), fsh(32)]
  children = [
    {
      flow = FLOW_HORIZONTAL
      hplace = ALIGN_RIGHT
      vplace = ALIGN_TOP
      valign = ALIGN_CENTER
      gap = midPadding
      children = [
        mkCurrencyUi(LEVEL_UP_ORDER)
        currenciesWidgetUi
      ]
    }
    {
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      size = flex()
      children = content
    }
  ]
}

let priceText = @(locId, orderData = null, goldData = null, colorStyle = textButtonColorStyle)
  function(_textField, params, handler, group, sf) {
    let txtStyle = { color = colorStyle(sf) }.__update(fontBody)
    return textButtonTextCtor({
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      margin = [hdpx(10), hdpx(20)]
      children = mkTextRow(loc(locId),
        @(t) txt(t).__update(txtStyle),
        {
          ["{price}"] = { //warning disable: -forgot-subst
            flow = FLOW_HORIZONTAL
            valign = ALIGN_CENTER
            gap = {
              padding = bigPadding
              children = txt(loc("mainmenu/or")).__update(txtStyle)
            }
            children = [
              orderData == null ? null
                : mkItemCurrency({
                    currencyTpl = orderData.currencyTpl
                    count = orderData.count
                    textStyle = txtStyle
                  })
              goldData == null ? null
                : mkCurrency({
                    currency = enlistedGold
                    price = goldData.count
                    txtStyle
                  })
            ]
          }
        }
      )
    }, params, handler, group, sf)
  }

let mkUseLevelUpOrderBtn = @(payData) {
  text = ""
  action = function() {
    let { guid } = curSoldierInfo.value
    useSoldierLevelupOrders(guid, payData)
  }
  customStyle = {
    // message box uses old textButton so the custom constructor defined in customStyle
    textCtor = priceText("perks/buyLevel", { count = 1, currencyTpl = LEVEL_UP_ORDER }, null,  msgBoxTextColorStyle)
    textMargin = [hdpx(10), hdpx(20)]
    hotkeys = [["^J:X"]]
  }
}

let mkBuyLevelGoldBtn = @(payData) {
  text = ""
  action = payData.action
  customStyle = {
    // message box uses old textButton so the custom constructor defined in customStyle
    textCtor = priceText("perks/buyLevel", null, { count = payData.cost }, msgBoxTextColorStyle)
    textMargin = [hdpx(10), hdpx(20)]
    hotkeys = payData?.hotkeys ?? [["^J:Y"]]
  }
}

let buyLevelBtnParams = function(soldier, perksCfgVal, perkLevelsGridVal, currenciesBalanceVal) {
  let { exp = 0, stepsLeft = 1 } = perksCfgVal
  let { level } = soldier
  let maxLevel = perkLevelsGridVal.MAX_LEVEL
  if (level == maxLevel)
    return null

  let ordersReq = 1
  let ordersCount = armyItemCountByTpl.value?[LEVEL_UP_ORDER] ?? 0
  let orderPayData = ordersReq > ordersCount
    ? null
    : getPayItemsData({ [LEVEL_UP_ORDER] = ordersReq }, curCampItems.value)
  let nextLevelData = getNextLevelData({
    level
    maxLevel
    exp
    lvlsCfg = perkLevelsGridVal
  })

  if (nextLevelData == null && orderPayData == null)
    return null

  let priceTextCtor = priceText("perks/buyLevel", orderPayData == null ? null : {
      count = ordersReq,
      currencyTpl = LEVEL_UP_ORDER
    }, orderPayData != null || nextLevelData == null ? null : {
      count = nextLevelData.cost
    })


  let action = function() {
    let notEnoughMoney = (nextLevelData?.cost ?? 0) - (currenciesBalanceVal?[enlistedGold.id] ?? 0)

    if (notEnoughMoney > 0 && orderPayData == null) {
      msgbox.showMessageWithContent({
        content = buyLevelMsgBox({
          flow = FLOW_HORIZONTAL
          children = mkTextRow(loc("shop/notEnoughCurrency"),
            @(t) txt(t).__update(fontBody, { color = attentionTxtColor }), {
            ["{priceDiff}"] = mkCurrency({ //warning disable: -forgot-subst
              currency = enlistedGold
              price = notEnoughMoney
            })
          })
        })
      })
      return
    }

    let buttons = []
    if (orderPayData != null)
      buttons.append(mkUseLevelUpOrderBtn(orderPayData))
    buttons.append(
      mkBuyLevelGoldBtn({
        action = @() buy_soldier_exp(perksCfgVal.guid,
          nextLevelData?.exp ?? 0, nextLevelData?.cost ?? 0, soundBuyLevel)
        cost = nextLevelData?.cost ?? 0
        hotkeys = [["^J:Y | Enter"]]
      }),
      {
        text = loc("Cancel")
        isCancel = true
        customStyle = { hotkeys = [[$"^{JB.B} | Esc"]] }
      }
    )

    msgbox.showMessageWithContent({
      uid = "buySoldierLevelMsgBox"
      content = buyLevelMsgBox({
        flow = FLOW_VERTICAL
        halign = ALIGN_CENTER
        children = [
          {
            vplace = ALIGN_TOP
            margin = largePadding
            rendObj = ROBJ_TEXT
            text = loc("soldierLevel", { level })
            color = attentionTxtColor
          }.__update(fontHeading2)
          {
            flow = FLOW_HORIZONTAL
            valign = ALIGN_BOTTOM
            children = mkTextRow(loc("buy/soldierLevelStats", { count = stepsLeft }),
              @(t) txt(t).__update(fontBody, { color = titleTxtColor }),
              { ["{countColorized}"] = //warning disable: -forgot-subst
                {
                  rendObj = ROBJ_TEXT
                  text = stepsLeft
                  color = attentionTxtColor
                }.__update(fontHeading2)
              })
          }
          {
            rendObj = ROBJ_TEXT
            text = loc("buy/soldierLevelConfirm")
            color = titleTxtColor
          }.__update(fontBody)
        ]
      })
      buttons
    })
  }

  return { priceTextCtor, cost = nextLevelData?.cost ?? 0, action }
}


let mkBuyLevelBtn = @(soldier, soldierPerksCfg) function() {
  let buyLevelData = buyLevelBtnParams(soldier, soldierPerksCfg,
    perkLevelsGrid.value, currenciesBalance.value)
  return {
    watch = [perkLevelsGrid, currenciesBalance, armyItemCountByTpl]
    children = buyLevelData
      ? Bordered(buyLevelData.priceTextCtor, buyLevelData.action, btnParams)
      : null
  }
}

let clickBuy = function(soldier, soldierPerksCfg, hasPoints, buyCb) {
  if (hasPoints) {
    buyCb()
    return
  }

  let { sClass, tier } = soldier
  let maxTier = sClass in maxTrainByClass.value ? maxTrainByClass.value[sClass] + 1 : tier

  let buttons = []
  let ordersReq = 1
  let ordersCount = armyItemCountByTpl.value?[LEVEL_UP_ORDER] ?? 0
  let payData = ordersReq > ordersCount
    ? null
    : getPayItemsData({ [LEVEL_UP_ORDER] = ordersReq }, curCampItems.value)
  if (tier < MAX_LEVEL && payData != null)
    buttons.append(mkUseLevelUpOrderBtn(payData))

  if (tier < maxTier) {
    let buyLevelData = buyLevelBtnParams(
      soldier, soldierPerksCfg, perkLevelsGrid.value, currenciesBalance.value)
    if (buyLevelData)
      buttons.append(mkBuyLevelGoldBtn(buyLevelData))
  }
  else if (tier < MAX_LEVEL)
    buttons.append({
      text = loc("perks/buyLevel", { price = "" })
      action = @() showTrainResearchMsg(soldier, close)
      customStyle = { hotkeys = [["^J:Y"]] }
    })

  buttons.append({
    text = buttons.len() == 0 ? loc("Close") : loc("Cancel")
    isCurrent = true
    customStyle = { hotkeys = [[ $"^{JB.B}" ]] }
  })

  msgbox.show({
    text = loc(tier < MAX_LEVEL ? "perks/notEnoughPoints" : "perks/notEnoughPointsMaxLevel")
    buttons
  })
}

let isUnlockMaximum = @(perkData, perks)
  max(1, perkData.available) == (perks?[perkData.perkId] ?? 0) + 1

let unlockPerkCb = function(perkData) {
  if (curSoldierInfo.value == null)
    return

  let { guid } = curSoldierInfo.value
  let perksCfg = soldierPerks.value?[guid] ?? {}
  let pointInfo = getPerkPointsInfo(perksList.value, perksCfg)
  let hasPoints = hasEnoughPoints(pointInfo, perkData)
  let sound = soundAddPerk(isUnlockMaximum(perkData, perksCfg.perks))
  clickBuy(curSoldierInfo.value, perksCfg,
    hasPoints, @() add_perk(guid, perkData.perkId, sound))
}

let mkTrainBtn = @(soldier) Bordered(loc("perks/buyLevel", { price = "" }),
  @() showTrainResearchMsg(soldier, close), btnParams)


let unlockedPoints = @(taken, available, color, font, fillColor, borderColor = null)
  {
    vplace = ALIGN_BOTTOM
    rendObj = ROBJ_BOX
    borderWidth = hdpxi(1)
    borderRadius = hdpx(3)
    borderColor = borderColor ?? color
    fillColor
    padding = [0, midPadding]
    children = available == 0
      ? {
          rendObj = ROBJ_TEXT
          text = fa["check"]
          color
        }.__update(fontawesome)
      : {
          rendObj = ROBJ_TEXT
          text = $"{taken}/{available}"
          color
        }.__update(font)
  }

let discardHigherTierMsg = @() msgbox.show({
  text = loc("perks/errorDiscardFirstTier")
  buttons = [{ text = loc("Ok"), isCurrent = true }]
})

let notEnoughCurrencyMsg = @(count) msgbox.show({
  text = ""
  children = {
    flow = FLOW_HORIZONTAL
    children = mkTextRow(loc("shop/notEnoughCurrency"),
      @(t) txt(t).__update(fontBody),
      {
        ["{priceDiff}"] = mkItemCurrency({ //warning disable: -forgot-subst
            currencyTpl = PERK_CHANGE_CURRENCY
            count
            textStyle = fontBody
          })
      })
  }
  buttons = [{ text = loc("Ok"), isCurrent = true }]
})

let removePerkOrProcessError = function(guid, selectedPerkVal, armyItemCountByTplVal) {
  let ordersInStock = armyItemCountByTplVal?[PERK_CHANGE_CURRENCY] ?? 0
  let price = priceForPerk(selectedPerkVal)
  let total = price * perkCancelCost.value
  let payItems = getPayItemsData({ [PERK_CHANGE_CURRENCY] = total }, curCampItems.value)
  if (payItems == null) {
    notEnoughCurrencyMsg(total - ordersInStock)
    return
  }
  remove_perk(guid, selectedPerkVal.perkId, payItems, @(_) sound_play("ui/perk_remove"))
}

let perkIconBtn = function(perkData, takenPoints, isTierAvailable, canUnlock, tooltip) {
  let isSelected = Computed(@() selectedPerk.value?.perkId == perkData.perkId)
  let { icon, color } = iconForPerk(perkData)
  let colorFn = getColorTbl(isTierAvailable, takenPoints, max(1, perkData.available))

  return watchElemState(function(sf) {
    let btnColors = colorFn(color, (sf & S_HOVER) || isSelected.value)
    return withTooltip({
      watch = isSelected
      size = [PERK_ICON_SIZE, PERK_ICON_SIZE]
      behavior = Behaviors.Button
      sound = soundActive
      skipDirPadNav = false
      onClick = function(mouseEvent) {
        if (isGamepad.value) {
          if (takenPoints < perkData.available)
            unlockPerkCb(perkData)
          return
        }
        if (mouseEvent.ctrlKey) {
          selectedPerk(perkData)
          let { guid = "" } = curSoldierInfo.value
          let perksCfg = soldierPerks.value?[guid] ?? {}
          if (canDiscardPerk(perksList.value, perksCfg, perkData))
            removePerkOrProcessError(perksCfg.guid, perkData, armyItemCountByTpl.value)
          else
            discardHigherTierMsg()

          return
        }
        selectedPerk(perkData)
      }
      onDoubleClick = function() {
        if (takenPoints < perkData.available)
          unlockPerkCb(perkData)
      }
      onHover = function(_) {
        if (isGamepad.value)
          selectedPerk(perkData)
      }
      halign = ALIGN_CENTER
      children = [
        {
          rendObj = ROBJ_BOX
          borderRadius = hdpx(5)
          borderWidth = hdpxi(2)
          borderColor = darkColor
          fillColor = btnColors[NodeElements.OUTER]
          valign = ALIGN_CENTER
          halign = ALIGN_CENTER
          padding = smallPadding
          size = SIZE_TO_CONTENT
          children = {
            rendObj = ROBJ_BOX
            size = SIZE_TO_CONTENT
            borderRadius = hdpx(3)
            borderColor = darkColor
            borderWidth = (sf & S_HOVER) || isSelected.value ? hdpxi(2) : 0
            halign = ALIGN_CENTER
            valign = ALIGN_TOP
            fillColor = btnColors[NodeElements.INNER]
            padding = [smallPadding, smallPadding, midPadding, smallPadding]
            children = perkPointIcon(icon, btnColors[NodeElements.ICON], hdpxi(isWide ? 62 : 56))
          }
        }
        unlockedPoints(takenPoints, perkData.available,
          btnColors[NodeElements.POINTS_TEXT],
          fontSub,
          btnColors[NodeElements.POINTS_BG],
          canUnlock && !(sf & S_HOVER) ? lightColor : btnColors[NodeElements.POINTS_BORDER])
      ]
    }, tooltip)
  })
}

let descriptionComp = @(text) {
  rendObj = ROBJ_TEXTAREA
  size = [flex(), SIZE_TO_CONTENT]
  behavior = Behaviors.TextArea
  halign = ALIGN_CENTER
  padding = midPadding
  text
}.__update(defTxtStyle)

let mkDescription = function(perksStatsCfgVal, perkCfg, taken, available) {
  let statConfig = perkCfg.stats.map(@(value) value * taken.tofloat() / max(1, available).tofloat())
  let text = "\n".join(getStatDescList(perksStatsCfgVal, { stats = statConfig }, false))
  return descriptionComp(text)
}


let tooltipStyle = {
  color = titleTxtColor
  margin = [midPadding, largePadding]
  halign = ALIGN_LEFT
}

let nextLevelHint = {
  rendObj = ROBJ_BOX
  size = [flex(), SIZE_TO_CONTENT]
  fillColor = tooltipHeaderColor
  padding = [midPadding, largePadding]
  children = txt(utf8ToUpper(loc("perks/nextLevelEffect")))
    .__update(priceTxtStyle)
  borderWidth = [hdpxi(1), hdpxi(1), 0, hdpxi(1)]
  borderColor = treeBgColor
}

let shortcutHintConsole = {
  flow = FLOW_HORIZONTAL
  gap = midPadding
  valign = ALIGN_CENTER
  children = [
    mkImageCompByDargKey(JB.A, { hplace = ALIGN_LEFT })
    txt(loc("perks/unlock")).__update(defTxtStyle)
  ]
}

let shortcutHint = {
  rendObj = ROBJ_TEXT
  text = loc("perks/doubleClick")
}.__update(defTxtStyle)

let discardShortcutHint = {
  rendObj = ROBJ_TEXT
  text = loc("perks/CtrlClick")
}.__update(defTxtStyle)

let mkPerkTooltip = @(perksStatsCfgVal, perkCfg, takenPoints,
    pointsPossible, isListView = false) function() {
  let showPoints = isListView ? takenPoints : 1 + takenPoints
  let hint = mkDescription(perksStatsCfgVal, perkCfg,
      min(showPoints, pointsPossible), pointsPossible).__update(tooltipStyle)
  return {
    rendObj = ROBJ_BOX
    flow = FLOW_VERTICAL
    minWidth = (unitSize * 7).tointeger()
    fillColor = tooltipBodyColor
    borderWidth = hdpxi(1)
    borderColor = treeBgColor
    children = isListView
      ? hint
      : [
          takenPoints < pointsPossible ? nextLevelHint : null
          hint
          @() {
            watch = isGamepad
            flow = FLOW_VERTICAL
            padding = [midPadding, largePadding]
            children = [
              takenPoints >= pointsPossible ? null
                : isGamepad.value ? shortcutHintConsole
                : shortcutHint,
              (takenPoints > 0 && !isGamepad.value) ? discardShortcutHint : null,
            ]
          }
        ]
  }
}

const PERKS_PER_ROW = 3

let mkTier = function(perksStatsCfgVal, perksListVal,
    perkListByStat, soldierPerkData, isTierAvailable, pointsInfo) {
  let bigRow = perkListByStat.findindex(@(perks) perks.len() > PERKS_PER_ROW) != null
  let rows = bigRow ? 2 : 1
  let vGap = unitSize * 0.4
  let hGap = unitSize * 0.5
  let children = pPointsList.map(@(statId) {
    size = [flex(), (PERK_ICON_SIZE * rows + vGap * (rows - 1)).tointeger() ]
    valign = ALIGN_TOP
    halign   = ALIGN_CENTER
    children = wrap(
      perkListByStat[statId].map(function(perkData) {
        let { perkId, available } = perkData
        let pointsTaken = soldierPerkData?[perkId] ?? 0
        let canUnlock = isTierAvailable && pointsTaken < available
          && hasEnoughPoints(pointsInfo, perkData)

        let pointsPossible = max(available, 1)
        let tooltip = mkPerkTooltip(perksStatsCfgVal, perksListVal?[perkId],
          pointsTaken,
          pointsPossible)
        return perkIconBtn(perkData, pointsTaken, isTierAvailable, canUnlock, tooltip)
      }),
      {
        width  = COLUMN_WIDTH
        halign = ALIGN_CENTER
        hGap
        vGap
      })
  })

  return {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    gap = COLUMN_GAP
    children
  }
}

let headerIconSize = hdpxi(45)
let pointsAnimationState = { guid = null, points = {} }
let addPointsAnimation = {
  opacity = 0
  transform = {}
  animations = [
    { prop = AnimProp.opacity, from = 0.2, to = 1, duration = 0.3,
      play = true, easing = InOutCubic }
    { prop = AnimProp.opacity, from = 1, to = 1, duration = 0.4,
      play = true, easing = InOutCubic, delay = 0.3}
    { prop = AnimProp.opacity, from = 1, to = 0, duration = 0.35,
      play = true, easing = InOutCubic, delay = 0.7 }
    { prop = AnimProp.translate, from = [hdpx(20), hdpx(50)], to = [hdpx(20), hdpx(20)],
      play = true, easing = OutCubic, duration = 1 }
  ]
}

let oldPointsAnimations = [
  { prop = AnimProp.opacity, from = 0.2, to = 1, duration = 0.2
    play = true, easing = InOutCubic }
  { prop = AnimProp.scale, from = [3.5,3.5], to = [1,1],
    play = true, easing = InOutCubic, duration = 1 }
]

let improvementRates = {
  weapon = 0.5
  vitality = 1
  speed = 0.5
}

let headerTooltip = @(statName, points, totalPoints) {
  rendObj = ROBJ_BOX
  fillColor = tooltipBodyColor
  borderWidth = hdpxi(1)
  borderColor = treeBgColor
  padding = largePadding
  gap = midPadding
  flow = FLOW_VERTICAL
  children = [
    {
      rendObj = ROBJ_TEXTAREA
      behavior = Behaviors.TextArea
      color = titleTxtColor
      text = loc($"perks/{statName}_hint", {
        rate = colorize(attentionTxtColor, "{0}%".subst(
          improvementRates[statName] * max(0, totalPoints)))
      })
    }.__update(fontSub)
    {
      rendObj = ROBJ_TEXTAREA
      behavior = Behaviors.TextArea
      color = titleTxtColor
      text = loc("perks/tree/pointsTooltip", {
        points = colorize(attentionTxtColor, max(0, points))
        totalPoints = colorize(attentionTxtColor, totalPoints)
      })
    }.__update(fontSub)
  ]
}

let lineCmp = {
  rendObj = ROBJ_SOLID
  size = [flex(), hdpxi(1)]
  color = lineColor
}

let treeHeader = function(perksListVal, perksCfg) {
  let { total, used } = getPerkPointsInfo(perksListVal, perksCfg)

  if (pointsAnimationState.guid != perksCfg.guid) {
    pointsAnimationState.guid = perksCfg.guid
    pointsAnimationState.points = clone total
  }

  let headers = pPointsList.map(function(statName) {
    let usedPoints = used?[statName] ?? 0
    // some premium soldiers have more perks than total points
    // show negative number in this case so the player knows
    let totalPoints = total[statName]
    let points = totalPoints - usedPoints
    let justChanged = totalPoints - (pointsAnimationState.points?[statName] ?? totalPoints)
    let { icon, color } = pPointsBaseParams[statName]
    let pointsAnimation = {
      transform = {}
      animations = justChanged > 0 ? oldPointsAnimations : null
    }

    return withTooltip({
      flow = FLOW_VERTICAL
      halign = ALIGN_CENTER
      size = [flex(), SIZE_TO_CONTENT]
      gap = smallPadding
      skipDirPadNav = false
      children = [
        {
          rendObj = ROBJ_IMAGE
          size = [headerIconSize, headerIconSize]
          image = Picture("{0}:{1}:{1}:K".subst(icon, headerIconSize))
          color
        }
        {
          flow = FLOW_HORIZONTAL
          gap = smallPadding
          children = [
            txt(utf8ToUpper(loc($"perks/{statName}_title"))).__update(titleTxtStyle)
            txt(totalPoints).__update(titleTxtStyle, { color })
          ]
        }
        txt(loc("perks/tree/unallocated")).__update(priceTxtStyle)
        {
          flow = FLOW_HORIZONTAL
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          size = [flex(), SIZE_TO_CONTENT]
          padding = [smallPadding, (unitSize * 1.2).tointeger()]
          gap = midPadding
          children = [
            lineCmp
            {
              key = $"{statName}_{points}"
              children = [
                {
                  rendObj = ROBJ_BOX
                  padding = [smallPadding, largePadding]
                  borderWidth = hdpxi(1)
                  borderRadius = hdpxi(3)
                  borderColor = attentionTxtColor
                  children = {
                    rendObj = ROBJ_TEXT
                    text = points
                    skipDirPadNav = false
                  }.__update(priceTxtStyle, fontBody, pointsAnimation)
                }
                justChanged == 0 ? null : {
                  rendObj = ROBJ_TEXT
                  text = $"+{justChanged}"
                  halign = ALIGN_RIGHT
                }.__update(priceTxtStyle, fontBody, addPointsAnimation)
              ]
            }
            lineCmp
          ]
        }
      ]
    },
    @() headerTooltip(statName, points, totalPoints))
  })

  pointsAnimationState.points = clone total
  return {
    flow = FLOW_HORIZONTAL
    size = [flex(), SIZE_TO_CONTENT]
    gap = COLUMN_GAP
    children = headers
  }
}

let gradientLeft = mkColoredGradientX({
  colorLeft=0x00000000, colorRight=separatorBgColor, width=28
})
let gradientRight = mkColoredGradientX({
  colorLeft=separatorBgColor, colorRight=0x00000000, width=28
})
let twoSideGradient = mkTwoSidesGradientX({
  centerColor = 0x77FFFFFF, sideColor = 0x05FFFFFF, isAlphaPremultiplied = false
})

let gradientCmp = @(image, size) {
  rendObj = ROBJ_IMAGE
  size
  image
}

let separatorComp = function(tierInfo) {
  let res = {
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    size = [flex(), midPadding * 2 + fontSub.fontSize]
    flow = FLOW_HORIZONTAL
    gap = midPadding
  }

  if (tierInfo.available)
    return res.__update({
      children = gradientCmp(twoSideGradient, [flex(), smallPadding])
    })

  return res.__update({
    children = [
      gradientCmp(gradientLeft, flex())
      {
        rendObj = ROBJ_BOX
        borderRadius = hdpx(3)
        borderColor = lineColor
        borderWidth = hdpxi(1)
        fillColor = separatorBgColor
        padding = [smallPadding, midPadding]
        flow = FLOW_HORIZONTAL
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        children = [
          faComp("lock", {
            size = [hdpxi(18), hdpxi(18)]
            fontSize = defTxtStyle.fontSize
            color = titleTxtColor
            halign = ALIGN_CENTER
          })
          tierInfo?.header
        ]
      }
      gradientCmp(gradientRight, flex())
    ]
  })
}

let columnBackground = {
  flow = FLOW_HORIZONTAL
  gap  = COLUMN_GAP
  size = flex()
  children = array(3).map(@(_) {
    rendObj = ROBJ_BOX
    fillColor = treeBgColor
    size = flex()
  })
}

let mkTree = function(perkTree, soldierWatch) {
  if (perkTree == null)
    return null

  return function() {
    let perksCfg = soldierPerks.value?[soldierWatch.value?.guid] ?? {}
    let pointsInfo = getPerkPointsInfo(perksList.value, perksCfg)

    let tierInfo = soldierWatch.value == null
      ? tiersAvailable(0, {}, true)
      : tiersAvailable(soldierWatch.value?.level ?? 1, pointsInfo.used)

    let tiers = []

    foreach (tierConfig in perkTree) {
      tiers.append(mkTier(perksStatsCfg.value, perksList.value, tierConfig.perks,
        perksCfg?.perks ?? {}, tierInfo[tierConfig.tier].available, pointsInfo))
      if (tierConfig.tier < perkTree.len())
        tiers.append(separatorComp(tierInfo[tierConfig.tier + 1]))
    }

    let children = [treeHeader(perksList.value, perksCfg)].extend(tiers)
    return {
      watch = [soldierWatch, soldierPerks, perksList, perksStatsCfg]
      size = [flex(), SIZE_TO_CONTENT]
      children = [
        columnBackground
        {
          flow = FLOW_VERTICAL
          size = [flex(), SIZE_TO_CONTENT]
          gap = VERTICAL_GAP
          padding = [isWide ? BIGGER_GAP : midPadding, 0]
          children
        }
      ]
    }
  }
}


let findFirstPerk = function(perkTree, soldier, soldierPerksVal) {
  let { perksCfg = {} } = soldierPerksVal?[soldier?.guid] ?? {}

  foreach (tierCfg in perkTree) {
    foreach (statId in pPointsList) {
      let list = tierCfg.perks?[statId] ?? []
      let firstPerk = list.findvalue(@(v) v.perkId not in perksCfg?.perks)
      if (firstPerk != null)
        return firstPerk
    }
  }
  return null
}

let lockedPerkCmp = @(text) {
  size = [flex(), SIZE_TO_CONTENT]
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  halign = ALIGN_CENTER
  text = utf8ToUpper(text)
  padding = MEDIUM_GAP
  margin = [MEDIUM_GAP, 0]
  color = attentionTxtColor
}.__update(fontBody)


let PRICE_ICON_SIZE = hdpxi(25)
let blockedPointsColor = { color = blockedTxtColor }

let priceCmp = function(selectedPerkVal, hasPoints, canGet = true) {
  let price = priceForPerk(selectedPerkVal)
  if (price == 0)
    return lockedPerkCmp(loc("perks/starter")).__update({
      halign = ALIGN_CENTER
    })

  let text = canGet ? loc("perks/obtain") : loc("perks/cost")
  let { icon, color } = statIconForPerk(selectedPerkVal)
  return {
    flow = FLOW_HORIZONTAL
    valign = ALIGN_BOTTOM
    padding = midPadding
    children = [
      txt(text).__update(defTxtStyle)
      { size = [midPadding, hdpx(1)] }
      txt(price).__update(priceTxtStyle, fontBody, hasPoints ? {} : blockedPointsColor)
      {
        rendObj = ROBJ_IMAGE
        size = [PRICE_ICON_SIZE, PRICE_ICON_SIZE]
        image = Picture("{0}:{1}:{1}:K".subst(icon, PRICE_ICON_SIZE))
        color
      }
    ]
  }
}

let availablePerk = @(soldier, perksCfg, hasPoints, buyCb) Accented(
  utf8ToUpper(loc("perks/unlock")),
  @() clickBuy(soldier, perksCfg, hasPoints, buyCb),
  {
    size = [flex(), SIZE_TO_CONTENT]
    hotkeys = [[ "^J:X | Enter", { description = { skip = true }} ]]
  })

let unlockedPerk = function(perkListVal, perksCfg,
    selectedPerkVal, armyItemCountByTplVal, cancelCost) {
  let price = priceForPerk(selectedPerkVal)
  let total = price * cancelCost

  let action = canDiscardPerk(perkListVal, perksCfg, selectedPerkVal)
    ? @() removePerkOrProcessError(perksCfg.guid, selectedPerkVal, armyItemCountByTplVal)
    : discardHigherTierMsg

  let buttonParams = {
    size = [flex(), SIZE_TO_CONTENT]
    hotkeys = [[ "^J:Y", { description = { skip = true }} ]]
  }

  let text = @(_textField, params, handler, group, sf) textButtonTextCtor({
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    children = mkTextRow(loc("perks/discard"),
      @(t) txt(t).__update({
        color = textButtonColorStyle(sf)
      }, fontBody),
      {
        ["{price}"] = mkItemCurrency({ //warning disable: -forgot-subst
          currencyTpl = PERK_CHANGE_CURRENCY
          count = total
          textStyle = {
            color = textButtonColorStyle(sf)
          }.__update(fontBody)
        })
      })
  }, params, handler, group, sf)
  return Bordered(text, action, buttonParams)
}

let iconSize = [
  (unitSize * 0.8).tointeger(),
  (unitSize * 0.3).tointeger()
]

let nextLevelIcon = {
  rendObj = ROBJ_IMAGE
  size = iconSize
  image = Picture("ui/skin#arrow_next_lvl.svg:{0}:{1}:K".subst(iconSize[0], iconSize[1]))
  color = attentionTxtColor
}

let lineNextLevel = lineCmp.__merge({ margin = [COLUMN_GAP, MEDIUM_GAP] })

let nextLevelCmp = {
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  children = [
    lineNextLevel
    {
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      gap = midPadding
      children = [
        nextLevelIcon
        txt(utf8ToUpper(loc("perks/nextLevelEffect"))).__update(defTxtStyle)
        nextLevelIcon
      ]
    }
    lineNextLevel
  ]
}

let perkEffectDetails = function(perksListVal, perksStatsCfgVal, perksCfg, perkData) {
  // computes stats when a perk has partial value:
  // 1 of 3 available = 33% of the base power, 3 / 3 = 100% etc
  // perksListVal: perkId => list of stats
  // perksStatsCfgVal: statId => base_power value
  // statConfig stores the value based on taken points: 0.33, 0.66 etc to create text description
  let { perkId, available } = perkData
  let perkCfg = perksListVal?[perkId]
  if (perkCfg == null)
    return null

  let pointsPossible = max(available, 1)
  let taken = perksCfg?.perks[perkId] ?? 0
  let children = []

  if (taken > 0) {
    children.append(mkDescription(perksStatsCfgVal, perkCfg, taken, pointsPossible))
  }
  if (taken != pointsPossible) {
    children.append(nextLevelCmp)
    children.append(mkDescription(perksStatsCfgVal, perkCfg, taken + 1, pointsPossible))
  }

  return {
    flow = FLOW_VERTICAL
    size = [flex(), SIZE_TO_CONTENT]
    halign = ALIGN_CENTER
    gap = BIGGER_GAP
    children
  }
}

let mkSelectedPerk = @(soldierWatch) function() {
  if (selectedPerk.value == null || soldierWatch.value == null)
    return { watch = selectedPerk }

  let { icon, color } = iconForPerk(selectedPerk.value)
  let { guid = "", level = 1 } = soldierWatch.value
  let perksCfg = soldierPerks.value?[guid] ?? {}
  if (perksCfg.len() == 0) {
    logPerks($"Perk structure empty for {guid}")
    return { watch = [selectedPerk, soldierWatch, soldierPerks] }
  }

  let { perkId, available, tier } = selectedPerk.value
  let taken = perksCfg?.perks[perkId] ?? 0

  let pointInfo = getPerkPointsInfo(perksList.value, perksCfg)
  let tierInfo = tiersAvailable(level, pointInfo.used)

  let state = stateForPerk(!tierInfo[tier].available, available, taken)
  let hasPoints = hasEnoughPoints(pointInfo, selectedPerk.value)

  let isStarter = priceForPerk(selectedPerk.value) == 0
  let isLocked = state == PerkState.LOCKED || isStarter
  let canBuy = !isStarter && (state == PerkState.AVAILABLE || state == PerkState.UNLOCKED_PART)
  let canRemove = !isStarter && state != PerkState.LOCKED && state != PerkState.AVAILABLE

  let sound = soundAddPerk(isUnlockMaximum(selectedPerk.value, perksCfg.perks))
  return {
    watch = [soldierWatch, selectedPerk, perksList, perksStatsCfg, soldierPerks]
    size = [COLUMN_WIDTH, flex()]
    children = [
      {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_VERTICAL
        gap = BIGGER_GAP
        halign = ALIGN_CENTER
        padding = [unitSize * 0.5, 0]
        children = [
          {
            size = [(unitSize * 2.2).tointeger(), (unitSize * 2.5).tointeger()]
            halign = ALIGN_CENTER
            children = [
              {
                rendObj = ROBJ_BOX
                valign = ALIGN_TOP
                borderColor = color
                borderWidth = hdpxi(3)
                borderRadius = hdpx(4)
                fillColor = darkColor
                padding = midPadding
                children = perkPointIcon(icon, color, (unitSize * 1.8).tointeger())
              }
              unlockedPoints(taken, available, color, fontBody, darkColor)
            ]
          }
          perkEffectDetails(perksList.value, perksStatsCfg.value, perksCfg, selectedPerk.value)
          canRemove ? @() {
            watch = [armyItemCountByTpl, perkCancelCost]
            size = [flex(), SIZE_TO_CONTENT]
            children = unlockedPerk(perksList.value, perksCfg, selectedPerk.value,
              armyItemCountByTpl.value, perkCancelCost.value)
          } : null
        ]
      }
      {
        vplace = ALIGN_BOTTOM
        flow = FLOW_VERTICAL
        size = [flex(), SIZE_TO_CONTENT]
        gap = midPadding
        halign = ALIGN_CENTER
        children = [
          priceCmp(selectedPerk.value, hasPoints, canBuy)
          isLocked ? lockedPerkCmp(tierInfo[tier]?.hint ?? "") : null
          canBuy ? availablePerk(soldierWatch.value, perksCfg,
            hasPoints, @() add_perk(guid, perkId, sound)) : null
        ]
      }
    ]
  }
}

let defaultPerkCfg = { available = 0, tier = 1 }

let getStartPerk = function(soldier, soldierPerksVal, perkSchemesVal, perksListVal) {
  let { perkSchemeId = "" } = soldierPerksVal?[soldier.guid] ?? {}
  let perkScheme = perkSchemesVal?[perkSchemeId]
  if (perkScheme == null)
    return null
  let defaultPerk = perkScheme.findvalue(@(s) s.numChosen == 1)
  if (defaultPerk == null || defaultPerk.perks.len() < 1)
    return null

  let perk = perksListVal?[defaultPerk.perks.top()]
  if (perk == null)
    return null
  return perk.__merge(defaultPerkCfg)
}

let resetPerksBtn = function(soldier, soldierPerksCfg, perksListVal,
  armyItemCountByTplVal, cancelCost) {

  let totalCost = soldierPerksCfg.perks.reduce(@(res, count, perkId)
    res + count * priceForPerk(perksListVal[perkId]), 0) * cancelCost
  let payItems = getPayItemsData({ enlisted_silver = totalCost }, curCampItems.value)

  let buttons = [
    {
      text = ""
      action = @() reset_perks(soldier.guid, true, payItems)
      customStyle = {
        // message box uses old textButton so the custom constructor defined in customStyle
        textCtor = priceText("perks/resetBtn", { count = totalCost, currencyTpl = PERK_CHANGE_CURRENCY})
        textMargin = [hdpx(10), hdpx(20)]
        hotkeys = [["^J:Y | Enter"]]
      }
    }
  ]

  let { isPremium = false } = getClassCfg(soldier.sClass)
  if (isPremium)
    buttons.append({
      text = ""
      action = @() reset_perks(soldier.guid, false, payItems)
      customStyle = {
        textCtor = priceText("perks/restorePremBtn", { count = totalCost, currencyTpl = PERK_CHANGE_CURRENCY})
        hotkeys = [["^J:X"]]
      }
    })

  buttons.append({
    text = loc("Cancel")
    isCancel = true
    customStyle = { hotkeys = [[$"^{JB.B} | Esc"]] }
  })

  let ordersInStock = armyItemCountByTplVal?[PERK_CHANGE_CURRENCY] ?? 0
  let action = ordersInStock < totalCost
    ? @() notEnoughCurrencyMsg(totalCost - ordersInStock)
    : @() msgbox.showMessageWithContent({
        uid = "resetPerksMsgBox"
        content = {
          size = [sw(90), fsh(32)]
          flow = FLOW_VERTICAL
          children = [
            {
              hplace = ALIGN_RIGHT
              children = currencySilverUi
            }
            {
              size = flex()
              rendObj = ROBJ_TEXT
              text = isPremium ? loc("perks/resetPremOptions") : loc("perks/resetConfirm")
              halign = ALIGN_CENTER
              valign = ALIGN_CENTER
            }.__update(fontBody)
          ]
        }
        buttons
      })

  return Bordered(priceText("perks/resetBtn",  { count = totalCost, currencyTpl = PERK_CHANGE_CURRENCY}), action)
}

let hasFreeRerolls = @(perksCfg) (perksCfg?.rerolls ?? 0) > 0

let mkFreeRerollBtn = function(guid) {
  let buttons = [
    {
      text = loc("perks/resetBtn", { price = "" })
      action = @() free_reroll_perks(guid, true)
      customStyle = { hotkeys = [["^J:Y | Enter"]] }
    }
    {
      text = loc("perks/restorePremBtn", { price = "" })
      action = @() free_reroll_perks(guid, false)
      customStyle = { hotkeys = [["^J:X"]] }
    }
    {
      text = loc("Cancel")
      isCancel = true
      customStyle = { hotkeys = [[$"^{JB.B} | Esc"]] }
    }
  ]

  let action = @() msgbox.show({
    text = loc("perks/resetPremOptions")
    buttons
  })
  return Bordered(loc("perks/resetBtn", { price = "" }), action)
}

let freeRerollBtn = function(soldier, perksCfg, params = {}) {
  let rerolls = perksCfg?.rerolls ?? 0
  return {
    flow = FLOW_VERTICAL
    halign = ALIGN_CENTER
    gap = MEDIUM_GAP
    children = [
      {
        rendObj = ROBJ_TEXTAREA
        behavior = Behaviors.TextArea
        text = loc("perks/rerollHint", { count = rerolls })
      }.__update(defTxtStyle)
      mkFreeRerollBtn(soldier.guid)
    ]
  }.__update(params)
}

let mkSoldierInfo = function(soldierWatch, soldierPerksCfg) {
  let curVehicleInfo = Computed(@() objInfoByGuid.value?[curVehicle.value])
  return function() {
    let res = {
      watch = [soldierWatch, soldierPerksCfg, maxTrainByClass, perkLevelsGrid, curVehicleInfo]
      size = [COLUMN_WIDTH, flex()]
    }
    if (soldierWatch.value == null)
      return res

    let { sClass, tier } = soldierWatch.value
    let maxTier = sClass in maxTrainByClass.value ? maxTrainByClass.value[sClass] + 1 : tier

    let soldierCardBlock = {
      flow = isWide ? FLOW_VERTICAL : FLOW_HORIZONTAL
      gap = MEDIUM_GAP
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children = [
        mkSoldierCard({
          soldierInfo = soldierWatch.value
          size = soldierCardSize
          expToLevel = perkLevelsGrid.value?.expToLevel ?? []
        })
        tier < maxTier ? mkBuyLevelBtn(soldierWatch.value, soldierPerksCfg.value)
          : tier < MAX_LEVEL ? mkTrainBtn(soldierWatch.value)
          : null
      ]
    }

    let soldierSeatBlock = function() {
      let seatsOrder = mkVehicleSeats(curVehicleInfo.value)
      let curSoldierIdx = curSquadSoldiersInfo.value.findindex(@(v)
        v.guid == soldierWatch.value?.guid)
      let seat = seatsOrder?[curSoldierIdx]
      let result = { watch = curSquadSoldiersInfo }
      return seat == null ? result
        : result.__update({
            rendObj = ROBJ_TEXT
            text = loc(seat.locName)
            hplace = ALIGN_LEFT
            pos = [0, -MEDIUM_GAP]
          }, defTxtStyle)
    }

    return res.__update(isWide
      ? {
          halign = ALIGN_CENTER
          children = [
            soldierSeatBlock
            soldierCardBlock
            @() {
              watch = [armyItemCountByTpl, perkCancelCost]
              size = [flex(), SIZE_TO_CONTENT]
              halign = ALIGN_CENTER
              vplace = ALIGN_BOTTOM
              margin = [bigPadding, 0, 0, 0]
              children = hasFreeRerolls(soldierPerksCfg.value)
                ? freeRerollBtn(soldierWatch.value, soldierPerksCfg.value)
                : resetPerksBtn(soldierWatch.value, soldierPerksCfg.value, perksList.value,
                    armyItemCountByTpl.value, perkCancelCost.value)
            }
          ]
        }
      : {
          size = SIZE_TO_CONTENT
          flow = FLOW_VERTICAL
          margin = [0, 0, COLUMN_GAP, 0]
          children = [
            soldierSeatBlock
            soldierCardBlock
          ]
        }
    )
  }
}

let getTreeData = function(perkTreeCfg, perkTreesSpecialCfg, soldier,
  soldierPerksVal, perkSchemesVal, perksListVal) {
  let tree = treeForSoldier(perkTreeCfg, perkTreesSpecialCfg, soldier)
  if (soldier == null)
    return tree
  let startPerk = getStartPerk(soldier, soldierPerksVal, perkSchemesVal, perksListVal)
  if (startPerk == null)
    return tree

  let stat = statForPerk(startPerk)
  let newTree = clone tree
  newTree[0] = clone tree[0]
  newTree[0].perks <- clone tree[0].perks
  newTree[0].perks[stat] <- [startPerk].extend(clone tree[0].perks[stat])
  return newTree
}

let treeCmp = @(soldierWatch) function() {
  let perkTreeCfg = perkTreeTbl(configs.value)
  if (perkTreeCfg.len() == 0) {
    logPerks("Perk tree config is empty")
    return { watch = configs }
  }

  let { perkTreesSpecial = {} } = configs.value
  let perkTree = getTreeData(perkTreeCfg, perkTreesSpecial, soldierWatch.value,
    soldierPerks.value, perkSchemes.value, perksList.value)

  if (selectedPerk.value == null)
    defer(function() {
      let firstPerk = findFirstPerk(perkTree, soldierWatch.value, soldierPerks.value)
      selectedPerk(firstPerk)
    })

  let soldierPerksCfg = Computed(@() soldierPerks.value?[soldierWatch.value?.guid])

  return isWide
    ? {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        gap = COLUMN_GAP
        watch = [configs, soldierWatch, soldierPerks, perkSchemes, perksList]
        children = [
          mkSoldierInfo(soldierWatch, soldierPerksCfg)
          mkTree(perkTree, soldierWatch)
          mkSelectedPerk(soldierWatch)
        ]
      }
    : {
        size = flex()
        flow = FLOW_VERTICAL
        watch = [configs, soldierWatch, soldierPerks, perkSchemes, perksList]
        margin = [0, sidePadding]
        children = [
          mkSoldierInfo(soldierWatch, soldierPerksCfg)
          {
            flow = FLOW_HORIZONTAL
            size = [flex(), SIZE_TO_CONTENT]
            gap = COLUMN_GAP
            children = [
              mkTree(perkTree, soldierWatch)
              mkSelectedPerk(soldierWatch)
            ]
          }
          @() {
            watch = [armyItemCountByTpl, perkCancelCost]
            size = [flex(), SIZE_TO_CONTENT]
            valign = ALIGN_TOP
            padding = [largePadding, 0, sidePadding, 0]
            children = hasFreeRerolls(soldierPerksCfg.value)
              ? freeRerollBtn(soldierWatch.value, soldierPerksCfg.value, { halign = ALIGN_LEFT })
              : resetPerksBtn(soldierWatch.value, soldierPerksCfg.value, perksList.value,
                  armyItemCountByTpl.value, perkCancelCost.value)
          }
        ]
      }
}

let openPerkTree = function(soldierWatch) {
  selectedPerk(null)
  let content = {
    flow = FLOW_VERTICAL
    padding = MEDIUM_GAP
    gap = isWide ? COLUMN_GAP : 0
    eventPassThrough = false
    size = flex()
    valign = ALIGN_TOP
    children = [
      {
        size = [flex(), SIZE_TO_CONTENT]
        children = [
          {
            size = [flex(), unitSize * 1.7]
            padding = unitSize * 0.3
            children = Bordered(loc("BACK"), close, {
              hotkeys = [[ $"^{JB.B} | Esc", { description = loc("BackBtn") } ]]
            })
          }
          {
            rendObj = ROBJ_TEXT
            text = loc("perks/tree")
            padding = midPadding
            hplace = ALIGN_CENTER
          }.__update(titleTxtStyle)
          {
            hplace = ALIGN_RIGHT
            flow = FLOW_HORIZONTAL
            valign = ALIGN_CENTER
            gap = midPadding
            children = [
              mkCurrencyUi(LEVEL_UP_ORDER)
              currenciesWidgetUi
              currencySilverUi
            ]
          }
        ]
      }
      treeCmp(soldierWatch)
    ]
  }

  addModalWindow({
    key = WND_UID
    rendObj = ROBJ_WORLD_BLUR_PANEL
    fillColor = darkPanelBgColor
    valign = ALIGN_TOP
    stopMouse = true
    stopHover = true
    onClick = @() null
    children = content
    cursor = normal
    hotkeys = [[$"^{JB.B} | Esc", { action = close }]]
  })
}

let perkListPopup = @(soldierWatch) function() {
  let perksCfg = soldierPerks.value?[soldierWatch.value?.guid] ?? {}
  let perksByStat = {}
  foreach(perkId, takenPoints in perksCfg.perks) {
    let perkData = perksList.value?[perkId]
    let { icon, color } = iconForPerk(perkData)
    let stat = statForPerk(perkData)
    if (stat not in perksByStat)
      perksByStat[stat] <- []
    let pointsPossible = perkData?.available ?? 1
    let tooltip = mkPerkTooltip(perksStatsCfg.value, perkData, takenPoints, pointsPossible, true)
    perksByStat[stat].append(withTooltip({
      rendObj = ROBJ_BOX
      valign = ALIGN_TOP
      borderColor = color
      borderWidth = hdpxi(2)
      borderRadius = hdpx(3)
      fillColor = darkColor
      padding = midPadding
      children = perkPointIcon(icon, color, (unitSize * 0.8).tointeger())
    }, tooltip))
  }

  let content = []

  foreach(statName, perkComponents in perksByStat) {
    let { color } = pPointsBaseParams[statName]
    content.append({
      rendObj = ROBJ_TEXT
      text = loc($"perks/{statName}_title")
      color
      padding = [midPadding, 0]
    }.__update(titleTxtStyle))
    content.append({
      flow = FLOW_HORIZONTAL
      gap = midPadding
      children = perkComponents
    })
  }

  return {
    watch = [soldierWatch, soldierPerks, perksStatsCfg, perksList]
    rendObj = ROBJ_BOX
    flow = FLOW_VERTICAL
    fillColor = panelBgColor
    gap = midPadding
    padding = MEDIUM_GAP
    children = content
  }
}

function openPerkList(event, soldierWatch) {
  let pos = [event.targetRect.r + COLUMN_GAP, event.targetRect.t]
  modalPopupWnd.add(pos, {
    uid = POPUP_UID
    popupHalign = ALIGN_LEFT
    popupValign = ALIGN_BOTTOM
    popupFlow = FLOW_VERTICAL
    rendObj = ROBJ_BOX
    fillColor = darkPanelBgColor
    padding = smallPadding
    valign = ALIGN_TOP
    stopMouse = true
    stopHover = true
    children = perkListPopup(soldierWatch)
    hotkeys = [[$"^{JB.B} | Esc", { action = @() modalPopupWnd.remove(POPUP_UID) }]]
  })
}

console_register_command(function(perkId) {
  if (curSoldierInfo.value == null) {
    log("Select a soldier")
    return
  }
  add_perk(curSoldierInfo.value.guid, perkId, soundAddPerk(true))
}, "meta.addCurSoldierPerk")

console_register_command(function() {
  openPerkTree(curSoldierInfo)
}, "debug.perkTree")

return {
  openPerkTree
  openPerkList
}
