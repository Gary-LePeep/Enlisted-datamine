from "%enlSqGlob/ui/ui_library.nut" import *

let { FORCE_EULA, showEula, acceptedEulaVersionBeforeLogin, eulaVersion } = require("%enlist/eula/eula.nut")
let { dgs_get_settings } = require("dagor.system")
let { set_setting_by_blk_path_and_save} = require("settings")

function isNewDevice(){
  let playedDevice = (dgs_get_settings()?["acceptedEulaVersionBeforeLogin"] ?? -1) > -1
  if (playedDevice)
    return false
  return true
}
function setAcceptedEulaVersionBeforeLogin(ver) {
  if ((ver ?? 0) > 0)
    set_setting_by_blk_path_and_save("acceptedEulaVersionBeforeLogin", ver)
}


function action(_login_status, cb) {
  if (isNewDevice()) {
    showEula(function(accept) {
      if (accept) {
        acceptedEulaVersionBeforeLogin(eulaVersion)
        setAcceptedEulaVersionBeforeLogin(eulaVersion)
        cb({})
      }
    }, FORCE_EULA)
  }
  else {
    acceptedEulaVersionBeforeLogin(eulaVersion)
    cb({})
  }
}

return {
  id  = "eula_before_login"
  action = action
}