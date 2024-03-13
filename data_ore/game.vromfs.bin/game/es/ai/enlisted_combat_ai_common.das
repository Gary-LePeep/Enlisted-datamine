module enlisted_combat_ai_common shared
require ecs
require math
require dm
require DngDm
require BallisticsProps
require BallisticsDm
require math.random
require DagorMath
require DngWeapon
require AnimV20
require CollRes
require Dacoll
require game.es.dm_ai_common


struct TargetDMAIPoint
  worldPos : float3
  partType : int

def pick_target_dm_ai_points(var out_points : array<TargetDMAIPoint>&; max_points, shoot_pos, target_eid, no_crew, rand_offset, allow_from_front, with_secondary_chance)
  query(target_eid) <| $ [es] (transform : float3x4;
                               damage_model : DamageModel;
                               damage_part_alive : BoolList;
                               collres : CollisionResource;
                               animchar : AnimcharBaseComponent;
                               dm_ai__points : Point3List;
                               dm_ai__pointsInfo : IPoint2List)
    var morePoints : array<TargetDMAIPoint>
    for pt, ptInfo in dm_ai__points, dm_ai__pointsInfo
      let partId = ptInfo.x
      let partType = ptInfo.y

      var pos : float3
      if partId >= 0
        if !damage_part_alive[partId]
          continue
        let collNodeId = get_collision_node_id(damage_model.dmData, partId)
        var nodeTm : float3x4
        collres |> collres_get_collision_node_tm(collNodeId, transform, animchar.nodeTree, nodeTm)
        pos = nodeTm * pt
      else
        pos = transform * pt

      pos.x += rnd_float(-rand_offset.x, rand_offset.x)
      pos.y += rnd_float(-rand_offset.y, rand_offset.y)
      pos.z += rnd_float(-rand_offset.x, rand_offset.x)

      let pointValue = evaluate_dm_ai_point_for_shot(pos, transform, shoot_pos, no_crew, allow_from_front, partType)

      if pointValue == DMAIPointValue PRIMARY
        out_points |> push([[TargetDMAIPoint worldPos=pos, partType=partType]])
      elif pointValue == DMAIPointValue SECONDARY
        morePoints |> push([[TargetDMAIPoint worldPos=pos, partType=partType]])

    if length(out_points) == 0 || rnd_float(0.0, 1.0) < with_secondary_chance
      for point in morePoints
        out_points |> push(point)

  let outPointsLen = length(out_points)
  if outPointsLen > 1
    shuffle(out_points)
    if outPointsLen > max_points
      out_points |> resize(max_points)


def trace_pierce_shot(var out_pos : float3&; shoot_pos, target_pos, shell_vel, shell_id, damage_id, ballistics_id, ballistic_coef, target_eid, chance_try_not_penetrate)
  var shootDir = float3()
  if !calculate_arc_low_start_dir(shoot_pos, target_pos, shell_vel, shootDir)
    return false

  let delta = target_pos - shoot_pos
  let deltaLen = length(delta)

  let dir = normalize(delta)
  var dist = deltaLen
  var norm : float3
  if traceray_normalized(shoot_pos, dir, dist, norm, ETF_DEFAULT)
    return false

  let heightDiffToDist = safediv(delta.y, deltaLen)
  let correctionCoef = cvt(heightDiffToDist, -1.0, 1.0, 2.0, -1.0) * ballistic_coef
  let correctionY = correctionCoef * max(0.0, abs(shootDir.y) * safediv(length(delta.xz), length(shootDir.xz)))

  out_pos = target_pos
  out_pos.y += correctionY

  if abs(correctionY) > 0.5
    let BALLISTIC_TEST_COEF = 0.5
    let delta2 = out_pos - shoot_pos
    let dir2 = normalize(delta2)
    dist = length(delta2) * BALLISTIC_TEST_COEF
    if traceray_normalized(shoot_pos, dir2, dist, norm, ETF_DEFAULT)
      return false

  let HIT_VEL_COEF = 0.9
  let hitVel = shell_vel * HIT_VEL_COEF

  var res = -1
  using() <| $(var criticalDamageTesterState : CriticalDamageTesterState#)
    criticalDamageTesterState.damagePropsId = damage_id
    criticalDamageTesterState.ballisticsPropsId = ballistics_id
    projectile_get_props(shell_id) <| $(projectileProps : ProjectileProps)
      set_critical_damage_tester_state_ballistics_props(criticalDamageTesterState, projectileProps)
      criticalDamageTesterState.mass = projectileProps.mass
    criticalDamageTesterState.speed = hitVel
    criticalDamageTesterState.distance = deltaLen
    criticalDamageTesterState.ray.start = shoot_pos
    criticalDamageTesterState.ray.dir = dir
    criticalDamageTesterState.ray.length = deltaLen
    criticalDamageTesterState.testSecondaryShatters = false
    criticalDamageTesterState.testExplosion = true
    criticalDamageTesterState.volumetricShell = true

    critical_damage_test(target_eid, get_damage_model_params(), /*combine_expl_damage*/ false, criticalDamageTesterState)

    res = int(criticalDamageTesterState.result)

  if res == int(TestResult EFFECTIVE) || res == int(TestResult POSSIBLE_EFFECTIVE)
    return true

  if res == int(TestResult NOT_PENETRATE)
    if rnd_float(0.0, 100.0) < chance_try_not_penetrate
      return true

  if rnd_float(0.0, 100.0) < 10.0
    return true

  return false
