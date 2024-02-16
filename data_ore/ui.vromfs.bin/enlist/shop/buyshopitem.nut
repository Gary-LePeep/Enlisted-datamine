from "%enlSqGlob/ui_library.nut" import *

let { fontHeading2, fontBody, fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let msgbox = require("%enlist/components/msgbox.nut")
let getPayItemsData = require("%enlist/soldiers/model/getPayItemsData.nut")
let { mkSinglePrice } = require("%enlist/shop/mkShopItemPrice.nut")
let { doesLocTextExist } = require("dagor.localize")
let { curCampItems } = require("%enlist/soldiers/model/state.nut")
let { txt, noteTextArea } = require("%enlSqGlob/ui/defcomps.nut")
let { mkItemCurrency, mkCurrencyImage } = require("%enlist/shop/currencyComp.nut")
let { sound_play } = require("%dngscripts/sound_system.nut")
let { HighlightFailure, MsgMarkedText, TextActive, textColor, TextHighlight
} = require("%ui/style/colors.nut")
let {
  bigPadding, smallPadding, defTxtColor, commonBtnHeight
} = require("%enlSqGlob/ui/viewConst.nut")
let { viewShopInfoBtnStyle, DISCOUNT_WARN_TIME } = require("shopPkg.nut")
let {
  barterShopItem, getBuyRequirementError, buyShopItem,
  realCurrencies, shopItemContentCtor, buyShopOffer
} = require("armyShopState.nut")
let { shopItems } = require("shopItems.nut")
let { openUrl, AuthenticationMode } = require("%ui/components/openUrl.nut")
let { currenciesById, currenciesBalance } = require("%enlist/currency/currencies.nut")
let { purchaseButtonStyle, primaryFlatButtonStyle
} = require("%enlSqGlob/ui/buttonsStyle.nut")
let colorize = require("%ui/components/colorize.nut")
let { sendBigQueryUIEvent } = require("%enlist/bigQueryEvents.nut")
let { getCurrencyPresentation } = require("%enlist/shop/currencyPresentation.nut")
let { priceWidget } = require("%enlist/components/priceWidget.nut")
let textButtonTextCtor = require("%ui/components/textButtonTextCtor.nut")
let serverTime = require("%enlSqGlob/userstats/serverTime.nut")
let { makeVertScroll, thinStyle } = require("%ui/components/scrollbar.nut")
let { openShopByCurrencyId } = require("%enlist/currency/purchaseMsgBox.nut")
let { allActiveOffers } = require("%enlist/offers/offersState.nut")
let squadsPresentation = require("%enlSqGlob/ui/squadsPresentation.nut")
let { openBPwindow, getRewardIdx } = require("%enlist/battlepass/bpWindowState.nut")
let { purchasesCount } = require("%enlist/meta/profile.nut")
let { titleTxtColor, attentionTxtColor } = require("%enlSqGlob/ui/designConst.nut")
let { setAutoGroup } = require("%enlist/shop/shopState.nut")
let { setCurSection } = require("%enlist/mainMenu/sectionsState.nut")
let faComp = require("%ui/components/faComp.nut")
let { mkStatList } = require("%enlist/soldiers/components/perksPackage.nut")
let sClassesCfg = require("%enlist/soldiers/model/config/sClassesConfig.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { buyItemAction } = require("%enlist/shop/buyShopItemAction.nut")
let { bonusesList } = require("%enlist/currency/bonuses.nut")
let { hasSquadsEffects } = require("%enlist/shop/armySlotDiscount.nut")
let currenciesWidgetUi = require("%enlist/currency/currenciesWidgetUi.nut")


let defTxtStyle = { color = defTxtColor }.__update(fontSub)
let smallActiveTxtStyle = { color = TextActive }.__update(fontSub)
let markedTxtStyle = { color = MsgMarkedText }.__update(fontSub)
let failureTxtStyle = { color = HighlightFailure }.__update(fontBody)
let highlightTxtStyle = { color = TextHighlight }.__update(fontBody)
let boldFailureTxtStyle = { color = HighlightFailure }.__update(fontBody)
let largeDefTxtStyle = { color = defTxtColor }.__update(fontHeading2)
let alertTxtStyle = { color = titleTxtColor }.__update(fontBody)

let buyBtnStyle = {
  size = [SIZE_TO_CONTENT, commonBtnHeight]
  minWidth = hdpxi(200)
}

enum DISCOUNT_STATE {
  STARTED = 0
  ENDING = 1
  ENDED = 2
}

const ENLISTED_SILVER = "enlisted_silver"

let needAskOnSpendingTicket = @(ticketName) ticketName in {
  weapon_order_gold = true
  soldier_order_gold = true
  vehicle_with_skin_order_gold = true
}

let defGap = fsh(3)
let currencySize = hdpx(29)

let hotkeyY = freeze({ hotkeys = [[ "^J:Y | Enter | Space", { description = {skip = true}} ]] })
let hotkeyX = freeze({ hotkeys = [[ "^J:X", { description = {skip = true}} ]] })

let mkDescription = @(descLocId) descLocId == null ? null
  : noteTextArea(loc(descLocId)).__update(defTxtStyle, {
      halign = ALIGN_CENTER
    })

let function mkResourcesLackInfo(reqResources, viewCurrs, costLocId, counts) {
  let lackResources = []
  foreach (currencyTpl, required in reqResources) {
    let count = required * counts - (viewCurrs?[currencyTpl] ?? 0)
    if (count > 0)
      lackResources.append(mkItemCurrency({
        currencyTpl, count, textStyle = boldFailureTxtStyle
      }))
  }
  if (lackResources.len() == 0)
    return null
  return {
    size = [fsh(50), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    margin = bigPadding
    children = [
      {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        halign = ALIGN_CENTER
        children = [
          txt(loc("shop/notEnoughCurrency", { priceDiff = "" })).__update(failureTxtStyle)
          {
            flow = FLOW_HORIZONTAL
            gap = bigPadding
            children = lackResources
          }
        ]
      }
      noteTextArea(loc(costLocId)).__update({
        halign = ALIGN_CENTER
      }, smallActiveTxtStyle)
    ]
  }
}

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

let mkAllPricesView = @(priceViews) {
  flow = FLOW_HORIZONTAL
  gap = bigPadding
  valign = ALIGN_CENTER
  children = [
    txt(loc("shop/willCostYou")).__update(defTxtStyle)
    {
      flow = FLOW_HORIZONTAL
      gap = {
        padding = bigPadding
        children = txt(loc("mainmenu/or")).__update(defTxtStyle)
      }
      valign = ALIGN_CENTER
      children = priceViews
    }
  ]
}

let mkBarterCurrency = @(barterTpl){
  size = [SIZE_TO_CONTENT, flex()]
  minHeight = SIZE_TO_CONTENT
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  gap = smallPadding
  children = [
    mkCurrencyImage(getCurrencyPresentation(barterTpl)?.icon)
    @(){
      watch = realCurrencies
      padding = [0, hdpx(3)]
      rendObj = ROBJ_TEXT
      text = realCurrencies.value?[barterTpl]
    }.__update(fontBody)
  ]
}

let btnWithCurrImageComp = @(text, currImgs, price, sf, count, shopItemPriceInc) {
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  margin = [hdpx(10), hdpx(20), hdpx(10), hdpx(50)]
  gap = hdpx(10)
  children = [
    {
      rendObj = ROBJ_TEXT
      color = textColor(sf, false, TextActive)
      text
    }.__update(fontBody)
    currImgs
    {
      rendObj = ROBJ_TEXT
      color = textColor(sf, false, TextActive)
      text = count * price
        + shopItemPriceInc * count * (count - 1) / 2
    }.__update(fontBody)
  ]
}

let notEnoughMoneyInfo = @(price, currencyId) {
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  children = [
    txt(loc("shop/notEnoughCurrency", {
      priceDiff = price - (currenciesBalance.value?[currencyId] ?? 0)
    })).__update(failureTxtStyle)
    currencyImage(currenciesById.value?[currencyId])
  ]
}

let function buyCurrencyText(currency, sf) {
  return {
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    margin = [hdpx(10), hdpx(20), hdpx(10), hdpx(50)]
    gap = currencyImage(currency)
    children = loc("btn/buyCurrency").split("{currency}").map(@(text) {
      rendObj = ROBJ_TEXT
      color = textColor(sf, false, TextActive)
      text
    }.__update(fontBody))
  }
}


let mkDiscountInfo = @(state) !state ? null
  : state == DISCOUNT_STATE.STARTED ? txt(loc("shop/discount_started")).__update(highlightTxtStyle)
  : state == DISCOUNT_STATE.ENDING ? txt(loc("shop/discount_ending")).__update(failureTxtStyle)
  : txt(loc("shop/discount_ended")).__update(failureTxtStyle)


let function recalcOfferPrice(offers, offerGuid, price, fullPrice, discountState, ts) {
  let offer = offers.findvalue(@(o) o.guid == offerGuid)
  if (offer == null)
    return discountState(DISCOUNT_STATE.ENDED)

  let { endTime = 0, discountInPercent = 0 } = offer
  if (discountInPercent <= 0)
    return discountState(DISCOUNT_STATE.ENDED)

  price(fullPrice.value - fullPrice.value * discountInPercent / 100)
  let newState = endTime <= ts ? DISCOUNT_STATE.ENDED
    : endTime - ts < DISCOUNT_WARN_TIME ? DISCOUNT_STATE.ENDING
    : DISCOUNT_STATE.STARTED
  discountState(newState)
}

let checkAndBuy = @(needShowConfirmation, handler, text = loc("shop/purchaseBaseHeader"), customStyle = {}, currencyWidget = null)
  needShowConfirmation
    ? msgbox.showMessageWithContent({
        uid = "confirmPurchaseMsgBox"
        content = {
          size = [sw(90), fsh(32)]
          flow = FLOW_VERTICAL
          children = [
            {
              hplace = ALIGN_RIGHT
              children = currencyWidget
            }
            {
              size = flex()
              rendObj = ROBJ_TEXT
              text
              halign = ALIGN_CENTER
              valign = ALIGN_CENTER
            }.__update(fontBody)
          ]
        }
        buttons = [
          {
            text = loc("btn/buy")
            action = handler
            customStyle = customStyle.__merge(buyBtnStyle, hotkeyX)
          }
          { text = loc("Cancel"), customStyle = { hotkeys = [[$"^{JB.B} | Esc"]] }, isCancel = true }
        ]
      })
    : handler()

let function notEnoughMsg(itemTpl, missingOrders) {
  let descId = $"dontHaveEnoughOrders/{itemTpl}"
  msgbox.showMsgbox({
    children = doesLocTextExist(descId)
      ? {
          rendObj = ROBJ_TEXTAREA
          size = [sw(70), SIZE_TO_CONTENT]
          behavior = Behaviors.TextArea
          text = descId
        }.__update(largeDefTxtStyle)
      : {
        flow = FLOW_VERTICAL
        size = [sw(70), SIZE_TO_CONTENT]
        gap = hdpx(15)
        children = [
          txt(loc("notEnoughOrders")).__update(largeDefTxtStyle)
          {
            flow = FLOW_HORIZONTAL
            children = [
              txt(loc("needMoreOrders" , { missingOrders })).__update(largeDefTxtStyle)
              mkCurrencyImage(getCurrencyPresentation(itemTpl)?.icon)
            ]
          }
          {
            rendObj = ROBJ_TEXTAREA
            size = [flex(), SIZE_TO_CONTENT]
            behavior = Behaviors.TextArea
            text = loc("dontHaveEnoughOrders")
          }.__update(largeDefTxtStyle)
        ]
      }
  })
}

let titleLocalization = @(locId, shopItem) loc(locId, { purchase = loc(shopItem?.nameLocId) ?? "" })

let warnIcon = faComp("exclamation-triangle", { fontSize = hdpx(16), color = attentionTxtColor })

let mkAlertObject = @(alertText) {
  flow = FLOW_HORIZONTAL
  margin = smallPadding
  gap = smallPadding
  valign = ALIGN_CENTER
  children = [
    warnIcon
    {
      rendObj = ROBJ_TEXT
      text = alertText
    }.__update(alertTxtStyle)
  ]
}


let function limitTextBlock(limit, guid) {
  if (limit <= 0)
    return null

  return function() {
    let count = purchasesCount.value?[guid].amount ?? 0
    return {
      watch = purchasesCount
      size = [flex(), SIZE_TO_CONTENT]
      rendObj = ROBJ_TEXTAREA
      behavior = Behaviors.TextArea
      halign = ALIGN_CENTER
      text = loc("shopItem/limit", { count, limit })
    }
  }}

let replentishSilverBtn = {
  action = function(){
    setAutoGroup("silver")
    setCurSection("SHOP")
  }
  customStyle = {
    textCtor = function(textComp, params, handler, group, sf) {
      textComp = {
        flow = FLOW_HORIZONTAL
        valign = ALIGN_CENTER
        margin = [hdpx(10), hdpx(20), hdpx(10), hdpx(50)]
        gap = {
          size = [currencySize, currencySize]
          rendObj = ROBJ_IMAGE
          image = Picture("!ui/uiskin/currency/enlisted_silver.svg")
        }
        children = loc("btn/buyCurrency").split("{currency}").map(@(text) {
          rendObj = ROBJ_TEXT
          color = textColor(sf, false, TextActive)
          text
        }.__update(fontBody))
        params = fontHeading2
      }
      return textButtonTextCtor(textComp, params, handler, group, sf)
    }
  }
}

let function mkNoFreeSpace(requiredInfo, activatePremiumBttn){
  let buttons = [{ text = loc("Ok"), isCancel = true }]
  if (requiredInfo.solvableByPremium && activatePremiumBttn!=null)
    buttons.append(activatePremiumBttn)
  if (requiredInfo?.resolveCb != null)
    buttons.append({ text = requiredInfo.resolveText,
      action = requiredInfo.resolveCb,
      isCurrent = true })
  return msgbox.show({ text = requiredInfo.text, buttons })
}


let canBuyWithGold = {
  size = [fsh(50), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  margin = bigPadding
  children = [
    noteTextArea(loc("buy/forEnlistedGold")).__update({
      halign = ALIGN_CENTER
    }, markedTxtStyle)
  ]
}

let function buyItem(shopItem, productView = null, viewBtnCb = null, activatePremiumBttn = null,
  description = null, pOfferGuid = null, countWatched = Watched(1), isNotSuitable = false,
  purchaseCb = null, needCheckAndBuy = false
) {
  // no free space for soldier:
  let requiredInfo = getBuyRequirementError(shopItem)
  if (requiredInfo != null)
    return mkNoFreeSpace(requiredInfo, activatePremiumBttn)

  let {
    guid, curItemCost = {}, referralLink = "", discountIntervalTs = [], shopItemPriceInc = 0,
    limit = -1
  } = shopItem

  // price in Gold
  local { price = 0, fullPrice = 0, currencyId = ""} = shopItem?.curShopItemPrice
  let currency = currenciesById.value?[currencyId]
  if (!(price instanceof Watched))
    price = Watched(price)
  if (!(fullPrice instanceof Watched))
    fullPrice = Watched(fullPrice)

  let ts = serverTime.value
  let discountState = Watched(null)
  if (pOfferGuid != null) {
    allActiveOffers.subscribe(function(offers) {
      recalcOfferPrice(offers, pOfferGuid, price, fullPrice, discountState, serverTime.value)
    })
    recalcOfferPrice(allActiveOffers.value, pOfferGuid, price, fullPrice, discountState, ts)
  }
  else if (discountIntervalTs.len() > 0){
    local [from, to = 0] = discountIntervalTs
    if (ts < from || ts < to){
      shopItems.subscribe(function(items){
        let curShopItem = items?[shopItem.guid]
        let curPrice = curShopItem?.curShopItemPrice.price ?? 0
        if (curPrice != price.value){
          discountState(curPrice > price.value ? DISCOUNT_STATE.ENDED : DISCOUNT_STATE.STARTED)
          price(curPrice)
        }
      })
      if (to > 0) {
        if (to - ts > DISCOUNT_WARN_TIME){
          gui_scene.resetTimeout(to - ts - DISCOUNT_WARN_TIME,
            @() discountState(DISCOUNT_STATE.ENDING))
        } else {
          discountState(DISCOUNT_STATE.ENDING)
        }
      }
    }
  }
  let hasGold = Computed(@() price.value > 0)

  // price in silver OR tickets:
  let barterPrice = clone curItemCost
  let hasSilver = ENLISTED_SILVER in curItemCost
  local silverPrice = {}
  if (hasSilver){
    silverPrice = { [ENLISTED_SILVER] = curItemCost[ENLISTED_SILVER]}
    delete barterPrice[ENLISTED_SILVER]
  }
  let silverInfo = Computed(@()
    getPayItemsData(silverPrice, curCampItems.value, countWatched.value))
  let hasBarter = barterPrice.len() > 0
  let barterInfo = Computed(@()
    getPayItemsData(barterPrice, curCampItems.value, countWatched.value))

  let hasOfferExpired = Computed(@() pOfferGuid != null
    && discountState.value == DISCOUNT_STATE.ENDED)

  let hasSquads = (shopItem?.squads.len() ?? 0) > 0
  let hasPremDays = (shopItem?.premiumDays ?? 0) > 0
  let hasSlotSquad = hasSquadsEffects(bonusesList.value?[shopItem?.bonusId].armyEffects)
  let contentCtor = shopItemContentCtor(shopItem)
  let shopItemContent = contentCtor?.value?.content
  let isSoldier = (shopItemContent?.soldierClasses.len() ?? 0) > 0

  // title
  local title = isSoldier ? titleLocalization("shop/wantPurchaseSoldier", shopItem)
    : !hasSquads ? titleLocalization("shop/wantPurchaseMsg", shopItem)
    : shopItem?.nameLocId ? loc(shopItem.nameLocId)
    : ", ".join(shopItem.squads.map(@(sq) loc(squadsPresentation?[sq.armyId][sq.id].titleLocId)))

  local costLocId = "shop/noItemsToPay"

  if (hasBarter)
    foreach (cur, _ in curItemCost) {
      let curLocId = $"items/{cur}/acquire"
      let locId = $"shop/noItemsToPay/{cur}"

      if (doesLocTextExist(curLocId))
        title = $"{title}\n{loc(curLocId)}"

      if (doesLocTextExist(locId))
        costLocId = locId
    }

  let srcComponent = hasSquads ? "buy_squad_window" : "buy_shop_item"

  let function buyCb(isSuccess) {
    if (!isSuccess)
      return
    if (hasSquads || hasPremDays || hasSlotSquad)
      sound_play("ui/purchase_additional_squad")
    purchaseCb?()
  }

  let msgBoxContent = function() {
    local silverPriceView = null
    local barterPriceView = null
    local goldPriceView = null
    let statsList = !isSoldier ? null : mkStatList(shopItemContent, sClassesCfg.value)
    let msgBody = [
      limitTextBlock(limit, guid)
      isNotSuitable ? mkAlertObject(loc("shop/unsuitableForSoldier")) : null
      productView ?? mkDescription(shopItem?.descLocId)
      statsList
      typeof description == "string" ? mkItemDescription(description) : description
    ]

    let allPricesData = []

    if (hasSilver){
      silverPriceView = mkSinglePrice({
        currTpl = ENLISTED_SILVER
        value = curItemCost[ENLISTED_SILVER]
      }, countWatched.value, shopItem.guid)
      allPricesData.append(silverPriceView)
    }

    if (hasBarter) {
      let barterTpl = barterPrice.keys()[0]
      barterPriceView = mkSinglePrice({
        currTpl = barterTpl
        value = barterPrice[barterTpl]
      }, countWatched.value, shopItem.guid)
      allPricesData.append(barterPriceView)
    }

    if (hasGold.value){
      goldPriceView = mkSinglePrice({
        currTpl = "EnlistedGold"
        price = price.value
        fullPrice = fullPrice.value
      }, countWatched.value, shopItem.guid)
      allPricesData.append(goldPriceView)
    }

    let allPrices = mkAllPricesView(allPricesData)

    msgBody.append(allPrices)

    // not enough silver
    local canBuyWithGoldInfo = null
    if (hasSilver && !silverInfo.value) {
      msgBody.append(mkResourcesLackInfo(
        silverPrice, realCurrencies.value, "shop/noSilverToPay", countWatched.value))
      if (price.value > 0) {
        canBuyWithGoldInfo = canBuyWithGold
      }
    }

    // not enough orders
    if (hasBarter && !barterInfo.value){
      msgBody.append(mkResourcesLackInfo(
        barterPrice, realCurrencies.value, "shop/noItemsToPay", countWatched.value))
      if (price.value > 0) {
        canBuyWithGoldInfo = canBuyWithGold
      }
    }

    if (canBuyWithGoldInfo
      && (currenciesBalance.value?[currencyId] ?? 0) >= price.value * countWatched.value)
      msgBody.append(canBuyWithGoldInfo)

    // not enough gold
    if ((currenciesBalance.value?[currencyId] ?? 0) < price.value * countWatched.value)
      msgBody.append(notEnoughMoneyInfo(price.value * countWatched.value, currencyId))

    msgBody.append(mkDiscountInfo(discountState.value))

    let watch = [price, fullPrice, currenciesBalance, silverInfo, barterInfo, hasGold, countWatched,
      discountState, contentCtor, countWatched]
    return {
      watch
      size = [fsh(80), SIZE_TO_CONTENT]
      margin = [defGap, 0, 0, 0]
      flow = FLOW_VERTICAL
      halign = ALIGN_CENTER
      gap = bigPadding
      children = msgBody
    }
  }

  // all currencies for top-right corner
  let topPanel = function(){
    let allResources = []

    if (hasBarter){
      let allBarterCurrencies = curItemCost.keys().map(@(tpl) mkBarterCurrency(tpl))
      allResources.extend(allBarterCurrencies)
    }

    if (hasGold.value && currencyId in currenciesById.value){
      let amount = currenciesBalance.value?[currencyId]
      let buyResource =
        priceWidget(amount ?? loc("currency/notAvailable"), currencyId)
          .__update({
            size = [SIZE_TO_CONTENT, flex()]
            gap = hdpx(10)
          })
      allResources.append(buyResource)
    }

    return {
      watch = [hasGold, currenciesById, currenciesBalance]
      flow = FLOW_HORIZONTAL
      size = [SIZE_TO_CONTENT, flex()]
      gap = hdpx(20)
      children = allResources
    }
  }

  let buttons = Computed(function(){
    local isUsedX = false
    local isUsedY = false
    let countVal = countWatched.value
    let priceVal = price.value
    let realCurrenciesVal = realCurrencies.value
    let purchaseCurrency = openShopByCurrencyId?[currencyId]
    let btns = []

    if (hasSilver)
      if (silverInfo.value){
        let [silverTpl = null, silverPrc = 0] = silverPrice.topairs()?[0]
        let buyInfoSilver = getPayItemsData(silverPrice, curCampItems.value, countVal)
        let silverCurrImg = mkCurrencyImage(getCurrencyPresentation(silverTpl)?.icon)
        btns.append({
          action = function() {
            let deltaSilver = silverPrc * countVal - (realCurrenciesVal?[silverTpl] ?? 0)
            if (deltaSilver > 0)
              notEnoughMsg(silverTpl, deltaSilver)
            else
              barterShopItem(shopItem, buyInfoSilver, buyCb, countVal)
          }
          customStyle = {
            textCtor = function(textComp, params, handler, group, sf) {
              textComp = btnWithCurrImageComp(
                isSoldier ? loc("btn/enlist") : loc("btn/buy"),
                silverCurrImg,
                silverPrc,
                sf,
                countVal,
                shopItemPriceInc)
              params = params.__merge(fontHeading2)
              return textButtonTextCtor(textComp, params, handler, group, sf)
            }
          }.__update(primaryFlatButtonStyle, hotkeyY)
        })
        isUsedY = true
      } else if (referralLink == "")
        btns.append(replentishSilverBtn)

    if (hasBarter)
      if (barterInfo.value) {
        let [barterTpl = null, barterPrc = 0] = barterPrice.topairs()?[0]
        let buyInfoBarter = getPayItemsData(barterPrice, curCampItems.value, countVal)
        let barterCurrImgs = mkCurrencyImage(getCurrencyPresentation(barterTpl)?.icon)
        let customStyle = {
          textCtor = function(textComp, params, handler, group, sf) {
            textComp = btnWithCurrImageComp(
              isSoldier ? loc("btn/enlist") : loc("btn/buy"),
              barterCurrImgs,
              barterPrc,
              sf,
              countVal,
              shopItemPriceInc)
            params = params.__merge(fontHeading2)
            return textButtonTextCtor(textComp, params, handler, group, sf)
          }
        }.__update(primaryFlatButtonStyle, !isUsedY ? hotkeyY : {})

        btns.append({
          action = function() {
            let deltaBarter = barterPrc * countVal - (realCurrenciesVal?[barterTpl] ?? 0)
            if (deltaBarter > 0)
              notEnoughMsg(barterTpl, deltaBarter)
            else
              checkAndBuy(
                needAskOnSpendingTicket(barterTpl),
                @() barterShopItem(shopItem, buyInfoBarter, buyCb, countVal),
                titleLocalization("shop/wantPurchaseMsg", shopItem),
                customStyle,
                mkBarterCurrency(barterTpl)
              )
          }
          customStyle
        })
        isUsedY = true
      }

    if (referralLink != "" && ((hasSilver && !silverInfo.value)
      || (hasBarter && !barterInfo.value))){
      btns.append({
        text = loc("btn/gotoReferralLink")
        action = @() openUrl(referralLink, AuthenticationMode.NOT_AUTHENTICATED, true)
        customStyle = !isUsedY ? hotkeyY : {}
      })
      isUsedY = true
    }

    if (hasGold.value && !hasOfferExpired.value) {
      let currencyBalance = currenciesBalance.value?[currencyId] ?? 0
      if (currencyBalance >= priceVal * countVal) {
        let customStyle = {
          textCtor = function(_textComp, params, handler, group, sf) {
            let textComp = btnWithCurrImageComp(
              isSoldier ? loc("btn/enlist") : loc("btn/buy"),
              currencyImage(currency),
              priceVal,
              sf,
              countVal,
              shopItemPriceInc)
            params = params.__merge(fontHeading2)
            return textButtonTextCtor(textComp, params, handler, group, sf)
          }
        }.__update(purchaseButtonStyle, buyBtnStyle, hotkeyX)

        btns.append({
          action = function() {
            if (pOfferGuid != null) {
              buyShopOffer(shopItem, currencyId, priceVal, buyCb, pOfferGuid)
              sendBigQueryUIEvent("action_buy_currency", null, srcComponent)
              return
            }

            checkAndBuy(
              priceVal > 100 && needCheckAndBuy,
              function() {
                buyShopItem(shopItem, currencyId, priceVal, buyCb, countVal)
                sendBigQueryUIEvent("action_buy_currency", null, srcComponent)
              },
              titleLocalization("shop/wantPurchaseMsg", shopItem),
              customStyle,
              currenciesWidgetUi
            )
          }
          customStyle
        })
        isUsedX = true
      }
      else {
        btns.append({
          customStyle = {
            textCtor = function(textComp, params, handler, group, sf) {
              textComp = buyCurrencyText(currency, sf)
              params = params.__merge(fontHeading2)
              return textButtonTextCtor(textComp, params, handler, group, sf)
            }
          }.__update(hotkeyX),
          action = function() {
            purchaseCurrency?()
            sendBigQueryUIEvent("event_low_currency", null, srcComponent)
          }
        })
        isUsedX = true
      }
    }

    // No gold price and not enough items for barter:
    if (hasBarter && !barterInfo.value && referralLink == "" && !hasGold.value){
      let rewardIdx = getRewardIdx(curItemCost.keys()?[0])
      if (rewardIdx != null) {
        btns.append({
          text = loc("btn/gotoBattlepass")
          action = @() openBPwindow(rewardIdx)
        }.__update(!isUsedX ? hotkeyX
          : !isUsedY ? hotkeyY
          : {}))
        if (!isUsedX)
          isUsedX = true
        else if (!isUsedY)
          isUsedY = true
      }
    }

    btns.append({
      text = loc("Cancel")
      customStyle = { hotkeys = [[$"^{JB.B}" ]] }
    })

    if (viewBtnCb)
      btns.append({
        text = loc("btn/view")
        action = viewBtnCb
        customStyle = viewShopInfoBtnStyle.__merge(!isUsedY ? hotkeyY
          : !isUsedX ? hotkeyX
          : {})
      })

    return btns
  })

  if (hasBarter || hasSilver || hasGold.value){
    let params = {
      text = colorize(MsgMarkedText, title)
      fontStyle = fontBody
      children = msgBoxContent
      topPanel
      buttons
    }
    msgbox.showWithCloseButton(params)
    if (hasGold.value)
      sendBigQueryUIEvent("open_buy_currency_window", null, srcComponent)
    return
  }

  if (buyItemAction(shopItem))
    return

  // no silver, no tickets, no price in gold, simple "not enough tickets" msg box
  msgbox.showMsgbox({ text = loc(costLocId) })
}

return kwarg(buyItem)
