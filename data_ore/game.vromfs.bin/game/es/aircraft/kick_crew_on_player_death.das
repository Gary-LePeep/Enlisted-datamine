require ecs
require game.events_game
require game.es.vehicle.vehicle_events

[es(tag=server)]
def kick_crew_on_player_death(evt : EventEntityDied; eid aka killed_soldier_eid : EntityId;
                              possessedByPlr, human_anim__vehicleSelected, human_vehicle__occupiedSeatEid : EntityId)
  if !possessedByPlr || !has(human_vehicle__occupiedSeatEid, "seat__kickCrewOnPlayerDeath")
    return
  query(human_anim__vehicleSelected) <| $ [es] (vehicle_seats__seatEids : EidList;
                                                deadIfNoCrewLeft : Tag const?;
                                                var isAlive : bool&)
    for seatEid in vehicle_seats__seatEids
      query(seatEid) <| $ [es] (seat__ownerEid : EntityId)
        if seat__ownerEid != killed_soldier_eid && !has(seat__ownerEid, "deadEntity")
          sendEvent(human_anim__vehicleSelected, [[CmdKickFromVehicle eid=seat__ownerEid]])
    if deadIfNoCrewLeft != null
      isAlive = false
