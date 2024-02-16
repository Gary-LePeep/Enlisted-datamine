from "%enlSqGlob/ui_library.nut" import *

let { utf8ToUpper } = require("%sqstd/string.nut")
let { sendBigQueryUIEvent } = require("%enlist/bigQueryEvents.nut")
let premiumWnd = require("%enlist/currency/premiumWnd.nut")
let { isCurCampaignProgressUnlocked } = require("%enlist/meta/curCampaign.nut")
let { curCampaignAccessItem } = require("%enlist/campaigns/campaignConfig.nut")
let { hasPremium } = require("%enlist/currency/premium.nut")
let { unlockCampaignPromo } = require("%enlist/soldiers/lockCampaignPkg.nut")
let { fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let { mkColoredGradientX } = require("%enlSqGlob/ui/gradients.nut")
let mkCountdownTimer = require("%enlSqGlob/ui/mkCountdownTimer.nut")
let serverTime = require("%enlSqGlob/userstats/serverTime.nut")
let { txt } = require("%enlSqGlob/ui/defcomps.nut")
let { mkDiscountWidget } = require("%enlist/shop/currencyComp.nut")
let { smallPadding, midPadding, titleTxtColor, defTxtColor, selectedPanelBgColor,
  brightAccentColor } = require("%enlSqGlob/ui/designConst.nut")


let premiumTextTitle = @(sf) {
  rendObj = ROBJ_TEXT
  text = loc("premium/widgetTitle")
  behavior = Behaviors.TextArea
  color = sf & S_HOVER ? brightAccentColor : defTxtColor
}.__update(fontSub)

let premiumTextSubtitle = {
  rendObj = ROBJ_TEXT
  text = loc("premium/widgetSubtitle")
  color = brightAccentColor
}.__update(fontSub)

let greenGradient = mkColoredGradientX({colorLeft=0xFF007800, colorRight=0xFF145014})
let hoverGradient = mkColoredGradientX({colorLeft=0xFF009000, colorRight=0xFF007800})

let bw = hdpx(2)
let mkEdge = @(sf, isLeftSide) {
  rendObj = ROBJ_FRAME
  size = [hdpxi(16), flex()]
  color = sf & S_HOVER ? brightAccentColor : selectedPanelBgColor
  borderWidth = [bw, isLeftSide ? bw : 0, bw, isLeftSide ? 0 : bw]
}

let x2Size = [hdpxi(40), hdpxi(34)]
let x2Image = {
  rendObj = ROBJ_IMAGE
  size = x2Size
  margin = [hdpx(4), 0]
  image = Picture($"!ui/gameImage/premium_banner_x2.svg:{x2Size[0]}:{x2Size[1]}:K")
}

let mkPromoWidget = function(openWnd) {
  let discountData = Computed(function(prev){
    if (prev == FRP_INITIAL)
      prev = { isDiscountActive = false, endTime = 0, discountInPercent = 0 }

    let { discountIntervalTs = [], discountInPercent = 0 } = curCampaignAccessItem.value
    let [ beginTime = 0, endTime = 0 ] = discountIntervalTs
    let isDiscountActive = beginTime > 0
      && beginTime <= serverTime.value
      && (serverTime.value <= endTime || endTime == 0)
    let res = {isDiscountActive, endTime, discountInPercent}
    return isEqual(res, prev) ? prev : res
  })
  return function(srcWindow, srcComponent = null, override = {}){
    return watchElemState(@(sf) {
      watch = [discountData]
      flow = FLOW_VERTICAL
      behavior = Behaviors.Button
      onClick = @() openWnd(srcWindow, srcComponent)
      children = [
        !discountData.value.isDiscountActive ? null : {
          rendObj = ROBJ_IMAGE
          size = [flex(), SIZE_TO_CONTENT]
          image = sf & S_HOVER ? hoverGradient : greenGradient
          fillColor = sf & S_HOVER ? Color(0, 0, 0, 210) : null
          padding = smallPadding
          children = {
            flow = FLOW_HORIZONTAL
            valign = ALIGN_CENTER
            size = [flex(), SIZE_TO_CONTENT]
            gap = smallPadding
            children = [
              mkCountdownTimer({ timestamp = discountData.value.endTime })
              txt({
                text = utf8ToUpper(loc("shop/discountNotify"))
                color = titleTxtColor
              }).__update(fontSub)
              { size = flex() }
              mkDiscountWidget(discountData.value.discountInPercent)
            ]
          }
        }
        {
          valign = ALIGN_CENTER
          flow = FLOW_HORIZONTAL
          gap = smallPadding
          children = [
            mkEdge(sf, false)
            x2Image
            {
              flow = FLOW_VERTICAL
              size = [ SIZE_TO_CONTENT, flex() ]
              margin = [0, 0, 0, midPadding]
              children = [
                premiumTextTitle(sf)
                premiumTextSubtitle
              ]
            }
            mkEdge(sf, true)
          ]
        }
      ]
    }.__update(override))
  }
}

let openPremiumWnd = function(srcWindow, srcComponent) {
  premiumWnd()
  sendBigQueryUIEvent("open_premium_window", srcWindow, srcComponent)
}

let premiumWidget = mkPromoWidget(openPremiumWnd)

let promoWidget = @(srcWindow, srcComponent = null, override = {}) @() {
  watch = [isCurCampaignProgressUnlocked, hasPremium]
  children = !isCurCampaignProgressUnlocked.value ? unlockCampaignPromo(override)
    : hasPremium.value ? null
    : premiumWidget(srcWindow, srcComponent, override)
}

return {
  promoWidget
  premiumWidget
}