from "%enlSqGlob/ui/ui_library.nut" import *

let { TextDefault, BtnBdDisabled } = require("%ui/style/colors.nut")
let { show } = require("%ui/components/msgbox.nut")
let { addModalWindow } = require("%ui/components/modalWindows.nut")
let { eventbus_subscribe } = require("eventbus")
let { exitGameMsgBox } = require("%enlist/mainMsgBoxes.nut")
let fontIconButton = require("%ui/components/fontIconButton.nut")
let circuitConf = require("app").get_circuit_conf()
let stub = @(...) null
let { browser_reload_page=stub, can_use_embeded_browser=stub,
  browser_go_back=stub } = require_optional("browser")
let tgbapi = require("tgbapi")

let windowTitle = Watched(null)
let canGoBack = Watched(false)

const WND_UID = "webbrowser_window"

function handleBrowserEvent(val) {
  if ("canGoBack" in val)
    canGoBack(!!val.canGoBack)
  if ("title" in val)
    windowTitle(val.title ?? "")
}

eventbus_subscribe("browser_event", handleBrowserEvent)

let WEB_LOGIN_URL = circuitConf?.webLoginUrl

let windowTitleHeader = @() {
  size = [flex(), SIZE_TO_CONTENT]
  rendObj = ROBJ_TEXT
  vplace = ALIGN_CENTER
  watch = windowTitle
  halign = ALIGN_CENTER
  text = windowTitle.value
  color = TextDefault
  padding = [hdpx(5), hdpx(200)]
}

let buttonsBlock = {
  size = flex()
  flow = FLOW_HORIZONTAL
  padding = [0, hdpx(30)]
  valign = ALIGN_CENTER
  gap = hdpx(15)
  children = [
    fontIconButton("arrow-left", {
      onClick = browser_go_back
      watch = canGoBack
      isEnabled = @() canGoBack.value
      iconColor = @(_) canGoBack.value ? null : BtnBdDisabled
    })
    fontIconButton("refresh", {
      onClick = browser_reload_page
    })
    { size = flex() }
    fontIconButton("power-off", {
      onClick = exitGameMsgBox
    })
  ]
}

let controlPanel = {
  rendObj = ROBJ_SOLID
  size = [flex(), hdpx(35)]
  color = Color(0,0,0)
  valign = ALIGN_CENTER
  children = [
    buttonsBlock
    windowTitleHeader
  ]
}

return function showBrowser() {
  if (can_use_embeded_browser()) {
    local loginUrl = WEB_LOGIN_URL

    if (tgbapi.is_running())
      loginUrl = tgbapi.get_weblogin_url(WEB_LOGIN_URL)

    addModalWindow({
      key = WND_UID
      rendObj = ROBJ_SOLID
      flow = FLOW_VERTICAL
      Color = Color(0,0,0)
      onClick = @() null
      children = [
        controlPanel
        {
          size = flex()
          rendObj = ROBJ_BROWSER
          behavior = Behaviors.Browser
          defaultUrl = loginUrl
        }
      ]
    })
  } else {
    show({text = loc("error/CANNOT_DISPLAY_WEBBROWSER")})
  }
}
