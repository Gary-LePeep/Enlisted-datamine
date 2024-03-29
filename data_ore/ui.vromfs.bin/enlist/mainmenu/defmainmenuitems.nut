from "%enlSqGlob/ui/ui_library.nut" import *

let platform = require("%dngscripts/platform.nut")
let { showControlsMenu } = require("%ui/hud/menus/controls_setup.nut")
let { showSettingsMenu } = require("%ui/hud/menus/settings_menu.nut")
let {exitGameMsgBox, logoutMsgBox} = require("%enlist/mainMsgBoxes.nut")
let { openUrl } = require("%ui/components/openUrl.nut")
let { gaijinSupportUrl, bugReportUrl, legalsUrl } = require("%enlSqGlob/supportUrls.nut")
let { get_setting_by_blk_path } = require("settings")
let qrWindow = require("qrWindow.nut")
let { openSteamLinkUrl } = require("%enlist/state/steamState.nut")

let SEPARATOR = {}
let GSS_URL = get_setting_by_blk_path("gssUrl") ?? "https://gss.gaijin.net/"
let CBR_URL = get_setting_by_blk_path("cbrUrl") ?? "https://community.gaijin.net/issues/p/enlisted"

let btnOptions = {
  name = loc("gamemenu/btnOptions")
  id = "Options"
  cb = @() showSettingsMenu(true)
}
let btnControls = {
  id = "Controls"
  name = loc("gamemenu/btnBindKeys")
  cb = @() showControlsMenu(true)
}
let btnExit = {
  id = "Exit"
  name = loc("Exit Game")
  cb = exitGameMsgBox
}
let btnLogout = {
  id = "Exit"
  name = loc("Exit Game")
  cb = logoutMsgBox
}
let allowUrl = platform.is_pc
let btnGSS = GSS_URL == "" ? null : {
  id = "Gss"
  name = loc("gss")
  cb = @() allowUrl ? openUrl(GSS_URL) : qrWindow({url = GSS_URL, header = loc("gss")})
}
let btnCBR = CBR_URL == "" ? null : {
  id = "Cbr"
  name = loc("cbr")
  cb = @() allowUrl ? openUrl(CBR_URL) : qrWindow({url = CBR_URL, header = loc("cbr")})
}
let btnSupport = gaijinSupportUrl == "" ? null : {
  id = "Support"
  name = loc("support")
  cb = @() allowUrl ? openUrl(gaijinSupportUrl)
    : qrWindow({url = gaijinSupportUrl, header = loc("support")})
}

let btnLegals = legalsUrl == "" ? null : {
  id = "Legals"
  name = loc("Legals")
  cb = @() allowUrl
    ? openUrl(legalsUrl, false, platform.is_mobile )
    : qrWindow({ url = legalsUrl, header = loc("Legals") })
}

let btnBugReport = (bugReportUrl == "" || !platform.is_pc) ? null : {
  id = "reportProblem"
  name = loc("gamemenu/btnReportProblem")
  cb = @() openUrl(bugReportUrl)
}

let btnLinkEmail = {
  id = "LinkEmail"
  name = loc("gamemenu/btnLinkAccount")
  cb = openSteamLinkUrl
}

return {
  btnControls
  btnOptions
  btnLogout
  btnExit
  btnGSS
  btnLinkEmail
  btnCBR
  btnSupport
  btnBugReport
  btnLegals
  SEPARATOR
}
