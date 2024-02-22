from "%enlSqGlob/ui/ui_library.nut" import *
let { is_xbox, is_sony } = require("%dngscripts/platform.nut")
let { optXboxGraphicsPreset, optPSGraphicsPreset } = require("%ui/hud/menus/options/quality_preset_console_options.nut")
let { optGraphicsQualityPreset }  = require("%ui/hud/menus/options/quality_preset_option.nut")
let preset = is_xbox
  ? optXboxGraphicsPreset
  : is_sony
    ? optPSGraphicsPreset
    : optGraphicsQualityPreset

return preset