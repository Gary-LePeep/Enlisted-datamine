require app
require ecs
require game.utils.sound_utils
require strings


[es(on_appear, tag=server)]
def create_user_point_sound(evt : Event;
                            userPointOwner : EntityId;
                            userPointType : string;
                            silentAppearance : bool;
                            transform : float3x4)
  if !empty(userPointType) && !silentAppearance
    query(userPointOwner) <| $ [es] (possessed : EntityId)
      play_net_sound_pos_to_team(possessed, "uiMap_{userPointType}", transform[3])
