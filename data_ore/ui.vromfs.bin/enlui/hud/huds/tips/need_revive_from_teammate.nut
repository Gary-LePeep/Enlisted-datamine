from "%enlSqGlob/ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
let {tipCmp} = require("%ui/hud/huds/tips/tipComponent.nut")

let reviveFromTeammateTip = tipCmp({
  text = loc("tips/need_revive_from_teammate")
  textColor = Color(200,40,40,110)
  transform = {pivot=[0,0.5]}
})

let needDisplayReviveFromTeamTip = Watched(false)

ecs.register_es("track_is_need_revive_from_teammate", {
  [["onChange", "onInit"]] = function(_eid, comp){
    needDisplayReviveFromTeamTip(comp.isDowned && !comp.human_inventory__canSelfRevive)
  }
   onDestroy = @(...) needDisplayReviveFromTeamTip(false)
},
{
  comps_track = [["isDowned", ecs.TYPE_BOOL]]
  comps_ro = [["human_inventory__canSelfRevive", ecs.TYPE_BOOL, true]]
  comps_rq=["watchedByPlr"]
})

return function() {
  return {
    watch = [needDisplayReviveFromTeamTip]
    size = SIZE_TO_CONTENT
    children = needDisplayReviveFromTeamTip.value ? reviveFromTeammateTip : null
  }
}
