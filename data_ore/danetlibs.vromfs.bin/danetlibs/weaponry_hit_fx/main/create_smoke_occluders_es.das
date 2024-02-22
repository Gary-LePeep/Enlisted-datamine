require ecs
require common_shooter.events_common_shooter
require DngDm
require DaWeapons
require Ballistics
require danetlibs.weaponry_hit_fx.main.weaponry_fx_common
require game.es.smoke_occluders_common


def create_smoke_occluders_impl(hit_effect_descriptor : int;
                                expl_effect_descriptor : int;
                                launch_desc : LaunchDesc;
                                dm_projectile_state : ProjectileState;
                                projectile_ballistics : ProjectileBallistics;
                                mat_id : int;
                                is_under_water : bool;
                                pos : float3;
                                norm : float3;
                                exploded : bool = true;
                                should_stop : bool = true;
                                ricochet : bool = false)
  if int(launch_desc.shellId.shellId) < 0
    return
  let fxName = get_projectile_fx_info(hit_effect_descriptor, expl_effect_descriptor,
                                      launch_desc, dm_projectile_state, projectile_ballistics, mat_id, is_under_water,
                                      exploded, should_stop, ricochet).fxName
  if fxName == "" || fxName == "-"
    return

  let tm = calc_effect_tm(pos, norm)
  create_smoke_occluders_for_effect(tm, fxName)


[es]
def projectile_create_smoke_occluders_on_hit_scene(evt : EventProjectileHitScene;
                                                   launch_desc : LaunchDesc;
                                                   dm_projectile_state : ProjectileState;
                                                   projectile_ballistics : ProjectileBallistics;
                                                   projectile__hitEffectDescriptor : int;
                                                   projectile__explEffectDescriptor : int;
                                                   projectile__isUnderwater : bool)
  if !evt.sceneIntersectionsExceeded || (evt.shouldStop && evt.allowDetonation)
    create_smoke_occluders_impl(projectile__hitEffectDescriptor, projectile__explEffectDescriptor,
                                launch_desc, dm_projectile_state, projectile_ballistics, evt.matId, projectile__isUnderwater,
                                evt.pos, evt.norm, evt.allowDetonation, evt.shouldStop, evt.ricochetAngle != 0.0)


[es]
def projectile_create_smoke_occluders_on_explode(evt : CmdShellExplosionFx;
                                                 scene_hit_place__matId : int;
                                                 scene_hit_place__pos : float3;
                                                 scene_hit_place__norm : float3;
                                                 launch_desc : LaunchDesc;
                                                 dm_projectile_state : ProjectileState;
                                                 projectile_ballistics : ProjectileBallistics;
                                                 projectile__hitEffectDescriptor : int;
                                                 projectile__explEffectDescriptor : int;
                                                 projectile__isUnderwater : bool)
  create_smoke_occluders_impl(projectile__hitEffectDescriptor, projectile__explEffectDescriptor,
                              launch_desc, dm_projectile_state, projectile_ballistics, scene_hit_place__matId, projectile__isUnderwater,
                              scene_hit_place__pos, scene_hit_place__norm)
