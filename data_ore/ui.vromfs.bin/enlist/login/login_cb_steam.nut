from "%enlSqGlob/ui/ui_library.nut" import *

let auth = require("auth")
let defLoginCb = require("%enlist/login/login_cb.nut")
let {startLogin} = require("%enlist/login/login_chain.nut")
let {linkSteamAccount} = require("%enlSqGlob/ui/login_state.nut")
let msgbox = require("%enlist/components/msgbox.nut")
let { get_setting_by_blk_path } = require("settings")
let { accentTitleTxtColor } = require("%enlSqGlob/ui/designConst.nut")
let colorize = require("%ui/components/colorize.nut")

let isLinkToSteamEnabled = get_setting_by_blk_path("linkToSteamEnabled")

let isNewSteamAccount = mkWatched(persist, "isNewSteamAccount", false) //account which not linked

function createSteamAccount() {
  linkSteamAccount(false)
  startLogin({ onlyKnown = false })
}

let steamNewAccountMsg = @() msgbox.show({
  text = loc("msg/steam/loginByGaijinNet", { note = colorize(accentTitleTxtColor,
    loc("msg/steam/loginByGaijinNetNote")) })
  buttons = [
    { text = loc("LoginViaGaijinNet"), isCurrent = true, action = @() linkSteamAccount(true) }
    { text = loc("CreateSteamAccount"), action = createSteamAccount }
  ]
})

function onSuccess(state) {
  state.userInfo.isNewSteamAccount <- isNewSteamAccount.value
  defLoginCb.onSuccess(state)
  isNewSteamAccount(false)
}

function onInterrupt(state) {
  if (state?.stageResult.eula.stop) {
    if (isLinkToSteamEnabled)
      steamNewAccountMsg()
  }
  else if (state?.status == auth.YU2_NOT_FOUND) {
    isNewSteamAccount(true)
    if (isLinkToSteamEnabled)
      steamNewAccountMsg()
    else
      createSteamAccount()
    return
  }

  defLoginCb.onInterrupt(state)
}

return {
  onSuccess = onSuccess
  onInterrupt = onInterrupt
}
