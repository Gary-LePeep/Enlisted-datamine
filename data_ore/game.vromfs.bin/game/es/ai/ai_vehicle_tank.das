require ecs
require ecs.safe
require app
require pathfinder
require danetlibs.pathfinder.main.pathfinder_common
require danetlibs.dm.dm_events
require game.es.events
require enlisted.events_enlisted
require enlisted.game.es.ai_poly_areas_common
require DagorConsole
require DagorRandom
require DagorMath
require DagorMathUtils
require math.base
require math.random
require math
require zones
require Dacoll
require BallisticsProps
require BallisticsDm
require PhysObj
require DngPhysObj
require DaWeaponProps
require turrets
require common_shooter.es.forestall_common
require common_shooter.events_common_shooter
require common_shooter.es.weapon.turret_common
require game.utils.team
require walkerai
require DngNet
require AnimV20
require GeomNodeTree
require vehicle
require Grid
require SmokeOccluder
require Gun
require dm
require DngDm
require DngWeapon
require CollRes
require game.es.dm_ai_common
require game.es.vehicle.vehicle_seats_common
require game.es.ai.enlisted_combat_ai_common


[event(unicast)]
struct CmdAiVehicleTankUpdateObjective {}


enum AiTankObjectiveType
  CAPZONE
  CUSTOM


enum AiTankTargetType
  HUMAN
  VEHICLE


enum AiTankPathFindingState
  UPDATING_DESTINATION
  UPDATING_PATH
  PATH_FOUND


enum AiTankMotionState
  STAND_BY
  MOVE
  TRY_TO_GET_UNSTUCK
  TRY_TO_EXIT_OBSTACLE
  HELP_TARGETTING


enum AiTankShootState
  READY
  BURST
  SHORT_PAUSE
  LONG_PAUSE


enum AiTankTargetState
  IDLE
  TARGET
  TARGET_FAILURE


def update_tank_next_position(planned_path : Point3List; max_step_size : float; var next_position : float3&; var recorded_min_distance : float&)
  recorded_min_distance = FLT_MAX
  if length(planned_path) == 1
    next_position = planned_path[0]
  elif !empty(planned_path)
    let diff = planned_path[1] - planned_path[0]
    let lenSq = length_sq(diff)
    if lenSq <= square(max_step_size)
      next_position = 0.5 * (planned_path[0] + planned_path[1]) // this averaging helps the tank take smoother turns
    else
      let dir = diff / sqrt(lenSq)
      next_position = planned_path[0] + 0.5 * max_step_size * dir


def erase_reached_points_in_path(tank_pos : float3; count : int; threshold : float; var path : Point3List&)
  let pointCount = min(count, length(path))
  for a in range(pointCount)
    let i = pointCount - a - 1
    if length_sq(path[i] - tank_pos) <= square(threshold)
      path |> erase(0, i + 1)
      return true
  return false


[es(tag=server, before=vehicle_input_driver_es, REQUIRE_NOT=deadEntity)]
def ai_vehicle_tank_driver_es(info : ParallelUpdateFrameDelayed;
                              transform : float3x4;
                              turret_control__gunEids : EidList;
                              ai_vehicle_tank__maxThrottle : float;
                              ai_vehicle_tank__steeringDeadZone : float;
                              ai_vehicle_tank__steeringSmoothness : float;
                              ai_vehicle_tank__nextPositionReachedThreshold : float;
                              ai_vehicle_tank__plannedPathLengthForSlowingDown : int;
                              ai_vehicle_tank__nextPositionReachedWaitTime : float;
                              ai_vehicle_tank__maxStepSize : float;
                              ai_vehicle_tank__motionState : int;
                              var ai_vehicle_tank__plannedPath : Point3List&;
                              var ai_vehicle_tank__nextPosition : float3&;
                              var ai_vehicle_tank__nextPositionRecordedMinDistance : float&;
                              var ai_vehicle_tank__motionStateTimeoutAt : float&;
                              var vehicle_net_phys : VehiclePhysActor&)
  var steering = 0.0
  var throttle = 0.0
  var brake = 1.0

  let diff = ai_vehicle_tank__nextPosition - transform[3]

  if length_sq(diff) <= square(ai_vehicle_tank__nextPositionReachedThreshold)
    if !empty(ai_vehicle_tank__plannedPath)
      ai_vehicle_tank__plannedPath |> erase(0)
      if ai_vehicle_tank__motionState == int(AiTankMotionState MOVE)
        ai_vehicle_tank__motionStateTimeoutAt = get_sync_time() + ai_vehicle_tank__nextPositionReachedWaitTime
      update_tank_next_position(ai_vehicle_tank__plannedPath,
                                ai_vehicle_tank__maxStepSize,
                                ai_vehicle_tank__nextPosition,
                                ai_vehicle_tank__nextPositionRecordedMinDistance)

  if ai_vehicle_tank__motionState == int(AiTankMotionState HELP_TARGETTING)
    for gunEid in turret_control__gunEids
      let success = query(gunEid) <| $ [es(REQUIRE=controlledByTankAiGunner)] (turret_aim__shootToPos : float3; turret_state : TurretState)
        var moveDir = turret_aim__shootToPos - transform[3]
        moveDir.y = 0.0
        moveDir = normalize(moveDir)
        let vehicleDirAngle = dir_to_angles(turret_state.shoot.dir)
        let targetDir = dir_to_angles(moveDir)
        let normAng = renorm_ang(targetDir.x, vehicleDirAngle.x) - vehicleDirAngle.x
        throttle = 0.0
        if abs(normAng) > ai_vehicle_tank__steeringDeadZone
          steering = sign(-normAng)
          brake = 0.0
      if success
        break
  else
    var moveDir = diff
    moveDir.y = 0.0
    let dist = length(moveDir)
    moveDir *= safeinv(dist)

    let vehicleDirAngle = dir_to_angles(transform[0])
    let targetDir = dir_to_angles(moveDir)
    let normAng = renorm_ang(targetDir.x, vehicleDirAngle.x) - vehicleDirAngle.x

    if ai_vehicle_tank__motionState == int(AiTankMotionState TRY_TO_EXIT_OBSTACLE)
      throttle = -1.0
      steering = 0.0
      brake = 0.0
    elif ai_vehicle_tank__motionState == int(AiTankMotionState STAND_BY) || empty(ai_vehicle_tank__plannedPath)
      throttle = 0.0
      steering = 0.0
    elif abs(normAng) > ai_vehicle_tank__steeringDeadZone && vehicle_net_phys.phys.haveSeparateBrakes
      if ai_vehicle_tank__motionState == int(AiTankMotionState MOVE)
        throttle = 0.0
        steering = sign(-normAng)
        brake = 0.0
      elif ai_vehicle_tank__motionState == int(AiTankMotionState TRY_TO_GET_UNSTUCK)
        throttle = -1.0
        steering = sign(normAng)
        brake = 0.0
    else
      throttle = clamp(cvt(abs(normAng), 0.0, ai_vehicle_tank__steeringDeadZone, 1.0, 0.5) * ai_vehicle_tank__maxThrottle, 0.0, 1.0)
      if length(ai_vehicle_tank__plannedPath) <= ai_vehicle_tank__plannedPathLengthForSlowingDown
        throttle = safediv(throttle, float(1 + ai_vehicle_tank__plannedPathLengthForSlowingDown - length(ai_vehicle_tank__plannedPath)))
        if length(ai_vehicle_tank__plannedPath) == 1
          throttle *= max(1.0, dist / ai_vehicle_tank__nextPositionReachedThreshold)
      steering = clamp(-normAng * ai_vehicle_tank__steeringSmoothness, -1.0, 1.0)
      brake = 0.0
      if ai_vehicle_tank__motionState == int(AiTankMotionState TRY_TO_GET_UNSTUCK)
        throttle *= -1.0
        steering *= -1.0

  assume producedCT = vehicle_net_phys.phys.producedCT

  producedCT |> ground_control_state_setAutomaticTransmission(true)
  producedCT |> ground_control_state_setKeepDrivingDirectionMode(false)

  producedCT |> ground_control_state_setAxisValue(EGroundControlAxis GCA_STEERING, steering)
  producedCT |> ground_control_state_setAxisValue(EGroundControlAxis GCA_THROTTLE, throttle)
  producedCT |> ground_control_state_setAxisValue(EGroundControlAxis GCA_HAND_BRAKE, brake)
  producedCT |> ground_control_state_setAxisValue(EGroundControlAxis GCA_BRAKE_LEFT, brake)
  producedCT |> ground_control_state_setAxisValue(EGroundControlAxis GCA_BRAKE_RIGHT, brake)


def remove_close_path_points(pos : float3; threshold : float; var path : Point3List&)
  var removeCount = 0
  let thresholdSq = square(threshold)
  for i in iter_range(path)
    if length_sq(path[i] - pos) <= thresholdSq
      removeCount++
    else
      break
  if removeCount > 0
    erase(path, 0, removeCount)

[unused_argument(nav_mesh_idx, poly_ref, flags)]
def get_poly_flags_ex2(nav_mesh_idx : int; poly_ref : dtPolyRef; var flags : uint16&)
  static_if typeinfo(builtin_function_exists @@ < (arg0 : int; arg1 : dtPolyRef; var arg2 : uint16 &) : bool > pathfinder::get_poly_flags_ex)
    return get_poly_flags_ex(nav_mesh_idx, poly_ref, flags)
  else
    flags = flags //so the warning about unnecessary 'var' in front of 'flags' shuts up
    return false


def try_find_tank_path(team : int;
                       tank_pos : float3;
                       dest : float3;
                       step_size : float;
                       max_length : float;
                       next_position_threshold : float;
                       ignore_battle_area : bool;
                       var out_path : Point3List&;
                       horz_dist : float = 0.5;
                       path_slop : float = 0.25)
  out_path |> clear()

  var isNavmeshUpdatePending = false
  find_query() <| $ [es] (battle_area_navmesh_manager__areaEids : EidList)
    if !empty(battle_area_navmesh_manager__areaEids)
      isNavmeshUpdatePending = true
    return true
  if isNavmeshUpdatePending
    return false

  let battleAreaFlags = ignore_battle_area ? uint16(PolyFlag POLYFLAG_GROUND) : team_to_tank_navmesh_poly_flags(team)

  var destTriangle : NavMeshTriangle
  if !get_triangle_by_pos_ex(NM_EXT_1, dest, 0.5, destTriangle)
    return false
  var destFlags : uint16
  get_poly_flags_ex2(NM_EXT_1, destTriangle.polyRef, destFlags)
  if (uint(destFlags) & uint(battleAreaFlags)) == 0u || (uint(destFlags) & uint(EnlPolyFlags POLYFLAG_TANK_OBSTACLE)) != 0u
    return false

  var tankTriangle : NavMeshTriangle
  if !get_triangle_by_pos_ex(NM_EXT_1, tank_pos, 0.5, tankTriangle)
    return false
  var tankFlags : uint16
  get_poly_flags_ex2(NM_EXT_1, tankTriangle.polyRef, tankFlags)
  if (uint(tankFlags) & uint(EnlPolyFlags POLYFLAG_TANK_OBSTACLE)) != 0u
    return false

  var res = true
  using(tank_pos, dest, float3(horz_dist, FLT_MAX, horz_dist)) <| $(var req : FindRequest#)
    req.includeFlags = int(battleAreaFlags)
    req.excludeFlags = int(EnlPolyFlags POLYFLAG_TANK_OBSTACLE)
    let findPathResult = find_path_ex(NM_EXT_1, req, step_size, path_slop) <| $(data)
      for point in data
        out_path |> push(point)
    if findPathResult != FindPathResult FPR_FULL
      out_path |> clear()
      res = false

  let maxPointCount = int(ceil(max_length / step_size))
  if length(out_path) > maxPointCount
    resize(out_path, maxPointCount)
  remove_close_path_points(tank_pos, next_position_threshold, out_path)

  return res


def can_capzone_be_attacked(team : int; capzone__owningTeam : int; capzone__mustBeCapturedByTeam : int; capzone__onlyTeamCanCapture : int)
  return (capzone__owningTeam != team &&
    (capzone__onlyTeamCanCapture == TEAM_UNASSIGNED && capzone__mustBeCapturedByTeam == TEAM_UNASSIGNED ||
    capzone__onlyTeamCanCapture == team ||
    capzone__mustBeCapturedByTeam == team))


[es(tag=server, on_event=CmdAiVehicleTankUpdateObjective, REQUIRE=aiVehicleTankGoToCapzones)]
def ai_tank_update_objective_capzone(evt : Event;
                                     team : int;
                                     ai_vehicle_tank__curObjective : EntityId;
                                     var ai_vehicle_tank__checkedObjective : EntityId&)
  var attackableZones : array<EntityId>
  var defendableZones : array<EntityId>
  var isCurZoneAttackable = false
  var isCurZoneDefendable = false

  query(ai_vehicle_tank__curObjective) <| $ [es] (active : bool;
                                                  ai_tank_objective__positions : Point3List;
                                                  capzone__owningTeam : int = -1;
                                                  capzone__mustBeCapturedByTeam : int = -1;
                                                  capzone__onlyTeamCanCapture : int = -1)
    if !active || empty(ai_tank_objective__positions)
      return
    if can_capzone_be_attacked(team, capzone__owningTeam, capzone__mustBeCapturedByTeam, capzone__onlyTeamCanCapture)
      isCurZoneAttackable = true
    else
      isCurZoneDefendable = true

  if isCurZoneAttackable
    ai_vehicle_tank__checkedObjective = ai_vehicle_tank__curObjective
    return

  query() <| $ [es] (eid : EntityId;
                     active : bool;
                     ai_tank_objective__positions : Point3List;
                     capzone__owningTeam : int = -1;
                     capzone__mustBeCapturedByTeam : int = -1;
                     capzone__onlyTeamCanCapture : int = -1)
    if !active || empty(ai_tank_objective__positions) || eid == ai_vehicle_tank__curObjective
      return
    if can_capzone_be_attacked(team, capzone__owningTeam, capzone__mustBeCapturedByTeam, capzone__onlyTeamCanCapture)
      attackableZones |> push(eid)
    else
      defendableZones |> push(eid)

  if !empty(attackableZones)
    ai_vehicle_tank__checkedObjective = attackableZones[rnd_int(0, length(attackableZones) - 1)]
  elif isCurZoneDefendable
    ai_vehicle_tank__checkedObjective = ai_vehicle_tank__curObjective
  elif !empty(defendableZones)
    ai_vehicle_tank__checkedObjective = defendableZones[rnd_int(0, length(defendableZones) - 1)]
  else
    ai_vehicle_tank__checkedObjective = INVALID_ENTITY_ID


def check_or_choose_new_custom_objective(cur_objective : EntityId)
  var isCurObjActive = false
  var activeObjectives : array<EntityId>

  query(cur_objective) <| $ [es] (active : bool)
    isCurObjActive = active

  if isCurObjActive
    return cur_objective

  query() <| $ [es(REQUIRE=ai_tank_objective_custom)] (eid : EntityId; active : bool)
    if !active
      return
    activeObjectives |> push(eid)

  if !empty(activeObjectives)
    return activeObjectives[rnd_int(0, length(activeObjectives) - 1)]
  return INVALID_ENTITY_ID


[es(tag=server, before=ai_vehicle_driver_es, REQUIRE_NOT=deadEntity)]
def ai_vehicle_tank_update_es(info : ParallelUpdateFrameDelayed;
                              eid : EntityId;
                              transform : float3x4;
                              turret_control__gunEids : EidList;
                              ai_vehicle_tank__targetScoreThresholdForStanding : float;
                              ai_vehicle_tank__updateInterval : float;
                              ai_vehicle_tank__destination : float3;
                              ai_vehicle_tank__nextPositionTooFarThreshold : float;
                              ai_vehicle_tank__nextPositionReachedWaitTime : float;
                              ai_vehicle_tank__nextPositionReachedThreshold : float;
                              ai_vehicle_tank__nextPositionRecordedMinDistanceStep : float;
                              ai_vehicle_tank__maxStepSize : float;
                              ai_vehicle_tank__plannedPathCheckedPointCount : int;
                              ai_vehicle_tank__tryToGetUnstuckWaitTime : float;
                              ai_vehicle_tank__tryToExitObstacleWaitTime : float;
                              ai_vehicle_tank__updatePathWaitTime : float;
                              ai_vehicle_tank__curObjective : EntityId&;
                              ai_vehicle_tank__checkedObjective : EntityId;
                              var ai_vehicle_tank__plannedPath : Point3List&;
                              var ai_vehicle_tank__nextPosition : float3&;
                              var ai_vehicle_tank__motionState : int&;
                              var ai_vehicle_tank__motionStateTimeoutAt : float&;
                              var ai_vehicle_tank__nextUpdateAt : float&;
                              var ai_vehicle_tank__nextPositionRecordedMinDistance : float&;
                              var ai_vehicle_tank__pathFindingState : int&;
                              var ai_vehicle_tank__pathFindingStateTimeoutAt : float&)
  if !pathfinder_is_loaded_ex(NM_EXT_1) || ai_vehicle_tank__nextUpdateAt > info.curTime
    return
  ai_vehicle_tank__nextUpdateAt = info.curTime + ai_vehicle_tank__updateInterval

  if erase_reached_points_in_path(transform[3], ai_vehicle_tank__plannedPathCheckedPointCount, ai_vehicle_tank__nextPositionReachedThreshold, ai_vehicle_tank__plannedPath)
    if ai_vehicle_tank__motionState == int(AiTankMotionState MOVE)
      ai_vehicle_tank__motionStateTimeoutAt = get_sync_time() + ai_vehicle_tank__nextPositionReachedWaitTime
    update_tank_next_position(ai_vehicle_tank__plannedPath,
                              ai_vehicle_tank__maxStepSize,
                              ai_vehicle_tank__nextPosition,
                              ai_vehicle_tank__nextPositionRecordedMinDistance)

  var isValuableTargetFound = false
  for gunEid in turret_control__gunEids
    query(gunEid) <| $ [es(REQUIRE=controlledByTankAiGunner)] (tank_turret_ai__targetScore : float)
      if tank_turret_ai__targetScore < ai_vehicle_tank__targetScoreThresholdForStanding
        isValuableTargetFound = true
    if isValuableTargetFound
      break

  if ai_vehicle_tank__motionState != int(AiTankMotionState MOVE)
    ai_vehicle_tank__nextPositionRecordedMinDistance = FLT_MAX

  var tankTriangle : NavMeshTriangle
  var exitedObstacle = false

  //transitions of motion state

  if isValuableTargetFound
    ai_vehicle_tank__motionState = int(AiTankMotionState HELP_TARGETTING)
  else
    var tankFlags = uint16(0)
    let isInsideNavMesh = get_triangle_by_pos_ex(NM_EXT_1, transform[3], 0.5, tankTriangle)
    if isInsideNavMesh
      get_poly_flags_ex2(NM_EXT_1, tankTriangle.polyRef, tankFlags)
    let isTankInsideObstacle = (uint(tankFlags) & uint(EnlPolyFlags POLYFLAG_TANK_OBSTACLE)) != 0u
    if (isTankInsideObstacle && ai_vehicle_tank__pathFindingState != int(AiTankPathFindingState PATH_FOUND)
        && (ai_vehicle_tank__motionState == int(AiTankMotionState MOVE) || ai_vehicle_tank__motionState == int(AiTankMotionState TRY_TO_EXIT_OBSTACLE)))
      ai_vehicle_tank__motionState = int(AiTankMotionState TRY_TO_EXIT_OBSTACLE)
      ai_vehicle_tank__motionStateTimeoutAt = info.curTime + ai_vehicle_tank__tryToExitObstacleWaitTime
    elif (ai_vehicle_tank__motionState == int(AiTankMotionState STAND_BY) ||
          ai_vehicle_tank__motionState == int(AiTankMotionState HELP_TARGETTING) ||
          (ai_vehicle_tank__motionState == int(AiTankMotionState TRY_TO_EXIT_OBSTACLE) ||
          ai_vehicle_tank__motionState == int(AiTankMotionState TRY_TO_GET_UNSTUCK)) && info.curTime > ai_vehicle_tank__motionStateTimeoutAt)
      exitedObstacle = ai_vehicle_tank__motionState == int(AiTankMotionState TRY_TO_EXIT_OBSTACLE)
      ai_vehicle_tank__motionState = int(AiTankMotionState MOVE)
      ai_vehicle_tank__motionStateTimeoutAt = info.curTime + ai_vehicle_tank__nextPositionReachedWaitTime
    elif ai_vehicle_tank__motionState == int(AiTankMotionState MOVE)
      let distSq = length_sq(ai_vehicle_tank__nextPosition - transform[3])
      if distSq <= square(ai_vehicle_tank__nextPositionRecordedMinDistance - ai_vehicle_tank__nextPositionRecordedMinDistanceStep)
        ai_vehicle_tank__motionStateTimeoutAt = info.curTime + ai_vehicle_tank__nextPositionReachedWaitTime
        ai_vehicle_tank__nextPositionRecordedMinDistance = sqrt(distSq)
      elif info.curTime > ai_vehicle_tank__motionStateTimeoutAt
        if !empty(ai_vehicle_tank__plannedPath)
          ai_vehicle_tank__motionState = int(AiTankMotionState TRY_TO_GET_UNSTUCK)
        ai_vehicle_tank__motionStateTimeoutAt = info.curTime + ai_vehicle_tank__tryToGetUnstuckWaitTime

  //update ai_vehicle_tank__checkedObjective depending on the chosen strategy
  sendEvent(eid, [[CmdAiVehicleTankUpdateObjective]])

  //transtions of pathfinding state

  if ai_vehicle_tank__curObjective != ai_vehicle_tank__checkedObjective
    ai_vehicle_tank__pathFindingState = int(AiTankPathFindingState UPDATING_DESTINATION)
  elif ai_vehicle_tank__pathFindingState == int(AiTankPathFindingState PATH_FOUND)
    if (exitedObstacle ||
        length_sq(ai_vehicle_tank__nextPosition - transform[3]) > square(ai_vehicle_tank__nextPositionTooFarThreshold) ||
        empty(ai_vehicle_tank__plannedPath) && length_sq(ai_vehicle_tank__destination - transform[3]) > square(ai_vehicle_tank__nextPositionTooFarThreshold))
      ai_vehicle_tank__pathFindingState = int(AiTankPathFindingState UPDATING_PATH)
      ai_vehicle_tank__pathFindingStateTimeoutAt = info.curTime + ai_vehicle_tank__updatePathWaitTime
  elif ai_vehicle_tank__pathFindingState == int(AiTankPathFindingState UPDATING_PATH)
    if info.curTime > ai_vehicle_tank__pathFindingStateTimeoutAt
      ai_vehicle_tank__pathFindingState = int(AiTankPathFindingState UPDATING_DESTINATION)


[es(tag=server, after=ai_vehicle_tank_update_es, REQUIRE_NOT=deadEntity)]
def ai_vehicle_tank_path_finding_es(info : ParallelUpdateFrameDelayed;
                                    transform : float3x4;
                                    team : int;
                                    ai_vehicle_tank__updatingPathTriesPerFrame : float;
                                    ai_vehicle_tank__updatingDestinationTriesPerFrame : float;
                                    ai_vehicle_tank__stepSize : float;
                                    ai_vehicle_tank__maxStepSize : float;
                                    ai_vehicle_tank__maxPathLength : float;
                                    ai_vehicle_tank__nextPositionReachedThreshold : float;
                                    ai_vehicle_tank__checkedObjective : EntityId;
                                    ai_vehicle_tank__ignoreBattleArea : bool;
                                    var ai_vehicle_tank__pathFindingState : int&;
                                    var ai_vehicle_tank__curObjective : EntityId&;
                                    var ai_vehicle_tank__curObjectivePosIdx : int&;
                                    var ai_vehicle_tank__plannedPath : Point3List&;
                                    var ai_vehicle_tank__destination : float3&;
                                    var ai_vehicle_tank__nextPosition : float3&;
                                    var ai_vehicle_tank__nextPositionRecordedMinDistance : float&;
                                    var ai_vehicle_tank__pathFindingTryCountRemainder : float&)
  if ai_vehicle_tank__pathFindingState == int(AiTankPathFindingState UPDATING_DESTINATION)
    using() <| $(var new_path : Point3List)
      query(ai_vehicle_tank__checkedObjective) <| $ [es] (ai_tank_objective__positions : Point3List;
                                                          ai_tank_objective__positionCountsPerType : IntList;
                                                          ai_tank_objective__probabilityPerPositionType : FloatList)
        //ai_vehicle_tank__updatingDestinationTriesPerFrame can be any positive number.
        //If it is less than 1.0, pathfinding will be skipped on some frames.
        //If greater than 1.0, pathfinding will happen every frame, possibly more than once
        //Note: the end position is chosen randomly from a list of positions each pathfinding attempt
        ai_vehicle_tank__pathFindingTryCountRemainder += ai_vehicle_tank__updatingDestinationTriesPerFrame
        let tryCountThisFrame = floor(ai_vehicle_tank__pathFindingTryCountRemainder)
        ai_vehicle_tank__pathFindingTryCountRemainder -= tryCountThisFrame

        for _ in range(int(tryCountThisFrame))
          var positionType = -1
          let typeRnd = rnd_float(0.0, 1.0)
          var cumulProb = 0.0
          var beginPosIdx = 0
          var endPosIdx = 0

          for i in iter_range(ai_tank_objective__probabilityPerPositionType)
            beginPosIdx = endPosIdx
            endPosIdx = beginPosIdx + ai_tank_objective__positionCountsPerType[i]
            cumulProb += ai_tank_objective__probabilityPerPositionType[i]
            if ai_tank_objective__positionCountsPerType[i] != 0 && typeRnd <= cumulProb
              positionType = i
              break

          if positionType < 0 // should not normally be possible
            continue

          let posIdx = rnd_int(beginPosIdx, endPosIdx - 1)
          let pos = ai_tank_objective__positions[posIdx]
          if try_find_tank_path(team, transform[3], pos, ai_vehicle_tank__stepSize, ai_vehicle_tank__maxPathLength,
                                ai_vehicle_tank__nextPositionReachedThreshold, ai_vehicle_tank__ignoreBattleArea, new_path)
            ai_vehicle_tank__pathFindingState = int(AiTankPathFindingState PATH_FOUND)
            ai_vehicle_tank__plannedPath := new_path
            ai_vehicle_tank__curObjective = ai_vehicle_tank__checkedObjective
            ai_vehicle_tank__curObjectivePosIdx = posIdx
            ai_vehicle_tank__destination = pos
            update_tank_next_position(ai_vehicle_tank__plannedPath,
                                      ai_vehicle_tank__maxStepSize,
                                      ai_vehicle_tank__nextPosition,
                                      ai_vehicle_tank__nextPositionRecordedMinDistance)
            break
  elif ai_vehicle_tank__pathFindingState == int(AiTankPathFindingState UPDATING_PATH)
    using() <| $(var new_path : Point3List)
      //ai_vehicle_tank__updatingPathTriesPerFrame can be less or equal to 1.0.
      //If less than 1.0, pathfinding will be skipped on some frames.
      //If equal to 1.0, pathfinding will happen once per every frame
      //There's no point in ai_vehicle_tank__updatingPathTriesPerFrame being greater than 1.0
      //because the pathfinding algorithm would yield the same results in the same frame
      //(the start and end positions are the same)
      ai_vehicle_tank__pathFindingTryCountRemainder += ai_vehicle_tank__updatingPathTriesPerFrame
      if ai_vehicle_tank__pathFindingTryCountRemainder >= 1.0
        if try_find_tank_path(team, transform[3], ai_vehicle_tank__destination, ai_vehicle_tank__stepSize,
                              ai_vehicle_tank__maxPathLength, ai_vehicle_tank__nextPositionReachedThreshold,
                              ai_vehicle_tank__ignoreBattleArea, new_path)
          ai_vehicle_tank__pathFindingState = int(AiTankPathFindingState PATH_FOUND)
          ai_vehicle_tank__plannedPath := new_path
          update_tank_next_position(ai_vehicle_tank__plannedPath,
                                    ai_vehicle_tank__maxStepSize,
                                    ai_vehicle_tank__nextPosition,
                                    ai_vehicle_tank__nextPositionRecordedMinDistance)
      ai_vehicle_tank__pathFindingTryCountRemainder -= floor(ai_vehicle_tank__pathFindingTryCountRemainder)


def get_forestall_or(owner_pos, owner_vel, target_pos, target_vel : float3; gun_eid : EntityId; default_val : float3)
  var res = default_val
  query(gun_eid) <| $ [es] (gun__curShellId : ShellPropIds)
    projectile_get_props(int(gun__curShellId.ballisticsId)) <| $(ballisticsProps : ProjectileProps)
      shell_start_get_props(int(gun__curShellId.shellId)) <| $(shellStartProps : ShellStartProps)
        let muzzleVelocity = shellStartProps.speed
        let forestall = get_forestall_pos(owner_pos, owner_vel, ballisticsProps, muzzleVelocity, target_pos, target_vel)
        if forestall.valid
          res = forestall.pos
  return res


struct AiGunnerTarget
  pos : float3 = float3(0, 0, 0)
  vel : float3 = float3(0, 0, 0)
  active : bool = false
  partType : int = -1


def get_target_pos(owner_pos, owner_vel, prev_target_pos : float3; prev_target_active : bool; prev_target_part_type : int; gun_eid, target_eid : EntityId; update_dm_target : bool)
  var target = AiGunnerTarget()
  query(target_eid) <| $ [es] (ai_target : Target; vehicle : Tag const?; ai_target__fixedAimOffset : float3 = float3())
    if !ai_target.isAlive
      return
    if vehicle == null
      target.pos = ai_target.targetPos
      target.active = true
    elif !update_dm_target
      target.pos = prev_target_pos
      target.active = prev_target_active
      target.partType = prev_target_part_type
    else
      let MAX_POINTS_PER_TARGET = 5
      let CHANCE_TRY_NOT_PENETRATE = 0.7
      let ignoreWithNoCrew = false
      let noCrew = ignoreWithNoCrew || !is_vehicle_with_alive_crew(target_eid)
      let withSecondaryChance = 0.25
      var targetDmAiPoints : array<TargetDMAIPoint>
      pick_target_dm_ai_points(targetDmAiPoints, MAX_POINTS_PER_TARGET, owner_pos, target_eid, noCrew, /*rand_offset*/ float2(), /*allow_from_front*/ true, withSecondaryChance)
      query(gun_eid) <| $ [es] (gun__curShellId : ShellPropIds; combatBallisticCoef : float = 0.0)
        for targetDmAiPoint in targetDmAiPoints
          let pos = targetDmAiPoint.worldPos
          var correctedPos : float3
          var runShootVel = 50.0
          shell_start_get_props(int(gun__curShellId.shellId)) <| $(shellStartProps : ShellStartProps)
            runShootVel = shellStartProps.speed
          if trace_pierce_shot(correctedPos, owner_pos, pos, runShootVel, int(gun__curShellId.shellId), int(gun__curShellId.damageId), int(gun__curShellId.ballisticsId), combatBallisticCoef, target_eid, CHANCE_TRY_NOT_PENETRATE)
            target.pos = correctedPos
            target.partType = targetDmAiPoint.partType
            target.active = true
            return
    target.vel = ai_target.velocity

    if length_sq(target.vel) > 1.0
      target.pos = get_forestall_or(owner_pos, owner_vel, target.pos, target.vel, gun_eid, target.pos)
    target.pos += ai_target__fixedAimOffset
  return target


def init_targets(turret_pos : float3;
                 owner_eid : EntityId;
                 owner_team : int;
                 prev_target_eid : EntityId;
                 max_dist : float;
                 var out_targets : EidList&;
                 var cur_target_eid : EntityId&)
  cur_target_eid = INVALID_ENTITY_ID
  out_targets |> clear()

  for_each_entity_in_grid([[uint[] ecs_hash("humans"); ecs_hash("vehicles")]], BSphere3(turret_pos, max_dist), GridEntCheck BOUNDING) <| $(eid : EntityId)
    query(eid) <| $ [es(REQUIRE=targetForTankAiGunner)] (eid : EntityId; team : int; ai_target : Target; isInVehicleHidden : bool = false)
      if owner_eid == eid || !ai_target.isAlive || team == TEAM_UNASSIGNED || is_teams_friendly(owner_team, team) || isInVehicleHidden
        return
      if prev_target_eid == eid
        cur_target_eid = prev_target_eid
      else
        out_targets |> push(eid)

  shuffle(out_targets)
  if cur_target_eid != INVALID_ENTITY_ID
    out_targets |> push(cur_target_eid, 0)


struct TargetScoreSettings
  angleScoreMult : float = 4.0
  distanceScoreMult : float = 1.0
  targetRetentionScoreMult : float = 0.2


def calc_target_score(target_eid : EntityId;
                      prev_target_eid : EntityId;
                      turret_pos : float3;
                      turret_initial_itm : float3x4;
                      turret_itm : float3x4;
                      ai_target : Target;
                      score_mult : float;
                      max_dist : float;
                      min_dist : float;
                      limit_angles : float4;
                      limit_vision_angles : float4;
                      settings : TargetScoreSettings;
                      var attackers : Object&)
  let initialLocalDirToTarget = turret_initial_itm * ai_target.targetPos
  let distanceToTarget = length(initialLocalDirToTarget)
  if distanceToTarget > max_dist || distanceToTarget < min_dist
    return FLT_MAX

  let angles = dir_to_angles(initialLocalDirToTarget)
  let yaw = angles.x
  let pitch = angles.y

  if yaw < limit_angles[0] || yaw > limit_angles[1] || pitch < limit_angles[2] || pitch > limit_angles[3]
    return FLT_MAX

  let localDirToTarget = turret_itm * ai_target.targetPos
  let visionAngles = dir_to_angles(localDirToTarget)
  let visionYaw = visionAngles.x
  let visionPitch = visionAngles.y

  let attackerTimeout = attackers["{target_eid}"]
  let useVisionLimits = (attackerTimeout ?? 0.0) < get_sync_time()
  if attackerTimeout != null && useVisionLimits
    erase(attackers, "{target_eid}")

  if useVisionLimits && (visionYaw < limit_vision_angles[0] || visionYaw > limit_vision_angles[1] || visionPitch < limit_vision_angles[2] || visionPitch > limit_vision_angles[3])
    return FLT_MAX

  let pos = turret_pos
  let vec = ai_target.targetPos - pos
  let dir = normalize(vec)
  let dist = length(vec)

  if rayhit_smoke_occluders(pos, ai_target.targetPos)
    return FLT_MAX

  if rayhit_normalized(pos, dir, dist, ETF_DEFAULT, -1)
    return FLT_MAX

  let angle = acos(dot(normalize(localDirToTarget), float3(1, 0, 0)))
  let targetRetentionMult = (target_eid == prev_target_eid ? settings.targetRetentionScoreMult : 1.0)
  return score_mult * targetRetentionMult * (settings.angleScoreMult * angle + settings.distanceScoreMult * distanceToTarget)


def find_next_target(owner_eid : EntityId;
                     owner_team : int;
                     targets_per_frame : int;
                     max_target_score : float;
                     turret_pos : float3;
                     turret_initial_itm : float3x4;
                     turret_itm : float3x4;
                     min_dist : float;
                     max_dist : float;
                     limit_angles_deg : float4;
                     limit_vision_angles_deg : float4;
                     var attackers : Object&;
                     var targets : EidList&;
                     var next_target_idx : int&;
                     var cur_target_eid : EntityId&;
                     var prev_target_eid : EntityId&;
                     var cur_target_type : int&;
                     var target_score : float&;
                     target_score_settings : TargetScoreSettings)
  let limitAngles = deg_to_rad(limit_angles_deg)
  let limitVisionAngles = deg_to_rad(limit_vision_angles_deg)

  if next_target_idx == 0
    target_score = FLT_MAX
    prev_target_eid = cur_target_eid
    init_targets(turret_pos, owner_eid, owner_team, prev_target_eid, max_dist, targets, cur_target_eid)

  let untilIdx = min(length(targets), next_target_idx + targets_per_frame)

  for targetIdx in range(next_target_idx, untilIdx)
    let targetEid = targets[targetIdx]
    query(targetEid) <| $ [es] (ai_target : Target; ai_target__scoreMult : float = 1.0; ai_target__type : int = int(AiTankTargetType HUMAN))
      let score = calc_target_score(targetEid, prev_target_eid, turret_pos, turret_initial_itm, turret_itm, ai_target, ai_target__scoreMult,
        max_dist, min_dist, limitAngles, limitVisionAngles, target_score_settings, attackers)
      if score < target_score
        target_score = score
        cur_target_eid = targetEid
        cur_target_type = ai_target__type

  if target_score > max_target_score
    target_score = FLT_MAX
    cur_target_eid = INVALID_ENTITY_ID
    cur_target_type = int(AiTankTargetType HUMAN)

  if untilIdx == length(targets)
    next_target_idx = 0
  else
    next_target_idx = untilIdx


[es(tag=server, before=before_net_phys_sync)]
def tank_ai_gunner_find_target(info : ParallelUpdateFrameDelayed;
                               gun__owner : EntityId;
                               turret__owner : EntityId;
                               turret__aimNodeId : int;
                               tank_turret_ai__targetCheckInterval : float;
                               tank_turret_ai__attackDist : float;
                               tank_turret_ai__maxTargetScore : float;
                               tank_turret_ai__limitAngles : float4 const?;
                               var turret_aim__target : EntityId&;
                               var tank_turret_ai__attackers : Object&;
                               var tank_turret_ai__nextTargetCheckAtTime : float&;
                               var tank_turret_ai__targetList : EidList&;
                               var tank_turret_ai__nextCheckedTargetIdx : int&;
                               var tank_turret_ai__curTargetEid : EntityId&;
                               var tank_turret_ai__prevTargetEid : EntityId&;
                               var tank_turret_ai__targetScore : float&;
                               var tank_turret_ai__curTargetType : int&;
                               controlledByTankAiGunner : Tag const?;
                               controlledByTankAiGunnerWithBot : Tag const?;
                               turret__limit : float4 = float4(-180, 180, -180, 180);
                               tank_turret_ai__atackMinDist : float = 0.f;
                               tank_turret_ai__limitVisionAngles : float4 = float4(-90, 90, -30, 50);
                               tank_turret_ai__checkedTargetsPerFrame : int = 2)
  if turret__aimNodeId < 0
    return
  if controlledByTankAiGunner == null && (controlledByTankAiGunnerWithBot == null || !can_soldier_control_turret(gun__owner))
    return

  query(gun__owner) <| $ [es(REQUIRE_NOT=deadEntity)] (team : int)
    if tank_turret_ai__nextCheckedTargetIdx == 0
      if info.curTime < tank_turret_ai__nextTargetCheckAtTime
        return
      tank_turret_ai__nextTargetCheckAtTime = info.curTime + tank_turret_ai__targetCheckInterval

    query(turret__owner) <| $ [es] (animchar : AnimcharBaseComponent)
      let parNodeId = geomtree_getParentNodeIdx(*animchar.nodeTree, turret__aimNodeId)
      if parNodeId < 0
        return

      var turretWtm : float3x4
      *animchar.nodeTree |> geomtree_getNodeWtmScalar(turret__aimNodeId, turretWtm)
      let turretItm = inverse(turretWtm)

      var tmOrig : float3x4
      var wtmParent : float3x4
      *animchar.originalNodeTree |> geomtree_getNodeTmScalar(turret__aimNodeId, tmOrig)
      *animchar.nodeTree |> geomtree_getNodeWtmScalar(parNodeId, wtmParent)
      var turretInitialWtm = wtmParent * tmOrig
      orthonormalize(turretInitialWtm)
      let turretInitialItm = inverse(turretInitialWtm)

      let limitAngles = tank_turret_ai__limitAngles ?? turret__limit
      find_next_target(turret__owner, team, tank_turret_ai__checkedTargetsPerFrame, tank_turret_ai__maxTargetScore, turretWtm[3],
        turretInitialItm, turretItm, tank_turret_ai__atackMinDist, tank_turret_ai__attackDist, limitAngles,
        tank_turret_ai__limitVisionAngles, tank_turret_ai__attackers, tank_turret_ai__targetList, tank_turret_ai__nextCheckedTargetIdx, tank_turret_ai__curTargetEid,
        tank_turret_ai__prevTargetEid, tank_turret_ai__curTargetType, tank_turret_ai__targetScore, TargetScoreSettings())
      turret_aim__target = tank_turret_ai__curTargetEid


struct AimingErrorSettings
  speedMult = 1.0
  angleMult = 1.0
  maxAngle = 0.5236 // PI / 6
  constantError = 0.5


def calc_aiming_error(time : float; freq : float; time_offset : float; dist : float; wish_dir : float3; shoot_dir : float3; shooter_vel : float3; target_vel : float3; settings : AimingErrorSettings)
  let vel = target_vel - shooter_vel
  let lateralSpeed = length(cross(vel, wish_dir))
  let angleDiff = safe_acos(dot(wish_dir, shoot_dir))
  let errorDueToSpeed = settings.speedMult * lateralSpeed
  let errorDueToAngle = settings.angleMult * min(angleDiff, settings.maxAngle) * dist

  return (errorDueToSpeed + errorDueToAngle + settings.constantError) * perlin_noise1(freq * time + time_offset)


def can_soldier_control_turret(eid : EntityId)
  var res = false
  query(eid) <| $ [es] (beh_tree__enabled : bool = false;
                        human_vehicle__canHoldWeapon : bool = false)
    res = beh_tree__enabled && !human_vehicle__canHoldWeapon
  return res


[es(tag=server, REQUIRE=turret_control__hasTankAiGunners, REQUIRE_NOT=deadEntity, after=vehicle_input_turret_es, before=apply_turret_aim_pos_to_remote_wish_dir_es)]
def turret_tank_ai_gunner_aim(evt : CmdTurretsUpdate;
                              transform : float3x4;
                              turret_control__gunEids : EidList;
                              net_phys__currentStateVelocity : float3;
                              ai_vehicle_tank__curObjective : EntityId = INVALID_ENTITY_ID;
                              ai_vehicle_tank__curObjectivePosIdx : int = -1)
  let shooterVel = net_phys__currentStateVelocity
  let shooterPos = transform[3]
  let curTime = get_sync_time()

  for gunEid in turret_control__gunEids
    query(gunEid) <| $ [es] (turret_state : TurretState;
                             gun__owner : EntityId;
                             tank_turret_ai__curTargetEid : EntityId;
                             tank_turret_ai__prevTargetEid : EntityId;
                             tank_turret_ai__burstWaitTime : float;
                             tank_turret_ai__shortPauseWaitTime : float;
                             tank_turret_ai__longPauseWaitTime : float;
                             tank_turret_ai__aimingGamma : float;
                             tank_turret_ai__idleSwing : float;
                             tank_turret_ai__maxBurstCount : int;
                             tank_turret_ai__dmTargetUpdateInterval : float;
                             var tank_turret_ai__targetState : int&;
                             var tank_turret_ai__shootState : int&;
                             var tank_turret_ai__prevTargetPos : float3&;
                             var tank_turret_ai__prevTargetActive : bool&;
                             var tank_turret_ai__prevTargetPartType : int&;
                             var tank_turret_ai__burstCount : int&;
                             var turret_aim__shootToPos : float3&;
                             var turret_aim__shootAngles : float2&;
                             var turret_aim__shootFlag : bool&;
                             var tank_turret_ai__shootStateTimeoutAt : float&;
                             var tank_turret_ai__dmTargetUpdateAt : float&;
                             controlledByTankAiGunner : Tag const?;
                             controlledByTankAiGunnerWithBot : Tag const?;
                             tank_turret_ai__shootAngleCos : float = 0.999)
      if controlledByTankAiGunner == null && (controlledByTankAiGunnerWithBot == null || !can_soldier_control_turret(gun__owner))
        return

      turret_aim__shootFlag = false

      var target : AiGunnerTarget

      //transitions of target state
      if tank_turret_ai__curTargetEid == INVALID_ENTITY_ID
        tank_turret_ai__targetState = int(AiTankTargetState IDLE)
      elif tank_turret_ai__targetState == int(AiTankTargetState IDLE) || tank_turret_ai__curTargetEid != tank_turret_ai__prevTargetEid
        tank_turret_ai__targetState = int(AiTankTargetState TARGET)

      //state machine output
      if tank_turret_ai__targetState == int(AiTankTargetState IDLE)
        let success = query(ai_vehicle_tank__curObjective) <| $ [es] (ai_tank_objective__aimAtPositions : Point3List)
          if uint(ai_vehicle_tank__curObjectivePosIdx) < uint(length(ai_tank_objective__aimAtPositions))
            turret_aim__shootToPos = ai_tank_objective__aimAtPositions[ai_vehicle_tank__curObjectivePosIdx]
            let diff = turret_aim__shootToPos - turret_state.shoot.pos
            let wishDir = normalize(diff)
            let lateralDir = normalize_default(cross(wishDir, float3(0, 1, 0)), float3(1, 0, 0))
            turret_aim__shootToPos += tank_turret_ai__idleSwing * lateralDir * sin(get_sync_time())
        if !success
          query(gun__owner) <| $ [es] (transform : float3x4)
            turret_aim__shootToPos = turret_state.shoot.pos + transform[0] * 100.0
      else // AiTankTargetState TARGET || AiTankTargetState TARGET_FAILURE
        let ignoreWithNoCrew = false
        let noCrew = ignoreWithNoCrew || !is_vehicle_with_alive_crew(tank_turret_ai__curTargetEid)
        let allowFromFront = true
        var updateDmTarget = false
        query(tank_turret_ai__curTargetEid) <| $ [es(REQUIRE=vehicle)] (transform aka target_transform : float3x4)
          let pointValue = evaluate_dm_ai_point_for_shot(tank_turret_ai__prevTargetPos, target_transform, shooterPos, noCrew, allowFromFront, tank_turret_ai__prevTargetPartType)
          updateDmTarget = curTime > tank_turret_ai__dmTargetUpdateAt || (pointValue == DMAIPointValue NONE && tank_turret_ai__targetState != int(AiTankTargetState TARGET_FAILURE))
        if updateDmTarget
          tank_turret_ai__dmTargetUpdateAt = curTime + tank_turret_ai__dmTargetUpdateInterval
        target = get_target_pos(shooterPos, shooterVel, tank_turret_ai__prevTargetPos,
          tank_turret_ai__prevTargetActive, tank_turret_ai__prevTargetPartType, gunEid,
          tank_turret_ai__curTargetEid, updateDmTarget)

        if !target.active
          tank_turret_ai__targetState = int(AiTankTargetState TARGET_FAILURE)
        else
          tank_turret_ai__targetState = int(AiTankTargetState TARGET)

          let diff = target.pos - turret_state.shoot.pos
          let wishDir = normalize(diff)
          let dist = length(diff)
          let shootDir = turret_state.shoot.dir

          turret_aim__shootToPos = target.pos
          let dir1 = normalize_default(cross(wishDir, float3(0, 1, 0)), float3(1, 0, 0))
          let dir2 = normalize(cross(dir1, wishDir))
          turret_aim__shootToPos += calc_aiming_error(get_sync_time(), 1.0, 17.21, dist, wishDir, shootDir, shooterVel, target.vel, AimingErrorSettings()) * dir1
          turret_aim__shootToPos += calc_aiming_error(get_sync_time(), 1.0, 13.19, dist, wishDir, shootDir, shooterVel, target.vel, AimingErrorSettings()) * dir2

          let dirDot = dot(wishDir, shootDir)
          let prob = pow((dirDot - tank_turret_ai__shootAngleCos) / (1.0 - tank_turret_ai__shootAngleCos), tank_turret_ai__aimingGamma)

          if ((tank_turret_ai__shootState == int(AiTankShootState READY) || tank_turret_ai__shootState == int(AiTankShootState BURST)) &&
              (tank_turret_ai__shootAngleCos <= dirDot &&
              rnd_float(0.0, 1.0) < prob))
            turret_aim__shootFlag = true

      turret_aim__shootAngles = turret_calc_shoot_angles(turret_state.shoot.pos, turret_aim__shootToPos)
      tank_turret_ai__prevTargetPos = target.pos
      tank_turret_ai__prevTargetActive = target.active
      tank_turret_ai__prevTargetPartType = target.partType

      //transitions of shoot state
      if tank_turret_ai__shootState == int(AiTankShootState READY)
        if turret_aim__shootFlag
          tank_turret_ai__shootState = int(AiTankShootState BURST)
          tank_turret_ai__shootStateTimeoutAt = curTime + tank_turret_ai__burstWaitTime
      elif tank_turret_ai__shootState == int(AiTankShootState BURST)
        if curTime > tank_turret_ai__shootStateTimeoutAt
          if tank_turret_ai__burstCount >= tank_turret_ai__maxBurstCount
            tank_turret_ai__burstCount = 0
            tank_turret_ai__shootState = int(AiTankShootState LONG_PAUSE)
            tank_turret_ai__shootStateTimeoutAt = curTime + tank_turret_ai__longPauseWaitTime
          else
            tank_turret_ai__burstCount += 1
            tank_turret_ai__shootState = int(AiTankShootState SHORT_PAUSE)
            tank_turret_ai__shootStateTimeoutAt = curTime + tank_turret_ai__shortPauseWaitTime
      elif tank_turret_ai__shootState == int(AiTankShootState SHORT_PAUSE)
        if curTime > tank_turret_ai__shootStateTimeoutAt
          tank_turret_ai__shootState = int(AiTankShootState READY)
      elif tank_turret_ai__shootState == int(AiTankShootState LONG_PAUSE)
        if curTime > tank_turret_ai__shootStateTimeoutAt
          tank_turret_ai__shootState = int(AiTankShootState READY)


def vehicle_not_still(this_eid : EntityId; still_transform : float3x4; still_box_extents : float)
  update_navmesh_poly_flags_on_still_obstacle(false, still_transform[3], still_box_extents)
  query() <| $ [es] (eid aka other_eid : EntityId;
                     vehicle__isStill aka other_vehicle__isStill : bool;
                     vehicle__stillTransform aka other_vehicle__stillTransform : float3x4;
                     vehicle__stillBoxExtents aka other_vehicle__stillBoxExtents : float)
    if this_eid != other_eid && other_vehicle__isStill && length_sq(other_vehicle__stillTransform[3] - still_transform[3]) < still_box_extents + other_vehicle__stillBoxExtents
      update_navmesh_poly_flags_on_still_obstacle(true, other_vehicle__stillTransform[3], other_vehicle__stillBoxExtents)
  //Let's not broadcast OnTankNavmeshFlagsLocalUpdate here,
  //so that AI tanks continue on the paths they had already chosen when the obstacle was there.
  //Otherwise, they sometimes get stuck, changing their path too often.


[es(tag=server)]
def vehicle_still_es(info : ParallelUpdateFrameDelayed;
                     eid : EntityId;
                     transform : float3x4;
                     vehicle__stillPosThreshold : float;
                     vehicle__stillCheckUpdateInterval : float;
                     vehicle__stillBoxExtents aka this_vehicle__stillBoxExtents : float;
                     var vehicle__stillTransform aka this_vehicle__stillTransform : float3x4&;
                     var vehicle__stillNextCheckAt : float&;
                     var vehicle__isStill : bool&;
                     deadEntity : Tag const?;
                     ai_vehicle_tank__motionState : int const?;
                     ai_vehicle_tank__plannedPath : Point3List const?)
  if info.curTime < vehicle__stillNextCheckAt
    return
  vehicle__stillNextCheckAt = info.curTime + vehicle__stillCheckUpdateInterval

  let isAiTank = ai_vehicle_tank__motionState != null && ai_vehicle_tank__plannedPath != null
  let isAiTankMoving = ((deadEntity == null) && isAiTank
    && (*ai_vehicle_tank__motionState == int(AiTankMotionState MOVE) || *ai_vehicle_tank__motionState == int(AiTankMotionState TRY_TO_GET_UNSTUCK))
    && !empty(*ai_vehicle_tank__plannedPath))

  let prevIsStill = vehicle__isStill
  vehicle__isStill = !isAiTankMoving && length_sq(transform[3] - vehicle__stillTransform[3]) < square(vehicle__stillPosThreshold)

  if !prevIsStill && vehicle__isStill
    update_navmesh_poly_flags_on_still_obstacle(true, vehicle__stillTransform[3], vehicle__stillBoxExtents)
    broadcastEvent([[OnTankNavmeshFlagsLocalUpdate pos=vehicle__stillTransform[3], extents = vehicle__stillBoxExtents]])
  elif prevIsStill && !vehicle__isStill
    vehicle_not_still(eid, vehicle__stillTransform, vehicle__stillBoxExtents)

  if !vehicle__isStill
    vehicle__stillTransform = transform


[es(tag=server, on_disappear)]
def on_still_vehicle_disappear(evt : Event;
                               eid : EntityId;
                               vehicle__isStill : bool;
                               vehicle__stillBoxExtents : float;
                               vehicle__stillTransform : float3x4)
  if vehicle__isStill
    vehicle_not_still(eid, vehicle__stillTransform, vehicle__stillBoxExtents)

[es(tag=server, on_event=OnTankNavmeshFlagsGlobalUpdate)]
def ai_vehicle_tank_new_path_on_nm_flags_global_update(evt : Event;
                                                       ai_vehicle_tank__plannedPath : Point3List;
                                                       var ai_vehicle_tank__pathFindingState : int&)
  let MIN_PLANNED_PATH_LENGTH = 5
  if length(ai_vehicle_tank__plannedPath) < MIN_PLANNED_PATH_LENGTH || ai_vehicle_tank__pathFindingState == int(AiTankPathFindingState UPDATING_DESTINATION)
    return
  ai_vehicle_tank__pathFindingState = int(AiTankPathFindingState UPDATING_PATH)


[es(tag=server)]
def ai_vehicle_tank_new_path_on_nm_flags_local_update(evt : OnTankNavmeshFlagsLocalUpdate;
                                                      transform : float3x4;
                                                      ai_vehicle_tank__plannedPath : Point3List;
                                                      ai_vehicle_tank__maxPathLength : float;
                                                      var ai_vehicle_tank__pathFindingState : int&)
  let MIN_PLANNED_PATH_LENGTH = 5
  if (length(ai_vehicle_tank__plannedPath) < MIN_PLANNED_PATH_LENGTH || ai_vehicle_tank__pathFindingState == int(AiTankPathFindingState UPDATING_DESTINATION) ||
      length_sq(evt.pos - transform[3]) > square(ai_vehicle_tank__maxPathLength + evt.extents))
    return
  ai_vehicle_tank__pathFindingState = int(AiTankPathFindingState UPDATING_PATH)


[es(tag=server, REQUIRE=turret_control__hasTankAiGunners, REQUIRE_NOT=deadEntity, after=turret_tank_ai_gunner_aim, before=apply_turret_aim_pos_to_remote_wish_dir_es)]
def turret_tank_ai_trigger_group(evt : CmdTurretsUpdate;
                                 turret_control__gunEids : EidList)
  for aiGunEid in turret_control__gunEids
    query(aiGunEid) <| $ [es(REQUIRE=(resolvedTurret, controlledByTankAiGunner), REQUIRE_NOT=turret__ignoreGroupTrigger)] (turret__groupHash aka ai_turret__groupHash : int;
                                                                                                                           turret_aim__shootToPos aka ai_turret_aim__shootToPos : float3;
                                                                                                                           turret_aim__shootFlag aka ai_turret_aim__shootFlag : bool;
                                                                                                                           turret_aim__target aka ai_turret_aim__target : EntityId)
      for gunEid in turret_control__gunEids
        query(gunEid) <| $ [es(REQUIRE=resolvedTurret, REQUIRE_NOT=controlledByTankAiGunner)] (turret__groupHash : int;
                                                                                               var turret_aim__shootToPos : float3&;
                                                                                               var turret_aim__shootFlag : bool&;
                                                                                               var turret_aim__target : EntityId&)
          if turret__groupHash == ai_turret__groupHash
            turret_aim__shootToPos = ai_turret_aim__shootToPos
            turret_aim__shootFlag = ai_turret_aim__shootFlag
            turret_aim__target = ai_turret_aim__target


[es(tag=server, on_event=EventOnGunCreated, REQUIRE=ai_vehicle_tank, REQUIRE_NOT=deadEntity)]
def turret_tank_ai_gun_init(evt : Event;
                            turret_control__gunEids : EidList)
  for turretEid in turret_control__gunEids
    query(turretEid) <| $ [es(REQUIRE_NOT=gun__isLauncher)] (var turret__isControlledByTankAi : bool&)
      turret__isControlledByTankAi = true


[es(on_appear, REQUIRE=vehicle)]
def tank_ai_init(evt : Event;
                 eid : EntityId;
                 ownedByPlayer : EntityId)
  query(ownedByPlayer) <| $ [es] (botAiEnabler : Tag const?)
    if botAiEnabler != null
      addSubTemplate(eid, "ai_vehicle_tank")


def find_bullet_id(target_type : int; ammo : IntList; ammo_set_length : int; ammo_set_info : Array; bullet_type_efficiency : Array)
  let rangeEnd = min(length(ammo), ammo_set_length)
  var res = -1
  var score = 0.0

  let list = bullet_type_efficiency[target_type] as Object
  if list == null
    return res
  for i in range(rangeEnd)
    if ammo[i] > 0
      let ammoBt = ((ammo_set_info[i] as Array)?[0] ?as Object)?["type"] ?? ""
      if empty(ammoBt)
        continue
      for elem in *list
        if ammoBt == elem.key
          if score < elem.value ?? 0.0
            res = i
            score = elem.value ?? 0.0
          break
  return res


[es(tag=server, no_order, REQUIRE=ai_vehicle_tank, REQUIRE_NOT=deadEntity)]
def ai_vehicle_tank_choose_shell(info : ParallelUpdateFrameDelayed;
                                 eid aka vehicle_eid : EntityId;
                                 [[shared_comp]] ai_vehicle_tank__bullet_type_efficiency : Array)
  query() <| $ [es] (gun : Gun;
                     eid : EntityId;
                     tank_turret_ai__curTargetType : int;
                     var nextBulletId : int&;
                     var currentBulletId : int&;
                     turret__owner : EntityId;
                     gun__ammoSets : Array;
                     [[shared_comp]] gun__ammoSetsInfo : Array;
                     gun__ammo_by_shell : IntList;
                     gun__reloadFinishTime : float const?)
    if turret__owner == vehicle_eid
      let maybeNextBulletId = find_bullet_id(tank_turret_ai__curTargetType, gun__ammo_by_shell, length(gun__ammoSets), gun__ammoSetsInfo, ai_vehicle_tank__bullet_type_efficiency)
      if maybeNextBulletId < 0
        return
      if maybeNextBulletId != nextBulletId
        nextBulletId = maybeNextBulletId
        sendEvent(vehicle_eid, [[EventOnSelectNextBulletId gunEid=eid, nextBulletId=nextBulletId]])
      let isReloadChange = gun__reloadFinishTime ?? gun.nextShotAtTime > info.curTime
      let isCurrentShellTypeDepleted = currentBulletId < length(gun__ammo_by_shell) && gun__ammo_by_shell[currentBulletId] <= 0
      if isCurrentShellTypeDepleted || isReloadChange
        currentBulletId = nextBulletId
