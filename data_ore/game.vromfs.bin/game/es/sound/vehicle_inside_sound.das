require ecs
require ecs.common
require ecs.safe
require player
require vehicle
require soundEvent
require game.utils.hero
require DagorSystem


def enable_for_vehicle(vehicle_inside_sound__enableForSeats : StringList;
                       enable_if_commander_camera_type : bool;
                       vehicle_camera_type : int;
                       [[shared_comp]] vehicle_seats__seats : Array;
                       vehicle_seats__seatEids : EidList)

  if enable_if_commander_camera_type || vehicle_camera_type != int(VehicleCameraType VEHICLE_CAMERA_COMMANDER)
    if empty(vehicle_inside_sound__enableForSeats)
      return true

    let hero = get_controlled_hero()
    var enable = false
    for i in iter_range(vehicle_seats__seatEids)
      let seatEid = vehicle_seats__seatEids[i]
      query(seatEid) <| $ [es] (seat__ownerEid : EntityId)
        if seat__ownerEid == hero
          let seatName = get_ecs_object(vehicle_seats__seats[i])?.name ?? ""
          enable = find_index(vehicle_inside_sound__enableForSeats, seatName) >= 0
    return enable

  return false


[es(tag=sound, on_appear, track=(is_watched_sound, vehicleCameraType, sound_banks_state__isPresetLoaded), on_event=EventOnSeatOwnersChanged)]
def vehicle_inside_sound_toggle(evt : Event;
                                is_watched_sound : bool;
                                sound_banks_state__isPresetLoaded : bool;

                                [[shared_comp]] vehicle_inside_sound__enableForSeats : StringList;
                                vehicle_inside_sound__enableIfCommanderCameraType : bool;
                                vehicleCameraType = int(VehicleCameraType VEHICLE_CAMERA_NONE);

                                [[shared_comp]] vehicle_seats__seats : Array;
                                vehicle_seats__seatEids : EidList;

                                vehicle_inside_sound__path : string;
                                var vehicle_inside_sound__event : SoundEvent&)

  let enableForVehicle = sound_banks_state__isPresetLoaded && is_watched_sound && enable_for_vehicle(vehicle_inside_sound__enableForSeats,
                                                                                                     vehicle_inside_sound__enableIfCommanderCameraType,
                                                                                                     vehicleCameraType,
                                                                                                     vehicle_seats__seats,
                                                                                                     vehicle_seats__seatEids)
  let enable = enableForVehicle// && enable_for_camera()

/*
  if is_watched_sound
    var curSeatName = ""
    for i in iter_range(vehicle_seats__seatEids)
      query(vehicle_seats__seatEids[i]) <| $ [es] (seat__ownerEid : EntityId)
        if seat__ownerEid == get_controlled_hero()
          curSeatName = get_ecs_object(vehicle_seats__seats[i])?.name ?? ""
    logerr("__{enable}__ curSeatName={curSeatName} vehicleCameraType={vehicleCameraType} enableForSeats={vehicle_inside_sound__enableForSeats} enableIfCommanderCameraType={vehicle_inside_sound__enableIfCommanderCameraType}")
*/

  if vehicle_inside_sound__event.enabled != enable
    vehicle_inside_sound__event.enabled = enable
    if vehicle_inside_sound__event.enabled
      vehicle_inside_sound__event |> play(vehicle_inside_sound__path)
    else
      if sound_banks_state__isPresetLoaded
        abandon(vehicle_inside_sound__event.handle)
      else
        release(vehicle_inside_sound__event.handle)


[es(tag=sound, REQUIRE=(vehicleInsideSnapshot3d, vehicleWithWatched), on_event=ParallelUpdateFrameDelayed, after=sound_begin_update_es, before=sound_end_update_es)]
def vehicle_inside_sound_update(evt : Event;
                                vehicle_inside_sound__event : SoundEvent;
                                transform : float3x4)
  set_pos(vehicle_inside_sound__event.handle, transform[3])
