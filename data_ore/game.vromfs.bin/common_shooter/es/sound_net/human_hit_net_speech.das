require ecs
require ecs.safe
require game.utils.team
require math
require math.base
require DagorSystem
require DngDm
require enlisted.events_enlisted
require human_sounds_net.modules.human_sounds_net_events
require common_shooter.events_common_shooter
require common_shooter.es.hit_result_common


def is_headshot(dm_parts__type : StringList&; coll_node_id : int)
  return coll_node_id >= 0 && string(dm_parts__type[coll_node_id]) == "head"


def is_concussed(eid : EntityId)
  return find_query() <| $ [es(REQUIRE=concussionSoundSuppression)] (game_effect__attachedTo : EntityId)
    return game_effect__attachedTo == eid


/*
def is_single_shot(human_eid : EntityId)
  // TODO: need to detect recent shots from human
  let hadRecentShots = true
  if hadRecentShots
    return false
  var gunEid = INVALID_ENTITY_ID
  query(human_eid) <| $ [es] (human_weap__gunEids : EidList;
                              human_weap__curGunSlot : int;
                              human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID)
    if human_attached_gun__attachedGunEid != INVALID_ENTITY_ID
      gunEid = human_attached_gun__attachedGunEid
    elif human_weap__curGunSlot >= 0
      gunEid = human_weap__gunEids[human_weap__curGunSlot]

  var burstSize = 0
  query(gunEid) <| $ [es] (gun__firingModeIndex : int;
                           gun__firingModes : Array)
    if gun__firingModeIndex >= 0 && gun__firingModeIndex < length(gun__firingModes)
      let modeObj = get_ecs_object(gun__firingModes[gun__firingModeIndex])
      if modeObj != null
        burstSize = (*modeObj).burstSize ?? 1
  return burstSize == 1
*/


def request_speech(eid : EntityId; phrase : string)
  sendEvent(eid, [[CmdRequestHumanSpeech phrase=phrase]])


def is_hard_hit(delta_hp, max_hp : float)
  return delta_hp > max_hp * 0.5


[es(tag=server)]
def human_hit_net_speech(evt : EventOnEntityHit;
                         eid : EntityId;
                         transform : float3x4;
                         isAlive : bool;
                         team : int;
                         hitpoints__maxHp : float;
                         human_net_speech__isFarKillThreshold = 100.)
  if evt.victim == evt.offender || !isAlive
    return

  if evt.victim != eid && evt.offender != eid
    return

  if evt.hitResult == int(HitResult HIT_RES_NONE)
    return

  assume dd = evt
  if dd.damageType != int(DamageType DM_PROJECTILE) && dd.damageType != int(DamageType DM_EXPLOSION) && dd.damageType != int(DamageType DM_MELEE) && dd.damageType != int(DamageType DM_BACKSTAB)
    return

  let wasKilled = (evt.hitResult == int(HitResult HIT_RES_KILLED)) && !is_concussed(evt.victim)

  if evt.victim == eid
    if !wasKilled && (dd.damageType == int(DamageType DM_PROJECTILE) || dd.damageType == int(DamageType DM_EXPLOSION))
      if is_hard_hit(dd.deltaHp, hitpoints__maxHp)
        sendEvent(evt.victim, [[CmdRequestHumanSpeech phrase="woundedHard"]])
      else
        sendEvent(evt.victim, [[CmdRequestHumanSpeech phrase="wounded"]])

  elif evt.offender == eid
    let offenderTeam = team
    query(evt.victim) <| $ [es(REQUIRE=human_net_phys)] (team aka victim_team : int; dm_parts__type : StringList&)
      if !is_teams_friendly(offenderTeam, victim_team)
        if wasKilled
          if dd.damageType == int(DamageType DM_EXPLOSION)
            request_speech(evt.offender, "enemyKillExplode")
          elif is_headshot(dm_parts__type, dd.collNodeId)
            request_speech(evt.offender, "enemyHeadshot")
          //elif dd.deltaHp >= hitpoints__maxHp && is_single_shot(evt.offender)
          //  request_speech(evt.offender, "enemyKillSingleShot")
          elif length_sq(dd.hitPos - transform[3]) > square(human_net_speech__isFarKillThreshold)
            request_speech(evt.offender, "enemyKillFar")
          elif (dd.damageType == int(DamageType DM_MELEE))
            request_speech(evt.offender, "enemyKillMelee")
          else
            request_speech(evt.offender, "enemyKill")
        else
          request_speech(evt.offender, "enemyHit")


[es(tag=server)]
def human_hit_friendly_human_net_speech(evt : ProjectileOnIntersectEntityWithHp;
                                        eid : EntityId;
                                        transform aka offender_transform : float3x4;
                                        isAlive : bool;
                                        team aka offender_team : int;
                                        human_net_speech__friendlyFireDistThreshold = 20.)
  if evt.offender == eid && isAlive
    query(evt.victim) <| $ [es(REQUIRE=human_net_phys)] (team aka victim_team : int = int(TEAM_UNASSIGNED))
      if is_teams_friendly(offender_team, victim_team)
        var eidToSpeak = INVALID_ENTITY_ID
        var closestDistSq = square(human_net_speech__friendlyFireDistThreshold)
        query() <| $ [es(REQUIRE=human_net_phys)] (eid : EntityId; team : int; transform : float3x4)
          if eid != evt.victim && eid != evt.offender && is_teams_friendly(team, offender_team)
            let distSq = length_sq(transform[3] - offender_transform[3])
            if distSq < closestDistSq
              eidToSpeak = eid
              closestDistSq = distSq
        if !!eidToSpeak
          sendEvent(eidToSpeak, [[CmdRequestHumanSpeech phrase="friendlyFireHit"]])
