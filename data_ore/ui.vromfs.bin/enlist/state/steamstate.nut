from "%enlSqGlob/ui/ui_library.nut" import *

let auth = require("auth")
let isSteamNewPlayer = require("%enlist/unlocks/steamNewPlayer.nut")
let steam = require("steam")
let userInfo = require("%enlSqGlob/userInfo.nut")
let { eventbus_subscribe_onehit } = require("eventbus")
let { get_circuit_conf } = require("app")
let { get_setting_by_blk_path } = require("settings")
let { isSteamRunning } = require("%enlSqGlob/ui/login_state.nut")
let { openUrl } = require("%ui/components/openUrl.nut")

let isLinked = keepref(Computed(@() !steam.is_running() || (userInfo.value?.tags ?? []).indexof("steamlogin") == null))
let isOpenLinkUrlInProgress = Watched(false)
let steamBindUrl = get_circuit_conf()?.steamBindUrl
let isLinkToEmailEnabled = get_setting_by_blk_path("linkToEmailEnabled")

let goToSteamUrl = function(res) {
  let token = res?.token ?? ""
  if (token == "")
    log("Steam Email Registration: empty token")
  else if (steamBindUrl == null)
    log("No Steam bind url for current circuit")
  else
    openUrl(steamBindUrl.subst({ token = token, langAbbreviation = loc("langAbbreviation") }))
  isOpenLinkUrlInProgress(false)
}

function openLinkUrl() {
  if (!steamBindUrl || steamBindUrl == "")
    return log("Steam Email Registration: empty steamBindUrl in network.blk")

  isOpenLinkUrlInProgress(true)

  eventbus_subscribe_onehit("get_steam_link_token", goToSteamUrl)
  auth.get_steam_link_token("get_steam_link_token")
}

let isLinkEmailAvailable = Computed(@() isLinkToEmailEnabled && !isLinked.value
  && isSteamRunning.value && isSteamNewPlayer.value)

return {
  openSteamLinkUrl = openLinkUrl
  isSteamLinked = isLinked
  isOpenSteamLinkUrlInProgress = isOpenLinkUrlInProgress
  isLinkEmailAvailable
}
