from "%enlSqGlob/ui/ui_library.nut" import *

let { currencyUi, freeExpUi, currencySilverUi } = require("%enlist/shop/armyCurrencyUi.nut")
let currenciesWidgetUi = require("%enlist/currency/currenciesWidgetUi.nut")
let { largePadding, bigPadding, midPadding, sidePadding } = require("%enlSqGlob/ui/designConst.nut")
let dropDownMainMenu =  require("%enlist/dropdownmenu/dropDownMainMenu.nut")
let profileButton = require("%enlist/profile/profileButton.nut")
let premiumWidgetUi = require("%enlist/premium/premiumButtonUi.nut")


let currencies = {
  flow = FLOW_VERTICAL
  halign = ALIGN_RIGHT
  gap = midPadding
  children = [
    {
      flow = FLOW_HORIZONTAL
      gap = bigPadding
      children = [
        currenciesWidgetUi
        currencySilverUi
      ]
    }
    {
      flow = FLOW_HORIZONTAL
      gap = bigPadding
      children = [
        currencyUi
        freeExpUi
      ]
    }
  ]
}

let profileInfoBlock = {
  flow = FLOW_HORIZONTAL
  gap = sidePadding
  margin = [bigPadding, 0, 0, 0]
  hplace = ALIGN_RIGHT
  halign = ALIGN_RIGHT
  children = [
    currencies
    {
      flow = FLOW_HORIZONTAL
      gap = largePadding
      valign = ALIGN_BOTTOM
      children =  [
        profileButton
        premiumWidgetUi
        dropDownMainMenu
      ]
    }
  ]
}

return profileInfoBlock
