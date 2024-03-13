from "%enlSqGlob/ui/ui_library.nut" import *
let { showSquadSpawn, isParatroopersSquad, paratroopersPointSelectorRequested } = require("%ui/hud/state/respawnState.nut")
let checkbox = require("%ui/components/checkbox.nut")


let showButton = Computed(@() showSquadSpawn.value && isParatroopersSquad.value)

let paratroopersButtonBlock = @() {
  watch = [ showButton ]
  size = [flex(), SIZE_TO_CONTENT]
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = showButton.value ? checkbox(paratroopersPointSelectorRequested, loc("respawn/airbornDeploy")) : null
}

return paratroopersButtonBlock