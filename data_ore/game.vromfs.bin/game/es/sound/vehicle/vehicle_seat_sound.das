require ecs
require game.es.vehicle.vehicle_events
require sound_utils.modules.sound_player_common
require soundHash
require soundEvent


[es(tag=sound, REQUIRE=vehicleSoundControlEnabled)]
def vehicle_seat_sound_enter(evt : EventEnterVehicle;
                             [[shared_comp]] vehicle_seat_sound__paths : Object;
                             sound_tags : Object;
                             is_watched_sound : bool;
                             transform : float3x4)
  sound_player_common::play_path(evt.enter ? "enter" : "leave", vehicle_seat_sound__paths, sound_tags, is_watched_sound, transform[3])


[es(tag=sound, on_event=(CmdVehiclePlaceNextSeat, CmdVehiclePlaceDriverSeat, CmdVehicleChangeSeat), REQUIRE=vehicleSoundControlEnabled)]
def vehicle_seat_sound_change(evt : Event;
                              [[shared_comp]] vehicle_seat_sound__paths : Object;
                              sound_tags : Object;
                              var sound_event_group : SoundEventGroup&;
                              is_watched_sound : bool;
                              transform : float3x4)
  sound_player_common::play_path("changeSeat", vehicle_seat_sound__paths, sound_tags, is_watched_sound, transform[3], sound_hash(""), sound_event_group)
