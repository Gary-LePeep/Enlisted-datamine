require app
require ecs
require game.utils.sound_utils
require strings


[es(on_appear, tag=server)]
def build_sound(evt : Event;
                buildSoundTag : string;
                buildByEngineerEid : EntityId;
                transform : float3x4)
  if !empty(buildSoundTag) && buildByEngineerEid != INVALID_ENTITY_ID
    play_net_sound_pos(buildByEngineerEid, "createBuilding_{buildSoundTag}", transform[3])
