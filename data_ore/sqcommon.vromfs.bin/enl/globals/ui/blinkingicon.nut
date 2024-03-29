from "%enlSqGlob/ui/ui_library.nut" import *

let faComp = require("%ui/components/faComp.nut")
let defcomps = require("%enlSqGlob/ui/defcomps.nut")
let { unseenColor, brightAccentColor } = require("%enlSqGlob/ui/designConst.nut")


let fxOverride = {
  fontFxColor = 0xAA000000
  fontFxFactor = hdpx(16)
  fontFx = FFT_SHADOW
  fontFxOffsX = hdpx(1)
  fontFxOffsY = hdpx(1)
}

let blinkingIcon = @(iconId, text = null) {
  hplace = ALIGN_RIGHT
  vplace = ALIGN_TOP
  valign = ALIGN_CENTER
  flow = FLOW_HORIZONTAL
  margin = [hdpx(2), hdpx(3), 0, 0]
  gap = hdpx(1)
  transform = {}
  animations = [{
    prop = AnimProp.opacity, from = 0.3, to = 1, duration = 1,
    play = true, loop = true, easing = Blink
  }]
  children = [
    faComp(iconId, {
      fontSize = hdpx(13)
      color = unseenColor
    }.__update(fxOverride))
    text != null ? defcomps.note({ text, color = unseenColor }) : null
  ]
}


let manageBlinkingObject = {
  size = flex()
  rendObj = ROBJ_BOX
  borderWidth = hdpx(2)
  borderColor = brightAccentColor
  fillColor = 0x33333333
  animations = [{
    prop = AnimProp.opacity, from = 1, to = 0, duration = 1,
    play = true, loop = true, easing = Blink
  }]
}


return {
  blinkingIcon
  manageBlinkingObject
}
