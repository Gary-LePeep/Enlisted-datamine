from "%enlSqGlob/ui/ui_library.nut" import *


let { fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let { currenciesList } = require("%enlist/currency/currencies.nut")
let { curCampItemsCount } = require("%enlist/soldiers/model/state.nut")
let { mkCurrency, mkCurrencyCount } = require("%enlist/currency/currenciesComp.nut")
let { mkColoredGradientX } = require("%enlSqGlob/ui/gradients.nut")
let { defTxtColor, titleTxtColor, largePadding } = require("%enlSqGlob/ui/designConst.nut")
let { mkItemCurrency } = require("currencyComp.nut")
let isChineseVersion = require("%enlSqGlob/isChineseVersion.nut")


let priceSize = [hdpx(248), hdpx(50)]

let transpLineColor    = 0x00000000
let realPriceLineColor = 0xFF334E80
let goldPriceLineColor = 0xFF6E0F0F
let mixPriceLineColor  = 0xFF797979

let realPriceGradient = mkColoredGradientX({colorLeft=realPriceLineColor, colorRight=transpLineColor})
let goldPriceGradient = mkColoredGradientX({colorLeft=goldPriceLineColor, colorRight=transpLineColor})
let mixPriceGradient  = mkColoredGradientX({colorLeft=mixPriceLineColor, colorRight=transpLineColor})


let defTxtStyle = freeze({ color = defTxtColor }.__update(fontBody))
let countTxtStyle = freeze({ color = titleTxtColor }.__update(fontBody))
let missTxtStyle = freeze({ color = defTxtColor }.__update(fontBody))


let priceSeparator = {
  padding = [0, largePadding]
  valign = ALIGN_BOTTOM
  rendObj = ROBJ_TEXT
  text = loc("mainmenu/or")
}.__update(defTxtStyle)

let mkPriceLine = @(bgImg) {
  size = [flex(), ph(8)]
  rendObj = ROBJ_IMAGE
  image = bgImg
}

let mkPriceBar = @(bgImg, children) {
  size = flex()
  flow = FLOW_HORIZONTAL
  gap = priceSeparator
  padding = [0, largePadding]
  valign = ALIGN_CENTER
  rendObj = ROBJ_IMAGE
  image = bgImg
  children
}

let shopPriceFrame = @(bgImg, priceContent) {
  size = flex()
  flow = FLOW_VERTICAL
  gap = { size = [flex(), ph(5)]}
  children = [
    mkPriceLine(bgImg)
    mkPriceBar(bgImg, priceContent)
    mkPriceLine(bgImg)
  ]
}


let mkPriceText = @(price, currencyId) loc($"priceText/{currencyId}",
  { price }, $"{price}{currencyId}")

function mkItemPurchaseInfo(currencies, currencyPrice, shop_price_curr, shop_price, params = {}) {
  let { price, fullPrice, currencyId = null } = currencyPrice
  let currency = currencies.findvalue(@(c) c.id == currencyId)
  let { iconSize = hdpxi(24), txtStyle = null } = params
  if (currency != null && price > 0)
    return mkCurrency({ currency, price, fullPrice, iconSize, txtStyle })

  // this block for console platform specific prices:
  if (shop_price_curr != "" && shop_price > 0)
    return mkCurrencyCount(mkPriceText(shop_price, shop_price_curr), txtStyle)

  return null
}

function mkItemBarterInfo(guid, curItemCost, campItems) {
  let children = []
  foreach (itemTpl, reqCount in curItemCost) {
    let inStock = campItems?[itemTpl] ?? 0
    children.append(mkItemCurrency({
      currencyTpl = itemTpl
      count = reqCount
      keySuffix = guid
      textStyle = inStock >= reqCount ? countTxtStyle : missTxtStyle
    }))
  }
  return children.len() == 0 ? null
    : {
        flow = FLOW_HORIZONTAL
        gap = largePadding
        children
      }
}


function mkShopItemPrice(shopItem, lockObject = null) {
  let { guid, curItemCost, curShopItemPrice,
    shop_price_curr = "", shop_price = 0
  } = shopItem
  let { price, currencyId = null } = curShopItemPrice
  let hasRealPrice = shop_price_curr != "" && shop_price > 0
  if (hasRealPrice && isChineseVersion)
    return null

  let hasGoldPrice = currencyId != null && price > 0
  let hasItemPrice = curItemCost.len() > 0
  let bgImg = hasRealPrice ? realPriceGradient
    : hasGoldPrice && !hasItemPrice ? goldPriceGradient
    : mixPriceGradient

  if (lockObject != null)
    return shopPriceFrame(bgImg, lockObject).__update({ size = priceSize })

  return function() {
    let currencyObj = mkItemPurchaseInfo(
      currenciesList.value,
      curShopItemPrice,
      shop_price_curr,
      shop_price
    )
    let barterObj = mkItemBarterInfo(guid, curItemCost, curCampItemsCount.value)

    return {
      size = priceSize
      children = currencyObj == null && barterObj == null ? null
        : shopPriceFrame(bgImg, [currencyObj, barterObj])
    }
  }
}

return {
  mkShopItemPrice
  mkItemPurchaseInfo
  mkItemBarterInfo
}
