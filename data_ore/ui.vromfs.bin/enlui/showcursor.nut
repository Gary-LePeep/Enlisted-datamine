from "%enlSqGlob/ui/ui_library.nut" import *

let {showSettingsMenu} = require("%ui/hud/menus/settings_menu.nut")
let {showGameMenu} = require("%ui/hud/menus/game_menu.nut")
let {hudIsInteractive} = require("%ui/hud/state/interactive_state.nut")
let {showControlsMenu} = require("%ui/hud/menus/controls_setup.nut")
let {hasMsgBoxes} = require("%ui/components/msgbox.nut")
let {hasModalWindows} = require("%ui/components/modalWindows.nut")
let {showPlayersMenu} =  require("%ui/hud/menus/players.nut")
let { needSpawnMenu } = require("%ui/hud/state/respawnState.nut")

let isCursorNeeded = Computed(@() hudIsInteractive.get()
  || showGameMenu.get() || showSettingsMenu.get()
  || showControlsMenu.get() || hasMsgBoxes.get() || hasModalWindows.get()
  || showPlayersMenu.get() || needSpawnMenu.get()
)

return {
  isCursorNeeded
}