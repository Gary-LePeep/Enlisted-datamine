from "%enlSqGlob/ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let {tipCmp} = require("%ui/hud/huds/tips/tipComponent.nut")
let { isOwnerInMobileRespawn } = require("%ui/hud/state/vehicle_state.nut")

let isMobileRespawnCloseToCapzone = Watched(false)

let isMobileRespawnCloseToCapzoneTip = tipCmp({
  text = loc("tips/mobileSpawnCloseToCapzone")
  textColor = Color(200,40,40,110)
})

ecs.register_es("track_mobile_respawn_close_to_capture_points",
  {
    [[ "onInit", "onChange" ]] = function onChange(_evt, _eid, comp) {
      isMobileRespawnCloseToCapzone(comp.human_vehicle__isMobileSpawnDriverCloseToCapturePoint)
    },
    onDestroy = @(_eid, _comp) isMobileRespawnCloseToCapzone(false)
  },
  {
    comps_rq = ["hero"],
    comps_track = [["human_vehicle__isMobileSpawnDriverCloseToCapturePoint", ecs.TYPE_BOOL]],
  }
)

return @() {
  watch = [isMobileRespawnCloseToCapzone, isOwnerInMobileRespawn]
  size = SIZE_TO_CONTENT
  children = (isMobileRespawnCloseToCapzone.value && isOwnerInMobileRespawn.value) ? isMobileRespawnCloseToCapzoneTip : null
}
