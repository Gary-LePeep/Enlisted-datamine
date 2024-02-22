require ecs
require danetlibs.explosion_patches.explosion_patches_events
require DngWeaponRender
require DngDm
require BallisticsProps
require DamageDecals


[es(tag=render, REQUIRE_NOT=disableRIBulletHole)]
def projectile_bullet_hole_on_ri_es(evt : CmdRendinstBulletHole;
                                    projectile_ballistics_props : ProjectileProps;
                                    dm_projectile_state : ProjectileState)
  let decal = get_bullet_decal(get_damage_model_params(), uint16(dm_projectile_state.projectileTypePropsId))
  let damageType = decal != null ? string(decal.stop) : ""
  let created = create_ri_projective_damage_decal(evt.pos, evt.dir, evt.norm, evt.riHandle,
    projectile_ballistics_props.caliber, evt.pmid, damageType)
  if !created
    //billboard decal
    add_projectile_bullet_hole(evt.riHandle, evt.pos, evt.norm, evt.pmid, projectile_ballistics_props.caliber)
