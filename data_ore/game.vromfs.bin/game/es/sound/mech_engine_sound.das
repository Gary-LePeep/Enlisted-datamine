require ecs
require soundEvent
require sound_utils.modules.sound_player_common
require sound_utils_net.modules.sound_utils_net_events
require DagorMath
require mech


[es(tag=sound, track=is_watched_sound, on_appear, REQUIRE=(walker_net_phys, vehicleSoundControlEnabled))]
def mech_engine_sound_toggle(evt : Event;
                             [[shared_comp]] mech_engine_sound__path : Object;
                             var mech_engine_sound__event : SoundEvent&;
                             is_watched_sound : bool;
                             transform : float3x4;
                             sound_tags : Object)
  abandon(mech_engine_sound__event.handle)
  mech_engine_sound__event.handle = sound_player_common::play_path(mech_engine_sound__path, sound_tags, is_watched_sound, transform[3], false)


[es(tag=sound, after=sound_begin_update_es, before=sound_end_update_es, REQUIRE=vehicleSoundControlEnabled)]
def mech_engine_sound_update(evt : ParallelUpdateFrameDelayed;
                             mech_engine_sound__event : SoundEvent;
                             var mech_engine_sound__throttle : float&;
                             walker_net_phys : WalkerPhysActor;
                             transform : float3x4)
  if mech_engine_sound__event.handle != invalid_sound_event_handle()
    set_pos(mech_engine_sound__event.handle, transform[3])
    set_var(mech_engine_sound__event.handle, "speed", length(walker_net_phys.phys.currentState.velocity))
    set_var(mech_engine_sound__event.handle, "broken", walker_net_phys.phys.currentState.damageState.readyness > 0. ? 0. : 1.)
    set_var(mech_engine_sound__event.handle, "load", safediv(walker_net_phys.phys.currentState.throttle - mech_engine_sound__throttle, evt.dt))
    mech_engine_sound__throttle = walker_net_phys.phys.currentState.throttle
