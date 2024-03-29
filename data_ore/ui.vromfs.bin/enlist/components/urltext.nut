from "%enlSqGlob/ui/ui_library.nut" import *

let { fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let { openUrl } = require("%ui/components/openUrl.nut")
let {Active, Inactive, ButtonHover} = require("%ui/style/colors.nut")

function url(str, address, params = {}) {
  let group = ElemGroup()
  let stateFlags = Watched(0)

  return function() {
    let sf = stateFlags.value
    let color = sf & S_ACTIVE ? Active
      : sf & S_HOVER ? ButtonHover
      : Inactive

    return {
      watch = stateFlags
      rendObj = ROBJ_TEXT
      behavior = Behaviors.Button
      sound = {
        hover = "ui/enlist/button_highlight"
        click = "ui/enlist/button_click"
      }
      text = str
      color
      group
      children = {
        rendObj = ROBJ_FRAME
        borderWidth = [0,0,2,0]
        color
        group
        size = flex()
        pos = [0, 2]
      }.__update(params?.childParams ?? {})
      onClick = function() { openUrl(address) }
      onElemState = @(newSF) stateFlags.update(newSF)
    }.__update(fontBody, params)
  }
}

return url
