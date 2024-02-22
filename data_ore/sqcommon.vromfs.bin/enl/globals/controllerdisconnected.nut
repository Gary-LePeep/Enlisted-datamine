let { globalWatched } = require("%dngscripts/globalState.nut")
let {controllerDisconnected, controllerDisconnectedUpdate} = globalWatched("controllerDisconnected", @() false)
let console_register_command = require("console").register_command

console_register_command(@() controllerDisconnectedUpdate(!controllerDisconnected.value), "ui.controllerDisconnected")

return {
  controllerDisconnected,
  controllerDisconnectedUpdate
}