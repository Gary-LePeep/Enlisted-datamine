from "%enlSqGlob/ui/ui_library.nut" import *

let { fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let {
  soldierWndWidth, midPadding, smallPadding, listCtors, slotBaseSize
} = require("%enlSqGlob/ui/designConst.nut")
let { soldiersLook } = require("%enlist/meta/servProfile.nut")
let icon3dByGameTemplate = require("%enlSqGlob/ui/icon3dByGameTemplate.nut")
let {
  currentItemPart, oldSoldiersLook, itemBlockOnClick, blockOnClick,
  customizationToApply, itemsInfo
} = require("soldierCustomizationState.nut")
let { curSoldierInfo } = require("%enlist/soldiers/model/curSoldiersState.nut")
let { mkItemCurrency } = require("%enlist/shop/currencyComp.nut")
let { mkCurrency } = require("%enlist/currency/currenciesComp.nut")
let { enlistedGold } = require("%enlist/currency/currenciesList.nut")
let faComp = require("%ui/components/faComp.nut")
let { appearanceToRender } = require("%enlist/scene/soldier_tools.nut")
let { amountText } = require("%enlist/soldiers/components/itemComp.nut")

let listBgColor = listCtors.bgColor
let listTxtColor = listCtors.txtColor

let blockHeight = hdpx(124)
let blockWidth = (soldierWndWidth - midPadding * 3) / 2
let currencyIconSize = hdpxi(30)


let itemParams = {
  width = blockWidth / 2
  hplace = ALIGN_LEFT
  height = blockHeight - hdpx(10)
}

let selectItemBlockWidth = slotBaseSize[0] - midPadding * 2
let purchaseItemBlockWidth = blockHeight

let selectingItemParams = {
  width = selectItemBlockWidth / 2
  height = blockHeight
  hplace = ALIGN_LEFT
}

let purchasingItemParams = {
  width = purchaseItemBlockWidth
  height = blockHeight
}

let mkPriceInteractive = @(currencyId, count, group, isSelected) watchElemState(@(sf){
  group
  children = currencyId == "EnlistedGold"
    ? mkCurrency({
        currency = enlistedGold
        price = count
        iconSize = currencyIconSize
        txtStyle = { color = listTxtColor(sf, isSelected) }
      })
    : mkItemCurrency({
        currencyTpl = currencyId
        count
        textStyle = { color = listTxtColor(sf, isSelected), fontSize = fontBody.fontSize }
      })
})

let priceBlock = @(itemPrice, params = {}) function(){
  let priceList = []
  let { isSelected = false, group = null } = params
  foreach (key, val in itemPrice) {
    if (key == "EnlistedGold")
      priceList.insert(0, mkPriceInteractive(key, val.price, group, isSelected))
    else
      priceList.append(mkPriceInteractive(key, val.price, group, isSelected))
  }
  return priceList.len() <= 0 ? null
    : {
        flow = FLOW_HORIZONTAL
        gap = hdpx(20)
        children = priceList
        vplace = ALIGN_BOTTOM
        valign = ALIGN_CENTER
      }
}

local mkCustomizationSlot = @(itemToShow, itemsPrices) watchElemState(function(sf){
  let { slotName, iconAttachments, item, locId, itemTemplate } = itemToShow
  let { armyId = null, guid = null } = curSoldierInfo.value
  let isSelected = slotName == currentItemPart.value
  let group = ElemGroup()
  let itemPrice = itemsPrices?[item] ?? {}
  return armyId == null || guid == null ? null : {
    watch = [soldiersLook, currentItemPart, curSoldierInfo]
    rendObj = ROBJ_SOLID
    size = [blockWidth, blockHeight]
    margin = [0, midPadding]
    onClick = @() blockOnClick(slotName)
    halign = ALIGN_RIGHT
    behavior = Behaviors.Button
    color = listBgColor(sf, isSelected)
    group
    children = [
      {
        rendObj = ROBJ_TEXT
        padding = smallPadding
        color = listTxtColor(sf, isSelected)
        text = loc(locId)
      }
      icon3dByGameTemplate(itemTemplate, itemParams.__merge({
        genOverride = { iconAttachments }
        shading = "same"
      }))
      currentItemPart.value == ""
        ? null
        : priceBlock(itemPrice, {
            vplace = ALIGN_BOTTOM
            padding = [smallPadding, 0]
            group
            isSelected
          })
    ]}
})

function mkPrice(currencyId, count, style){
  if (currencyId == "EnlistedGold")
    return mkCurrency({
      currency = enlistedGold
      price = count
      iconSize = currencyIconSize
    }.__update({ txtStyle = style }))

  return mkItemCurrency({
    currencyTpl = currencyId
    count
    textStyle = style.__update({ fontSize = fontBody.fontSize })
  })
}


let removeBtn = @(item, removeAction) watchElemState(@(sf){
  size = [flex(), SIZE_TO_CONTENT]
  behavior = Behaviors.Button
  padding = smallPadding
  valign = ALIGN_CENTER
  onClick = @() removeAction(item)
  rendObj =  ROBJ_SOLID
  color = listBgColor(sf)
  children = [
    faComp("close", {
      fontSize = hdpx(12)
      color = listTxtColor(sf)
    })
    {
      rendObj = ROBJ_TEXT
      hplace = ALIGN_RIGHT
      color = listTxtColor(sf)
      text = loc("remove")
    }
  ]
})

let defaultItemTitle = @(sf, isSelected){
  rendObj = ROBJ_TEXT
  text = loc("appearance/default_item")
  hplace = ALIGN_RIGHT
  color = listTxtColor(sf, isSelected)
}

let emptySlotTitle = @(sf, isSelected){
  rendObj = ROBJ_TEXT
  text = loc("appearance/empty_slot")
  hplace = ALIGN_RIGHT
  color = listTxtColor(sf, isSelected)
}


function selectingItemBlock(item, itemTemplate, guid, isSelected,
  iconAttachments, premiumItemsCount, itemPrice
){
  let group = ElemGroup()
  let isDefaultItem = soldiersLook.value[guid].items.findvalue(@(val) val == item) != null
  let isEmptySlot = itemTemplate == null
  let rightTopInfo = @(sf, isSel) isEmptySlot
    ? emptySlotTitle(sf, isSel)
    : isDefaultItem
      ? defaultItemTitle(sf, isSel)
      : item in premiumItemsCount && premiumItemsCount[item] > 1
        ? amountText(premiumItemsCount[item], sf, isSel)
        : null

  return watchElemState(@(sf){
    watch = soldiersLook
    size = [selectItemBlockWidth, blockHeight]
    rendObj = ROBJ_SOLID
    padding = midPadding
    xmbNode = XmbNode()
    behavior = Behaviors.Button
    sound = {
      hover = "ui/enlist/button_highlight"
      click = "ui/enlist/button_click"
      active = "ui/enlist/button_action"
    }
    halign = ALIGN_RIGHT
    color = listBgColor(sf, isSelected)
    onClick = @() itemBlockOnClick(item)
    group
    onHover = function(hovered){
      let currentSlot = currentItemPart.value
      local res = (clone appearanceToRender.value) ?? {}
      let itemToShow = hovered
        ? item
        : customizationToApply.value?[currentSlot]

      if (itemToShow == null || itemToShow == oldSoldiersLook.value?[currentSlot]) {
        if (currentSlot in res) {
          //No need to left item in slot, because we override with watch data
          //before render soldier. oldSoldiersLook includes premium items too.
          res.$rawdelete(currentSlot)
        }
      }
      else
        res[currentSlot] <- itemToShow

      appearanceToRender(res)
    }

    children = [
      icon3dByGameTemplate(itemTemplate, selectingItemParams.__merge({
        genOverride = { iconAttachments }
        shading = "same"
      }))
      rightTopInfo(sf, isSelected)
      priceBlock(itemPrice, {
        vplace = ALIGN_BOTTOM
        isSelected
        group
      })
    ]
  })
}

let purchasingItemBlock = function(item, itemTemplate, premiumItemsCount, removeAction,
  iconAttachments, itemPrice) {
    let count = premiumItemsCount?[item] ?? 0
    let icon = icon3dByGameTemplate(itemTemplate, purchasingItemParams.__merge({
      genOverride = { iconAttachments }
      shading = "same"
    }))
    return watchElemState(@(sf) {
      flow = FLOW_VERTICAL
      gap = smallPadding
      halign = ALIGN_CENTER
      children = [{
        size = [blockHeight, blockHeight]
        rendObj = ROBJ_SOLID
        color = listBgColor(sf)
        children = [
          count <= 1 ? null : amountText(count, sf, false)
          icon
        ]
      }
        priceBlock(itemPrice)
        removeBtn(item, removeAction)
      ]
    })
  }


let itemBlock = @(itemId, itemsPrices, premiumItemsCount, removeAction = null) function(){
  let { guid } = curSoldierInfo.value
  let { gametemplate = null, iconAttachments = [], itemSlot = "" } = itemsInfo.value?[itemId]
  let isSelected = Computed(function() {
    let curItemIdCheck = customizationToApply.value?[itemSlot] ?? oldSoldiersLook.value?[itemSlot]
    return removeAction == null && curItemIdCheck == itemId
  })
  let itemPrice = itemsPrices?[itemId] ?? {}
  return {
    watch = [curSoldierInfo, isSelected, itemsInfo]
    flow = FLOW_VERTICAL
    gap = smallPadding
    children = [
      removeAction == null
        ? selectingItemBlock(itemId, gametemplate, guid, isSelected.value,
            iconAttachments, premiumItemsCount, itemPrice)
        : purchasingItemBlock(itemId, gametemplate, premiumItemsCount, removeAction,
            iconAttachments, itemPrice)
    ]}
}


return {
  itemBlock
  currencyIconSize
  mkCustomizationSlot
  mkPrice
}