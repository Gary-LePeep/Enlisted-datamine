import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui/ui_library.nut" import *

let { blurBack } = require("style.nut")
let { localPlayerEid } = require("%ui/hud/state/local_player.nut")
let { wWidth, wHeight, weaponWidgetAnims } = require("vehicle_weapon_widget.nut")
let mobileRespawnOccupiedSeats = Watched(null)

let passengersText = {
  size = [wWidth / 3, wHeight / 2]
  rendObj = ROBJ_TEXT
  text = loc("hud/mobile_respawn_passengers")
  hplace = ALIGN_LEFT
  vplace = ALIGN_CENTER
}

function mobileRespawnWidget(occupiedSeats) {
  let icon = {
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    size = [wHeight, wHeight]
    rendObj = ROBJ_IMAGE
    image = Picture($"!ui/skin#enlisted_unithelmet.svg:{wHeight}:{wHeight}:K")
    color = Color(255, 255, 255, occupiedSeats == 0 ? 120 : 255)
  }

  let countText = {
    rendObj = ROBJ_TEXT
    text = occupiedSeats
    hplace = ALIGN_RIGHT
    vplace = ALIGN_CENTER
  }

  return {
    size = [wWidth,wHeight]
    animations = weaponWidgetAnims
    children = {
      size = [wWidth, wHeight]
      clipChildren = true
      children = [
        blurBack
        passengersText
        icon
        countText
      ]
    }
  }
}

ecs.register_es("track_mobile_respawn_state",{
  [["onInit", "onChange"]] = function(_, _eid, comp) {
    if (comp.ownedByPlayer == localPlayerEid.value)
      mobileRespawnOccupiedSeats(comp.mobile_respawn__occupiedSeats)
  },
  onDestroy = function(_, _eid, comp) {
    if (comp.ownedByPlayer == localPlayerEid.value)
      mobileRespawnOccupiedSeats(null)
  }
},
{
  comps_track = [["mobile_respawn__occupiedSeats", ecs.TYPE_INT]],
  comps_ro = [["ownedByPlayer", ecs.TYPE_EID]],
  comps_rq = ["mobileRespawnTag", "vehicleWithWatched"]
},
{tags="ui"}
)

return {
  mobileRespawnWidget
  mobileRespawnOccupiedSeats
}