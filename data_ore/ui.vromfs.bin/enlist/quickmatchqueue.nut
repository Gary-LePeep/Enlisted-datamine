import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui_library.nut" import *

let queueState = require("%enlist/state/queueState.nut")
let { STATUS, curGameMode, queueStatus, isInQueue,
  timeInQueue, queueClusters, queueInfo } = queueState

let { revokeAllSquadInvites, dismissAllOfflineSquadmates, squadOnlineMembers,
  isInSquad, autoSquad, squadId, squadMembers, isInvitedToSquad
} = require("%enlist/squad/squadManager.nut")
let { remap_nick } = require("%enlSqGlob/remap_nick.nut")
let msgbox = require("components/msgbox.nut")
let { matchingCall, netStateCall } = require("matchingClient.nut")
let matching_api = require("matching.api")
let matching_errors = require("matching.errors")
let { get_time_msec } = require("dagor.time")
let { get_app_id } = require("app")
let { checkMultiplayerPermissions } = require("permissions/permissions.nut")
let { EventUserMMQueueJoined } = require("gameevents")
let JB = require("%ui/control/gui_buttons.nut")
let userInfo = require("%enlSqGlob/userInfo.nut")

let { crossnetworkPlay } = require("%enlSqGlob/crossnetwork_state.nut")
let eventbus = require("eventbus")
let isChangesBlocked = Computed(@() isInQueue.value
  || squadMembers.value?[userInfo.value?.userId].state.ready)
let showBlockedChangesMessage = @() msgbox.show({ text = loc("queue/changesBlocked") })
let startQueueTime = Watched(0)
let private = {
  nextQPosUpdateTime  = 0
}

let function onTimer(){
  if (queueStatus.value == STATUS.NOT_IN_QUEUE)
    return

  timeInQueue.update(get_time_msec() - startQueueTime.value)

  let now = get_time_msec()
  if (now > private.nextQPosUpdateTime) {
    private.nextQPosUpdateTime = now + 1000000

    matchingCall("enlmm.get_my_queue_postion",
      function(response) {
        private.nextQPosUpdateTime = now + 5000
        if (response.error == 0)
          queueInfo(response)
      }
    )
  }
}

local wasStatus = queueStatus.value
queueStatus.subscribe(function(s) {
  if (s == STATUS.NOT_IN_QUEUE) {
    timeInQueue(0)
    startQueueTime(get_time_msec())
    queueInfo(null)
    curGameMode(null)
    gui_scene.clearTimer(onTimer)
  } else if (s == STATUS.JOINING || (s == STATUS.IN_QUEUE && wasStatus == STATUS.NOT_IN_QUEUE)) {
    startQueueTime(get_time_msec())
    timeInQueue(0)
    queueInfo(null)
    gui_scene.clearTimer(onTimer)
    gui_scene.setInterval(1.0, onTimer)

    ecs.g_entity_mgr.broadcastEvent(EventUserMMQueueJoined())
  }
  wasStatus = s
})

let function errorText(response) {
  if (response.error == 0)
    return ""
  let errKey = response?.error_id ?? matching_errors.error_string(response.error)
  return loc($"error/{errKey}")
}

let function joinQueueCallback(response) {
  if (response.error == 0)
    return

  log(response)
  queueStatus(STATUS.NOT_IN_QUEUE)
  msgbox.show({ text = errorText(response) })
}

let function joinImpl(gameMode, gameParams) {
  netStateCall(function() {
    curGameMode(gameMode)
    queueStatus(STATUS.JOINING)

    local squadParams = {}
    if (isInSquad.value && squadOnlineMembers.value.len() > 1) {
      let smembers = []
      let appIds = {}
      foreach (uid, member in squadOnlineMembers.value) {
        smembers.append(uid)
        appIds[uid.tostring()] <- member.state?.appId ?? get_app_id()
      }
      squadParams = {
        squad = {
          members = smembers
          leader = squadId.value
        }
        appIds
      }
    }

    foreach (queue in gameMode.queues) {
      let queueId = queue.id
      let queueParams = gameParams?[queueId]
      if (queueParams == null)
        continue

      let params = {
        queueId
        clusters = queueClusters.value.filter(@(has) has).keys()
        allowFillGroup = autoSquad.value ?? queue?.allowFillGroup ?? false
        appId = get_app_id()
        crossplayType = crossnetworkPlay.value
      }.__update(squadParams, queueParams)
      log("enlmm.join_quick_match_queue", params)
      matchingCall("enlmm.join_quick_match_queue", joinQueueCallback, params)
    }
  })
}

let function joinQueue(gameMode, gameParams = {}) {
  if (!checkMultiplayerPermissions()) {
    log("no permissions to run multiplayer")
    return
  }

  if (!isInSquad.value) {
    joinImpl(gameMode, gameParams)
    return
  }

  let { maxGroupSize = 1, minGroupSize = 1 } = gameMode
  local notReadyMembers = ""
  let squadOnlineMembersVal = squadOnlineMembers.value
  let squadOnlineMembersAmount = squadOnlineMembersVal.len()
  foreach (member in squadOnlineMembers.value)
    if ((!member.isLeader && !member.state?.ready) || member.state?.inBattle)
      notReadyMembers += ((notReadyMembers != "") ? ", " : "") + remap_nick(member?.realnick)

  if (notReadyMembers.len())
    return msgbox.show({text=loc("squad/notReadyMembers" { notReadyMembers })})
  if (minGroupSize > squadOnlineMembersAmount)
    return msgbox.show({text=loc("squad/tooFewMembers" { reqMembers = minGroupSize })})
  if (maxGroupSize < squadOnlineMembersAmount)
    return msgbox.show({text=loc("squad/tooMuchMembers" { maxMembers = maxGroupSize })})

  let offlineNum = squadMembers.value.len() - squadOnlineMembersAmount
  local msg = offlineNum ? loc("squad/hasOfflineMembers", { number = offlineNum }) : ""
  if (isInvitedToSquad.value.len())
    msg = (msg.len() ? "\n" : "").concat(msg, loc("squad/hasInvites", { number = isInvitedToSquad.value.len() }))

  if (msg.len()) {
    return msgbox.show({
      text = "\n".concat(msg, loc("squad/theyWillNotGoToBattle"))
      buttons = [
        { text = loc("squad/removeAndGoToBattle")
          isCurrent = true
          action = function() {
            dismissAllOfflineSquadmates()
            revokeAllSquadInvites()
            joinImpl(gameMode, gameParams)
          }
        }
        { text = loc("Cancel"), isCancel = true, customStyle = { hotkeys = [[$"^{JB.B} | Esc"]] } }
      ]
    })
  }
  else
    joinImpl(gameMode, gameParams)
}

let function leaveQueue(cb = null) {
  queueStatus(STATUS.NOT_IN_QUEUE)
  netStateCall(function() {
    matchingCall("enlmm.leave_quick_match_queue", function(_) { cb?() })
  })
}


/************************************* Subscriptions **************************************/

foreach (name, cb in {
  ["enlmm.on_quick_match_queue_leaved"] = function(request) {
    print("onQuickMatchQueueLeaved")
    log(request)
    queueStatus(STATUS.NOT_IN_QUEUE)
  },

  ["enlmm.on_quick_match_queue_joined"] = function(request) {
    print("onQuickMatchQueueJoined")
    log(request)
    queueStatus(STATUS.IN_QUEUE)
  },
}){
  matching_api.listen_notify(name)
  eventbus.subscribe(name,cb)
}

eventbus.subscribe("matching.logged_out", @(...) queueStatus(STATUS.NOT_IN_QUEUE))

// leave queue if player leaves or enters squad
isInSquad.subscribe(function(_) {
  if (isInQueue.value)
    leaveQueue()
})

let squadMembersGeneration = Watched(0)
local prevSquadMembers = {}
let changeGen = @() squadMembersGeneration(squadMembersGeneration.value+1)

let function onSquadMembersChange(v) {
  local changedGen = false
  foreach (uid, member in v) {
    if (uid in prevSquadMembers)
      continue
    let isLeader = member?.isLeader
    if (!member.state?.ready && isLeader) {
      changeGen()
      changedGen = true
      break
    }
  }
  prevSquadMembers = v
  if (!changedGen && (v.len() != prevSquadMembers.len() || !isEqual(v.keys(), prevSquadMembers.keys())))
    changeGen()
}
squadMembers.subscribe(onSquadMembersChange)
onSquadMembersChange(squadMembers.value)

//leave queue if squadMembers list changed
squadMembersGeneration.subscribe(function(_) {
  if (isInQueue.value)
    leaveQueue()
})

return queueState.__merge({
  joinQueue
  leaveQueue
  isChangesBlocked
  showBlockedChangesMessage
})