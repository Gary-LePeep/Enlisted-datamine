from "%enlSqGlob/ui/ui_library.nut" import *

let { startLogin } = require("%enlist/login/login_chain.nut")
let { isLoggedIn } = require("%enlSqGlob/ui/login_state.nut")
let { get_circuit } = require("app")
let { eventbus_subscribe } = require("eventbus")
let auth = require("auth")
let { addModalWindow, removeModalWindow } = require("%ui/components/modalWindows.nut")
let {
  browser_add_window_method = @(_n,_c) null,
  BROWSER_EVENT_INITIALIZED = null
} = require_optional("browser")
local isLoginStarted = false

const LOGIN_WND_UID = "login_back_window"
const BROWSER_WND_UID = "webbrowser_window"

let onLogingWnd = {
  key = LOGIN_WND_UID
  size = flex()
  rendObj = ROBJ_IMAGE
  image = Picture("ui/stalingrad_login_screen_blured.avif")
  keepAspect = KEEP_ASPECT_FILL
}

function onKongZhongAuthResult(result) {
  if (result.status == auth.YU2_OK && !isLoginStarted) {
    isLoginStarted = true
    removeModalWindow(BROWSER_WND_UID)
    startLogin({})
    addModalWindow(onLogingWnd)
  }
}

isLoggedIn.subscribe(function(v){
  if (v){
    isLoginStarted = false
    removeModalWindow(LOGIN_WND_UID)
  }
})


function handleBrowserWindowMethodCall(val) {
  if ("name" in val && "p1" in val) {
    if (val.name == "onKongZhongLoginComplete") {
      eventbus_subscribe("auth_kongzhong", onKongZhongAuthResult)
      auth.login_kongzhong({ kz_token = val.p1, circuit = get_circuit() }, "auth_kongzhong")
    }
  }
}

function handleBrowserEvent(val) {
  if ("eventType" in val && val.eventType == BROWSER_EVENT_INITIALIZED)
    browser_add_window_method("onKongZhongLoginComplete", 1)
}

eventbus_subscribe("browser_window_method_call", handleBrowserWindowMethodCall)
eventbus_subscribe("browser_event", handleBrowserEvent)
