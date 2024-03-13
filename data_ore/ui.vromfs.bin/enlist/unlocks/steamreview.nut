from "%enlSqGlob/ui/ui_library.nut" import *

let { unlockProgress } = require("%enlSqGlob/userstats/unlocksState.nut")
let { onlineSettingUpdated, settings } = require("%enlist/options/onlineSettings.nut")
let { nestWatched } = require("%dngscripts/globalState.nut")
let serverTime = require("%enlSqGlob/userstats/serverTime.nut")

const STEAM_REVIEW_UNLOCK_ID = "steam_review_unlock"
const SAVE_ID = "user/steamReview"

let isDebugSteamReviewAvailable = nestWatched("isDebugSteamReviewAvailable", null)

let isSteamReviewAvailableUnlock = Computed(@()
  unlockProgress.value?[STEAM_REVIEW_UNLOCK_ID].isCompleted)

let isSteamReviewAvailable = Computed(function() {
  return settings.value?[SAVE_ID] ?? isSteamReviewAvailableUnlock.value ?? false
})

function saveSteamReview(_ = null) {
  if (SAVE_ID not in settings.value && isSteamReviewAvailableUnlock.value)
    settings.mutate(@(set) set[SAVE_ID] <- serverTime.value)
}

isSteamReviewAvailableUnlock.subscribe(saveSteamReview)
onlineSettingUpdated.subscribe(saveSteamReview)

let isAvailable = Computed(@() isDebugSteamReviewAvailable.value ?? isSteamReviewAvailable.value)

console_register_command(function(val) {
  isDebugSteamReviewAvailable(val)
  console_print($"debugSteamReview = { isDebugSteamReviewAvailable.value }, steamReview = {
    isSteamReviewAvailable.value }, isAvailable: { isAvailable.value }")
}, "debug.steam_review_unlock_set_debug_state")

console_register_command(function() {
  console_print($"debugSteamReview = { isDebugSteamReviewAvailable.value }, steamReview = {
    isSteamReviewAvailable.value }, isAvailable: { isAvailable.value }")
}, "debug.steam_review_unlock_state")

return isAvailable
