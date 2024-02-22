require ecs
require math.base
require DngCamera
require soundSystem
require sound_utils_net.modules.sound_utils_net_events

/*
[es(tag=sound, REQUIRE=msg_sink)]
def sound_begin_update_es(info : ParallelUpdateFrameDelayed)
  let listenerTm = get_cur_cam_entity() |> get_TMatrix("transform") ?? IDENT_TM
  if listenerTm == IDENT_TM
    sound_reset_3d_listener()
  sound_update_listener(info.dt, listenerTm)

  +sndsys::set_time_speed(get_timespeed());
  +sndsys::begin_update(info.dt));
*/

[es(tag=sound, after=sound_begin_update_es, REQUIRE=msg_sink)]
def sound_end_update_es(info : ParallelUpdateFrameDelayed)
  sound_update(info.dt)
