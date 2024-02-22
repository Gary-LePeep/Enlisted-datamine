from "%enlSqGlob/ui/ui_library.nut" import *

let {get_setting_by_blk_path} = require("settings")
let {getOnlineSaveData, optionCheckBox, optionCtor} = require("%ui/hud/menus/options/options_lib.nut")
let autoleanSettingState = require("%enlSqGlob/ui/autoleanState.nut")


let optionAutoleanCtor = @(actionCb) function (opt, group, xmbNode) {
  let optSetValue = opt.setValue
  function setValue(val) {
    optSetValue(val)
    actionCb(val)
  }
  opt = opt.__merge({ setValue })
  return optionCheckBox(opt, group, xmbNode)
}

function mkOption(title, blkPath, actionCb) {
  let { watch, setValue } = getOnlineSaveData(blkPath, @() get_setting_by_blk_path(blkPath) ?? false)
  return optionCtor({
    name = title
    tab = "Game"
    widgetCtor = optionAutoleanCtor(actionCb)
    var = watch
    setValue = setValue
    blkPath = blkPath
  })
}

return [
  mkOption(loc("gameplay/autolean_setting"), "gameplay/autolean_setting", @(enabled) autoleanSettingState(enabled))
]
