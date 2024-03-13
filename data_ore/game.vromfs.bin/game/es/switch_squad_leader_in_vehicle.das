require ecs
require DngNet
require enlisted.events_enlisted
require game.es.vehicle.vehicle_events
require game.es.vehicle.vehicle_seats_common
require player

[es(tag=gameClient)]
def vehicle_change_leader_requester(evt : CmdVehiclePlaceSeat; vehicle_seats__seatEids : EidList)
  let sitterEid = evt.eid
  let seatOrderNo = evt.seat
  if uint(seatOrderNo) >= uint(length(vehicle_seats__seatEids))
    return
  let seatNo = get_int(vehicle_seats__seatEids[seatOrderNo], "seats_order__seatNo") ?? -1
  if uint(seatNo) >= uint(length(vehicle_seats__seatEids))
    return
  let seatEid = vehicle_seats__seatEids[seatNo]
  let ownerEid = get_Eid(seatEid, "seat__ownerEid") ?? INVALID_ENTITY_ID
  let playerEid = get_Eid(seatEid, "seat__playerEid") ?? INVALID_ENTITY_ID
  if (playerEid == (get_Eid(sitterEid, "possessedByPlr") ?? INVALID_ENTITY_ID) && (get_bool(ownerEid, "isAlive") ?? false))
    let squadEid = get_Eid(sitterEid, "squad_member__squad") ?? INVALID_ENTITY_ID
    send_net_event(squadEid, [[RequestSquadChangeLeader eid=ownerEid]])

def get_next_soldier_in_plane(soldier, vehicle_seats__seatEids)
  let sitterPlayer = (get_Eid(soldier, "possessedByPlr") ?? INVALID_ENTITY_ID)
  let curSeatNo = find_seat_with_owner(soldier, vehicle_seats__seatEids)
  let seatsCount = length(vehicle_seats__seatEids)
  for seatNo in range(seatsCount)
    let seatNoFromCur = (seatNo + curSeatNo + 1) % seatsCount
    let seatEid = vehicle_seats__seatEids[seatNoFromCur]
    if !(get_bool(seatEid, "seats_order__canPlaceManually") ?? false)
      continue
    let ownerEid = get_Eid(seatEid, "seat__ownerEid") ?? INVALID_ENTITY_ID
    let playerEid = get_Eid(seatEid, "seat__playerEid") ?? INVALID_ENTITY_ID
    if (playerEid == sitterPlayer && (get_bool(ownerEid, "isAlive") ?? false))
      return ownerEid
  return INVALID_ENTITY_ID

[es(tag=gameClient)]
def vehicle_change_soldier_in_plane_requester(evt : CmdPlanePlaceNextSeat; vehicle_seats__seatEids : EidList)
  let sitterEid = evt.eid
  let nextSoldier = get_next_soldier_in_plane(sitterEid, vehicle_seats__seatEids)
  if nextSoldier != sitterEid && nextSoldier != INVALID_ENTITY_ID
    let squadEid = get_Eid(sitterEid, "squad_member__squad") ?? INVALID_ENTITY_ID
    send_net_event(squadEid, [[RequestSquadChangeLeader eid=nextSoldier]])
    return

[es(tag=gameClient, REQUIRE=heroVehicle)]
def plane_next_seat_found_on_seats_change(evt : EventOnSeatOwnersChanged;
                                          vehicle_seats__seatEids : EidList;
                                          var plane__seatNext : int&)
  let soldierLoc = get_Eid(get_local_player_eid(), "possessed") ?? INVALID_ENTITY_ID
  let nextSoldier = get_next_soldier_in_plane(soldierLoc, vehicle_seats__seatEids)
  if nextSoldier != INVALID_ENTITY_ID
    plane__seatNext = find_seat_with_owner(nextSoldier, vehicle_seats__seatEids)


[es(tag=server, before=vehicle_seats_stop_switch_timer_if_occupied)]
def vehicle_seats_switch_timer_replace_squad_mate(evt : EventEnterVehicle; vehicle_seats__seatEids : EidList)
  if !evt.enter
    return
  let incomerIndex = find_seat_with_owner(evt.incomer, vehicle_seats__seatEids)
  if incomerIndex < 0
    return
  let incomerSeatOwnerEid = get_Eid(vehicle_seats__seatEids[incomerIndex], "seat__ownerEid") ?? INVALID_ENTITY_ID
  let incomerSeatPlayerEid = get_Eid(vehicle_seats__seatEids[incomerIndex], "seat__playerEid") ?? INVALID_ENTITY_ID
  for seatEid in vehicle_seats__seatEids
    query(seatEid) <| $ [es] (seat__ownerEid : EntityId; seats_switch_time__newSeatNo : int)
      if seats_switch_time__newSeatNo != incomerIndex
        return
      let awaitingChangeEid = seat__ownerEid
      if incomerSeatPlayerEid == (get_Eid(awaitingChangeEid, "possessedByPlr") ?? INVALID_ENTITY_ID)
        let squadEid = get_Eid(awaitingChangeEid, "squad_member__squad") ?? INVALID_ENTITY_ID
        sendEvent(squadEid, [[CmdSwitchSquadLeader eid=incomerSeatOwnerEid]])