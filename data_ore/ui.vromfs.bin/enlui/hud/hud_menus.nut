import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui/ui_library.nut" import *

require("state/debriefing_es.nut")//fixme
let { get_setting_by_blk_path } = require("settings")
let { showChatInput } =  require("%ui/hud/chat.ui.nut")
let briefing = require("huds/overlays/enlisted_briefing.nut")
let { showBriefing } = require("state/briefingState.nut")
let { playersMenuUi, showPlayersMenu } = require("%ui/hud/menus/players.nut")
let { isAlive } = require("%ui/hud/state/health_state.nut")

let { hudMenus, openMenu } = require("%ui/hud/ct_hud_menus.nut")
let { scoresMenuUi, showScores } = require("huds/scores.nut")
let { showBigMap, bigMap } = require("%ui/hud/menus/big_map.nut")
let { showPieMenu, pieMenuLayer } = require("%ui/hud/state/pie_menu_state.nut")
let pieMenu = require("%ui/hud/pieMenu.ui.nut")
let { showBuildingToolMenu } = require("%ui/hud/state/building_tool_menu_state.nut")
let buildingToolMenu = require("%ui/hud/huds/building_tool_menu.ui.nut")
let { isBuildingToolMenuAvailable } = require("%ui/hud/state/building_tool_state.nut")
let squadSoldiersMenu = require("%ui/hud/huds/squad_soldiers_menu.ui.nut")
let { showSquadSoldiersMenu, isSquadSoldiersMenuAvailable } = require("%ui/hud/state/squad_soldiers_menu_state.nut")
let supplyMenu = require("%ui/hud/huds/paratroopers_supply_menu.ui.nut")
let { showSupplyMenu } = require("%ui/hud/state/paratroopers_supply_menu_state.nut")
let { showBattleChat, forceDisableBattleChat } = require("%ui/hud/state/hudOptionsState.nut")
let { isReplay } = require("%ui/hud/state/replay_state.nut")
let { isGamepad } = require("%ui/control/active_controls.nut")
let dainput = require("dainput2")
let {CmdResetDigitalActionStickyToggle} = require("dasevents")
//local { forcedMinimalHud } = require("state/hudGameModes.nut")

function openBuildingToolMenu() {
  if (isBuildingToolMenuAvailable.value)
    showBuildingToolMenu(true)
}

function openCommandsMenu(layer) {
  if (!isReplay.value && isAlive.value){
    showPieMenu(true)
    pieMenuLayer(layer)
  }
}

function openSquadSoldiersMenu() {
  if (isSquadSoldiersMenuAvailable.value)
    showSquadSoldiersMenu(true)
}

isSquadSoldiersMenuAvailable.subscribe(function(isAvailable) {
  if (!isAvailable)
    showSquadSoldiersMenu(false)
})

let { artilleryMap, showArtilleryMap } = require("%ui/hud/menus/artillery_radio_map.nut")

let { debriefingShow, debriefingDataExt } = require("%ui/hud/state/debriefingStateInBattle.nut")
let debriefing = require("menus/mk_debriefing.nut")(debriefingDataExt)

let groups = {
  debriefing = 1
  gameHud   = 3
  chatInput = 4
  pieMenu   = 5
}
let showChatInputAct = Computed(@() !forceDisableBattleChat.value && showChatInput.value)
let showPieMenuAct = Computed(@() showPieMenu.value && !isReplay.value && isAlive.value)

let disableMenu = get_setting_by_blk_path("disableMenu") ?? false
let huds = [
  {
    show = showBuildingToolMenu
    menu = buildingToolMenu
    holdToToggleDurMsec = @() isGamepad.value ? -1 : null
    close = @() showBuildingToolMenu(false)
    open = openBuildingToolMenu
    event = "HUD.BuildingToolMenu"
    group = groups.pieMenu
    id = "BuildingToolMenu"
  },
  {
    show = showPieMenuAct,
    open = @() openCommandsMenu(1),
    close = @() showPieMenu(false)
    menu = pieMenu
    holdToToggleDurMsec = @() -1
    event = "HUD.CommandsMenu"
    group = groups.pieMenu
    id = "PieMenu"
  },
  {
    show = showPieMenuAct,
    open = @() openCommandsMenu(2),
    close = @() showPieMenu(false)
    holdToToggleDurMsec = @() -1
    event = "HUD.QuickChat"
    group = groups.pieMenu
    id = "QuickChat"
  },
  {
    show = showSquadSoldiersMenu
    menu = squadSoldiersMenu
    open = openSquadSoldiersMenu
    holdToToggleDurMsec = @() -1
    close = @() showSquadSoldiersMenu(false)
    event = "HUD.SquadSoldiersMenu"
    group = groups.pieMenu
    id = "SquadSoldiersMenu"
  },
  {
    show = showChatInputAct
    open = function() {
      if (showBattleChat.value || !forceDisableBattleChat.value)
        showChatInput(true)
    }
    close = @() showChatInput(false)
    event = "HUD.ChatInput"
    group = groups.chatInput
    id = "Chat"
  },
  {
    show = showBriefing
    menu = briefing
    event = "HUD.Briefing"
    group = groups.gameHud
    id = "Briefing"
  },
  {
    show = showArtilleryMap
    menu = artilleryMap
    group = groups.gameHud
    id = "ArtilleryMap"
  },
  {
    show = showSupplyMenu
    menu = supplyMenu
    group = groups.gameHud
    id = "SupplyMenu"
  },
  {
    show = showBigMap
    menu = bigMap
    event = "HUD.BigMap"
    group = groups.gameHud
    id = "BigMap"
  },
  {
    show = showPlayersMenu
    menu = playersMenuUi
    group = groups.gameHud
    id = "Players"
  },
  {
    show = showScores
    menu = scoresMenuUi
    event = "HUD.Scores"
    group = disableMenu ? groups.debriefing : groups.gameHud
    id = "Scores"
  },
  {
    show = debriefingShow
    menu = debriefing
    group = groups.debriefing
    id = "Debriefing"
  }
].filter(@(v) v!=null)

function unstickEventWhenHudClosed(menu) {
  if (menu?.event == null || !(menu?.show instanceof Watched))
    return
  menu.show.subscribe(function(val) {
    if (!val) {
      ecs.g_entity_mgr.broadcastEvent(CmdResetDigitalActionStickyToggle({
        action = dainput.get_action_handle(menu.event, 0xFFFF)
      }))
    }
  })
}

function unstickEventWhenHudOpenCommandFailed(menu) {
  if (menu?.event == null || !(menu?.show instanceof Watched) || type(menu?.open) != "function")
    return

  let originOpenFn = menu.open
  menu.open = function() {
    originOpenFn()
    if (!menu.show.value) {
      ecs.g_entity_mgr.broadcastEvent(CmdResetDigitalActionStickyToggle({
        action = dainput.get_action_handle(menu.event, 0xFFFF)
      }))
    }
  }
}

// if menu was opened with a sticky key and closed not by clicking that key, we want to unstick it
// otherwise the next click of the key will do the unstick and no menu will open
huds.each(unstickEventWhenHudClosed)
huds.each(unstickEventWhenHudOpenCommandFailed)
hudMenus(huds)

debriefingDataExt.subscribe(function(val) {
  if (val.len() > 0)
    openMenu("Debriefing")
})

