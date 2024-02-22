from "%sqstd/frp.nut" import Watched, Computed, FRP_INITIAL, FRP_DONT_CHECK_NESTED, set_nested_observable_debug, make_all_observables_immutable
from "math" import clamp, min, max

let { loc } = require("%dngscripts/localizations.nut")
let { register_command, command } = require("console")
let { defer } = require("dagor.workcycle")
let darg_library = require("%darg/darg_library.nut")

global enum Layers {
  Default
  Upper
  ComboPopup
  MsgBox
  Blocker
  Tooltip
  Inspector
}

let export = {
  loc
  console_register_command = register_command
  console_command = command
  defer
}
let darg = require("daRg")
let logs = require("%enlSqGlob/library_logs.nut")

local screenScale = 1.0

function screenScaleUpdate(safeAreaScale) {
  screenScale = safeAreaScale
}

let getScreenScale = @() screenScale

let hdpx = @(pixels) darg_library.hdpx(pixels) * screenScale
let hdpxi = @(pixels) hdpx(pixels).tointeger()
let fsh = @(v) darg_library.fsh(v) * screenScale

let enlistedLibrary = darg_library.__merge({
  hdpx,
  hdpxi,
  fsh,
  screenScaleUpdate,
  getScreenScale
})

/*
let Pic = darg.Picture
let { send_error_log } = require("clientlog")

darg.Picture <- function(s){
  if (s.contains("/.svg") || s.contains("#.svg")) {
    logs.log(getstackinfos(2))
    send_error_log("incorrect_image_name", {
      attach_game_log = true
      collection = "events"
      meta = {
        hint = "error"
      }
    })
    return null
  }
  return Pic(s)
}
*/

return export.__update(
  {Watched, Computed, FRP_INITIAL, FRP_DONT_CHECK_NESTED, set_nested_observable_debug, make_all_observables_immutable, min, max, clamp},
  darg,
  logs,
  enlistedLibrary,
  require("%sqstd/functools.nut")
)
