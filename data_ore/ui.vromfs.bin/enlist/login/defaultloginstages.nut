from "%enlSqGlob/ui/ui_library.nut" import *

let platform = require("%dngscripts/platform.nut")
let { disableNetwork } = require("%enlSqGlob/ui/login_state.nut")

return disableNetwork ? require("chains/login_pc.nut")
  : platform.is_xbox ? require("chains/login_xbox.nut")
  : platform.is_sony ? require("chains/login_ps4.nut")
  : require("chains/login_pc.nut")
