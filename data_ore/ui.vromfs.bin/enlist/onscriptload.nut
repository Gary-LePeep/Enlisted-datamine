from "%enlSqGlob/ui/ui_library.nut" import *
let { is_sony } = require("%dngscripts/platform.nut")

require("%enlSqGlob/sqevents.nut")
set_nested_observable_debug( VAR_TRACE_ENABLED )
require("%enlSqGlob/ui/styleUpdate.nut")
require("notifications.nut")
require("currency/currenciesList.nut")
require("sections.nut")
require("scene/scene_control.nut")
require("campaigns/selectCampaignArmyScene.nut")
require("meta/profileRefresh.nut")
require("meta/dumpStats.nut")
require("%enlist/soldiers/model/configArmiesDump.nut")
require("faceGen.nut")
require("battleData/sendSoldiersData.nut")
require("battleData/mkDefaultProfile.nut")
require("battleData/singleMissionRewardId.nut")
require("battleData/applyBattleExp.nut")
let { setMainMenuComp } = require("%enlist/mainMenu/mainMenuComp.nut")
let mainMenu = require("%enlist/mainMenu/mainMenu.nut")
setMainMenuComp(mainMenu)
require("notifications/mainMenuDescription.nut")
require("notifications/premiumExpiration.nut")
require("notifications/memberLockedCampaign.nut")
require("notifications/unlockRewardCampaignNotification.nut")
require("notifications/newSquadReceivedNotification.nut")
require("notifications/serviceNotificationMonitor.nut")
require("notifications/updateGameNotify.nut")
require("%enlist/login/initLogin.nut")
require("login/initLoginStages.nut")
require("squad/myExtData.nut")
require("%enlist/currency/initPurchaseActions.nut")

require("%enlist/tutorial/tutorialWnd.nut")
require("soldiers/chooseSquadsScene.nut")
require("soldiers/chooseSoldiersScene.nut")
require("%enlist/tutorial/ordersTutorial.nut")
require("%enlist/tutorial/squadTutorialsMsg.nut")
require("%enlist/tutorial/newSquadByArmyLevelTutorial.nut")
require("soldiers/selectItemScene.nut")


require("soldiers/notReadySquadsMsg.nut")
require("%ui/complaints/complain.nut")
require("%enlist/guidelinesPopup.nut")
require("%enlist/shop/shopResultMsgbox.nut")
require("%enlSqGlob/ui/webHandlers/webHandlers.nut")
require("%enlSqGlob/ui/weGameHandlers/weGameHandlers.nut")
require("battlepass/bpWindow.nut")
require("battlepass/debugBpRewardsView.nut")
require("unlocks/dailyRewardsUi.nut")
require("gameModes/eventModesWindow.nut")
require("gameModes/createEventRoomWnd.nut")
require("gameModes/missionsRatingWnd.nut")
require("leaderboard/leaderboardWnd.nut")
require("%enlist/profile/profileScene.nut")
require("%enlist/profile/anoProfileScene.nut")
require("%enlist/profile/unseenProfileStuffs.nut")
require("%enlist/contacts/externalIdsManager.nut")
require("%enlist/soldiers/soldierCustomizationScene.nut")
require("%enlist/soldiers/model/shopItemsToRequest.nut")
require("%enlist/usermail/usermailScene.nut")
require("%enlist/vehicles/selectVehicleScene.nut")
require("%enlist/vehicles/customizeScene.nut")
require("%enlist/vehicles/hitcamScene.nut")
require("%enlist/soldiers/model/console_cmd.nut")
require("%enlist/replay/replayDownloadInfo.nut")
require("%enlist/replay/replayWebHadlers.nut")
require("%enlist/gameModes/hangarWebHandlers.nut")
require("%enlist/items/itemCollageScene.nut")
require("%enlist/shop/rentedSquadDialog.nut")
require("%enlist/tutorial/armyUnlocksVideoHint.nut")
require("notifications/benchmarkNotification.nut")
require("%enlist/preset/presetEquipUtils.nut")
require("%enlist/shop/updateSeenBundles.nut")
require("%enlist/benchmark/benchmarkUi.nut")
require("%enlist/options/onlineSettingsOnShutdown.nut")


let { setMenuOptions, menuTabsOrder } = require("%ui/hud/menus/settings_menu.nut")
let { violenceOptions } = require("%ui/hud/menus/options/violence_options.nut")
let { harmonizationOption } = require("%ui/hud/menus/options/harmonization_options.nut")
let { harmonizationNickOption } = require("%ui/hud/menus/options/harmonization_nick_options.nut")
let planeControlOptions = require("%ui/hud/menus/options/plane_control_options.nut")
let { cameraShakeOptions } = require("%ui/hud/menus/options/camera_shake_options.nut")
let { hudOptions } = require("%ui/hud/menus/options/hud_options.nut")
let { renderOptions } = require("%ui/hud/menus/options/render_options.nut")
let { soundOptions } = require("%ui/hud/menus/options/sound_options.nut")
let { cameraFovOption } = require("%ui/hud/menus/options/camera_fov_option.nut")
let { voiceChatOptions } = require("%ui/hud/menus/options/voicechat_options.nut")
let { crossnetworkOptions } = require("%enlist/options/crossnetwork_options.nut")
let { vehicleCameraFovOption } = require("%ui/hud/menus/vehicle_camera_fov_option.nut")
let { planeFlightSenseOption } = require("%ui/hud/menus/options/plane_camera_options.nut")
let { vehicleCameraFollowOption } = require("%ui/hud/menus/vehicle_camera_follow_option.nut")
let { leaderboardOptions } = require("%ui/hud/menus/options/leaderboard_options.nut")
let narratorOptions = require("%ui/hud/menus/options/narrator_options.nut")
let autoleanOptions = require("%ui/hud/menus/options/autolean_options.nut")
let vehicleGroupLimitOptions = require("%ui/hud/menus/options/vehicle_group_limit_options.nut")
let qualityPresetOption = require("%ui/hud/menus/options/get_quality_preset_option.nut")


let options = [qualityPresetOption, cameraFovOption, vehicleCameraFovOption,
  planeFlightSenseOption, vehicleCameraFollowOption, harmonizationOption, harmonizationNickOption]
options.extend(
  renderOptions, soundOptions, voiceChatOptions, cameraShakeOptions, violenceOptions, planeControlOptions,
  crossnetworkOptions, leaderboardOptions, hudOptions, narratorOptions, autoleanOptions, vehicleGroupLimitOptions
)

setMenuOptions(options)

menuTabsOrder([
  {id = "Graphics", text=loc("options/graphicsParameters")},
  {id = "Sound", text = loc("sound")},
  {id = "Game", text = loc("options/game")},
  {id = "VoiceChat", text = loc("controls/tab/VoiceChat")},
])

// FIXME it's just quick and dirty fix. autoSquad parameter should be moved otside of general
// squadState and passed to quickMatchQueue as project specific argument
require("%enlist/squad/squadState.nut").autoSquad(null)
require("backgroundContentUpdater.nut")

let quickMatchQueueInfoCmp = require("queueWaitingInfo.ui.nut")
let {aboveUiLayer} = require("%enlist/uiLayers.nut")
aboveUiLayer.add(quickMatchQueueInfoCmp, "quickMatchQueue")

let { matchRandomTeam } = require("%enlist/quickMatch.nut")
let { curArmy, selectArmy } = require("soldiers/model/state.nut")
let { isEventModesOpened, customRoomsModeSaved, isCustomRoomsMode
} = require("gameModes/eventModesState.nut")
let { curCampaign, setCurCampaign } = require("%enlist/meta/curCampaign.nut")

let { throttle } = require("%sqstd/timers.nut")
let { changelogDisabled, haveUnseenVersions, requestPatchnotes,
  patchnotesReceived, maxVersionInt } = require("changeLogState.nut")
let { openChangelog } = require("openChangelog.nut")
let { get_time_msec } = require("dagor.time")

let { isInBattleState } = require("%enlSqGlob/inBattleState.nut")
let { nestWatched } = require("%dngscripts/globalState.nut")

let patchnote = nestWatched("patchnote", {
  cachedUpdatedVersion = -1
  timeShown = -1
  requestMadeTime = -1
})
let { unlockProgress } = require("%enlSqGlob/userstats/unlocksState.nut")

const MIN_SEC_BETWEEN_REQUESTS = 10 //10 seconds
let checkVersionAndReqPatchnotes = throttle(function(...) {
  if (!isInBattleState.value
      && maxVersionInt.value >= 0
      && maxVersionInt.value > patchnote.value.cachedUpdatedVersion) {
    requestPatchnotes()
    patchnote.mutate(function(v) {
      v.cachedUpdatedVersion = maxVersionInt.value
      v.requestMadeTime = get_time_msec()
    })
  }
}, MIN_SEC_BETWEEN_REQUESTS, {leading=true, trailing=false})
checkVersionAndReqPatchnotes()
gui_scene.setInterval(301, checkVersionAndReqPatchnotes) //check version each 10minutes in menu
isInBattleState.subscribe(checkVersionAndReqPatchnotes) //check versions after returning from Battle

let needShowPatchnote = keepref(Computed(@() patchnotesReceived.value
  && haveUnseenVersions.value
  && (unlockProgress.value?["not_a_new_player_unlock"].isCompleted ?? false)
  && patchnote.value.timeShown != patchnote.value.requestMadeTime
))

if (!changelogDisabled)
  needShowPatchnote.subscribe(function(v) {
    if (!v)
      return
    openChangelog()
    patchnote.mutate(@(val) val.timeShown = val.requestMadeTime)
  })

require("%enlist/mainScene/webPromo.nut")

let leaveQueueNotification = require("notifications/leaveQueueNotification.nut")
leaveQueueNotification({
  watch = curCampaign
  setValue = setCurCampaign
})
leaveQueueNotification({
  watch = curArmy
  setValue = selectArmy
  askLeave = @() !matchRandomTeam.value
})
leaveQueueNotification({
  watch = isEventModesOpened
})
leaveQueueNotification({
  watch = isCustomRoomsMode
  setValue = customRoomsModeSaved
})

require("%enlist/debriefing/debriefingInMenu.nut")

let fonts = require("%enlSqGlob/ui/fontsStyle.nut")
require("%enlist/components/fontsDebugWnd.nut")(fonts)
let debriefingDbg = require("%enlist/debriefing/debriefing_dbg.nut")
let debriefingState = require("%enlist/debriefing/debriefingStateInMenu.nut")
debriefingDbg.init({
  state = debriefingState
  samplePath = ["../prog/enlist/debriefing/samples/debriefing_sample.json",
                "../prog/enlist/debriefing/samples/debriefing_sample2.json"]
  savePath = "debriefing_enlisted.json"
  loadPostProcess = function(debrData) {
    if (typeof debrData?.players != "table")
      return

    let players = {}
    foreach (id, player in debrData.players)
      players[id.tointeger()] <- player
    debrData.players = players
  }
})

let { removeAllMsgboxes } = require("%ui/components/msgbox.nut")
isInBattleState.subscribe(function(v) {
  if (v)
    removeAllMsgboxes()
})

if (is_sony)
  require("%enlist/ps4/supportedPlatforms.nut")(["PS4", "PS5"])

console_register_command(@(trigger) anim_start(trigger), "anim.start")
console_register_command(@(trigger) anim_request_stop(trigger), "anim.stop")
console_register_command(@(trigger) anim_skip(trigger), "anim.skip")
console_register_command(@(trigger) anim_skip_delay(trigger), "anim.skipDelay")
