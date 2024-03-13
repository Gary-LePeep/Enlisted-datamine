from "%enlSqGlob/ui/ui_library.nut" import *

let colorize = require("%ui/components/colorize.nut")
let { utf8ToUpper } = require("%sqstd/string.nut")
let { secondsToHoursLoc } = require("%ui/helpers/time.nut")
let { premiumActiveTime, hasPremium } = require("premium.nut")
let { fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let { defTxtColor, activeTxtColor, hasPremiumColor } = require("%enlSqGlob/ui/designConst.nut")

let premiumBtnSize = hdpxi(62)

let premiumImagePath = @(size) "!ui/uiskin/currency/enlisted_prem.svg:{0}:{0}:K"
    .subst(size.tointeger())

let premiumImage = @(size, override = {}) @() {
  watch = hasPremium
  rendObj = ROBJ_IMAGE
  size = [size, size]
  image = Picture(premiumImagePath(size))
  color = hasPremium.value ? Color(255,255,255) : Color(120,120,120)
}.__update(override)


function premiumActiveInfo(customStyle = {}, premColor = hasPremiumColor) {
  let timeLeft = Computed(@()
    premiumActiveTime.value > 0 ? secondsToHoursLoc(premiumActiveTime.value) : null)
  return @() timeLeft.value
    ? {
        watch = timeLeft
        rendObj = ROBJ_TEXTAREA
        behavior = Behaviors.TextArea
        color = activeTxtColor
        text = utf8ToUpper("{0} {1}".subst(loc("premium/activated"),
          loc("premium/activatedLeft", { timeInfo = colorize(premColor, timeLeft.value) })))
      }.__update(fontSub, customStyle)
    : {
        watch = timeLeft
        rendObj = ROBJ_TEXT
        color =  defTxtColor
        text = utf8ToUpper(loc("premium/notActivated"))
      }.__update(fontSub, customStyle)
}


let premiumBg = @(size) Picture("!ui/uiskin/premium/prem_bg.svg:{0}:{0}:K".subst(size))

return {
  premiumImage
  premiumActiveInfo
  premiumBtnSize
  premiumBg
}
