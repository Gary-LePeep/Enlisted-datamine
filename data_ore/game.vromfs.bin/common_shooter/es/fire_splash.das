require ecs
require common_shooter.events_common_shooter
require DaWeapons

[es(tag=server, REQUIRE=shell__burnAffectedEntities, REQUIRE_NOT=launch_desc)]
def fire_splash_on_shell_explode(evt : EventShellExplodedServer;
                                 shell__gun_props_id : int;
                                 shell__shell_id__shell_id : int;
                                 shell__owner : EntityId;
                                 shell__affectedEntities : EidList)
  for target in shell__affectedEntities
    query(target) <| $ [es] (burning__maxForce : float;
                             var burning__isBurning : bool&;
                             var burning__force : float&;
                             var burning__offender : EntityId&;
                             var burning__offenderShellId : int&;
                             var burning__offenderGunPropsId : int&)
      burning__isBurning = true
      burning__force = burning__maxForce
      burning__offender = shell__owner
      burning__offenderShellId = shell__shell_id__shell_id
      burning__offenderGunPropsId = shell__gun_props_id


[es(tag=server, REQUIRE=shell__burnAffectedEntities)]
def fire_splash_on_projectile_explode(evt : EventShellExplodedServer;
                                      launch_desc : LaunchDesc;
                                      ownerEid : EntityId;
                                      shell__affectedEntities : EidList)
  for target in shell__affectedEntities
    query(target) <| $ [es] (burning__maxForce : float;
                             var burning__isBurning : bool&;
                             var burning__force : float&;
                             var burning__offender : EntityId&;
                             var burning__offenderShellId : int&;
                             var burning__offenderGunPropsId : int&)
      burning__isBurning = true
      burning__force = burning__maxForce
      burning__offender = ownerEid
      burning__offenderShellId = int(launch_desc.shellId.shellId)
      burning__offenderGunPropsId = int(launch_desc.gunPropsId)
