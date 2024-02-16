require ecs
require math.base
require DagorMath
require vehicle
require soundEvent
require soundHash
require sound_utils.modules.sound_player_common
require sound_utils_net.modules.sound_utils_net_events


[es(tag=sound, after=ground_vehicle_sound_update_vars)]
def ground_vehicle_brakes_sound(info : ParallelUpdateFrameDelayed;
                                sound_control__shouldPlay : bool;
                                vehicle_net_phys : VehiclePhysActor;
                                vehicle_sound_vars__isOnGround : bool;
                                var ground_vehicle_brakes_sound__brakes : float&;
                                ground_vehicle_brakes_sound__brakesStart : float;
                                ground_vehicle_brakes_sound__speedFadeInOut : float2;
                                var sound_event_group : SoundEventGroup&;
                                is_watched_sound : bool;
                                [[shared_comp]] ground_vehicle_brakes_sound__path : Object;
                                sound_tags : Object;
                                transform : float3x4)

  assume currentState = vehicle_net_phys.phys.currentState
  let speed = abs(dot(float3(currentState.velocity), transform[0]))
  let speedFadeIn = cvt(speed, 0., ground_vehicle_brakes_sound__speedFadeInOut.x, 0., 1.)
  let speedFadeOut = cvt(speed, ground_vehicle_brakes_sound__speedFadeInOut.x, ground_vehicle_brakes_sound__speedFadeInOut.y, 1., 0.)

  let brakes = vehicle_sound_vars__isOnGround ? saturate(max(abs(currentState.leftSteeringBrake), abs(currentState.rightSteeringBrake))) : 0.
  ground_vehicle_brakes_sound__brakes = max(max(ground_vehicle_brakes_sound__brakes - info.dt, 0.), brakes * speedFadeOut * speedFadeIn)

  if ground_vehicle_brakes_sound__brakes > ground_vehicle_brakes_sound__brakesStart && sound_control__shouldPlay && is_watched_sound
    if !is_playing(get_sound(sound_event_group, sound_hash("brakes")))
      sound_player_common::play_path(ground_vehicle_brakes_sound__path, sound_tags, is_watched_sound, transform[3], sound_hash("brakes"), sound_event_group)
    let handle = get_sound(sound_event_group, sound_hash("brakes"))
    set_var(handle, "brakes", ground_vehicle_brakes_sound__brakes)
  else
    reject_sound(sound_event_group, sound_hash("brakes"))
