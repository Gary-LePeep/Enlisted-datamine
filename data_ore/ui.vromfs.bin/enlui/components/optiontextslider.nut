from "%enlSqGlob/ui/ui_library.nut" import *

let {fontBody} = require("%enlSqGlob/ui/fontsStyle.nut")
let {DEFAULT_TEXT_COLOR} = require("%ui/hud/style.nut")
let slider = require("%ui/components/slider.nut")

let slider_value_width = calc_str_box("200%", fontBody)[0]

return function(opt, _group, xmbNode, morphText = @(val) val) {
  let valWatch = opt.var
  return {
    size = flex()
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    gap = fsh(1)

    children = [
      slider.Horiz(valWatch, opt.__merge({xmbNode}))
      @() {
        watch = valWatch
        size = [slider_value_width, SIZE_TO_CONTENT]
        rendObj = ROBJ_TEXT
        color = DEFAULT_TEXT_COLOR
        text = morphText(valWatch.value)
      }.__update(fontBody)
    ]
  }
}