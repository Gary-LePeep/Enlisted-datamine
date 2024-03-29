import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/library_logs.nut" import *
let { eventbus_send } = require("eventbus")
let { get_setting_by_blk_path } = require("settings")
let {trackPlayerStart = null} = require("demo_track_player.nut")
if (trackPlayerStart==null)
  return

let {EventLevelLoaded} = require("gameevents")
let {argv} = require("dagor.system")
let {get_time_msec} = require("dagor.time")
let io = require("io")
let { startswith, split_by_chars, format } = require("string")
let platform = require("%dngscripts/platform.nut")
let { exit_game, get_dir, switch_to_menu_scene } = require("app")
let { get_avg_cpu_only_cycle_time_usec, reset_summed_cpu_only_cycle_time } = require("dagor.perf")

let disableMenu = get_setting_by_blk_path("disableMenu") ?? false

let benchmarkParamsQuery = ecs.SqQuery("benchmarkParamsQuery", {comps_rw=[["benchmark_runs", ecs.TYPE_INT], ["benchmark_name", ecs.TYPE_STRING]]})

let setBParam = @(compName, commandlinearg, transform = @(v) v) function () {
  let set = argv
    .filter(@(a) a && startswith(a, $"{commandlinearg}="))
    .map(@(a) transform(split_by_chars(a, "=")[1]))?[0]
  if (set!=null)
    benchmarkParamsQuery.perform(function(_eid, comp) {
      log(compName, set)
      comp[compName] = set
    })
}
let setRuns = setBParam("benchmark_runs", "benchmark_passes", @(v) v.tointeger())
let setName = setBParam("benchmark_name", "benchmark_name")

let benchStatsComps = [
  ["averageDt", ecs.TYPE_FLOAT],
  ["prevMsec", ecs.TYPE_INT],
  ["firstMsec", ecs.TYPE_INT],
  ["frames", ecs.TYPE_INT],
  ["slowFrames", ecs.TYPE_INT],
  ["verySlowFrames", ecs.TYPE_INT],
  ["rangeDt", ecs.TYPE_FLOAT],
  ["rangeFrames", ecs.TYPE_INT],
  ["rangeAvgTimes", ecs.TYPE_ARRAY],
  ["maxMemoryUsedKb", ecs.TYPE_INT],
  ["allMemoryUsedKb", ecs.TYPE_INT64],
  ["maxDeviceVRamUsedKb", ecs.TYPE_INT],
  ["allDeviceVRamUsedKb", ecs.TYPE_INT64],
  ["maxSharedVRamUsedKb", ecs.TYPE_INT],
  ["allSharedVRamUsedKb", ecs.TYPE_INT64],
  ["currentRun", ecs.TYPE_INT],
  ["benchmark_runs", ecs.TYPE_INT],
  ["benchmark_name", ecs.TYPE_STRING],
]

let benchStatsQuery = ecs.SqQuery("benchStatsQuery", {comps_rw=benchStatsComps, comps_ro=[["benchmark_name",ecs.TYPE_STRING, "benchmark_runs"]]})

local lastBenchmarkResult = null

function saveAndResetStats(){

  benchStatsQuery.perform(function(_eid, comps){

    let benchmarkName = comps.benchmark_name
    if (benchmarkName != "" && comps.currentRun > 0) {
      let stats = benchStatsQuery.perform(@(_eid, comp) clone comp)
      let file_name = $"benchmark.{benchmarkName}.{stats.currentRun}.txt"
      local file_path = file_name
      if (platform.is_ps4)
        file_path = $"/hostapp/{file_name}"
      else if (platform.is_ps5)
        file_path = $"/devlog/app/{file_name}"
      else if (platform.is_xbox)
        file_path = $"D:/{file_name}"
      else if (platform.is_android) {
        let dir = get_dir("gamedir")
        file_path = $"{dir}/{file_name}"
      }
      let f = io.file(file_path, "wt")
      local {slowFrames, frames, prevMsec, firstMsec, verySlowFrames, maxMemoryUsedKb, allMemoryUsedKb, maxDeviceVRamUsedKb, allDeviceVRamUsedKb, maxSharedVRamUsedKb, allSharedVRamUsedKb } = stats
      frames = frames > 0 ? frames : 1

      let avgMemoryUsedKb = allMemoryUsedKb / frames
      let avgDeviceVRamUsedKb = allDeviceVRamUsedKb / frames
      let avgSharedVRamUsedKb = allSharedVRamUsedKb / frames

      let avgCpuOnlyCycleTimeUsec = get_avg_cpu_only_cycle_time_usec()
      let avgCpuOnlyCycleFps = avgCpuOnlyCycleTimeUsec > 0.0 ? 1.0 / (avgCpuOnlyCycleTimeUsec / 1000000.0) : 0.0

      let rangeAvgTimes = comps.rangeAvgTimes?.getAll() ?? []

      local maxRangeAvgTime = 0.0
      foreach(rangeAvgTime in rangeAvgTimes) {
        if (rangeAvgTime > maxRangeAvgTime)
          maxRangeAvgTime = rangeAvgTime
      }

      let threshold = 0.97 * maxRangeAvgTime
      local slowestRangeAvgTime = 0.0

      foreach(rangeAvgTime in rangeAvgTimes) {
        if ((threshold > rangeAvgTime) && (rangeAvgTime > slowestRangeAvgTime))
          slowestRangeAvgTime = rangeAvgTime
      }

      let minFPS = slowestRangeAvgTime > 0.0 ? 1.0 / slowestRangeAvgTime : 0.0

      prevMsec = prevMsec > firstMsec ? prevMsec : firstMsec+1
      let avg_fps = 1000.0 * frames / (prevMsec - firstMsec)
      let slow_frames_pct = 100.0 * slowFrames / frames
      let very_slow_frames_pct = 100.0 * verySlowFrames / frames
      let timeTakenMs = prevMsec - firstMsec
      let res = "\n".concat(
        $"avg_fps={avg_fps}",
        $"min_fps={minFPS}",
        $"score={frames}",
        $"slow_frames_pct={slow_frames_pct}",
        $"very_slow_frames_pct={very_slow_frames_pct}",

        $"max_memory_used_in_kb={maxMemoryUsedKb}",
        format("avg_memory_used_in_kb=%.2f",avgMemoryUsedKb),

        $"max_device_vram_used_in_kb={maxDeviceVRamUsedKb}",
        format("avg_device_vram_in_kb=%.2f",avgDeviceVRamUsedKb),

        $"max_shared_vram_used_in_kb={maxSharedVRamUsedKb}",
        format("avg_shared_vram_in_kb=%.2f",avgSharedVRamUsedKb),

        format("avg_cpu_only_cycle_fps=%.2f",avgCpuOnlyCycleFps),

        $"RawStats: frames={frames}, slowFrames={slowFrames}, verySlowFrames={verySlowFrames}, timeTakenMs={timeTakenMs}, timeStartedMs={firstMsec}, timeEndMs={prevMsec}",
        "\n"
      )
      log($"Benchmark stats:\n{res}")
      f.writestring(res)
      f.close()

      lastBenchmarkResult = {
        avg_fps
        minFPS
        score = frames
        slow_frames_pct
        very_slow_frames_pct
        maxMemoryUsedKb
        avgMemoryUsedKb
        maxDeviceVRamUsedKb
        avgDeviceVRamUsedKb
        maxSharedVRamUsedKb
        avgSharedVRamUsedKb
        avgCpuOnlyCycleFps
        slowFrames
        verySlowFrames
        timeTakenMs
        timeStartedMs = firstMsec
        timeEndMs = prevMsec
      }
    }
    reset_summed_cpu_only_cycle_time();
    foreach (compName, _ in comps){
      if (compName == "benchmark_name" || compName == "benchmark_runs")
        continue
      if (compName == "currentRun")
        comps.currentRun++
      else if (compName == "averageDt")
        comps[compName] = 0.0
      else if (compName == "firstMsec")
        comps[compName] = get_time_msec()
      else if (compName == "rangeDt")
        comps[compName] = 0.0
      else if (compName == "rangeAvgTimes") {
        if (comps.currentRun == 0)
          comps[compName] = array(500)
        comps[compName].clear()
      }
      else
        comps[compName] = 0
    }

    if (comps.currentRun > comps.benchmark_runs) {
      if (disableMenu)
        exit_game()
      else {
        eventbus_send("benchmark.result", lastBenchmarkResult)
        switch_to_menu_scene()
      }
    }
  })
}

let activeBenchmarkQuery = ecs.SqQuery("activateBenchmarkQuery", {comps_rw=[["benchmark_active", ecs.TYPE_BOOL]]})
let activateBenchmark = @() activeBenchmarkQuery.perform(@(_, comp) comp.benchmark_active=true)

ecs.register_es("benchmark_activate_es",
  { [EventLevelLoaded] = function(eid, comp) {
      saveAndResetStats()
      setRuns()
      setName()
      comp.benchmark_active=true
      let tracks = comp.camera_tracks?.getAll() ?? []
      if (tracks.len() == 0)
        tracks.append({duration=10.0})
      tracks.append(saveAndResetStats) //this is bad. better to send event that track was finished and do all on it
      ecs.set_callback_timer(function() {
        activateBenchmark()
        trackPlayerStart(eid, tracks, 0.1, 0.15)
      }, 1.0, false)
    }
  },
  { comps_rw = [
      ["benchmark_active",ecs.TYPE_BOOL],
    ],
    comps_ro = [
      ["camera_tracks",ecs.TYPE_ARRAY, []],
    ],
    comps_rq = [
      "benchmark_name"
    ]
  },
  {tags="gameClient"}
)
