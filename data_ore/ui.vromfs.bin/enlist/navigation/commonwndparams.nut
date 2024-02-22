from "%enlSqGlob/ui/ui_library.nut" import *

let { largePadding, navHeight, footerContentHeight, smallPadding, contentGap, maxContentWidth
} = require("%enlSqGlob/ui/designConst.nut")
let currenciesWidgetUi = require("%enlist/currency/currenciesWidgetUi.nut")
let { currencyUi } = require("%enlist/shop/armyCurrencyUi.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { Bordered } = require("%ui/components/txtButton.nut")


let wndBottomPadding = footerContentHeight + smallPadding

let currencyHeader = @() {
  flow = FLOW_HORIZONTAL
  gap = largePadding
  hplace = ALIGN_RIGHT
  children = [
    currenciesWidgetUi
    currencyUi
  ]
}

let wndHeader = @(closeAction) {
  size = [flex(), navHeight]
  valign = ALIGN_BOTTOM
  maxWidth = maxContentWidth
  hplace = ALIGN_CENTER
  children = Bordered(loc("BACK"), closeAction,
    { hotkeys = [[ $"^{JB.B} | Esc", { description = loc("BackBtn") } ]] })
}


let commonWndParams = {
  size = flex()
  flow = FLOW_VERTICAL
  gap = contentGap
  padding = [0,0, wndBottomPadding, 0]
}


return {
  commonWndParams
  wndHeader
  currencyHeader
}

