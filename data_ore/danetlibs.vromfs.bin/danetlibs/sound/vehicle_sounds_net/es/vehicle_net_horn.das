require ecs
require app
require vehicle_sounds_net.modules.vehicle_sounds_net_events
require sound_utils_net.modules.sound_utils_net_events
require vehicle
require DngNet

let MAX_HORN_TIME = 30.


def get_player_seat(player : EntityId; seat_eids : EidList&)
  var playerSeat = INVALID_ENTITY_ID
  for seatEid in seat_eids
    query(seatEid) <| $ [es] (seat__ownerEid : EntityId; seat__ownerControls : VehicleControlsState)
      if seat__ownerControls.canControlVehicle
        query(seat__ownerEid) <| $ [es(REQUIRE_NOT=deadEntity)] (possessedByPlr : EntityId)
          if possessedByPlr == player
            playerSeat = seatEid
  return playerSeat


[es(tag=server)]
def vehicle_net_horn_request(evt : CmdVehicleHornRequest;
                             vehicle_seats__seatEids : EidList&;
                             var vehicle_horn__player : EntityId&;
                             var vehicle_horn__seat : EntityId&;
                             var vehicle_horn__endTime : float&;
                             isAlive : bool)
  if !!evt.player
    if evt.enable
      if !vehicle_horn__player && isAlive
        vehicle_horn__seat = get_player_seat(evt.player, vehicle_seats__seatEids)
        if !!vehicle_horn__seat
          vehicle_horn__player = evt.player
          vehicle_horn__endTime = get_sync_time() + MAX_HORN_TIME
    elif vehicle_horn__player == evt.player
      vehicle_horn__player = INVALID_ENTITY_ID
      vehicle_horn__seat = INVALID_ENTITY_ID
      vehicle_horn__endTime = 0.


[es(tag=server, after=sound_begin_update_es, before=sound_end_update_es)]
def vehicle_net_horn(info : ParallelUpdateFrameDelayed;
                     var vehicle_horn__endTime : float&;
                     vehicle_seats__seatEids : EidList&;
                     var vehicle_horn__player : EntityId&;
                     var vehicle_horn__seat : EntityId&;
                     isAlive : bool)
  if !!vehicle_horn__player && (!isAlive || vehicle_horn__seat != get_player_seat(vehicle_horn__player, vehicle_seats__seatEids))
    vehicle_horn__player = INVALID_ENTITY_ID
    vehicle_horn__seat = INVALID_ENTITY_ID
    vehicle_horn__endTime = 0.
