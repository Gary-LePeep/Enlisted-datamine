module gun_common shared
require ecs
require app
require Gun
require DaWeapons
require DngPhys
require daslib/safe_addr
require common_shooter.events_common_shooter

def shoot_from_gun(gun_eid : EntityId; gun_tm : float3x4?; start_vel : float)
  let atTime = get_sync_time()
  let gctrl = [[GunControls() shoot=true, wishShoot=true, boltActionMult = 1., timeStep = 0.01]]
  let gunPos = (*gun_tm)[3]
  let gunDir = (*gun_tm)[0]
  let gunVel = start_vel * gunDir
  let gloc = [[GunLocation() gunDir      = gunDir,
                              gunShootDir = gunDir,
                              gunVel      = safe_addr(gunVel),
                              gunPos      = safe_addr(gunPos),
                              visTm       = gun_tm,
                              physTm      = gun_tm]]

  sendEventImmediate(gun_eid, [[CmdGunUpdate atTime=atTime, isForReal=true, seed=phys_time_to_seed(atTime), gctrl=gctrl, gloc=gloc]])

def shoot_from_gun(gun_templ : string; bullet_type_index : int; start_vel : float; tm : float3x4?; distance : float = 0.)
  let finalizeCreation <- @ <| (gunEid : EntityId)
    query(gunEid) <| $ [es(REQUIRE=gun__overrideProjectileDistance)] (var gun__projectileTemplate : das_string&)
      gun__projectileTemplate := "{gun__projectileTemplate}+shell_override_projectile_distance"
    shoot_from_gun(gunEid, tm, start_vel)

  let projectileSubTmpl = distance > 0. ? "+gun_override_projectile_distance" : ""
  let templateName = "{gun_templ}+turret_with_several_types_of_shells+gun_ammo_load_on_init{projectileSubTmpl}"
  createEntity(templateName, finalizeCreation) <| $(var init : ComponentsInitializer)
    set(init, "currentBulletId", bullet_type_index)
    if distance > 0.
      set(init, "gun__overrideProjectileDistance", distance)
    query() <| $ [es(REQUIRE=localPlayer)] (eid : EntityId)
      set(init, "gun__owner", eid)
