from "math" import min

let userstat = require_optional("userstats")
if (userstat==null)
  return require("userstatSecondary.nut") //ui VM, receive all data by cross call instead of host

let { Watched, Computed } = require("frp")
let console_register_command = require("console").register_command
let { tostring_r } = require("%sqstd/string.nut")
let { debug } = require("dagor.debug")
let { console_print } = require("%enlSqGlob/library_logs.nut")
let { resetTimeout } = require("dagor.workcycle")
let { loc } = require("dagor.localize")
let loginState = require("%enlSqGlob/ui/login_state.nut")
let CharClientEvent = require("%enlSqGlob/charClient/charClientEvent.nut")

let logUs = require("%enlSqGlob/library_logs.nut").with_prefix("[USERSTAT] ")
let { split_by_chars } = require("string")
let { debounce } = require("%sqstd/timers.nut")
let userInfo = require("%enlSqGlob/userInfo.nut")
let { get_time_msec } = require("dagor.time")
let {error_response_converter} = require("%enlSqGlob/netErrorConverter.nut")
let { globalWatched, nestWatched } = require("%dngscripts/globalState.nut")
let { eventbus_subscribe } = require("eventbus")
let matchingNotifications = require("%enlSqGlob/ui/notifications/matchingNotifications.nut")
let { get_app_id } = require("app")
let { arrayByRows } = require("%sqstd/underscore.nut")

let { appId, gameLanguage } = require("%enlSqGlob/clientState.nut")
let time = require("serverTime.nut")
let { serverTimeUpdate } = require("serverTimeUpdate.nut")

function mkWatched(persistKey, defVal=null){
  let container = persist(persistKey, @() {v=defVal})
  let watch = Watched(container.v)
  watch.subscribe(@(v) container.v=v)
  return watch
}


let handlers  = {}
let executors = {}
let clientUserStats = CharClientEvent({name   = "userStats",
                                         client = userstat,
                                         handlers,
                                         executors})


let adminHandlers   = {}
let adminUserStats  = CharClientEvent({name     = "userStats.admin",
                                         client   = userstat,
                                         handlers = adminHandlers})

const STATS_REQUEST_TIMEOUT = 45000
const STATS_UPDATE_INTERVAL = 300000 //unlocks progress update interval
const MAX_DELAY_FOR_MASSIVE_REQUEST_SEC = 300 //random delay up to this value when all player want the same config simultaneously.

let chardToken = keepref(Computed(@() userInfo.value?.token))
let userId = keepref(Computed(@() userInfo.value?.userId))

local needSyncSteamAchievements = false
userId.subscribe(@(_v) needSyncSteamAchievements = loginState.isSteamRunning.value)

let errorLogMaxLen = 10
let errorLog = mkWatched("errorLog", [])
let lastSuccessTime = mkWatched("lastSuccessTime", 0)

function checkError(actionId, result) {
  if (result?.error == null)
    return
  errorLog.mutate(function(l) {
    l.append({ action = actionId, result = result, time = get_time_msec() })
    if (l.len() > errorLogMaxLen)
      l.remove(0)
  })
}

function doRequest(request, cb) {
  userstat.request(request, @(result) error_response_converter(cb, result))
}


let syncSteamAchievements = @() clientUserStats.request("SyncUnlocksWithSteam")

handlers["SyncUnlocksWithSteam"] <- @(_)null


function makeUpdatable(persistName, request, watches, defValue) {
  let dataKey = $"userstat.{persistName}"
  let lastTimeKey = $"userstat.{persistName}.lastTime"
  let dataS = globalWatched(dataKey, @() defValue)
  let lastTimeS = globalWatched(lastTimeKey, @() { request = 0, update = 0 })
  let data = dataS[dataKey]
  let dataUpdate = dataS[$"{dataKey}Update"]
  let lastTime = lastTimeS[lastTimeKey]
  let lastTimeUpdate = lastTimeS[$"{lastTimeKey}Update"]
  let isRequestInProgress = @() lastTime.value.request > lastTime.value.update
    && lastTime.value.request + STATS_REQUEST_TIMEOUT > get_time_msec()
  let canRefresh = @() !isRequestInProgress()
    && (!lastTime.value.update || (lastTime.value.update + STATS_UPDATE_INTERVAL < get_time_msec()))

  function processResult(result, cb) {
    checkError(persistName, result)
    if (cb)
      cb(result)

    serverTimeUpdate(1000 * (result?.response.timestamp ?? 0), lastTime.value.request)
    if (result?.error) {
      dataUpdate(defValue)
      logUs($"Failed to update {persistName}")
      logUs(result)
      return
    }

    logUs($"Updated {persistName}")
    lastSuccessTime(get_time_msec())
    dataUpdate(result?.response ?? defValue)

    if (needSyncSteamAchievements) {
      syncSteamAchievements()
      needSyncSteamAchievements = false
    }
  }

  function prepareToRequest() {
    lastTimeUpdate(lastTime.value.__merge({request = get_time_msec()}))
  }

  function refresh(cb = null) {
    if (!chardToken.value || appId < 0) {
      dataUpdate(defValue)
      if (cb)
        cb({ error = "not logged in" })
      return
    }
    if (!canRefresh())
      return

    prepareToRequest()

    request(function(result){
      processResult(result, cb)
    })
  }

  function forceRefresh(cb = null) {
    lastTimeUpdate(lastTime.value.__merge({ update = 0, request = 0}))
    refresh(cb)
  }

  foreach (w in watches)
    w.subscribe(function(_v) {
      lastTimeUpdate(lastTime.value.__merge({update = 0}))
      dataUpdate(defValue)
      forceRefresh()
    })

  if (lastTime.value.request > lastTime.value.update)
    forceRefresh()

  return {
    id = persistName
    data
    refresh
    forceRefresh
    processResult
    prepareToRequest
    lastUpdateTime = Computed(@() lastTime.value.update)
  }
}


let descListUpdatable = makeUpdatable("GetUserStatDescList",
  @(cb) doRequest({
    headers = {
      appid = appId,
      token = chardToken.value,
      language = loc("steam/languageName", gameLanguage).tolower()
    },
    action = "GetUserStatDescList"
  }, cb),
  [chardToken],
  {})

let statsFilter = nestWatched("statsFilter", { modes = [] })

let unlocksFilter = mkWatched("unlocksFilter", {})

function setUnlocksFilter(uFilter) {
  unlocksFilter(uFilter)
}

let toTable = @(arr) arr.reduce(@(res, v) res.rawset(v, true), {})

function isEqualUnordered(arr1, arr2) {
  let tbl1 = toTable(arr1)
  let tbl2 = toTable(arr2)
  if (tbl1.len() != tbl2.len())
    return false
  foreach (val, _ in tbl1)
    if (val not in tbl2)
      return false
  return true
}

function setStatsModes(modes) {
  let curModes = statsFilter.value.modes
  if (!isEqualUnordered(curModes, modes))
    statsFilter.mutate(function(v) { v.modes = modes })
}

let statsUpdatable = makeUpdatable("GetStats",
  @(cb) doRequest({
      headers = {
        appid = appId,
        token = chardToken.value
      },
      action = "GetStats"
      data = statsFilter.value,
    }, cb),
  [chardToken, statsFilter],
  {})

let unlocksUpdatable = makeUpdatable("GetUnlocks",
  @(cb) doRequest({
      headers = {
        appid = appId,
        token = chardToken.value
      },
      action = "GetUnlocks"
      data = unlocksFilter.value,
    }, cb),
  [chardToken, unlocksFilter],
  {})

let lastMassiveRequestTime = mkWatched("lastMassiveRequestTime", 0)
let massiveRefresh = debounce(
  function(checkTime) {
    logUs("Massive update start")
    foreach (data in [statsUpdatable, descListUpdatable, unlocksUpdatable])
      if (data.lastUpdateTime.value < checkTime) {
        logUs($"Update {data.id}")
        data.forceRefresh()
      }
    lastMassiveRequestTime(checkTime)
  }, 0, MAX_DELAY_FOR_MASSIVE_REQUEST_SEC)

let nextMassiveUpdateTime = mkWatched("nextMassiveUpdateTime", 0)
statsUpdatable.data.subscribe(function(stats) {
  local nextUpdate = 0
  let curTime = time.value
  foreach (tbl in stats?.inactiveTables ?? {}) {
    let startsAt = tbl?["$startsAt"] ?? 0
    if (startsAt > curTime)
      nextUpdate = nextUpdate > 0 ? min(nextUpdate, startsAt) : startsAt
  }
  foreach (tbl in stats?.stats ?? {}) {
    let endsAt = tbl?["$endsAt"] ?? 0
    if (endsAt > curTime)
      nextUpdate = nextUpdate > 0 ? min(nextUpdate, endsAt) : endsAt
  }
  nextMassiveUpdateTime(nextUpdate)
})

let lastMassiveRequestQueued = mkWatched("lastMassiveRequestQueued", 0)
if (lastMassiveRequestQueued.value > lastMassiveRequestTime.value)
  massiveRefresh(lastMassiveRequestQueued.value) //if reload script while wait for the debounce

function queueMassiveUpdate() {
  logUs("Queue massive update")
  lastMassiveRequestQueued(nextMassiveUpdateTime.value)
  massiveRefresh(nextMassiveUpdateTime.value)
}

function startMassiveUpdateTimer() {
  if (nextMassiveUpdateTime.value <= lastMassiveRequestTime.value)
    return
  resetTimeout(nextMassiveUpdateTime.value - time.value, queueMassiveUpdate)
}
startMassiveUpdateTimer()
nextMassiveUpdateTime.subscribe(@(_) startMassiveUpdateTimer())


function regeneratePersonalUnlocks(context = null) {
  clientUserStats.request("RegeneratePersonalUnlocks", {}, context)
}


handlers["RegeneratePersonalUnlocks"] <- function(result, context) {
  if ("console_print" in context)
    console_print(result)
  if (result?.error)
    return
  unlocksUpdatable.forceRefresh()
  statsUpdatable.forceRefresh()
}


function generatePersonalUnlocks(context = null) {
  clientUserStats.request("GeneratePersonalUnlocks", {data = {table = "daily"}}, context)
}

handlers["GeneratePersonalUnlocks"] <- function(result, context) {
  if ("console_print" in context)
    console_print(result)
  if (!result?.error)
    unlocksUpdatable.forceRefresh()
}


//config = { <unlockId> = <stage> }
function setLastSeen(config) {
  clientUserStats.request("SetLastSeenUnlocks", {data = config})
}

handlers["SetLastSeenUnlocks"] <- function(result) {
  if (!result?.error)
    unlocksUpdatable.forceRefresh()
}

let unlockRewardsInProgress = Watched({})
function receiveRewards(unlockName, stage, context = null) {
  if (unlockName in unlockRewardsInProgress.value)
    return
  logUs($"receiveRewards {unlockName}={stage}", context)
  unlockRewardsInProgress.mutate(@(u) u[unlockName] <- true)
  clientUserStats.request("GrantRewards",
    {data = {unlock = unlockName, stage = stage}},
    (context ?? {}).__merge({ unlockName }))
}

handlers["GrantRewards"] <- function(result, context) {
  let { unlockName = null } = context
  if (unlockName in unlockRewardsInProgress.value)
    unlockRewardsInProgress.mutate(@(v) v.$rawdelete(unlockName))
  logUs("GrantRewards result:", result)
  if ("error" in result)
    return
  unlocksUpdatable.forceRefresh()
  statsUpdatable.forceRefresh()
}

function receiveRewardsAllUp(unlocksToRewards, context = null) {
  let idsTbl = {}
  let data = []
  foreach (task in unlocksToRewards) {
    let { name, upToStage = -1 } = task
    if (name not in unlockRewardsInProgress.value) {
      data.append({ unlock = name, up_to_stage = upToStage })
      idsTbl[name] <- true
    }
  }
  if (data.len() == 0)
    return
  let idsTblKeys = idsTbl.keys()
  logUs($"receiveRewardsAllUp: {", ".join(idsTblKeys)}")
  unlockRewardsInProgress.mutate(@(u) u.__update(idsTbl))
  clientUserStats.request("BatchGrantRewards",
    {data = {unlocksToReward = data}},
    (context ?? {}).__merge({ unlocksKeys = idsTblKeys }))
}

function receiveRewardsAll(unlocksToRewards, context = null) {
  let idsTbl = {}
  let data = []
  foreach (task in unlocksToRewards) {
    let { name, stage } = task
    if (name not in unlockRewardsInProgress.value) {
      data.append({ unlock = name, stage })
      idsTbl[name] <- true
    }
  }
  if (data.len() == 0)
    return
  let idsTblKeys = idsTbl.keys()
  logUs($"receiveRewardsAll: {", ".join(idsTblKeys)}")
  unlockRewardsInProgress.mutate(@(u) u.__update(idsTbl))
  clientUserStats.request("BatchGrantRewards",
    {data = {unlocksToReward = data}},
    (context ?? {}).__merge({ unlocksKeys = idsTblKeys }))
}

handlers["BatchGrantRewards"] <- function(result, context) {
  let { unlocksKeys = [] } = context
  unlockRewardsInProgress.mutate(function(u) {
    foreach (key in unlocksKeys)
      if (key in u)
        u.$rawdelete(key)
  })
  logUs("BatchGrantRewards result:", result)
  if ("error" in result)
    return
  unlocksUpdatable.forceRefresh()
  statsUpdatable.forceRefresh()
}

function resetPersonalUnlockProgress(unlockName, context = null) {
  adminUserStats.request("AdmResetPersonalUnlockProgress", {
    headers = { token = chardToken.value, userId = userId.value },
    data = { unlock = unlockName }
  },
  context)
}

adminHandlers["AdmResetPersonalUnlockProgress"] <- function(result, context) {
  if ("console_print" in context)
    console_print(result)
  if (!result?.error)
    unlocksUpdatable.forceRefresh()
}


function rerollUnlock(unlockName, cb = null) {
  doRequest({
    headers = { appid = appId, token = chardToken.value },
    data = { unlock = unlockName }
    action = "RerollPersonalUnlock"
  },
  function(result) {
    if (result?.error) {
      if (cb)
        cb(result)
      return
    }
    unlocksUpdatable.forceRefresh(cb)
    statsUpdatable.forceRefresh()
  })
}


function changeStat(stat, mode, amount, shouldSet, cb = null) {
  local errorText = null
  if (typeof amount != "integer" && typeof amount != "float")
    errorText = $"Amount must be numeric (current = {amount})"
  else if (descListUpdatable.data.value?.stats?[stat] == null) {
    errorText = $"Stat {stat} does not exist."
    let similar = []
    let parts = split_by_chars(stat, "_", true)
    foreach (s, _v in descListUpdatable.data.value?.stats ?? {})
      foreach (part in parts)
        if (s.indexof(part) != null) {
          similar.append(s)
          break
        }
    let statsText = "\n      ".join(["  Similar stats:"].extend(arrayByRows(similar, 8).map(@(v) " ".join(v))))
    errorText = "\n  ".join([errorText, statsText], true)
  }

  if (errorText != null) {
    cb?({ error = errorText })
    return
  }

  doRequest({
      headers = {
        appid = appId,
        token = chardToken.value
        userId = userId.value
      },
      data = {
        [stat] = shouldSet ? { "$set": amount } : amount,
        ["$mode"] = mode
      }
      action = "ChangeStats"
    },
    function(result) {
      cb?(result)
      if (!result?.error) {
        unlocksUpdatable.forceRefresh()
        statsUpdatable.forceRefresh()
      }
    })
}


function addStat(stat, mode, amount, cb = null) {
  changeStat(stat, mode, amount, false, cb)
}


function setStat(stat, mode, amount, cb = null) {
  changeStat(stat, mode, amount, true, cb)
}


function sendPsPlus(havePsPlus, token, cb = null) {
  let haveTxt = havePsPlus ? "present" : "absent"
  debug($"Sending PS+: {haveTxt}")
  doRequest({
      headers = {
        appid = get_app_id(),
        token = token
      },
      data = {
        ["have_ps_plus"] = havePsPlus ? true : false
      },
      action = "SetPsPlus"
    },
    function(result) {
      if (cb)
        cb({})
      if (result?.error)
        debug($"Failed to send PS+: {result.error}")
      else
        debug("Succesfully sent PS+")
    })
}


function buyUnlock(unlockName, stage, currency, price, cb = null) {
  doRequest({
    headers = { appid = appId, token = chardToken.value}
    data = { name = unlockName, stage = stage, price = price, currency = currency },
    action = "BuyUnlock"
  },
  function(result) {
    if (result?.error) {
      if (cb)
        cb(result)
      return
    }
    unlocksUpdatable.forceRefresh(function(_res) {
      statsUpdatable.forceRefresh(cb)
    })
  })
}

let seasonRewards = mkWatched("seasonRewards", null)
function updateSeasonRewards(cb = null) {
  doRequest({
    headers = { appid = appId, token = chardToken.value}
    action = "GetSeasonRewards"
  },
  function(result) {
    if (!result?.error)
      seasonRewards(result?.response)
    cb?(result)
  })
}

function clnChangeStats(data, cb = null) {
  statsUpdatable.prepareToRequest()
  unlocksUpdatable.prepareToRequest()
  data["$filter"] <- statsFilter.value
  doRequest({
    headers = { appid = appId, token = chardToken.value}
    data = data
    action = "ClnChangeStats"
  },
  function(result) {
    statsUpdatable.processResult(result, cb)
    unlocksUpdatable.processResult(result, cb)
  })
}

function clnAddStat(mode, stat, amount, cb = null) {
  let data = {
      [stat] = amount,
      ["$mode"] = mode
  }

  clnChangeStats(data, cb)
}

function clnSetStat(mode, stat, amount, cb = null) {
  let statData = {
    ["$set"] = amount
  }

  let data = {
      [stat] = statData,
      ["$mode"] = mode
  }

  clnChangeStats(data, cb)
}

function markUserLogsAsSeen(userlogs) {
  doRequest({
    headers = {
      appid = appId,
      token = chardToken.value
    },
    action = "SetLastSeenUserLogs"
    data = { userlogs },
  }, function(result) {
    if ("error" not in result) {
      unlocksUpdatable.forceRefresh()
      statsUpdatable.forceRefresh()
    }
  })
}

matchingNotifications.subscribe("userStat",
  @(ev) ev?.func == "updateConfig" ? queueMassiveUpdate() : unlocksUpdatable.forceRefresh())


function requestAnoPlayerStats(uid, cb){
  doRequest({
    headers = {
      appid = appId,
      token = chardToken.value
      userId = uid
    },
    action = "AnoGetStats"
    allow_other = true
    data = statsFilter.value
  }, cb)
}

let debugRecursive = @(v) println(tostring_r(v, { recursionLevel = 7 }))
console_register_command(@() descListUpdatable.forceRefresh(console_print), "userstat.get_desc_list")
console_register_command(@() debugRecursive(descListUpdatable.data.value) ?? console_print("Done"),
  "userstat.debug_desc_list")
console_register_command(@() statsUpdatable.forceRefresh(console_print), "userstat.get_stats")
console_register_command(@() debugRecursive(statsUpdatable.data.value) ?? console_print("Done"),
  "userstat.debug_stats")
console_register_command(@() unlocksUpdatable.forceRefresh(console_print), "userstat.get_unlocks")
console_register_command(@() regeneratePersonalUnlocks({console_print = true}), "userstat.reset_personal")
console_register_command(@() updateSeasonRewards(@(v) debugRecursive(v?.response ?? v) ?? console_print("Done")), "userstat.get_season_rewards")
console_register_command(@(unlockName) resetPersonalUnlockProgress(unlockName, {console_print = true}), "userstat.reset_unlock_progress")
console_register_command(@() generatePersonalUnlocks({console_print = true}), "userstat.generate_personal")
console_register_command(@() debugRecursive(unlocksUpdatable.data.value?.personalUnlocks), "userstat.debug_personal")
console_register_command(@(stat, mode, amount) addStat(stat, mode, amount, console_print), "userstat.add_stat")
console_register_command(@(stat, mode, amount) setStat(stat, mode, amount, console_print), "userstat.set_stat")
console_register_command(@() syncSteamAchievements(), "userstat.sync_steam_achievements")
console_register_command(@(have_psplus) sendPsPlus(have_psplus, chardToken.value), "userstat.set_ps_plus")
console_register_command(@(mode, stat, amount) clnAddStat(mode, stat, amount, console_print), "userstat.cln_add_stat")
console_register_command(@(mode, stat, amount) clnSetStat(mode, stat, amount, console_print), "userstat.cln_set_stat")
console_register_command(@() nextMassiveUpdateTime(time.value + 1), "userstat.test_massive_update")
console_register_command(@(amount) addStat("monthly_challenges", "solo", amount, console_print), "unlocks.add")

console_register_command(@(userlogs) markUserLogsAsSeen(userlogs), "unlocks.markUserLogsAsSeen")


let dbgUserstatFailed = Watched(false)
console_register_command(@() dbgUserstatFailed(!dbgUserstatFailed.value), "userstat.fail")

let cmdList = {
  setLastSeenCmd = @(d) setLastSeen(d?.p ?? d)
  refreshStats = @(_d = null) statsUpdatable.refresh()
  forceRefreshUnlocks = @(_d = null) unlocksUpdatable.forceRefresh()
}

eventbus_subscribe("userstat.cmd", @(d) cmdList?[d.cmd]?(d))

return {
  buyUnlock
  userstatStats = statsUpdatable.data
  userstatUnlocks = unlocksUpdatable.data
  userstatDescList = descListUpdatable.data
  userstatExecutors = executors
  receiveUnlockRewards = receiveRewards
  receiveUnlockRewardsAll = receiveRewardsAll
  receiveUnlockRewardsAllUp = receiveRewardsAllUp
  sendPsPlusStatusToUserstatServer = sendPsPlus
  rerollUnlock
  updateSeasonRewards
  seasonRewards
  forceRefreshUnlocks = cmdList.forceRefreshUnlocks
  refreshUserstats = cmdList.refreshStats
  setStatsModes
  setUnlocksFilter
  markUserLogsAsSeen
  requestAnoPlayerStats
  unlockRewardsInProgress
  MAX_DELAY_FOR_MASSIVE_REQUEST_SEC
}
