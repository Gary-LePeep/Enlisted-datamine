import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui/ui_library.nut" import *
let { EventOnBattleResult } = require("%enlSqGlob/sqevents.nut")
let logD = require("%enlSqGlob/library_logs.nut").with_prefix("[DEBRIEFING] ")
let { eventbus_send } = require("eventbus")
let watchdog = require("watchdog")
let armyData = require("armyData.nut")
let soldiersData = require("soldiersData.nut")
let { teams } = require("%ui/hud/state/teams.nut")
let { localPlayerEid, localPlayerTeam, localPlayerGroupId, localPlayerGroupMembers } = require("%ui/hud/state/local_player.nut")
let { isDebugDebriefingMode } = require("%enlSqGlob/wipFeatures.nut")
let { get_session_id } = require("app")
let { isTutorial } = require("%ui/hud/tutorial/state/tutorial_state.nut")
let { singleMissionRewardId, singleMissionRewardSum } = require("%enlSqGlob/singleMissionRewardState.nut")

let debriefingData = mkWatched(persist, "debriefingData")
let debriefingShow = mkWatched(persist, "debriefingShow", false)
local watchdogData = persist("watchdogMode", @() { mode = null })

const INVALID_SESSION = "0"

let debriefingUpdateData = mkWatched(persist, "debriefingUpdateData", {})
let battleStats = mkWatched(persist, "battleStats", {})
let isMissionSuccess = Computed(@() debriefingData.value?.result.success)
let canApplyRewards = keepref(Computed(@() battleStats.value.len() > 0
  && (get_session_id() != INVALID_SESSION
    || isDebugDebriefingMode
    || (singleMissionRewardId.value != null && isMissionSuccess.value))))


let mkGetExpToNextLevel = @(expToLevel)
  @(level, maxLevel) level < (maxLevel ?? (expToLevel.len() - 1))
    ? (expToLevel?[level] ?? 0)
    : 0

function extrapolateStatsExp(soldier, expData, getExpToNextLevel) {
  // Specify the default value for maxLevel
  // as this code runs with pre-generated data where maxLevel is undefined.
  local { maxLevel = 1, level, exp } = soldier
  let addExp = expData.exp
  local nextExp = getExpToNextLevel(level, maxLevel)
  let wasExp = {
    exp
    level
    nextExp
  }
  exp += addExp
  while(nextExp > 0 && exp >= nextExp) {
    exp -= nextExp
    if (level < maxLevel)
      level++
    nextExp = getExpToNextLevel(level, maxLevel)
  }

  return expData.__merge({
    exp = addExp
    wasExp = wasExp
    newExp = {
      exp
      level
      nextExp
    }
  })
}

let chargeExp = @(expData) eventbus_send("charge_battle_exp_rewards", expData)

function getSquadData(squadId, stats) {
  let squad = (armyData.value?.squads ?? []).findvalue(@(s) s.squadId == squadId)
  let awardScore = (squad?.squad ?? []).reduce(
    @(res, soldier) res + (stats?[soldier?.guid ?? ""].awardScore ?? 0),
    0)
  return {
    awardScore = awardScore
    nameLocId = squad?.nameLocId
    titleLocId = squad?.titleLocId
    icon = squad?.icon
    wasExp = squad?.exp ?? 0
    wasLevel = squad?.level ?? 0
    toLevelExp = squad?.toLevelExp ?? 0
    battleExpBonus = squad?.battleExpBonus ?? 0.0
    isRented = squad?.isRented ?? 0.0
  }
}

function shareExp(list, expSum) {
  let oneExp = (expSum / (list.len() || 1)).tointeger()
  return list.map(@(_) { exp = oneExp })
}

function calcSingleMissionExpReward(expReward) {
  let expSum = (armyData.value?.premiumExpMul ?? 1.0) * singleMissionRewardSum.value
  let tutorial = isTutorial.value
  return {
    armyExp = expSum.tointeger()
    squadsExp = tutorial ? {} : shareExp(expReward?.squadsExp ?? {}, expSum)
    soldiersExp = tutorial ? {} : shareExp(expReward?.soldiersExp ?? {}, expSum)
  }
}

function applyRewardOnce() {
  if (debriefingUpdateData.value.len())
    return //already applied

  logD("Recalc squads stats")
  let armyId = armyData.value?.armyId
  if (armyId == null) {
    logD("Skip soldiers exp reward due unknown armyId")
    return
  }

  let isSingleMission = get_session_id() == INVALID_SESSION
  let sMissionRewardId = isSingleMission ? singleMissionRewardId.value : null
  let { armyExp = 0, squadsExp = {}, soldiersExp = {}, armyExpDetailed = {},
    boosts = {}, expMode = ""
  } = !isSingleMission || isDebugDebriefingMode ? battleStats.value?.expReward
      : sMissionRewardId != null ? calcSingleMissionExpReward(battleStats.value?.expReward)
      : null
  let { isArmyProgressLocked = false } = battleStats.value
  let players = battleStats.value?.players.map(@(player) [player.eid, player]).totable() ?? {}
  let awards = battleStats.value?.awards ?? []

  let items = {}
  let stats = {}
  foreach (guid, data in battleStats.value?.stats ?? {}) {
    let soldier = soldiersData.value?[guid]
    if (!soldier) {
      logD("Not found soldier {0} in army {1} for reward. Skip. ".subst(guid, armyId))
      continue
    }
    items[guid] <- soldier
    stats[guid] <- data
  }

  let getExpToNextLevel = mkGetExpToNextLevel(armyData.value?.expToLevel ?? [])
  let statsWithExp = stats.map(
    @(s, guid) s.__merge(extrapolateStatsExp(soldiersData.value[guid], soldiersExp?[guid] ?? { exp = 0 }, getExpToNextLevel)))

  debriefingUpdateData({
    armyId
    campaignId = armyData.value?.campaignId
    singleMissionRewardId = sMissionRewardId
    soldiers = {
      items = items
      stats = statsWithExp
    }
    squads = squadsExp.map(@(expData,  squadId) getSquadData(squadId, stats).__update(expData))
    armyExp
    armyExpDetailed
    isArmyProgressLocked
    armyWasExp = armyData.value?.exp
    armyWasGrowthExp = armyData.value?.growthExp
    globalData = armyData.value?.globalData
    armyWasLevel = armyData.value?.level
    armyProgress = armyData.value?.armyProgress
    growthProgress = armyData.value?.growthProgress
    premiumExpMul = armyData.value?.premiumExpMul
    heroes = battleStats.value?.heroes
    battleHeroAwards = battleStats.value?.battleHeroAwards
    isBattleHero = battleStats.value?.isBattleHero
    battleHeroSoldier = battleStats.value?.battleHeroSoldier
    wasPlayerRank = battleStats.value?.wasPlayerRank
    playerRank = battleStats.value?.playerRank
    scorePrices = battleStats.value?.scorePrices
    players
    awards
    boosts
    expMode
  })

  if (sMissionRewardId != null && !isDebugDebriefingMode)
    chargeExp({
      armyId
      singleMissionRewardId = sMissionRewardId
      soldiersExp = soldiersExp.map(@(ed) ed.exp)
      squadsExp = squadsExp.map(@(ed) ed.exp)
      armyExp
    })
}

canApplyRewards.subscribe(function(c) { if (c) applyRewardOnce() })

ecs.register_es("soldiers_stats_listener_es",
  { [EventOnBattleResult] = function(evt, _eid, _comp) {
      logD("Receive battle stats")
      battleStats(evt.data ?? {})
    }
  },
  {})

//we send only base data, because userstats update will be the same in enlist vm
function subscribeDebriefingWatches(data = debriefingData, show = debriefingShow) {
  data.subscribe(@(val) eventbus_send("debriefing.data", val))
  show.subscribe(function(val) {
    if (val)
      watchdogData.mode = watchdog.change_mode(watchdog.LOBBY)
    else
      watchdog.change_mode(watchdogData.mode)
    eventbus_send("debriefing.show", val)
  })
}

let debriefingDataExt = Computed(function(){
  if (debriefingData.value == null)
    return null
  let teamsData = {}
  foreach (team in teams.value)
    if (team?["team__id"]) {
      let teamId = team["team__id"].tostring()
      teamsData[teamId] <- { teamId, icon = team?["team__icon"], armies = team?["team__armies"] }
    }
  let res = debriefingData.value
    .__merge({
      localPlayerEid = localPlayerEid.value
      localPlayerGroupMembers = localPlayerGroupMembers.value
      localPlayerGroupId = localPlayerGroupId.value
      myTeam = localPlayerTeam.value
      teams = teamsData
      armyId = armyData.value?.armyId
      isFinal = debriefingUpdateData.value.len() > 0
    }, debriefingUpdateData.value)
  logD("DebriefingDataExt updated")
  return res
})

debriefingDataExt.subscribe(@(val) debriefingShow(val!=null && val.len()>0))
subscribeDebriefingWatches(debriefingDataExt, debriefingShow)

return {
  debriefingData
  debriefingDataExt
  debriefingShow
}
