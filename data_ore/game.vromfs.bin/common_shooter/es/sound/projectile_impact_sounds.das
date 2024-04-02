require ecs
require ecs.safe
require sound_utils.modules.sound_physmat_common
require sound_utils.modules.sound_player_common
require soundEvent
require strings
require BallisticsProps
require DngDm
require common_shooter.events_common_shooter
require enlisted.events_enlisted
require game.utils.team


def is_armored(parts_armor : FloatList const?; node_id : int; sound_tags : Object)
  return parts_armor != null ? (node_id >= 0 && node_id < length(*parts_armor) && (*parts_armor)[node_id] != 0.) : read_sound_tag("armored", sound_tags)


[es(tag=sound)]
def projectile_impact_sounds_on_intersected_entity_with_hp(evt : EventProjectileIntersectEntityWithHp;
                                                           projectile__stopped : bool;
                                                           projectile__exploded : bool;
                                                           projectile_sound__shellCaliberThreshold : float;
                                                           projectile_ballistics_props : ProjectileProps)

  let isShell = projectile_ballistics_props.caliber >= projectile_sound__shellCaliberThreshold
  query(evt.victim) <| $ [es] ([[shared_comp]] entity_intersected_with_projectile_sound__paths : Object;
                               is_watched_sound : bool = false;
                               sound_tags : Object;
                               dm_parts__type : StringList const?;
                               dm_parts__partsArmor : FloatList const?)
    assume __paths = entity_intersected_with_projectile_sound__paths

    let bulletShellPath = isShell ? (__paths.shell ?as Object) : (__paths.bullet ?as Object)
    var path = projectile__exploded ? (bulletShellPath?.exploded ?as Object) : projectile__stopped ? (bulletShellPath?.stopped ?as Object) : bulletShellPath
    path = path != null ? path : bulletShellPath

    if path != null

      if dm_parts__type != null && uint(evt.collNodeId) < uint(length(*dm_parts__type))
        let part = get_desc(*path, "part_{(*dm_parts__type)[evt.collNodeId]}")
        path = part != null ? part : path

      var handle = sound_player_common::play_path(*path, sound_tags, is_watched_sound, evt.pos, false)
      if is_armored(dm_parts__partsArmor, evt.collNodeId, sound_tags)
        set_var_optional(handle, "armored", 1.)
      abandon(handle)


def get_hit_scene_path(is_shell, exploded : bool; owner_eid : EntityId; var friendly_var : float&)
  if is_shell
    return exploded ? "explodeShell" : "hitShell"
  else
    query(owner_eid) <| $ [es] (team : int; hero : Tag const?)
      friendly_var = (hero != null || is_teams_friendly(team, get_local_player_team())) ? 1. : 0.
    return exploded ? "explodeBullet" : "hitBullet"


[es(tag=sound)]
def projectile_impact_sounds_on_hit_scene(evt : EventProjectileHitScene;
                                          ownerEid : EntityId = INVALID_ENTITY_ID;
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

    var friendlyVar = 0.
    let path = projectile_sound__paths[get_hit_scene_path(isShell, projectile__exploded, ownerEid, friendlyVar)] ?? ""
    if !empty(path)
      let smid = int(get_projectile_sound_material_id(evt.matId))
      if friendlyVar != 0.
        var handle = soundEvent::play("[cal={projectile_ballistics_props.caliber};mat={smid}]{path}", evt.pos)
        set_var_optional(handle, "friendlyBullet", friendlyVar)
        abandon(handle)
      else
        oneshot("[cal={projectile_ballistics_props.caliber};mat={smid}]{path}", evt.pos)


[es(tag=sound, on_event=CmdShellExplosionFx)]
def projectile_impact_sounds_on_shell_explosion(evt : Event;
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
