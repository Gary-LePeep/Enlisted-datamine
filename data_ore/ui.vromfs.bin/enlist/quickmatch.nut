from "%enlSqGlob/ui/ui_library.nut" import *

let { showMsgbox } = require("%enlist/components/msgbox.nut")
let { fontBody, fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let checkbox = require("%ui/components/checkbox.nut")
let crossplayIcon = require("%enlist/components/crossplayIcon.nut")
let { isInQueue, leaveQueue, joinQueue, timeInQueue, curGameMode
} = require("%enlist/quickMatchQueue.nut")
let { curUnfinishedBattleTutorial } = require("tutorial/battleTutorial.nut")
let { isInSquad, isSquadLeader, squadLeaderState } = require("%enlist/squad/squadState.nut")
let { curArmiesList, armies } = require("%enlist/meta/profile.nut")
let { curArmy } = require("%enlist/soldiers/model/state.nut")
let { endswith } = require("string")
let localSettings = require("%enlist/options/localSettings.nut")("quickMatch/")
let { currentGameMode, eventGameModes } = require("gameModes/gameModeState.nut")
let saveCrossnetworkPlayValue = require("%enlist/options/crossnetwork_save.nut")
let { crossnetworkPlay, CrossplayState } = require("%enlSqGlob/crossnetwork_state.nut")
let { txt } = require("%enlSqGlob/ui/defcomps.nut")
let { titleTxtColor } = require("%enlSqGlob/ui/designConst.nut")
let { is_xbox } = require("%dngscripts/platform.nut")
let { selEvent, isEventModesOpened } = require("%enlist/gameModes/eventModesState.nut")
let { nestWatched } = require("%dngscripts/globalState.nut")
let isChineseVersion = require("%enlSqGlob/isChineseVersion.nut")
let { getArmyBR, maxMatesArmiesTiers, BRByArmies, getLiveArmyBR
} = require("%enlist/soldiers/armySquadTier.nut")
let { selectedGameMode } = require("%enlist/mainScene/changeGameModeButton.nut")
let { missionsByQueue, campaignsByMissions } = require("%enlist/gameModes/missionsQueues.nut")
let logQM = require("%enlSqGlob/library_logs.nut").with_prefix("[QuickMatch] ")

let lastGameMode = nestWatched("lastGameMode", null)

let isInEventGM = Computed(@() isEventModesOpened.value
  || (curGameMode.value != null
    && eventGameModes.value.findvalue(function(v) {
      let isSameQueueId = v.queues.findvalue(@(q) q.queueId == curGameMode.value?.queueId) != null
      return isSameQueueId
    })))

let defaultRandomTeam = !isChineseVersion
let matchRandomTeamCommon = localSettings(defaultRandomTeam, "matchRandomTeam")
let matchRandomTeamEvent = localSettings(defaultRandomTeam, "matchRandomTeamEvent")
let matchRandomTeam = Computed(@() isInEventGM.value
  ? matchRandomTeamEvent.value
  : matchRandomTeamCommon.value)

let randTeamAvailable = Computed(function () {
  let isAvailable = curUnfinishedBattleTutorial.value == null
    && (!isInSquad.value || isSquadLeader.value)

  if (!isInEventGM.value && isAvailable)
    return isAvailable

  let { minCampaignLevelReq = 1 } = selEvent.value
  return curArmiesList.value
    .reduce(@(pre, cur) pre && armies.value[cur].level >= minCampaignLevelReq, isAvailable)
})

let queuesCampaignsData = Computed(function() {
  local brMin = null, brMax = null
  let armyId = curArmy.value
  local isRandom = matchRandomTeam.value
  let mapsList = {}

  let squadLeaderInfo = squadLeaderState.value
  if (isInSquad.value && squadLeaderInfo != null) {
    isRandom = squadLeaderInfo?.isTeamRandom ?? false
  }

  foreach (queue in selectedGameMode.value?.queues ?? []) {
    if (queue?.isLocal)
      continue

    let { teamAllies = [], teamAxis = [] } = queue?.extraParams
    let queueTeam = teamAllies.contains(armyId) ? 0
      : teamAxis.contains(armyId) ? 1
      : null
    if (!isRandom && queueTeam == null)
      continue

    let availArmies = [
      curArmiesList.value.findvalue(@(army) teamAllies.contains(army))
      curArmiesList.value.findvalue(@(army) teamAxis.contains(army))
    ]

    let queueBRs = queue.queueSuffixes.map(@(v) v.tointeger())
    if (queueBRs.len() == 0)
      queueBRs.append(1, 2, 3, 4, 5)
    local isContains = false
    foreach (army in availArmies) {
      let br = maxMatesArmiesTiers.value?[army].tier ?? getLiveArmyBR(BRByArmies.value, army)
      if (queueBRs.contains(br) && (isRandom || army == armyId)) {
        isContains = true
        break
      }
    }

    if (!isContains)
      continue

    foreach (army in availArmies) {
      local campaigns = mapsList?[army]
      if (campaigns == null) {
        campaigns = {}
        mapsList[army] <- campaigns
      }

      let missions = missionsByQueue?[queue.id] ?? []
      foreach (mission in missions) {
        let campaign = campaignsByMissions?[mission]
        if (campaign)
          campaigns[campaign] <- true
      }
    }

    foreach (br in queueBRs) {
      if (brMin == null || br < brMin)
        brMin = br
      if (brMax == null || br > brMax)
        brMax = br
    }
  }

  foreach (army, campaigns in mapsList) {
    mapsList[army] = campaigns.keys()
  }

  return {
    brMin
    brMax
    mapsList
  }
})

function joinImpl(gameMode) {
  logQM($"joinImpl queues:{", ".join((gameMode?.queues ?? []).map(@(q) q.id))}")
  lastGameMode(gameMode)

  let gameParams = {}
  let armyId = curArmy.value
  let teamLegacy = endswith(armyId, "_allies") ? 0
    : endswith(armyId, "_axis") ? 1
    : null
  let isRandom = matchRandomTeam.value

  logQM($"  armies:{", ".join(curArmiesList.value)} curArmy:{armyId} teamLegacy:{teamLegacy}")
  foreach (queue in gameMode?.queues ?? []) {
    let { teamAllies = [], teamAxis = [] } = queue?.extraParams
    let team = teamAllies.contains(armyId) ? 0
      : teamAxis.contains(armyId) ? 1
      : null
    let queueTeam = gameMode?.eventCurArmy ?? team ?? teamLegacy
    if (!isRandom && queueTeam == null) {
      logQM($"  queue:{queue.id} not fit")
      continue
    }

    let queueSuffixes = [
      curArmiesList.value.findvalue(@(army) teamAllies.contains(army))
      curArmiesList.value.findvalue(@(army) teamAxis.contains(army))
    ]
    if (isInSquad.value && isSquadLeader.value && maxMatesArmiesTiers.value != null)
      queueSuffixes.apply(function(army) {
        let { tier = 1 } = maxMatesArmiesTiers.value?[army]
        return max(tier, getArmyBR(army)).tostring()
      })
    else
      queueSuffixes.apply(@(army) getArmyBR(army).tostring())

    let queueBRs = queue.queueSuffixes
    let mteams = []
    foreach (teamIdx in (isRandom ? [0, 1] : [queueTeam]))
      if (queueBRs.contains(queueSuffixes[teamIdx]))
        mteams.append(teamIdx)
    if (mteams.len() == 0) {
      logQM($"  queue:{queue.id} no teams")
      continue
    }

    logQM($"  queue:{queue.id} is ok mteams:", mteams, "queueSuffixes:", queueSuffixes)
    gameParams[queue.queueId] <- {
      mteams
      queueSuffixes
    }
  }

  joinQueue(gameMode, gameParams)
}

function join(gameMode) {
  if (isInQueue.value)
    leaveQueue(@() joinImpl(gameMode))
  else
    joinImpl(gameMode)
}

function setRandTeamValue(val) {
  let watch = isInEventGM.value ? matchRandomTeamEvent : matchRandomTeamCommon
  if (val == watch.value)
    return
  watch(val)

  if (isInQueue.value)
    join(lastGameMode.value)
}

let randTeamBoxStyle = {
  text = loc("queue/join_any_team")
  margin = 0
}.__update(fontBody)

let randTeamCheckbox = checkbox(matchRandomTeam, randTeamBoxStyle, {
  setValue = setRandTeamValue
  textOnTheLeft = true
  hotkeys = [["^J:RS.Tilted"]]
})

let alwaysRandTeamSign = checkbox(Watched(true), randTeamBoxStyle, {
  setValue = @(_val) showMsgbox({ text = loc("modeIsAlwaysForRandTeam") })
  textOnTheLeft = true
})

function activateCrossplay(_val) {
  saveCrossnetworkPlayValue(CrossplayState.ALL)
}

let isCrossplayStateOn = Computed(@() crossnetworkPlay.value == CrossplayState.ALL)
let canSwitchCrossplayState = Computed(@() !is_xbox || crossnetworkPlay.value != CrossplayState.OFF)

let hasCrossplayHint = Computed(function() {
  if (!isInQueue.value
    || isCrossplayStateOn.value)
    return false

  let crossplayHintSec = currentGameMode.value?.showCrossplayHintAfterSec ?? -1
  if (crossplayHintSec < 0)
    return false

  return timeInQueue.value / 1000 >= crossplayHintSec
})

let crossplayCheckbox = checkbox(isCrossplayStateOn,
  {
    text = loc("queue/switchCrossplay")
    color = Color(255,255,255)
    margin = 0
  }.__update(fontBody),
  {
    setValue = activateCrossplay
    textOnTheLeft = true
  })

let crossplayHint = @() {
  watch = [hasCrossplayHint, canSwitchCrossplayState]
  flow = FLOW_HORIZONTAL
  gap = fsh(2)
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = hasCrossplayHint.value
    ? [
        crossplayIcon
        {
          flow = FLOW_VERTICAL
          children = [
            txt({
              text = loc("queueCrossplayHint")
              color = titleTxtColor
            }).__update(fontSub)
            canSwitchCrossplayState.value ? crossplayCheckbox : null
          ]
        }
      ]
    : null
}

let isCurQueueReqRandomSide = Computed(@()
  lastGameMode.value?.alwaysRandomSide ?? false)

let isCurEventReqRandomSide = keepref(Computed(@()
  (selEvent.value?.alwaysRandomSide ?? false) && isEventModesOpened.value))

isCurEventReqRandomSide.subscribe(function(val) {
  if (val)
    setRandTeamValue(true)
})

return {
  randTeamAvailable
  randTeamCheckbox
  alwaysRandTeamSign
  crossplayHint
  joinQueue = join
  matchRandomTeam
  isCurQueueReqRandomSide
  queuesCampaignsData
}
