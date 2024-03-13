from "%enlSqGlob/ui/ui_library.nut" import *
from "roomMemberStatuses.nut" import *
let { debounce } = require("%sqstd/timers.nut")
let { deep_clone } = require("%sqstd/underscore.nut")
let { appId } = require("%enlSqGlob/clientState.nut")
let {
  roomIsLobby, setMemberAttributes, room, isEventRoom, roomTeamArmies, roomMembers,
  doConnectToHostOnHostNotfy, canOperateRoom, isInRoom, lobbyStatus, LobbyStatus
} = require("enlRoomState.nut")
let { curArmy, setRoomArmy } = require("%enlist/soldiers/model/state.nut")
let { chosenPortrait, chosenNickFrame } = require("%enlist/profile/decoratorState.nut")
let { isInDebriefing } = require("%enlist/debriefing/debriefingStateInMenu.nut")
let { isInBattleState } = require("%enlSqGlob/inBattleState.nut")
let { showMsgbox } = require("%enlist/components/msgbox.nut")


let keysToDropReady = ["mode", "difficulty", "teamArmies", "scenes"]

let curTeam = mkWatched(persist, "curTeam", 0) // TODO refactor method of updating current team
let myArmy = mkWatched(persist, "myArmy", "")
let hasBalanceCheckedByEntrance = Watched(false)
let lastPlayedSessionId = mkWatched(persist, "lastPlayedSessionId", -1)
let isReady = doConnectToHostOnHostNotfy //really it value need to be always the same atm. But need better name.

// TODO update current teams concerning available event queues
//mteam.subscribe(@(v) isEventRoom.value ? null : curTeam(v))

myArmy.subscribe(@(a) isInRoom.value ? setRoomArmy(a) : null)
curArmy.subscribe(@(a) !isInRoom.value ? myArmy(a) : null)

let method = @(_) isReady(canOperateRoom.value)
foreach (v in [canOperateRoom, isInDebriefing])
  v.subscribe(method)

let myRoomPublic = Computed(@() !isEventRoom.value
  ? { appId = appId
      team = curTeam.value
    }
  : { appId = appId
      team = curTeam.value
      army = myArmy.value
      isReady = isReady.value
      portrait = chosenPortrait.value?.guid
      nickFrame = chosenNickFrame.value?.guid
      status = isInBattleState.value ? IN_BATTLE.id
        : isInDebriefing.value ? IN_DEBRIEFING.id
        : isReady.value ? IN_LOBBY_READY.id
        : IN_LOBBY_NOT_READY.id
    })

function updateMyPublic() {
  if (roomIsLobby.value)
    setMemberAttributes({ public = myRoomPublic.value })

  if (myRoomPublic.value?.status == IN_BATTLE.id && (room.value?.public.sessionId ?? 0) > 0)
    lastPlayedSessionId(room.value?.public.sessionId)
}
let updateMyPublicDebounced = debounce(updateMyPublic, 0.1)
myRoomPublic.subscribe(@(_) updateMyPublicDebounced())

isInRoom.subscribe(function(is) {
  isReady(canOperateRoom.value || !(roomIsLobby.value && isEventRoom.value))
  updateMyPublicDebounced()

  if (!is) {
    setRoomArmy(null)
    myArmy(curArmy.value)
  }
})


local lastRoomPublic = deep_clone(room.value?.public)
let doesTeamContainArmy = @(team, armyId)
  roomTeamArmies.value?[team].contains(armyId) ?? false

function setMyArmy(armyId) {
  if (armyId == myArmy.value || !doesTeamContainArmy(curTeam.value, armyId))
    return
  myArmy(armyId)
}

function setReady(ready) {
  if (canOperateRoom.value || ready == isReady.value) //always ready
    return
  isReady(ready)
  //todo: disbalance messages here
}

function setMyTeam(team) {
  if (team == curTeam.value)
    return

  setReady(false)
  let armyId = myArmy.value
  let hasToChangeArmy = !doesTeamContainArmy(team, armyId)
  if (hasToChangeArmy)
    myArmy(roomTeamArmies.value?[team][0])

  curTeam(team)
}

let hasPlayedCurSession = Computed(function(){
  let { GameInProgress, GameInProgressNoLaunched } = LobbyStatus
  return (room.value?.public.sessionId ?? 0) == lastPlayedSessionId.value
    && (lobbyStatus.value == GameInProgress || lobbyStatus.value == GameInProgressNoLaunched)
  })

isInBattleState.subscribe(function(v){
  if (!v && room.value?.public.sessionId != null && !canOperateRoom.value)
    isReady(false)
})

let canChangeTeam = Computed(function(){
  let maxPlayersByTeam = (room.value?.public.maxPlayers ?? 0) / 2
  let currentTeam = curTeam.value
  let teamToJoin = 1 - currentTeam
  let doesTeamToJoinExists = teamToJoin in roomTeamArmies.value
  let members = roomMembers.value ?? []
  let playersInTeam = members.filter(@(player) player.public?.team == teamToJoin)
  let isRoomCreating = lobbyStatus.value == LobbyStatus.WaitingBeforeLauch
  return doesTeamToJoinExists && playersInTeam.len() < maxPlayersByTeam
    && !hasPlayedCurSession.value && !isRoomCreating
})

function teamSelectAfterEntrance(){
  let members = roomMembers.value ?? []
  let playersInTeamA = members.reduce(@(sum, player) sum + (player?.public.team == 0 ? 1 : 0), 0)
  let playersInTeamB = members.reduce(@(sum, player) sum + (player?.public.team == 1 ? 1 : 0), 0)
  let teamToSelect = playersInTeamA > playersInTeamB ? 1 : 0
  setMyTeam(teamToSelect)
  hasBalanceCheckedByEntrance(true)
}

function onRoomChanged() {
  let isFirstConnectToRoom = lastRoomPublic == null
  let needDropReady = null != keysToDropReady.findindex(@(key)
    !isEqual(lastRoomPublic?[key], room.value?.public[key]))
  lastRoomPublic = deep_clone(room.value?.public)
  if (!roomIsLobby.value || room.value == null)
    return
  if (!isEventRoom.value) {
    updateMyPublic()
    return
  }

  if (needDropReady)
    isReady(canOperateRoom.value)

  let armyId = myArmy.value

  if(!doesTeamContainArmy(curTeam.value, armyId)) {
    setRoomArmy(roomTeamArmies.value?[curTeam.value][0])
    if (!isFirstConnectToRoom && !canOperateRoom.value && !isInDebriefing.value)
      showMsgbox({
        text = loc("lobbyMsg/playerArmyHasChanged")
        buttons = [{ text = loc("Ok"), action = @() anim_start("campaign_blink") }]
      })
  }

  if (!hasBalanceCheckedByEntrance.value)
    teamSelectAfterEntrance()
}

let onRoomChangedDebounced = debounce(onRoomChanged, 0.01)
foreach (w in [room, roomIsLobby, isEventRoom, roomTeamArmies])
  w.subscribe(@(_) onRoomChangedDebounced())

return {
  myRoomPublic
  curTeam
  myArmy
  setMyArmy
  setMyTeam
  canChangeTeam
  isReady = Computed(@() isReady.value)
  setReady
  hasBalanceCheckedByEntrance
  hasPlayedCurSession
}