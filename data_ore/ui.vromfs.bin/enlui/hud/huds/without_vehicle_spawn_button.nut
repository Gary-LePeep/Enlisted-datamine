from "%enlSqGlob/ui/ui_library.nut" import *
let { showSquadSpawn, spawnWithoutVehicleRequested, spawnWithoutVehicleAvailable } = require("%ui/hud/state/respawnState.nut")
let checkbox = require("%ui/components/checkbox.nut")

let showWithoutVehicleButton = Computed(@() showSquadSpawn.value && spawnWithoutVehicleAvailable.value)

let withoutVehicleSpawnButtonBlock = @() {
  watch = [ showWithoutVehicleButton ]
  size = [flex(), SIZE_TO_CONTENT]
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = showWithoutVehicleButton.value ? checkbox(spawnWithoutVehicleRequested, loc("respawn/spawnWithoutVehicle")) : null
}

return withoutVehicleSpawnButtonBlock