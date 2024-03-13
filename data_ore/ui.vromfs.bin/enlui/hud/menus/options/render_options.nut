from "%enlSqGlob/ui/ui_library.nut" import *

let {floor} = require("math")
let {get_setting_by_blk_path} = require("settings")
let {safeAreaAmount, safeAreaBlkPath, safeAreaList, safeAreaSetAmount,
  safeAreaCanChangeInOptions} = require("%enlSqGlob/ui/safeArea.nut")
let platform = require("%dngscripts/platform.nut")
let {DBGLEVEL} = require("dagor.system")

let {loc_opt, defCmp, getOnlineSaveData, mkSliderWithText,
  optionPercentTextSliderCtor, optionCheckBox, optionCombo, optionSlider,
  mkDisableableCtor, optionSpinner,
  optionCtor
} = require("options_lib.nut")
let { resolutionList, resolutionValue } = require("resolution_state.nut")
let { antiAliasingMode, antiAliasingModeToString, addOptionVarInfo
} = require("%enlSqGlob/renderOptionsState.nut")
let { DLSS_BLK_PATH, DLSS_OFF, dlssAvailable, dlssValue, dlssToString,
  dlssSetValue, dlssNotAllowLocId, DLSSG_BLK_PATH, dlssgAvailable, dlssgValue, dlssgSetValue, dlssgNotAllowLocId
} = require("dlss_state.nut")
let { XESS_BLK_PATH, XESS_OFF, xessAvailable, xessValue, xessToString,
  xessSetValue, xessNotAllowLocId
} = require("xess_state.nut")
let { FSR2_BLK_PATH, FSR2_OFF, fsr2Supported, fsr2Available, fsr2Value, fsr2ToString,
  fsr2SetValue
} = require("fsr2_state.nut")
let { LOW_LATENCY_BLK_PATH, LOW_LATENCY_OFF, LOW_LATENCY_NV_ON,
  LOW_LATENCY_NV_BOOST, lowLatencyAvailable, lowLatencyValue,
  lowLatencySetValue, lowLatencyToString, lowLatencySupported
} = require("low_latency_options.nut")
let { PERF_METRICS_BLK_PATH, PERF_METRICS_FPS,
  perfMetricsAvailable, perfMetricsValue, perfMetricsSetValue, perfMetricsToString
} = require("performance_metrics_options.nut")
let { is_inline_rt_supported, is_dx12, is_hdr_available, is_hdr_enabled, change_paper_white_nits,
  change_gamma, is_gui_driver_select_enabled, is_rendinst_tessellation_supported,
  get_default_static_resolution_scale
} = require("videomode")
let { availableMonitors, monitorValue, get_friendly_monitor_name } = require("monitor_state.nut")
let { fpsList, UNLIMITED_FPS_LIMIT } = require("fps_list.nut")
let {isBareMinimum} = require("quality_preset_common.nut")
let msgbox = require("%ui/components/msgbox.nut")
let { globalWatched } = require("%dngscripts/globalState.nut")

let resolutionToString = @(v) typeof v == "string" ? v : $"{v[0]} x {v[1]}"

let gammaBlkPath = "graphics/gamma_correction"
let gammaCorrectionSave = getOnlineSaveData(gammaBlkPath,
  @() get_setting_by_blk_path(gammaBlkPath) ?? 1.0,
  @(p) clamp(p, 0.5, 1.5)
)

let bareOffText = Computed(@() isBareMinimum.value ? loc("option/off") : null)
let bareLowText = Computed(@() isBareMinimum.value ? loc("option/low") : null)
let bareMinimumText = Computed(@() isBareMinimum.value ? loc("option/minimum") : null)

let consoleGfxSettingsBlk = get_setting_by_blk_path("graphics/consoleGfxSettings")
let consoleSettingsEnabled = (consoleGfxSettingsBlk != null) && (consoleGfxSettingsBlk == true)

let isOptAvailable = @() platform.is_pc || (DBGLEVEL > 0 && (platform.is_sony || platform.is_xbox) && consoleSettingsEnabled)
let isPcDx12 = @() platform.is_pc && is_dx12()
let isDriverOptAvailable = @() platform.is_win64 && is_gui_driver_select_enabled()
let isDevBuild = @() platform.is_pc && DBGLEVEL != 0

const defDriver = "auto"
let originalDriverValue = get_setting_by_blk_path("video/driver") ?? defDriver
let driverValue = Watched(originalDriverValue)

let optSafeArea = optionCtor({
  name = loc("options/safeArea")
  widgetCtor = optionSpinner
  tab = "Graphics"
  isAvailable = safeAreaCanChangeInOptions
  blkPath = safeAreaBlkPath
  var = safeAreaAmount
  setValue = safeAreaSetAmount
  defVal = 1.0
  available = safeAreaList
  valToString = @(s) $"{s*100}%"
  isEqual = defCmp
  restart = false
  reload = true
})

let optDriver = optionCtor({
  name = loc("options/driver")
  widgetCtor = optionSpinner
  tab = "Graphics"
  blkPath = "video/driver"
  isAvailable = isDriverOptAvailable
  defVal = "auto"
  var = driverValue
  available = DBGLEVEL > 0 ? ["auto", "dx11", "dx12", "vulkan"] : ["auto", "dx11", "dx12"]
  restart = true
  valToString = loc_opt
})

const defVideoMode = "fullscreen"
let originalValVideoMode = get_setting_by_blk_path("video/mode") ?? defVideoMode
let videoModeVar = Watched(originalValVideoMode)

let isDx12Selected = Computed(@() (isDriverOptAvailable() ? driverValue.value == "dx12" : isPcDx12()))

let optVideoMode = optionCtor({
  name = loc("options/mode")
  widgetCtor = optionSpinner
  tab = "Graphics"
  blkPath = "video/mode"
  isAvailable = isOptAvailable
  defVal = defVideoMode
  available = platform.is_windows ? ["windowed", "fullscreenwindowed", "fullscreen"] : ["windowed", "fullscreen"]
  originalVal = originalValVideoMode
  var = videoModeVar
  restart = !platform.is_windows
  valToString = @(s) loc($"options/mode_{s}")
  isEqual = defCmp
})

let optMonitorSelection = optionCtor({
  name = loc("options/monitor", "Monitor")
  widgetCtor = mkDisableableCtor(
    Computed(@() videoModeVar.value == "windowed" ? loc("options/auto") : null),
    optionSpinner)
  tab = "Graphics"
  blkPath = "video/monitor"
  isAvailable = isOptAvailable
  defVal = availableMonitors.current
  available = availableMonitors.list
  originalVal = availableMonitors.current
  var = monitorValue
  valToString = @(v) (v == "auto") ? loc("options/auto") : get_friendly_monitor_name(v)
  isEqual = defCmp
})

videoModeVar.subscribe(function(val){
  if (["fullscreenwindowed", "fullscreen"].indexof(val)!=null)
    resolutionValue("auto")
  else
    monitorValue("auto")
})

let normalize_res_string = @(res) typeof res == "string" ? res.replace(" ", "") : res

let optResolution = optionCtor({
  name = loc("options/resolution")
  widgetCtor = optionCombo
  tab = "Graphics"
  originalVal = resolutionValue
  blkPath = "video/resolution"
  isAvailable = isOptAvailable
  var = resolutionValue
  defVal = resolutionValue
  available = resolutionList
  restart = !(platform.is_windows || platform.is_xboxone)
  valToString = @(v) (v == "auto") ? loc("options/auto") : "{0} x {1}".subst(v[0], v[1])
  isEqual = function(a, b) {
    if (typeof a == "string" || typeof b == "string")
      return normalize_res_string(a) == normalize_res_string(b)
    return a[0]==b[0] && a[1]==b[1]
  }
  convertForBlk = resolutionToString
})

let optHdr = optionCtor({
  name = loc("options/hdr", "HDR")
  tab = "Graphics"
  blkPath = "video/enableHdr"
  isAvailable = @() (isPcDx12() && DBGLEVEL > 0) || platform.is_sony
  restart = platform.is_sony
  widgetCtor = mkDisableableCtor(
    Computed(@() is_hdr_available(monitorValue.value) ? null : "{0} ({1})".subst(loc("option/off"), loc("option/monitor_does_not_support", "Monitor doesn't support"))),
    optionCheckBox)
  defVal = false
})

const MIN_PAPER_WHITE_NITS = 100
const MAX_PAPER_WHITE_NITS = 1000
const PAPER_WHITE_NITS_STEP = 10
const DEF_PAPER_WHITE_NITS = 200

let paperWhiteBlkPath = "video/paperWhiteNits"
let paperWhiteOptData = getOnlineSaveData(paperWhiteBlkPath,
  @() get_setting_by_blk_path(paperWhiteBlkPath) ?? DEF_PAPER_WHITE_NITS,
  @(p) clamp(p.tointeger(), MIN_PAPER_WHITE_NITS, MAX_PAPER_WHITE_NITS))

let optPaperWhiteNits = optionCtor({
  name = loc("options/paperWhiteNits", "Paper White Nits")
  tab = "Graphics"
  isAvailable = is_hdr_enabled
  widgetCtor = mkSliderWithText
  var = paperWhiteOptData.watch
  setValue = function(val) {
    paperWhiteOptData.setValue(val)
    change_paper_white_nits(val)
  }
  blkPath = paperWhiteBlkPath
  defVal = DEF_PAPER_WHITE_NITS
  min = MIN_PAPER_WHITE_NITS
  max = MAX_PAPER_WHITE_NITS
  step = PAPER_WHITE_NITS_STEP
  pageScroll = PAPER_WHITE_NITS_STEP
})

let optVsync = optionCtor({
  name = loc("options/vsync")
  tab = "Graphics"
  isAvailable = isOptAvailable
  widgetCtor = mkDisableableCtor(
    Computed(@() lowLatencyValue.value != LOW_LATENCY_NV_ON && lowLatencyValue.value != LOW_LATENCY_NV_BOOST ? null
                   : "{0} ({1})".subst(loc("option/off"), loc("option/off_by_reflex"))),
    optionCheckBox)
  restart = !platform.is_windows
  blkPath = "video/vsync"
  defVal = false
})

let optFpsLimit = optionCtor({
  name = loc("options/fpsLimit")
  tab = "Graphics"
  isAvailable = isOptAvailable
  widgetCtor = optionCombo
  blkPath = "video/fpsLimit"
  defVal = UNLIMITED_FPS_LIMIT
  available = fpsList
  restart = false
  valToString = @(v) (v == UNLIMITED_FPS_LIMIT) ? loc("option/off") : loc("options/fpsLimit/hertz", { value = v })
  convertForBlk = @(v) (v == UNLIMITED_FPS_LIMIT) ? 0 : floor(v + 0.5).tointeger()
  convertFromBlk = @(v) (v == 0) ? UNLIMITED_FPS_LIMIT : v
})

let optLatency = optionCtor({
  name = loc("option/latency", "NVIDIA Reflex Low Latency")
  tab = "Graphics"
  widgetCtor = mkDisableableCtor(
    Computed(@() isBareMinimum.value ?
                 loc("option/off") :
                 (lowLatencySupported.value ?
                   (dlssgValue.value ?
                     "{0} ({1})".subst(loc("option/nv_boost"), loc("option/forced_by_frame_generation")) :
                     null) :
                   "{0} ({1})".subst(loc("option/off"), loc("option/unavailable")))),
    optionSpinner)
  isAvailable = isOptAvailable
  blkPath = LOW_LATENCY_BLK_PATH
  defVal = LOW_LATENCY_OFF
  var = lowLatencyValue
  setValue = lowLatencySetValue
  available = lowLatencyAvailable
  valToString = @(v) loc(lowLatencyToString[v])
})

let optPerformanceMetrics = optionCtor({
  name = loc("options/perfMetrics", "Performance Metrics")
  widgetCtor = optionSpinner
  tab = "Graphics"
  isAvailable = isOptAvailable
  blkPath = PERF_METRICS_BLK_PATH
  defVal = PERF_METRICS_FPS
  var = perfMetricsValue
  setValue = perfMetricsSetValue
  available = perfMetricsAvailable
  valToString = @(v) loc(perfMetricsToString[v])
})


let optShadowsQuality = optionCtor(addOptionVarInfo({
  optId = "shadowsQuality"
  name = loc("options/shadowsQuality", "Shadow Quality")
  blkPath = "graphics/shadowsQuality"
  widgetCtor = mkDisableableCtor(bareMinimumText, optionSpinner)
  defVal = "low"
  tab = "Graphics"
  isAvailable = isOptAvailable
  available = DBGLEVEL > 0 ? [ "minimum",  "low", "medium", "high", "ultra" ] : [  "minimum", "low", "medium", "high" ]
  restart = false
  valToString = loc_opt
  isEqual = defCmp
}))


let optEffectsShadows = optionCtor(addOptionVarInfo({
  optId = "effectsShadows"
  name = loc("options/effectsShadows", "Shadows from Effects")
  blkPath = "graphics/effectsShadows"
  widgetCtor = mkDisableableCtor(bareOffText, optionCheckBox)
  defVal = true
  tab = "Graphics"
  isAvailable = isOptAvailable
  restart = false
}))


//-----------< GI Quality >-----------------------
const GI_QUALITY_OPT_DEF_VALUE = "low"
let optGiQuality = optionCtor(addOptionVarInfo({
  optId = "giQuality"
  name = loc("options/giQuality", "Global Illumination Quality")
  blkPath = "graphics/giQuality"
  widgetCtor = mkDisableableCtor(bareMinimumText, optionSpinner)
  defVal = GI_QUALITY_OPT_DEF_VALUE
  tab = "Graphics"
  isAvailable = isOptAvailable
  available = [ "minimum", "low", "medium", "high" ]
  valToString = loc_opt
  originalVal = isBareMinimum.value ? "minimum" : GI_QUALITY_OPT_DEF_VALUE
}))
//-----------</ GI Quality >-----------------------

//-----------< RTGI >------------------------------
const RTGI_OPT_DEF_VALUE = false
let giQualityVar = optGiQuality.var
let rtGIDisabled = Computed(@() giQualityVar.value == "minimum" || giQualityVar.value == "low")

let rtgiOptData = addOptionVarInfo({
  optId = "rtgiEnabled"
  name = loc("options/RTGI", "Ray Tracing Enhanced Global Illumination")
  blkPath = "graphics/gi/inlineRaytracing"
  tab = "Graphics"
  isAvailable = @() isPcDx12() && isDevBuild()
  widgetCtor = mkDisableableCtor(Computed(@() !is_inline_rt_supported()
    ? loc("options/inlne_rt_not_supported", "Inline Raytracing not supported")
    : rtGIDisabled.value
    ? loc("options/disabled_by_gi_quality", "Disabled by 'Global Illumination Quality'")
    : null),
    optionCheckBox)
  defVal = RTGI_OPT_DEF_VALUE
})

let rtgiVar = rtgiOptData?.var ?? Watched(rtgiOptData.defVal)
let rtGIValue = Computed(@() ((is_inline_rt_supported() && !rtGIDisabled.value)
  ? rtgiVar.value : RTGI_OPT_DEF_VALUE))

rtgiOptData.var <- rtGIValue

let optRTGi = optionCtor(rtgiOptData)
//-----------</ RTGI >-----------------------


let optSkiesQuality = optionCtor(addOptionVarInfo({
  optId = "skiesQuality"
  name = loc("options/skiesQuality", "Atmospheric Scattering Quality")
  blkPath = "graphics/skiesQuality"
  widgetCtor = mkDisableableCtor(bareLowText, optionSpinner)
  defVal = "low"
  tab = "Graphics"
  isAvailable = isOptAvailable
  available = [ "low", "medium", "high" ]
  restart = false
  valToString = loc_opt
}))


let optSsaoQuality = optionCtor(addOptionVarInfo({
  optId = "aoQuality"
  name = loc("options/ssaoQuality", "Ambient Occlusion Quality")
  blkPath = "graphics/aoQuality"
  widgetCtor = mkDisableableCtor(bareOffText, optionSpinner)
  defVal = "medium"
  tab = "Graphics"
  isAvailable = isOptAvailable
  available = [ "low", "medium", "high" ]
  valToString = loc_opt
  restart = false
  isEqual = defCmp
}))


let optObjectsDistanceMul = optionCtor(addOptionVarInfo({
  optId = "objectsDistanceMul"
  name = loc("options/objectsDistanceMul")
  blkPath = "graphics/objectsDistanceMul"
  widgetCtor = optionSlider
  defVal = 1.0
  tab = "Graphics"
  isAvailable = isDevBuild
  min = 0.0 max = 1.5 unit = 0.05 pageScroll = 0.05
  restart = false
  getMoreBlkSettings = function(val){
    return [
      {blkPath = "graphics/rendinstDistMul", val = val},
      {blkPath = "graphics/riExtraMulScale", val = val}
    ]
  }
}))


let optCloudsQuality = optionCtor(addOptionVarInfo({
  optId = "cloudsQuality"
  name = loc("options/cloudsQuality", "Clouds Quality")
  blkPath = "graphics/cloudsQuality"
  widgetCtor = mkDisableableCtor(bareLowText, optionSpinner)
  defVal = "default"
  tab = "Graphics"
  isAvailable = isOptAvailable
  available = [ "default", "highres", "volumetric" ]
  restart = false
  valToString = loc_opt
  isEqual = defCmp
}))


let optVolumeFogQuality = optionCtor(addOptionVarInfo({
  optId = "volumeFogQuality"
  name = loc("options/volumeFogQuality", "Volumetric Fog Quality")
  blkPath = "graphics/volumeFogQuality"
  widgetCtor = mkDisableableCtor(bareLowText, optionSpinner)
  defVal = "close"
  tab = "Graphics"
  isAvailable = isOptAvailable
  available = [ "close", "far" ]
  restart = false
  valToString = loc_opt
  isEqual = defCmp
}))


let optWaterQuality = optionCtor(addOptionVarInfo({
  optId = "waterQuality"
  name = loc("options/waterQuality", "Water Quality")
  blkPath = "graphics/waterQuality"
  widgetCtor = mkDisableableCtor(bareLowText, optionSpinner)
  defVal = "low"
  tab = "Graphics"
  isAvailable = isOptAvailable
  available = [ "low", "medium", "high" ]
  restart = false
  valToString = loc_opt
  isEqual = defCmp
}))


let optGroundDisplacementQuality = optionCtor(addOptionVarInfo({
  optId = "groundDisplacementQuality"
  name = loc("options/groundDisplacementQuality", "Terrain Tessellation Quality")
  blkPath = "graphics/groundDisplacementQuality"
  widgetCtor = mkDisableableCtor(bareLowText, optionSpinner)
  defVal = 1
  tab = "Graphics"
  isAvailable = isOptAvailable
  available = [ 0, 1, 2 ]
  restart = false
  valToString = loc_opt
  isEqual = defCmp
}))


let optGroundDeformations = optionCtor(addOptionVarInfo({
  optId = "groundDeformations"
  name = loc("options/groundDeformations", "Dynamic Terrain Deformations")
  blkPath = "graphics/groundDeformations"
  widgetCtor = mkDisableableCtor(bareOffText, optionSpinner)
  defVal = "low"
  tab = "Graphics"
  isAvailable = isOptAvailable
  available = [ "off", "low", "medium", "high" ]
  restart = false
  valToString = loc_opt
  isEqual = defCmp
}))


let optImpostor = optionCtor(addOptionVarInfo({
  optId = "impostor"
  name = loc("options/impostor", "Impostor quality")
  blkPath = "graphics/impostor"
  widgetCtor = optionSpinner
  defVal = 0
  isAvailable = isDevBuild
  tab = "Graphics"
  available = [ 0, 1, 2 ]
  restart = false
  valToString = loc_opt
  isEqual = defCmp
}))


//---------------< Anti-Aliasing Mode Chosen >-----------------
let aaModeOptData = addOptionVarInfo({
  optId = "antiAliasingModeChosen"
  name = loc("options/antiAliasingMode", "Anti-aliasing Mode")
  blkPath = "video/antiAliasingMode"
  widgetCtor = mkDisableableCtor(Computed(@() isBareMinimum.value ? loc("option/fxaa", "FXAA") : null), optionSpinner)
  defVal = antiAliasingMode.TAA
  tab = "Graphics"
  isAvailable = @() platform.is_pc
  available = Computed(@() [isBareMinimum.value ? antiAliasingMode.FXAA : null,
                antiAliasingMode.TAA,
                antiAliasingMode.TSR,
                dlssNotAllowLocId.value == null ? antiAliasingMode.DLSS : null,
                (xessNotAllowLocId.value == null && isDx12Selected.value) ? antiAliasingMode.XESS : null,
                (fsr2Supported.value && isDx12Selected.value) ? antiAliasingMode.FSR2 : null,
                antiAliasingMode.SSAA ].filter(@(q) q != null))
  valToString = @(v) loc(antiAliasingModeToString[v].optName, antiAliasingModeToString[v].defLocString)
})

let aaModeVar = aaModeOptData?.var ?? Watched(aaModeOptData.defVal)

let antiAliasingModeValue = Computed(@() isBareMinimum.value
  ? antiAliasingMode.FXAA
  : max(aaModeVar.value, antiAliasingMode.TAA))

aaModeOptData.var <- antiAliasingModeValue

let optAntiAliasingMode = optionCtor(aaModeOptData)
//--------------</ Anti-Aliasing Mode Chosen >---------------------


let optTaaQuality = optionCtor(addOptionVarInfo({
  optId = "taaQuality"
  name = loc("options/taaQuality", "Temporal Antialiasing Quality")
  blkPath = "graphics/taaQuality"
  widgetCtor = mkDisableableCtor(bareOffText, optionSpinner)
  defVal = 1
  isAvailable = isOptAvailable
  isAvailableWatched = Computed(@() isOptAvailable() && antiAliasingModeValue.value == antiAliasingMode.TAA)
  tab = "Graphics"
  available = [ 0, 1, 2]
  restart = false
  valToString = loc_opt
  isEqual = defCmp
}))


let optDlss = optionCtor({
  name = loc("options/dlssQuality", "NVIDIA DLSS Quality")
  blkPath = DLSS_BLK_PATH
  widgetCtor = mkDisableableCtor(
    Computed(@() dlssNotAllowLocId.value == null ? null : "{0} ({1})".subst(loc("option/off"), loc(dlssNotAllowLocId.value))),
    optionSpinner)
  defVal = DLSS_OFF
  tab = "Graphics"
  isAvailable = isOptAvailable
  isAvailableWatched = Computed(@() isOptAvailable() && (antiAliasingModeValue.value == antiAliasingMode.DLSS))
  var = dlssValue
  setValue = dlssSetValue
  available = dlssAvailable
  valToString = @(v) loc(dlssToString[v])
})


let optDlssFrameGeneration = optionCtor({
  name = loc("options/dlssFrameGeneration", "Frame Generation")
  blkPath = DLSSG_BLK_PATH
  widgetCtor = mkDisableableCtor(
    Computed(@() dlssgNotAllowLocId.value == null ? null : "{0} ({1})".subst(loc("option/off"), loc(dlssgNotAllowLocId.value))),
    optionCheckBox)
  defVal = false
  tab = "Graphics"
  isAvailable = @() isOptAvailable() && isPcDx12()
  isAvailableWatched = Computed(@() isOptAvailable() && isPcDx12() && antiAliasingModeValue.value == antiAliasingMode.DLSS && DBGLEVEL > 0)
  var = dlssgValue
  setValue = dlssgSetValue
  available = dlssgAvailable
})


let optXess = optionCtor({
  name = loc("options/xessQuality", "Intel XeSS Quality")
  blkPath = XESS_BLK_PATH
  widgetCtor = mkDisableableCtor(
    Computed(@() xessNotAllowLocId.value == null ? null : "{0} ({1})".subst(loc("option/off"), loc(xessNotAllowLocId.value))),
    optionSpinner)
    isAvailable = isOptAvailable
  defVal = XESS_OFF
  tab = "Graphics"
  isAvailableWatched = Computed(@() isOptAvailable() && antiAliasingModeValue.value == antiAliasingMode.XESS && isDx12Selected.value)
  var = xessValue
  setValue = xessSetValue
  available = xessAvailable
  valToString = @(v) loc(xessToString[v])
})


let optFsr2 = optionCtor({
  name = loc("options/fsr2Quality", "FSR2 Quality")
  blkPath = FSR2_BLK_PATH
  widgetCtor = mkDisableableCtor(
    Computed(@() fsr2Supported.value ? null : "{0} ({1})".subst(loc("option/off"), loc("fsr2/notSupported"))),
    optionSpinner)
  defVal = FSR2_OFF
  tab = "Graphics"
  isAvailable = isOptAvailable
  isAvailableWatched = Computed(@() isOptAvailable() && antiAliasingModeValue.value == antiAliasingMode.FSR2)
  var = fsr2Value
  setValue = fsr2SetValue
  available = fsr2Available
  valToString = @(v) loc(fsr2ToString[v])
})


let optSharpening = optionCtor(addOptionVarInfo({
  optId = "sharpening"
  name = loc("options/sharpening", "Sharpening")
  blkPath = "graphics/sharpening"
  widgetCtor = mkDisableableCtor(bareOffText, optionPercentTextSliderCtor)
  defVal = 0.0
  isAvailable = isOptAvailable
  min = 0.0
  max = 100.0
  unit = 5.0/100.0
  pageScroll = 5.0
  restart = false
  tab = "Graphics"
  valToString = loc_opt
  isEqual = defCmp
}))

//----------------< Dynamic Resolution >---------------------
const DYNAMIC_RESOLUTION_BLK_PATH = "video/dynamicResolution/targetFPS"
const DYNAMIC_RESOLUTION_OFF = 0
let dynamicResolutionFPS = Watched(get_setting_by_blk_path(DYNAMIC_RESOLUTION_BLK_PATH) ?? DYNAMIC_RESOLUTION_OFF)

// Needs fixing up
// let optDynamicResolution = optionCtor({
//   name = loc("options/dynamic_resolution", "Dynamic Resolution")
//   blkPath = DYNAMIC_RESOLUTION_BLK_PATH
//   widgetCtor = optionCombo
//   defVal = DYNAMIC_RESOLUTION_OFF
//   tab = "Graphics"
//   isAvailable = @() isOptAvailable() && isPcDx12()
//   isAvailableWatched = Computed(@() isOptAvailable() && isPcDx12() && antiAliasingModeValue.value == antiAliasingMode.TSR)
//   var = dynamicResolutionFPS
//   setValue = @(v) dynamicResolutionFPS(v)
//   available = [DYNAMIC_RESOLUTION_OFF].extend(fpsList.value.filter(@(v) v != UNLIMITED_FPS_LIMIT))
//   valToString = @(v) v == DYNAMIC_RESOLUTION_OFF ? loc("option/off") : "{0} {1}".subst(v, loc("options/fps", "FPS"))
//   isEqual = defCmp
//   restart = false
// })
//----------------</ Dynamic Resolution >---------------------


let optTemporalUpsamplingRatio = optionCtor(addOptionVarInfo({
  optId = "temporalUpsamplingRatio"
  name = loc("options/temporal_upsampling_ratio", "Temporal Resolution Scale")
  blkPath = "video/temporalUpsamplingRatio"
  widgetCtor = mkDisableableCtor(
    Computed(@() dynamicResolutionFPS.value != DYNAMIC_RESOLUTION_OFF ? loc("options/adaptive", "Adaptive") : null),
    optionPercentTextSliderCtor)
  defVal = 100.0
  tab = "Graphics"
  isAvailable = isOptAvailable
  isAvailableWatched = Computed(@() isOptAvailable() && antiAliasingModeValue.value == antiAliasingMode.TSR)
  min = 25.0
  max = 100.0
  unit = 5.0/75.0
  pageScroll = 5.0
  restart = false
}))


let optStaticResolutionScale = optionCtor(addOptionVarInfo({
  optId = "staticResolutionScale"
  name = loc("options/static_resolution_scale", "Static Resolution Scale")
  blkPath = "video/staticResolutionScale"
  widgetCtor = optionPercentTextSliderCtor
  defVal = get_default_static_resolution_scale()
  tab = "Graphics"
  isAvailable = isOptAvailable
  isAvailableWatched = Computed(@() isOptAvailable() && isBareMinimum.value)
  min = 50.0
  max = 100.0
  unit = 5.0/50.0
  pageScroll = 5.0
  restart = false
}))


//------------------< Static Resolution Scale >---------------------
let staticResolutionScaleWatched = optStaticResolutionScale.var

let optStaticUplsamplingQuality = optionCtor(addOptionVarInfo({
  optId = "staticUpsampleQuality"
  name = loc("options/static_upsampling_quality", "Static Upsampling Quality")
  blkPath = "graphics/staticUpsampleQuality"
  widgetCtor = optionSpinner
  defVal = "catmullrom"
  tab = "Graphics"
  isAvailable = isOptAvailable
  isAvailableWatched = Computed(@() isOptAvailable() && isBareMinimum.value && staticResolutionScaleWatched.value < 100.0)
  available = ["bilinear", "catmullrom", "sharpen"]
  restart = false
  valToString = loc_opt
}))
//------------------</ Static Resolution Scale >---------------------


let optGammaCorrection = optionCtor({
  name = loc("options/gamma_correction", "Gamma correction")
  blkPath = "graphics/gamma_correction"
  widgetCtor = optionSlider
  defVal = 1.0
  tab = "Graphics"
  isAvailable = @() !is_hdr_enabled()
  var = gammaCorrectionSave.watch
  setValue = function(v) {
      gammaCorrectionSave.setValue(v)
      change_gamma(v)
    }
  min = 0.5 max = 1.5 unit = 0.05 pageScroll = 0.05
  restart = false
})


let optTexQuality = optionCtor(addOptionVarInfo({
  optId = "texQuality"
  name = loc("options/texQuality")
  blkPath = "graphics/texquality"
  widgetCtor = mkDisableableCtor(bareLowText, optionSpinner)
  defVal = "high"
  isAvailable = isOptAvailable
  tab = "Graphics"
  available = ["low", "medium", "high"]
  restart = true
  valToString = loc_opt
  isEqual = defCmp
  tooltipText = loc("guiHints/texQuality")
}))


let optAnisotropy = optionCtor(addOptionVarInfo({
  optId = "anisotropy"
  name = loc("options/anisotropy")
  blkPath = "graphics/anisotropy"
  widgetCtor = mkDisableableCtor(bareOffText, optionSpinner)
  defVal = 4
  tab = "Graphics"
  isAvailable = isOptAvailable
  available = [1, 2, 4, 8, 16]
  restart = false
  valToString = @(v) (v==1) ? loc("option/off") : $"{v}X"
  isEqual = defCmp
}))


let optOnlyonlyHighResFx = optionCtor(addOptionVarInfo({
  optId = "onlyHighResFx"
  name = loc("options/onlyHighResFx")
  blkPath = "graphics/fxTarget"
  widgetCtor = mkDisableableCtor(bareOffText, optionSpinner)
  defVal = "lowres"
  tab = "Graphics"
  isAvailable = isOptAvailable
  available = ["lowres", "medres", "highres"]
  restart = false
  valToString = loc_opt
}))


let optDropletsOnScreen = optionCtor(addOptionVarInfo({
  optId = "dropletsOnScreen"
  name = loc("options/dropletsOnScreen")
  blkPath = "graphics/dropletsOnScreen"
  widgetCtor = mkDisableableCtor(bareOffText, optionCheckBox)
  defVal = true
  tab = "Graphics"
  isAvailable = @() platform.is_pc
  restart = false
}))


let optFXAAQuality = optionCtor(addOptionVarInfo({
  optId = "fxaaQuality"
  name = loc("options/FXAAQuality")
  blkPath = "graphics/fxaaQuality"
  widgetCtor = optionSpinner
  defVal = "medium"
  tab = "Graphics"
  isAvailableWatched = Computed(@() antiAliasingModeValue.value == antiAliasingMode.FXAA)
  available = ["low", "medium", "high"]
  restart = false
  valToString = loc_opt
}))


let optSSRQuality = optionCtor(addOptionVarInfo({
  optId = "ssrQuality"
  name = loc("options/SSRQuality")
  blkPath = "graphics/ssrQuality"
  widgetCtor = mkDisableableCtor(bareLowText, optionSpinner)
  defVal = "low"
  tab = "Graphics"
  isAvailable = isOptAvailable
  available = ["low", "medium", "high"]
  restart = false
  valToString = loc_opt
}))


let optScopeImageQuality = optionCtor(addOptionVarInfo({
  optId = "scopeImageQuality"
  name = loc("options/scopeImageQuality", "Scope Image Quality")
  blkPath = "graphics/scopeImageQuality"
  widgetCtor = mkDisableableCtor(bareLowText, optionSpinner)
  defVal = 0
  tab = "Graphics"
  isAvailable = isOptAvailable
  available = [0, 1, 2, 3]
  valToString = loc_opt
  restart = false
  isEqual = defCmp
}))


let optUncompressedScreenshots = optionCtor(addOptionVarInfo({
  optId = "uncompressedScreenshots"
  name = loc("options/uncompressedScreenshots")
  blkPath = "screenshots/uncompressedScreenshots"
  widgetCtor = optionCheckBox
  defVal = false
  tab = "Graphics"
  isAvailable = isOptAvailable
  restart = false
}))


let optFSR = optionCtor(addOptionVarInfo({
  optId = "fsr"
  name = loc("options/optFSR", "AMD FidelityFX Super Resolution 1.0")
  blkPath = "video/fsr"
  widgetCtor = mkDisableableCtor(bareOffText, optionSpinner)
  defVal = "off"
  tab = "Graphics"
  isAvailableWatched = Computed(@() isOptAvailable() && antiAliasingModeValue.value == antiAliasingMode.TAA)
  available = ["off", "ultraquality", "quality", "balanced", "performance"]
  restart = false
  valToString = loc_opt
}))


let optFFTWaterQuality = optionCtor(addOptionVarInfo({
  optId = "fftWaterQuality"
  name = loc("options/fft_water_quality", "Water Ripples Quality")
  blkPath = "graphics/fftWaterQuality"
  widgetCtor = mkDisableableCtor(bareLowText, optionSpinner)
  defVal = "high"
  tab = "Graphics"
  isAvailable = isOptAvailable
  available = ["low", "medium", "high", "ultra"]
  restart = false
  valToString = loc_opt
}))


let optHQProbeReflections = optionCtor(addOptionVarInfo({
  optId = "hqProbeReflections"
  name = loc("options/HQProbeReflections")
  blkPath = "graphics/HQProbeReflections"
  widgetCtor = mkDisableableCtor(bareOffText, optionCheckBox)
  defVal = true
  tab = "Graphics"
  isAvailable = @() platform.is_pc
  restart = false
}))


let optHQVolumetricClouds = optionCtor(addOptionVarInfo({
  optId = "hqVolumetricClouds"
  name = loc("options/HQVolumetricClouds")
  blkPath = "graphics/HQVolumetricClouds"
  widgetCtor = mkDisableableCtor(bareOffText, optionCheckBox)
  defVal = false
  tab = "Graphics"
  isAvailable = @() platform.is_pc
  restart = false
}))


let optHQVolfog = optionCtor(addOptionVarInfo({
  name = loc("options/HQVolfog")
  blkPath = "graphics/HQVolfog"
  widgetCtor = mkDisableableCtor(bareOffText, optionCheckBox)
  defVal = false
  tab = "Graphics"
  isAvailable = @() platform.is_pc
  restart = false
}))


let optSSSS = optionCtor(addOptionVarInfo({
  optId = "ssss"
  name = loc("options/ssss")
  blkPath = "graphics/ssssQuality"
  widgetCtor = mkDisableableCtor(bareOffText, optionSpinner)
  defVal = "low"
  tab = "Graphics"
  isAvailable = isOptAvailable
  available = ["off", "low", "high"]
  restart = false
  valToString = loc_opt
}))


let optRendinstTesselation = optionCtor(addOptionVarInfo({
  optId = "rendinstTesselation"
  name = loc("options/rendinstTesselation", "Tree tesselation")
  blkPath = "graphics/rendinstTesselation"
  widgetCtor = mkDisableableCtor(bareOffText, optionCheckBox)
  defVal = false
  tab = "Graphics"
  isAvailable = @() (isOptAvailable() && is_rendinst_tessellation_supported() && isDevBuild()) // TODO move it to advanced options when assets are set up
  restart = false
}))

let { wasSSAAWarningShown, wasSSAAWarningShownUpdate
} = globalWatched("wasSSAAWarningShown", @() false)

antiAliasingModeValue.subscribe(function(mode) {
  if (!wasSSAAWarningShown.value && mode == antiAliasingMode.SSAA) {
    wasSSAAWarningShownUpdate(true)
    msgbox.show({text=loc("settings/ssaa_warning")})
  }
})

return {
  resolutionToString
  optDriver
  optResolution
  optSafeArea
  optVideoMode
  optMonitorSelection
  optHdr
  optPaperWhiteNits
  optPerformanceMetrics
  optLatency
  optVsync
  optFpsLimit
  optShadowsQuality
  optEffectsShadows
  optGiQuality
  optRTGi
  optSkiesQuality
  optSsaoQuality
  optObjectsDistanceMul
  optCloudsQuality
  optVolumeFogQuality
  optWaterQuality
  optGroundDisplacementQuality
  optGroundDeformations
  optImpostor
  optTaaQuality
  optGammaCorrection
  optTexQuality
  optAnisotropy
  optOnlyonlyHighResFx
  optDropletsOnScreen
  optSSRQuality
  optScopeImageQuality
  optUncompressedScreenshots
  optDlss
  optXess
  optFsr2
  optSharpening
  optTemporalUpsamplingRatio
  optStaticResolutionScale
  optStaticUplsamplingQuality
  optFSR
  optFFTWaterQuality
  optHQProbeReflections
  optHQVolumetricClouds
  optHQVolfog
  optRendinstTesselation
  optSSSS
  optAntiAliasingMode

  renderOptions = [
    optSafeArea,

    // Display
    {name = loc("group/display", "Display") isSeparator=true tab="Graphics"},
    optDriver,
    optResolution,
    optVideoMode,
    optMonitorSelection,
    optHdr,
    optPaperWhiteNits,
    optGammaCorrection,
    optPerformanceMetrics,
    optLatency,
    optVsync,
    optFpsLimit,

    //Antialiasing
    {name = loc("group/antialiasing", "Antialiasing") isSeparator=true tab="Graphics"},
    optAntiAliasingMode,
    optTaaQuality,
    // optDynamicResolution,
    optTemporalUpsamplingRatio,
    optStaticResolutionScale,
    optStaticUplsamplingQuality,
    optFXAAQuality,
    optFSR,
    optDlss,
    optXess,
    optFsr2,
    optSharpening,
    optDlssFrameGeneration,

    // Shadows & lighting
    {name = loc("group/shadows_n_lighting", "Shadows & Lighting") isSeparator=true tab="Graphics"},
    optShadowsQuality,
    optEffectsShadows,

    // Lighting
    optGiQuality,
    optSkiesQuality,
    optSsaoQuality,
    optSSRQuality,
    optHQProbeReflections,
    optSSSS,

    {name = loc("group/details_n_textures", "Details & Textures") isSeparator=true tab="Graphics"},
    // Texture
    optTexQuality,
    optAnisotropy,
    // Details
    optCloudsQuality,
    optVolumeFogQuality,
    optWaterQuality,
    optFFTWaterQuality,
    optGroundDisplacementQuality,
    optGroundDeformations,
    optOnlyonlyHighResFx,
    optDropletsOnScreen,
    optScopeImageQuality,

    // Other
    {name = loc("group/other", "Other")
     isSeparator=true
     tab="Graphics"
     isAvailable = optUncompressedScreenshots.isAvailable },  // to hide last block's header if it's empty
    optUncompressedScreenshots,

    // Dev builds only
    {name = "Dev options" isSeparator=true tab="Graphics" isAvailable = isDevBuild },
    optImpostor,
    optObjectsDistanceMul,
    optRendinstTesselation,

    // Advanced
    { name = loc("group/advanced", "Advanced options"), isSeparator = true, tab = "Graphics" },
    optRTGi,
    optHQVolumetricClouds,
    optHQVolfog,
  ]
}
