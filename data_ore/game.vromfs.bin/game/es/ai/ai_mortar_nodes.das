options always_export_initializer = true

require app
require ecs
require BehNodes
require DagorDataBlock
require DagorSystem

require math
require math.ang
require math.base
require math.random
require DagorMath
require DagorMathUtils
require DagorRandom

require Grid
require Dacoll
require pathfinder

require HumanPhys
require DngHuman
require DngWalkerai

require Gun
require DngWeapon
require DaWeaponProps

require game.utils.team
require game.es.level_common
require game.es.battle_area_common
require enlisted.game.es.fortifications_build_common
require common_shooter.es.mortar.mortar_common

require DngNet
require common_shooter.events_common_shooter
require enlisted.events_enlisted


[beh_node(name="canShootAtPointWithMortar")]
class CanShootAtPointWithMortar : BehNodeAdapter
  gunSlotParam = -1
  posParam = -1
  checkAmmo : bool = true
  traceRatio : float = 0.0
  traceOffset : float3 = float3(0.0, 0.5, 0.0)
  traceParts : int = 200
  traceMinDist : float = 10.0

  runStep : int = 0
  runPrevPos : float3 = float3()
  runFromPos : float3 = float3()
  runToPos : float3 = float3()
  runShootDir : float3 = float3()
  runShootVel : float = 0.0
  runTime : float = 0.0
  runStepToTimeCoef : float = 0.0
  runSkipSteps : int = 0
  runSkipped : bool = false

  def override loadFromBlk(data : DataBlock) : void
    gunSlotParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "gunSlotParam", ""), -1)
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3())
    checkAmmo = datablock_getBool(data, "checkAmmo", checkAmmo)
    traceRatio = datablock_getReal(data, "traceRatio", traceRatio)
    traceOffset = datablock_getPoint3(data, "traceOffset", traceOffset)
    traceParts = max(2, datablock_getInt(data, "traceParts", traceParts))
    traceMinDist = datablock_getReal(data, "traceMinDist", traceMinDist)

  def override init() : void
    runStep = -1
  def override exit() : void
    runStep = -1

  def override update(dt : float) : EBehResult
    if runStep < 0
      let agentEid = beh_tree_eid(owner)

      var hasFromPos = false
      query(agentEid) <| $ [es] (transform : float3x4)
        runFromPos = transform[3] + traceOffset
        hasFromPos = true
      if !hasFromPos
        return EBehResult ER_FAILED

      runToPos = owner.blackBoard |> datablock_getPoint3(posParam)

      var canShoot = false
      let slotIdx = owner.blackBoard |> datablock_getInt(gunSlotParam)
      query(agentEid) <| $ [es] (human_weap__gunEids : EidList)
        if slotIdx < 0 || slotIdx >= length(human_weap__gunEids)
          return
        let gunEid = human_weap__gunEids[slotIdx]
        query(gunEid) <| $ [es(REQUIRE=mortar)] (gun__curShellId : ShellPropIds; gun__totalAmmo : int = 0; gun__ammo : int = 0)
          let availableAmmo = gun__totalAmmo + gun__ammo
          if availableAmmo > 0
            runShootVel = get_shell_speed(gun__curShellId)
            canShoot = true
      if !canShoot
        return EBehResult ER_FAILED

      if traceRatio <= 0.0
        return EBehResult ER_SUCCESS

      calculate_arc_high_start_dir(runFromPos, runToPos, runShootVel, runShootDir)
      if !calculate_arc_high_time(runFromPos.y, runShootDir.y * runShootVel, runToPos.y, runTime)
        return EBehResult ER_FAILED
      runStep = 0
      runStepToTimeCoef = runTime / float(traceParts)
      runPrevPos = runFromPos
      runSkipSteps = min(traceParts / 2, 1 + int(float(traceParts) * traceRatio))
      runSkipped = false

    var newPos = runPrevPos
    let minDistSq = square(traceMinDist)
    while runStep < traceParts && distance_sq(runPrevPos, newPos) < minDistSq
      runStep += 1
      calculate_arc_point(runFromPos, runShootDir, runShootVel, float(runStep) * runStepToTimeCoef, newPos)

    let delta = newPos - runPrevPos
    let dir = normalize(delta)
    var dist = length(dir)
    var norm : float3
    if traceray_normalized(runPrevPos, dir, dist, norm, ETF_ALL)
      return EBehResult ER_FAILED

    if !runSkipped && runStep >= runSkipSteps
      runSkipped = true
      runStep = traceParts - runSkipSteps
      calculate_arc_point(runFromPos, runShootDir, runShootVel, float(runStep) * runStepToTimeCoef, runPrevPos)

    runPrevPos = newPos
    if runStep < traceParts
      return EBehResult ER_RUNNING
    return EBehResult ER_SUCCESS


[beh_node(name="shootAtPointWithMortar")]
class ShootAtPointWithMortar : BehNodeAdapter
  posParam = -1
  numShotsParam = -1
  numShots : int = 1

  randRadius : float2 = float2(5.0, 15.0)

  yawAimMaxVel : float = 3.0
  pitchAimMaxVel : float = 1.0
  yawFitAng : float = 0.2
  pitchFitAng : float = 0.01
  yawMaxWaitTime : float = 1.0
  pitchMaxWaitTime : float = 2.0

  yawNoiseAngle : float = 0.01
  pitchNoiseAngle : float = 0.01

  startWaitTime : float2 = float2(1.5, 2.0)
  afterAimedWaitTime : float2 = float2(1.5, 2.0)
  shootCooldownTime : float2 = float2(5.0, 6.0)
  endWaitTime : float2 = float2(2.5, 3.0)
  controlsReactionTime : float = 0.3

  runState : int = -1
  runWaitTime : float = 0.0
  runGunEid : EntityId = INVALID_ENTITY_ID
  runFromPos : float3 = float3()
  runToPos : float3 = float3()
  runShootVel : float = 0.0
  runShootDir : float3 = float3()
  runShots : int = 0

  STATE_INIT = 0
  STATE_START_MORTAR = 1
  STATE_STARTED_MORTAR = 2
  STATE_AIMING_YAW = 3
  STATE_AIMING_PITCH = 4
  STATE_SHOOT = 5
  STATE_RELEASE = 6
  STATE_DONE = 7

  def override loadFromBlk(data : DataBlock) : void
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3())
    numShots = datablock_getInt(data, "numShots", numShots)
    if datablock_find_param(data, "numShotsParam") >= 0
      numShotsParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "numShotsParam", ""), 1)

    randRadius = datablock_getPoint2(data, "randRadius", randRadius)

    yawAimMaxVel = datablock_getReal(data, "yawAimMaxVel", yawAimMaxVel)
    pitchAimMaxVel = datablock_getReal(data, "pitchAimMaxVel", pitchAimMaxVel)
    yawFitAng = datablock_getReal(data, "yawFitAng", yawFitAng)
    pitchFitAng = datablock_getReal(data, "pitchFitAng", pitchFitAng)
    yawMaxWaitTime = datablock_getReal(data, "yawMaxWaitTime", yawMaxWaitTime)
    pitchMaxWaitTime = datablock_getReal(data, "pitchMaxWaitTime", pitchMaxWaitTime)

    yawNoiseAngle = datablock_getReal(data, "yawNoiseAngle", yawNoiseAngle)
    pitchNoiseAngle = datablock_getReal(data, "pitchNoiseAngle", pitchNoiseAngle)

    startWaitTime = datablock_getPoint2(data, "startWaitTime", startWaitTime)
    afterAimedWaitTime = datablock_getPoint2(data, "afterAimedWaitTime", afterAimedWaitTime)
    shootCooldownTime = datablock_getPoint2(data, "shootCooldownTime", shootCooldownTime)
    endWaitTime = datablock_getPoint2(data, "endWaitTime", endWaitTime)
    controlsReactionTime = datablock_getReal(data, "controlsReactionTime", controlsReactionTime)

  def override init() : void
    stop_mortar_mode()
    runGunEid = INVALID_ENTITY_ID
    runState = STATE_INIT
  def override exit() : void
    stop_mortar_mode()
    runGunEid = INVALID_ENTITY_ID
    runState = STATE_INIT

  def approach_to(val : float; to : float; dt : float; fit_ofs : float; max_vel : float)
    if dt <= 0.0
      return val
    let delta = to - val
    if delta > -fit_ofs && delta < fit_ofs
      return val + delta * 1.5
    let vel = clamp(delta / dt, -max_vel, max_vel)
    return val + vel * dt

  def stop_mortar_mode()
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (var human_weap__mortarMode : bool&)
      human_weap__mortarMode = false

    var agent = beh_tree_entity_agent(*owner)
    var phys = agent.phys
    if phys != null
      assume ct = phys.producedCT
      var dir = ct.wishShootDir
      dir.y = 0.0
      dir = normalize(dir)
      ct |> human_control_state_set_wish_look_dir(dir)
      ct |> human_control_state_set_wish_shoot_dir(dir)

  def override update(dt : float) : EBehResult
    var agent = beh_tree_entity_agent(*owner)
    var phys = agent.phys
    if phys == null
      return EBehResult ER_FAILED
    assume ct = phys.producedCT

    if runState <= STATE_INIT
      var inMortarMode = false
      runGunEid = INVALID_ENTITY_ID
      query(agent.eid) <| $ [es] (human_weap__currentGunEid : EntityId;
                                  human_weap__mortarMode : bool;
                                  transform : float3x4)
        runGunEid = human_weap__currentGunEid
        inMortarMode = human_weap__mortarMode
        runFromPos = transform[3]

      runToPos = owner.blackBoard |> datablock_getPoint3(posParam)
      let randYaw = rnd_float(0.0, PI * 2.0)
      let randDisp = rnd_float(randRadius.x, randRadius.y)
      runToPos.x += sin(randYaw) * randDisp
      runToPos.z += cos(randYaw) * randDisp

      var canShoot = false
      query(runGunEid) <| $ [es(REQUIRE=mortar)] (gun__curShellId : ShellPropIds; gun__totalAmmo : int = 0; gun__ammo : int = 0)
        let availableAmmo = gun__totalAmmo + gun__ammo
        if availableAmmo > 0
          runShootVel = get_shell_speed(gun__curShellId)
          canShoot = true
      if !canShoot
        return EBehResult ER_FAILED

      ct |> human_control_state_set_neutral_ctrl()
      ct |> human_control_state_set_walk_speed(0.f)
      ct |> human_control_state_set_control_bit(HumanPhysControlType HCT_CRAWL, false)
      ct |> human_control_state_set_control_bit(HumanPhysControlType HCT_CROUCH, false)
      ct |> human_control_state_set_control_bit(HumanPhysControlType HCT_AIM, false)
      ct |> human_control_state_set_control_bit(HumanPhysControlType HCT_SHOOT, false)

      if !inMortarMode
        ct |> human_control_state_set_control_bit(HumanPhysControlType HCT_SHOOT, true)

      runState = STATE_START_MORTAR
      runWaitTime = get_sync_time() + controlsReactionTime

    if get_sync_time() < runWaitTime
      return EBehResult ER_RUNNING

    if runState == STATE_START_MORTAR
      ct |> human_control_state_set_control_bit(HumanPhysControlType HCT_SHOOT, false)
      runState = STATE_STARTED_MORTAR
      runWaitTime = get_sync_time() + rnd_float(startWaitTime.x, startWaitTime.y)
      return EBehResult ER_RUNNING

    if runState == STATE_STARTED_MORTAR
      var inMortarMode = false
      query(agent.eid) <| $ [es] (human_weap__mortarMode : bool)
        inMortarMode = human_weap__mortarMode
      if !inMortarMode
        return EBehResult ER_FAILED

      if !calculate_arc_high_start_dir(runFromPos, runToPos, runShootVel, runShootDir)
        return EBehResult ER_FAILED

      let toYaw = (runShootDir.x != 0. || runShootDir.z != 0.) ? atan2(-runShootDir.z, runShootDir.x) : 0.
      let lookDir = angles_to_dir(float2(toYaw, 0.0))
      ct |> human_control_state_set_wish_look_dir(lookDir)

      runState = STATE_AIMING_YAW
      runWaitTime = -yawMaxWaitTime
      return EBehResult ER_RUNNING

    if runState == STATE_AIMING_YAW
      var curAngles = dir_to_angles(ct.wishShootDir)
      let toAngles = renorm_ang(dir_to_angles(runShootDir), curAngles)
      curAngles.x = approach_to(curAngles.x, toAngles.x, dt, yawFitAng, yawAimMaxVel)
      curAngles.y = approach_to(curAngles.y, 0.0, dt, pitchFitAng, pitchAimMaxVel)

      let noiseFactor1 = clamp(abs(toAngles.x - curAngles.y) / HALF_PI, 0.0, 1.0)
      let noiseFactor2 = abs(safediv(runWaitTime, pitchMaxWaitTime))
      curAngles.x += sin(-noiseFactor2 * PI * 5.0) * yawNoiseAngle * square(noiseFactor1)

      let lookDir = angles_to_dir(curAngles)

      ct |> human_control_state_set_wish_shoot_dir(lookDir)
      ct |> human_control_state_set_wish_look_dir(lookDir)

      if runWaitTime < -1.0 || abs(norm_s_ang(toAngles.x - curAngles.x)) > 0.01
        runWaitTime += dt
        if runWaitTime >= 0.0
          return EBehResult ER_FAILED
        return EBehResult ER_RUNNING

      var hasShootNodePos = false
      query(runGunEid) <| $ [es] (gun : Gun)
        runFromPos = gun.shootNodePos
        hasShootNodePos = true
      if !hasShootNodePos
        return EBehResult ER_FAILED

      if !calculate_arc_high_start_dir(runFromPos, runToPos, runShootVel, runShootDir)
        return EBehResult ER_FAILED

      runState = STATE_AIMING_PITCH
      runWaitTime = -pitchMaxWaitTime

    if runState == STATE_AIMING_PITCH
      let destYaw = (runShootDir.x != 0. || runShootDir.z != 0.) ? atan2(-runShootDir.z, runShootDir.x) : 0.
      let destPitch = dir_to_angles(runShootDir).y
      var curAngles = dir_to_angles(ct.wishShootDir)
      curAngles.x = approach_to(curAngles.x, renorm_ang(destYaw, curAngles.x), dt, yawFitAng, yawAimMaxVel)
      curAngles.y = approach_to(curAngles.y, destPitch, dt, pitchFitAng, pitchAimMaxVel)

      let noiseFactor = clamp(abs(destPitch - curAngles.y) / HALF_PI, 0.0, 1.0)
      curAngles.y += rnd_float(-1.0, 1.0) * pitchNoiseAngle * noiseFactor

      let shootDir = angles_to_dir(float2(curAngles.x, curAngles.y))
      let lookDir = angles_to_dir(float2(curAngles.x, 0.0))

      ct |> human_control_state_set_wish_shoot_dir(shootDir)
      ct |> human_control_state_set_wish_look_dir(lookDir)

      if runWaitTime < -1.0 || abs(destPitch - curAngles.y) > 0.01
        runWaitTime += dt
        if runWaitTime >= 0.0
          return EBehResult ER_FAILED
        return EBehResult ER_RUNNING

      runState = STATE_SHOOT
      runWaitTime = get_sync_time() + rnd_float(afterAimedWaitTime.x, afterAimedWaitTime.y)
      runShots = numShots
      if numShotsParam >= 0
        runShots = max(1, owner.blackBoard |> datablock_getInt(numShotsParam))
      return EBehResult ER_RUNNING

    if runState == STATE_SHOOT
      if runShots > 0
        // NOTE: Setting HCT_SHOOT to true doesn't work in online as it's client-processed only.
        //       So, send CmdStartMortarStrikeAtPos event instead just like client does after all.
        send_net_event(agent.eid, [[CmdStartMortarStrikeAtPos pos=runToPos]])

        runShots -= 1
        runState = STATE_RELEASE
        runWaitTime = get_sync_time() + controlsReactionTime
        return EBehResult ER_RUNNING
      runState = STATE_DONE

    if runState == STATE_RELEASE
      ct |> human_control_state_set_control_bit(HumanPhysControlType HCT_SHOOT, false)
      runState = STATE_SHOOT
      runWaitTime = get_sync_time() + rnd_float(shootCooldownTime.x, shootCooldownTime.y)
      if runShots <= 0
        runWaitTime = get_sync_time() + rnd_float(endWaitTime.x, endWaitTime.y)
      return EBehResult ER_RUNNING

    stop_mortar_mode()
    return EBehResult ER_SUCCESS


def private check_soldier_mortar(soldier_eid : EntityId; var out_max_dist : float&)
  var hasMortar = false
  out_max_dist = 0.0
  query(soldier_eid) <| $ [es] (human_weap__gunEids : EidList)
    for slot in iter_range(human_weap__gunEids)
      let gunEid = human_weap__gunEids[slot]
      query(gunEid) <| $ [es(REQUIRE=mortar)] (gun__totalAmmo : int = 0;
                                               gun__ammo : int = 0;
                                               mortar__distanceLimit : float = 0.0;
                                               mortar__minTargetDistance : float = 50.0)
        let availableAmmo = gun__totalAmmo + gun__ammo
        if availableAmmo > 0
          let maxDist = mortar__distanceLimit
          if maxDist > mortar__minTargetDistance && (!hasMortar || maxDist > out_max_dist)
            out_max_dist = maxDist
            hasMortar = true
  return hasMortar

def private get_squad_soldiers_for_mortar_attack(squad_eid : EntityId;
                                                 var out_list : array<EntityId>&;
                                                 var out_max_dists : array<float>&)
  out_list |> clear()
  out_max_dists |> clear()
  query(squad_eid) <| $ [es] (squad__allMembers : EidList)
    for memberEid in squad__allMembers
      var soldierOK = false
      query(memberEid) <| $ [es] (isAlive : bool; isDowned : bool)
        soldierOK = isAlive && !isDowned
      var maxDist = 0.0
      if soldierOK && check_soldier_mortar(memberEid, maxDist)
        out_list |> push(memberEid)
        out_max_dists |> push(maxDist)

def private get_zones_for_mortar_attack(var zones : EidList&)
  zones |> clear()
  query() <| $ [es(REQUIRE=capzone)] (active : bool; eid : EntityId)
    if active
      zones |> push(eid)
  shuffle(zones)

def private generate_mortar_attack_source_point(var pos : float3&; step : int; capzone_eid : EntityId; away_dist : float; var traces_left : int&;
                                                var inside_capzone_eid : EntityId&; var closest_target_pos : float3&; our_team : int; agent_pos : float3)
  let MAX_STEPS = 25
  if step > MAX_STEPS
    return -1

  var approxRadius = -1.0
  var sphereRadius = 0.0
  var capTransform : float3x4
  query(capzone_eid) <| $ [es] (capzone__approximateRadius = -1.0; sphere_zone__radius = 0.0; transform : float3x4)
    approxRadius = capzone__approximateRadius
    sphereRadius = sphere_zone__radius
    capTransform = transform

  if inside_capzone_eid != INVALID_ENTITY_ID
    capTransform[3] = closest_target_pos

  let STEP_DIST = 5.0
  let SHIFT_DIST_COEF = 0.75
  let SHIFT_MIN_DIST = 20.0
  let SHIFT_MAX_DIST = 75.0

  let delta = capTransform[3] - pos
  let maxShift = clamp(length(delta) * SHIFT_DIST_COEF, SHIFT_MIN_DIST, SHIFT_MAX_DIST)
  let shift = rnd_float(-maxShift, maxShift)
  let dir = normalize(delta)
  let origPos = pos
  pos += dir * STEP_DIST * float(step)
  pos.x += dir.z * shift
  pos.z -= dir.x * shift

  traces_left -= 1

  let HEIGHT_UP = 1000.0
  pos.y += HEIGHT_UP
  var foundProjectedPos = false
  let extents = float3(3.0, FLT_MAX, 3.0)
  var polyRef : dtPolyRef = uint64(0)
  if project_to_nearest_navmesh_point(pos, extents, polyRef)
    var waterLevel = 0.f;
    let MAX_HEIGHT_UNDERWATER = -0.3
    if traceht_water(pos, waterLevel)
      if waterLevel - pos.y > MAX_HEIGHT_UNDERWATER
        return 0
    foundProjectedPos = true
  if !foundProjectedPos
    return 0

  if capzone_eid != inside_capzone_eid && is_pos_inside_capture_point(pos, away_dist, capTransform, approxRadius, sphereRadius)
    if inside_capzone_eid == INVALID_ENTITY_ID && is_pos_inside_capture_point(origPos, away_dist, capTransform, approxRadius, sphereRadius)
      inside_capzone_eid = capzone_eid
      var hasClosestPos = false
      var closestDistSq = 0.0
      query() <| $ [es(REQUIRE=respbase, REQUIRE_NOT=customRespawnBase)] (active : bool; team : int; transform : float3x4; respawnbaseType : string)
        if !active || respawnbaseType != "human" || is_teams_friendly(team, our_team)
          return
        let distSq = distance_sq(transform[3], agent_pos)
        if !hasClosestPos || closestDistSq > distSq
          hasClosestPos = true
          closestDistSq = distSq
          closest_target_pos = transform[3]
      if !hasClosestPos
        closest_target_pos = capTransform[3]
      return 1
    return -1
  return 1

def private trace_mortar_attack_up(pos : float3)
  let checkPos = pos + float3(0.0, 1.0, 0.0)
  let HEIGHT_UP = 1000.0
  let dirUp = float3(0.0, 1.0, 0.0)
  var dist = HEIGHT_UP
  var norm : float3
  return traceray_normalized(checkPos, dirUp, dist, norm, ETF_DEFAULT & ~ETF_HEIGHTMAP)

def private check_mortar_attack_source_point(pos : float3; our_team : int; var traces_left : int&; agent_pos : float3; var out_covered : bool&)
  let origPos = pos
  if is_pos_indoor(pos)
    return false

  traces_left -= 1

  if trace_mortar_attack_up(pos)
    return false

  if !has_active_enemy_human_battle_area_at(pos, our_team)
    return false

  if !has_active_human_battle_area_at(pos, our_team)
    return false

  let extents = float3(0.5, FLT_MAX, 0.5)
  if !check_path(agent_pos, origPos, extents, 0.5, 1.0)
    return false

  traces_left -= 2

  let ANGLES = 12
  let STAND_OFFSET = 0.5
  let TRACE_ANGLE = deg_to_rad(60.0)
  let TRACE_DIST = 1.0
  let TRACE_DIST_UP = sin(TRACE_ANGLE) * TRACE_DIST
  let TRACE_DIST_FORW = cos(TRACE_ANGLE) * TRACE_DIST
  let py1 = pos.y + STAND_OFFSET
  let py2 = py1 + TRACE_DIST_UP
  let traceFromPos = float3(pos.x, py1, pos.y)
  let toRadCoef = (PI * 2.0 / float(ANGLES))
  for i in range(ANGLES)
    let rad = float(i) * toRadCoef
    let px = pos.x + sin(rad) * TRACE_DIST_FORW
    let pz = pos.z + cos(rad) * TRACE_DIST_FORW
    var dist = TRACE_DIST
    var norm : float3
    let traceToPos = float3(px, py2, pz)
    let traceDir = normalize(traceToPos - traceFromPos)
    if traceray_normalized(traceFromPos, traceDir, dist, norm, ETF_DEFAULT)
      return false

  let COVER_TRACE_DIST = 15.0
  var notInCover = false
  query() <| $ [es(REQUIRE=respbase, REQUIRE_NOT=customRespawnBase)] (active : bool; team : int; transform : float3x4; respawnbaseType : string)
    if !active || respawnbaseType != "human" || is_teams_friendly(team, our_team) || notInCover
      return
    let delta = transform[3] - agent_pos
    var dist = COVER_TRACE_DIST
    var norm : float3
    let traceFromPos2 = agent_pos + float3(0.0, 2.0, 0.0)
    let traceDir2 = normalize(delta)
    traces_left -= 1
    if !traceray_normalized(traceFromPos2, traceDir2, dist, norm, ETF_DEFAULT)
      notInCover = true
  out_covered = !notInCover
  return true


[beh_node(name="isMortarsSquad")]
class IsMortarsSquad : BehNodeAdapter
  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    var hasMortars = false
    query(agentEid) <| $ [es] (squad_member__squad : EntityId; squad_member__playerEid : EntityId)
      var mortarsEnabled = false
      query(squad_member__playerEid) <| $ [es] (team : int)
        if team > 0
          query() <| $ [es] (team__id : int; team_bots__maxMortarAttacksAtOnce : int)
            if team__id == team && team_bots__maxMortarAttacksAtOnce > 0
              mortarsEnabled = true
      if !mortarsEnabled
        return
      var list : array<EntityId>
      var maxDists : array<float>
      get_squad_soldiers_for_mortar_attack(squad_member__squad, list, maxDists)
      if length(list) > 0
        hasMortars = true
    return hasMortars ? EBehResult ER_SUCCESS : EBehResult ER_FAILED


[beh_node(name="planMortarAttack")]
class PlanMortarAttack : BehNodeAdapter
  posOutParam = -1
  capZoneAwayDist : float = 30.0

  runStep : int = 0
  runIndex1 : int = 0
  runIndex2 : int = 0
  runIndex3 : int = 0
  runTotal : int = 0

  runTeam : int = 0
  runPlayerEid : EntityId = INVALID_ENTITY_ID
  runSquadEid : EntityId = INVALID_ENTITY_ID
  runTeamEid : EntityId = INVALID_ENTITY_ID
  runAgentPos : float3 = float3()
  runAllocTime : float = 0.0
  runTicketIdx : int = -1
  runMoveToPos1 : float3 = float3()
  runMoveToPos2 : float3 = float3()
  runSuccess1 : bool = false
  runSuccess2 : int = 0

  MAX_CHECKS_PER_DIST = 5
  MAX_TRACES_PER_UPDATE = 5
  MAX_UNCOVERED_TO_GIVE_UP = 10
  SCAN_STEP_DISTANCE = 12.0

  STEP_INIT_CHECK = 0
  STEP_SEARCH = 1
  STEP_DONE = 2

  def override loadFromBlk(data : DataBlock) : void
    posOutParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posOutParam", ""), float3())
    capZoneAwayDist = datablock_getReal(data, "capZoneAwayDist", capZoneAwayDist)

  def override init() : void
    runStep = STEP_INIT_CHECK
  def override exit() : void
    runStep = STEP_INIT_CHECK

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    let curTime = get_sync_time()

    if runStep == STEP_INIT_CHECK
      runSquadEid = INVALID_ENTITY_ID
      query(agentEid) <| $ [es] (squad_member__playerEid : EntityId;
                                 squad_member__squad : EntityId;
                                 transform : float3x4)
        query(squad_member__playerEid) <| $ [es] (team : int;
                                                  var botPlayer__nextMortarAttackTime : float&;
                                                  botPlayer__timeBetweenPlanningMortarAttacks : float2)
          if curTime > botPlayer__nextMortarAttackTime
            let timeBetween = botPlayer__timeBetweenPlanningMortarAttacks
            botPlayer__nextMortarAttackTime = curTime + rnd_float(timeBetween.x, timeBetween.y)
            runTeam = team
            runPlayerEid = squad_member__playerEid
            runSquadEid = squad_member__squad
            runAgentPos = transform[3]
            runAllocTime = timeBetween.x
      if !runSquadEid
        return EBehResult ER_FAILED

      var list : array<EntityId>
      var maxDists : array<float>
      get_squad_soldiers_for_mortar_attack(runSquadEid, list, maxDists)
      if empty(list)
        return EBehResult ER_FAILED

      query() <| $ [es] (team__id : int;
                         eid aka team_eid : EntityId;
                         var team_bots__mortarAttackSquadsEids : EidList&;
                         var team_bots__mortarAttackSquadsTimeouts : FloatList&;
                         team_bots__maxMortarAttacksAtOnce : int)
        if team__id != runTeam
          return
        var numActiveMortarSquads = 0
        runTicketIdx = -1
        for squad_index in iter_range(team_bots__mortarAttackSquadsEids)
          if runSquadEid != team_bots__mortarAttackSquadsEids[squad_index] && team_bots__mortarAttackSquadsTimeouts[squad_index] > curTime
            ++numActiveMortarSquads
          else
            team_bots__mortarAttackSquadsEids[squad_index] = runSquadEid
            team_bots__mortarAttackSquadsTimeouts[squad_index] = curTime + runAllocTime
            runTicketIdx = squad_index
            runTeamEid = team_eid
        if runTicketIdx < 0
          if numActiveMortarSquads >= team_bots__maxMortarAttacksAtOnce
            runSquadEid = INVALID_ENTITY_ID
          else
            runTeamEid = team_eid
            runTicketIdx = length(team_bots__mortarAttackSquadsEids)
            team_bots__mortarAttackSquadsEids |> push(runSquadEid)
            team_bots__mortarAttackSquadsTimeouts |> push(curTime + runAllocTime)
      if !runSquadEid
        return EBehResult ER_FAILED

      query(runPlayerEid) <| $ [es] (var botPlayer__mortarAttackZones : EidList&)
        get_zones_for_mortar_attack(botPlayer__mortarAttackZones)
        if empty(botPlayer__mortarAttackZones)
          runSquadEid = INVALID_ENTITY_ID
      if !runSquadEid
        return EBehResult ER_FAILED

      runStep = STEP_SEARCH
      runIndex1 = 0
      runIndex2 = 0
      runIndex3 = 0
      runTotal = 0
      runSuccess1 = false
      runSuccess2 = 0
      runMoveToPos1 = runAgentPos
      runMoveToPos2 = runAgentPos
      return EBehResult ER_RUNNING

    if runStep == STEP_SEARCH
      ++runTotal

      query(runTeamEid) <| $ [es] (var team_bots__mortarAttackSquadsTimeouts : FloatList&)
        if runTicketIdx < length(team_bots__mortarAttackSquadsTimeouts)
          team_bots__mortarAttackSquadsTimeouts[runTicketIdx] = curTime + runAllocTime

      var done = true
      query(runPlayerEid) <| $ [es] (botPlayer__mortarAttackZones : EidList)
        let numZones = length(botPlayer__mortarAttackZones)
        var tracesLeft = MAX_TRACES_PER_UPDATE
        var insideCapZoneEid = INVALID_ENTITY_ID
        var closestTargetPos = float3()
        while tracesLeft > 0 && runIndex1 < numZones
          let capzoneEid = botPlayer__mortarAttackZones[runIndex1]
          var pos = runAgentPos
          let result = generate_mortar_attack_source_point(pos, runIndex2, capzoneEid, capZoneAwayDist, tracesLeft, insideCapZoneEid, closestTargetPos, runTeam, runAgentPos)
          if result < 0
            ++runIndex1
            runIndex2 = 0
            runIndex3 = 0
            insideCapZoneEid = INVALID_ENTITY_ID
            continue
          if result > 0
            var covered = false
            if check_mortar_attack_source_point(pos, runTeam, tracesLeft, runAgentPos, covered)
              if !covered
                if runSuccess2 <= 0 || distance_sq(runAgentPos, pos) < distance_sq(runAgentPos, runMoveToPos2)
                  runMoveToPos2 = pos
                runSuccess2 += 1
                if runSuccess2 >= MAX_UNCOVERED_TO_GIVE_UP
                  runIndex1 = numZones
                  break
              else
                runIndex1 = numZones
                runSuccess1 = true
                runMoveToPos1 = pos
                break
          runIndex3 += 1
          if runIndex3 >= MAX_CHECKS_PER_DIST
            runIndex2 += 1
            runIndex3 = 0
            continue
        done = runIndex1 >= numZones
      if !done
        return EBehResult ER_RUNNING
      if !runSuccess1 && runSuccess2 > 0
        runSuccess1 = true
        runMoveToPos1 = runMoveToPos2
      runStep = STEP_DONE

    if !runSuccess1
      query(runTeamEid) <| $ [es] (var team_bots__mortarAttackSquadsEids : EidList&)
        if runTicketIdx < length(team_bots__mortarAttackSquadsEids)
          team_bots__mortarAttackSquadsEids[runTicketIdx] = INVALID_ENTITY_ID

    owner.blackBoard |> set(posOutParam, runMoveToPos1)
    return runSuccess1 ? EBehResult ER_SUCCESS : EBehResult ER_FAILED

[beh_node(name="updateMortarAttackTimeout")]
class UpdateMortarAttackTimeout : BehNodeAdapter
  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)

    var playerTeam = -1
    var squadEid = INVALID_ENTITY_ID
    var allocTime = 0.0
    query(agentEid) <| $ [es] (squad_member__playerEid : EntityId;
                               squad_member__squad : EntityId)
      query(squad_member__playerEid) <| $ [es] (team : int; botPlayer__timeBetweenPlanningMortarAttacks : float2)
        playerTeam = team
        squadEid = squad_member__squad
        let timeBetween = botPlayer__timeBetweenPlanningMortarAttacks
        allocTime = rnd_float(timeBetween.x, timeBetween.y)
    if !squadEid
      return EBehResult ER_FAILED

    var updated = false
    query() <| $ [es] (team__id : int;
                       team_bots__mortarAttackSquadsEids : EidList;
                       var team_bots__mortarAttackSquadsTimeouts : FloatList&)
      if team__id != playerTeam
        return
      for squad_index in iter_range(team_bots__mortarAttackSquadsEids)
        if squadEid == team_bots__mortarAttackSquadsEids[squad_index]
          team_bots__mortarAttackSquadsTimeouts[squad_index] = get_sync_time() + allocTime
          updated = true

    return updated ? EBehResult ER_SUCCESS : EBehResult ER_FAILED


def private get_mortar_attack_zone_or_spawn_pos_and_radius(eid : EntityId; var out_pos : float3&; var out_radius : float&; respawn_radius : float; var is_respawn : bool&)
  var result = false
  is_respawn = false
  query(eid) <| $ [es(REQUIRE=capzone)] (transform : float3x4; capzone__approximateRadius = -1.0; sphere_zone__radius = 0.0)
    result = true
    out_pos = transform[3]
    if sphere_zone__radius > 0.0
      out_radius = sphere_zone__radius
    elif capzone__approximateRadius > 0.0
      out_radius = capzone__approximateRadius
    else
      out_radius = sqrt(length_sq(transform[0]) + length_sq(transform[2])) * 0.5
  if result
    out_radius *= 0.8
    return true
  query(eid) <| $ [es(REQUIRE=respbase)] (transform : float3x4)
    result = true
    out_pos = transform[3]
    out_radius = respawn_radius
    is_respawn = true
  return result

def private gather_mortar_attack_targets(var targets : EidList&; pos : float3; yaw : float; dist : float; radius : float; our_team : int)
  var center = pos
  center.x += sin(yaw) * dist
  center.z += cos(yaw) * dist

  let bsph = BSphere3(center, radius)

  for_each_entity_in_grid(ecs_hash("humans"), bsph, GridEntCheck BOUNDING) <| $(human_eid : EntityId)
    query(human_eid) <| $ [es] (team : int)
      if team != TEAM_UNASSIGNED && team != our_team
        targets |> push(human_eid)

  for_each_entity_in_grid(ecs_hash("vehicles"), bsph, GridEntCheck BOUNDING) <| $(vehicle_eid : EntityId)
    query(vehicle_eid) <| $ [es(REQUIRE_NOT=airplane)] (team : int)
      if team != TEAM_UNASSIGNED && team != our_team
        targets |> push(vehicle_eid)

def private get_mortar_attack_target_pos_and_value(target_eid : EntityId; var out_pos : float3&; var out_value : float&)
  var hasPos = false
  query(target_eid) <| $ [es] (transform : float3x4; isTank : Tag const?)
    hasPos = true
    out_pos = transform[3]
    out_value = (isTank != null) ? 5.0 : 1.0
  return hasPos

def private check_mortar_attack_target_point(pos : float3; attacked_pos : Point3List; attacked_radius : float; var mod_value : float&; var traces_left : int&)
  if is_pos_indoor(pos)
    return false

  traces_left -= 1

  let HEIGHT_UP = 1000.0
  let PRE_STEP = 1.0
  var fromPos = pos
  fromPos.y += HEIGHT_UP
  let dirDown = float3(0.0, -1.0, 0.0)
  var dist = HEIGHT_UP - PRE_STEP
  var norm : float3
  if traceray_normalized(fromPos, dirDown, dist, norm, ETF_DEFAULT)
    return false

  let minDistSq = square(attacked_radius)
  for pt in attacked_pos
    let distSq = distance_sq(pos, pt)
    if distSq < minDistSq
      mod_value *= 0.1
      break

  return true

def cleanup_mortar_attack_targets(var targets : EidList&; var points : Point3List&; var values : FloatList&)
  var idx = 0
  var len = length(targets)
  var removed = 0
  while idx < len
    if targets[idx] != INVALID_ENTITY_ID
      ++idx
    else
      --len
      targets[idx] = targets[len]
      values[idx] = values[len]
      points[idx] = points[len]
      targets |> resize(len)
      values |> resize(len)
      points |> resize(len)
      ++removed


[beh_node(name="performMortarAttack")]
class PerformMortarAttack : BehNodeAdapter
  posParam = -1
  inRadius : float = 15.0
  waitTimeout : float = 15.0
  mortarMinDist : float = 50.0
  maxShiftDist : float = 30.0
  respawnRadius : float = 30.0
  attackedRadius : float = 15.0
  movingTimeout : float = 10.0

  runStep : int = 0
  runIndex1 : int = 0
  runIndex2 : int = 0
  runIndex3 : int = 0
  runTimeout : float = 0.0
  runTotal : int = 0

  runTeam : int = 0
  runTeamEid : EntityId = INVALID_ENTITY_ID
  runSquadEid : EntityId = INVALID_ENTITY_ID
  runPlayerEid : EntityId = INVALID_ENTITY_ID
  runAgentPos : float3 = float3()
  runMaxDist : float = 0.0
  runTicketIdx : int = -1
  runMaxAttacks : int = 0

  TICKET_EXTRA_TIMEOUT = 10.0
  MAX_ATTACKED_POS_COUNT = 5
  MAX_TRACES_PER_UPDATE = 5
  NUM_DIRECTIONS_IN_CIRCLE = 32

  STEP_INIT_CHECK = 0
  STEP_WAIT_FOR_SQUAD = 1
  STEP_FIND_TARGETS = 2
  STEP_GIVE_ORDERS = 3
  STEP_DONE = 4

  def override loadFromBlk(data : DataBlock) : void
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3())
    inRadius = datablock_getReal(data, "inRadius", inRadius)
    waitTimeout = datablock_getReal(data, "waitTimeout", waitTimeout)
    mortarMinDist = datablock_getReal(data, "mortarMinDist", mortarMinDist)
    maxShiftDist = datablock_getReal(data, "maxShiftDist", maxShiftDist)
    respawnRadius = datablock_getReal(data, "respawnRadius", respawnRadius)
    attackedRadius = datablock_getReal(data, "attackedRadius", attackedRadius)
    movingTimeout = datablock_getReal(data, "movingTimeout", movingTimeout)

  def override init() : void
    runStep = STEP_INIT_CHECK
    runPlayerEid = INVALID_ENTITY_ID

  def override exit() : void
    runStep = STEP_INIT_CHECK
    clear_targets_arrays()

  def clear_targets_arrays()
    query(runPlayerEid) <| $ [es] (var botPlayer__mortarAttackTargets : EidList&;
                                   var botPlayer__mortarAttackPoints : Point3List;
                                   var botPlayer__mortarAttackValues : FloatList&)
      botPlayer__mortarAttackTargets |> clear()
      botPlayer__mortarAttackPoints |> clear()
      botPlayer__mortarAttackValues |> clear()

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    let curTime = get_sync_time()

    if runStep == STEP_INIT_CHECK
      var proceed = false
      query(agentEid) <| $ [es] (squad_member__playerEid : EntityId;
                                 squad_member__squad : EntityId;
                                 transform : float3x4)
        if squad_member__squad == INVALID_ENTITY_ID
          return

        var list : array<EntityId>
        var maxDists : array<float>
        get_squad_soldiers_for_mortar_attack(squad_member__squad, list, maxDists)
        if empty(list)
          return

        runMaxDist = maxDists[0]
        for maxDist in maxDists
          if runMaxDist < maxDist
            runMaxDist = maxDist

        query(squad_member__playerEid) <| $ [es] (team : int;
                                                  botPlayer__mortarAttackMaxAttackers : int2;
                                                  var botPlayer__mortarSoldiers : EidList&;
                                                  var botPlayer__mortarMaxDists : FloatList&)
          runTeamEid = INVALID_ENTITY_ID
          find_query() <| $ [es] (eid : EntityId; team__id : int)
            if team__id == team
              runTeamEid = eid
              return true
            return false
          if runTeamEid == INVALID_ENTITY_ID
            return

          var ticketIdx = -1
          query(runTeamEid) <| $ [es] (team_bots__mortarAttackSquadsEids : EidList;
                                       var team_bots__mortarAttackSquadsTimeouts : FloatList&)
            for squad_index in iter_range(team_bots__mortarAttackSquadsEids)
              if team_bots__mortarAttackSquadsEids[squad_index] == squad_member__squad
                ticketIdx = squad_index
                team_bots__mortarAttackSquadsTimeouts[squad_index] = curTime + TICKET_EXTRA_TIMEOUT
                break
          if ticketIdx < 0
            return

          proceed = true
          runTeam = team
          runSquadEid = squad_member__squad
          runPlayerEid = squad_member__playerEid
          runAgentPos = transform[3]
          runTicketIdx = ticketIdx
          runMaxAttacks = rnd_int(botPlayer__mortarAttackMaxAttackers.x, botPlayer__mortarAttackMaxAttackers.y)
          botPlayer__mortarSoldiers |> clear()
          botPlayer__mortarMaxDists |> clear()
          for soldierIdx, soldierEid in iter_range(list), list
            botPlayer__mortarSoldiers |> push(soldierEid)
            botPlayer__mortarMaxDists |> push(maxDists[soldierIdx])
      if !proceed
        return EBehResult ER_FAILED
      runStep = STEP_WAIT_FOR_SQUAD
      runTimeout = curTime + waitTimeout
      return EBehResult ER_RUNNING

    if runStep == STEP_WAIT_FOR_SQUAD
      query(runTeamEid) <| $ [es] (var team_bots__mortarAttackSquadsTimeouts : FloatList&)
        if runTicketIdx < length(team_bots__mortarAttackSquadsTimeouts)
          team_bots__mortarAttackSquadsTimeouts[runTicketIdx] = curTime + TICKET_EXTRA_TIMEOUT

      var ready = false

      var countNearby = 0
      let inRadiusSq = square(inRadius)
      query(runPlayerEid) <| $ [es] (botPlayer__mortarSoldiers : EidList)
        for soldierEid in botPlayer__mortarSoldiers
          query(soldierEid) <| $ [es] (transform : float3x4)
            let distSq = distance_sq(runAgentPos, transform[3])
            if distSq <= inRadiusSq
              ++countNearby
        if countNearby >= length(botPlayer__mortarSoldiers) || (countNearby >= 1 && curTime >= runTimeout)
          ready = true
      if curTime >= runTimeout && !ready
        query(runTeamEid) <| $ [es] (var team_bots__mortarAttackSquadsEids : EidList&)
          if runTicketIdx < length(team_bots__mortarAttackSquadsEids)
            team_bots__mortarAttackSquadsEids[runTicketIdx] = INVALID_ENTITY_ID
        return EBehResult ER_FAILED

      query(runPlayerEid) <| $ [es] (var botPlayer__mortarAttackZones : EidList&)
        get_zones_for_mortar_attack(botPlayer__mortarAttackZones)
        query() <| $ [es(REQUIRE=respbase, REQUIRE_NOT=customRespawnBase)] (eid : EntityId; active : bool; respawnbaseType : string; team : int)
          if active && respawnbaseType == "human" && !is_teams_friendly(team, runTeam)
            botPlayer__mortarAttackZones |> push(eid)
        if empty(botPlayer__mortarAttackZones)
          runSquadEid = INVALID_ENTITY_ID
      if !runSquadEid
        query(runTeamEid) <| $ [es] (var team_bots__mortarAttackSquadsEids : EidList&)
          if runTicketIdx < length(team_bots__mortarAttackSquadsEids)
            team_bots__mortarAttackSquadsEids[runTicketIdx] = INVALID_ENTITY_ID
        return EBehResult ER_FAILED

      clear_targets_arrays()

      runStep = STEP_FIND_TARGETS
      runIndex1 = 0
      runIndex2 = 0
      runIndex3 = 0
      runTotal = 0
      return EBehResult ER_RUNNING

    if runStep == STEP_FIND_TARGETS
      ++runTotal

      query(runTeamEid) <| $ [es] (var team_bots__mortarAttackSquadsTimeouts : FloatList&)
        if runTicketIdx < length(team_bots__mortarAttackSquadsTimeouts)
          team_bots__mortarAttackSquadsTimeouts[runTicketIdx] = curTime + TICKET_EXTRA_TIMEOUT

      query(runPlayerEid) <| $ [es] (var botPlayer__nextMortarAttackTime : float&; botPlayer__timeBetweenMortarAttacks : float2)
        botPlayer__nextMortarAttackTime = curTime + rnd_float(botPlayer__timeBetweenMortarAttacks.x, botPlayer__timeBetweenMortarAttacks.y)

      var done = false
      query(runPlayerEid) <| $ [es] (botPlayer__mortarAttackZones : EidList;
                                     var botPlayer__mortarAttackTargets : EidList&;
                                     var botPlayer__mortarAttackPoints : Point3List&;
                                     var botPlayer__mortarAttackValues : FloatList&;
                                     botPlayer__mortarAttackedPos : Point3List)
        let numZones = length(botPlayer__mortarAttackZones)
        var tracesLeft = MAX_TRACES_PER_UPDATE
        var pos = float3()
        var val = 0.0

        while tracesLeft > 0 && runIndex1 < NUM_DIRECTIONS_IN_CIRCLE
          let yawCoef = (PI * 2.0) / float(NUM_DIRECTIONS_IN_CIRCLE)
          let yawAngle = float(runIndex1) * yawCoef
          let scanWideRadius = yawCoef * runMaxDist
          let scanDistRadius = max(0.0, runMaxDist - mortarMinDist) * 0.5
          let scanRadius = max(scanWideRadius, scanDistRadius)
          let scanAtDist = mortarMinDist + scanDistRadius * 0.5
          gather_mortar_attack_targets(botPlayer__mortarAttackTargets, runAgentPos, yawAngle, scanAtDist, scanRadius, runTeam)
          --tracesLeft
          ++runIndex1
          if runIndex1 >= NUM_DIRECTIONS_IN_CIRCLE
            let numTargets = length(botPlayer__mortarAttackTargets)
            botPlayer__mortarAttackPoints |> resize(numTargets)
            botPlayer__mortarAttackValues |> resize(numTargets)
            let mortarMinDistSq = square(mortarMinDist)
            let runMaxDistSq = square(runMaxDist)
            for idx, targetEid in iter_range(botPlayer__mortarAttackTargets), botPlayer__mortarAttackTargets
              if get_mortar_attack_target_pos_and_value(targetEid, pos, val)
                let distSq = distance_sq(runAgentPos, pos)
                if distSq >= mortarMinDistSq && distSq <= runMaxDistSq
                  botPlayer__mortarAttackPoints[idx] = pos
                  botPlayer__mortarAttackValues[idx] = val
                else
                  botPlayer__mortarAttackTargets[idx] = INVALID_ENTITY_ID
              else
                botPlayer__mortarAttackTargets[idx] = INVALID_ENTITY_ID
            cleanup_mortar_attack_targets(botPlayer__mortarAttackTargets, botPlayer__mortarAttackPoints, botPlayer__mortarAttackValues)

        if runIndex1 >= NUM_DIRECTIONS_IN_CIRCLE
          while tracesLeft > 0 && runIndex2 < numZones
            let zoneEid = botPlayer__mortarAttackZones[runIndex2]
            var isRespawn = false
            if get_mortar_attack_zone_or_spawn_pos_and_radius(zoneEid, pos, val, respawnRadius, isRespawn)
              let minDistSq = square(val)
              for idx, targetPos in iter_range(botPlayer__mortarAttackPoints), botPlayer__mortarAttackPoints
                let distSq = distance_sq(pos, targetPos)
                if distSq < minDistSq
                  botPlayer__mortarAttackTargets[idx] = INVALID_ENTITY_ID
                elif !isRespawn
                  botPlayer__mortarAttackValues[idx] *= 1000.0
                  botPlayer__mortarAttackValues[idx] /= distSq
              --tracesLeft
            ++runIndex2
            if runIndex2 >= numZones
              cleanup_mortar_attack_targets(botPlayer__mortarAttackTargets, botPlayer__mortarAttackPoints, botPlayer__mortarAttackValues)

        if runIndex2 >= numZones
          let numTargets = length(botPlayer__mortarAttackTargets)
          while tracesLeft > 0 && runIndex3 < numTargets
            let targetEid = botPlayer__mortarAttackTargets[runIndex3]
            for i in range(numTargets)
              if i != runIndex3 && botPlayer__mortarAttackTargets[i] == targetEid
                botPlayer__mortarAttackTargets[i] = INVALID_ENTITY_ID
            if targetEid != INVALID_ENTITY_ID
              let attackPos = botPlayer__mortarAttackPoints[runIndex3]
              if !check_mortar_attack_target_point(attackPos, botPlayer__mortarAttackedPos, attackedRadius, botPlayer__mortarAttackValues[runIndex3], tracesLeft)
                botPlayer__mortarAttackTargets[runIndex3] = INVALID_ENTITY_ID
            ++runIndex3

        done = runIndex2 >= numZones && runIndex3 >= length(botPlayer__mortarAttackTargets)
        if done
          cleanup_mortar_attack_targets(botPlayer__mortarAttackTargets, botPlayer__mortarAttackPoints, botPlayer__mortarAttackValues)
          let numTargets = length(botPlayer__mortarAttackTargets)
          var indexes : array<int>
          indexes |> resize(numTargets)
          for i in range(numTargets)
            indexes[i] = i
          sort(indexes) <| $(lhs, rhs : int)
            return botPlayer__mortarAttackValues[lhs] > botPlayer__mortarAttackValues[rhs]
          var points : array<float3>
          points |> resize(numTargets)
          for i in range(numTargets)
            let refIdx = indexes[i]
            points[i] = botPlayer__mortarAttackPoints[refIdx]
          for i in range(numTargets)
            botPlayer__mortarAttackPoints[i] = points[i]
      if !done
        return EBehResult ER_RUNNING

      runStep = STEP_GIVE_ORDERS
      runIndex1 = 0
      runIndex2 = 0
      runTimeout = 0.0
      query(runPlayerEid) <| $ [es] (var botPlayer__mortarSoldiers : EidList&; var botPlayer__mortarMaxDists : FloatList&)
        shuffle(botPlayer__mortarSoldiers)
        for idx in iter_range(botPlayer__mortarSoldiers)
          if botPlayer__mortarSoldiers[idx] == agentEid
            let maxDist = botPlayer__mortarMaxDists[idx]
            botPlayer__mortarSoldiers |> erase(idx)
            botPlayer__mortarMaxDists |> erase(idx)
            botPlayer__mortarSoldiers |> push(agentEid)
            botPlayer__mortarMaxDists |> push(maxDist)
            break
      return EBehResult ER_RUNNING

    if runStep == STEP_GIVE_ORDERS
      query(runTeamEid) <| $ [es] (var team_bots__mortarAttackSquadsTimeouts : FloatList&)
        if runTicketIdx < length(team_bots__mortarAttackSquadsTimeouts)
          team_bots__mortarAttackSquadsTimeouts[runTicketIdx] = curTime + TICKET_EXTRA_TIMEOUT

      query(runPlayerEid) <| $ [es] (var botPlayer__nextMortarAttackTime : float&; botPlayer__timeBetweenMortarAttacks : float2)
        botPlayer__nextMortarAttackTime = curTime + rnd_float(botPlayer__timeBetweenMortarAttacks.x, botPlayer__timeBetweenMortarAttacks.y)

      var done = false
      query(runPlayerEid) <| $ [es] (botPlayer__mortarSoldiers : EidList;
                                     botPlayer__mortarMaxDists : FloatList;
                                     botPlayer__mortarAttackNumShots : int2;
                                     var botPlayer__mortarAttackPoints : Point3List&;
                                     var botPlayer__mortarAttackedPos : Point3List&)
        if runIndex1 >= length(botPlayer__mortarSoldiers) || empty(botPlayer__mortarAttackPoints) || runIndex2 >= runMaxAttacks
          done = true
          return
        let soldierEid = botPlayer__mortarSoldiers[runIndex1]
        var got = false
        var pos = float3()
        query(soldierEid) <| $ [es] (human_net_phys__curMoveState : int; transform : float3x4)
          if human_net_phys__curMoveState == int(HUMoveState EMS_STAND)
            got = true
            pos = transform[3]
        if !got
          runTimeout += dt
        else
          if !trace_mortar_attack_up(pos)
            var gotTarget = false
            var targetPos = pos
            let soldierMaxDistSq = square(botPlayer__mortarMaxDists[runIndex1])
            for idx in iter_range(botPlayer__mortarAttackPoints)
              targetPos = botPlayer__mortarAttackPoints[idx]
              if distance_sq(pos, targetPos) < soldierMaxDistSq
                botPlayer__mortarAttackPoints |> erase(idx)
                gotTarget = true
                break
            if gotTarget
              let numShots = rnd_int(botPlayer__mortarAttackNumShots.x, botPlayer__mortarAttackNumShots.y)
              if numShots > 0
                sendEvent(soldierEid, [[CmdMortarAttackOrder orderPosition=pos, orderTargetPos=targetPos, orderNumShots=numShots]])
                botPlayer__mortarAttackedPos |> push(targetPos)
                if length(botPlayer__mortarAttackedPos) > MAX_ATTACKED_POS_COUNT
                  botPlayer__mortarAttackedPos |> erase(0)
                ++runIndex2
        if got || runTimeout >= movingTimeout
          ++runIndex1
          runTimeout = 0.0
      if done
        runStep = STEP_DONE
      return EBehResult ER_RUNNING

    if runIndex2 <= 0
      query(runTeamEid) <| $ [es] (var team_bots__mortarAttackSquadsEids : EidList&)
        if runTicketIdx < length(team_bots__mortarAttackSquadsEids)
          team_bots__mortarAttackSquadsEids[runTicketIdx] = INVALID_ENTITY_ID
      query(runPlayerEid) <| $ [es] (var botPlayer__nextMortarAttackTime : float&; botPlayer__timeBetweenPlanningMortarAttacks : float2)
        botPlayer__nextMortarAttackTime = curTime + rnd_float(botPlayer__timeBetweenPlanningMortarAttacks.x, botPlayer__timeBetweenPlanningMortarAttacks.y)
      return EBehResult ER_FAILED
    return EBehResult ER_SUCCESS
