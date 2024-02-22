require ecs
require statBQ
require jsonwriter
require game.events_game
require game.es.stat_bq_common
require DngDm
require enlisted.game.es.offender_cache_common
require game.es.battle_area_common

[es(tag=server, REQUIRE=human)]
def send_to_bq_soldier_kills(evt : EventEntityDied;
                             eid : EntityId;
                             soldier__sClass : string;
                             transform aka victim_transform : float3x4;
                             squad_member__playerEid : EntityId)
  let gunPropsId = evt.gunPropsId
  let victimOwnerPlayer = squad_member__playerEid
  let offenderOwnerPlayer = get_offender_from_cache(evt.offender).player

  var damageTypeEnum = DamageType DM_PROJECTILE
  for damageEnum in each_enum(DamageType DM_PROJECTILE)
    if evt.damageType == int(damageEnum)
      damageTypeEnum = damageEnum
  // CHANGES TO THIS SCHEME SHOULD BE REFLECTED IN BQ TABLE (ask devops if you don't know what it means)
  let victimOutOfZone = is_tm_outside_battle_area(victim_transform, evt.victimTeam) ? "_victimoutofzone" : ""
  send_event_bq_with_header("soldier_kill") <| $(var jw : JsonWriter)
    jw_key_value(jw, "victim_class", "{soldier__sClass}{victimOutOfZone}")
    jw_key_value(jw, "victim_pos", "{transform[3]}")

    query(evt.offender) <| $ [es] (soldier__sClass : string; transform aka offender_transform : float3x4)
      let offenderGreyzone = is_tm_outside_battle_area(offender_transform, evt.victimTeam) ? "_killergreyzone" : ""
      jw_key_value(jw, "soldier_class", "{soldier__sClass}{offenderGreyzone}")
      jw_key_value(jw, "offender_pos", "{transform[3]}")

    jw_key_value(jw, "weapon_type", gunPropsId >= 0 ? get_gun_component_by_props_id(gunPropsId, "item__weapType") : "")
    jw_key_value(jw, "weapon_template", gunPropsId >= 0 ? get_gun_component_by_props_id(gunPropsId, "item__weapTemplate") : "")
    jw_key_value(jw, "damage_type", "{damageTypeEnum}")

    add_entity_type(jw, evt.offender, "offender")
    add_entity_type(jw, eid, "victim")

    query(victimOwnerPlayer) <| $ [es] (userid : uint64)
      add_user_id(jw, userid, "victim_user_id")
    query(offenderOwnerPlayer) <| $ [es] (userid : uint64)
      add_user_id(jw, userid)

    find_query() <| $ [es] (battle_area__team : int; battle_area__deactivatedAtTime : float; battleAreaId : string; active : bool)
      if active && battle_area__team == evt.victimTeam && battle_area__deactivatedAtTime < 0.
        jw_key_value(jw, "capzone_id", "{battleAreaId}")
        return true
      return false