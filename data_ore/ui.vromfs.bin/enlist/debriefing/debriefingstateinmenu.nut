from "%enlSqGlob/ui/ui_library.nut" import *

let { eventbus_subscribe } = require("eventbus")
let { isInBattleState } = require("%enlSqGlob/inBattleState.nut")
let { dailyTasks } = require("%enlist/unlocks/taskListState.nut")
let { nestWatched } = require("%dngscripts/globalState.nut")


let data = nestWatched("data", null)
let show = nestWatched("show", false)

let statsBeforeBattle = nestWatched("statsBeforeBattle", {})

eventbus_subscribe("debriefing.data", @(val) data(val))
eventbus_subscribe("debriefing.show", @(val) show(val))


isInBattleState.subscribe(function(isInBattle) {
  if (!isInBattle)
    return

  let res = {
    daily = {}
  }
  foreach (task in dailyTasks.value) {
    res.daily[task.name] <- {
      current = task.current
      isCompleted = task.isCompleted
    }
  }
  statsBeforeBattle(res)
})

let computedData = Computed(function() {
  let baseData = data.value
  if (baseData == null)
    return baseData

  let wasTasksProgress = statsBeforeBattle.value
  let dailyTasksProgress = []
  foreach (task in dailyTasks.value) {
    let wasTaskData = wasTasksProgress?.daily[task.name]
    if (wasTaskData == null)
      continue

    if (task.current > wasTaskData.current || (task.isCompleted && !wasTaskData.isCompleted))
      dailyTasksProgress.append(task.__merge({
        wasCurrent = wasTaskData.current
      }))
  }

  let extData = {}
  if (dailyTasksProgress.len() > 0)
    extData.dailyTasksProgress <- dailyTasksProgress

  return baseData.__merge(extData)
})

let clearData = @() data(null)

return {
  show
  data = computedData
  clearData
  isInDebriefing = Computed(@() show.value && computedData.value != null)
}
