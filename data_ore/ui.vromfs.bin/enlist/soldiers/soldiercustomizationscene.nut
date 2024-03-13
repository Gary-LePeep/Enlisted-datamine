from "%enlSqGlob/ui/ui_library.nut" import *

let JB = require("%ui/control/gui_buttons.nut")
let { fontBody, fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let { panelBgColor, horGap, emptyGap, largePadding, slotBaseSize,
  defTxtColor, soldierWndWidth, midPadding, maxContentWidth,
  blurBgColor, blurBgFillColor
} = require("%enlSqGlob/ui/designConst.nut")
let { curArmyData, curCampItemsCount, curSquad } = require("model/state.nut")
let { sceneWithCameraAdd, sceneWithCameraRemove } = require("%enlist/sceneWithCamera.nut")
let {
  isCustomizationWndOpened, availableCItem, currentItemPart, createItemsPerSlotWatch,
  saveOutfit, premiumItemsCount, curSoldierItemsPrice
} = require("soldierCustomizationState.nut")
let closeBtnBase = require("%ui/components/closeBtn.nut")
let { itemBlock, mkCustomizationSlot } = require("soldierCustomizationPkg.nut")
let mkHeader = require("%enlist/components/mkHeader.nut")
let currenciesWidgetUi = require("%enlist/currency/currenciesWidgetUi.nut")
let { mkMenuScene } = require("%enlist/mainMenu/mkMenuScene.nut")
let mkNameBlock = require("%enlist/components/mkNameBlock.nut")
let { Bordered } = require("%ui/components/txtButton.nut")
let { curSoldierInfo } = require("%enlist/soldiers/model/curSoldiersState.nut")
let { makeVertScroll, thinStyle } = require("%ui/components/scrollbar.nut")
let { multiPurchaseAllowed } = require("%enlist/featureFlags.nut")
let { mkOutfitsListButton } = require("%enlist/soldiers/mkOutfitsList.nut")
let mkCallnameBlock = require("mkCallnameBlock.nut")
let {
  multiApplyBtn, purchaseBtn, customizationCurrency, ignoreForMultiPurchase
} = require("components/soldierCustomizationBuyWnd.nut")

let closeButton = closeBtnBase({ onClick = @() saveOutfit() })

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

let chooseItemWrapParams = {
  width = slotBaseSize[0]
  vGap = midPadding
  hGap = midPadding
  halign = ALIGN_CENTER
}

let chooseItemBlock = function() {
  let itemsPerSlotWatch = createItemsPerSlotWatch()
  return {
    watch = [itemsPerSlotWatch, premiumItemsCount]
    size = [slotBaseSize[0], flex()]
    rendObj = ROBJ_WORLD_BLUR_PANEL
    flow = FLOW_VERTICAL
    padding = [midPadding, 0]
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


let lookWrapParams = {
  width = soldierWndWidth
  vGap = midPadding
}

let lookCustomizationBlock = @() {
  watch = [multiPurchaseAllowed, availableCItem, currentItemPart, curSoldierItemsPrice]
  size = flex()
  halign = ALIGN_CENTER
  flow = FLOW_VERTICAL
  gap = midPadding
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
  watch = [curSoldierInfo, curSquad]
  rendObj = ROBJ_WORLD_BLUR_PANEL
  size = [soldierWndWidth, flex()]
  color = blurBgColor
  fillColor = blurBgFillColor
  flow = FLOW_VERTICAL
  gap = midPadding
  padding = midPadding
  children = [
    mkNameBlock(curSoldierInfo)
    mkOutfitsListButton(curSquad.value, @(calleeCb) saveOutfit(false, calleeCb))
    lookCustomizationBlock
    mkBlockHeader(loc("customize/callnameTitle"))
    mkCallnameBlock(curSoldierInfo.value)
  ]
}

let rightBtnBlock = {
  size = flex()
  halign = ALIGN_RIGHT
  valign = ALIGN_BOTTOM
  children = {
    flow = FLOW_HORIZONTAL
    valign = ALIGN_BOTTOM
    gap = midPadding
    children = purchaseBtn
  }
}

let centralBlock = {
  size = flex()
  flow = FLOW_HORIZONTAL
  gap = midPadding
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
  gap = midPadding
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