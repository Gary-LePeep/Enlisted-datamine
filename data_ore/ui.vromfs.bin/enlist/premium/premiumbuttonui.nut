from "%enlSqGlob/ui/ui_library.nut" import *

let { fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let { panelBgColor, midPadding, hoverSlotBgColor } = require("%enlSqGlob/ui/designConst.nut")
let cursors = require("%ui/style/cursors.nut")
let tooltipBox = require("%ui/style/tooltipBox.nut")
let premiumWnd = require("%enlist/currency/premiumWnd.nut")
let { premiumActiveInfo, premiumImage, premiumBg
} = require("%enlist/currency/premiumComp.nut")
let { sendBigQueryUIEvent } = require("%enlist/bigQueryEvents.nut")
let { premiumProducts } = require("%enlist/shop/armyShopState.nut")
let { mkNotifierBlink } = require("%enlist/components/mkNotifier.nut")
let { hasPremium } = require("%enlist/currency/premium.nut")
let mkGlare = require("%enlist/components/mkGlareAnim.nut")


let IMAGE_WIDTH = hdpxi(62) - midPadding * 2
let btnWidth = hdpxi(62)


let hasDiscount = Computed(@() premiumProducts.value.findindex(@(i)
  (i?.discountInPercent ?? 0) > 0) != null)

let glareAnim = mkGlare({
  nestWidth = btnWidth
  glareWidth = btnWidth / 3
  glareDuration = 0.7
  glareOpacity = 0.5
  glareDelay = 5
})

let premiumWidget = watchElemState(@(sf) {
  watch = [hasDiscount, hasPremium]
  size = [btnWidth, btnWidth]
  vplace = ALIGN_TOP
  behavior = Behaviors.Button
  onClick = function() {
    premiumWnd()
    sendBigQueryUIEvent("open_premium_window", null, "menubar_premium")
  }
  onHover = @(on) cursors.setTooltip(on
    ? tooltipBox(premiumActiveInfo())
    : null)
  sound = {
    hover = "ui/enlist/button_highlight"
    click = "ui/enlist/button_click"
    active = "ui/enlist/button_action"
  }
  animations = hasPremium.value ? null
    : [{prop = AnimProp.color, from = panelBgColor, to = 0xFF302438, duration = 3,
        loop = true, play = true, easing = CosineFull }]
  children = {
    rendObj = ROBJ_SOLID
    color = sf & S_HOVER ? hoverSlotBgColor : panelBgColor
    size = [btnWidth, btnWidth]
    halign = ALIGN_CENTER
    hplace = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = [
      {
        rendObj = ROBJ_IMAGE
        opacity = sf & S_HOVER ? 1 : 0.6
        size = [btnWidth, btnWidth]
        image = premiumBg(btnWidth)
      }
      premiumImage(IMAGE_WIDTH)
      !hasDiscount.value ? null
        : mkNotifierBlink(loc("shop/discountNotify"), {
            size = SIZE_TO_CONTENT,
            vplace = ALIGN_BOTTOM
          }, {}, fontSub)
      hasPremium.value ? null : glareAnim
    ]
  }
})

return premiumWidget
