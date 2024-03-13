import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui/ui_library.nut" import *

let { mkFrameIncrementObservable } = require("%ui/ec_to_watched.nut")

let repairKitsDefValue = 0
let { repairKits, repairKitsSetValue } = mkFrameIncrementObservable(repairKitsDefValue, "repairKits")

ecs.register_es("total_repairkits_ui",{
  [["onChange", "onInit"]] = @(_, _eid, comp) repairKitsSetValue(comp.total_kits__targetRepair),
  onDestroy = @(...) repairKitsSetValue(repairKitsDefValue)
}, {
  comps_track=[["total_kits__targetRepair", ecs.TYPE_INT]],
  comps_rq=["watchedByPlr"]
})

return {repairKits}
