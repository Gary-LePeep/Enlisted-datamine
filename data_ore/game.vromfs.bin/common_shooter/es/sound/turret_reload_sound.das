require ecs
require soundEvent
require math.base
require Gun
require common_shooter.es.sound.gun_sound_common
require sound_utils_net.modules.sound_utils_net_events


[es(tag=sound)]
def turret_reload_sound_progress(info : ParallelUpdateFrameDelayed;
                                 turret__isBroken : bool;
                                 ui_turret_reload_progress__finishTime : float;
                                 ui_turret_reload_progress__progressStopped : float;
                                 gun__owner : EntityId;
                                 gun_reload_sound__progressPath : string;
                                 gun_reload_sound__readyPath : string;
                                 gun_reload_sound__readyTimeOffset : float;
                                 var gun_reload_sound__event : SoundEvent&)
  let isReloadStopped = ui_turret_reload_progress__progressStopped >= 0.
  let isReloading = ui_turret_reload_progress__finishTime > 0. && !isReloadStopped && !turret__isBroken && is_watched_gun_sound(gun__owner)
  let isReloadingProgress = isReloading && info.curTime < ui_turret_reload_progress__finishTime - gun_reload_sound__readyTimeOffset

  if gun_reload_sound__event.enabled != isReloadingProgress
    gun_reload_sound__event.enabled = isReloadingProgress
    release(gun_reload_sound__event.handle)
    if gun_reload_sound__event.enabled
      gun_reload_sound__event |> play(gun_reload_sound__progressPath)

    if !isReloadingProgress && isReloading
      oneshot(gun_reload_sound__readyPath)


[es(tag=sound)]
def gun_ready_to_shoot_sound(info : ParallelUpdateFrameDelayed;
                             gun : Gun;
                             gun__owner : EntityId;
                             gun__timeBetweenShots : float;
                             gun_ready_to_shoot_sound__duration : float;
                             gun_ready_to_shoot_sound__minTimeBetweenShots : float;
                             gun_ready_to_shoot_sound__path : string)
  if info.curTime + gun_ready_to_shoot_sound__duration >= gun.curState.nextShotAtTime && info.curTime + gun_ready_to_shoot_sound__duration - info.dt < gun.curState.nextShotAtTime && gun.curState.nextShotAtTime > 0.
    if gun__timeBetweenShots >= gun_ready_to_shoot_sound__minTimeBetweenShots
      if is_watched_gun_sound(gun__owner)
        oneshot(gun_ready_to_shoot_sound__path)
