require app
require ecs
require ecs.common
require DagorSystem
require enlisted.events_enlisted
require GridCollision
require DagorRandom
require game.es.events
require game.utils.team
require game.events_game
require EffectorData
require AnimV20
require GeomNodeTree
require DngDm
require math
require math.base
require DagorMath
require common_shooter.events_common_shooter
require game.es.awards_common
require game.es.vehicle.vehicle_events
require enlisted.game.es.offender_cache_common
require PhysVars
require DngBehTree
require game.es.node_attach_common
require danetlibs.native_dasevents.main.native_events
require DngNet
require Dacoll

[es(on_appear, tag=render)]
def attached_effects_apeear_es(evt : Event;
                               eid aka base_eid : EntityId;
                               animchar : AnimcharBaseComponent;
                               attach_effects__scales : FloatList;
                               attach_effects__templateNames : StringList;
                               attach_effects__nodes : StringList)
  for effectName, nodeName, scale in attach_effects__templateNames, attach_effects__nodes, attach_effects__scales
    let nodeId = geomtree_findNodeIndex(*animchar.nodeTree, string(nodeName))
    var tm : float3x4
    var ctm = IDENT_TM
    ctm[0] *= scale
    ctm[1] *= scale
    ctm[2] *= scale

    geomtree_getNodeWtmScalar(*animchar.nodeTree, nodeId, tm)
    tm = tm * ctm

    let effectEid = createEntity(string(effectName)) <| $(var init : ComponentsInitializer)
      set(init, "transform", tm)
      set(init, "effect_animation__transform", tm)
    attach_to_node(effectEid, base_eid, nodeId, ctm)

[es(on_disappear, REQUIRE=attach_effects__templateNames, tag=render)]
def attached_effects_disapeear_es(evt : Event;
                                  eid aka base_eid : EntityId)
  query() <| $ [es(REQUIRE=burning)] (eid aka eff_eid : EntityId; node_attached__entity : EntityId)
    if node_attached__entity == base_eid
      destroyEntity(eff_eid)

[es(on_appear, tag=server)]
def simple_zombie_spawner_init(evt : Event;
                               simple_spawner__useTeamSpawns : int;
                               var simple_spawner__zonesPos : Point3List)
  query() <| $ [es(REQUIRE=respbase)] (transform : float3x4;
                                       team : int)
    if team == simple_spawner__useTeamSpawns
      push(simple_spawner__zonesPos, transform[3])


[es(tag=server)]
def simple_zombie_spawner(evt : ParallelUpdateFrameDelayed;
                          eid : EntityId;
                          simple_spawner__nextSpawnPeriod : float;
                          simple_spawner__additionalHeight : float;
                          simple_spawner__zonesPos : Point3List;
                          simple_spawner__template : string;
                          simple_spawner__randomRadius : float;
                          var simple_spawner__nextSpawnAtTime : float&;
                          var simple_spawner__spawnsCount : int&)
  let zonesCount = length(simple_spawner__zonesPos)
  if zonesCount == 0
    logerr("no zones was inited for simple spawner")
    destroyEntity(eid)
    return
  if simple_spawner__nextSpawnAtTime > evt.curTime
    return

  simple_spawner__nextSpawnAtTime = evt.curTime + simple_spawner__nextSpawnPeriod
  let selectedSpawn = rnd_int(0, zonesCount - 1)
  var tm = IDENT_TM
  tm[3] = simple_spawner__zonesPos[selectedSpawn]
  tm[3].y += simple_spawner__additionalHeight

  let randomXdiff = rnd_float(-simple_spawner__randomRadius, simple_spawner__randomRadius)
  let randomZdiff = rnd_float(-simple_spawner__randomRadius, simple_spawner__randomRadius)
  tm[3] += float3(1., 0., 0.) * randomXdiff
  tm[3] += float3(0., 0., 1.) * randomZdiff

  var targerEid = INVALID_ENTITY_ID
  find_query() <| $ [es] (entity_spawner__aliveHumans : EidList)
    let randomHuman = rnd_int(0, length(entity_spawner__aliveHumans) - 1)
    targerEid = entity_spawner__aliveHumans[randomHuman]
    return true

  createEntity(simple_spawner__template) <| $(var init)
    init |> set("transform", tm)

  simple_spawner__spawnsCount--
  if simple_spawner__spawnsCount <= 0
    destroyEntity(eid)


[es(on_appear, tag=gameClient)]
def propeller_init_phys_var(evt : Event;
                            var zombie__propellerVar : int&;
                            var phys_vars : PhysVars)
  zombie__propellerVar = phys_vars |> registerVar("prop_rot", 0.0)


[es(no_order, tag=gameClient)]
def propeller_anim_update(info : ParallelUpdateFrameDelayed;
                          zombie__propellerSpeed : float;
                          zombie__propellerVar : int;
                          var zombie__propellerCurValue : float&;
                          var phys_vars : PhysVars)
  if zombie__propellerVar >= 0
    zombie__propellerCurValue += info.dt * zombie__propellerSpeed
    zombie__propellerCurValue = zombie__propellerCurValue % 360.
    phys_vars |> setVar(zombie__propellerVar, zombie__propellerCurValue)


[es(REQUIRE=navmesh_phys__wishLookDir, on_appear, before=navmesh_phys_create_sub_entity_on_init)]
def navmesh_phys_sub_entity_attach_node(evt : Event;
                                        animchar aka zombie_animchar : AnimcharBaseComponent;
                                        var zombie__attachEntityNodeId : int&;
                                        zombie__attachEntityNode = "weapon")
  zombie__attachEntityNodeId = geomtree_findNodeIndex(*zombie_animchar.nodeTree, string(zombie__attachEntityNode))

[es(REQUIRE=navmesh_phys__wishLookDir, on_appear, tag=server)]
def navmesh_phys_create_sub_entity_on_init(evt : Event;
                                           eid : EntityId;
                                           zombie__attachHandsEntityTemplate : string;
                                           zombie__attachEntityNodeId : int;
                                           var anim__attachHandsEntity : EntityId&;
                                           var anim__attachHandsEntityCached : EntityId&)
  if !anim__attachHandsEntity && zombie__attachEntityNodeId >= 0
    anim__attachHandsEntity = createEntity(zombie__attachHandsEntityTemplate) <| $(var init)
      init |> set("anim__attachEntityTo", eid)
    anim__attachHandsEntityCached = anim__attachHandsEntity

[es(tag=server, REQUIRE=zombie)]
def disable_zombie_beh_tree_on_dead(evt : EventEntityDied;
                                    var beh_tree__enabled : bool&)
  beh_tree__enabled = false

[es(tag=server)]
def detach_entities_on_dead(evt : EventEntityDied;
                            anim__attachEntityTo : EntityId)
  query(anim__attachEntityTo) <| $ [es] (var anim__attachHandsEntity : EntityId&)
    anim__attachHandsEntity = INVALID_ENTITY_ID

[es(tag=server)]
def kill_attached_entities_on_dead(evt : EventEntityDied;
                                   anim__attachHandsEntity : EntityId)
  query(anim__attachHandsEntity) <| $ [es] (var mine__activated : bool&)
    mine__activated = false
  query(anim__attachHandsEntity) <| $ [es(REQUIRE_NOT=mineActivatorTemplate)] (var hitpoints__hp : float&;
                                                                               hitpoints__deathHpThreshold = 0.f)
    hitpoints__hp = hitpoints__deathHpThreshold - 1.

[es(tag=server, on_disappear)]
def navmesh_phys_remove_sub_entity_on_disappear(evt : Event;
                                                anim__attachHandsEntityCached : EntityId)
  if !!anim__attachHandsEntityCached
    destroyEntity(anim__attachHandsEntityCached)

[es(on_appear, REQUIRE=(deadEntity, anim__attachHandsEntity))]
def reset_copy_nodes_for_zombie(evt : Event;
                                var copy_skeleton_nodes__copyFromEid : EntityId&)
  copy_skeleton_nodes__copyFromEid = INVALID_ENTITY_ID

[es(REQUIRE=navmesh_phys__wishLookDir, before=navmesh_phys_look_fun_init)]
def update_zombies_attach_object_tm(evt : ParallelUpdateFrameDelayed;
                                    anim__attachHandsLocalTm : float3x4;
                                    animchar aka zombie_animchar : AnimcharBaseComponent;
                                    zombie__attachEntityNodeId : int;
                                    anim__attachHandsEntity : EntityId)
  query(anim__attachHandsEntity) <| $ [es] (var transform aka obj_transform : float3x4)
    geomtree_getNodeWtmScalar(*zombie_animchar.nodeTree, zombie__attachEntityNodeId, obj_transform)
    obj_transform[1] *= -1.
    obj_transform = obj_transform * anim__attachHandsLocalTm

[es(on_appear, tag=gameClient)]
def init_attach_nodes_on_item_in_hands_created(evt : Event;
                                               animchar aka item_animchar : AnimcharBaseComponent;
                                               var zombie__attachLHandNodeId : int&;
                                               var zombie__attachRHandNodeId : int&;
                                               zombie__attachLHandNode = "Bip01 L Hand";
                                               zombie__attachRHandNode = "Bip01 R Hand")
  if zombie__attachLHandNode != ""
    zombie__attachLHandNodeId = zombie__attachLHandNode == "root" ? 0 : geomtree_findNodeIndex(*item_animchar.nodeTree, string(zombie__attachLHandNode))
  if zombie__attachRHandNode != ""
    zombie__attachRHandNodeId = zombie__attachRHandNode == "root" ? 0 : geomtree_findNodeIndex(*item_animchar.nodeTree, string(zombie__attachRHandNode))

[es(REQUIRE=navmesh_phys__wishLookDir, tag=gameClient)]
def zombies_hands_object_update_effectors(evt : ParallelUpdateFrameDelayed;
                                          animchar__visible : bool;
                                          transform aka zombie_transform : float3x4;
                                          anim__attachHandsEntity : EntityId;
                                          var animchar_effectors__effectorsState : Object)
  var rightHandEffector = animchar_effectors__effectorsState |> getNullableRW_EffectorData("r.hand")
  var leftHandEffector = animchar_effectors__effectorsState |> getNullableRW_EffectorData("l.hand")
  rightHandEffector.weight = 0.
  leftHandEffector.weight = 0.
  query(anim__attachHandsEntity) <| $ [es] (transform aka obj_transform : float3x4;
                                            animchar aka item_animchar : AnimcharBaseComponent;
                                            zombie__attachLHandAdditiveTm : float3x4 const?;
                                            zombie__attachRHandAdditiveTm : float3x4 const?;
                                            zombie__attachLHandNodeId : int;
                                            zombie__attachRHandNodeId : int)
    let objWofs = geomtree_calc_optimal_wofs(obj_transform[3])
    let d_wofs = objWofs - geomtree_calc_optimal_wofs(zombie_transform[3])
    var ojbLocalWtm = obj_transform
    ojbLocalWtm[3] = obj_transform[3] - objWofs

    if !animchar__visible
      return

    var objRootTm : float3x4
    geomtree_getNodeWtmRelScalar(*item_animchar.nodeTree, 0, objRootTm)
    if zombie__attachLHandNodeId >= 0
      geomtree_getNodeWtmRelScalar(*item_animchar.nodeTree, zombie__attachLHandNodeId, leftHandEffector.wtm)
      if zombie__attachLHandAdditiveTm != null
        leftHandEffector.wtm =  leftHandEffector.wtm * (*zombie__attachLHandAdditiveTm)
      leftHandEffector.wtm = ojbLocalWtm * (inverse(objRootTm) * leftHandEffector.wtm)
      leftHandEffector.position = leftHandEffector.wtm[3] + d_wofs
      leftHandEffector.wtm[3] = leftHandEffector.position
      leftHandEffector.weight = 1.

    if zombie__attachRHandNodeId >= 0
      geomtree_getNodeWtmRelScalar(*item_animchar.nodeTree, zombie__attachRHandNodeId, rightHandEffector.wtm)
      if zombie__attachRHandAdditiveTm != null
        rightHandEffector.wtm = rightHandEffector.wtm * (*zombie__attachRHandAdditiveTm)
      rightHandEffector.wtm = ojbLocalWtm * (inverse(objRootTm) * rightHandEffector.wtm)
      rightHandEffector.position = rightHandEffector.wtm[3] + d_wofs
      rightHandEffector.wtm[3] = rightHandEffector.position
      rightHandEffector.weight = 1.

[es(tag=server, REQUIRE=zombie)]
def zombie_mode_killed_points(evt : EventEntityDied;
                              paid_loot__pointsForKill : int)
  query(evt.offender) <| $ [es] (var paid_loot__points : int&)
    paid_loot__points += paid_loot__pointsForKill

[es(tag=server, track=entity_spawner__curWaveId, REQUIRE=zombieSpawnMode)]
def add_points_to_soldiers_on_wave_changed(evt : Event;
                                           entity_spawner__nextWavePoints : int;
                                           entity_spawner__curWaveId : int)
  if entity_spawner__curWaveId <= 0
    return
  query() <| $ [es] (var paid_loot__points : int&)
    paid_loot__points += entity_spawner__nextWavePoints

[es(tag=server, track=paid_loot__points)]
def add_loot_points_to_player_score(evt : Event; paid_loot__points : int; possessedByPlr : EntityId; guid : string)
  query(possessedByPlr) <| $ [es] (var scoring_player__zombieLastSavedScore : int&)
    if paid_loot__points > scoring_player__zombieLastSavedScore
      send_award_stat(possessedByPlr, guid, "zombieTotalScore", float(paid_loot__points - scoring_player__zombieLastSavedScore))
    scoring_player__zombieLastSavedScore = paid_loot__points

[es(on_appear)]
def navmesh_phys_look_dir_init(evt : Event;
                               transform : float3x4;
                               var navmesh_phys__wishLookDir : float3&)
  navmesh_phys__wishLookDir = normalize(transform[0])


[es(on_appear, REQUIRE=human, REQUIRE_NOT=(zombie, hitpoints__alwaysDowned))]
def init_humans_for_zombie_mode(evt : Event;
                                eid : EntityId;
                                var hitpoints__downedTimer : float&)
  find_query() <| $ [es(REQUIRE=entity_spawner__aliveHumans)] ()
    addSubTemplate(eid, "zombie_mode_soldier")
    hitpoints__downedTimer = -1.
    return true


[es(tag=server)]
def zombie_mode_session_finished(evt : EventAnyEntityDowned;
                                 var zombie_mode__sessionFinished : bool&)
  if zombie_mode__sessionFinished
    return
  let hasAliveHumans = find_query() <| $ [es(REQUIRE=human, REQUIRE_NOT=zombie)] (isAlive : bool; isDowned : bool)
    return isAlive && !isDowned
  if !hasAliveHumans
    broadcastEvent([[EventTeamLost team=get_int(evt.victim, "team") ?? TEAM_UNASSIGNED]])
    zombie_mode__sessionFinished = true


[es(tag=server, on_appear, track=(isAlive, isDowned), REQUIRE=human, REQUIRE_NOT=zombie)]
def alive_humans_eids_for_spawner(evt : Event;
                                  eid : EntityId;
                                  isAlive : bool;
                                  isDowned : bool)
  find_query() <| $ [es] (var entity_spawner__aliveHumans : EidList)
    let humanIdInList = find_index(entity_spawner__aliveHumans, eid)
    if isAlive && !isDowned
      if humanIdInList < 0
        push(entity_spawner__aliveHumans, eid)
      if length(entity_spawner__aliveHumans) == 1 //first spawner player. We must reinit zombies without target (for case when all soldiers died)
        query() <| $ [es] (var walker_agent__targetEid : EntityId&;
                           var walker_agent__priorityTarget : EntityId&)
          if walker_agent__priorityTarget == INVALID_ENTITY_ID
            walker_agent__priorityTarget = eid
            walker_agent__targetEid = eid
    else
      if humanIdInList >= 0
        erase(entity_spawner__aliveHumans, humanIdInList)
    return true

[es(tag=server, REQUIRE=zombie)]
def find_target_for_zombie_es(info : ParallelUpdateFrameDelayed;
                              transform aka zombie_transform : float3x4;
                              zombie__findTargetCooldown : float;
                              zombie__findClosestTargetDist : float;
                              var zombie__findTargetTime : float&;
                              var walker_agent__targetEid : EntityId&;
                              var walker_agent__priorityTarget : EntityId&)
  if info.curTime > zombie__findTargetTime
    zombie__findTargetTime = info.curTime + zombie__findTargetCooldown
  else
    return

  var minDistSq = square(zombie__findClosestTargetDist)
  find_query() <| $ [es] (entity_spawner__aliveHumans : EidList)
    var validTarget = false
    for humanEid in entity_spawner__aliveHumans
      query(humanEid) <| $ [es] (transform aka soldier_transform : float3x4; eid : EntityId)
        let curDistSq = distance_sq(soldier_transform[3], zombie_transform[3])
        if curDistSq < minDistSq
          walker_agent__priorityTarget = eid
          walker_agent__targetEid = eid
          minDistSq = curDistSq
          validTarget = true

    if validTarget
      return true

    validTarget = !!walker_agent__priorityTarget

    query(walker_agent__priorityTarget) <| $ [es] (isDowned : bool; isAlive : bool)
      validTarget = !isDowned && isAlive

    if !validTarget && length(entity_spawner__aliveHumans) > 0
      let randomHuman = rnd_int(0, length(entity_spawner__aliveHumans) - 1)
      let targerEid = entity_spawner__aliveHumans[randomHuman]
      walker_agent__priorityTarget = targerEid
      walker_agent__targetEid = targerEid

    return true

[es(tag=server, on_appear, track=isAlive, REQUIRE=zombie)]
def alive_zombies_explode_on_die(evt : Event;
                                 isAlive : bool;
                                 hitpoints__lastOffender : EntityId;
                                 transform : float3x4;
                                 zombie__grenadeTemplate = "")
  if zombie__grenadeTemplate != "" && !isAlive
    createEntity(zombie__grenadeTemplate) <| $(var init)
      init |> set("ownerEid", hitpoints__lastOffender)
      init |> set("transform", transform)

[es(tag=server, on_appear, track=isAlive, REQUIRE=zombie, REQUIRE_NOT=zombie_no_award)]
def alive_zombies_count_for_spawner(evt : Event;
                                    isAlive : bool)
  find_query() <| $ [es] (var entity_spawner__aliveZombiesCount : int&)
    if isAlive
      entity_spawner__aliveZombiesCount++
    else
      entity_spawner__aliveZombiesCount--
    return true

[es(tag=server, on_disappear, REQUIRE=zombie, REQUIRE_NOT=zombie_no_award)]
def alive_zombies_remove_on_disappear(evt : Event;
                                      isAlive : bool)
  find_query() <| $ [es] (var entity_spawner__aliveZombiesCount : int&)
    if isAlive
      entity_spawner__aliveZombiesCount--
    return true

[es(tag=server, on_appear)]
def fill_spawns_eids_on_entity_spawner_created(evt : Event;
                                               var entity_spawner__spawns : EidList)
  clear(entity_spawner__spawns)
  query() <| $ [es(REQUIRE=zombieSpawn)] (eid : EntityId)
    push(entity_spawner__spawns, eid)

[es(tag=server, on_appear, REQUIRE=zombieSpawn)]
def fill_spawns_eids_on_zombie_spawn_created(evt : Event;
                                             eid : EntityId)
  query() <| $ [es] (var entity_spawner__spawns : EidList)
    let alreadyInList = find_index(entity_spawner__spawns, eid) >= 0
    if !alreadyInList
      push(entity_spawner__spawns, eid)

[es(tag=server, on_appear)]
def fill_tank_spawns_eids_on_entity_spawner_created(evt : Event;
                                                    var entity_spawner__tankSpawns : EidList&;
                                                    var entity_spawner__curTankSpawnId : int&)
  clear(entity_spawner__tankSpawns)
  query() <| $ [es(REQUIRE=zombieTankSpawn)] (eid : EntityId)
    push(entity_spawner__tankSpawns, eid)
  let tankSpawnCount = length(entity_spawner__tankSpawns)
  if tankSpawnCount > 0
    entity_spawner__curTankSpawnId = rnd_int(0, tankSpawnCount - 1)

[es(tag=server, on_appear, REQUIRE=zombieTankSpawn)]
def fill_tank_spawns_eids_on_zombie_spawn_created(evt : Event;
                                                  eid : EntityId)
  query() <| $ [es] (var entity_spawner__tankSpawns : EidList&; var entity_spawner__curTankSpawnId : int&)
    let alreadyInList = find_index(entity_spawner__tankSpawns, eid) >= 0
    if !alreadyInList
      push(entity_spawner__tankSpawns, eid)
    let tankSpawnCount = length(entity_spawner__tankSpawns)
    if tankSpawnCount > 0
      entity_spawner__curTankSpawnId = rnd_int(0, tankSpawnCount - 1)

[es(tag=server, on_appear, track=entity_spawner__curWaveId, REQUIRE=zombieSpawnMode)]
def init_wave_templates_for_spawner(evt : Event;
                                    entity_spawner__waves : Array;
                                    entity_spawner__curWaveId : int;
                                    entity_spawner__lastWaveMul : float;
                                    entity_spawner__winOnWave : int;
                                    entity_spawner__winTeam : int;
                                    var entity_spawner__counstSpawnInWave : int&;
                                    var entity_spawner__alreadySpawnInWave : int&;
                                    var entity_spawner__wavesTemplates : StringList;
                                    var entity_spawner__count : IntList;
                                    var entity_spawner__briefing : das_string;
                                    entity_spawner__briefingTime : float = 15.;
                                    entity_spawner__genericWavesRepeat : int)
  clear(entity_spawner__wavesTemplates)
  clear(entity_spawner__count)
  if entity_spawner__curWaveId == entity_spawner__winOnWave
    broadcastEvent([[EventTeamWon team=entity_spawner__winTeam]])
    return
  entity_spawner__counstSpawnInWave = 0
  entity_spawner__alreadySpawnInWave = 0
  let wavesCount = length(entity_spawner__waves)
  let genericWave = entity_spawner__curWaveId >= wavesCount

  var resultWave = entity_spawner__curWaveId
  var waveMul = 1.0
  if genericWave
    let numOfGenericWave = (entity_spawner__curWaveId - wavesCount) % entity_spawner__genericWavesRepeat
    resultWave = wavesCount - entity_spawner__genericWavesRepeat + numOfGenericWave

    let waveMulPow = int(float(entity_spawner__curWaveId - wavesCount) / float(entity_spawner__genericWavesRepeat)) + 1
    waveMul = pow(entity_spawner__lastWaveMul, float(waveMulPow))


  let waveData = get_ecs_object(entity_spawner__waves[resultWave])
  if waveData == null
    logerr("incorrect data in entity_spawner__waves. No objects in it.")
    return
  entity_spawner__briefing := ""
  for it in *waveData
    if it.key == "wave_briefing"
      entity_spawner__briefing := get_string(it.value, "")
      if entity_spawner__curWaveId == 0
        query() <| $ [es(REQUIRE=team__id)] (var team__briefing : das_string&;
                                             var team__goalShowTime : float&)
          team__briefing := entity_spawner__briefing
          team__goalShowTime = entity_spawner__briefingTime
      continue
    var count = get_int(it.value) ?? -1
    if count <= 0
      logerr("Expecting positive value for key {it.key}. Got {count}")
      continue
    count = it.key == "zombie_eclipse_controller" ? 1 : int(float(count) * waveMul)
    if it.key == "zombie_ai_vehicle_tank_spawner"
      count = min(count, 4)
    push(entity_spawner__wavesTemplates, it.key)
    push(entity_spawner__count, count)
    entity_spawner__counstSpawnInWave += count

[es(tag=server)]
def zombie_mode_creator(evt : ParallelUpdateFrameDelayed;
                        entity_spawner__aliveZombiesCount : int;
                        entity_spawner__aliveZombiesLimit : int;
                        entity_spawner__spawns : EidList;
                        entity_spawner__aliveHumans : EidList;
                        entity_spawner__nextWavePeriod : float;
                        entity_spawner__nextSpawnPeriod : float;
                        entity_spawner__maxWaveTimeAfterLastSpawned : float;
                        entity_spawner__briefing : string;
                        var entity_spawner__nextSpawnAtTime : float&;
                        var entity_spawner__curWaveId : int&;
                        var entity_spawner__nextWaveAtTime : float&;
                        var entity_spawner__forceNextWaveAtTime : float&;
                        var entity_spawner__wavesTemplates : StringList;
                        var entity_spawner__count : IntList;
                        var entity_spawner__alreadySpawnInWave : int&;
                        entity_spawner__briefingTime : float = 15.;
                        entity_spawners__walkSpeedMultRange = float2(0.6, 1.))
  if entity_spawner__aliveZombiesCount > entity_spawner__aliveZombiesLimit
    return

  if entity_spawner__nextSpawnAtTime > evt.curTime
    return

  if entity_spawner__nextWaveAtTime > evt.curTime
    return
  elif entity_spawner__nextWaveAtTime >= 0.
    query() <| $ [es(REQUIRE=team__id)] (var team__briefing : das_string&;
                                         var team__goalShowTime : float&)
      team__briefing := entity_spawner__briefing
      team__goalShowTime = entity_spawner__briefingTime
    entity_spawner__nextWaveAtTime = -1.
    return

  let humansCount = length(entity_spawner__aliveHumans)
  if humansCount == 0
    return

  let typesCount = length(entity_spawner__wavesTemplates)
  let spawnsCount = length(entity_spawner__spawns)
  if typesCount == 0
    if entity_spawner__forceNextWaveAtTime < 0.
      entity_spawner__forceNextWaveAtTime = evt.curTime + entity_spawner__maxWaveTimeAfterLastSpawned
    if entity_spawner__aliveZombiesCount == 0 || entity_spawner__forceNextWaveAtTime < evt.curTime
      entity_spawner__nextWaveAtTime += evt.curTime + entity_spawner__nextWavePeriod
      entity_spawner__curWaveId++
      entity_spawner__forceNextWaveAtTime = -1.
    return

  let templateId = rnd_int(0, typesCount - 1)
  let spawnId = rnd_int(0, spawnsCount - 1)

  if entity_spawner__count[templateId] <= 0
    logerr("incorrect data in entity_spawner__count inited. Field must be removed from spawn list on zombie spawned")
    return

  query(entity_spawner__spawns[spawnId]) <| $ [es(REQUIRE=zombieSpawn)] (transform : float3x4)
    entity_spawner__alreadySpawnInWave ++
    createEntity(string(entity_spawner__wavesTemplates[templateId])) <| $(var init : ComponentsInitializer)
      set(init, "transform", transform)
      set(init, "navmesh_phys__walkSpeedMult", rnd_float(entity_spawners__walkSpeedMultRange.x, entity_spawners__walkSpeedMultRange.y))
    entity_spawner__count[templateId]--
    entity_spawner__nextSpawnAtTime = evt.curTime + entity_spawner__nextSpawnPeriod
    if entity_spawner__count[templateId] <= 0
      erase(entity_spawner__wavesTemplates, templateId)
      erase(entity_spawner__count, templateId)


def validate_vehicle_position(tm : float3x4)
  var wishPos = tm[3]

  var vehiclesPos : array<float3>
  query() <| $ [es(REQUIRE=vehicle)] (transform : float3x4)
    push(vehiclesPos, transform[3])

  var isWorking = true
  var iter = 0
  while iter < 5 && isWorking
    isWorking = false
    for pos in vehiclesPos
      var dist = wishPos - pos
      dist.y = 0.0
      var len = length(dist)
      if len == 0.0
        len = 1.0
        dist = float3(1.0, 0.0, 0.0)
      if len < 5.0
        dist = dist / len
        wishPos = wishPos + dist * 5.0
        isWorking = true
    ++iter

  var resTm = tm
  resTm[3] = wishPos
  let traceStart = resTm[3] + float3(0.0, 50.0, 0.0)
  let TRACE_HEIGHT = 70.0
  var height = TRACE_HEIGHT
  if tracedown_normalized(traceStart, height, ETF_DEFAULT)
    resTm[3] = traceStart + float3(0.0, -height + 3.0, 0.0)
  return resTm


[es(tag=server, on_appear, REQUIRE=zombie_ai_vehicle_tank_spawner)]
def zombie_ai_vehicle_tank_spawner(evt : Event;
                                   zombie_ai_vehicle_tank_spawner__template : string;
                                   var zombie_ai_vehicle_tank_spawner__tankEid : EntityId&)
  find_query() <| $ [es] (entity_spawner__tankSpawns : EidList; var entity_spawner__curTankSpawnId : int&)
    let spawnId = entity_spawner__curTankSpawnId
    query(entity_spawner__tankSpawns[spawnId]) <| $ [es(REQUIRE=zombieTankSpawn)] (transform : float3x4;
                                                                                   zombie_tank_spawn_zone__objectiveId : int;
                                                                                   var zombie_tank_spawn_zone__curPositionIdx : int&)
      var objectiveEid = INVALID_ENTITY_ID
      var posCount = 0
      var dest = float3()
      find_query() <| $ [es] (eid : EntityId;
                              zombie_tank_objective__id : int;
                              ai_tank_objective__positionIds : IntList;
                              ai_tank_objective__positions : Point3List)
        if zombie_tank_objective__id == zombie_tank_spawn_zone__objectiveId
          objectiveEid = eid
          posCount = length(ai_tank_objective__positionIds)
          dest = ai_tank_objective__positions[zombie_tank_spawn_zone__curPositionIdx]
          return true
        return false
      zombie_ai_vehicle_tank_spawner__tankEid = createEntity(zombie_ai_vehicle_tank_spawner__template) <| $(var init : ComponentsInitializer)
        set(init, "transform", validate_vehicle_position(transform))
        set(init, "ai_vehicle_tank__curObjective", objectiveEid)
        set(init, "ai_vehicle_tank__checkedObjective", objectiveEid)
        set(init, "ai_vehicle_tank__curObjectivePosIdx", zombie_tank_spawn_zone__curPositionIdx)
        set(init, "ai_vehicle_tank__destination", dest)
        set(init, "ai_vehicle_tank__pathFindingStateTimeoutAt", get_sync_time() + 10.0)
      let isLastPositionInObjective = zombie_tank_spawn_zone__curPositionIdx == posCount - 1
      zombie_tank_spawn_zone__curPositionIdx = (zombie_tank_spawn_zone__curPositionIdx + 1) % posCount
      if isLastPositionInObjective
        entity_spawner__curTankSpawnId = (entity_spawner__curTankSpawnId + 1) % length(entity_spawner__tankSpawns)
    return true


def vehicle_spawn_crew(team : int;
                       crew_template : string;
                       player_template : string;
                       vehicle_eid : EntityId)
  query(vehicle_eid) <| $ [es(REQUIRE_NOT=deadEntity)] (vehicle_seats__seatEids : EidList)
    var seats : array<int>
    for seat in vehicle_seats__seatEids
      query(seat) <| $ [es] (seat__ownerEid : EntityId; seat__id : int)
        let hasOwner = query(seat__ownerEid) <| $ [es(REQUIRE_NOT=deadEntity)] () {}
        if !hasOwner
          seats |> push(seat__id)
    if !empty(seats)
      let playerEid = createEntity(player_template) <| $(var init)
        set(init, "canBeLocal", false)
        set(init, "team", team)
      for seatId in seats
        let finalize <- @ <| (crewEid : EntityId)
          sendEvent(playerEid, [[CmdUseVehicleOnSpawn vehicle=vehicle_eid, seatOrderNo=seatId, squad=INVALID_ENTITY_ID, possessed=crewEid]])
        createEntity(crew_template, finalize) <| $(var init)
          set(init, "squad_member__playerEid", playerEid)
          set(init, "team", team)


[es(tag=server)]
def zombie_ai_vehicle_tank_spawner_crew(info : ParallelUpdateFrameDelayed;
                                        eid : EntityId;
                                        zombie_ai_vehicle_tank_spawner__tankEid : EntityId;
                                        var zombie_ai_vehicle_tank_spawner__spawnCrewDelay : float&)
  zombie_ai_vehicle_tank_spawner__spawnCrewDelay -= info.dt
  if zombie_ai_vehicle_tank_spawner__spawnCrewDelay > 0.0
    return
  vehicle_spawn_crew(3, "zombie_ai_vehicle_tank_crew_member", "bot_player", zombie_ai_vehicle_tank_spawner__tankEid)
  destroyEntity(eid)


[es(tag=server, on_appear, REQUIRE=deadEntity)]
def on_zombie_ai_vehicle_tank_after_death(evt : Event;
                                          zombie_ai_vehicle_tank__timeToDestroy : float;
                                          var zombie_ai_vehicle_tank__destroyAtTime : float&)
  zombie_ai_vehicle_tank__destroyAtTime = get_sync_time() + zombie_ai_vehicle_tank__timeToDestroy


[es(tag=server, REQUIRE=deadEntity)]
def destroy_zombie_ai_vehicle_tank_after_death(info : ParallelUpdateFrameDelayed;
                                               eid : EntityId;
                                               vehicle_seats__seatEids : EidList;
                                               zombie_ai_vehicle_tank__destroyAtTime : float)
  if info.curTime < zombie_ai_vehicle_tank__destroyAtTime
    return
  for seatEid in vehicle_seats__seatEids
    query(seatEid) <| $ [es] (seat__ownerEid : EntityId)
      destroyEntity(seat__ownerEid)
  destroyEntity(eid)


[es(REQUIRE=(zombie, deadEntity), on_appear)]
def disable_collision_on_death(evt : Event;
                               var grid_obj__hidden : int&)
  grid_obj__hidden |= int(GridHideFlag EGH_IN_VEHICLE) // dirty hack to disable collision

[es(tag=server, REQUIRE=zombie, REQUIRE_NOT=zombie_no_award)]
def zombie_kills_award_and_stats(evt : EventEntityDied)
  query(evt.offender) <| $ [es] (guid : string; possessedByPlr : EntityId)
    send_award_stat(possessedByPlr, guid, "zombieKills")

[es(tag=server, REQUIRE=destroyEntityOnDie)]
def destroy_entities_on_dead(evt : EventEntityDied;
                             eid : EntityId)
  destroyEntity(eid)

[es(tag=server, track=entity_spawner__curWaveId)]
def current_zombie_wave_scoring(evt : Event; entity_spawner__curWaveId : int)
  query() <| $ [es] (var scoring_player__zombieWaves : int&)
    scoring_player__zombieWaves = entity_spawner__curWaveId

[es(tag=server, track=entity_spawner__curWaveId, REQUIRE=entity_spawner__curWaveId)]
def clean_wave_depends_entities_es(evt : Event)
  query() <| $ [es(REQUIRE=entity_spawner__removeOnWaveEnd)] (eid : EntityId)
    destroyEntity(eid)

[es(tag=server, REQUIRE=zombie, REQUIRE_NOT=zombie_no_award)]
def zombie_killed_by_headshot(evt : EvtEntityKilledToPart;
                              dm_parts__type : StringList)
  query(evt.offender) <| $ [es] (guid : string; possessedByPlr : EntityId)
    if uint(evt.collNodeId) < uint(length(dm_parts__type)) && dm_parts__type[evt.collNodeId] == "head" && evt.damageType == int(DamageType DM_PROJECTILE)
      send_award_stat(possessedByPlr, guid, "zombieHeadshots")

[es(tag=server, track=human_parachute__isDeployed)]
def reset_zombie_beh_tree_after_parachute_closing(evt : Event; eid : EntityId; human_parachute__isDeployed : bool;
                                                  var beh_tree__refs__behaviour : das_string&; beh_tree__data__aggressiveBeh : string)
  if !human_parachute__isDeployed
    beh_tree__refs__behaviour := beh_tree__data__aggressiveBeh
    DngBehTree::load_beh_tree_from_ecs(eid)

[es(tag=server)]
def loot_points_for_boss_zombie_damage(evt : CmdApplyDamage;
                                       paid_loot__pointsPerDamage : float)
  query(evt.offender) <| $ [es] (var paid_loot__points : int&)
    paid_loot__points += int(evt.deltaHp * paid_loot__pointsPerDamage)

[es(tag=server, REQUIRE=hitpoints__alwaysDowned)]
def show_who_downed_player(evt : EventEntityDowned; eid : EntityId)
  let zombieName = get_string(evt.offender, "killLogName", "")
  if zombieName != ""
    using() <| $(var data : Object)
      set(data, "name", zombieName)
      send_net_event(eid, [[CmdHeroLogExEvent event="soldier_downed", key="soldier_downed/downed_by", data=ecs_addr(data)]])
