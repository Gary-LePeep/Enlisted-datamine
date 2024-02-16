from "%enlSqGlob/ui_library.nut" import *

let spinner = require("%ui/components/spinner.nut")(hdpxi(90))
let { abs, round } = require("math")
let { addModalWindow, removeModalWindow } = require("%ui/components/modalWindows.nut")
let buyShopItem = require("%enlist/shop/buyShopItem.nut")
let mkCountdownTimer = require("%enlSqGlob/ui/mkCountdownTimer.nut")
let { gameProfile } = require("%enlist/soldiers/model/config/gameProfile.nut")
let { utf8ToUpper } = require("%sqstd/string.nut")
let { fontGiant, fontTitle, fontHeading1, fontHeading2, fontBody, fontSub
} = require("%enlSqGlob/ui/fontsStyle.nut")
let { safeAreaBorders } = require("%enlist/options/safeAreaState.nut")
let { premiumProducts, purchaseInProgress } = require("%enlist/shop/armyShopState.nut")
let { sendBigQueryUIEvent } = require("%enlist/bigQueryEvents.nut")
let { currenciesList } = require("%enlist/currency/currencies.nut")
let { mkCurrency } = require("%enlist/currency/currenciesComp.nut")
let { mkDiscountWidget } = require("%enlist/shop/currencyComp.nut")
let { txt, noteTextArea } = require("%enlSqGlob/ui/defcomps.nut")
let { premiumActiveInfo, premiumImage } = require("premiumComp.nut")
let { bigPadding, accentTitleTxtColor, commonBtnHeight, titleTxtColor,
  selectedTxtColor, activeTxtColor, smallPadding, bgPremiumColor,
  basePremiumColor
} = require("%enlSqGlob/ui/viewConst.nut")
let { Purchase } = require("%ui/components/textButton.nut")
let { openUrl } = require("%ui/components/openUrl.nut")
let { mkHeaderFlag, primeFlagStyle, mkCenterHeaderFlag } = require("%enlSqGlob/ui/mkHeaderFlag.nut")
let colorize = require("%ui/components/colorize.nut")
let { normal } = require("%ui/style/cursors.nut")
let { premiumUrl = null } = require("app").get_circuit_conf()
let { allActiveOffers } = require("%enlist/offers/offersState.nut")
let { isGamepad } = require("%ui/control/active_controls.nut")
let { wndHeader } = require("%enlist/navigation/commonWndParams.nut")
let { transpBgColor, defItemBlur } = require("%enlSqGlob/ui/designConst.nut")
let { SLOT_COUNT, SLOT_COUNT_MAX } = require("%enlist/preset/presetEquipCfg.nut")
let { PREMIUM_SLOTS_COUNT } = require("%enlist/squadPresets/squadPresetsState.nut")


const WND_UID = "premiumWindow"
let WND_WIDTH = fsh(120)
let ANIM_DELAY = 0.1
let ANIM_TIME = 0.3
let BLINK_DELAY = 0.2
let BONUSES_TEXT_DELAY = 2.0

const DEFAULT_PREMIUM_DAYS = 30
let curSelectedId = Watched(null)
let curAnimatedId = Watched(null)
let showAnimation = Watched(true)


let defaultSelectedItem = keepref(Computed(@() premiumProducts.value.reduce(@(res, item)
    abs(res.premiumDays - DEFAULT_PREMIUM_DAYS) <= abs(item.premiumDays - DEFAULT_PREMIUM_DAYS)
      ? res : item)?.id))
defaultSelectedItem.subscribe(@(defItem) defItem ? curSelectedId(defItem) : null)

let mkImage = @(path, customStyle = {}) {
  rendObj = ROBJ_IMAGE
  size = flex()
  imageValign = ALIGN_TOP
  image = Picture(path)
}.__update(customStyle)

let function close() {
  if (curAnimatedId.value != null)
    curAnimatedId(null)
  else
    removeModalWindow(WND_UID)
}

let mkPremiumDescAnim = @(delay) !showAnimation.value ? {} : {
  transform = {}
  animations = [
    { prop = AnimProp.opacity, from = 0, to = 0, duration = delay + 0.05,
      play = true }
    { prop = AnimProp.opacity, from = 0, to = 1, duration = ANIM_TIME,
      delay, play = true, easing = OutQuad }
    { prop = AnimProp.translate, from = [0, -hdpx(150)], to = [0, 0],
      duration = ANIM_TIME, delay, play = true, easing = OutQuad, onFinish = @() showAnimation(false) }
  ]
}

let mkPremiumValAnim = @(delay, c1, c2) [
  { prop = AnimProp.color, from = c1, to = c2, duration = 0.75,
    play = true, delay }
  { prop = AnimProp.color, from = c2, to = c2, duration = 0.15,
    play = true, delay = delay + 0.7 }
  { prop = AnimProp.color, from = c2, to = c1, duration = 0.55,
    play = true, delay = delay + 0.8 }
  { prop = AnimProp.scale, from = [1,1], to = [1.1,1.1], duration = 0.25,
    play = true, delay }
  { prop = AnimProp.scale, from = [1.1,1.1], to = [1.1,1.1], duration = 0.35,
    play = true, delay = delay + 0.2 }
  { prop = AnimProp.scale, from = [1.1,1.1], to = [1,1], duration = 0.45,
    play = true, delay = delay + 0.5 }
]

let premiumDesc = @(idx, unitVal, descText, unitDesc = null) {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  padding = [fsh(4), fsh(1)]
  children = [
    {
      flow = FLOW_HORIZONTAL
      children = [
        txt({
          text = unitVal
          color = accentTitleTxtColor
          transform = {}
          animations = mkPremiumValAnim(BLINK_DELAY * idx + BONUSES_TEXT_DELAY,
            accentTitleTxtColor, activeTxtColor)
        }).__update(fontGiant)
        unitDesc == null ? null
          : txt({
              text = unitDesc
              color = activeTxtColor
              padding = [0, bigPadding]
            }).__update(fontHeading2)
      ]
    }
    {
      size = [flex(), SIZE_TO_CONTENT]
      children = noteTextArea(descText).__update({ color = activeTxtColor }, fontBody)
    }
  ]
}.__update(mkPremiumDescAnim(ANIM_DELAY * idx))

let function premiumDescBlock() {
  let { premiumBonuses = null } = gameProfile.value
  let {
    premiumExpMul = 1, maxSquadsInBattle = 0, soldiersReserve = 0
  } = premiumBonuses
  let expBonus = 100 * (premiumExpMul - 1)
  let equipSlots = SLOT_COUNT_MAX - SLOT_COUNT
  let squadSlots = PREMIUM_SLOTS_COUNT
  return {
    watch = gameProfile
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    gap = {
      rendObj = ROBJ_SOLID
      size = [hdpx(1), flex()]
      color = basePremiumColor
      margin = bigPadding
    }
    children = [
      premiumDesc(0, $"+{expBonus}%", loc("premiumDescExp"), loc("exp"))
      premiumDesc(2, $"+{maxSquadsInBattle}", loc("premiumDescSquadUnits"))
      premiumDesc(3, $"+{soldiersReserve}", loc("premiumDescReserve"))
      premiumDesc(4, "+2", loc("premiumDecalSlots"))
      premiumDesc(5, $"+{max(equipSlots, squadSlots)}",
        loc("premiumPresetsSlots", { equipSlots, squadSlots }))
    ]
  }
}

let function onPurchase(shopItem, premItemView, offer = null) {
  if (purchaseInProgress.value || curAnimatedId.value != null)
    return

  buyShopItem({
    shopItem
    pOfferGuid = offer?.guid
    productView = {
      margin = [0,0,fsh(3),0]
      halign = ALIGN_CENTER
      children = premItemView
    }
    purchaseCb = @() curAnimatedId(shopItem.id)
  })
  sendBigQueryUIEvent("action_buy_premium", "premium_promo")
}

let saveValueBlock = @(selected, percents) {
  rendObj = selected ? ROBJ_SOLID : ROBJ_BOX
  size = [hdpx(120), SIZE_TO_CONTENT]
  color = selected ? accentTitleTxtColor : null
  halign = ALIGN_CENTER
  borderWidth = [0, 0, hdpx(2), 0]
  padding = [hdpx(5), 0]
  children = {
    rendObj = ROBJ_TEXTAREA
    size = [flex(), SIZE_TO_CONTENT]
    behavior = Behaviors.TextArea
    halign = ALIGN_CENTER
    text = loc("shop/youSave", {
      percents = colorize(selected ? selectedTxtColor :  accentTitleTxtColor, $"{percents}%")
    })
    color = selected ? selectedTxtColor : titleTxtColor
  }
}

let discountBannerHeight = hdpxi(16 + 2*smallPadding)

let mkDiscountBanner = @(locId, endTime) {
  size = [flex(), 0]
  pos = [0, discountBannerHeight]
  valign = ALIGN_BOTTOM
  halign = ALIGN_CENTER
  gap = smallPadding
  flow = FLOW_VERTICAL
  children = [
    mkCenterHeaderFlag({
        size = [flex(), discountBannerHeight]
        rendObj = ROBJ_TEXT
        valign = ALIGN_CENTER
        halign = ALIGN_CENTER
        text = utf8ToUpper(loc(locId))
        color = selectedTxtColor
      }.__update(fontSub),
      primeFlagStyle.__merge({
        size = [pw(90), discountBannerHeight]
        centerColor = accentTitleTxtColor
        middle = 0.25
      })
    )
    endTime == 0 ? null : {
      rendObj = ROBJ_VECTOR_CANVAS
      size = [pw(80), discountBannerHeight]
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      commands = [
        [VECTOR_WIDTH, hdpx(1)],
        [VECTOR_FILL_COLOR, accentTitleTxtColor],
        [VECTOR_COLOR, Color(0,0,0,0)],
        [VECTOR_POLY, 10,0, 90,0, 80,100, 20,100],
      ]
      children = mkCountdownTimer({ timestamp = endTime, color = selectedTxtColor })
    }
  ]
}

let mkPremItemView = @(selected, size, days, saveVal, sf = 0) {
  rendObj = ROBJ_BOX
  size
  borderWidth = hdpx(1)
  borderColor = selected || (sf & S_HOVER) ? accentTitleTxtColor : basePremiumColor
  children = {
    flow = FLOW_VERTICAL
    hplace = ALIGN_CENTER
    halign = ALIGN_CENTER
    vplace = ALIGN_CENTER
    children = [
      saveVal <= 0 ? null
        : saveValueBlock(selected, saveVal)
      txt({
        text = days
        color = selected || (sf & S_HOVER) ? accentTitleTxtColor : activeTxtColor
      }).__update(fontTitle)
      txt({
        text = loc("premiumDays", { days })
        color = activeTxtColor
      }).__update(fontHeading2)
    ]
  }
}


let purchaseButton = @(action, params = {}) Purchase(loc("btn/buy"), action, {
  margin = 0
  size = [flex(), commonBtnHeight]
  hotkeys = [ ["^J:Y", {description={ skip=true } sound="click"}] ]
}.__update(params))

let backgroundImageBlock = {
  rendObj = ROBJ_IMAGE
  size = flex()
  image = Picture($"!ui/gameImage/prem_select_bg.svg")
}

let mkPremItem = kwarg(
  function(shopItem, idx, premSize, maxDayPrice, offer, currencies, curSelectedIdWatch) {
    let {
      id, premiumDays = 0, curShopItemPrice = {},
      discountInPercent = 0, discountIntervalTs = []
    } = shopItem
    local { currencyId = "", price = 0, fullPrice = 0 } = curShopItemPrice

    if (premiumDays == 0 || price == 0 || currencyId == "")
      return null

    let currency = currencies.findvalue(@(c) c.id == currencyId)
    if (currency == null)
      return null

    let isSelected = curSelectedIdWatch.value == id
    let saveVal = premiumDays <= 0 || maxDayPrice <= 0 ? 0
      : 100 - round(price.tofloat() / premiumDays / maxDayPrice * 100)
    let cellSize = [premSize, premSize]

    let discountBanner = offer != null ? mkDiscountBanner("specialOfferShort", offer.endTime)
      : discountInPercent > 0 ? mkDiscountBanner("shop/discountNotify", discountIntervalTs?[1] ?? 0)
      : null

    return {
      flow = FLOW_VERTICAL
      children = [
        watchElemState(@(sf) {
          behavior = Behaviors.Button
          onHover = function(on) {
            if (on && isGamepad.value)
              curSelectedIdWatch(id)
          }
          onClick = @() isSelected
            ? onPurchase(shopItem, mkPremItemView(true, cellSize, premiumDays, saveVal), offer)
            : curSelectedIdWatch(id)
          children = [
            isSelected ? backgroundImageBlock : null
            {
              flow = FLOW_VERTICAL
              halign = ALIGN_CENTER
              size = [premSize + hdpx(20), SIZE_TO_CONTENT]
              padding = [hdpx(8), 0,0,0]
              children = [
                {
                  size = [flex(), SIZE_TO_CONTENT]
                  halign = ALIGN_CENTER
                  children = [
                    mkPremItemView(isSelected, cellSize, premiumDays, saveVal, sf)
                      .__update(mkPremiumDescAnim(ANIM_DELAY * idx + 0.5))
                    discountBanner
                  ]
                }
                {
                  size = [premSize, hdpx(68)]
                  valign = ALIGN_CENTER
                  halign = ALIGN_CENTER
                  gap = {
                    size = flex()
                  }
                  flow = FLOW_HORIZONTAL
                  children = [
                    mkDiscountWidget(discountInPercent, mkPremiumDescAnim(ANIM_DELAY * idx + 0.5))
                    mkCurrency({
                      currency
                      price
                      fullPrice
                      txtStyle = { color = activeTxtColor }.__update(fontBody)
                      discountStyle = { color = activeTxtColor }.__update(fontBody)
                      dimStyle = { color = basePremiumColor}.__update(fontBody)
                    })
                  ]
                }
              ]
            }
          ]
        })
        !isSelected ? null :
          purchaseButton(@() onPurchase(shopItem,
            mkPremItemView(true, cellSize,  premiumDays, saveVal), offer))
      ]
    }.__update(mkPremiumDescAnim(ANIM_DELAY * idx + 0.5))
  })

let offersByPremItem = Computed(function() {
  let offers = allActiveOffers.value
  let res = {}
  foreach (shopItem in premiumProducts.value) {
    let offer = offers.findvalue(@(o) o?.shopItemGuid == shopItem.guid)
    if (offer != null)
      res[shopItem.guid] <- offer
  }
  return res
})

let function premiumBuyBlockUi() {
  let res = {
    watch = [curAnimatedId, premiumProducts, currenciesList, curSelectedId, offersByPremItem]
  }
  let premiumShopItems = premiumProducts.value
  if (curAnimatedId.value != null || premiumShopItems.len() == 0)
    return res

  let maxDayPrice = premiumShopItems.reduce(function(maxPrice, val) {
    let days = val.premiumDays
    let price = days > 0 ? val.curShopItemPrice.price / days : 0
    return max(price, maxPrice)
  }, 0)
  let premSize = min((WND_WIDTH / premiumShopItems.len()) - hdpx(20), hdpx(220))
  let offers = offersByPremItem.value
  return res.__update({
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    gap = { size = flex() }
    children = premiumShopItems.map(function(shopItem, idx) {
      let offer = offers?[shopItem.guid]
      return mkPremItem({
        shopItem, idx, premSize, maxDayPrice, offer,
        currencies = currenciesList.value,
        curSelectedIdWatch = curSelectedId
      })
    })
  })
}

let premiumBuyBlockBtn = {
  size = [pw(30), flex()]
  hplace = ALIGN_CENTER
  minWidth = SIZE_TO_CONTENT
  children = purchaseButton(@() openUrl(premiumUrl))
}

let premiumInfo = {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_HORIZONTAL
  padding = fsh(2)
  margin = [0,0,fsh(18),0]
  children = [
    premiumImage(hdpx(80))
    {
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_HORIZONTAL
      padding = fsh(1)
      children = [
        noteTextArea(loc("premiumDescBase"))
          .__update({
            color = activeTxtColor
          }, fontBody)
        {
          size = flex()
          halign = ALIGN_RIGHT
          children = premiumActiveInfo(fontHeading2, accentTitleTxtColor)
        }
      ]
    }
  ]
}

let premiumBlockContent = @() {
  size = flex()
  flow = FLOW_VERTICAL
  gap = bigPadding
  children = [
    premiumInfo
    mkHeaderFlag({
      padding = [fsh(2), fsh(3)]
      rendObj = ROBJ_TEXT
      text = utf8ToUpper(loc("premium/title"))
    }.__update(fontHeading1), primeFlagStyle)
    {
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      vplace = ALIGN_BOTTOM
      gap = bigPadding
      children = [
        premiumDescBlock
        premiumUrl != null ? premiumBuyBlockBtn : premiumBuyBlockUi
      ]
    }
  ]
}

let premiumInfoBlock = {
  size = flex()
  children = [
    mkImage("ui/gameImage/premium_bg.avif", { keepAspect = KEEP_ASPECT_FIT })
    premiumBlockContent()
  ]
  transform = {}
  animations = [
    { prop = AnimProp.opacity, from = 0, to = 1, duration = 0.5,
      play = true, easing = OutCubic }
    { prop = AnimProp.translate, from = [0, -hdpx(250)], to = [0, 0],
      duration = 0.2, play = true, easing = OutQuad }
  ]
}

let function open() {
  curSelectedId(defaultSelectedItem.value)
  showAnimation(true)
  addModalWindow({
    key = WND_UID
    rendObj = ROBJ_SOLID
    size = flex()
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    color = bgPremiumColor
    stopMouse = true
    stopHover = true
    cursor = normal
    children = [
      @() {
        watch = safeAreaBorders
        size = flex()
        maxHeight = fsh(100)
        padding = safeAreaBorders.value
        children = [
          {
            size = flex()
            flow = FLOW_HORIZONTAL
            halign = ALIGN_CENTER
            children = [
              {
                size = [flex(), ph(75)]
                maxWidth = hdpx(180)
                hplace = ALIGN_RIGHT
                children = mkImage("ui/gameImage/premium_decor_left.avif")
              }
              {
                size = [WND_WIDTH, flex()]
                children = premiumInfoBlock
              }
              {
                size = [flex(), ph(75)]
                maxWidth = hdpx(180)
                children = mkImage("ui/gameImage/premium_decor_right.avif")
              }
            ]
          }
          wndHeader(close)
        ]
      }
      @() {
        watch = purchaseInProgress
        pos = [0, -hdpx(180)]
        hplace = ALIGN_CENTER
        vplace = ALIGN_CENTER
        children = purchaseInProgress.value ? spinner : null
      }
      function() {
        let res = { watch = [curAnimatedId, premiumProducts] }
        let shopItemId = curAnimatedId.value
        if (shopItemId == null)
          return res

        let shopItem = premiumProducts.value.findvalue(@(s) s.id == shopItemId)
        if (shopItem == null)
          return res

        let days = shopItem?.premiumDays ?? 0
        return res.__update({
          size = flex()
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          rendObj = ROBJ_WORLD_BLUR_PANEL
          fillColor = transpBgColor
          color = defItemBlur
          children = {
            flow = FLOW_VERTICAL
            halign = ALIGN_CENTER
            valign = ALIGN_CENTER
            padding = [0,0,hdpxi(100),0]
            children = [
              txt({ text = loc("youHaveReceived") }).__update(fontHeading2)
              txt({ text = days, color = accentTitleTxtColor }).__update(fontTitle)
              txt({ text = loc("premiumDays", { days }), color = activeTxtColor
                }).__update(fontHeading2)
              {
                size = [hdpxi(140), hdpxi(140)]
                margin = bigPadding
                halign = ALIGN_CENTER
                valign = ALIGN_CENTER
                children = [
                  mkImage("ui/gameImage/searchlight_earth_flare.avif", {
                    size = [hdpxi(512), hdpxi(256)]
                  })
                  premiumImage(hdpxi(140))
                ]
              }
            ]
            transform = {}
            animations = [
              { prop = AnimProp.scale, from = [0.1, 0.1], to = [1, 1], duration = 0.7,
                play = true, easing = OutCubic }
              { prop = AnimProp.opacity, from = 0, to = 1, duration = 0.7,
                play = true, easing = OutCubic }
              { prop = AnimProp.scale, from = [1, 1], to = [2, 2], delay = 2.5, duration = 0.5,
                play = true, easing = OutCubic }
              { prop = AnimProp.opacity, from = 1, to = 0, delay = 2.5, duration = 0.5,
                play = true, onFinish = @() curAnimatedId(null) }
            ]
          }
        })
      }
    ]
    onClick = @() null
    onDetach = @() curAnimatedId(null)
  })
}

return open
