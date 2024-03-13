require ecs
require ecs.safe
require BallisticsProps
require sound_utils.modules.sound_physmat_common
require soundEvent
require strings
require RendInst
require DngDm

[cpp_event(unicast)]
struct EventProjectileHitScene
  pos : float3
  shouldStop : bool
  ricochetAngle : float
  smokeTracerStop : bool
  rendinstCellIdx : int
  rendinstIdx : int
  rendinstPool : int
  rendinstOffs : uint
  rendinstLayer : int
  matId : int
  norm : float3
  allowDetonation : bool
  sceneIntersectionsExceeded : bool
  collType : int
  vel : float3
  riexHandle : riex_handle_t

[cpp_event(unicast)]
struct CmdShellExplosionFx {}

[es(tag=sound)]
def projectile_impact_sounds_on_hit_scene(evt : EventProjectileHitScene;
                                          projectile_ballistics_props : ProjectileProps;
                                          projectile__exploded : bool;
                                          projectile_sound__shellCaliberThreshold : float;
                                          [[shared_comp]] projectile_sound__paths : Object;
                                          projectile_sound__ricoThreshold : float)
  if !evt.sceneIntersectionsExceeded || (evt.shouldStop && evt.allowDetonation)
    let isShell = projectile_ballistics_props.caliber >= projectile_sound__shellCaliberThreshold

    if abs(evt.ricochetAngle) > projectile_sound__ricoThreshold
      let ricoPath = isShell ? (projectile_sound__paths.ricoShell ?? "") : (projectile_sound__paths.ricoBullet ?? "")
      if !empty(ricoPath)
        let smid = int(get_projectile_sound_material_id(evt.matId))
        oneshot("[cal={projectile_ballistics_props.caliber};mat={smid}]{ricoPath}", evt.pos)
        if !evt.shouldStop
          return

    let pathId = projectile__exploded ? (isShell ? "explodeShell" : "explodeBullet") : (isShell ? "hitShell" : "hitBullet")
    let path = projectile_sound__paths[pathId] ?? ""
    if !empty(path)
      let smid = int(get_projectile_sound_material_id(evt.matId))
      oneshot("[cal={projectile_ballistics_props.caliber};mat={smid}]{path}", evt.pos)


[es(tag=sound)]
def projectile_impact_sounds_on_shell_explosion(evt : CmdShellExplosionFx;
                                                scene_hit_place__matId : int;
                                                scene_hit_place__pos : float3;
                                                projectile_sound__shellCaliberThreshold : float;
                                                projectile_ballistics_props : ProjectileProps;
                                                [[shared_comp]] projectile_sound__paths : Object)
  let pathId = projectile_ballistics_props.caliber >= projectile_sound__shellCaliberThreshold ? "explodeShell" : "explodeBullet"
  let path = projectile_sound__paths[pathId] ?? ""
  if !empty(path)
    let smid = int(get_projectile_sound_material_id(scene_hit_place__matId))
    oneshot("[cal={projectile_ballistics_props.caliber};mat={smid}]{path}", scene_hit_place__pos)
