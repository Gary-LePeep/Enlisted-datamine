from "%enlSqGlob/ui/ui_library.nut" import *

let cursors = require("%ui/style/cursors.nut")
let picSz = hdpxi(54)
let {hudIsInteractive} = require("%ui/hud/state/interactive_state.nut")
let { serverResponseError } = require("%enlist/matchingClient.nut")

let isSavingData = Watched(false)

function pic(name) {
  return Picture("ui/skin#info/{0}.svg:{1}:{1}:K".subst(name, picSz))
}

let mkIcon = @(iconName, tipText, isVisibleWatch, color) @() {
    watch = [isVisibleWatch, hudIsInteractive]
    key = iconName
    children =  isVisibleWatch.value
                ? {
                    flow = FLOW_HORIZONTAL
                    rendObj = ROBJ_SOLID
                    color = Color(0,0,0,200)
                    size = [picSz * 5, picSz * 1.5]
                    halign = ALIGN_RIGHT
                    valign = ALIGN_CENTER
                    margin = hdpx(5)
                    children = [
                    {
                      text = loc(tipText, "")
                      rendObj = ROBJ_TEXTAREA
                      behavior = Behaviors.TextArea
                      color = color
                      size = [picSz * 3.2, picSz]
                      halign = ALIGN_CENTER
                      valign = ALIGN_CENTER
                    }
                    {
                      behavior = hudIsInteractive.value ? Behaviors.Button : null
                      onHover = @(on) cursors.setTooltip(on ? loc(tipText, "") : null)
                      image = pic(iconName)
                      rendObj = ROBJ_IMAGE
                      color = color
                      margin = hdpx(15)
                      animations = [{ prop = AnimProp.opacity, from = 0.5, to = 1.0,
                        duration = 1, play = true, loop = true, easing = Blink}]
                    }]
                  }
                : null
}

let noServerStatus = mkIcon("no_connection_error", "connectingToServer", serverResponseError, Color(200, 50, 0, 160))
let saveDataStatus = mkIcon("data_saving", "hud/saving_data", isSavingData, Color(255, 200, 15, 160))

return {
  //NetworkStatus = mkIcon("no_network", "hud/no_network")
  noServerStatus
  saveDataStatus
}
