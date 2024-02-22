from "%enlSqGlob/ui/ui_library.nut" import *
let { addModalWindow, removeModalWindow } = require("%ui/components/modalWindows.nut")
let { benchmarkResult, launchBenchmark, closeBenchmarksList, isBenchmarksListOpened
} = require("%enlist/benchmark/benchmarkState.nut")
let { Bordered } = require("%ui/components/txtButton.nut")
let { fontHeading2, fontHeading1, fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let { isInBattleState } = require("%enlSqGlob/inBattleState.nut")
let { millisecondsToSecondsInt } = require("%sqstd/time.nut")
let { titleTxtColor, defTxtColor, sidePadding, attentionTxtColor, bigPadding, hoverSlotBgColor,
  fullTransparentBgColor, darkTxtColor, darkPanelBgColor, contentGap
} = require("%enlSqGlob/ui/designConst.nut")
let { format } = require("string")
let benchmarkScenes = require("%enlist/configs/benchmarkScenes.nut")
let JB = require("%ui/control/gui_buttons.nut")

const WND_RESULT_UID = "benchmark_result_window"
const WND_SCENES_UID = "benchmark_scenes_window"

function roundFPS(val) {
  return format("%.1f", val)
}

let lines = [
  { name = loc("benchmark/score"), id = "score" },
  { name = loc("benchmark/average_fps"), id = "avg_fps", modifier = roundFPS },
  { name = loc("benchmark/min_fps"), id = "minFPS", modifier = roundFPS },
  { name = loc("benchmark/time_taken"), id = "timeTakenMs", modifier = millisecondsToSecondsInt },
]

let mkLine = @(name, value) {
  flow = FLOW_HORIZONTAL
  gap = 30
  children = [
    {
      rendObj = ROBJ_TEXT
      size = [sw(30), SIZE_TO_CONTENT]
      halign = ALIGN_RIGHT
      color = defTxtColor
      text = name
    }.__update(fontBody)
    {
      rendObj = ROBJ_TEXT
      size = [sw(30), SIZE_TO_CONTENT]
      halign = ALIGN_LEFT
      color = defTxtColor
      text = value
    }.__update(fontBody)
  ]
}

let header = {
  rendObj = ROBJ_TEXT
  text = loc("benchmark/result_header")
  halign = ALIGN_CENTER
  color = attentionTxtColor
  margin = [0, 0, sidePadding, 0]
}.__update(fontHeading1)

let mkLocation = @(location) {
  rendObj = ROBJ_TEXT
  text = loc(location)
  halign = ALIGN_CENTER
  color = titleTxtColor
  margin = [0, 0, sidePadding, 0]
}.__update(fontHeading2)

let mkBenchmarkContent = @(data) {
  halign = ALIGN_CENTER
  flow = FLOW_VERTICAL
  children = [
    header
    mkLocation(data.location)
  ].extend(lines.map(function(line) {
    let { modifier = null } = line
    let value = modifier ? modifier(data[line.id])
      : data[line.id]
    return mkLine(line.name, value)
  }))
}

let benchmarkSelectionHeader = {
  rendObj = ROBJ_TEXT
  text = loc("benchmark/location")
  halign = ALIGN_CENTER
  color = attentionTxtColor
  margin = [0, 0, sidePadding, 0]
}.__update(fontHeading1)

function mkLocationOption(location) {
  return watchElemState(@(sf) {
    rendObj = ROBJ_BOX
    behavior = Behaviors.Button
    onClick = function() {
      closeBenchmarksList()
      launchBenchmark(location)
    }
    fillColor = sf & S_HOVER ? hoverSlotBgColor
      : fullTransparentBgColor
    children = {
      rendObj = ROBJ_TEXT
      size = [sw(30), SIZE_TO_CONTENT]
      halign = ALIGN_CENTER
      color = sf & S_HOVER ? darkTxtColor
        : defTxtColor
      text = loc(location.name)
    }.__update(fontBody)
  })
}

let mkCloseButton = @(handler) Bordered(loc("Close"), handler, { hotkeys = [[$"^{JB.B} | Esc"]] })

let benchmarksList = {
  halign = ALIGN_CENTER
  flow = FLOW_VERTICAL
  gap = bigPadding
  children = [
    benchmarkSelectionHeader
  ].extend(benchmarkScenes.map(@(scene) mkLocationOption(scene)))
}

let benchmarksListWindow = {
  key = WND_SCENES_UID
  rendObj = ROBJ_SOLID
  flow = FLOW_VERTICAL
  size = flex()
  gap = contentGap
  color = darkPanelBgColor
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  onClick = @() null
  children = [
    benchmarksList
    mkCloseButton(closeBenchmarksList)
  ]
}

function resultWindow() {
  let results = mkBenchmarkContent(benchmarkResult.value)
  addModalWindow({
    key = WND_RESULT_UID
    rendObj = ROBJ_SOLID
    flow = FLOW_VERTICAL
    size = flex()
    gap = contentGap
    color = darkPanelBgColor
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    onClick = @() null
    children = [
      results
      mkCloseButton(function() {
        benchmarkResult(null)
        removeModalWindow(WND_RESULT_UID)
      })
    ]
  })
}

let needOpenResult = keepref(Computed(@() benchmarkResult.value && !isInBattleState.value))
if (needOpenResult.value)
  resultWindow()
needOpenResult.subscribe(@(v) v ? resultWindow() : null)

if (isBenchmarksListOpened.value)
  addModalWindow(benchmarksListWindow)

isBenchmarksListOpened.subscribe(@(v) v ? addModalWindow(benchmarksListWindow)
  : removeModalWindow(WND_SCENES_UID))

let debugResult = {
  score = 7839
  verySlowFrames = 0
  maxSharedVRamUsedKb = 0
  avg_fps = 111.93
  minFPS = 94.8104
  timeStartedMs = 2509985
  slow_frames_pct = 0.0892971
  avgSharedVRamUsedKb = -1
  avgDeviceVRamUsedKb = -1
  slowFrames = 7
  location = "benchmark/scene_normandy_coast"
  timeEndMs = 2580020
  avgCpuOnlyCycleFps = 0
  timeTakenMs = 70035
  avgMemoryUsedKb = 6216231
  maxDeviceVRamUsedKb = 0
  maxMemoryUsedKb = 6243832
  very_slow_frames_pct = 0
}

console_register_command(function() {
  benchmarkResult(debugResult)
}, "ui.debug_benchmark_result")
