import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui/ui_library.nut" import *

let steam = require_optional("steam")
let { eventbus_subscribe } = require("eventbus")
let {EventWindowActivated, EventWindowDeactivated} = require("os.window")
let { nestWatched } = require("%dngscripts/globalState.nut")

let windowActive = nestWatched("windowActive", true)
let steamOverlayActive = nestWatched("steamOverlayActive", false)

ecs.register_es("os_window_activation_tracker",
  {
    [EventWindowActivated] = @(...) windowActive.update(true),
    [EventWindowDeactivated] = @(...) windowActive.update(false)
  })

eventbus_subscribe("steam.overlay_activation", @(params) steamOverlayActive.update(params.active))

if (steam) {
  steamOverlayActive.update(steam.is_overlay_active())
}

return {
  windowActive
  steamOverlayActive
}
