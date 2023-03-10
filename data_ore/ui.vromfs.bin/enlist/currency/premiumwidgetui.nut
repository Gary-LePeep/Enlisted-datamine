from "%enlSqGlob/ui_library.nut" import *

let cursors = require("%ui/style/cursors.nut")
let tooltipBox = require("%ui/style/tooltipBox.nut")
let premiumWnd = require("premiumWnd.nut")
let { premiumActiveInfo, premiumImage } = require("premiumComp.nut")
let { smallPadding, bigPadding, discountBgColor
} = require("%enlSqGlob/ui/viewConst.nut")
let { sendBigQueryUIEvent } = require("%enlist/bigQueryEvents.nut")
let { premiumProducts } = require("%enlist/shop/armyShopState.nut")
let { mkNotifierBlink } = require("%enlist/components/mkNotifier.nut")

let IMAGE_WIDTH = hdpx(35)

let premDiscount = Computed(@()
  premiumProducts.value
    .reduce(@(res, val) max(res, (val?.discountInPercent ?? 0)), 0)
)

let premiumWidget = @() {
  watch = premDiscount
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  padding = bigPadding
  size = [IMAGE_WIDTH, SIZE_TO_CONTENT]
  vplace = ALIGN_TOP
  gap = smallPadding
  behavior = Behaviors.Button
  onClick = function() {
    premiumWnd()
    sendBigQueryUIEvent("open_premium_window", null, "menubar_premium")
  }
  onHover = @(on) cursors.setTooltip(on
    ? tooltipBox(premiumActiveInfo())
    : null)
  children = [
    premiumImage(IMAGE_WIDTH)
    premDiscount.value == 0 ? null
      : mkNotifierBlink(loc("shop/discount", { percents = premDiscount.value }),
          { size = SIZE_TO_CONTENT },
          { color = discountBgColor })
  ]
}

return premiumWidget
