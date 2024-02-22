from "%enlSqGlob/ui/ui_library.nut" import *

let { is_xbox, is_xboxone, is_xboxone_X, is_xbox_scarlett, isXboxScarlett, is_xbox_anaconda,
  is_ps4_simple, is_ps4_pro, is_ps5, is_ps4 } = require("%dngscripts/platform.nut")
let { loc_opt, optionSpinner, optionCtor } = require("%ui/hud/menus/options/options_lib.nut")

let { resolutionToString } = require("%ui/hud/menus/options/render_options.nut")
let { resolutionList } = require("%ui/hud/menus/options/resolution_state.nut")
let { get_setting_by_blk_path } = require("settings")

let { globalWatched } = require("%dngscripts/globalState.nut")

const ConsolePresetBlkPath = "graphics/consolePreset"

local availableGraphicPresets = ["HighFPS"]
if (is_xbox) {
  if (is_xboxone && !is_xboxone_X)
    availableGraphicPresets = ["HighFPS"]
  else
    availableGraphicPresets = [ "HighFPS", "HighQuality" ]
}
else if (is_ps4)
  availableGraphicPresets = ["HighFPS"]
else if (is_ps5)
  availableGraphicPresets = [ "HighFPS", "HighQuality" ]


let { consoleGraphicsPreset, consoleGraphicsPresetUpdate } = globalWatched("consoleGraphicsPreset",
  @() get_setting_by_blk_path(ConsolePresetBlkPath) ?? availableGraphicPresets[0])

wlog(consoleGraphicsPreset, "consoleGraphicsPreset")

const bm_anisotropy = 1
const hfps_anisotropy = 2
const hq_anisotropy = 4

let consoleGfxSettingsBlk = get_setting_by_blk_path("graphics/consoleGfxSettings")
let presetAvailable = ((consoleGfxSettingsBlk == null) || (consoleGfxSettingsBlk == false)) && availableGraphicPresets.len() > 1
function preset_val_loc(v) {
  if (isXboxScarlett && v == "HighFPS")
    return loc("option/HighFPSwithHint")
  else if (availableGraphicPresets.contains("bareMinimum"))
    return v == "bareMinimum" ? loc_opt("HighFPS") : loc_opt("HighQuality")
  else
    return loc_opt(v)
}

let optXboxGraphicsPreset = optionCtor({
  name = loc("options/graphicsPreset")
  widgetCtor = optionSpinner
  tab = "Graphics"
  var = consoleGraphicsPreset
  setValue = consoleGraphicsPresetUpdate
  defVal = "HighFPS"
  isAvailable = @() presetAvailable
  available = availableGraphicPresets
  valToString = preset_val_loc
  blkPath = ConsolePresetBlkPath
  getMoreBlkSettings = function(v){
    return [
      {blkPath = "video/resolution", val = resolutionToString(resolutionList.value?[v == "HighFPS" ? 0 : 1] ?? "auto")},
      {blkPath = "graphics/lodsShiftDistMul", val = (v != "HighQuality" ? 1.3 : 1.0)},
      {blkPath = "graphics/taaQuality",   val = (v == "HighQuality" || (is_xboxone_X || is_xbox_scarlett) ? 1 : 0)},
      {blkPath = "graphics/anisotropy", val = (v == "HighFPS" ? hfps_anisotropy : (v == "HighQuality" ? hq_anisotropy : bm_anisotropy))},
      {blkPath = "graphics/aoQuality", val = (v != "HighQuality" ? ((is_xboxone_X || is_xbox_scarlett) ? "medium": "low") : "high")},
      {blkPath = "graphics/groundDeformations", val = (v == "HighQuality" ? "medium" : "off")},
      {blkPath = "graphics/shadowsQuality", val = (v == "HighQuality" ? "high" : (v == "HighFPS" ? "low" : "minimum"))},
      {blkPath = "graphics/effectsShadows", val = (v == (is_xboxone_X || is_xbox_scarlett))},
      {blkPath = "graphics/dropletsOnScreen", val = (v == "HighQuality")},
      {blkPath = "graphics/scopeImageQuality", val = (v == "HighQuality" ? 1 : 0)},
      {blkPath = "graphics/fxTarget", val = (v == "HighQuality" ? "highres" : "lowres")},
      {blkPath = "graphics/shouldRenderHeroCockpit", val = true},
      {blkPath = "graphics/giQuality", val = ((v == "HighQuality" && is_xboxone_X) || is_xbox_scarlett) ? "medium" : "minimum"},
      {blkPath = "graphics/skiesQuality", val = (is_xboxone ? "low" : (v == "HighFPS" ? "medium" : "high"))},
      {blkPath = "video/freqLevel", val = (v == "HighFPS" ? 3 : 1)},
      {blkPath = "video/antiAliasingMode", val = (is_xboxone_X || is_xbox_scarlett ? 3 : 2)}, //3 = TSR 2 = TAA
      {blkPath = "video/temporalUpsamplingRatio", val = (is_xboxone_X || is_xbox_scarlett ? 80.0 : 100.0)},
      {blkPath = "graphics/ssssQuality", val = ((v == "HighQuality" && is_xboxone_X) || is_xbox_scarlett ? "high" : "off")},
      {blkPath = "graphics/cloudsQuality", val = (is_xbox_scarlett ? (v == "HighQuality" && is_xbox_anaconda ? "volumetric" : "highres") : "default")},
      {blkPath = "graphics/volumeFogQuality", val = "close"},
      {blkPath = "graphics/waterQuality", val = ((is_xbox_scarlett && v == "HighQuality") ? "medium" : "low")},
    ]
  }
})

let optPSGraphicsPreset = optionCtor({
  name = loc("options/graphicsPreset")
  widgetCtor = optionSpinner
  tab = "Graphics"
  var = consoleGraphicsPreset
  setValue = consoleGraphicsPresetUpdate
  defVal = "HighFPS"
  isAvailable = @() presetAvailable
  available = availableGraphicPresets
  valToString = preset_val_loc
  blkPath = ConsolePresetBlkPath
  getMoreBlkSettings = function(v){
    return [
      {blkPath = "video/resolution", val = resolutionToString(resolutionList.value?[v == "HighFPS" && is_ps5 ? 0 : 1] ?? "auto")},
      {blkPath = "graphics/lodsShiftDistMul", val = (v != "HighQuality" ? 1.3 : 1.0)},
      {blkPath = "graphics/taaQuality",   val = (is_ps4_pro? 2 : ((v == "HighQuality" || is_ps5)? 1:0))},
      {blkPath = "graphics/anisotropy", val = (v == "HighFPS" ? hfps_anisotropy : (v == "HighQuality" ? hq_anisotropy : bm_anisotropy))},
      {blkPath = "graphics/aoQuality", val = (v != "HighQuality" ? (is_ps4_pro ? "medium": "low") : "high")},
      {blkPath = "graphics/groundDeformations", val = (v == "HighQuality" ? "medium" : "off")},
      {blkPath = "graphics/shadowsQuality", val = (v == "HighQuality" ? "high" : (v == "HighFPS" ? "low" : "minimum"))},
      {blkPath = "graphics/effectsShadows", val = (v == "HighQuality" ? true : false)},
      {blkPath = "graphics/dropletsOnScreen", val = (v == "HighQuality")},
      {blkPath = "graphics/scopeImageQuality", val = (v == "HighQuality" ? 1 : 0)},
      {blkPath = "video/vsync_tearing_tolerance_percents", val = 10},
      {blkPath = "video/freqLevel", val = (is_ps5 && v == "HighFPS" ? 3 : 1)},
      {blkPath = "graphics/shouldRenderHeroCockpit", val = true},
      {blkPath = "graphics/skiesQuality", val = (is_ps4_simple || v == "bareMinimum" ? "low" : (v == "HighFPS" ? "medium" : "high"))},
      {blkPath = "video/antiAliasingMode", val = (is_ps4_pro ? 3 : 2)}, //3 = TSR 2 = TAA
      {blkPath = "video/temporalUpsamplingRatio", val = (is_ps4_pro ? 80.0 : 100.0)},
      {blkPath = "graphics/ssssQuality", val = ((v == "HighQuality" && is_ps4_pro) || is_ps5 ? "high" : "off")},
      {blkPath = "graphics/waterQuality", val = ((is_ps5 && v == "HighQuality") ? "medium" : "low")}
    ]
  }
})

return {
  ConsolePresetBlkPath
  consoleGraphicsPreset
  consoleGraphicsPresetUpdate
  availableGraphicPresets
  optXboxGraphicsPreset
  optPSGraphicsPreset
}
