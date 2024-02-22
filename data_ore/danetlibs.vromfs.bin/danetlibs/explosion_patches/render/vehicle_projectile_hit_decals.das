require ecs
require math.base
require DngDm
require danetlibs.dm.dm_events
require danetlibs.explosion_patches.render.vehicle_damage_decals_common


enum ProjectileHitType
  PIERCE
  STOP
  RICOCHETE

def create_damage_decal_on_hit_event(local_pos : float3;
                                     local_dir : float3;
                                     local_normal : float3;
                                     transform : float3x4;
                                     caliber : float;
                                     bullet_type_id : int;
                                     coll_node_id : int;
                                     hit_type : ProjectileHitType;
                                     vehicle_eid : EntityId)
  // Don't spawn decals for unknown type. It will use default texture which doesn't look good sometimes.
  if (bullet_type_id < 0)
    return
  let decal = get_bullet_decal(get_damage_model_params(), uint16(bullet_type_id))
  let hitAngleCos = -dot(local_dir, local_normal);
  let angledType = hitAngleCos < cos(deg_to_rad(45.0f));
  var damageType = ""
  if (decal != null)
    if hit_type == ProjectileHitType PIERCE
      damageType = angledType ? string(decal.pierceAngled) : string(decal.pierce)
    elif hit_type == ProjectileHitType STOP
      damageType = angledType ? string(decal.stopAngled) : string(decal.stop)
    elif hit_type == ProjectileHitType RICOCHETE
      damageType = string(decal.ricochet)
  let pos = transform * local_pos
  let dir = rotate(transform, local_dir)
  let normal = rotate(transform, local_normal)
  create_damage_decal_on_vehicle(pos, dir, normal, caliber, coll_node_id, damageType, vehicle_eid)

[es(tag=render, REQUIRE=damage_model, REQUIRE_NOT=disableUpdate)]
def vehicle_damage_decal_on_hit(evt : EventOnHitByProjectile;
                                transform : float3x4;
                                eid : EntityId)
  let hitType = evt.pierced ? ProjectileHitType PIERCE : ProjectileHitType STOP
  create_damage_decal_on_hit_event(evt.localHitPos, evt.localHitDir, evt.localNormal, transform,
                                   evt.caliber, evt.bulletTypeId, evt.nodeId, hitType, eid)

[es(tag=render, REQUIRE=damage_model, REQUIRE_NOT=disableUpdate)]
def vehicle_damage_decal_on_ricochet(evt : EventOnRicochet;
                                     transform : float3x4;
                                     eid : EntityId)
  let hitType = ProjectileHitType RICOCHETE
  var bulletTypeId = -1
  ecs::query(evt.projectileEid) <| $ [es] (dm_projectile_state : ProjectileState)
    bulletTypeId = dm_projectile_state.projectileTypePropsId
  create_damage_decal_on_hit_event(evt.localHitPos, evt.localHitDir, evt.localNormal, transform,
                                   evt.caliber, bulletTypeId, evt.nodeId, hitType, eid)
