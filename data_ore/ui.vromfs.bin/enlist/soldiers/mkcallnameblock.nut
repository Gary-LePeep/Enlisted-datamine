from "%enlSqGlob/ui/ui_library.nut" import *

let { fontBody, fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let textInput = require("%ui/components/textInput.nut")
let { defTxtColor, activeTxtColor, smallPadding, commonBtnHeight
} = require("%enlSqGlob/ui/designConst.nut")
let { curCampItems, curCampItemsCount } = require("model/state.nut")
let { configs } = require("%enlist/meta/configs.nut")
let { mkItemCurrency } = require("%enlist/shop/currencyComp.nut")
let { purchaseMsgBox } = require("%enlist/currency/purchaseMsgBox.nut")
let getPayItemsData = require("model/getPayItemsData.nut")
let { use_callname_change_order, buy_callname_change } = require("%enlist/meta/clientApi.nut")
let { clearBorderSymbols } = require("%sqstd/string.nut")
let { localizeSoldierName } = require("%enlSqGlob/ui/itemsInfo.nut")
let { canUseOrder, mkCurrencyButton } = require("%enlist/soldiers/components/currencyButton.nut")
let obsceneFilter = require("%enlSqGlob/obsceneFilter.nut")
let spinner = require("%ui/components/spinner.nut")
let popupsState = require("%enlSqGlob/ui/popup/popupsState.nut")


const MAX_CHARS = 16
const CALLNAME_ORDER_TPL = "callname_change_order"

let changeCallnameGoldCost = Computed(@() configs.value?.gameProfile.changeCallnameGoldCost)
let callnameChangeInProgress = Watched(false)
let isWaitingObsceneFilter = Watched(false)
let waitingSpinner = spinner(commonBtnHeight/2)

let tiOptions = {
  margin = [hdpx(8),0,0,0]
  padding = 0
  textmargin = hdpx(5)
  maxChars = MAX_CHARS
  colors = { backGroundColor = Color(0, 0, 0, 255) }
  placeholder = loc("customize/writeCallsign")
}.__update(fontBody)

function callnameChangeAction(soldier, prevCallname, callname) {
  if (prevCallname == callname)
    return

  let orderTpl = CALLNAME_ORDER_TPL
  let orderReq = 1
  let campItems = curCampItemsCount.value
  if (canUseOrder(orderTpl, orderReq, campItems)) {
    let payData = getPayItemsData({ [orderTpl] = orderReq }, curCampItems.value)
    if (payData != null){
      callnameChangeInProgress(true)
      use_callname_change_order(soldier.guid, callname, payData, function(_){
        callnameChangeInProgress(false)
      })
    }
    return
  }

  purchaseMsgBox({
    price = changeCallnameGoldCost
    currencyId = "EnlistedGold"
    description = loc("customize/callnameAcception", {callSign = callname})
    title = loc("customize/callnameChooseForGoldConfirm")
    purchase = function() {
      callnameChangeInProgress(true)
      buy_callname_change(soldier.guid, callname, changeCallnameGoldCost.value, function(_){
        callnameChangeInProgress(false)
      })
    }
    srcComponent = "buy_change_soldier_callname"
    productView = null
  })
}

let stdText = @(text) {
  rendObj = ROBJ_TEXT
  hplace = ALIGN_CENTER
  color = defTxtColor
  text
}.__update(fontSub)

function mkSoldierNameColorized(soldier, callname) {
  let { name, surname } = localizeSoldierName(soldier)
  return function() {
    let callnameText = (callname.value ?? "") == "" ? null : {
      rendObj = ROBJ_TEXT
      color = activeTxtColor
      text = $"\"{callname.value}\""
    }
    return {
      watch = callname
      flow = FLOW_HORIZONTAL
      gap = smallPadding
      children = [
        stdText(name)
        callnameText
        stdText(surname)
      ]
    }
  }
}

function filterAndSetCallname(callNameToSet, soldier, prevCallname){
  if (isWaitingObsceneFilter.value)
    return
  isWaitingObsceneFilter(true)
  obsceneFilter(callNameToSet, function(filteredCallName){
    isWaitingObsceneFilter(false)
    if (filteredCallName != callNameToSet){
      return popupsState.addPopup({
        id = "prohibited_callname"
        text = loc("prohibitedCallname")
        styleName = "error"
      })
    }
    callnameChangeAction(soldier, prevCallname, filteredCallName)
  })
}

function mkCallnameBlock(soldier){
  let ordersAvailable = curCampItemsCount.value?[CALLNAME_ORDER_TPL] ?? 0
  let callnameEditWatch = Watched(soldier?.callname)
  let callnameCleaned = Computed(@() clearBorderSymbols(callnameEditWatch.value))
  let prevCallname = soldier?.callname
  let isChanged = Computed(@() callnameCleaned.value != prevCallname)
  return @() {
    watch = [
      curCampItemsCount, changeCallnameGoldCost, isChanged,
      callnameChangeInProgress, isWaitingObsceneFilter
    ]
    flow = FLOW_VERTICAL
    size = [flex(), SIZE_TO_CONTENT]
    gap = hdpx(8)
    children = [
      {
        rendObj = ROBJ_TEXTAREA
        behavior = Behaviors.TextArea
        size = [flex(), SIZE_TO_CONTENT]
        color = defTxtColor
        text = loc("customize/callnameDescription")
      }.__update(fontSub)
      textInput(callnameEditWatch,
        tiOptions.__merge({
          onEscape = @() callnameEditWatch(prevCallname)
          onReturn = @() filterAndSetCallname(callnameCleaned.value, soldier, prevCallname)
        }))
      mkSoldierNameColorized(soldier, callnameCleaned)
      isWaitingObsceneFilter.value
        ? {
            size =[flex(), SIZE_TO_CONTENT]
            halign = ALIGN_CENTER
            children = waitingSpinner
          }
        : {
            size = [flex(), SIZE_TO_CONTENT]
            flow = FLOW_HORIZONTAL
            valign = ALIGN_CENTER
            vplace = ALIGN_CENTER
            children = [
              {
                size = [flex(), SIZE_TO_CONTENT]
                flow = FLOW_HORIZONTAL
                hplace = ALIGN_CENTER
                valign = ALIGN_CENTER
                gap = hdpx(5)
                children = [
                  stdText(loc(ordersAvailable == 0
                    ? "shop/noOrdersAvailable"
                    : "shop/youHave"
                  ))
                  mkItemCurrency({
                    currencyTpl = CALLNAME_ORDER_TPL
                    count = ordersAvailable > 0 ? ordersAvailable : null
                    textStyle = { color = defTxtColor, vplace = ALIGN_BOTTOM }
                  })
                ]
              }
              mkCurrencyButton({
                text = loc("customize/callnameConfirmBtn")
                cb = @() filterAndSetCallname(callnameCleaned.value, soldier, prevCallname)
                orderTpl = CALLNAME_ORDER_TPL
                orderCount = 1
                cost = changeCallnameGoldCost.value
                campItems = curCampItemsCount.value
                isEnabled = isChanged.value && !callnameChangeInProgress.value
              })
            ]
          }
    ]
  }
}

return mkCallnameBlock
