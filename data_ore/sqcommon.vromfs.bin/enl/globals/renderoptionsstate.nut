let { globalWatched } = require("%dngscripts/globalState.nut")
let { get_setting_by_blk_path } = require("settings")

enum antiAliasingMode {
  OFF = 0
  FXAA = 1,
  TAA = 2,
  TSR = 3,
  DLSS = 4,
  XESS = 6,
  FSR2 = 7,
  SSAA = 8
};

let antiAliasingModeToString = {
  [antiAliasingMode.OFF]  = { optName = "option/off",  defLocString = "Off" },
  [antiAliasingMode.FXAA] = { optName = "option/fxaa", defLocString = "FXAA" },
  [antiAliasingMode.TAA]  = { optName = "option/taa",  defLocString = "Temporal Anti-aliasing" },
  [antiAliasingMode.TSR]  = { optName = "option/tsr",  defLocString = "Temporal Super Resolution" },
  [antiAliasingMode.DLSS] = { optName = "option/dlss", defLocString = "NVIDIA DLSS" },
  [antiAliasingMode.XESS] = { optName = "option/xess", defLocString = "Intel XeSS" },
  [antiAliasingMode.FSR2] = { optName = "option/fsr2", defLocString = "FSR2" },
  [antiAliasingMode.SSAA] = { optName = "options/optSSAA", defLocString = "SSAA" },
}

let isOptionAvailable = @(option) option?.isAvailable() ?? true

function addOptionVarInfo(option) {
  if (option?.optId == null || !isOptionAvailable(option))
    return option

  let gw = globalWatched(option.optId,
    @() get_setting_by_blk_path(option.blkPath) ?? option.defVal)

  option.var <- gw[option.optId]
  option.setValue <- gw[$"{option.optId}Update"]
  return option
}

return {
  antiAliasingMode
  antiAliasingModeToString
  addOptionVarInfo
  isOptionAvailable
}
