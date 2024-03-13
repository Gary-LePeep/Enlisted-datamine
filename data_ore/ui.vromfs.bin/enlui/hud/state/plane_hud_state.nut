import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui/ui_library.nut" import *

let showFuel = Watched(false)
let showFuelIfLessPct = Watched(10.0)
let planeSeatNext = Watched(-1)

function checkFuelLevel(_evt, _eid, comp) {
  let fuelPct = comp["plane_view__fuel_pct"]
  let isLeaking = comp["plane_view__fuel_leak"]
  showFuel(isLeaking || fuelPct < showFuelIfLessPct.value)
}

ecs.register_es("plane_next_seat_es", {
  onChange = function(_eid, comps) {
    planeSeatNext(comps.plane__seatNext) }
  onDestroy = @() planeSeatNext(-1)
},
{
  comps_rq = ["heroVehicle"],
  comps_track = [["plane__seatNext", ecs.TYPE_INT]]
})

ecs.register_es("plane_fuel_es", {
  onUpdate = checkFuelLevel
},
{
  comps_ro = [
    ["plane_view__fuel_pct", ecs.TYPE_FLOAT],
    ["plane_view__fuel_leak", ecs.TYPE_BOOL],
  ],
  comps_rq = ["vehicleWithWatched"]
},
{ updateInterval=5.0, tags="ui", after="*", before="*" })

return {showFuel, planeSeatNext}