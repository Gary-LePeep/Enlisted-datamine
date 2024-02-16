require ecs
require game.utils.sound_utils

[es(tag=server, on_appear)]
def oneshot_net_sound_created(evt : Event;
                              oneshot_net_sound__onCreate : string;
                              transform : float3x4)
  play_scene_net_sound(oneshot_net_sound__onCreate, transform[3], false)

[es(tag=sound, on_disappear)]
def oneshot_net_sound_destroyed(evt : Event;
                                oneshot_net_sound__onDestroy : string;
                                transform : float3x4)
  play_scene_net_sound(oneshot_net_sound__onDestroy, transform[3], false)
