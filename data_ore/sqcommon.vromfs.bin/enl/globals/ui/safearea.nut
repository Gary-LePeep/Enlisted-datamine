from "%enlSqGlob/ui/ui_library.nut" import *

let {get_setting_by_blk_path} = require("settings")
let {fabs} = require("math")
let {globalWatched} = require("%dngscripts/globalState.nut")
let { getOrMkSaveData } = require("%enlSqGlob/mkOnlineSaveData.nut")
let platform = require("%dngscripts/platform.nut")
let { reload_ui_scripts, reload_overlay_ui_scripts } = require("app")
let { debugSafeAreaList, debugSafeAreaListUpdate } = globalWatched("debugSafeAreaList", @() false)

let blkPath = "video/safeArea"
let safeAreaList = (platform.is_xbox) ? [0.9, 0.95, 1.0]
  : platform.is_sony ? [require("sony").getDisplaySafeArea()]
  : debugSafeAreaList.value ? [0.9, 0.95, 1.0]
  : [1.0]
let canChangeInOptions = @() safeAreaList.len() > 1

function validate(val) {
  if (safeAreaList.indexof(val) != null)
    return val
  local res = null
  foreach (v in safeAreaList)
    if (res == null || fabs(res - val) > fabs(v - val))
      res = v
  return res
}
let safeAreaDefault = @() canChangeInOptions() ? validate(get_setting_by_blk_path(blkPath) ?? safeAreaList.top())
  : safeAreaList.top()

let storedAmount = getOrMkSaveData("safeAreaAmount", safeAreaDefault,
  @(value) canChangeInOptions() ? validate(value) : safeAreaDefault())

let {debugSafeAreaAmount, debugSafeAreaAmountUpdate} = globalWatched("debugSafeAreaAmount", @() null)
let {showSafeArea, showSafeAreaUpdate} = globalWatched("showSafeArea", @() false)

function setAmount(val) {
  storedAmount(val)
  debugSafeAreaAmountUpdate(null)
}

let amount = Computed(@() debugSafeAreaAmount.value ?? storedAmount.value)
let horPadding = Computed(@() sw(100*(1-amount.value)/2))
let verPadding = Computed(@() sh(100*(1-amount.value)/2))

console_register_command(@() showSafeAreaUpdate(!showSafeArea.value), "ui.safeAreaShow")

console_register_command(
  function(val = 0.9) {
    if (val > 1.0 || val < 0.9) {
      vlog(@"SafeArea is supported between 0.9 (lowest visible area) and 1.0 (full visible area).
This range is according console requirements. (Resetting to use in options = '{0}')".subst(storedAmount.value))
      debugSafeAreaAmountUpdate(null)
      return
    }
    debugSafeAreaAmountUpdate(val)
    reload_overlay_ui_scripts()
    reload_ui_scripts()
  }, "ui.safeAreaSet"
)

console_register_command(function() {
  debugSafeAreaListUpdate(!debugSafeAreaList.value)
  let actionText = debugSafeAreaList.value ? "added" : "removed"
  console_print($"SafeArea options {actionText}. Reload UI for changes.")
  reload_ui_scripts()
  reload_overlay_ui_scripts()
}, "ui.showDebugSafeAreaList")

return {
  verPadding
  horPadding

  safeAreaCanChangeInOptions = canChangeInOptions
  safeAreaBlkPath = blkPath
  safeAreaVerPadding = verPadding
  safeAreaHorPadding = horPadding
  safeAreaSetAmount = setAmount
  safeAreaAmount = amount
  safeAreaShow = showSafeArea
  safeAreaList = safeAreaList
}
