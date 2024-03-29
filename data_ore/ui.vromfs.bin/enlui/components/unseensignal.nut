from "%enlSqGlob/ui/ui_library.nut" import *


let faComp = require("%ui/components/faComp.nut")
let { UnseenGlow, UnseenIcon } = require("%ui/style/colors.nut")

let blinkAnimation = [ { prop = AnimProp.opacity, from = 0.3, to = 1, duration = 1, play = true,
  loop = true, easing = Blink} ]


let mkUnseenIcon = @(animations = null)
  @(scale = 1, iconColor = UnseenIcon, iconName = "exclamation-circle") faComp(iconName, {
    size = [hdpx(32 * scale), hdpx(32 *scale)]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    rendObj = ROBJ_INSCRIPTION
    fontSize = hdpx(16 * scale)
    fontFxColor = UnseenGlow
    fontFxFactor = min(hdpx(64), 64)
    fontFx = FFT_GLOW
    color = iconColor
    animations
  })


return {
  blinkUnseenIcon = mkUnseenIcon(blinkAnimation)
  noBlinkUnseenIcon = mkUnseenIcon()
}
