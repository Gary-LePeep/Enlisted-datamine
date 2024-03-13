from "%enlSqGlob/ui/ui_library.nut" import *

let { addModalWindow, removeModalWindow } = require("%ui/components/modalWindows.nut")
let { Bordered } = require("%ui/components/txtButton.nut")
let { defTxtColor } = require("%enlSqGlob/ui/designConst.nut")
let { fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let { openUrl } = require("%ui/components/openUrl.nut")
let { PrimaryFlat } = require("%ui/components/textButton.nut")
let { round } = require("math")
let { setSteamRateWindowSeenFlag, steamURL } = require("%enlist/steam/steamRateState.nut")
let fontIconButton = require("%ui/components/fontIconButton.nut")
let JB = require("%ui/control/gui_buttons.nut")

const steamRatioWndUID = "steam_ratio_wnd"

let logoSize = [sw(10), round(sw(10) * (66.0 / 210.0))]

let function closeWindow() {
  removeModalWindow(steamRatioWndUID)
}

let closeBtn = fontIconButton("close", {
  skipDirPadNav = true
  onClick = closeWindow
  hplace = ALIGN_RIGHT
  vplace = ALIGN_TOP
  size = [fsh(5), fsh(5)]
})

let mkWindow = @() {
  size = flex()
  children = [
    {
      flow = FLOW_VERTICAL
      size = flex()
      children = [
        {
          rendObj = ROBJ_IMAGE
          size = [sw(100), round(sw(100) * (280.0/1920.0))]
          image = Picture("ui/uiskin/steam/steam_rate_bg.avif")
        }
        {
          rendObj = ROBJ_IMAGE
          size = flex()
          keepAspect = KEEP_ASPECT_FILL
          image = Picture("ui/uiskin/steam/steam_bg.avif")
          color = 0xFF808080
        }
      ]
    }
    {
      rendObj = ROBJ_IMAGE
      pos = [sw(30), sh(18)]
      size = logoSize
      image = Picture($"!ui/uiskin/steam/steam_logo.svg:{logoSize[0]}:{logoSize[1]}:K")
      keepAspect = KEEP_ASPECT_FIT
    }
    {
      flow = FLOW_VERTICAL
      size = [sw(40), SIZE_TO_CONTENT]
      hplace = ALIGN_CENTER
      vplace = ALIGN_BOTTOM
      halign = ALIGN_CENTER
      margin = [0, 0, sh(15), 0]
      children = [
        {
          rendObj = ROBJ_TEXTAREA
          size = [flex(), SIZE_TO_CONTENT]
          behavior = Behaviors.TextArea
          color = defTxtColor
          text = loc("steam/rate_review")
          margin = [0, 0, sh(5), 0]
        }.__update(fontBody)
        {
          flow = FLOW_HORIZONTAL
          size = [flex(), SIZE_TO_CONTENT]
          gap = sw(20)
          halign = ALIGN_CENTER
          children = [
            Bordered(loc("Close"), closeWindow, { hotkeys=[[$"^{JB.B} | Esc" ]] })
            PrimaryFlat(loc("steam/review"), function() {
                openUrl(steamURL)
              closeWindow()
            }, { hotkeys = [["^J:X | Enter"]] })
          ]
        }
      ]
    }
    closeBtn
  ]
}

function openSteamReviewWnd() {
  setSteamRateWindowSeenFlag()
  addModalWindow({
    key = steamRatioWndUID
    size = flex()
    onClick = @() null
    children = mkWindow()
  })
}

console_register_command(function() {
  openSteamReviewWnd()
}, "debug.show_steam_rate_wnd")

return {
  openSteamReviewWnd
}
