require ecs
require game.es.sound_net.sound_net_events
require game.utils.sound_utils


[es(tag=server, REQUIRE=net_sound__descs)]
def on_request_play_net_sound_pos(cmd : CmdRequestPlayNetSoundPos;
                                  eid : EntityId)
  play_net_sound_pos(eid, cmd.name, cmd.pos)


[es(tag=server, REQUIRE=net_sound__descs)]
def on_request_play_net_sound_pos_to_target(cmd : CmdRequestPlayNetSoundPosToTarget;
                                            eid : EntityId)
  play_net_sound_pos_to_target(eid, cmd.name, cmd.pos)


[es(tag=server, REQUIRE=net_sound__descs)]
def on_request_play_net_sound(cmd : CmdRequestPlayNetSound;
                              eid : EntityId)
  play_net_sound(eid, cmd.name)
