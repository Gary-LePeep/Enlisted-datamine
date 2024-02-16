require ecs
require ecs.safe
require ecs.common
require soundEvent
require soundHash
require soundProps
require game.es.sound.sound_events
require sound_utils.modules.sound_player_common
require common_shooter.events_common_shooter
require DngDm
require strings


def damage_type_to_sound_path(damage_type : int)
  if damage_type == int(DamageType DM_PROJECTILE)
    return "hit_dmgProjectile"
  if damage_type == int(DamageType DM_MELEE) || damage_type == int(DamageType DM_BACKSTAB)
    return "hit_dmgMelee"
  if damage_type == int(DamageType DM_EXPLOSION)
    return "hit_dmgExplosion"
  if damage_type == int(DamageType DM_HOLD_BREATH)
    return "hit_dmgAsphyxiation"
  if damage_type == int(DamageType DM_GAS)
    return "hit_dmgGas"
  return ""


def is_armored(parts_armor : FloatList const?; node_id : int; sound_tags : Object)
  return parts_armor != null ? (node_id >= 0 && node_id < length(*parts_armor) && (*parts_armor)[node_id] != 0.) : read_sound_tag("armored", sound_tags)


def play_shatter_sounds(var count : int; var delay_first_next_last : float3; pos : float3; human_hit_sound__paths, sound_tags : Object; is_watched_sound : bool)
  let obj = human_hit_sound__paths["shatter"] ?as Object
  if obj != null
    var path : string
    if get_option_path(obj, sound_tags, is_watched_sound, path)
      while count-- != 0
        delayed_oneshot(path, pos, delay_first_next_last.x)
        delay_first_next_last.x = delay_first_next_last.y
        delay_first_next_last.y = delay_first_next_last.z


[es(tag=sound, REQUIRE=humanSound)]
def human_hit_sound(evt : EventOnEntityHit; eid : EntityId;
                    [[shared_comp]] human_hit_sound__paths : Object;
                    human_hit_sound__shattersDelayFirstNextLast : float3;
                    is_watched_sound : bool;
                    sound_tags : Object;
                    var sound_event_group : SoundEventGroup&;
                    dm_parts__type : StringList const?;
                    dm_parts__partsArmor : FloatList const?;
                    isAlive : bool;
                    transform : float3x4)
  if eid == evt.victim
    var name, path : string
    if evt.actionPropsId >= 0
      action_sound_get_props(evt.actionPropsId) <| $(props : SoundActionProps)
        name = props.humanHitSoundName
        path = props.humanHitSoundPath
    if empty(path)
      path = damage_type_to_sound_path(evt.damageType)

    var pathObj = !empty(path) ? (human_hit_sound__paths[path] ?as Object) : null
    if pathObj != null
      let collNodeId = evt.collNodeId
      if dm_parts__type != null && uint(collNodeId) < uint(length(*dm_parts__type))
        let part = get_desc(*pathObj, "part_{(*dm_parts__type)[collNodeId]}")
        pathObj = part != null ? part : pathObj

      if get_option_path(pathObj, sound_tags, is_watched_sound, path)
        if empty(name)
          name = (*pathObj).name ?? ""
        let handle = play_name_path_impl(name, path, evt.hitPos, false/*is_abandon*/)
        if evt.damageType == int(DamageType DM_PROJECTILE) || evt.damageType == int(DamageType DM_MELEE) || evt.damageType == int(DamageType DM_BACKSTAB)
          let isArmored = isAlive && is_armored(dm_parts__partsArmor, collNodeId, sound_tags)
          set_var_optional(handle, "armored", isArmored ? 1. : 0.)
        let localPos = inverse(transform) * evt.hitPos
        add_sound(sound_event_group, sound_hash("dmghit"), localPos, handle, 4/*max_instances*/)
        keyoff(handle)

    // shatters
    if evt.damageType == int(DamageType DM_EXPLOSION)
      let maxShatters = 3
      let numShatters = min(evt.shatterCount, maxShatters)
      if numShatters > 0
        play_shatter_sounds(numShatters, human_hit_sound__shattersDelayFirstNextLast, transform[3], human_hit_sound__paths, sound_tags, is_watched_sound)


[es(tag=sound, REQUIRE=(humanSound, is_watched_sound), track=is_watched_sound)]
def human_hit_sound_toggle_watched(evt : Event;
                                   var sound_event_group : SoundEventGroup&)
  release_sound(sound_event_group, sound_hash("dmghit"))
