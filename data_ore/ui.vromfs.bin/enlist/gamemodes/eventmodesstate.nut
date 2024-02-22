from "%enlSqGlob/ui/ui_library.nut" import *

let { matchingCall } = require("%enlist/matchingClient.nut")
let { get_app_id } = require("app")
let serverTime = require("%enlSqGlob/userstats/serverTime.nut")
let { eventbus_subscribe } = require("eventbus")
let { matching_listen_notify } = require("matching.api")
let { debounce } = require("%sqstd/timers.nut")

let { eventGameModes } = require("gameModeState.nut")
let { userstatStats, MAX_DELAY_FOR_MASSIVE_REQUEST_SEC
} = require("%enlSqGlob/userstats/userstat.nut")
let { allModes, isRoomCfgActual, actualizeRoomCfg } = require("createEventRoomCfg.nut")
let { hasCustomGames, showEventsWidget } = require("%enlist/featureFlags.nut")
let { curArmy } = require("%enlist/soldiers/model/state.nut")
let { loadJson } = require("%sqstd/json.nut")
let squadsPresentation = require("%enlSqGlob/ui/squadsPresentation.nut")
let mkCurSquadsList = require("%enlSqGlob/ui/mkSquadsList.nut")
let isNewbie = require("%enlist/unlocks/isNewbie.nut")
let armiesPresentation = require("%enlSqGlob/ui/armiesPresentation.nut")
let { nestWatched } = require("%dngscripts/globalState.nut")

let isEventModesOpened = nestWatched("isEventModesOpened", false)
let customRoomsModeSaved = nestWatched("customRoomsModeSaved", false)
let hasCustomRooms = Computed(@()
  !isNewbie.value && allModes.value.len() > 0 && hasCustomGames.value)
let isCustomRoomsMode = Computed(@() customRoomsModeSaved.value && hasCustomRooms.value)
let selEventIdByPlayer = nestWatched("selEventByPlayer", null)
let curEventSquadId = nestWatched("curEventSquadId")
let eventCurArmyIdx = nestWatched("eventCurArmyIdx", 0)
let eventsArmiesList = nestWatched("eventsArmiesList", [])
let hasUniqueArmies = nestWatched("hasUniqueArmies", false)
let { campaignsByArmies } = require("%enlSqGlob/renameCommonArmies.nut")

let curTab = Watched(null)

let hasBaseEvent = Computed(@() showEventsWidget.value
  && (hasCustomRooms.value || eventGameModes.value.len() > 0))

let inactiveEventsToShow = Computed (@()
  eventGameModes.value.filter(@(gm) gm.showWhenInactive && !gm.isEnabled))

let activeEvents = Computed (@() eventGameModes.value.filter(@(gm) gm.isEnabled))

let allEventsToShow = Computed (@() [].extend(activeEvents.value, inactiveEventsToShow.value))

let promotedEvent = Computed(@()
  allEventsToShow.value.findvalue(@(gm) gm.isPreviewImage)
    ?? allEventsToShow.value?[0])

let selEvent = Computed(@()
  eventGameModes.value.findvalue(@(gm) gm.id == selEventIdByPlayer.value)
    ?? eventGameModes.value?[0])

let selLbMode = Computed(@() selEvent.value?.leaderboardTables[0])
let eventCustomProfilePath = Computed(@() selEvent.value?.customProfile)

let eventCustomProfile = Computed(@() eventCustomProfilePath.value != null
  ? loadJson(eventCustomProfilePath.value)
  : null)


let eventCustomSquads = Computed(function() {
  if (eventCustomProfile.value == null)
    return null
  local armyId = curArmy.value
  if (eventCustomProfile.value?[armyId] == null) {
    let armies = eventCustomProfile.value.keys()
    armyId = armies?[eventCurArmyIdx.value] ?? armies?[0]
  }

  let squads = eventCustomProfile.value?[armyId].squads ?? []
  if (squads.len() == 0)
    return null
  return squads
    .map(function(squad) {
      let squadId = squad.squadId
      let squadDesc = squadsPresentation?[armyId][squadId]
      local { premIcon = null } = squadDesc
      if ((squad?.battleExpBonus ?? 0) > 0)
        premIcon = premIcon ?? armiesPresentation?[armyId].premIcon
      return {
        squadId
        icon = squadDesc?.icon
        premIcon
        name = squad?.locId ? loc(squad.locId) : "---"
        squadType = squad?.squadType ?? "unknown"
        level = squad?.level ?? 0
        squadSize = squad.squad.len()
        vehicle = squad?.curVehicle
        vehicleType = squad?.vehicleType
      }
    })
  }
)

function updateEvent() {
  let armyList = selEvent.value.queues[0].extraParams?.armies ?? campaignsByArmies.keys()
  if (eventCustomProfile.value != null) {
    let squads = eventCustomSquads.value
    let uniqueArmyList = eventCustomProfile.value.keys()
    let armiesCustomProfile = []
    foreach (armyId in armyList)
      if (uniqueArmyList.contains(armyId))
        armiesCustomProfile.append(armyId)
    hasUniqueArmies(armiesCustomProfile.len() <= 1)
    eventsArmiesList(hasUniqueArmies.value ? uniqueArmyList : armiesCustomProfile)
    curEventSquadId(squads[0].squadId)
  }
  else {
    eventsArmiesList(armyList)
    hasUniqueArmies(false)
  }
}

function checkUpdateEvent(_) {
  if (isEventModesOpened.value && !isCustomRoomsMode.value)
    updateEvent()
}

foreach (v in [selEvent, isEventModesOpened])
  v.subscribe(checkUpdateEvent)

isEventModesOpened.subscribe(@(v) v ? null : eventsArmiesList([]))

let eventsSquadList = @(squads) mkCurSquadsList({
  curSquadsList = squads
  curSquadId = curEventSquadId
  setCurSquadId = @(squadId) curEventSquadId(squadId)
})

let selEventEndTime = Computed(function() {
  let time = userstatStats.value?.stats[selLbMode.value]["$endsAt"].tointeger() ?? 0
  return time
})

let needActualizeCfg = keepref(Computed(@() !isRoomCfgActual.value && isEventModesOpened.value))
needActualizeCfg.subscribe(function(v) { if (v) actualizeRoomCfg() })

function openCustomGameMode() {
  customRoomsModeSaved(true)
  isEventModesOpened(true)
}

function openEventsGameMode() {
  customRoomsModeSaved(false)
  isEventModesOpened(true)
}

let eventStartTime = Watched({})

function nearestTime(mmEvent, mmAction, timeTable) {
  if (mmEvent.action == mmAction && (mmEvent.queue_id not in timeTable
      || mmEvent.time < timeTable[mmEvent.queue_id]) )
    timeTable[mmEvent.queue_id] <- mmEvent.time
}

local isMMScheduleProcessed = false

function timeUntilStart() {

  if (isMMScheduleProcessed)
    return

  let self = callee()

  matchingCall("enlmm.get_schedule_list",
    function(response) {
      local timeStart = {}
      local timeFinish = {}
      local nextRefresh = 0

      if (response.error != 0)
        return

      (response?.list ?? [])
        .each(function (x) {
          nearestTime(x, "enable_queue", timeStart)
          nearestTime(x, "disable_queue", timeFinish)
        })

        foreach (queueId, timestamp in timeStart) {
          if (timeFinish[queueId] < timestamp)
            timeStart[queueId] = 0
          if (nextRefresh == 0 || nextRefresh > min(timestamp, timeFinish[queueId]))
            nextRefresh = min(timestamp, timeFinish[queueId])
        }
        eventStartTime(timeStart)

        if (nextRefresh > 0)
          gui_scene.resetTimeout(nextRefresh - serverTime.value, function() {
            isMMScheduleProcessed = false
            self()
          })

      isMMScheduleProcessed = true
    }, {appId = get_app_id()})
}

let requestNewSchedule = debounce(function() {
  isMMScheduleProcessed = false
  timeUntilStart()
}, 0, MAX_DELAY_FOR_MASSIVE_REQUEST_SEC)

hasBaseEvent.subscribe(@(_) timeUntilStart())

matching_listen_notify("enlmm.notify_schedule_list_changed")
eventbus_subscribe("enlmm.notify_schedule_list_changed", @(_) requestNewSchedule())

return {
  eventGameModes
  activeEvents
  inactiveEventsToShow
  allEventsToShow
  promotedEvent
  isEventModesOpened
  isCustomRoomsMode
  hasCustomRooms
  customRoomsModeSaved
  selEvent
  selLbMode
  selectEvent = @(eventId) selEventIdByPlayer(eventId)
  openEventModes = @() isEventModesOpened(true)
  openCustomGameMode
  openEventsGameMode
  selEventEndTime
  eventCustomSquads
  eventsSquadList
  eventsArmiesList
  eventCurArmyIdx
  hasBaseEvent
  eventCustomProfile
  curTab
  eventStartTime
}