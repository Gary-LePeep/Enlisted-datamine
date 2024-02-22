import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui/ui_library.nut" import *

let {get_sync_time} = require("net")

let { watchedTable2TableOfWatched } = require("%sqstd/frp.nut")
let { mkFrameIncrementObservable } = require("%ui/ec_to_watched.nut")
let defValue = freeze({
  isExtinguishing = false
  isRepairing = false
  maintenanceTime = 0.0
  maintenanceTotalTime = 0.0
  vehicleRepairTime = 0.0
  isRepairRequired = false
  isExtinguishRequired = false
  hasRepairKit = false
  hasExtinguisher = false
  canMaintainVehicle = false
})

let { state, stateSetValue } = mkFrameIncrementObservable(defValue, "state")
let exportState = watchedTable2TableOfWatched(state)


let maintenanceTargetQuery = ecs.SqQuery("maintenanceTargetQuery", {
  comps_ro = [
    ["repairable__repairTotalTime", ecs.TYPE_FLOAT, -1.0],
    ["repairable__repairTime", ecs.TYPE_FLOAT, -1.0],
    ["extinguishable__extinguishTotalTime", ecs.TYPE_FLOAT, -1.0],
    ["extinguishable__extinguishTime", ecs.TYPE_FLOAT, -1.0],
    ["extinguishable__inProgress", ecs.TYPE_BOOL, false],
    ["repairable__inProgress", ecs.TYPE_BOOL, false],
  ]
})
ecs.register_es("ui_maintenance_es",
  {
    [["onChange", "onInit"]] = function (_eid, comp) {
      let isHeroExtinguishing = comp["extinguisher__active"]
      let isHeroRepairing = comp["repair__active"]
      let mntTgtEid = comp["maintenance__target"]
      let res = {
        isExtinguishing = isHeroExtinguishing
        isRepairing = isHeroRepairing
        hasRepairKit = comp.repair__hasRepairKit
        hasExtinguisher = comp.extinguisher__hasExtinguisher
        canMaintainVehicle = comp.maintenance__canMaintainVehicle
        isRepairRequired = false
        isExtinguishRequired = false
        vehicleRepairTime = 0.0
        maintenanceTime = 0.0
        maintenanceTotalTime = 0.0
      }
      if (mntTgtEid != ecs.INVALID_ENTITY_ID) {
        res.isRepairRequired <- comp.maintenance__targetNeedsRepair
        res.isExtinguishRequired <- comp.maintenance__targetNeedsExtinguishing
        maintenanceTargetQuery.perform(mntTgtEid, function(_eid, mntTgtComp){
          res.vehicleRepairTime <- ((mntTgtComp["repairable__inProgress"] && isHeroRepairing) ? mntTgtComp["repairable__repairTime"] : null)
          if (mntTgtComp["extinguishable__inProgress"] && isHeroExtinguishing) {
            res.maintenanceTime <- mntTgtComp["extinguishable__extinguishTime"] + get_sync_time()
            res.maintenanceTotalTime <- mntTgtComp["extinguishable__extinguishTotalTime"]
          }
          else if (mntTgtComp["repairable__inProgress"] && isHeroRepairing) {
            res.maintenanceTime <- mntTgtComp["repairable__repairTime"] + get_sync_time()
            res.maintenanceTotalTime <- mntTgtComp["repairable__repairTotalTime"]
          }
          else {
            res.maintenanceTime <- 0.0
            res.maintenanceTotalTime <- 0.0
          }
        })
      }
      stateSetValue(res)
    },
    function onDestroy(...){
      stateSetValue(defValue)
    }
  },
  {
    comps_track = [
      ["maintenance__target", ecs.TYPE_EID],
      ["extinguisher__active", ecs.TYPE_BOOL, false],
      ["repair__active", ecs.TYPE_BOOL, false],
      ["repair__hasRepairKit", ecs.TYPE_BOOL, false],
      ["extinguisher__hasExtinguisher", ecs.TYPE_BOOL, false],
      ["maintenance__canMaintainVehicle", ecs.TYPE_BOOL, false],
      ["maintenance__targetNeedsRepair", ecs.TYPE_BOOL, false],
      ["maintenance__targetNeedsExtinguishing", ecs.TYPE_BOOL, false],
    ],
    comps_rq=["watchedByPlr"]
  }
)

return exportState