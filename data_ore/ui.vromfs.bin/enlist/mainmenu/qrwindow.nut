from "%enlSqGlob/ui/ui_library.nut" import *

let JB = require("%ui/control/gui_buttons.nut")
let { fontHeading2, fontSub, fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let {ModalBgTint, TextDefault, WindowBlur} = require("%ui/style/colors.nut")
let { bigGap } = require("%enlSqGlob/ui/designConst.nut")
let mkQrCode = require("%ui/components/mkQrCode.nut")
let { openUrl, AuthenticationMode } = require("%ui/components/openUrl.nut")
let {addModalWindow, removeModalWindow} = require("%ui/components/modalWindows.nut")
let spinner = require("%ui/components/spinner.nut")


const WND_UID = "qr_window"
const URL_REFRESH_SEC = 300 //short token life time is 5 min.
let waitingSpinner = spinner()

function close(onCloseCb = null) {
  onCloseCb?()
  removeModalWindow(WND_UID)
}

let waitInfo = {
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  children = [
    { rendObj = ROBJ_TEXT, text = loc("xbox/waitingMessage"), color = TextDefault }.__update(fontSub)
    waitingSpinner
  ]
}

let qrWindow = kwarg(function (url, header = "", desc = "", needShowRealUrl = true) {
  let realUrl = Watched(null)
  function receiveRealUrl() {
    openUrl(url, AuthenticationMode.NOT_AUTHENTICATED, false, @(u) realUrl(u))
    gui_scene.setTimeout(URL_REFRESH_SEC, receiveRealUrl)
  }

  return @() {
    watch = realUrl
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    rendObj = ROBJ_WORLD_BLUR_PANEL
    color = WindowBlur
    padding = 2 * bigGap
    gap = bigGap

    flow = FLOW_VERTICAL
    halign = ALIGN_CENTER

    onAttach = receiveRealUrl
    onDetach = @() gui_scene.clearTimer(receiveRealUrl)

    children = [
      { rendObj = ROBJ_TEXT, text = header }.__update(fontHeading2)
      desc == "" ? null : {
        rendObj = ROBJ_TEXTAREA,
        behavior = Behaviors.TextArea,
        halign = ALIGN_CENTER
        text = desc,
        maxWidth = hdpx(600)
      }.__update(fontBody)
      needShowRealUrl ? { rendObj = ROBJ_TEXT, text = url }.__update(fontSub) : null
      realUrl.value ? mkQrCode({ data = realUrl.value }) : waitInfo
    ]
  }
})

return @(params, onCloseCb = null) addModalWindow({
  key = WND_UID
  size = [sw(100), sh(100)]
  rendObj = ROBJ_WORLD_BLUR_PANEL
  fillColor = ModalBgTint
  onClick = @() close(onCloseCb)
  children = qrWindow(params)
  hotkeys = [[$"^{JB.B} | Esc", { action = @() close(onCloseCb), description = loc("Cancel") }]]
})