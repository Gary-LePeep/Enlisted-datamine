let { globalWatched, nestWatched } = require("%dngscripts/globalState.nut")
let gameLauncher = require("%enlist/gameLauncher.nut")
let { eventbus_subscribe } = require("eventbus")

let { selectedBenchmark, selectedBenchmarkUpdate } = globalWatched("selectedBenchmark", @() null)
let { isBenchmarksListOpened, isBenchmarksListOpenedUpdate
} = globalWatched("isBenchmarksListOpened", @() false)
let benchmarkResult = nestWatched("benchmarkResult", null)

function launchBenchmark(scene) {
  benchmarkResult(null)
  selectedBenchmarkUpdate(scene)
  gameLauncher.startGame({
    game = "enlisted",
    scene = scene.path
  })
}

eventbus_subscribe("benchmark.result", function(result) {
  benchmarkResult(result.__merge({ location = selectedBenchmark.value.name }))
})

return {
  launchBenchmark
  benchmarkResult
  isBenchmarksListOpened
  openBenchmarksList = @() isBenchmarksListOpenedUpdate(true)
  closeBenchmarksList = @() isBenchmarksListOpenedUpdate(false)
}
