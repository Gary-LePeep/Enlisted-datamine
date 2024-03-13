from "%enlSqGlob/ui/ui_library.nut" import *

let { unlockProgress } = require("%enlSqGlob/userstats/unlocksState.nut")
let { onlineSettingUpdated, settings } = require("%enlist/options/onlineSettings.nut")
let { nestWatched } = require("%dngscripts/globalState.nut")

const STEAM_NEWBIE_UNLOCK_ID = "not_a_new_steam_player_unlock"
const SAVE_ID = "user/notSteamNewbiePlayer"

let isSteamDebugNewbie = nestWatched("isSteamDebugNewbie", null)

let isSteamNewbieUnlock = Computed(@() unlockProgress.value?[STEAM_NEWBIE_UNLOCK_ID].isCompleted)

let isSteamNewbieBase = Computed(@() !(settings.value?[SAVE_ID]
  ?? isSteamNewbieUnlock.value ?? false))

function saveNewbie(_ = null) {
  if (SAVE_ID not in settings.value && isSteamNewbieUnlock.value)
    settings.mutate(@(set) set[SAVE_ID] <- true)
}

isSteamNewbieUnlock.subscribe(saveNewbie)
onlineSettingUpdated.subscribe(saveNewbie)

let isSteamNewbie = Computed(@() isSteamDebugNewbie.value ?? isSteamNewbieBase.value)

console_register_command(function(val) {
  isSteamDebugNewbie(val)
  console_print($"isSteamNewbieUnlock: { isSteamNewbieUnlock.value }, steamDebugNewbie = {
    isSteamDebugNewbie.value }, isSteamNewbie = { isSteamNewbie.value }")
}, "debug.steam_newbie_unlock_set_debug_state")

console_register_command(function() {
  console_print($"isSteamNewbieUnlock: { isSteamNewbieUnlock.value }, steamDebugNewbie = {
    isSteamDebugNewbie.value }, isSteamNewbie = { isSteamNewbie.value }")
}, "debug.steam_newbie_unlock_state")

return isSteamNewbie
