require ecs
require vehicle
require game.es.vehicle.vehicle_events
require game.es.vehicle.vehicle_seats_common


def find_first_proper_seat_no(seatEids : EidList; requiredRoomSpace : int; soldier_eid : EntityId)
  var res = -1
  for orderSeatEid in seatEids
    query(orderSeatEid) <| $ [es] (seats_order__seatNo : int;
                                   seat__vehicleEid : EntityId;
                                   seats_order__canPlaceManually : bool;
                                   seats_order__canPlaceOnlyOwner : bool = false;
                                   seat__roomSpace : int = -1)
      if !seats_order__canPlaceManually
        return
      let seatNo = seats_order__seatNo
      let seatEid = seatEids[seatNo]
      if seats_order__canPlaceOnlyOwner
        let vehicleOwnedSquad = get_Eid(seat__vehicleEid, "ownedBySquad") ?? INVALID_ENTITY_ID
        let soldierSquad = get_Eid(soldier_eid, "squad_member__squad") ?? INVALID_ENTITY_ID
        if vehicleOwnedSquad != soldierSquad
          return
      let ownerEid = get_Eid(seatEid, "seat__ownerEid") ?? INVALID_ENTITY_ID
      let isPlayer = get_bool(seatEid, "seat__isPlayer") ?? false
      if (seat__roomSpace == requiredRoomSpace || seat__roomSpace < 0 || requiredRoomSpace < 0) && (ownerEid == INVALID_ENTITY_ID || !isPlayer)
        res = seatNo
    if res >= 0
      return res
  return res

[es(tag=server, on_appear, on_event=EventOnSeatOwnersChanged)]
def validate_vehicle_seat_owners(evt : Event; eid : ecs::EntityId; vehicle_seats__seatEids : EidList)
  for seatNo, seatEid in iter_range(vehicle_seats__seatEids), vehicle_seats__seatEids
    query(seatEid) <| $ [es] (seat__ownerEid : EntityId; seat__isPlayer : bool; seat__orderNo : int; seat__roomSpace : int = -1)
      let canPlaceManually = get_bool(vehicle_seats__seatEids[seat__orderNo], "seats_order__canPlaceManually") ?? false
      if !!seat__ownerEid && seat__isPlayer && !canPlaceManually
        let properSeatNo = find_first_proper_seat_no(vehicle_seats__seatEids, seat__roomSpace, seat__ownerEid)
        if properSeatNo >= 0
          sendEventImmediate(eid, [[CmdVehicleSwapSeats seatNo1=seatNo, seatNo2=properSeatNo]])
