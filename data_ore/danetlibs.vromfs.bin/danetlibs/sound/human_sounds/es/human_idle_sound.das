require ecs
require soundEvent
require sound_utils.modules.sound_player_common
require sound_utils_net.modules.sound_utils_net_events
require HumanPhys
require DagorSystem


[es(tag=sound, track=(human_net_phys__curMoveState, sleep_mode__isActivated), on_appear)]
def human_idle_sound_is_idle(evt : Event;
                             var human_idle_sound__isActive : bool&;
                             human_net_phys__curMoveState : int = int(HUMoveState EMS_SPRINT);
                             sleep_mode__isActivated : bool = true)
  human_idle_sound__isActive = sleep_mode__isActivated && (human_net_phys__curMoveState == int(HUMoveState EMS_SPRINT) ||
                                                           human_net_phys__curMoveState == int(HUMoveState EMS_RUN))


[es(tag=sound, REQUIRE=humanIdleSound, track=(human_idle_sound__isActive, sound_control__soundEnabled, isAlive), on_appear)]
def human_idle_sound(evt : Event;
                     sound_control__soundEnabled : bool;
                     human_idle_sound__isActive : bool = false;
                     sound_tags : Object;
                     [[shared_comp]] human_idle_sound__paths : Object;
                     var human_idle_sound__event : SoundEvent&;
                     is_watched_sound : bool;
                     transform : float3x4;
                     isAlive : bool)
  abandon(human_idle_sound__event.handle)
  if sound_control__soundEnabled && isAlive
    let path = human_idle_sound__isActive ? "activeState" : "idleState"
    human_idle_sound__event.handle = sound_player_common::play_path(path, human_idle_sound__paths, sound_tags, is_watched_sound, transform[3], false)



[es(tag=sound, after=sound_begin_update_es, before=sound_end_update_es)]
def human_idle_sound_update(evt : ParallelUpdateFrameDelayed;
                            human_idle_sound__event : SoundEvent;
                            human_idle_sound__stealableGroupIdx : int;
                            transform : float3x4)
  if human_idle_sound__event.handle != invalid_sound_event_handle()
    set_pos(human_idle_sound__event.handle, transform[3])
    if human_idle_sound__stealableGroupIdx >= 0
      update_event_instance_stealing(human_idle_sound__event.handle, human_idle_sound__stealableGroupIdx, evt.dt)


[es(tag=sound, on_appear)]
def stealable_human_idle_sound_appear(evt : Event;
                                      var human_idle_sound__stealableGroupIdx : int&;
                                      human_idle_sound__stealableGroupName : string;
                                      human_idle_sound__stealableTargetInstances : int;
                                      human_idle_sound__stealableFadeInOutSpeed : float)
  human_idle_sound__stealableGroupIdx = create_event_instance_stealing_group(human_idle_sound__stealableGroupName, human_idle_sound__stealableTargetInstances, human_idle_sound__stealableFadeInOutSpeed)
  if human_idle_sound__stealableGroupIdx == -1
    logerr("human_idle_sound__stealableGroupIdx for group '{human_idle_sound__stealableGroupName}' is not valid")
