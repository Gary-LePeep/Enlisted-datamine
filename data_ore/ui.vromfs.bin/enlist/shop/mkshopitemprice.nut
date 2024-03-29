from "%enlSqGlob/ui/ui_library.nut" import *

let { utf8ToUpper } = require("%sqstd/string.nut")
let { fontBody, fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let { txt } = require("%enlSqGlob/ui/defcomps.nut")
let { currenciesList, currenciesById } = require("%enlist/currency/currencies.nut")
let { curCampItemsCount } = require("%enlist/soldiers/model/state.nut")
let { mkItemCurrency } = require("currencyComp.nut")
let { mkCurrency, mkCurrencyCount, oldPriceLine } = require("%enlist/currency/currenciesComp.nut")
let { mkDiscountWidget } = require("%enlist/shop/currencyComp.nut")
let mkCountdownTimer = require("%enlSqGlob/ui/mkCountdownTimer.nut")
let { mkHeaderFlag, primeFlagStyle } = require("%enlSqGlob/ui/mkHeaderFlag.nut")
let { shopItemContentCtor } = require("%enlist/shop/armyShopState.nut")
let serverTime = require("%enlSqGlob/userstats/serverTime.nut")
let { brightAccentColor, midPadding, bonusColor,
  defTxtColor, activeTxtColor, titleTxtColor
} = require("%enlSqGlob/ui/designConst.nut")


let sidePadding = fsh(2)
let discountBannerHeight = hdpx(48) // equal to PRICE_HEIGHT!


function hasItemsToBarter(curItemCost, campItems) {
  if (curItemCost.len() == 0)
    return false

  foreach (itemTpl, reqCount in curItemCost)
    if ((campItems?[itemTpl] ?? 0) < reqCount)
      return false

  return true
}

let mkPriceText = @(price, currencyId) loc($"priceText/{currencyId}", { price })

let mkPurchaseText = @(isSoldier) isSoldier ? loc("mainmenu/enlistFor") : loc("mainmenu/buyFor")

function mkItemPurchaseInfo(shopItem, campItems, currencies, isNarrow) {
  let { curItemCost, curShopItemPrice, shop_price_curr = "",
    shop_price = 0, shop_price_full = 0, discountInPercent = 0,
    isPriceHidden = false, hideDiscount = false
  } = shopItem

  let hasBarter = hasItemsToBarter(curItemCost, campItems)
  let hasDiscount = curShopItemPrice.fullPrice > curShopItemPrice.price
  let isSoldier = (shopItemContentCtor(shopItem)?.value.content.soldierClasses.len() ?? 0) > 0
  if (hasBarter && !hasDiscount)
    return txt({
      text = isSoldier ? loc("mainmenu/enlist") : loc("mainmenu/receive")
      color = activeTxtColor
      padding = [0, sidePadding, 0, 0]
    }.__update(fontBody))

  let { price, fullPrice, currencyId = null } = curShopItemPrice
  //block for Ingame Currencies: Gold, etc
  let currency = currencies.findvalue(@(c) c.id == currencyId)
  if (currency != null && (price > 0 || discountInPercent > 0))
    return {
      flow = FLOW_HORIZONTAL
      padding = [0, sidePadding, 0, 0]
      valign = ALIGN_CENTER
      gap = midPadding
      children = [
        isNarrow || isPriceHidden ? null
          : txt({
              text = mkPurchaseText(isSoldier)
              color = activeTxtColor
            }.__update(fontSub))
        mkDiscountWidget(discountInPercent)
        isPriceHidden ? null : mkCurrency({
          currency
          price
          fullPrice
        })
      ]
    }

  // this block for external store:
  if (shop_price_curr != "" && shop_price > 0) {
    let hasStoreDiscount = shop_price_full > shop_price
    let children = []
    if (!isPriceHidden) {
      if (!isNarrow || !hasStoreDiscount)
        children.append(txt({
          text = mkPurchaseText(isSoldier)
          color = activeTxtColor
        }.__update(fontSub)))

      children.append(mkCurrencyCount(
        mkPriceText(shop_price, shop_price_curr),
        { color = hasStoreDiscount ? bonusColor : activeTxtColor }
      ))

      if (hasStoreDiscount)
        children.append({children = [
          mkCurrencyCount(mkPriceText(shop_price_full, shop_price_curr), { color = defTxtColor })
          oldPriceLine.__merge({ color = defTxtColor })
        ]})
    }
    if (!hideDiscount)
      children.append(mkDiscountWidget(discountInPercent))

    return {
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      gap = midPadding
      padding = [0, sidePadding, 0, 0]
      children
    }
  }

  return null
}

function mkItemBarterInfo(shopItem, campItems) {
  let { guid, curItemCost } = shopItem
  if (curItemCost.len() == 0)
    return null

  let children = []
  foreach (itemTpl, reqCount in curItemCost) {
    let inStock = campItems?[itemTpl] ?? 0
    children.append(mkItemCurrency({
      currencyTpl = itemTpl
      count = $"{inStock}/{reqCount}"
      keySuffix = guid
      textStyle = (inStock >= reqCount
        ? { color = bonusColor,  }
        : {}).__merge(fontBody)
    }))
  }
  return {
    flow = FLOW_HORIZONTAL
    gap = midPadding
    padding = [0,0,0,sidePadding]
    children
  }
}

let baseIconSize = [hdpxi(25), hdpxi(25)]

let mkPrice = @(shopItem, bgParams = {}, needPriceText = true,
  showGoldPrice = true, styleOverride = {}, discountStyle = null,
  iconSize = baseIconSize, dimStyle = {}
) (shopItem?.isPriceHidden ?? false) ? null : function() {
    let children = []
    foreach (itemTpl, value in shopItem.curItemCost)
      children.append(mkItemCurrency({
        currencyTpl = itemTpl
        count = value
        keySuffix = shopItem.guid
        textStyle = styleOverride
        iconSize
      }))
    if (showGoldPrice) {
      let { curShopItemPrice } = shopItem
      let { price, fullPrice, currencyId = null } = curShopItemPrice
      let currency = currenciesById.value?[currencyId]
      if (currency != null && price > 0) {
        if (children.len() > 0)
          children.append(txt({ text = loc("mainmenu/or")}.__update(fontBody)))
        children.append(mkCurrency({
          currency
          price
          fullPrice
          discountStyle
          dimStyle
          txtStyle = styleOverride
          iconSize = iconSize[0]
        }))
      }
    }

    let otherTxtStyle = fontBody.__merge(styleOverride)
    if (children.len() == 0) {
      let { shop_price_curr = "", shop_price = 0 } = shopItem
      children.append(txt({
        text = loc($"priceText/{shop_price_curr}", { price = shop_price })
      }.__update(otherTxtStyle)))
    }

    if (needPriceText && children.len() > 0)
      children.insert(0, txt({ text = loc("price")}.__update(otherTxtStyle)))

    return {
      watch = currenciesById
      flow = FLOW_HORIZONTAL
      gap = midPadding
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children
    }.__update(bgParams)
  }

function mkSinglePrice(priceData, count, guid) {
  let { currTpl = "", value = 0, price = 0, fullPrice = 0} = priceData
  if (currTpl == "EnlistedGold"){
    let currency = currenciesById.value?[currTpl]
    return mkCurrency({ currency, price = price * count, fullPrice = fullPrice * count})
  }

  return mkItemCurrency({
    currencyTpl = currTpl,
    count = value * count,
    keySuffix = guid
  })
}

function mkDiscountInfo(discountData) {
  if (discountData == null)
    return null

  let { locId, endTime = 0 } = discountData
  return {
    size = flex()
    valign = ALIGN_BOTTOM
    children = mkHeaderFlag({
      size = [SIZE_TO_CONTENT, discountBannerHeight]
      flow = FLOW_VERTICAL
      valign = ALIGN_CENTER
      padding = [0, fsh(5), 0, fsh(1)]
      children = [
        txt({
          text = utf8ToUpper(loc(locId))
          color = titleTxtColor
        }.__update(fontSub))
        endTime == 0 ? null : mkCountdownTimer({ timestamp = endTime, color = titleTxtColor })
      ]
    }, primeFlagStyle.__merge({
      size = SIZE_TO_CONTENT
      offset = 0
      flagColor = brightAccentColor
    }))
  }
}

function mkShopItemPrice(shopItem, personalOffer = null, isNarrow = false) {
  local {
    curItemCost, curShopItemPrice, shop_price_curr = "",
    shop_price = 0, discountInPercent = 0,
    discountIntervalTs = [], isPriceHidden = false, showSpecialOfferText = false
  } = shopItem
  let { price } = curShopItemPrice
  let [ beginTime = 0, endTime = 0 ] = discountIntervalTs
  let isDiscountActive = beginTime > 0
    && beginTime <= serverTime.value
    && (serverTime.value <= endTime || endTime == 0)
  let discountData = personalOffer != null ? {
        endTime = personalOffer.endTime
        locId = "specialOfferShort"
      }
    : discountInPercent > 0 || (discountInPercent == 0 && isDiscountActive) ? {
        endTime
        locId = showSpecialOfferText ? "specialOfferShort" : "shop/discountNotify"
      }
    : null

  if (discountData == null
    && curItemCost.len() == 0
    && price == 0
    && discountInPercent == 0
    && (shop_price_curr == "" || shop_price == 0 || isPriceHidden))
      return null

  return @() {
    watch = [curCampItemsCount, currenciesList]
    size = flex()
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    children = [
      mkItemBarterInfo(shopItem, curCampItemsCount.value)
      mkDiscountInfo(discountData)
      { size = flex() }
      mkItemPurchaseInfo(shopItem, curCampItemsCount.value, currenciesList.value, isNarrow)
    ]
  }
}

return {
  mkShopItemPrice
  mkPrice = kwarg(mkPrice)
  mkSinglePrice
}
