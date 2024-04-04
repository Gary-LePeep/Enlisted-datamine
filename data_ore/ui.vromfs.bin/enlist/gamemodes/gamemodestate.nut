from "%enlSqGlob/ui/ui_library.nut" import *

let { logerr } = require("dagor.debug")
let { doesLocTextExist } = require("dagor.localize")
let { matchingQueues } = require("%enlist/matchingQueues.nut")
let isNewbie = require("%enlist/unlocks/isNewbie.nut")
let {
  curUnfinishedBattleTutorial, curBattleTutorial, curBattleTutorialTank, curBattleTutorialEngineer,
  curBattleTutorialAircraft, curPractice} = require("%enlist/tutorial/battleTutorial.nut")
let localSettings = require("%enlist/options/localSettings.nut")("quickMatch/")
let { curCampaign, curArmy } = require("%enlist/soldiers/model/state.nut")
let { isInSquad } = require("%enlist/squad/squadState.nut")
let { purchasesExt } = require("%enlist/meta/profile.nut")
let armiesPresentation = require("%enlSqGlob/ui/armiesPresentation.nut")
let { seenGamemodes } = require("seenGameModes.nut")
let { gameLanguage } = require("%enlSqGlob/clientState.nut")
let { maxVersionStr } = require("%enlSqGlob/client_version.nut")
let { check_version } = require("%sqstd/version_compare.nut")

let selGameModeIdByCampaign = mkWatched(persist, "curGameMode", {})
let savedGameModeIdByCampaign = localSettings({}, "curGameMode")

const INFANTRY_TUTORIAL_ID = "tutorial"
const TANK_TUTORIAL_ID = "tutorial_tank"
const ENGINEER_TUTORIAL_ID = "tutorial_engineer"
const AIRCRAFT_TUTORIAL_ID = "tutorial_aircraft"

function updateGameMode(...) {
  selGameModeIdByCampaign(clone savedGameModeIdByCampaign.value)
}

updateGameMode()
foreach (v in [curCampaign, savedGameModeIdByCampaign])
  v.subscribe(updateGameMode)

let selGameModeId = Computed(@() selGameModeIdByCampaign.value?[curCampaign.value])

let defTutorialImage = "ui/game_mode_moscow_tutorial.avif"
let defTutorialTankImage = "ui/game_mode_tutorial_tank.avif"
let defTutorialEngineerImage = "ui/game_mode_tutorial_engineer.avif"
let defTutorialAircraftImage = "ui/game_mode_tutorial_aircraft.avif"
let defPracticeImage = "ui/game_mode_moscow_practice.avif"

let mkGameModeDefaults = @() {
  id = null
  isTutorial = false
  isAvailable = false
  isEnabled = false
  isLocal = false
  minGroupSize = 1
  maxGroupSize = 1
  queues = []
  isLocked = false
  lockLevel = 0
  title = null
  description = null
  image = null
  fbImage = null
  scenes = []
  uiOrder = 0
  needShowCrossplayIcon = true
  reqVersion = null
  isVersionCompatible = true
  isEventQueue = false
  isNewbies = false
  isAvailableForNoobs = false
  isLeaderboardVisible = false
  showWhenInactive = false
  isPreviewImage = false
  leaderboardTables = []
  customProfile = null
  campaignsToShow = []
}

let onlineGameModes = Computed(function() {
  let maxVersionValue = maxVersionStr.value
  let res = []
  let used = {}
  foreach (queueIdx, queue in matchingQueues.value) {
    let { extraParams = {} } = queue
    if ((!(queue?.enabled ?? true) || (queue?.disabled ?? false))
      && !(extraParams?.showWhenInactive ?? false))
        continue

    let id = queue?.id ?? queue?.queueId ?? $"#{queueIdx}"
    if (id in used) {
      logerr($"Not unique queue mode '{id}'")
      continue
    }

    let { reqVersion = null, hideOnIncompatableVersion = false } = extraParams
    let isVersionCompatible = reqVersion == null || check_version(reqVersion, maxVersionValue)
    if (!isVersionCompatible && hideOnIncompatableVersion)
      continue

    used[id] <- true
    res.append(queue)
  }
  res.sort(@(a, b) a.uiOrder <=> b.uiOrder)
  return res
})

let offlineGameModes = Computed(function() {
  if (!curBattleTutorial.value)
    return []

  let armyId = curArmy.value
  return [
    {
      isLocal = true
      isTutorial = true
      id = INFANTRY_TUTORIAL_ID
      locId = "TUTORIAL"
      descLocId = "tutorial_desc"
      uiOrder = 0
      image = armiesPresentation?[armyId].tutorialImage ?? defTutorialImage
      scenes = [curBattleTutorial.value]
    },
    {
      isLocal = true
      isTutorial = true
      id = TANK_TUTORIAL_ID
      locId = "TUTORIAL_TANK"
      descLocId = "tutorial_tank_desc"
      uiOrder = 1
      image = armiesPresentation?[armyId].tutorialTankImage ?? defTutorialTankImage
      scenes = [curBattleTutorialTank.value]
    },
    {
      isLocal = true
      isTutorial = true
      id = ENGINEER_TUTORIAL_ID
      locId = "TUTORIAL_ENGINEER"
      descLocId = "tutorial_engineer_desc"
      uiOrder = 2
      image = armiesPresentation?[armyId].tutorialEngineerImage ?? defTutorialEngineerImage
      scenes = [curBattleTutorialEngineer.value]
    },
    {
      isLocal = true
      isTutorial = true
      id = AIRCRAFT_TUTORIAL_ID
      locId = "TUTORIAL_AIRCRAFT"
      descLocId = "tutorial_aircraft_desc"
      uiOrder = 3
      image = armiesPresentation?[armyId].tutorialAircraftImage ?? defTutorialAircraftImage
      scenes = [curBattleTutorialAircraft.value]
    },
    {
      isLocal = true
      id = "practice"
      locId = "PRACTICE"
      descLocId = "practice_desc"
      uiOrder = 4
      image = armiesPresentation?[armyId].practiceImage ?? defPracticeImage
      scenes = [curPractice.value]
    }
  ]
})

let allGameModes = Computed(function() {
  let campId = curCampaign.value
  let isAllowLocal = !isInSquad.value
  let uiModes = {}
  let res = []
  foreach (queue in [].extend(offlineGameModes.value, onlineGameModes.value)) {
    let { extraParams = {} } = queue
    let { uiGameModeId = null, minCampaignLevel = 0, isEventQueue = false, campaigns = [],
      newbies = false, availableForNoobs = false, showWhenInactive = false, isPreviewImage = false,
      leaderboardTables = [], customProfile = null, campaignsToShow = [],
      isLeaderboardVisible = false
    } = extraParams

    if (campaigns.len() > 0 && !campaigns.contains(campId))
      continue

    local gMode
    if (uiGameModeId == null) {
      gMode = mkGameModeDefaults()
      res.append(gMode)
    }
    else {
      gMode = uiModes?[uiGameModeId]
      if (gMode == null) {
        gMode = mkGameModeDefaults()
        uiModes[uiGameModeId] <- gMode
        res.append(gMode)
      }
    }
    gMode.queues.append(queue)

    gMode.id = gMode.id ?? queue?.id
    let { maxGroupSize = 1 } = queue
    if (gMode.maxGroupSize == 1)
      gMode.maxGroupSize = maxGroupSize
    else if (gMode.maxGroupSize != maxGroupSize)
      logerr($"Queues in gamemode {gMode.id} has different max group size")

    gMode.needShowCrossplayIcon = gMode.maxGroupSize > 1
    gMode.isTutorial = gMode.isTutorial || !!queue?.isTutorial
    gMode.isAvailable = gMode.isAvailable || !queue?.isLocal || isAllowLocal
    gMode.isLocal = gMode.isLocal || !!queue?.isLocal
    gMode.lockLevel = gMode.lockLevel == 0 ? minCampaignLevel
      : min(gMode.lockLevel, minCampaignLevel)
    gMode.image = gMode.image ?? queue?.image ?? extraParams?.image
    gMode.uiOrder = max(gMode.uiOrder, queue?.uiOrder ?? 0)
    gMode.reqVersion = gMode.reqVersion ?? queue?.reqVersion
    gMode.isVersionCompatible = gMode.isVersionCompatible && (queue?.isVersionCompatible ?? true)
    gMode.isEventQueue = gMode.isEventQueue || isEventQueue
    gMode.isNewbies = gMode.isNewbies || newbies
    gMode.isAvailableForNoobs = gMode.isAvailableForNoobs || availableForNoobs
    gMode.isLeaderboardVisible = gMode.isLeaderboardVisible || isLeaderboardVisible
    gMode.scenes = gMode.scenes.len() > 0 ? gMode.scenes : (queue?.scenes ?? [])
    gMode.showWhenInactive = gMode.showWhenInactive || showWhenInactive
    gMode.isPreviewImage = gMode.isPreviewImage || isPreviewImage
    gMode.leaderboardTables.extend(leaderboardTables)
    gMode.customProfile = gMode.customProfile ?? customProfile
    gMode.campaignsToShow.extend(campaignsToShow)
    gMode.isEnabled = gMode.isEnabled || !!queue?.enabled

    local modeTitle = loc(queue?.locId, "")
    if (modeTitle == "") {
      let { locTable = {} } = extraParams
      modeTitle = locTable?[gameLanguage] ?? locTable?["English"] ?? ""
    }
    gMode.title = gMode.title ?? modeTitle

    let descLocId = queue?.descLocId ?? extraParams?.descLocId
    local modeDescription
    if (descLocId != null && doesLocTextExist(descLocId))
      modeDescription = loc(descLocId)
    else {
      let { descLocTable = {} } = extraParams
      modeDescription = descLocTable?[gameLanguage] ?? descLocTable?["English"] ?? modeTitle
    }
    gMode.description = gMode.description ?? modeDescription
  }
  return res
})

let isNewbieFit = @(gameMode, newbie, allow = false) gameMode.isLocal
  || gameMode.isNewbies == newbie
  || (allow && gameMode.isAvailableForNoobs && newbie)

let mainGameModes = Computed(function() {
  let isNewbieV = isNewbie.value
  let res = allGameModes.value.filter(@(gm) !gm.isEventQueue)
  let newbieRes = res.filter(@(gm) isNewbieFit(gm, isNewbieV))
  return newbieRes
    .findvalue(@(gm) gm.queues.findvalue(@(qu) qu?.enabled && qu?.queueId) != null) != null
      ? newbieRes //apply newbie gamemodes only if there exist online modes
      : res
})

let splittedModes = Computed(function() {
  let tutorialModes = []
  let mainModes = []
  foreach (mode in mainGameModes.value)
    if (mode.isTutorial)
      tutorialModes.append(mode)
    else
      mainModes.append(mode)
  return { tutorialModes, mainModes }
})

let tutorialModes = Computed(@() splittedModes.value.tutorialModes)

let mainModes = Computed(@() splittedModes.value.mainModes)

let eventGameModes = Computed(function() {
  let isNewbieV = isNewbie.value
  let boughtGuids = purchasesExt.value
  return allGameModes.value
    .filter(function(gm) {
      if (!gm.isEventQueue || !isNewbieFit(gm, isNewbieV, true))
        return false
      let { requirePurchase = "" } = gm?.extraParams
      if (requirePurchase != "")
        return requirePurchase in boughtGuids
      return true
    })
})

let allGameModesById = Computed(function() {
  let res = {}
  foreach (mode in allGameModes.value)
    res[mode.id] <- mode
  return res
})

let hasUnseenGameMode = Computed(@() mainGameModes.value
  .findvalue(@(gMode) gMode.id not in seenGamemodes.value?.seen))

let hasUnopenedGameMode = Computed(@() mainGameModes.value
  .findvalue(@(gMode) gMode.id not in seenGamemodes.value?.opened))

let currentGameMode = Computed(function() {
  let id = selGameModeId.value
  let allGm = mainGameModes.value.filter(@(gm) gm.isAvailable)

  return allGm.findvalue(@(gm) gm.scenes.contains(curUnfinishedBattleTutorial.value))
    ?? allGm.findvalue(@(gm) gm.id == id)
    ?? allGm.findvalue(@(gm) !gm.isLocal)
    ?? allGm?[0]
})

let currentGameModeId = Computed(@() currentGameMode.value?.id)

function setGameMode(id) {
  let gameMode = mainGameModes.value.findvalue(@(gm) gm.id == id)
  if (gameMode != null) {
    if (onlineGameModes.value.contains(gameMode))
      savedGameModeIdByCampaign.mutate(@(v) v[curCampaign.value] <- id)
    else
      selGameModeIdByCampaign.mutate(@(v) v[curCampaign.value] <- id)
  }
  else
    logerr($"incorrect game mode selected {id}")
}

console_register_command(@() savedGameModeIdByCampaign.mutate({}), "meta.resetSavedGamemodes")

return {
  allGameModesById
  eventGameModes
  currentGameModeId
  currentGameMode
  setGameMode
  hasUnseenGameMode
  hasUnopenedGameMode
  TANK_TUTORIAL_ID
  ENGINEER_TUTORIAL_ID
  AIRCRAFT_TUTORIAL_ID
  tutorialModes
  mainModes
}
