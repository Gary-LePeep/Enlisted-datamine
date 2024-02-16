let { globalWatched } = require("%dngscripts/globalState.nut")
let { currentReplayInfo, currentReplayInfoUpdate } = globalWatched("currentReplayInfo", @() {})

return {
  currentReplayInfo
  currentReplayInfoUpdate
}
