require ecs
require game.events_game

[es(tag=gameClient, REQUIRE=camera__target)]
def shooter_cam_on_target_change(evt : CmdSetCameraTarget;
                                 shooter_cam__tauOnChange : float;
                                 camera__target : EntityId;
                                 var shooter_cam__tauInc : float&)
  query(evt.target) <| $ [es] (isInVehicle : bool; var human_cam__offsetMult : float&)
    if shooter_cam__tauOnChange > 0.0f && camera__target != evt.target
      shooter_cam__tauInc = shooter_cam__tauOnChange
      if isInVehicle
        human_cam__offsetMult = 0.0f