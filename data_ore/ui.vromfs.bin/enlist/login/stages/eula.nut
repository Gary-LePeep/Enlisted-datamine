from "%enlSqGlob/ui/ui_library.nut" import *

let { eulaVersion, showEula, acceptedEulaVersionBeforeLogin } = require("%enlist/eula/eula.nut")
//let platform = require("%dngscripts/platform.nut")

let onlineSettings = require("%enlist/options/onlineSettings.nut")
let eulaEnabled = true//(platform.is_pc || platform.is_xbox || platform.is_sony || platform.is_nswitch || platform.is_mobile)
function action(_login_status, cb) {
  if (!eulaEnabled) {
    log("eula check disabled")
    cb({})
    return
  }
  local acceptedVersion = onlineSettings.settings.value?["acceptedEULA"]
  log($"eulaVersion {eulaVersion}, accepted version before login {acceptedEulaVersionBeforeLogin.value}, current acceptedVersion: {acceptedVersion}")
  if ((acceptedEulaVersionBeforeLogin.value ?? -1) == eulaVersion || (acceptedVersion==null && ((acceptedEulaVersionBeforeLogin.value ?? -1) > -1)) ) {
    log("accepted current EULA version before login")
    acceptedVersion = acceptedEulaVersionBeforeLogin.value
    onlineSettings.settings.mutate(@(value) value["acceptedEULA"] <- acceptedVersion)
  }
  if (acceptedVersion != eulaVersion) {
    showEula(function(accept) {
      if (accept) {
        onlineSettings.settings.mutate(@(value) value["acceptedEULA"] <- eulaVersion)
        cb({})
      }
      else
        cb({stop = true})
    }, acceptedVersion != null)
  }
  else {
    cb({})
  }
}

return {
  id  = "eula"
  action = action
}