from "%enlSqGlob/ui_library.nut" import *

let JB = require("%ui/control/gui_buttons.nut")
let { fontBody, fontSub, fontHeading2 } = require("%enlSqGlob/ui/fontsStyle.nut")
let { defTxtColor, soldierWndWidth, bigPadding, titleTxtColor,
  blurBgColor, blurBgFillColor, maxContentWidth, slotBaseSize, commonBtnHeight
} = require("%enlSqGlob/ui/viewConst.nut")
let { panelBgColor, horGap, emptyGap, largePadding } = require("%enlSqGlob/ui/designConst.nut")
let { curArmyData, curCampItemsCount } = require("model/state.nut")
let { sceneWithCameraAdd, sceneWithCameraRemove } = require("%enlist/sceneWithCamera.nut")
let {
  isCustomizationWndOpened, availableCItem, currentItemPart, createItemsPerSlotWatch,
  PURCHASE_WND_UID, isPurchaseWndOpened, setPurchaseWindowData, getCustomizedSoldierLook,
  buyItemsWithCurrency, buyItemsWithTickets, saveOutfit, multipleApplyOutfit, hasSquadItemsToBuy,
  isPurchasing, isMultiplePurchasing, itemsToBuy, itemsBuyList,
  ignoreForMultiPurchase, premiumItemsCount, selectedItemsPrice, curSoldierItemsPrice, itemsCost,
  closePurchaseWnd, removeItem, removeAndCloseWnd
} = require("soldierCustomizationState.nut")
let closeBtnBase = require("%ui/components/closeBtn.nut")
let { itemBlock, mkPrice, mkCustomizationSlot
} = require("soldierCustomizationPkg.nut")
let mkHeader = require("%enlist/components/mkHeader.nut")
let currenciesWidgetUi = require("%enlist/currency/currenciesWidgetUi.nut")
let { mkMenuScene } = require("%enlist/mainMenu/mkMenuScene.nut")
let mkNameBlock = require("%enlist/components/mkNameBlock.nut")
let { Bordered } = require("%ui/components/txtButton.nut")
let { Flat, PrimaryFlat, Purchase } = require("%ui/components/textButton.nut")
let { TextHover, TextNormal, textMargin } = require("%ui/components/textButton.style.nut")
let textButtonTextCtor = require("%ui/components/textButtonTextCtor.nut")
let mkTextRow = require("%darg/helpers/mkTextRow.nut")
let { curSoldierInfo } = require("%enlist/soldiers/model/curSoldiersState.nut")
let { mkItemCurrency } = require("%enlist/shop/currencyComp.nut")
let { makeVertScroll, thinStyle } = require("%ui/components/scrollbar.nut")
let { addModalWindow } = require("%ui/components/modalWindows.nut")
let spinner = require("%ui/components/spinner.nut")
let { multiPurchaseAllowed } = require("%enlist/featureFlags.nut")
let { mkOutfitsListButton } = require("%enlist/soldiers/mkOutfitsList.nut")
let mkCallnameBlock = require("mkCallnameBlock.nut")

const APPEARANCE_ORDER_TPL = "appearance_change_order"

let closeButton = closeBtnBase({ onClick = @() saveOutfit() })
let purchaseCloseBtn = closeBtnBase({ onClick = closePurchaseWnd })
let verticalGap = bigPadding * 2
let purchaseWndWidth = min(sw(40), maxContentWidth) - hdpx(75) * 2
let waitingSpinner = spinner(hdpx(35))

let mkBlockHeader = @(text) {
  rendObj = ROBJ_BOX
  fillColor = panelBgColor
  size = [flex(), hdpx(48)]
  valign = ALIGN_CENTER
  children = {
    rendObj = ROBJ_TEXT
    hplace = ALIGN_CENTER
    text
    color = defTxtColor
  }.__update(fontBody)
}

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

let btnTextCtor = @(locId, tmpl, cost) @(_, params, handler, group, sf)
  textButtonTextCtor({
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    margin = textMargin
    children = mkTextRow(loc(locId),
      @(text) {
        rendObj = ROBJ_TEXT
        text
        color = sf & S_HOVER ? TextHover : TextNormal
      }.__update(fontBody),
      {
        ["{currency}"] = mkPrice(tmpl, cost, { //warning disable: -forgot-subst
            color = sf & S_HOVER ? TextHover : TextNormal
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

let function purchaseBtnBlock() {
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
    if (v.cost > 0)
      btnsBlock.append(
        v.tmpl == "EnlistedGold"
          ? Purchase("", buyItemsWithCurrency,
              { textCtor = btnTextCtor("btn/buyCurrency", v.tmpl, v.cost) })
          : PrimaryFlat("", buyItemsWithTickets, {
              isEnabled = (curCampItemsCount.value?[APPEARANCE_ORDER_TPL] ?? 0) >= v.cost
              hotkeys = [["^J:X"]]
              textCtor = btnTextCtor("btn/buyCurrency", v.tmpl, v.cost)
            })
      )
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

let chooseItemWrapParams = {
  width = slotBaseSize[0]
  vGap = bigPadding
  hGap = bigPadding
  halign = ALIGN_CENTER
}

let chooseItemBlock = function() {
  let itemsPerSlotWatch = createItemsPerSlotWatch()
  return {
    watch = [itemsPerSlotWatch, premiumItemsCount]
    size = [slotBaseSize[0], flex()]
    rendObj = ROBJ_WORLD_BLUR_PANEL
    flow = FLOW_VERTICAL
    padding = [bigPadding, 0]
    color = blurBgColor
    fillColor = blurBgFillColor
    stopMouse = true
    xmbNode = XmbContainer({
      canFocus = true
      scrollSpeed = 5.0
      isViewport = true
    })
    children = makeVertScroll(
        wrap(itemsPerSlotWatch.value.map(@(item)
            itemBlock(item, curSoldierItemsPrice.value, premiumItemsCount.value)),
          chooseItemWrapParams),
      {
        size = [SIZE_TO_CONTENT, flex()]
        styling = thinStyle
      })
  }
}

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


let lookWrapParams = {
  width = soldierWndWidth
  vGap = bigPadding
}

let lookCustomizationBlock = @() {
  watch = [multiPurchaseAllowed, availableCItem, currentItemPart, curSoldierItemsPrice]
  size = flex()
  halign = ALIGN_CENTER
  flow = FLOW_VERTICAL
  gap = bigPadding
  children = [wrap(availableCItem.value.map(@(item)
    mkCustomizationSlot(item, curSoldierItemsPrice.value)), lookWrapParams)
    {
      rendObj = ROBJ_TEXTAREA
      behavior = Behaviors.TextArea
      size = [flex(), SIZE_TO_CONTENT]
      text = loc("appearance/attachments_override")
      halign = ALIGN_CENTER
    }.__update(fontSub)
    multiPurchaseAllowed.value && !ignoreForMultiPurchase(currentItemPart.value)
      ? multiApplyBtn : null
  ]
}

let leftCustomizationBlock = @() {
  watch = [curSoldierInfo]
  rendObj = ROBJ_WORLD_BLUR_PANEL
  size = [soldierWndWidth, flex()]
  color = blurBgColor
  fillColor = blurBgFillColor
  flow = FLOW_VERTICAL
  gap = bigPadding
  padding = bigPadding
  children = [
    mkNameBlock(curSoldierInfo)
    mkOutfitsListButton(curSoldierInfo.value, @(calleeCb) saveOutfit(false, calleeCb))
    lookCustomizationBlock
    mkBlockHeader(loc("customize/callnameTitle"))
    mkCallnameBlock(curSoldierInfo.value)
  ]
}

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

let rightBtnBlock = {
  size = flex()
  halign = ALIGN_RIGHT
  valign = ALIGN_BOTTOM
  children = {
    flow = FLOW_HORIZONTAL
    valign = ALIGN_BOTTOM
    gap = bigPadding
    children = purchaseBtn
  }
}

let centralBlock = {
  size = flex()
  flow = FLOW_HORIZONTAL
  gap = bigPadding
  children = [
    leftCustomizationBlock
    chooseItemBlock
    rightBtnBlock
  ]
}

let topBar = @() {
  watch = [curArmyData, curCampItemsCount]
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  margin = [largePadding, 0, 0, 0]
  gap = bigPadding
  size = flex()
  maxWidth = maxContentWidth
  children = [
    Bordered(loc("BackBtn"), @() saveOutfit(), { margin = 0, hotkeys = [[$"^{JB.B}"]] })
    mkHeader({
      armyId = curArmyData.value?.guid
      textLocId = loc("appearance/choose")
      addToRight = {
        size = [SIZE_TO_CONTENT, flex()]
        flow = FLOW_HORIZONTAL
        valign = ALIGN_CENTER
        children = [
          currenciesWidgetUi
          horGap
          customizationCurrency
          emptyGap
        ]
      }
      closeButton
    })
  ]
}

let wndContent = mkMenuScene(topBar, centralBlock, {size = [flex(), SIZE_TO_CONTENT]})

let soldierCustomizationScene = {
  size = flex()
  halign = ALIGN_CENTER
  key = "soldierCustomization"
  behavior = Behaviors.MenuCameraControl
  onDetach = @() isCustomizationWndOpened(false)
  children = wndContent
}


isCustomizationWndOpened.subscribe(function(flag) {
  if (flag)
    sceneWithCameraAdd(soldierCustomizationScene, "soldiers")
  else
    sceneWithCameraRemove(soldierCustomizationScene)})