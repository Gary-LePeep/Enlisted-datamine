from "%enlSqGlob/ui/ui_library.nut" import *

let {rand, RAND_MAX} = require("math")
let {horPadding, verPadding} = require("%enlSqGlob/ui/safeArea.nut")
let {debug_borders,
  hudLayoutStateGen,
  getLeftPanelTop, getLeftPanelMiddle, getLeftPanelBottom,
  getCenterPanelTop, getCenterPanelMiddle, getCenterPanelBottom,
  getRightPanelBottom, getRightPanelTop, getRightPanelMiddle,
  centerPanelBottomStyle, centerPanelTopStyle, centerPanelMiddleStyle,
  rightPanelBottomStyle, rightPanelTopStyle, rightPanelMiddleStyle,
  leftPanelBottomStyle, leftPanelTopStyle, leftPanelMiddleStyle
} = require("state/hud_layout_state.nut")
let debug_borders_robj = @() (debug_borders.value ) ? ROBJ_FRAME: null

function debug_colors() {
  return Color(rand()*155/RAND_MAX+100, rand()*155/RAND_MAX+100, rand()*155/RAND_MAX+100)
}

function mpanel(elems, params={}) {
  return @() {
    size = flex()
    flow = FLOW_VERTICAL
    valign = ALIGN_TOP
    halign = ALIGN_LEFT
    rendObj = debug_borders_robj()
    color = debug_colors()
    watch = hudLayoutStateGen
    borderWidth = hdpx(1)
    gap = fsh(1)
  }.__update(params, {children=elems})
}


function panel(params={}) {
  let { size= flex(), children = null, watch = null } = params
  return @() {
    rendObj = debug_borders_robj()
    watch
    size
    color = debug_colors()
    flow = FLOW_VERTICAL
    padding = fsh(1)
    children
  }
}

function leftPanel(params={}) {
  return panel(params.__merge({
    watch = [leftPanelTopStyle, leftPanelMiddleStyle, leftPanelBottomStyle]
    size = flex(1)
    children = [
      mpanel(getLeftPanelTop(), { size =[flex(),flex(1)] }.__update(leftPanelTopStyle.value))
      mpanel(getLeftPanelMiddle(), { valign = ALIGN_BOTTOM size =[flex(),flex(3)] minHeight = SIZE_TO_CONTENT}.__update(leftPanelMiddleStyle.value))
      mpanel(getLeftPanelBottom(), {  valign = ALIGN_BOTTOM maxHeight = flex(1) size = [flex(),SIZE_TO_CONTENT]}.__update(leftPanelBottomStyle.value))
    ]
  }))
}
function centerPanel(params={}) {
  return panel(params.__merge({
    watch = [centerPanelTopStyle, centerPanelMiddleStyle, centerPanelBottomStyle]
    size = flex(2)
    children = [
      mpanel(getCenterPanelTop(), {halign = ALIGN_CENTER, size = [flex(),flex(3)]}.__update(centerPanelTopStyle.value))
      mpanel(getCenterPanelMiddle(), {halign = ALIGN_CENTER, valign = ALIGN_BOTTOM, size = [flex(),flex(2)]}.__update(centerPanelMiddleStyle.value))
      mpanel(getCenterPanelBottom(), {halign = ALIGN_CENTER valign = ALIGN_BOTTOM, size = [flex(), flex(1)]}.__update(centerPanelBottomStyle.value))
    ]
  }))
}

function rightPanel(params={}) {
  return panel(params.__merge({
    watch = [rightPanelTopStyle, rightPanelMiddleStyle, rightPanelBottomStyle]
    size = flex(1)
    children = [
      mpanel(getRightPanelTop(), { size =[flex(),flex(1)] halign=ALIGN_RIGHT}.__update(rightPanelTopStyle.value))
      mpanel(getRightPanelMiddle(), { size =[flex(),flex(2)] halign=ALIGN_RIGHT valign=ALIGN_CENTER}.__update(rightPanelMiddleStyle.value))
      mpanel(getRightPanelBottom(), { size =[flex(),flex(1)] halign=ALIGN_RIGHT valign=ALIGN_BOTTOM}.__update(rightPanelBottomStyle.value))
    ]
  }))
}

function footer(size) {
  return {
    size = [flex(), size]
    rendObj = debug_borders_robj()
    color = debug_colors()
  }
}

function header(size) {
  return {
    size = [flex(), size]
    rendObj = debug_borders_robj()
    color = debug_colors()
    flow = FLOW_HORIZONTAL
    padding = [0, fsh(2)]
  }
}

function HudLayout() {
  local children = []
  children = [
    header(max(verPadding.value, fsh(1)))
    {
      flow = FLOW_HORIZONTAL
      size = flex()
      children = [
        {size = [max(fsh(1), horPadding.value),flex()]} //leftPadding
        leftPanel({size=[fsh(40),flex()]})
        centerPanel()
        rightPanel({size=[fsh(40),flex()]})
        {size = [max(fsh(1), horPadding.value),flex()]} //rightPadding
      ]
    }
    footer(max(verPadding.value, fsh(1)))
  ]
  let desc = {
    size = flex()
    flow = FLOW_VERTICAL
    watch = [debug_borders, horPadding, verPadding, hudLayoutStateGen]
    children
  }


  return desc
}

return HudLayout
