from "%enlSqGlob/ui/ui_library.nut" import *

let mkDropMenuBtn = require("%enlist/dropdownmenu/mkDropDownMenuBlock.nut")
let {
  btnOptions, btnControls, btnExit, btnLogout, SEPARATOR, btnGSS, btnSupport, btnCBR, btnLegals,
  btnLinkEmail
} = require("%enlist/mainMenu/defMainMenuItems.nut")
let { openChangelog } = require("%enlist/openChangelog.nut")
let { isInQueue } = require("%enlist/state/queueState.nut")
let isChineseVersion = require("%enlSqGlob/isChineseVersion.nut")
let { customGamesOpen } = require("%enlist/mpRoom/customGamesWnd.nut")
let debugProfileWnd = require("%enlist/mainMenu/debugProfileWnd.nut")
let debugConfigsWnd = require("%enlist/mainMenu/debugConfigsWnd.nut")
let {hasClientPermission} = require("%enlSqGlob/client_user_rights.nut")
let { DBGLEVEL, dgs_get_settings } = require("dagor.system")
let { get_circuit, app_set_offline_mode, is_user_game_mod, switch_to_menu_scene } = require("app")
let { is_sony, is_xbox, is_console } = require("%dngscripts/platform.nut")
let { openUrl } = require("%ui/components/openUrl.nut")
let qrWindow = require("%enlist/mainMenu/qrWindow.nut")
let { enlistedForumUrl, feedbackUrl } = require("%enlSqGlob/supportUrls.nut")
let { hasCampaignSelection }  = require("%enlist/campaigns/campaign_sel_state.nut")
let { setCurCampaign } = require("%enlist/meta/curCampaign.nut")
let { changelogDisabled } = require("%enlist/changeLogState.nut")
let msgbox = require("%enlist/components/msgbox.nut")
let { doesLocTextExist } = require("dagor.localize")
let gameLauncher = require("%enlist/gameLauncher.nut")
let { isReplayTabHidden } = require("%enlist/replay/replaySettings.nut")
let profileScene = require("%enlist/profile/profileScene.nut")
let { file_exists } = require("dagor.fs")
let { remove } = require("system")
let { hasBattlePass } = require("%enlist/unlocks/taskRewardsState.nut")
let { openBPwindow } = require("%enlist/battlepass/bpWindowState.nut")
let { openBenchmarksList } = require("%enlist/benchmark/benchmarkState.nut")
let { hasGpuBenchmark } = require("%enlist/featureFlags.nut")
let { get_setting_by_blk_path } = require("settings")
let { isLinkEmailAvailable } = require("%enlist/state/steamState.nut")


let noSandboxEditorInMenu = true
function startSandBoxEditor() {
  app_set_offline_mode(true)
  gameLauncher.startGame({
      game = "enlisted", scene = "gamedata/scenes/sandbox_editor_start.blk", modId = "sandboxEditor"
  })
}

let btnChangeCampaign = {
  id = "ChangeCamppaign"
  name = loc("btn/changeCampaign")
  cb = @() setCurCampaign(null)
}

let btnBattlePass = {
  id = "BattlePass"
  name = loc("bp/battlePass")
  cb = openBPwindow
}

let btnCustomGames = {
  id  = "CustomGames"
  name = loc("Custom games")
  cb = customGamesOpen
}

let btnChangelog = changelogDisabled ? null : {
  id = "Changelog"
  name = loc("gamemenu/btnChangelog")
  cb = openChangelog
}

let gameStoryMsg = doesLocTextExist("gameStoryMsg") ? loc("gameStoryMsg") : ""
let btnShowGameStory = gameStoryMsg == "" ? null : {
  id = "GameStory"
  name = loc("gamemenu/btnGameStory")
  cb = @() msgbox.showMsgbox({ text = gameStoryMsg })
}

let btnDebugProfile = {
  id = "DebugProfile"
  name = loc("Debug Profile")
  cb = debugProfileWnd
}

let btnDebugConfigs = {
  id = "DebugConfigs"
  name = loc("Debug Configs")
  cb = debugConfigsWnd
}

let btnForum = enlistedForumUrl == "" ? null : {
  id = "Forum"
  name = loc("forum")
  cb = !is_xbox ? @() openUrl(enlistedForumUrl)
    : @() qrWindow({url = enlistedForumUrl, header = loc("forum")})
}

let btnFeedback = feedbackUrl == "" ? null : {
  id = "Feedback"
  name = loc("feedback", "Feedback")
  cb = @() openUrl(feedbackUrl)
}

let btnSandboxEditor = {
  id = "SandboxEditor"
  name = loc("Sandbox Editor")
  cb = startSandBoxEditor
}

let btnReplays = {
  id = "replay"
  name = loc("replay/records")
  cb = @() profileScene("replay")
}

let btnResetHangar = {
  id = "resetHanhar"
  name = loc("hangar/reset")
  cb = @() msgbox.show({
    text = loc("hangar_reset_confirmation")
    buttons = [
      {
        text = loc("Yes")
        action = function() {
          let customHangarFile = dgs_get_settings()?.menu?.scene ?? ""
          if (file_exists(customHangarFile))
            remove(customHangarFile)
          switch_to_menu_scene()
        }
      }
      { text=loc("No"), isCurrent = true}
    ]
  })
}

let btnBenchmark = {
  id = "Benchmark"
  name = loc("benchmark/menu_option")
  cb = openBenchmarksList
}

let perksSimulationUrl = get_setting_by_blk_path("perksSimulationUrl") ?? ""
let btnPerksSimulation = {
  id = "PerksSimulation"
  name = loc("btn/perksSimulation")
  cb = @() openUrl(perksSimulationUrl)
}


let videoTipsUrl = get_setting_by_blk_path("videoTipsUrl") ?? ""
let btnVideoTips = {
  id = "VideoTips"
  name = loc("btn/VideoTips")
  cb = @() openUrl(videoTipsUrl)
}


let needCustomGames = (DBGLEVEL > 0
  || ["moon","sun","ganymede","yueliang"].indexof(get_circuit()) != null)
    ? Computed(@() !isInQueue.value)
    : Watched(false)
let serverDataPermission = hasClientPermission("debug_server_data")
let canDebugProfile = Computed(@() DBGLEVEL > 0
  || serverDataPermission.value)

function buttons(){
  let res = []
  if (needCustomGames.value) {
    res.append(btnCustomGames)
    if (!is_console && !noSandboxEditorInMenu)
      res.append(btnSandboxEditor)
  }
  res.append(btnShowGameStory)
  res.append(btnChangelog)
  if (!isReplayTabHidden.value)
    res.append(btnReplays)
  if (hasGpuBenchmark.value)
    res.append(btnBenchmark)
  if (is_user_game_mod())
    res.append(btnResetHangar)
  if (res.len() > 0)
    res.append(SEPARATOR)
  if (hasCampaignSelection.value)
    res.append(btnChangeCampaign)
  if (hasBattlePass.value)
    res.append(btnBattlePass)
  res.append( btnOptions, btnControls, btnSupport )
  if (perksSimulationUrl != "")
    res.append(btnPerksSimulation)
  if (videoTipsUrl != "")
    res.append(btnVideoTips)
  res.append( btnForum, btnFeedback, btnGSS )
  if (isLinkEmailAvailable.value)
    res.append(btnLinkEmail)
  if (!isChineseVersion)
    res.append(btnCBR)
  res.append(btnLegals)
  if (is_xbox) {
    res.append(btnLogout)
    if (DBGLEVEL > 0)
      res.append(btnExit)
  } else if (!is_sony)
    res.append(btnExit)
  if (canDebugProfile.value)
    res.append(SEPARATOR, btnDebugProfile, btnDebugConfigs)

  return res.filter(@(v) v!=null)
}
let watch = [needCustomGames, hasCampaignSelection, canDebugProfile,
  isReplayTabHidden, hasBattlePass, isLinkEmailAvailable]

return mkDropMenuBtn(buttons, watch)
