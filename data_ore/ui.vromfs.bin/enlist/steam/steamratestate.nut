from "%enlSqGlob/ui/ui_library.nut" import *

let { isSteamLinked } = require("%enlist/state/steamState.nut")
let { isSteamRunning } = require("%enlSqGlob/ui/login_state.nut")
let { onlineSettingUpdated, settings } = require("%enlist/options/onlineSettings.nut")
let steam = require("steam")
let isSteamRateUnlock = require("%enlist/unlocks/steamReview.nut")

const SEEN_STEAM_REVIEW = "hasSeenSteamReviewWindow"

let steamURL = $"http://store.steampowered.com/app/{ steam.get_app_id() }/"

function setSteamRateWindowSeenFlag(state = true) {
  if (!onlineSettingUpdated.value)
    return
  if (state == null) {
    if (SEEN_STEAM_REVIEW in settings.value)
      settings.mutate(@(s) s.$rawdelete(SEEN_STEAM_REVIEW))
  }
  else
    settings.mutate(@(s) s[SEEN_STEAM_REVIEW] <- state)
}

let isSteamRateWindowAvailable = Computed(function() {
  let isPureSteamAccount = isSteamRunning.value && !isSteamLinked.value
  if (!isPureSteamAccount)
    return false

  if (settings.value?[SEEN_STEAM_REVIEW])
    return false

  return isSteamRateUnlock.value
})

console_register_command(function() {
  console_print($"{SEEN_STEAM_REVIEW}: ", settings.value?[SEEN_STEAM_REVIEW])
}, "debug.steam_window_seen_state")

console_register_command(function(state) {
  if (state == null || state == true || state == false) {
    setSteamRateWindowSeenFlag(state)
    console_print($"{SEEN_STEAM_REVIEW}: ", settings.value?[SEEN_STEAM_REVIEW])
  }
  else {
    console_print("Wrong value. Should be true/false/null")
  }
}, "debug.steam_window_set_seen_state")

return {
  setSteamRateWindowSeenFlag
  isSteamRateWindowAvailable
  steamURL
}
