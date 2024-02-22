require ecs
require game.utils.sound_utils


[es(tag=server, on_appear, REQUIRE_NOT=sceneSoundSource)]
def oneshot_net_sound_appear(evt : Event;
                             eid : EntityId;
                             oneshot_net_sound__onAppear : string)
  play_net_sound(eid, oneshot_net_sound__onAppear)


[es(tag=server, on_disappear, REQUIRE_NOT=sceneSoundSource)]
def oneshot_net_sound_disappear(evt : Event;
                                eid : EntityId;
                                oneshot_net_sound__onDisappear : string)
  play_net_sound(eid, oneshot_net_sound__onDisappear)


[es(tag=server, on_appear, REQUIRE=sceneSoundSource)]
def oneshot_scene_net_sound_appear(evt : Event;
                                   oneshot_net_sound__onAppear : string;
                                   transform : float3x4)
  play_scene_net_sound(oneshot_net_sound__onAppear, transform[3], false)


[es(tag=server, on_disappear, REQUIRE=sceneSoundSource)]
def oneshot_scene_net_sound_disappear(evt : Event;
                                      oneshot_net_sound__onDisappear : string;
                                      transform : float3x4)
  play_scene_net_sound(oneshot_net_sound__onDisappear, transform[3], false)
