import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui/ui_library.nut" import *

let enemy_attack_markers = Watched({})

function deleteMarker(eid, _){
  if (eid in enemy_attack_markers.value)
    enemy_attack_markers.mutate(@(v) v.$rawdelete(eid))
}

function createMarker(eid, _comp) {
  enemy_attack_markers.mutate(@(v) v[eid] <- {})
}

ecs.register_es(
  "ui_enemy_attack_markers_state",
  {
    onInit = createMarker
    onDestroy = deleteMarker
  },
  {
    comps_rq = ["enemy_attack_marker"]
  }
)

return enemy_attack_markers