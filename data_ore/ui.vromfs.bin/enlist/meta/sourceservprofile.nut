from "%enlSqGlob/ui_library.nut" import *

let { app_is_offline_mode } = require("app")
let { nestWatched } = require("%dngscripts/globalState.nut")
let { EVENT_SAVE_DISABLE_NETWORK_DATA } = require("configs.nut")
let { disableNetwork } = require("%enlSqGlob/login_state.nut")
let { saveJson, loadJson } = require("%sqstd/json.nut")
let eventbus = require("eventbus")
let { set_huge_alloc_threshold } = require("dagor.memtrace")

const DISABLE_NETWORK_PROFILE = "disable_network_profile.json"

let profileStructure = freeze({
  items = {}
  wallposters = {}
  soldiers = {}
  soldiersLook = {}
  soldiersOutfit = {}
  squads = {}
  armies = {}
  soldierPerks = {}
  growthState = {}
  growthProgress = {}
  researches = {} // DEPRECATED
  researchProgress = {}
  squadProgress = {}
  armyEffects = {}
  slotsIncrease = {}
  unlockedSquads = {}
  purchasesCount = {}
  purchasesExt = {}
  receivedUnlocks = {}
  rewardedSingleMissons = {}
  premium = {}
  armyStats = {}
  activeBoosters = {}
  decorators = {}
  vehDecorators = {}
  medals = {}
  offers = {}
  metaConfig = {}
})

let function loadOfflineProfile() {
  let prevSize = set_huge_alloc_threshold(66560 << 10)
  let res = loadJson(DISABLE_NETWORK_PROFILE)
  set_huge_alloc_threshold(prevSize)
  return res
}

let sourceProfileData = nestWatched("player_profile_data",
  (disableNetwork && !app_is_offline_mode())
    ? loadOfflineProfile()
    : (clone profileStructure)
)

let function dumpProfile(...) {
  saveJson(DISABLE_NETWORK_PROFILE, sourceProfileData.value.map(@(w) w.value), { logger = log_for_user })
  console_print($"Current user profile saved to {DISABLE_NETWORK_PROFILE}")
}

eventbus.subscribe(EVENT_SAVE_DISABLE_NETWORK_DATA, dumpProfile)

return {
  profileStructure
  sourceProfileData
}