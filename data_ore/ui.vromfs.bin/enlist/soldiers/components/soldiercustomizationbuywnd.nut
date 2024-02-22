from "%enlSqGlob/ui/ui_library.nut" import *

let { fontBody, fontHeading2 } = require("%enlSqGlob/ui/fontsStyle.nut")
let {
  bigPadding, maxContentWidth, commonBtnHeight, defTxtColor, titleTxtColor,
  blurBgColor, blurBgFillColor
} = require("%enlSqGlob/ui/viewConst.nut")
let { horGap, emptyGap } = require("%enlSqGlob/ui/designConst.nut")
let { TextHover, TextNormal, textMargin } = require("%ui/components/textButton.style.nut")
let spinner = require("%ui/components/spinner.nut")
let closeBtnBase = require("%ui/components/closeBtn.nut")
let { Bordered } = require("%ui/components/txtButton.nut")
let { Flat, PrimaryFlat, Purchase } = require("%ui/components/textButton.nut")
let textButtonTextCtor = require("%ui/components/textButtonTextCtor.nut")
let mkTextRow = require("%darg/helpers/mkTextRow.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { mkItemCurrency } = require("%enlist/shop/currencyComp.nut")
let currenciesWidgetUi = require("%enlist/currency/currenciesWidgetUi.nut")
let { addModalWindow, removeModalWindow } = require("%ui/components/modalWindows.nut")
let { purchaseMsgBox } = require("%enlist/currency/purchaseMsgBox.nut")
let getPayItemsData = require("%enlist/soldiers/model/getPayItemsData.nut")
let { soldiersLook } = require("%enlist/meta/servProfile.nut")
let { outfitShopTypes, curArmyOutfit, allOutfitByArmy, getCustomizeScheme, getSquadCampainOutfit
} = require("%enlist/soldiers/model/config/outfitConfig.nut")
let { configs } = require("%enlist/meta/configs.nut")
let { squadsCfgById } = require("%enlist/soldiers/model/config/squadsConfig.nut")
let {
  curCustomizationItem, currentItemPart, increment, getAvailableItem, closeCustomizationWnd,
  customizedSoldierInfo, oldSoldiersLook, freeItemsBySquad, freeItemsForSoldier,
  customizationToApply, itemsToBuy, selectedItemsPrice, curSoldierItemsPrice
} = require("%enlist/soldiers/soldierCustomizationState.nut")
let { findItemTemplate, allItemTemplates
} = require("%enlist/soldiers/model/all_items_templates.nut")
let { mkPrice, itemBlock } = require("%enlist/soldiers/soldierCustomizationPkg.nut")
let { curCampItems, curCampItemsCount, curSquadSoldiersInfo, armySquadsById
} = require("%enlist/soldiers/model/state.nut")
let { multiPurchaseAllowed } = require("%enlist/featureFlags.nut")
let { isLinkedTo } = require("%enlSqGlob/ui/metalink.nut")
let { buy_outfit, use_outfit_orders, change_outfit_squad
} = require("%enlist/meta/clientApi.nut")

const PURCHASE_WND_UID = "PURCHASE_WND"
const APPEARANCE_ORDER_TPL = "appearance_change_order"

let verticalGap = bigPadding * 2
let purchaseWndWidth = min(sw(40), maxContentWidth) - hdpx(75) * 2
let waitingSpinner = spinner(hdpx(35))

// purchase window state
let isPurchasing = Watched(false)
local afterPurchaseCb = null
let isPurchaseWndOpened = Watched(false)
let isMultiplePurchasing = Watched(false)
let itemsInPurchaseWnd = Watched({})
let ignoreForMultiPurchase = @(slot) slot == "head"

let closePurchaseWnd = function() {
  isMultiplePurchasing(false)
  isPurchaseWndOpened(false)
  removeModalWindow(PURCHASE_WND_UID)
}
let purchaseCloseBtn = closeBtnBase({ onClick = closePurchaseWnd })

isPurchasing.subscribe(@(v) v ? null : closePurchaseWnd())
itemsInPurchaseWnd.subscribe(function(v) {
  if (v.len() == 0)
    closePurchaseWnd()
})

let setPurchaseWindowData = function(items, isMultiple = false, onBuyCb = @() null) {
  itemsInPurchaseWnd(items)
  isMultiplePurchasing(isMultiple)
  isPurchaseWndOpened(true)
  afterPurchaseCb = onBuyCb
}

// special data for purchase window
function multipleItemsToBuyImpl(soldierVal, soldiersListVal, allOutfitByArmyVal,
  soldiersLookVal, armySquadsByIdVal, freeItems, selectedItems) {
  let { armyId = null, squadId = null } = soldierVal
  if (armyId == null || selectedItems.len() == 0)
    return {}

  let campaignOutfit = getSquadCampainOutfit(armyId, squadId, armySquadsByIdVal)
  let squadItems = clone freeItems
  let linkedItems = allOutfitByArmyVal?[armyId] ?? []
  foreach(soldier in soldiersListVal) {
    let sGuid = soldier.guid

    let defaultItems = soldiersLookVal?[sGuid].items ?? {}
    defaultItems.each(@(val) increment(squadItems, val))

    linkedItems.each(function(outfit) {
      if (isLinkedTo(outfit, sGuid) && isLinkedTo(outfit, campaignOutfit))
        increment(squadItems, outfit.basetpl)
    })
  }

  let countForSquad = {}
  let count = soldiersListVal.len()

  foreach(_slot, item in selectedItems) {
    if (ignoreForMultiPurchase(item))
      continue

    let needBuy = count - (squadItems?[item] ?? 0)
    if (needBuy > 0)
      countForSquad[item] <- needBuy
  }
  return countForSquad
}

function hasSquadItemsToBuy(items) {
  let needItems = multipleItemsToBuyImpl(customizedSoldierInfo.value, curSquadSoldiersInfo.value,
    allOutfitByArmy.value, soldiersLook.value, armySquadsById.value,
    freeItemsBySquad.value, items)
  return (needItems.len() > 0)
}

let multipleItemsToBuy = Computed(@()
  multipleItemsToBuyImpl(customizedSoldierInfo.value, curSquadSoldiersInfo.value,
    allOutfitByArmy.value, soldiersLook.value, armySquadsById.value,
    freeItemsBySquad.value, itemsInPurchaseWnd.value))

let multipleItemsCost = Computed(function() {
  let { armyId = null } = customizedSoldierInfo.value

  let totalPrice = {}
  foreach (item, count in multipleItemsToBuy.value) {
    let { itemsubtype = null } = findItemTemplate(allItemTemplates, armyId, item)
    let itemPrice = outfitShopTypes.value?[itemsubtype] ?? {}

    foreach(_, costData in itemPrice) {
      let { currencyId = "", orderTpl = "", price = 0 } = costData
      let key = currencyId != "" ? currencyId : orderTpl
      totalPrice[key] <- (totalPrice?[key] ?? 0) + price * count
    }
  }
  return totalPrice
})

let totalItemsCost = Computed(function() {
  let itemsToCheckPrice = customizationToApply.value
  let totalPrice = {}
  if (itemsToCheckPrice.len() <= 0)
    return totalPrice

  let { armyId = null, guid = null} = customizedSoldierInfo.value
  if (armyId == null || guid == null)
    return totalPrice

  foreach (item in itemsToCheckPrice) {
    if (item in freeItemsForSoldier.value)
      continue
    let curItemPrice = curSoldierItemsPrice.value?[item] ?? {}
    curItemPrice.each(function(v) {
      let { currencyId = "", orderTpl = "" } = v
      let key = currencyId != "" ? currencyId : orderTpl
      totalPrice[key] <- (totalPrice?[key] ?? 0) + v.price
    })
  }

  return totalPrice
})

let itemsCost = Computed(@()
  isMultiplePurchasing.value ? multipleItemsCost.value : totalItemsCost.value)

let itemsBuyList = Computed(@()
  isMultiplePurchasing.value
    ? multipleItemsToBuy.value
    : itemsInPurchaseWnd.value.reduce(function(res, value) {
      res[value] <- 1
      return res
    }, {})
)

// button handlers

function getCustomizedSoldierLook() {
  let { armyId = null, squadId = null } = customizedSoldierInfo.value
  let campaignOutfit = getSquadCampainOutfit(armyId, squadId, armySquadsById.value)
  let itemScheme = getCustomizeScheme(squadsCfgById.value,
    configs.value, armyId, squadId, campaignOutfit)
  return oldSoldiersLook.value.__merge(customizationToApply.value)
    .filter(@(_, slot) !ignoreForMultiPurchase(slot) && (itemScheme?[slot] ?? []).len() > 1)
}


function multipleApplyOutfit(needEverything = false) {
  let applyItems = needEverything ? getCustomizedSoldierLook() : customizationToApply.value
  let premList = curArmyOutfit.value ?? []
  let usedItems = {}
  let itemsByTpl = {}
  let requestData = {}
  foreach (soldier in curSquadSoldiersInfo.value) {
    let soldierGuid = soldier.guid
    let multiPrem = {}
    let defaultItems = soldiersLook.value?[soldierGuid].items ?? {}
    foreach (slot, itemToEquip in applyItems) {
      if (ignoreForMultiPurchase(itemToEquip))
        continue

      if ((defaultItems?[slot] ?? "") == itemToEquip) {
        multiPrem[slot] <- ""
        continue
      }

      let possibleItems = itemsByTpl?[itemToEquip]
        ?? premList.filter(@(item) item.basetpl == itemToEquip)
      itemsByTpl[itemToEquip] <- possibleItems

      let { itemGuid, alreadyEquipped } =
        getAvailableItem(possibleItems, soldierGuid, slot, "", usedItems)

      if (!alreadyEquipped && itemGuid != "") {
        usedItems[itemGuid] <- true
        multiPrem[slot] <- itemGuid
      }
    }
    requestData[soldierGuid] <- {
      free = {}
      premium = multiPrem
    }
  }

  let { armyId = null, squadId = null } = customizedSoldierInfo.value
  let campaignOutfit = getSquadCampainOutfit(armyId, squadId, armySquadsById.value)
  change_outfit_squad(requestData, campaignOutfit)
  closeCustomizationWnd()
}

let afterPurchase = function(_) {
  afterPurchaseCb?()
  isPurchasing(false)
}

function buyItemsWithCurrency() {
  let { armyId = null } = customizedSoldierInfo.value
  if (armyId == null || isPurchasing.value)
    return

  let { EnlistedGold } = itemsCost.value
  let items = itemsBuyList.value
  return purchaseMsgBox({
    price = EnlistedGold
    currencyId = "EnlistedGold"
    alwaysShowCancel = true
    purchase = function() {
      isPurchasing(true)
      buy_outfit(armyId, items, EnlistedGold, afterPurchase)
    }
  })
}

function buyItemsWithTickets() {
  let { armyId = null } = customizedSoldierInfo.value
  if (armyId == null || isPurchasing.value)
    return

  let costData = itemsCost.value
  let orderTpl = costData.findindex(@(_, id) id != "EnlistedGold")
  if (orderTpl == null)
    return

  let price = costData[orderTpl]
  let items = itemsBuyList.value
  let orders = getPayItemsData({ [orderTpl] = price }, curCampItems.value)

  isPurchasing(true)
  use_outfit_orders(armyId, items, orders, afterPurchase)
}

function removeItem(itemToDelete) {
  let key = itemsInPurchaseWnd.value.findindex(@(item) item == itemToDelete)

  if (key != null) {
    itemsInPurchaseWnd.mutate(@(v) v.$rawdelete(key))
    if (itemsInPurchaseWnd.value.len() == 0) {
      curCustomizationItem(oldSoldiersLook.value?[currentItemPart.value])
      closePurchaseWnd()
    }
  }
}

function removeAndCloseWnd(itemToDelete) {
  removeItem(itemToDelete)
  curCustomizationItem(null)
  closePurchaseWnd()
}

// UI code
let customizationCurrency = @() {
  watch = curCampItemsCount
  children = mkItemCurrency({
    currencyTpl = APPEARANCE_ORDER_TPL
    count = curCampItemsCount.value?[APPEARANCE_ORDER_TPL] ?? 0
    textStyle = { color = defTxtColor, vplace = ALIGN_BOTTOM, fontSize = fontBody.fontSize }
  })
}

let purchaseHeader = {
  size = [flex(), SIZE_TO_CONTENT]
  halign = ALIGN_RIGHT
  children = [
    {
      rendObj = ROBJ_TEXT
      text = loc("appearance/header")
      color = titleTxtColor
      hplace = ALIGN_CENTER
    }.__update(fontBody)
    {
      flow = FLOW_HORIZONTAL
      children = [
        emptyGap
        currenciesWidgetUi
        horGap
        customizationCurrency
        emptyGap
        purchaseCloseBtn
      ]
    }
  ]
}.__update(fontHeading2)

let purchaseItemWrapParams = {
  width = purchaseWndWidth
  halign = ALIGN_CENTER
  vplace = ALIGN_CENTER
  vGap = verticalGap
  hGap = verticalGap
}

let purchaseContent = function() {
  let itemsToShow = itemsBuyList.value.keys()
  let itemAction = itemsToShow.len() > 1 ? removeItem : removeAndCloseWnd

  return {
    watch = [itemsBuyList, isMultiplePurchasing, selectedItemsPrice]
    size = [purchaseWndWidth, SIZE_TO_CONTENT]
    padding = [verticalGap, 0]
    gap = verticalGap
    flow = FLOW_VERTICAL
    children = [
      isMultiplePurchasing.value ? {
          rendObj = ROBJ_TEXT
          text = loc("appearance/buyAndApply")
          color = defTxtColor
          hplace = ALIGN_CENTER
        }.__update(fontBody) : null
      wrap(itemsToShow.map(@(item)
          itemBlock(item, selectedItemsPrice.value, itemsBuyList.value, itemAction)),
        purchaseItemWrapParams)
      ]
  }
}

let btnTextCtor = @(locId, tmpl, cost, isEnabled = true) @(_, params, handler, group, sf)
  textButtonTextCtor({
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    margin = textMargin
    children = mkTextRow(loc(locId),
      @(text) {
        rendObj = ROBJ_TEXT
        text
        color = (sf & S_HOVER) && isEnabled ? TextHover : TextNormal
      }.__update(fontBody),
      {
        ["{currency}"] = mkPrice(tmpl, cost, { //warning disable: -forgot-subst
            color = (sf & S_HOVER) && isEnabled ? TextHover : TextNormal
          }.__update(fontBody))
      }
    )
  }, params, handler, group, sf)


let multiBuyBtn = Flat(loc("appearance/buyForSquad"),
  function() {
    let items = itemsToBuy.value.filter(@(_item, slot) !ignoreForMultiPurchase(slot))
    setPurchaseWindowData(items, true, multipleApplyOutfit)
  },
  {
    hotkeys = [["^J:Y"]]
  })

function purchaseBtnBlock() {
  let allPrices = itemsCost.value
  let priceList = []
  foreach (key, val in allPrices) {
    if (key == "EnlistedGold")
      priceList.append({
        tmpl = key
        cost = val
      })
    else
      priceList.insert(0, {
        tmpl = key
        cost = val
      })
  }
  let btnsBlock = [
    Flat(loc("BackBtn"), closePurchaseWnd, {
      hotkeys = [[$"^{JB.B} | Esc"]]
    })
  ]

  foreach(v in priceList) {
    if (v.cost > 0) {
      let isEnabledTicket = (curCampItemsCount.value?[APPEARANCE_ORDER_TPL] ?? 0) >= v.cost
      btnsBlock.append(
        v.tmpl == "EnlistedGold"
          ? Purchase("", buyItemsWithCurrency,
              { textCtor = btnTextCtor("btn/buyCurrency", v.tmpl, v.cost) })
          : PrimaryFlat("", buyItemsWithTickets, {
              isEnabled = isEnabledTicket
              hotkeys = [["^J:X"]]
              textCtor = btnTextCtor("btn/buyCurrency", v.tmpl, v.cost, isEnabledTicket)
            })
      )
    }
  }

  if (multiPurchaseAllowed.value && !isMultiplePurchasing.value
      && itemsToBuy.value.findindex(@(_item, slot) !ignoreForMultiPurchase(slot)) != null)
    btnsBlock.append(multiBuyBtn)

  return {
    watch = [itemsCost, curCampItemsCount, multiPurchaseAllowed, isMultiplePurchasing,
      isPurchasing, itemsToBuy]
    size = [flex(), hdpx(100)]
    valign = ALIGN_BOTTOM
    flow = FLOW_HORIZONTAL
    halign = ALIGN_CENTER
    children = isPurchasing.value ? waitingSpinner : btnsBlock
  }
}


let purchaseWndContent = {
  size = [flex(), SIZE_TO_CONTENT]
  maxWidth = maxContentWidth
  padding = hdpx(75)
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  gap = verticalGap
  children = [
    purchaseHeader
    purchaseContent
    purchaseBtnBlock
  ]
}

let purchaseWnd = {
  rendObj = ROBJ_WORLD_BLUR_PANEL
  size = [flex(), SIZE_TO_CONTENT]
  color = blurBgColor
  fillColor = blurBgFillColor
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  flow = FLOW_VERTICAL
  children = purchaseWndContent
}

let openPurchaseWnd = @() addModalWindow({
  key = PURCHASE_WND_UID
  rendObj = ROBJ_WORLD_BLUR_PANEL
  size = flex()
  vplace = ALIGN_CENTER
  hplace = ALIGN_CENTER
  valign = ALIGN_CENTER
  halign = ALIGN_CENTER
  children = purchaseWnd
  onClick = @() null
})

isPurchaseWndOpened.subscribe(function(val) {
  if (val)
    openPurchaseWnd()
})

let multiApplyBtn = Bordered(loc("appearance/applySquad"),
  function() {
    let items = getCustomizedSoldierLook()
    if (!hasSquadItemsToBuy(items)) {
      multipleApplyOutfit(true)
      return
    }
    setPurchaseWindowData(items, true, @() multipleApplyOutfit(true))
  },
  { size = [flex(), commonBtnHeight], hotkeys = [["^J:X"]] }
)

let purchaseBtn = function() {
  let items = itemsToBuy.value
  let count = items.len()
  return {
    watch = itemsToBuy
    flow = FLOW_VERTICAL
    gap = verticalGap
    children = [
      count == 0 ? null
        : {
            rendObj = ROBJ_TEXT
            text = loc("appearance/itemsInCart", { count })
          }.__update(fontHeading2)
      Bordered(loc("appearance/purchase"),
        @() setPurchaseWindowData(clone items), {
          margin = 0
          isEnabled = count > 0
          hotkeys = [["^J:Y"]]
        })
    ]
  }
}

return {
  multiApplyBtn
  purchaseBtn
  customizationCurrency
  ignoreForMultiPurchase
}
