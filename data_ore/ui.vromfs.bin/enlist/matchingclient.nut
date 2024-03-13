from "%enlSqGlob/ui/ui_library.nut" import *

let msgbox = require("%enlist/components/msgbox.nut")
let {matching_call, matching_notify} = require("matching.api")
let matching_errors = require("matching.errors")
let connectHolder = require("%enlist/connectHolderR.nut")
let { isSteamRunning, isLoggedIn, logOut, isSteamConnectionLost
} = require("%enlSqGlob/ui/login_state.nut")
let appInfo =  require("%dngscripts/appInfo.nut")
let { eventbus_subscribe, eventbus_subscribe_onehit } = require("eventbus")

local matchingLoginActions = []
let debugDelay = mkWatched(persist, "debugDelay", 0)

isLoggedIn.subscribe(function(val) {
  if (!val)
    connectHolder.deactivate_matching_login()
})

function netStateCall(func) {
  if (connectHolder.is_logged_in())
    func()
  else
    matchingLoginActions.append(func)
}


function matchingCallImpl(cmd, cb = null, params = null) {
  let res = matching_call(cmd, params)
  if (cb == null)
    return
  if (res?.reqId != null)
    eventbus_subscribe_onehit($"{cmd}.{res.reqId}", cb)
  else
    cb(res)
}

let matchingCall = @(cmd, cb = null, params = null) debugDelay.value <= 0
  ? matchingCallImpl(cmd, cb, params)
  : gui_scene.setTimeout(debugDelay.value, @() matchingCallImpl(cmd, cb, params))

function matchingNotify(cmd, params=null) {
  netStateCall(function() { matching_notify(cmd, params) })
}

eventbus_subscribe("matching.login_failed", function(_result) {
  matchingLoginActions = []
  logOut()
})

eventbus_subscribe("matching.logged_out", function(notify) {
  matchingLoginActions = []
  logOut()

  if (notify != null) {
    if (notify.reason == matching_errors.DisconnectReason.ConnectionClosed && notify.message.len() == 0) {
      if (isSteamRunning.value)
        isSteamConnectionLost(true)
      msgbox.show({
        text = loc("error/CLIENT_ERROR_CONNECTION_CLOSED")
        buttons = [{ text = loc("Ok"), isCurrent = true, action = @() null }]
      })
    }
    else {
      log($"Matching server disconnect by {notify.reason} with message {notify.message}")
      msgbox.show({
        text = loc("msgboxtext/matchingDisconnect",
          {error = loc("error/{0}".subst(notify.reason_str))})
      })
    }
  }
})

eventbus_subscribe("matching.logged_in", function(_reason) {
  let actions = matchingLoginActions
  matchingLoginActions = []
  foreach (act in actions)
    act()
})

function startLogin(userInfo) {
  let loginInfo = {
    userId = userInfo.userId
    userName = userInfo.name
    token = userInfo.chardToken
    versionStr = appInfo.version.value
    authJwt = userInfo.authJwt
  }

  connectHolder.activate_matching_login(loginInfo)
}

console_register_command(@(delay) debugDelay(delay), "matching.delay_calls")

return {
  serverResponseError = connectHolder.server_response_error
  matchingCall
  matchingNotify
  startLogin
  netStateCall
}
