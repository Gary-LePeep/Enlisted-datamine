import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui/ui_library.nut" import *
let { watchedTable2TableOfWatched } = require("%sqstd/frp.nut")
let { mkFrameIncrementObservable } = require("%ui/ec_to_watched.nut")

let comps = freeze([
  {comp = "vehicle_view__isAutomaticTransmission", typ = ecs.TYPE_BOOL,def=false,name="isAutomaticTransmission"}
  {comp = "vehicle_view__gear",                    typ = ecs.TYPE_INT, def=0,    name="gear"}
  {comp = "vehicle_view__neutralGear",             typ = ecs.TYPE_INT, def=0,    name="neutralGear"}
  {comp = "vehicle_view__rpm",                     typ = ecs.TYPE_INT, def=0,    name="rpm"}
  {comp = "vehicle_view__cruiseControl",           typ = ecs.TYPE_INT, def=0,    name="cruiseControl"}
  {comp = "vehicle_view__speed",                   typ = ecs.TYPE_INT, def=0,    name="speed"}
])

let defValue = freeze(comps.reduce(function(res, b){
  res[b.name] <- b.def
  res.enabled <- false
  return res
} ,{}))

let { state, stateSetValue } = mkFrameIncrementObservable(defValue, "state")
let exportState = watchedTable2TableOfWatched(state)

ecs.register_es("ui_vehicle_view_state",
  {
    [["onInit","onChange"]] = function(_, comp){
      let res = {}
      comps.each(@(v) res[v.name] <- comp[v.comp])
      res.enabled <- true
      stateSetValue(res)
    }
    function onDestroy(_, __){
      stateSetValue(defValue)
    }
  },
  {
    comps_track = comps.map(@(obj) [obj.comp, obj.typ, obj.name]),
    comps_rq = ["vehicleView", "vehicleWithWatched"]
    comps_no = ["deadEntity"]
  },
  { tags="ui" }
)

return exportState