from "%enlSqGlob/ui/ui_library.nut" import *

let { fontHeading2, fontBody, fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let checkbox = require("%ui/components/checkbox.nut")
let msgbox = require("%enlist/components/msgbox.nut")
let { currenciesById, currenciesBalance } = require("%enlist/currency/currencies.nut")
let { mkDontShowTodayComp, setDontShowToday } = require("%enlist/options/dontShowAgain.nut")
let colorize = require("%ui/components/colorize.nut")
let colors = require("%ui/style/colors.nut")
let textButtonTextCtor = require("%ui/components/textButtonTextCtor.nut")
let { priceWidget } = require("%enlist/components/priceWidget.nut")
let { makeVertScroll, thinStyle } = require("%ui/components/scrollbar.nut")
let { sendBigQueryUIEvent } = require("%enlist/bigQueryEvents.nut")
let { smallPadding } = require("%enlSqGlob/ui/designConst.nut")
let { purchaseButtonStyle } = require("%enlSqGlob/ui//buttonsStyle.nut")
let { mkCurrency } = require("currenciesComp.nut")
let JB = require("%ui/control/gui_buttons.nut")


let defGap = fsh(3)
let currencySize = hdpx(29)
let openShopByCurrencyId = {}

let mkItemDescription = @(description) makeVertScroll({
    size = [flex(), SIZE_TO_CONTENT]
    rendObj = ROBJ_TEXTAREA
    behavior = Behaviors.TextArea
    halign = ALIGN_CENTER
    text = description
  }.__update(fontBody)
  {
    size = [flex(), SIZE_TO_CONTENT]
    maxHeight = hdpx(300)
    styling = thinStyle
  })

let currencyImage = @(currency) currency
  ? {
      size = [currencySize, currencySize]
      rendObj = ROBJ_IMAGE
      image = Picture(currency.image(currencySize))
    }
  : null

function mkItemCostInfo(price, fullPrice, currencyId) {
  let currency = currenciesById.value?[currencyId]
  return {
    flow = FLOW_HORIZONTAL
    gap = smallPadding
    valign = ALIGN_CENTER
    children = [
      {
        rendObj = ROBJ_TEXT
        text = "{0} ".subst(loc("shop/willCostYou"))
      }.__update(fontSub)
      mkCurrency({
        currency
        price
        fullPrice
        iconSize = hdpxi(20)
      })
    ]
  }
}

function buyCurrencyText(currency, sf) {
  return {
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    margin = [hdpx(10), hdpx(20), hdpx(10), hdpx(50)]
    gap = currencyImage(currency)
    children = loc("btn/buyCurrency").split("{currency}").map(@(text) {
      rendObj = ROBJ_TEXT
      color = colors.textColor(sf, false, colors.TextActive)
      text
    }.__update(fontBody))
  }
}

let notEnoughMoneyInfo = @(price, currencyId) {
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  children = [
    {
      rendObj = ROBJ_TEXT
      color = colors.HighlightFailure
      text = loc("shop/notEnoughCurrency", {
        priceDiff = price - (currenciesBalance.value?[currencyId] ?? 0)
      })
    }.__update(fontBody)
    currencyImage(currenciesById.value?[currencyId])
  ]
}

function show(price, currencyId, purchase, fullPrice = null, title = "", productView = null,
  description = null, purchaseCurrency = null, dontShowMeTodayId = null, srcWindow = null,
  srcComponent = null, alwaysShowCancel = false, showOnlyWhenNotEnoughMoney = false,
  gap = defGap, additionalButtons = [], purchaseText = null
) {
  let bqBuyCurrency = @() sendBigQueryUIEvent("action_buy_currency", srcWindow, srcComponent)
  let currency = currenciesById.value?[currencyId]
  purchaseCurrency = purchaseCurrency ?? openShopByCurrencyId?[currencyId]

  if (!(price instanceof Watched))
    price = Watched(price)
  if (!(fullPrice instanceof Watched))
    fullPrice = Watched(fullPrice)

  let notEnoughMoney = currency == null
    ? Watched(false)
    : Computed(@() (currenciesBalance.value?[currencyId] ?? 0) < price.value)

  if (showOnlyWhenNotEnoughMoney && !notEnoughMoney.value) {
    purchase()
    bqBuyCurrency()
    return
  }

  local dontShowCheckbox = null
  if (dontShowMeTodayId != null && !notEnoughMoney.value) {
    let dontShowMeToday = mkDontShowTodayComp(dontShowMeTodayId)
    if (dontShowMeToday.value) {
      purchase()
      bqBuyCurrency()
      return
    }
    dontShowCheckbox = checkbox(dontShowMeToday, loc("dontShowMeAgainToday"),
      { setValue = @(v) setDontShowToday(dontShowMeTodayId, v) })
  }

  let buttons = Computed(function() {
    if (!notEnoughMoney.value)
      return [{
        text = purchaseText ?? loc("btn/buy")
        action = function() {
          purchase()
          bqBuyCurrency()
        }
        customStyle = {
          hotkeys = [[ "^J:X | Enter", { description = {skip = true}} ]]
        }.__update(purchaseButtonStyle)
      }]
      .extend(alwaysShowCancel ? [{ text = loc("Cancel"),
        customStyle = { hotkeys = [[$"^{JB.B} | Esc"]] } }] : [])
      .extend(additionalButtons)

    let res = []
    if (purchaseCurrency != null)
      res.append({
        customStyle = {
          textCtor = function(textComp, params, handler, group, sf) {
            textComp = buyCurrencyText(currency, sf)
            params = params.__merge(fontHeading2)
            return textButtonTextCtor(textComp, params, handler, group, sf)
          }
          hotkeys = [[ "^J:Y | Enter" ]]
        },
        action = function() {
          purchaseCurrency()
          sendBigQueryUIEvent("event_low_currency", srcWindow, srcComponent)
        }
      })
    res.extend(additionalButtons)
    if (alwaysShowCancel || purchaseCurrency == null)
      res.append({ text = loc("Cancel"), customStyle = { hotkeys = [[$"^{JB.B} | Esc"]] } })
    return res
  })

  let params = {
    text = colorize(colors.MsgMarkedText, title)
    fontStyle = fontBody
    children = {
      size = [fsh(80), SIZE_TO_CONTENT]
      margin = [defGap, 0, 0, 0]
      flow = FLOW_VERTICAL
      halign = ALIGN_CENTER
      gap
      children = [
        productView
        typeof description == "string" ? mkItemDescription(description) : description
        @() {
          watch = [price, fullPrice, notEnoughMoney]
          halign = ALIGN_CENTER
          flow = FLOW_VERTICAL
          gap = smallPadding
          children = [
            mkItemCostInfo(price.value, fullPrice.value, currencyId)
            notEnoughMoney.value
              ? notEnoughMoneyInfo(price.value, currencyId)
              : dontShowCheckbox
          ]
        }
      ]
    }
    topPanel = currencyId in currenciesById.value
      ? priceWidget(currenciesBalance.value?[currencyId] ?? loc("currency/notAvailable"), currencyId)
          .__update({
            size = [SIZE_TO_CONTENT, flex()]
            gap = hdpx(10)
          })
      : null
    buttons
  }

  msgbox.showWithCloseButton(params)
  sendBigQueryUIEvent("open_buy_currency_window", srcWindow, srcComponent)
}

return {
  purchaseMsgBox = kwarg(show)
  buyCurrencyText
  currencyImage
  mkItemCostInfo
  openShopByCurrencyId
  setOpenShopFunctions = @(list) openShopByCurrencyId.__update(list)
}