from "%enlSqGlob/ui_library.nut" import *

let { get_setting_by_blk_path } = require("settings")
let { globalWatched } = require("%dngscripts/globalState.nut")

let {harmonizationNickState, harmonizationNickStateUpdate} = globalWatched("harmonizationNickState",
  @() get_setting_by_blk_path("harmonizationNickEnabled") ?? false)



return {
  harmonizationNickState
  harmonizationNickStateUpdate
}