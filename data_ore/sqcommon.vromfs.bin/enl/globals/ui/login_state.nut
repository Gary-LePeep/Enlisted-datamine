let { Computed } = require("frp")
let { nestWatched } = require("%dngscripts/globalState.nut")
let {userInfo, userInfoUpdate} = require("%enlSqGlob/userInfoState.nut")
let { hideAllModalWindows } = require("%ui/components/modalWindows.nut")
let {get_arg_value_by_name} = require("dagor.system")
let console_register_command = require("console").register_command
let {eventbus_subscribe} = require("eventbus")
let steam = require("steam")
let epic = require("epic")
let auth = require("auth")

let {get_setting_by_blk_path} = require("settings")

let isSteamRunning = nestWatched("isSteamRunning", steam.is_running())
let isEpicRunning = nestWatched("isEpicRunning", epic.is_running())
let isLoggedIn = keepref(Computed(@() userInfo.value != null))
let linkSteamAccount = nestWatched("linkSteamAccount", false)
let disableNetwork = get_setting_by_blk_path("debug")?.disableNetwork ?? get_arg_value_by_name("disableNetwork") ?? false

function logOut() {
  println("logout")
  hideAllModalWindows()
  userInfoUpdate(null)
}

console_register_command(logOut, "app.logout")

eventbus_subscribe(auth.token_renew_fail_event, function(_status) {
  println("logout due to auth token renew failure")
  logOut()
})

return {
  logOut
  isLoggedIn
  isSteamRunning
  isEpicRunning
  linkSteamAccount
  disableNetwork
}
