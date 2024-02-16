module turret_hit_analyzer_common shared
require ecs
require app
require dm
require game.utils.team
require game.es.events
require DngDm
require DagorMath
require DaWeaponProps
require Dacoll
require Ballistics
require BallisticsProps
require BallisticsDm
require PhysMat
require GridCollision
require CollisionTraces
require GamePhys
require SmokeOccluder

enum SimulateMode
  FULL
  FIND_HIT_POS_ONLY


def trace_shootable_objects(from, dir : float3; len : float; ignore_human, ignore_vehicle : EntityId; cb : block<(intersections : IntersectedEntities) : void>)
  using() <| $(var intersections : IntersectedEntities)
    var t1 = len; var t2 = len; var t3 = len
    trace_entities_in_grid(ecs_hash("humans"), from, dir, t1, ignore_human, intersections, SortIntersections NO)
    trace_entities_in_grid(ecs_hash("vehicles"), from, dir, t2, ignore_vehicle, intersections, SortIntersections NO)
    trace_entities_in_grid(ecs_hash("interactable"), from, dir, t3, INVALID_ENTITY_ID, intersections, SortIntersections YES)
    invoke(cb, intersections)

def simulate_shot_entity(eid : EntityId;
                         shell_prop_ids : ShellPropIds;
                         velocity : float;
                         distance : float;
                         ray : Ray3;
                         test_secondary_shatters : bool = false;
                         test_explosion : bool = false;
                         is_volumetric_shell : bool = false)
  var res = -1
  using() <| $(var criticalDamageTesterState : CriticalDamageTesterState#)
    criticalDamageTesterState.damagePropsId = int(shell_prop_ids.damageId)
    criticalDamageTesterState.ballisticsPropsId = int(shell_prop_ids.ballisticsId)
    projectile_get_props(int(shell_prop_ids.shellId)) <| $(projectileProps : ProjectileProps)
      set_critical_damage_tester_state_ballistics_props(criticalDamageTesterState, projectileProps)
      criticalDamageTesterState.mass = projectileProps.mass
    criticalDamageTesterState.speed = velocity
    criticalDamageTesterState.distance = distance
    criticalDamageTesterState.ray = ray
    criticalDamageTesterState.testSecondaryShatters = test_secondary_shatters
    criticalDamageTesterState.testExplosion = test_explosion
    criticalDamageTesterState.volumetricShell = is_volumetric_shell

    critical_damage_test(eid, get_damage_model_params(), /*combine_expl_damage*/ false, criticalDamageTesterState)

    res = int(criticalDamageTesterState.result)
  return res

def simulate_shot(owner_eid : EntityId;
                  shell_prop_ids : ShellPropIds;
                  shoot_tm : float3x4;
                  mode : SimulateMode;
                  var out_hit_pos : float3&;
                  var out_hit_result : int&;
                  turret_hit_analyzer__maxDistance : float)
  out_hit_pos = float3()

  var hitResult = -1
  var quit = false

  projectile_get_props(int(shell_prop_ids.shellId)) <| $(projectileProps : ProjectileProps)
    shell_start_get_props(int(shell_prop_ids.shellId)) <| $(shellStartProps : ShellStartProps)
      using() <| $(var ballistics : ProjectileBallistics#)
        let shootPos = shoot_tm[3]
        let shootDir = shoot_tm[0]

        let maxDistance = min(turret_hit_analyzer__maxDistance, projectileProps.maxDistance)
        let smokeTraceEnd = shootPos + shootDir * maxDistance
        let isBlockedBySmoke = rayhit_smoke_occluders(shootPos, smokeTraceEnd)

        let inVel = shootDir * shellStartProps.speed
        let density = atmosphere_density(shootPos.y)
        ballistics |> projectile_ballistics_setupWithKV(projectileProps, shootPos, inVel, 1.0f, density)

        var distance = 0.0

        let dt = 1.0 / 24.0
        var atTime = 0.0
        while distance <= maxDistance
          let prevPos = ballistics.state.pos

          ballistics |> projectile_ballistics_move(ballistics.state.atTick + 1, dt)

          let curPos = ballistics.state.pos
          let toCurPos = curPos - prevPos
          var len = length(toCurPos)
          let dir = toCurPos * safeinv(len)

          distance += len

          var pmid = 0
          var norm = float3()
          using() <| $(var desc : RendInstDesc#)
            var sceneIntersected = traceray_normalized(prevPos, dir, len, pmid, norm, ETF_ALL, desc, -1)
            let curTime = get_sync_time()
            var waterLen = len
            let end = prevPos + dir * waterLen
            if traceray_water_at_time(prevPos, end, curTime, waterLen)
              if !sceneIntersected
                len += 10.0
                using() <| $(var desc2 : RendInstDesc#)
                  traceray_normalized(prevPos, dir, len, pmid, norm, ETF_ALL, desc2, -1)
              pmid = get_material_id("water3d")
              norm = float3(0.0, 1.0, 0.0)
              sceneIntersected = true

            var vehicleEid = INVALID_ENTITY_ID
            var projectileOwnerTeam = TEAM_UNASSIGNED
            query(owner_eid) <| $ [es] (human_anim__vehicleSelected : EntityId; team : int)
              vehicleEid = human_anim__vehicleSelected
              projectileOwnerTeam = team

            trace_shootable_objects(prevPos, dir, len, owner_eid, vehicleEid) <| $(sortedIntersectedList : IntersectedEntities)
              var entitiesIntersected = false
              if length(sortedIntersectedList) > 0
                for isect in sortedIntersectedList
                  let eid = isect.eid
                  let newHitPos = prevPos + dir * isect.t
                  out_hit_pos = newHitPos

                  let invul = check_shell_invulnerability(eid, distance, dir, newHitPos, curTime)
                  if invul.isInvulnerable
                    sendEvent(isect.eid, [[ProjectileHitInvulnerableNotification hitPos=isect.pos, hitDir=dir]])
                    continue
                  if has(eid, "turretHitAlwaysEffective")
                    hitResult = int(TestResult EFFECTIVE)
                    return
                  if has(eid, "turretHitAlwaysIneffective")
                    hitResult = int(TestResult INEFFECTIVE)
                    return

                  var damageModel : DamageModel const?
                  var restrictToTeam = TEAM_UNASSIGNED
                  var team = TEAM_UNASSIGNED
                  var isExploded = false
                  query(eid) <| $ [es] (damage_model : DamageModel const?;
                                        vehicle_seats__restrictToTeam : int = TEAM_UNASSIGNED;
                                        team aka entity_team : int = TEAM_UNASSIGNED;
                                        isExploded aka entity_isExploded : bool = false)
                    damageModel = damage_model
                    restrictToTeam = vehicle_seats__restrictToTeam
                    team = entity_team
                    isExploded = entity_isExploded
                  let isTeamsFriendly = is_teams_friendly(projectileOwnerTeam, team)
                  let isTeamFireAllowed = (!isTeamsFriendly || is_friendly_fire_allowed())
                  let isCorrectRestrictToTeam = (restrictToTeam == TEAM_UNASSIGNED || restrictToTeam != projectileOwnerTeam)
                  if (damageModel != null && !isExploded && isTeamFireAllowed &&
                      isCorrectRestrictToTeam && !invul.haveDeflectedShell && !isBlockedBySmoke)
                    if mode == SimulateMode FULL
                      let t = damageModel.collisionData.boundingSphere.r
                      let velocity = length(ballistics.state.vel)
                      let velDir = ballistics.state.vel * safeinv(velocity)
                      hitResult = simulate_shot_entity(eid, shell_prop_ids, velocity, distance, Ray3(newHitPos - velDir * t, velDir, t * 4.0))
                    quit = true
                    return
                  entitiesIntersected = true
                  hitResult = int(TestResult INEFFECTIVE)
                  return
              if hitResult != -1 || quit
                return
              if sceneIntersected && !entitiesIntersected
                out_hit_pos = prevPos + dir * waterLen
                hitResult = int(TestResult INEFFECTIVE)
                return
          if hitResult != -1 || quit
            break
          atTime += dt

        if quit && hitResult == -1
          return

        if hitResult != -1
          out_hit_result = hitResult
        else
          out_hit_pos = ballistics.state.pos
          out_hit_result = int(TestResult INEFFECTIVE)
