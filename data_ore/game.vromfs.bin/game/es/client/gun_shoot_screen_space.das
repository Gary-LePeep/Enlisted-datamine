require ecs
require game.es.vehicle.vehicle_events
require game.es.gun_common
require DngCamera
require DngDm

[es(on_appear, REQUIRE=projectile__overrideLaunchDistance)]
def projectile_create_with_distance(evt : Event;
                                    gunEid : EntityId;
                                    var dm_projectile_state : ProjectileState&)
  dm_projectile_state.distance = get_float(gunEid, "gun__overrideProjectileDistance") ?? 0.

[es]
def shoot_gun_screen_space(evt : CmdShootGunScreenSpace)
  var worldPoint : float3
  var worldDir : float3
  screen_to_world(evt.screenPos, worldPoint, worldDir)
  let gunTemplate = evt.gunTemplate
  let bulletIndex = evt.bulletNo
  let distance = evt.distance
  let gunVelocity = 0.

  let up = float3(0, 1, 0)
  var tmPtr = new [[float3x4()]]
  assume tm = *tmPtr
  if length_sq(worldDir) > 0.0
    tm[0] = normalize(worldDir)
    tm[2] = cross(tm[0], up)
    tm[1] = cross(tm[2], tm[0])
    tm[3] = worldPoint
  shoot_from_gun(gunTemplate, bulletIndex, gunVelocity, tmPtr, distance)
