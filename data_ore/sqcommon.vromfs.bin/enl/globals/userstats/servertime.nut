let { nestWatched } = require("%dngscripts/globalState.nut")
let console_register_command = require("console").register_command
let { console_print } = require("%enlSqGlob/library_logs.nut")

let serverTime = nestWatched("userstat.time", 0)

console_register_command(@() console_print($"serverTime: {serverTime.value}"), "stat.time")

return serverTime