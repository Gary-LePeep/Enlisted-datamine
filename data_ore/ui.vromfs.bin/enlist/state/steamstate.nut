from "%enlSqGlob/ui/ui_library.nut" import *

let userInfo = require("%enlSqGlob/userInfo.nut")
let steam = require("steam")
let auth = require("auth")
let { openUrl } = require("%ui/components/openUrl.nut")
let { eventbus_subscribe_onehit } = require("eventbus")
let { get_circuit_conf } = require("app")

let isLinked = keepref(Computed(@() !steam.is_running() || (userInfo.value?.tags ?? []).indexof("steamlogin") == null))
let isOpenLinkUrlInProgress = Watched(false)
let steamBindUrl = get_circuit_conf()?.steamBindUrl

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

return {
  openSteamLinkUrl = openLinkUrl
  isSteamLinked = isLinked
  isOpenSteamLinkUrlInProgress = isOpenLinkUrlInProgress
}
