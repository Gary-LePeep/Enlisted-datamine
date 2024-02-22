import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui/ui_library.nut" import *

//USED ONLY IN CUISINE ROYALE AND ENLISTED

let artilleryStrikes = Watched({})

function onUpdatePos(eid, comp) {
  if (!comp.artillery_zone__showOnMinimap)
    return
  let res = {
    pos = comp["artillery__targetPos"]
    radius = comp["artillery_zone__radius"]
  }
  artilleryStrikes.mutate(@(value) value[eid] <- res)
}

function onEventEntityDestroyed(eid, _comp) {
  artilleryStrikes.mutate(@(v) v?.$rawdelete(eid))
}

ecs.register_es("hud_artillery_zones_ui_es",
  {
    [["onInit", "onChange"]] = onUpdatePos,
    [ecs.EventEntityDestroyed] = onEventEntityDestroyed
  },
  {
    comps_track = [
      ["artillery__targetPos", ecs.TYPE_POINT3],
    ],
    comps_ro = [
      ["artillery_zone__radius", ecs.TYPE_FLOAT],
      ["artillery_zone__showOnMinimap", ecs.TYPE_BOOL, true]
    ]
  }
)

return artilleryStrikes
