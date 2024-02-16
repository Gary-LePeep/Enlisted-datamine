from "%enlSqGlob/ui_library.nut" import *

let { rand } = require("math")
let { chooseRandom } = require("%sqstd/rand.nut")
let { matchingCall } = require("%enlist/matchingClient.nut")
let baseRoomState = require("%enlist/state/roomState.nut")
let { room, startSessionWithLocalDedicated, canStartWithLocalDedicated, joinedRoomWithInvite,
  isHostInGame
} = baseRoomState
let roomMembersBase = baseRoomState.roomMembers
let { showMsgbox } = require("%enlist/components/msgbox.nut")
let { openEventModes } = require("%enlist/gameModes/eventModesState.nut")
let { gameProfile } = require("%enlist/soldiers/model/config/gameProfile.nut")
let { portraits, nickFrames } = require("%enlSqGlob/ui/decoratorsPresentation.nut")
let { error_string } = require("matching.errors")
let { save_settings, get_setting_by_blk_path, set_setting_by_blk_path } = require("settings")
let memberStatuses = require("roomMemberStatuses.nut")


const IS_LOCAL_DEDICATED = "startWithLocalDedicated"

let roomScene = Computed(@() room.value?.public.scene)
let isEventRoom = Computed(@() room.value?.public.digestGroup == "events-lobby")
let debugMembers = mkWatched(persist, "debugMembers", [])
let roomMembers = Computed(@() (clone roomMembersBase.value).extend(debugMembers.value))
let isLocalDedicated = Watched(get_setting_by_blk_path(IS_LOCAL_DEDICATED) ?? false)
isLocalDedicated.subscribe(function(v) {
  set_setting_by_blk_path(IS_LOCAL_DEDICATED, v)
  save_settings()
})


let roomTeamArmies = Computed(function() {
  let { armiesTeamA = [], armiesTeamB = [] } = room.value?.public
  return [armiesTeamA, armiesTeamB]
})

let function onStartSessionResult(res) {
  if (res.error == 0)
    return

  log("Error on start session: ", res)
  showMsgbox({
    text = loc("msgbox/failedJoinRoom",
      { error = res?.accept == false ? loc(res?.reason ?? "") // server rejected invite
        : loc($"error/{error_string(res.error)}")
      })
  })
}

let function startSession() {
  isHostInGame(true)
  if (isLocalDedicated.value && canStartWithLocalDedicated.value)
    startSessionWithLocalDedicated(onStartSessionResult)
  else
    matchingCall("mrooms.start_session",
      onStartSessionResult,
      { cluster = room.value?.public.cluster })
}

let function cancelSessionStart() {
  matchingCall("mrooms.cancel_session_start")
}

let mkDebugMembers = @(count) array(count).map(function(_, idx) {
  let campaign = chooseRandom((gameProfile.value?.campaigns ?? {}).keys())
  let rnd = rand()
  return {
    userId = rnd
    memberId = 1000 - idx
    name = $"WWWWWWWWWWWWWWW{rnd % 10}"
    nameText = $"WWWWWWWWWWWWWWW{rnd % 10}"
    squadNum = max(0, rnd % 10 - 4)
    public = {
      team = rnd % 2
      campaign
      army = chooseRandom(gameProfile.value?.campaigns[campaign].armies ?? [])?.id ?? ""
      isReady = (rnd % 2) == 1
      portrait = chooseRandom(portraits.keys())
      nickFrame = chooseRandom(nickFrames.keys())
      status = chooseRandom(memberStatuses.keys())
    }
  }
})


joinedRoomWithInvite.subscribe(function(v){
  if (!v)
    return
  openEventModes()
})

console_register_command(
  @() debugMembers(debugMembers.value.len() > 0 ? [] : mkDebugMembers(rand() % 64)),
  "eventRooms.toggleDebugMembersMode")
console_register_command(@() debugMembers(mkDebugMembers(rand() % 64)),
  "eventRooms.regenerateDebugMembers")

return baseRoomState.__merge({
  roomScene
  roomTeamArmies
  isEventRoom
  roomMembers
  isLocalDedicated

  startSession
  cancelSessionStart
})
