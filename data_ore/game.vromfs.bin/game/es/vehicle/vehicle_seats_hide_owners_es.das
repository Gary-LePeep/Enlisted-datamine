require ecs
require ecs.common
require vehicle
require PhysVars
require game.utils.hero
require game.es.vehicle.vehicle_seats_common
require enlisted.events_enlisted
require ecs.safe

[es(on_appear)]
def vehicle_seats_hide_owner_init_es(evt : Event;
                                     [[shared_comp]] vehicle_seats__seats : Array;
                                     var vehicle_seats_hide_owner : BoolList)
  let seatsCount = length(vehicle_seats__seats)
  resize(vehicle_seats_hide_owner, seatsCount)
  for seatNo in range(0, seatsCount)
    let seat = get_ecs_object(vehicle_seats__seats[seatNo])
    vehicle_seats_hide_owner[seatNo] = get_bool(seat, "shouldHideOwner") ?? false


[es(tag=server, REQUIRE=isInVehicle, after=vehicle_seats_hatch_es)]
def vehicle_seats_hide_owners_es(info : ParallelUpdateFrameDelayed;
                                 eid : EntityId;
                                 human_anim__vehicleSelected : EntityId;
                                 var isInVehicleHidden : bool&)
  ecs::query(human_anim__vehicleSelected) <| $ [es] (vehicle_seats__seatEids : EidList;
                                                     vehicle_seats_hide_owner : BoolList;
                                                     isCrewHiddenByTurret : bool = false)
    let seatNo = find_seat_with_owner(eid, vehicle_seats__seatEids)
    if seatNo < 0
      return

    query(vehicle_seats__seatEids[seatNo]) <| $ [es] (seats_hatch_nodes__isValid : bool = false; seats_hatch_nodes__openPos : float = 0.f; seat__isPlayer : bool = false)
      let hasHatch = seats_hatch_nodes__isValid
      let isHatchClosed = hasHatch && seats_hatch_nodes__openPos <= 0.f
      let isPlayer = seat__isPlayer
      let canHide = !isPlayer || !hasHatch || isHatchClosed
      isInVehicleHidden = canHide && (vehicle_seats_hide_owner[seatNo] || isCrewHiddenByTurret)

[es(tag=render, REQUIRE=hero, on_appear, track=vehicleCameraType)]
def vehicle_seats_hide_owners_local(evt : Event;
                                    eid : EntityId;
                                    vehicleCameraType : int;
                                    human_anim__vehicleSelected : EntityId;
                                    var isInVehicleHiddenLocal : bool&)
  isInVehicleHiddenLocal = false
  if (vehicleCameraType == int(VehicleCameraType VEHICLE_CAMERA_COMMANDER) ||
      vehicleCameraType == int(VehicleCameraType VEHICLE_CAMERA_DEAD))
    return
  query(human_anim__vehicleSelected) <| $ [es] (vehicle_seats__seatEids : EidList; [[shared_comp]] vehicle_seats__seats : Array)
    let seatNo = find_seat_with_owner(eid, vehicle_seats__seatEids)
    if seatNo < 0
      return

    isInVehicleHiddenLocal = (vehicle_seats__seats?[seatNo] ?as Object)?.hideHeroAnimcharLocal ?? false

[es(tag=render, REQUIRE=hero, on_disappear)]
def vehicle_seats_show_owners_local_on_disapper(evt : Event; var isInVehicleHiddenLocal : bool&)
  isInVehicleHiddenLocal = false

[es(tag=server)]
def hide_soldiers_in_tank_with_rotated_hatch(info : ParallelUpdateFrameDelayed;
                                             turret__curPitchVarId : int;
                                             turret__owner : EntityId;
                                             turret__minPitchForHideCrew : float)
  query(turret__owner) <| $ [es] (phys_vars : PhysVars; var isCrewHiddenByTurret : bool&)
    if turret__curPitchVarId >= 0
      isCrewHiddenByTurret = getVar(phys_vars, turret__curPitchVarId) > turret__minPitchForHideCrew
