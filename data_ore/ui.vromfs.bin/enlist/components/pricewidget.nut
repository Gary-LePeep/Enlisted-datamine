from "%enlSqGlob/ui_library.nut" import *

let { fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let { currenciesById } = require("%enlist/currency/currencies.nut")
let { setTooltip } = require("%ui/style/cursors.nut")
let { mkCurrencyCardsTooltip } = require("%enlist/shop/currencyComp.nut")
let { ticketGroups } = require("%enlist/shop/currencyPresentation.nut")
let { abbreviateAmount } = require("%enlist/shop/numberUtils.nut")


let priceWidget = function(price, currencyId) {
  let currency = currenciesById.value?[currencyId]

  let tooltip = type(price) == "integer" && (currencyId in ticketGroups)
    ? mkCurrencyCardsTooltip(currencyId,
        [{
          amount = price
          icon = ticketGroups[currencyId].icon
        }]
      )
    : null

  return {
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    behavior = Behaviors.Button
    onHover = tooltip
      ? @(on) setTooltip(on ? tooltip : null)
      : null
    children = [
      currency == null ? null : {
        size = [hdpx(30), hdpx(30)]
        rendObj = ROBJ_IMAGE
        image = Picture(currency.image(hdpx(30)))
      }
      {
        rendObj = ROBJ_TEXT
        text = currency
          ? abbreviateAmount(price)
          : loc($"priceText/{currencyId}", { price }, $"{price}{currencyId}")
      }.__update(fontBody)
    ]
  }
}

return {
  priceWidget
}
