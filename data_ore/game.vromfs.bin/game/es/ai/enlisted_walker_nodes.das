options always_export_initializer = true

require ecs
require DngNet
require app
require enlisted.game.es.ai.ai_aiming_common
require enlisted.game.es.squad_behaviour_command_common
require math.base
require game.es.ai.walker_common
require Covers
require enlisted.game.es.enlisted_covers_common
require CollRes
require DagorSystem
require DagorDataBlock
require math
require math.random
require DagorMathUtils
require DagorMath
require BehNodes
require Grid
require pathfinder
require Dacoll
require DngWalkerai
require enlisted.events_enlisted
require HumanPhys
require DngHuman
require vehicle
require zones
require game.utils.team
require game.es.vehicle.vehicle_events
require game.es.events
require game.es.level_common
require common_shooter.es.concussion_common
require danetlibs.pathfinder.main.pathfinder_common
require common_shooter.es.ai.common_shooter_walker_nodes_common
require common_shooter.es.squad_common
require common_shooter.events_common_shooter
require enlisted.game.es.bomb_site_common
require enlisted.game.es.enlisted_squad_common
require enlisted.game.es.ai.ai_covers_common
require enlisted.game.es.fortifications_build_common
require terraform
require walkerai
require game.es.squad_order_common


[beh_node(name="isInConcussion")]
class IsInConcussion : BehNodeAdapter
  def override update(dt : float) : EBehResult
    let isConcussion = has_concussion_affect(beh_tree_eid(owner))
    return isConcussion ? EBehResult ER_SUCCESS : EBehResult ER_FAILED


[beh_node(name="inConcussion")]
class InConcussion : BehNodeAdapter
  isStarted : bool = false
  def override init()
    isStarted = false

  def override update(dt : float) : EBehResult
    var agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult ER_FAILED
    let has_concussion = has_concussion_affect(agent.eid)
    if !has_concussion
      return isStarted ? EBehResult ER_SUCCESS : EBehResult ER_FAILED
    var phys = agent.phys
    if phys == null
      return EBehResult ER_FAILED
    if !isStarted
      isStarted = true
      phys.producedCT |> human_control_state_set_walk_speed(0f)
    return EBehResult ER_RUNNING


[beh_node(name="chooseMaxStance")]
class ChooseMaxStanceNode : BehNodeAdapter
  def override loadFromBlk(var data : DataBlock) : void
    owner.blackBoard |> get_or_create("maxStance", STANCE_STAND)
    owner.blackBoard |> get_or_create("maxStanceOrder", STANCE_STAND)
    owner.blackBoard |> get_or_create("maxStanceOrderForce", false)
    owner.blackBoard |> get_or_create("maxStanceOrderEndTime", 0f)
    owner.blackBoard |> get_or_create("maxStanceAtLeast", STANCE_CRAWL)

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    let maxStanceAtLeast = owner.blackBoard |> datablock_getInt("maxStanceAtLeast", STANCE_CRAWL)
    var maxStanceOrder = owner.blackBoard |> datablock_getInt("maxStanceOrder", STANCE_STAND)
    let maxStanceOrderForce = owner.blackBoard |> datablock_getBool("maxStanceOrderForce", false)
    var resetOder = false
    if maxStanceOrder < STANCE_STAND
      let maxStanceOrderEndTime = owner.blackBoard |> datablock_getReal("maxStanceOrderEndTime", 0f)
      if maxStanceOrderEndTime < get_sync_time()
        resetOder = true
      elif !maxStanceOrderForce && ((get_int(eid, "walker_agent__serverAiAction") ?? int(AiAction AI_ACTION_UNKNOWN)) == int(AiAction AI_ACTION_MOVE))
        resetOder = true

    if resetOder
      maxStanceOrder = STANCE_STAND
      owner.blackBoard |> set("maxStanceOrder", maxStanceOrder)
      owner.blackBoard |> set("maxStanceOrderForce", false)

    owner.blackBoard |> set("maxStance", max(maxStanceAtLeast, maxStanceOrder))
    return EBehResult ER_SUCCESS


[beh_node(name="isSwimming")]
class IsSwimmingNode : BehNodeAdapter
  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    var isSwimming = false
    ecs::query(eid) <| $ [es] (human_net_phys : HumanActor)
      isSwimming = human_phys_state_get_is_swimming(human_net_phys.phys.currentState)
    if !isSwimming
      return EBehResult ER_FAILED
    return EBehResult ER_SUCCESS

[beh_node(name="isReadyForAction")]
class IsReadyForAction : BehNodeAdapter
  checkFence : bool = false
  fenceFailedTimeParam = -1

  timeKeepFail : float = 2.5
  minHeightDown : float = 0.5
  distAheadCheck : float = 1.0

  def override loadFromBlk(var data : DataBlock) : void
    checkFence = datablock_getBool(data, "checkFence", checkFence)
    if checkFence
      fenceFailedTimeParam = owner.blackBoard |> get_or_create("fenceFailedTimeParam", -1.0)
      timeKeepFail = datablock_getReal(data, "timeKeepFail", timeKeepFail)

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    var readyForAction = true
    query(eid) <| $ [es] (human_net_phys : HumanActor; walker_agent : EntityAgent; transform : float3x4; beh_tree__usingLadders : bool = false)
      if human_phys_state_get_is_swimming(human_net_phys.phys.currentState)
        readyForAction = false
        return
      if human_phys_state_get_is_underwater(human_net_phys.phys.currentState)
        readyForAction = false
        return
      if beh_tree__usingLadders && human_net_phys.phys.currentState.isAttachedToLadder
        readyForAction = false
        return
      if checkFence && fenceFailedTimeParam >= 0
        let lastTimeFailed = owner.blackBoard |> datablock_getReal(fenceFailedTimeParam)
        if lastTimeFailed >= 0.0 && get_sync_time() < lastTimeFailed + timeKeepFail
          readyForAction = false
          return
        let pos = transform[3]
        var nextPos = float3()
        if get_agent_pathPos(walker_agent, 0, nextPos)
          if pos.y > nextPos.y + minHeightDown
            owner.blackBoard |> set(fenceFailedTimeParam, get_sync_time())
            readyForAction = false
            return
    return readyForAction ? EBehResult ER_SUCCESS : EBehResult ER_FAILED


[beh_node(name="isIndoor")]
class isIndoorNode : BehNodeAdapter
  offset = float3(0.0, 0.3, 0.0)
  def override update(dt : float) : EBehResult
    var isIndoor = false
    query(beh_tree_eid(owner)) <| $ [es] (transform : float3x4)
      isIndoor = is_pos_indoor(transform[3] + offset)
    return isIndoor ? EBehResult ER_SUCCESS : EBehResult ER_FAILED


def determinate_radius(phys_state : HumanPhysState)
  return determinate_stance(phys_state) == STANCE_CRAWL ? 0.7 : 0.5

[beh_node(name="validateStandPosition")]
class ValidateStandPositionNode : BehNodeAdapter
  movingTime : float = 0f
  maxMovingTime = 2f
  resetWishPositionThreshold = 1f
  wishPosParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    let agent = beh_tree_entity_agent(*owner)
    wishPosParam = owner.blackBoard |> get_or_create("wishPosition", agent.pos)

  def override update(dt : float) : EBehResult
    var agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult ER_SUCCESS
    var phys = agent.phys
    if phys == null
      return EBehResult ER_SUCCESS
    var collides = 0
    var moveDir : float3
    if movingTime < maxMovingTime
      let agentRadius = determinate_radius(phys.currentState)
      for_each_entity_in_grid(ecs_hash("humans"), BSphere3(agent.pos, agentRadius), GridEntCheck BOUNDING) <| $(eid : EntityId; pos : float3)
        if eid != agent.eid && collides <= 2
          ecs::query(eid) <| $ [es] (isAlive : bool; human_net_phys : HumanActor)
            if isAlive
              let radius = determinate_radius(human_net_phys.phys.currentState)
              if distance_sq(agent.pos, pos) <= square(radius + agentRadius)
                let dir = normalize(agent.pos - pos)
                moveDir += dir
                collides ++
    let walkDir = moveDir.xz
    if collides >= 1 && collides <= 2 && length(walkDir) > FLT_EPSILON
      let shootDir = float2(phys.producedCT.wishShootDir.x, phys.producedCT.wishShootDir.z)
      phys.producedCT |> human_control_state_set_world_walk_dir(normalize(walkDir), shootDir)
      phys.producedCT |> human_control_state_set_walk_speed(0.5)
      movingTime += dt
    elif movingTime > 0f
      let wishPos = owner.blackBoard |> datablock_getPoint3(wishPosParam)
      if distance_sq(wishPos, agent.pos) < resetWishPositionThreshold
        owner.blackBoard |> set(wishPosParam, agent.pos)
      phys.producedCT |> human_control_state_set_walk_speed(0f)
      movingTime = 0f

    return movingTime > 0f ? EBehResult ER_RUNNING : EBehResult ER_SUCCESS

// currently unused but might be needed later. TODO: we are sending a net event here using sendEvent which is not allowed now, so a fix is needed
// [beh_node(name="setEnemyMark")]
// class SetEnemyMark : BehNodeAdapter
//   maxTraceCount = 1
//   targetDistSearch = 40f
//   minTargetAngleCos = 0.95
//   minTargetAngleSin = sqrt(1.0 - square(0.95))

//   def override update(dt : float) : EBehResult
//     let agent = beh_tree_entity_agent(*owner)
//     if agent == null
//       return EBehResult ER_SUCCESS
//     let playerEid = get_Eid(agent.eid, "possessedByPlr") ?? INVALID_ENTITY_ID
//     let aimTMRef = get_TMatrix(agent.eid, "human__aimTm")
//     if !playerEid || aimTMRef == null
//       return EBehResult ER_SUCCESS
//     let aimTm = *aimTMRef
//     let tracePos = aimTm[3]
//     let traceDir = aimTm[0]
//     let flags = (ETF_ALL) & ~(ETF_LMESH | ETF_HEIGHTMAP)
//     var tracesCount = 0
//     let radius = targetDistSearch * minTargetAngleSin
//     find_entity_in_grid([[uint[] ecs_hash("humans"); ecs_hash("vehicles")]], tracePos, traceDir, targetDistSearch, radius, GridEntCheck POS) <| $(targetEid : EntityId; targetPos : float3)
//       query(targetEid) <| $ [es] (team : int)
//         if is_teams_friendly(team, agent.teamId) || team == TEAM_UNASSIGNED
//           return
//         var dir = targetPos - tracePos
//         let dist = length(targetPos - tracePos)
//         dir *= safeinv(dist)
//         if dot(dir, traceDir) < minTargetAngleCos
//           return
//         tracesCount++
//         if (rayhit_normalized(tracePos, dir, dist, flags, agent.shootRayMat) ||
//                               traceTransparencyRayRIGenNormalized(tracePos, dir, dist, 0.01) ||
//                               rayhit_smoke_occluders(tracePos, targetPos))
//           return
//         sendEvent(playerEid, [[CmdCreateMapUserPoint pos = targetPos, dir = dir, norm = float3(0.0, 1.0, 0.0), item_name = "enemy" ]]) // should not send net event using sendEvent
//         tracesCount = maxTraceCount // one event per update is enough
//       return tracesCount >= maxTraceCount

//     return EBehResult ER_SUCCESS



[beh_node(name="getRegroupPos")]
class GetRegroupPos : BehNodeAdapter
  posParam : int = -1
  squadEid : ecs::EntityId = ecs::INVALID_ENTITY_ID

  def override loadFromBlk(var data : DataBlock) : void
    let agent = beh_tree_entity_agent(*owner)
    squadEid = get_Eid(agent.eid, "squad_member__squad") ?? ecs::INVALID_ENTITY_ID
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", "wishPosition"), agent.pos)

  def override update(dt : float) : EBehResult
    let agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult ER_FAILED

    let eid = beh_tree_eid(owner)

    query(squadEid) <| $ [es] (squad__regroupPos : float3; squad__leader : ecs::EntityId)
      if squad__leader == eid
        return

      set(owner.blackBoard, posParam, agent.pos)

      query(eid) <| $ [es] (squad_member__isPersonalOrder : bool;
                            squad_member__orderPosition : float3)
        if !squad_member__isPersonalOrder
          let position = squad__regroupPos
          if squad__leader != eid && is_point_safe(position, agent.teamId)
            set(owner.blackBoard, posParam, position)
        else
          set(owner.blackBoard, posParam, squad_member__orderPosition)

    return EBehResult ER_SUCCESS


[beh_node(name="isPosInPit")]
class IsPosInPit : BehNodeAdapter
  posParam : int = -1
  minDepth : float = 0.5

  OVERGROUND_EPSILON : float = 1.0 // because regroup position always at navmesh i.e. over ground
  UNDERGROUND_EPSILON : float = 0.1 // because of ground holes and underground locations

  def override loadFromBlk(var data : DataBlock) : void
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", "wishPosition"), float3())
    minDepth = datablock_getReal(data, "minDepth", minDepth)

  def override update(dt : float) : EBehResult
    let pos = owner.blackBoard |> datablock_getPoint3(posParam)
    let pos2D = float2(pos.x, pos.z)
    if !is_valid_heightmap_pos(pos2D)
      return EBehResult ER_FAILED
    var inPit = false
    let hasResult = find_query() <| $ [es] (terraform : TerraformComponent)
      let origHeight = terraform_getHmapHeightOrigValAtPos(terraform, pos2D)
      if pos.y < origHeight + OVERGROUND_EPSILON
        let nowHeight = traceht_hmap(pos2D)
        inPit = origHeight - nowHeight >= minDepth && pos.y >= nowHeight - UNDERGROUND_EPSILON
      return true
    if !hasResult || !inPit
      return EBehResult ER_FAILED
    return EBehResult ER_SUCCESS


[beh_node(name="setSquadFormation")]
class SetSquadFormation : BehNodeAdapter
  spread : SquadFormationSpread = SquadFormationSpread ESFN_STANDARD

  def override loadFromBlk(var data : DataBlock) : void
    let formationName = data |> datablock_getStr("formation", "")
    if formationName == "closest"
      spread = SquadFormationSpread ESFN_CLOSEST
    elif formationName == "standard"
      spread = SquadFormationSpread ESFN_STANDARD
    elif formationName == "wide"
      spread = SquadFormationSpread ESFN_WIDE
    return

  def override update(dt : float) : EBehResult
    let agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult ER_FAILED

    var ok = false
    query(agent.eid) <| $ [es] (squad_member__squad : EntityId)
      query(squad_member__squad) <| $ [es] (squad__ownerPlayer : EntityId)
        query(squad__ownerPlayer) <| $ [es] (var squadFormationSpread : int&)
          ok = true
          if squadFormationSpread != int(spread)
            squadFormationSpread = int(spread)
            reset_squad_behaviour(squad_member__squad)

    return ok ? EBehResult ER_SUCCESS : EBehResult ER_FAILED


[beh_node(name="isPersonalOrder")]
class IsPersonalOrder : BehNodeAdapter
  def override update(dt : float) : EBehResult
    let agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult ER_FAILED

    let eid = beh_tree_eid(owner)

    var isPersonalOrder = false
    query(eid) <| $ [es] (squad_member__isPersonalOrder : bool)
      isPersonalOrder = squad_member__isPersonalOrder

    return isPersonalOrder ? EBehResult ER_SUCCESS : EBehResult ER_FAILED

[beh_node(name="getRegroupDistance")]
class GetRegroupDistance : BehNodeAdapter
  distParam : int = -1
  squadEid : ecs::EntityId = ecs::INVALID_ENTITY_ID
  minDist : float = 10.0f

  def override loadFromBlk(var data : DataBlock) : void
    squadEid = get_Eid(beh_tree_eid(owner), "squad_member__squad") ?? ecs::INVALID_ENTITY_ID
    distParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "distParam", "regroupDistance"), 10.0f)
    minDist = data |> datablock_getReal("minDist", minDist)

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    set(owner.blackBoard, distParam, minDist)
    query(squadEid) <| $ [es] (squad__spreadAroundOrderPoint : float3; squad__leader : ecs::EntityId)
      if squad__leader != eid
        set(owner.blackBoard, distParam, max(squad__spreadAroundOrderPoint.y * 2.0f, minDist))
    return EBehResult ER_SUCCESS

[beh_node(name="getFollowPosition")]
class GetFollowPosition : BehNodeAdapter
  posParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    let eid = beh_tree_eid(owner)
    var ownerPos : float3
    query(eid) <| $ [es] (transform : float3x4)
      ownerPos = transform[3]
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", "followPos"), ownerPos)

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    query(eid) <| $ [es] (transform : float3x4; squad_member__squad : EntityId = INVALID_ENTITY_ID)
      let ownerPos = transform[3]
      owner.blackBoard |> set(posParam, ownerPos)
      query(squad_member__squad) <| $ [es] (squad__orderType : int = int(SquadOrder ESO_FOLLOW_ME); squad__leader : EntityId)
        if squad__orderType == int(SquadOrder ESO_FOLLOW_ME)
          query(squad__leader) <| $ [es(REQUIRE_NOT=deadEntity)] (transform : float3x4)
            owner.blackBoard |> set(posParam, transform[3])
    return EBehResult ER_SUCCESS

typedef
  ZonePos = tuple < eid : EntityId; pos : float3; radius : float >


def try_find_points_near_cap_zone(agent; var pos : float3&)
  let extents = float3(0.5, FLT_MAX, 0.5)
  return find_query() <| $ [es(REQUIRE=capzone__progress)] (active : bool;
                                                            capzone__hasNearestNavmeshPos : bool;
                                                            capzone__nearestNavmeshPos : float3;
                                                            capzone__minRadius : float)
    if !active || !capzone__hasNearestNavmeshPos
      return false

    for _i in range(5)
      let biasAngle = rnd_float(0.0, TWOPI)
      let radiusExt = 1.5
      let horzExt = 1.5
      let biasPos = float3(capzone__minRadius * cos(biasAngle) * radiusExt,
                           0.,
                           capzone__minRadius * sin(biasAngle) * radiusExt)

      var newPos = capzone__nearestNavmeshPos + biasPos

      let projExtents = float3(horzExt, FLT_MAX, horzExt)
      if (project_to_nearest_navmesh_point_no_obstacles(newPos, projExtents) &&
          check_path(agent.pos, newPos, extents, 0.5, 0.5, agent.customNav))
        pos = newPos
        return true

    pos = capzone__nearestNavmeshPos
    return true

def pick_random_or_closest_position(positions : Point3List; from_pos : float3; closest : bool; round_len : float; def_position : float3)
  if empty(positions)
    return def_position
  var points : array<float3>
  for pos in positions
    var waterLevel = 0.0
    let MAX_HEIGHT_UNDERWATER = -0.1
    if traceht_water(pos, waterLevel)
      if waterLevel - pos.y < MAX_HEIGHT_UNDERWATER
        points |> push(pos)
  if empty(points)
    return def_position
  if !closest
    return points[rnd_int(0, length(points) - 1)]
  var posDist = -1.0
  for pt in points
    let dist = float(int(distance(from_pos, pt) / round_len)) * round_len
    if posDist < 0.0 || dist < posDist
      posDist = dist
  var points2 : array<float3>
  for pt in points
    let dist = float(int(distance(from_pos, pt) / round_len)) * round_len
    if dist == posDist
      points2 |> push(pt)
  if empty(points2)
    return def_position
  return points[rnd_int(0, length(points) - 1)]

[beh_node(name="findPointInCapzone")]
class FindPointInCapzone : BehNodeAdapter
  posParam : int = -1
  targetEidParam : int = -1

  closestPoint : bool = false
  closestRoundLen : float = 5.0

  maxDistSq : float = 1000000.

  squadEid : EntityId = INVALID_ENTITY_ID

  def override loadFromBlk(var data : DataBlock) : void
    query(beh_tree_eid(owner)) <| $ [es] (transform aka agent_transform : float3x4;
                                          squad_member__squad : EntityId)
      posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", "wishPosition"), agent_transform[3])
      squadEid = squad_member__squad

    targetEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetEidParam", "leaderTargetEid"), 0)

    closestPoint = datablock_getBool(data, "closestPoint", closestPoint)
    closestRoundLen = datablock_getReal(data, "closestRoundLen", closestRoundLen)

    let maxDist = datablock_getReal(data, "maxDist", 1000.)
    maxDistSq = maxDist * maxDist

  def override update(dt : float) : EBehResult
    var res = EBehResult ER_FAILED

    query(squadEid) <| $ [es] (squad__leader : EntityId)
      if squad__leader != beh_tree_eid(owner)
        return

      query(beh_tree_eid(owner)) <| $ [es] (transform aka agent_transform : float3x4;
                                            team aka owner_team : int;
                                            squad_member__squad : EntityId)
        let teamHash = string(owner_team)
        var capzones : array<tuple<dist : float; eid : EntityId>>

        query() <| $ [es(REQUIRE=capzone__progress)] (eid : EntityId;
                                                      active : bool;
                                                      capzone__progress : float;
                                                      capzone__hasNearestNavmeshPos : bool;
                                                      capzone__capTeam : int;
                                                      transform aka capzone_transform : float3x4)
          if !active || !capzone__hasNearestNavmeshPos || (abs(1. - capzone__progress) <= FLT_EPSILON && capzone__capTeam == owner_team)
            return

          let distSqr = distance_sq(agent_transform[3], capzone_transform[3])
          capzones |> emplace([[auto distSqr, eid]])

        sort(capzones) <| $(lhs, rhs)
          return lhs.dist < rhs.dist

        for elem in capzones
          if res == EBehResult ER_SUCCESS
            return

          query(elem.eid) <| $ [es] (teamPresence : Object;
                                     capzone__maxTeamPresence : int;
                                     capzone__insideNavmeshPositions : Point3List;
                                     transform aka capzone_transform : float3x4)
            let myTeamInZone = teamPresence[teamHash] != null ? get_ecs_array(teamPresence[teamHash]) : null

            if myTeamInZone == null
              owner.blackBoard |> set(targetEidParam, int(uint(elem.eid)))
              let pos = pick_random_or_closest_position(capzone__insideNavmeshPositions, agent_transform[3], closestPoint, closestRoundLen, capzone_transform[3])
              owner.blackBoard |> set(posParam, pos)

              res = EBehResult ER_SUCCESS
              return

            var uniqueTeams : table<uint>
            for agentEid in *myTeamInZone
              query(get_Eid(agentEid) ?? INVALID_ENTITY_ID) <| $ [es] (squad_member__squad : EntityId)
                uniqueTeams |> insert(uint(squad_member__squad))

            let alreadyOnRoute = uniqueTeams |> key_exists(uint(squad_member__squad))

            if alreadyOnRoute
              owner.blackBoard |> set(targetEidParam, int(uint(elem.eid)))
              let pos = pick_random_or_closest_position(capzone__insideNavmeshPositions, agent_transform[3], closestPoint, closestRoundLen, capzone_transform[3])
              owner.blackBoard |> set(posParam, pos)

              res = EBehResult ER_SUCCESS
              return

            if myTeamInZone != null && length(uniqueTeams) > capzone__maxTeamPresence
              return

            let distSq = distance_sq(capzone_transform[3], agent_transform[3])
            if distSq > maxDistSq
              return

            owner.blackBoard |> set(targetEidParam, int(uint(elem.eid)))
            let pos = pick_random_or_closest_position(capzone__insideNavmeshPositions, agent_transform[3], closestPoint, closestRoundLen, capzone_transform[3])
            owner.blackBoard |> set(posParam, pos)

            res = EBehResult ER_SUCCESS

    return res

[beh_node(name="resetNearCapzone")]
class ResetNearCapzone : BehNodeAdapter
  def override update(dt : float) : EBehResult
    query(beh_tree_eid(owner)) <| $ [es] (var beh_tree__capzoneOfInterest : EntityId&)
      beh_tree__capzoneOfInterest = INVALID_ENTITY_ID

    return EBehResult ER_SUCCESS

[beh_node(name="findPointNearCapzone")]
class FindPointNearCapzone : BehNodeAdapter
  posParam : int = -1
  targetEidParam : int = -1

  closestPoint : bool = false
  closestRoundLen : float = 5.0

  maxDistSq : float = 1000000.

  squadEid : EntityId = INVALID_ENTITY_ID

  def override loadFromBlk(var data : DataBlock) : void
    query(beh_tree_eid(owner)) <| $ [es] (transform aka agent_transform : float3x4;
                                          squad_member__squad : EntityId)
      posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", "wishPosition"), agent_transform[3])
      squadEid = squad_member__squad

    targetEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetEidParam", "leaderTargetEid"), 0)

    closestPoint = datablock_getBool(data, "closestPoint", closestPoint)
    closestRoundLen = datablock_getReal(data, "closestRoundLen", closestRoundLen)

    let maxDist = datablock_getReal(data, "maxDist", 1000.)
    maxDistSq = maxDist * maxDist

  def override update(dt : float) : EBehResult
    var capturedZonesMap : table<uint; uint>

    var res = EBehResult ER_FAILED

    query(squadEid) <| $ [es] (squad__leader : EntityId)
      if squad__leader != beh_tree_eid(owner)
        return

      query(beh_tree_eid(owner)) <| $ [es] (team aka owner_team : int;
                                            transform aka agent_transform : float3x4;
                                            var beh_tree__capzoneOfInterest : EntityId&)
        query() <| $ [es(REQUIRE=capzone)] (eid : EntityId)
          capturedZonesMap[uint(eid)] = 0u

        query() <| $ [es] (team aka agent_team : int;
                           beh_tree__capzoneOfInterest : EntityId)
          if owner_team == agent_team
            capturedZonesMap[uint(beh_tree__capzoneOfInterest)] += 1u

        let alreadyOnRoute = find_query() <| $ [es] (eid : EntityId;
                                                     active : bool;
                                                     capzone__hasNearestNavmeshPos : bool)
          if !active || !capzone__hasNearestNavmeshPos
            return false

          return beh_tree__capzoneOfInterest == eid

        if alreadyOnRoute
          res = EBehResult ER_SUCCESS
          return

        var maxTeamInZone = UINT_MAX

        query() <| $ [es(REQUIRE=capzone__progress)] (eid : EntityId;
                                                      active : bool;
                                                      capzone__hasNearestNavmeshPos : bool;
                                                      capzone__outsideNavmeshPositions : Point3List;
                                                      transform aka capzone_transform : float3x4)
          if !active || !capzone__hasNearestNavmeshPos
            return

          let distSq = distance_sq(capzone_transform[3], agent_transform[3])
          if distSq > maxDistSq
            return

          if capturedZonesMap[uint(eid)] <= maxTeamInZone
            beh_tree__capzoneOfInterest = eid
            owner.blackBoard |> set(targetEidParam, int(uint(eid)))

            let pos = pick_random_or_closest_position(capzone__outsideNavmeshPositions, agent_transform[3], closestPoint, closestRoundLen, capzone_transform[3])
            owner.blackBoard |> set(posParam, pos)

            maxTeamInZone = capturedZonesMap[uint(eid)]

            res = EBehResult ER_SUCCESS

    return res

[beh_node(name="initPeriodicTimer")]
class InitPeriodicTimer : BehNodeAdapter
  timeParam : int = -1
  timePeriod : float2 = float2(2.5, 5.)

  def override loadFromBlk(var data : DataBlock)
    timeParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "timeParam", "time"), 0.)

    timePeriod = datablock_getPoint2(data, "timePeriod", float2(2.5, 5.))

  def override update(dt : float) : EBehResult
    owner.blackBoard |> set(timeParam, get_sync_time() + rnd_float(timePeriod.x, timePeriod.y))
    return EBehResult ER_SUCCESS

[beh_node(name="periodicTimer")]
class PeriodicTimer : BehNodeAdapter
  timeParam : int = -1

  timePeriod : float2 = float2(2.5, 5.)

  def override loadFromBlk(var data : DataBlock)
    timeParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "timeParam", "time"), 0.)

    timePeriod = datablock_getPoint2(data, "timePeriod", float2(2.5, 5.))

  def override update(dt : float) : EBehResult
    let prevTime = owner.blackBoard |> datablock_getReal(timeParam)

    let curTime = get_sync_time()

    if prevTime - curTime < 0.
      owner.blackBoard |> set(timeParam, curTime + rnd_float(timePeriod.x, timePeriod.y))
      return EBehResult ER_SUCCESS

    return EBehResult ER_FAILED


[beh_node(name="leaderBehaviour")]
class LeaderBehaviour : BehNodeAdapter
  squadEid : ecs::EntityId = ecs::INVALID_ENTITY_ID
  posParam : int = -1
  targetZonePosParam : int = -1 // leader target zone center
  targetPosParam : int = -1 // actual leader target (zone center or point in world)
  targetEidParam : int = -1 // actual leader target eid (zone)
  updateInterval : float = 2.5
  updateParam : int = -1
  dangerAreasCheckDistance : float = 30.0

  def override loadFromBlk(var data : DataBlock) : void
    let agent = beh_tree_entity_agent(*owner)
    squadEid = get_Eid(agent.eid, "squad_member__squad") ?? ecs::INVALID_ENTITY_ID
    updateInterval = data |> datablock_getReal("updateInterval", updateInterval)
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", "wishPosition"), agent.pos)
    targetZonePosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetZonePosParam", "leaderTargetZonePos"), agent.pos)
    targetPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetPosParam", "leaderTargetPos"), agent.pos)
    targetEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetEidParam", "leaderTargetEid"), 0)
    updateParam = owner.blackBoard |> get_or_create("leaderBehaviourUpdate", 2.5)
    dangerAreasCheckDistance = data |> datablock_getReal("dangerAreasCheckDistance", dangerAreasCheckDistance)

  def override update(dt : float) : EBehResult
    let agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult ER_FAILED

    if get_sync_time() < (owner.blackBoard |> datablock_getReal(updateParam))
      return EBehResult ER_FAILED

    let targetZonePos = owner.blackBoard |> datablock_getPoint3(targetZonePosParam)
    let targetPos = owner.blackBoard |> datablock_getPoint3(targetPosParam)
    var nextPos : ZonePos = [[auto EntityId(uint(owner.blackBoard |> datablock_getInt(targetEidParam))), targetPos,-1f]]
    let oldZoneEid = nextPos.eid

    var isLeader = false
    var renewTargetPos = false
    query(squadEid) <| $ [es] (squad__leader : ecs::EntityId)
      if squad__leader != agent.eid
        return
      isLeader = true

      let maxDist = 1000.0
      let teamHash = string(agent.teamId)
      var alreadyOnRoute = false

      ecs::find_query() <| $ [es(REQUIRE=capzone__progress)] (transform : float3x4; capzone__owningTeam : int; capzone__maxTeamPresence : int;
                                                              capzone__hasNearestNavmeshPos : bool; capzone__nearestNavmeshPos : float3;
                                                              teamPresence : ecs::Object; active : bool)
        if !active || agent.teamId == capzone__owningTeam || !capzone__hasNearestNavmeshPos
          return false
        let zonePos = transform[3];
        let distSq = distance_sq(zonePos, agent.pos)
        if distSq > square(maxDist)
          return false
        let myTeamInZone = teamPresence[teamHash] != null ? get_ecs_array(deref(teamPresence[teamHash])) : null
        if myTeamInZone != null && length(*myTeamInZone) > capzone__maxTeamPresence
          return false
        if capzone__nearestNavmeshPos == targetZonePos
          alreadyOnRoute = true
          return true
        return false

      if alreadyOnRoute
        if (oldZoneEid != INVALID_ENTITY_ID) && ((length_sq(agent.pos - targetPos) <= dangerAreasCheckDistance * dangerAreasCheckDistance))
          query(agent.eid) <| $ [es] (agentDangerAreas : ecs::Object)
            if danger_areas_test_point(agentDangerAreas, targetPos)
              renewTargetPos = true
        return
      var validZones : array<ZonePos>
      var allZones : array<ZonePos>
      ecs::query() <| $ [es(REQUIRE=capzone__progress)] (eid : EntityId; transform : float3x4; capzone__owningTeam : int; capzone__maxTeamPresence : int;
                                                         capzone__hasNearestNavmeshPos : bool; capzone__nearestNavmeshPos : float3;
                                                         teamPresence : ecs::Object; active : bool; capzone__minRadius = -1f)
        if !active || !capzone__hasNearestNavmeshPos
          return
        var zonePos = transform[3]
        let distSq = distance_sq(zonePos, agent.pos)
        if distSq > square(maxDist)
          return
        let myTeamInZone = teamPresence[teamHash] != null ? get_ecs_array(deref(teamPresence[teamHash])) : null
        if myTeamInZone != null
          if length(*myTeamInZone) > capzone__maxTeamPresence
            return
        zonePos = capzone__nearestNavmeshPos
        let extents = float3(0.5, FLT_MAX, 0.5)
        let hasPath = pathfinder::find_path(agent.pos, zonePos, extents, 1.0, 0.25, agent.customNav)
        if hasPath != FindPathResult FPR_FAILED
          if agent.teamId != capzone__owningTeam
            validZones |> emplace([[auto eid, zonePos, capzone__minRadius]])
          allZones |> emplace([[auto eid, zonePos, capzone__minRadius]])

      if length(validZones) > 0
        nextPos = validZones[grnd() % length(validZones)]
        return

      if length(allZones) > 0
        nextPos = allZones[grnd() % length(allZones)]
        return

      if !alreadyOnRoute
        var pos = float3()
        if try_find_points_near_cap_zone(agent, pos)
          nextPos = [[auto INVALID_ENTITY_ID, pos,-1f]]
          return

      nextPos = [[auto INVALID_ENTITY_ID, datablock_getPoint3(owner.blackBoard, posParam),-1f]]

    if !isLeader
      return EBehResult ER_FAILED

    // if renewTargetPos is true then targetPos is already valid, but in danger.
    // try to find a better one.
    if renewTargetPos
      query(oldZoneEid) <| $ [es] (capzone__minRadius : float; capzone__nearestNavmeshPos : float3)
        nextPos.eid = oldZoneEid
        nextPos.radius = capzone__minRadius
        nextPos.pos = capzone__nearestNavmeshPos
    var result = nextPos.pos
    var found = false
    if nextPos.eid != INVALID_ENTITY_ID && nextPos.radius > 0f
      var tries = 5
      while tries -- > 0
        var s, c : float
        sincos(gfrnd() * PI * 2.0, s, c)
        let radius = (0.1f + gfrnd() * 0.9f) * max(nextPos.radius - 2.0f, 0.0f)
        let randomPos = nextPos.pos + float3(c * radius, 0f, s * radius)
        let extents = float3(0.5, FLT_MAX, 0.5)
        let newPos = get_lower_navmesh_pos(randomPos, 0.5f) <| $(p)
          return is_point_in_capzone(p, nextPos.eid, 1.0) && check_path(nextPos.pos, p, extents, 0.5, 0.5, agent.customNav)
        if newPos is pos
          result = newPos as pos
          found = true
          var isSafe = true
          if renewTargetPos
            query(agent.eid) <| $ [es] (agentDangerAreas : ecs::Object)
              isSafe = !danger_areas_test_point(agentDangerAreas, result)
          if isSafe
            break

    owner.blackBoard |> set(updateParam, get_sync_time() + updateInterval)
    if found
      owner.blackBoard |> set(targetPosParam, result)
      owner.blackBoard |> set(targetZonePosParam, nextPos.pos)
      owner.blackBoard |> set(targetEidParam, int(uint(nextPos.eid)))
    owner.blackBoard |> set(posParam, result)
    return found ? EBehResult ER_SUCCESS : EBehResult ER_FAILED



[beh_node(name="deactivateWeapMod")]
class DeactivateWeapModNode : BehNodeAdapter
  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    ecs::query(eid) <| $ [es] (human_weap__currentGunSlot : int; human_weap__gunMods : ecs::Array)
      if human_weap__currentGunSlot < 0
        return
      let gunModEids = get_ecs_EidList(human_weap__gunMods[human_weap__currentGunSlot])
      for gunMod in *gunModEids
        ecs::query(gunMod) <| $ [es] (weapon_mod__active : bool)
          if weapon_mod__active
            sendEvent(eid, [[CmdWeapModActivate slotId=human_weap__currentGunSlot, activate=false]])
    return EBehResult ER_SUCCESS



[beh_node(name="shouldEquipBuildTool")]
class ShouldEquipBuildTool : BehNodeAdapter
  targetEidParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    targetEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetParam", "targetParam"), 0)

  def override update(dt : float) : EBehResult
    let target = EntityId(uint(owner.blackBoard |> datablock_getInt(targetEidParam)))
    return has(target, "builder_preview") ? EBehResult ER_SUCCESS : EBehResult ER_FAILED

[beh_node(name="interactWithBuildingTarget")]
class InteractWithBuildingTarget : BehNodeAdapter
  targetEidParam : int = -1
  syncDelayExtraTime : float = 0.5
  endAtTimeLimit : float = -1.0

  def override loadFromBlk(var data : DataBlock) : void
    targetEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetUnitParam", "targetUnitParam"), 0)
    syncDelayExtraTime = datablock_getReal(data, "syncDelayExtraTime", syncDelayExtraTime)

  def override init()
    endAtTimeLimit = -1.0

  def override exit()
    var agent = beh_tree_entity_agent(*owner)
    var phys = agent.phys
    if phys != null
      phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType HCT_SHOOT, false)
    send_net_event(agent.eid, [[EventSetBuildingTarget target = INVALID_ENTITY_ID]])

  def override update(dt : float) : EBehResult
    var agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult ER_FAILED
    var phys = agent.phys
    if phys == null
      return EBehResult ER_SUCCESS
    let target = EntityId(uint(owner.blackBoard |> datablock_getInt(targetEidParam)))
    if !target
      return EBehResult ER_SUCCESS
    if endAtTimeLimit < 0.0
      let maxInteractTime = get_float(target, "building_builder__maxTimeToBuild") ?? get_float(target, "building_destroy__maxTimeToDestroy") ?? 0.0
      endAtTimeLimit = get_sync_time() + maxInteractTime + syncDelayExtraTime

    let weapon = get_Eid(agent.eid, "human_weap__currentGunEid") ?? INVALID_ENTITY_ID
    let buildingToolSelected = has(weapon, "buildingTool")
    if buildingToolSelected
      phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType HCT_SHOOT, true)

    if get_Eid(agent.eid, "building_action__target") ?? INVALID_ENTITY_ID != target
      if has(target, "builder_server_preview")
        if !buildingToolSelected
          return EBehResult ER_SUCCESS // don't try to build without building tool
        send_net_event(agent.eid, [[EventSetBuildingTarget target = target]])
      else
        send_net_event(agent.eid, [[EventDismantleBuilding target=target]])

    return endAtTimeLimit < get_sync_time() ? EBehResult ER_SUCCESS : EBehResult ER_RUNNING


def add_to_set(var set : int&; index : int)
  set |= (1 << index)

def remove_from_set(var set : int&; index : int)
  set &= ~(1 << index)

def is_in_set(set : int; index : int)
  return (set & (1 << index)) != 0


let
  SEAT_DRIVER = 0
  SEAT_MAIN_GUNNER = 1
  SEAT_LOADER = 2
  SEAT_COMMANDER = 3
  SEAT_EXTRA_GUNNER = 4
  SEAT_PLAYER_SWAP = 5

struct AgentSeatSkills
  found : bool = false
  driverScore : float = 0.0
  gunnerScore : float = 0.0
  loaderScore : float = 0.0

def get_agent_seat_skills(agent_eid : EntityId) : AgentSeatSkills
  var skills : AgentSeatSkills
  query(agent_eid) <| $ [es] (driver_skills__brakingTauMult : float = 1.0;
                              driver_skills__gearChangeTimeMult : float = 1.0;
                              driver_skills__drivingSpeedThresholdMult : float = 1.0;
                              entity_mods__turretPitchMultWhenAimingYaw : float = 0.0;
                              entity_mods__canChangeShellDuringVehicleGunReload : bool = false;
                              entity_mods__vehicleReloadMult : float = 1.0)
    skills.found = true
    skills.driverScore = cvt(driver_skills__brakingTauMult * driver_skills__gearChangeTimeMult * driver_skills__drivingSpeedThresholdMult, 1.0, 0.0, 0.0, 0.9)
    skills.gunnerScore = cvt(entity_mods__turretPitchMultWhenAimingYaw, 0.0, 10.0, 0.0, 0.9)
    skills.loaderScore = cvt(entity_mods__vehicleReloadMult * (entity_mods__canChangeShellDuringVehicleGunReload ? 0.5 : 1.0), 1.0, 0.0, 0.0, 0.9)
  return skills

def get_seat_affinity(seat_eid : EntityId; soldier_squad : EntityId; allow_non_controllable_gunner_seat : bool)
  var mask = 0
  query(seat_eid) <| $ [es] (seat__availableControls : VehicleControlsState;
                             seat__commonTurretControlMask : uint;
                             seats_order__canPlaceManually : bool;
                             seats_order__canPlaceOnlyOwner : bool = false;
                             seat__vehicleEid : EntityId;
                             seat__squadEid : EntityId;
                             seat__ownerEid : EntityId;
                             seats_order__isExtraPlace : bool = false;
                             seat__loaderTurretIds : IntList const?;
                             seatsCommander : Tag const?)
    let seatHasGuns = (seat__availableControls.turretsMask & ~seat__commonTurretControlMask) != 0u
    let vehicleOwnerSquad = get_Eid(seat__vehicleEid, "ownedBySquad") ?? INVALID_ENTITY_ID
    if seats_order__canPlaceOnlyOwner && !!vehicleOwnerSquad && vehicleOwnerSquad != soldier_squad
      return
    if !!seat__ownerEid && seat__squadEid == vehicleOwnerSquad && soldier_squad != vehicleOwnerSquad
      return
    let isCommanderSeat = seatsCommander != null
    let isDriverSeat = seat__availableControls.canControlVehicle
    let isMainGunnerSeat = seatHasGuns && (seats_order__canPlaceManually || allow_non_controllable_gunner_seat) && !seats_order__isExtraPlace
    let isLoaderSeat = seat__loaderTurretIds != null && length(*seat__loaderTurretIds) > 0
    let isExtraGunnerSeat = seatHasGuns && !isMainGunnerSeat
    let isPlayerSwapSeat = seats_order__canPlaceManually

    if isCommanderSeat
      add_to_set(mask, SEAT_COMMANDER)
    elif isDriverSeat
      add_to_set(mask, SEAT_DRIVER)
    elif isMainGunnerSeat
      add_to_set(mask, SEAT_MAIN_GUNNER)
    elif isLoaderSeat
      add_to_set(mask, SEAT_LOADER)
    elif isExtraGunnerSeat
      add_to_set(mask, SEAT_EXTRA_GUNNER)
    elif isPlayerSwapSeat
      add_to_set(mask, SEAT_PLAYER_SWAP)
  return mask

def get_seat_priority(seat_mask : int; agent_skills : AgentSeatSkills)
  if is_in_set(seat_mask, SEAT_DRIVER)
    return 6.0 + agent_skills.driverScore - (agent_skills.gunnerScore + agent_skills.loaderScore) * 0.05
  if is_in_set(seat_mask, SEAT_MAIN_GUNNER)
    return 5.0 + agent_skills.gunnerScore - (agent_skills.driverScore + agent_skills.loaderScore) * 0.05
  if is_in_set(seat_mask, SEAT_LOADER)
    return 4.0 + agent_skills.loaderScore - (agent_skills.driverScore * agent_skills.gunnerScore) * 0.05
  if is_in_set(seat_mask, SEAT_COMMANDER)
    return 3.0
  if is_in_set(seat_mask, SEAT_EXTRA_GUNNER)
    return 2.0 + agent_skills.gunnerScore - (agent_skills.driverScore + agent_skills.loaderScore) * 0.05
  if is_in_set(seat_mask, SEAT_PLAYER_SWAP)
    return 1.0
  return 0.0


[beh_node(name="checkVehicleSeats")]
class CheckVehicleSeats : BehNodeAdapter

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)

    var res = EBehResult ER_FAILED

    query(eid) <| $ [es] (human_anim__vehicleSelected : EntityId;
                          isInVehicle : bool = false;
                          isAlive : bool = false;
                          squad_member__squad : EntityId;
                          maxVehicleVelocityCanReEnter : float = 1.0)
      let vehicleEid = human_anim__vehicleSelected
      if !vehicleEid || !isInVehicle || !isAlive
        return

      query(vehicleEid) <| $ [es] (vehicle_seats__seatEids : EidList;
                                   net_phys__currentStateVelocity : float3 = float3())
        var nowSeatNo = -1
        var nowRoomSpace = -1
        var nowBusy = false

        for seatNo, seatEid in iter_range(vehicle_seats__seatEids), vehicle_seats__seatEids
          query(seatEid) <| $ [es] (seat__ownerEid : EntityId;
                                    seat__roomSpace : int = -1;
                                    seats_switch_time__time : float)
            if seat__ownerEid == eid
              nowSeatNo = seatNo
              nowRoomSpace = seat__roomSpace
              nowBusy = seats_switch_time__time > 0.0
          if nowSeatNo >= 0
            break
        if nowBusy || nowSeatNo < 0
          return

        let curvel = net_phys__currentStateVelocity
        let maxvel = maxVehicleVelocityCanReEnter
        let canChangeRoomNow = maxvel < 0.0 || length_sq(curvel) < maxvel * maxvel

        var seatsAll = 0
        var seatsFilter = -1
        var numOtherDrivers = 0
        var numOtherCommanders = 0
        var seatMasks : array<int>
        var crewSkills : array<AgentSeatSkills>
        resize(seatMasks, length(vehicle_seats__seatEids))
        resize(crewSkills, length(vehicle_seats__seatEids))

        var hasMainGunner = false
        for seatNo, seatEid in iter_range(vehicle_seats__seatEids), vehicle_seats__seatEids
          let seatMask = get_seat_affinity(seatEid, squad_member__squad, false)
          seatMasks[seatNo] = seatMask
          if is_in_set(seatMask, SEAT_MAIN_GUNNER)
            hasMainGunner = true
        if !hasMainGunner
          for seatNo, seatEid in iter_range(vehicle_seats__seatEids), vehicle_seats__seatEids
            let seatMask = get_seat_affinity(seatEid, squad_member__squad, true)
            seatMasks[seatNo] = seatMask

        for seatNo, seatEid in iter_range(vehicle_seats__seatEids), vehicle_seats__seatEids
          query(seatEid) <| $ [es] (seat__ownerEid : EntityId;
                                    seats_switch_time__time : float;
                                    seats_switch_time__newSeatNo : int = -1;
                                    seat__adjacentSeat : int = -1;
                                    seat__roomSpace : int = -1;
                                    seat__isLocked : bool = false;
                                    seats_order__notForBots : bool = false)
            let isBusySeat = nowSeatNo == seatNo || seats_switch_time__time > 0.0 || seats_switch_time__newSeatNo >= 0
            let hasAliveOwner = !!seat__ownerEid && get_bool(seat__ownerEid, "isAlive") ?? false
            let isAIEnabled = get_bool(seat__ownerEid, "beh_tree__enabled") ?? false
            let canMoveToSeatRoom = canChangeRoomNow || nowRoomSpace == seat__roomSpace || nowRoomSpace < 0 || seat__roomSpace < 0

            add_to_set(seatsAll, seatNo)

            if hasAliveOwner && isAIEnabled
              crewSkills[seatNo] = get_agent_seat_skills(seat__ownerEid)

            if isBusySeat || (hasAliveOwner && !isAIEnabled) || !canMoveToSeatRoom || seat__isLocked || seats_order__notForBots
              remove_from_set(seatsFilter, seatNo)

            if hasAliveOwner && seats_switch_time__time > 0.0 && seats_switch_time__newSeatNo >= 0
              remove_from_set(seatsFilter, seats_switch_time__newSeatNo)

            if seat__adjacentSeat > -1
              query(vehicle_seats__seatEids[seat__adjacentSeat]) <| $ [es] (seat__ownerEid aka adjacent_seat__ownerEid : EntityId)
                if !!adjacent_seat__ownerEid && (get_bool(adjacent_seat__ownerEid, "isAlive") ?? false)
                  remove_from_set(seatsFilter, seat__adjacentSeat)
                  remove_from_set(seatsFilter, seatNo)

            let seatMask = seatMasks[seatNo]
            if hasAliveOwner && !isBusySeat
              if is_in_set(seatMask, SEAT_DRIVER)
                ++numOtherDrivers
              if is_in_set(seatMask, SEAT_COMMANDER)
                ++numOtherCommanders

        let seatsFiltered = seatsAll & seatsFilter
        if seatsFiltered == 0
          return

        let nowSeatMask = seatMasks[nowSeatNo]
        if is_in_set(nowSeatMask, SEAT_DRIVER) && numOtherDrivers <= 0
          return

        let agentSkills = crewSkills[nowSeatNo]
        var nowPriority = get_seat_priority(nowSeatMask, agentSkills)
        if is_in_set(nowSeatMask, SEAT_COMMANDER) && numOtherCommanders > 0
          nowPriority = 0.0

        var seatTakeNo = -1
        var seatTakePriority = -1.0
        for seatOrder, seatOrderEid in iter_range(vehicle_seats__seatEids), vehicle_seats__seatEids
          let seatNo = get_int(seatOrderEid, "seats_order__seatNo") ?? seatOrder
          if !is_in_set(seatsFiltered, seatNo) || seatNo < 0
            continue

          let takePriority = get_seat_priority(seatMasks[seatNo], agentSkills)
          if takePriority <= nowPriority
            continue
          let thatPriority = crewSkills[seatNo].found ? get_seat_priority(seatMasks[seatNo], crewSkills[seatNo]) : -1.0
          if thatPriority >= takePriority
            continue

          var bestCrewSeatNo = -1
          var bestCrewPriority = -1.0
          for crewSeatNo, crewMemberSkills in iter_range(crewSkills), crewSkills
            if crewMemberSkills.found
              let crewPriority = get_seat_priority(seatMasks[crewSeatNo], crewMemberSkills)
              let takeCrewPriority = get_seat_priority(seatMasks[seatNo], crewMemberSkills)
              if takeCrewPriority > crewPriority && (bestCrewSeatNo < 0 || bestCrewPriority < crewPriority)
                bestCrewSeatNo = crewSeatNo
                bestCrewPriority = crewPriority

          if bestCrewSeatNo >= 0 && (takePriority < bestCrewPriority || (takePriority == bestCrewPriority && bestCrewSeatNo > nowSeatNo))
            return

          if seatTakeNo < 0 || seatTakePriority < takePriority
            seatTakeNo = seatNo
            seatTakePriority = takePriority

        if seatTakeNo >= 0
          sendEvent(vehicleEid, [[CmdVehicleChangeSeat eid=eid, seat=seatTakeNo]])
          res = EBehResult ER_SUCCESS
    return res


[beh_node(name="getOrderPosition")]
class GetOrderPosition : BehNodeAdapter
  posParam : int = -1
  orderPosParam : int = -1
  traceVisible : bool = false

  def override loadFromBlk(var data : DataBlock) : void
    let agent = beh_tree_entity_agent(*owner)
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", "wishPosition"), agent.pos)
    orderPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "orderPosParam", "wishPosition"), agent.pos)
    traceVisible = datablock_getBool(data, "traceVisible", traceVisible)

  def override update(dt : float) : EBehResult
    let agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult ER_FAILED

    let oldPos = datablock_getPoint3(owner.blackBoard, posParam)

    set(owner.blackBoard, orderPosParam, agent.pos)
    if is_point_safe(oldPos, agent.teamId)
      set(owner.blackBoard, orderPosParam, oldPos)

    query(agent.eid) <| $ [es] (squad_member__squad : ecs::EntityId;
                                squad_member__orderType : int;
                                squad_member__offset : float3;
                                squad_member__isPersonalOrder : bool;
                                squad_member__orderPosition : float3)
      query(squad_member__squad) <| $ [es] (squad__leader : ecs::EntityId;
                                            squad__orderType : int;
                                            squad__regroupPos : float3;
                                            squad__spreadAroundOrderPoint : float3)
        if !squad_member__isPersonalOrder && squad__leader != agent.eid
          var wishPosition = find_best_squad_pos(squad__leader, squad__orderType, squad__regroupPos,
            squad_member__offset, squad__spreadAroundOrderPoint.x)

          if wishPosition.isValidPt && traceVisible
            let actorRadius = 0.3
            var ofs = wishPosition.p - squad__regroupPos; ofs.y = 0.0
            let dir = normalize(ofs)
            var t1 = length(ofs) + actorRadius
            var t2 = t1
            var norm : float3
            if (traceray_normalized(squad__regroupPos + float3(0.0, 0.3, 0.0), dir, t1, norm, ETF_ALL)
             || traceray_normalized(squad__regroupPos + float3(0.0, 1.3, 0.0), dir, t2, norm, ETF_ALL))
              let dist = max(0.0, min(t1, t2) - actorRadius)
              let projExtents = float3(0.5, 2.5, 0.5)
              var tracedPos = squad__regroupPos + dir * dist
              if pathfinder::project_to_nearest_navmesh_point_no_obstacles(tracedPos, projExtents)
                wishPosition.p = tracedPos

          if wishPosition.isValidPt && is_point_safe(wishPosition.p, agent.teamId)
            set(owner.blackBoard, orderPosParam, wishPosition.p)
        elif squad_member__orderType == int(SquadMateOrder ESMO_DEFEND_POINT) && squad_member__isPersonalOrder
          var leaderTm = IDENT_TM
          query(squad__leader) <| $ [es] (transform : float3x4)
            leaderTm = transform
          leaderTm[3] = squad_member__orderPosition

          let wishPosition = find_best_squad_pos(leaderTm, float3(0.0, 0.0, 0.0), 0.0)
          if is_point_safe(wishPosition, agent.teamId)
            set(owner.blackBoard, orderPosParam, wishPosition)

    return EBehResult ER_SUCCESS


[beh_node(name="findNearestActiveBombSiteForPlanting")]
class FindNearestActiveBombSiteForPlanting : BehNodeAdapter
  bombSitePosParam : int = -1
  bombSiteEidParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    let agent = beh_tree_entity_agent(*owner)
    bombSitePosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "bombSitePosParam", "bombSitePos"), agent.pos)
    bombSiteEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "bombSiteEidParam", "bombSiteEid"), 0)

  def override update(dt : float) : EBehResult
    let agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult ER_FAILED

    var bombSiteInRadiusDistSqr = 0.

    query(agent.eid) <| $ [es] (beh_tree__bombSiteInRadiusDistSqr : float)
      bombSiteInRadiusDistSqr = beh_tree__bombSiteInRadiusDistSqr

    let found = find_query() <| $ [es] (eid : EntityId;
                                        active : bool;
                                        transform : float3x4;
                                        bomb_site__plantingTeam : int;
                                        bomb_site__isPlantingOrReseting : bool;
                                        bomb_site__isBombPlanted : bool)
      if (active && agent.teamId == bomb_site__plantingTeam &&
         !bomb_site__isPlantingOrReseting && !bomb_site__isBombPlanted)
        let isNearBombSite = distance_sq(agent.pos, transform[3]) < bombSiteInRadiusDistSqr
        if isNearBombSite
          owner.blackBoard |> set(bombSitePosParam, transform[3])
          owner.blackBoard |> set(bombSiteEidParam, int(uint(eid)))
          return true
      return false

    return found ? EBehResult ER_SUCCESS : EBehResult ER_FAILED

[beh_node(name="findNearestActiveBombSiteForDefusing")]
class FindNearestActiveBombSiteForDefusing : BehNodeAdapter
  bombSitePosParam : int = -1
  bombSiteEidParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    let agent = beh_tree_entity_agent(*owner)
    bombSitePosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "bombSitePosParam", "bombSitePos"), agent.pos)
    bombSiteEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "bombSiteEidParam", "bombSiteEid"), 0)

  def override update(dt : float) : EBehResult
    let agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult ER_FAILED

    var bombSiteInRadiusDistSqr = 0.

    query(agent.eid) <| $ [es] (beh_tree__bombSiteInRadiusDistSqr : float)
      bombSiteInRadiusDistSqr = beh_tree__bombSiteInRadiusDistSqr

    let found = find_query() <| $ [es] (eid : EntityId;
                                        active : bool;
                                        transform : float3x4;
                                        bomb_site__plantingTeam : int;
                                        bomb_site__isDefusing : bool;
                                        bomb_site__isBombPlanted : bool)
      if (active && agent.teamId != bomb_site__plantingTeam &&
          bomb_site__isBombPlanted && !bomb_site__isDefusing)
        let isNearBombSite = distance_sq(agent.pos, transform[3]) < bombSiteInRadiusDistSqr
        if isNearBombSite
          owner.blackBoard |> set(bombSitePosParam, transform[3])
          owner.blackBoard |> set(bombSiteEidParam, int(uint(eid)))
          return true
      return false

    return found ? EBehResult ER_SUCCESS : EBehResult ER_FAILED


[beh_node(name="checkPlantBombOrder")]
class CheckPlantBombOrder : BehNodeAdapter
  bombSitePosParam : int = -1
  bombSiteEidParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (transform : float3x4)
      bombSitePosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "bombSitePosParam", "bombSitePos"), transform[3])
    bombSiteEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "bombSiteEidParam", "bombSiteEid"), 0)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)

    var hasPlantBombOrder = false

    query(agentEid) <| $ [es] (squad_member__orderType : int;
                               squad_member__orderPosition : float3;
                               squad_member__orderUseEntity : EntityId)
      if squad_member__orderType == int(SquadMateOrder ESMO_PLANT_BOMB)
        owner.blackBoard |> set(bombSitePosParam, squad_member__orderPosition)
        owner.blackBoard |> set(bombSiteEidParam, int(uint(squad_member__orderUseEntity)))
        hasPlantBombOrder = true

    return hasPlantBombOrder ? EBehResult ER_SUCCESS : EBehResult ER_FAILED


[beh_node(name="checkDefuseBombOrder")]
class CheckDefuseBombOrder : BehNodeAdapter
  bombSitePosParam : int = -1
  bombSiteEidParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    let agent = beh_tree_entity_agent(*owner)
    bombSitePosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "bombSitePosParam", "bombSitePos"), agent.pos)
    bombSiteEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "bombSiteEidParam", "bombSiteEid"), 0)

  def override update(dt : float) : EBehResult
    let agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult ER_FAILED

    var hasDefuseBombOrder = false

    query(agent.eid) <| $ [es] (squad_member__orderType : int;
                                squad_member__orderPosition : float3;
                                squad_member__orderUseEntity : EntityId)
      if squad_member__orderType == int(SquadMateOrder ESMO_DEFUSE_BOMB)
        owner.blackBoard |> set(bombSitePosParam, squad_member__orderPosition)
        owner.blackBoard |> set(bombSiteEidParam, int(uint(squad_member__orderUseEntity)))
        hasDefuseBombOrder = true

    return hasDefuseBombOrder ? EBehResult ER_SUCCESS : EBehResult ER_FAILED


[beh_node(name="plantBombNode")]
class PlantBombNode : BehNodeAdapter
  bomdSiteEidParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    bomdSiteEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "bombSiteEidParam", "bombSiteEid"), 0)

  def override update(dt : float) : EBehResult
    let agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult ER_FAILED

    var isValidAgentstate = false
    query(agent.eid) <| $ [es] (isAlive : bool;
                                isDowned : bool)
      isValidAgentstate = isAlive && !isDowned

    if !isValidAgentstate
      return EBehResult ER_FAILED

    let bombSiteEid = EntityId(uint(owner.blackBoard |> datablock_getInt(bomdSiteEidParam)))
    if !bombSiteEid
      return EBehResult ER_FAILED

    if can_plant_bomb(bombSiteEid, agent.eid)
      sendEvent(bombSiteEid, [[CmdUse requesterEid=agent.eid]])
      return EBehResult ER_RUNNING

    return EBehResult ER_FAILED

[beh_node(name="defuseBombNode")]
class DefuseBombNode : BehNodeAdapter
  bomdSiteEidParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    bomdSiteEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "bombSiteEidParam", "bombSiteEid"), 0)

  def override update(dt : float) : EBehResult
    let agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult ER_FAILED

    var isValidAgentstate = false
    query(agent.eid) <| $ [es] (isAlive : bool;
                                isDowned : bool)
      isValidAgentstate = isAlive && !isDowned

    if !isValidAgentstate
      return EBehResult ER_FAILED

    let bombSiteEid = EntityId(uint(owner.blackBoard |> datablock_getInt(bomdSiteEidParam)))
    if !bombSiteEid
      return EBehResult ER_FAILED

    if (can_defuse_bomb(bombSiteEid, agent.eid))
      sendEvent(bombSiteEid, [[CmdUse requesterEid=agent.eid]])
      return EBehResult ER_RUNNING

    return EBehResult ER_FAILED

[beh_node(name="findPotentialEnemyDirectionEntryPoint")]
class FindPotentialEnemyDirectionEntryPoint : BehNodeAdapter
  posParam : int = -1
  minCoverHeight : float = 1.

  def override loadFromBlk(var data : DataBlock) : void
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", "potentialEnemyPos"), float3())
    minCoverHeight = owner.blackBoard |> datablock_getReal("minCoverHeight", 1.f)

    let agentEid = beh_tree_eid(owner)
    if !(query(agentEid) <| $ [es(REQUIRE=(isAlive, isDowned,
                                                      cover_updater__heldCovers,
                                                      transform))] {})
      logerr("{agentEid}: <{getEntityTemplateName(agentEid)}> findPotentialEnemyDirectionEntryPoint requires agent.isAlive,\
        agent.isDowned, agent.cover_updater__heldCovers and agent.transform fields")

  def override update(dt : float) : EBehResult
    var res = EBehResult ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (isAlive : bool;
                                          isDowned : bool;
                                          cover_updater__heldCovers : ecs::IPoint2List;
                                          transform : float3x4)
      let isValidAgentState = isAlive && !isDowned

      if isValidAgentState && length(cover_updater__heldCovers) != 0
        let heldCoverId = cover_updater__heldCovers[0].x

        var isCoverNearWall = false
        query() <| $ [es] (covers : CoversComponent)
          isCoverNearWall = covers.list[heldCoverId].hLeft >= minCoverHeight && covers.list[heldCoverId].hRight >= minCoverHeight

        if isCoverNearWall && posParam != -1
          let to = owner.blackBoard |> datablock_getPoint3(posParam)

          let extents = float3(0.5, FLT_MAX, 0.5)
          find_path(transform[3], to, extents, 1.0, 1.0, null) <| $(data)
            if length(data) > 1
              let dir = transform[3] + normalize(data[1] - transform[3])
              owner.blackBoard |> set(posParam, dir)

      res = EBehResult ER_SUCCESS

    return res

[beh_node(name="getRandomPointNearTarget")]
class GetRandomPointNearTarget : BehNodeAdapter
  posParam : int = -1
  targetUnitId : int = -1
  targetUnitParam : int = -1

  minMaxAccuracyRange : float2

  distToTargetRangeX : float2 = float2(0.4f, 0.8f)
  distToTargetRangeY : float2 = float2(0.1f, 0.2f)

  minHeightDiff : float = 1.5

  useGenerationByXZ : bool = true
  useGenerationByY : bool = true

  def override loadFromBlk(var data : DataBlock) : void
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3(0., 0., 0.))

    targetUnitParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetUnitParam", ""), 0);

    minMaxAccuracyRange = datablock_getPoint2(data, "minMaxAccuracyRange", float2(8.f, 100.f))

    useGenerationByXZ = datablock_getBool(data, "useGenerationByXZ", true)
    useGenerationByY = datablock_getBool(data, "useGenerationByY", true)

    minHeightDiff = datablock_getReal(data, "minHeightDiff", 1.5);

    query(beh_tree_eid(owner)) <| $ [es] (walker_agent__distToTargetRandomX : float2;
                                          walker_agent__distToTargetRandomY : float2)
      distToTargetRangeX = walker_agent__distToTargetRandomX
      distToTargetRangeY = walker_agent__distToTargetRandomY

  def override init()
    targetUnitId = owner.blackBoard |> datablock_getInt(targetUnitParam)

  def override update(dt : float) : EBehResult
    if targetUnitId == 0
      return EBehResult ER_FAILED

    var pos = float3()
    var agentShootPos = float3()

    query(EntityId(uint(targetUnitId))) <| $ [es] (ai_target : Target)
      pos = ai_target.targetPos

    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (agent_dangers__standShootPos : float3)
      agentShootPos = agent_dangers__standShootPos

    let dirToTarget = pos - agentShootPos;

    let multByAngle = (dot(normalize(pos.xz), normalize(agentShootPos.xz)) + 1.f) * 0.5f

    if useGenerationByXZ
      let rndDistX = rnd_float(distToTargetRangeX.x, distToTargetRangeX.y)
      var sign = 1.f

      if (rnd_int(0, 1) == 0)
        sign = -1.

      let tangentByX = normalize(float3(sign, 0.f, safediv(dirToTarget.x, -dirToTarget.z)));

      pos += tangentByX * rndDistX * multByAngle;

    if useGenerationByY
      let rndDistY = rnd_float(distToTargetRangeY.x, distToTargetRangeY.y)

      if pos.y - agentShootPos.y >= minHeightDiff && rnd_int(0, 1) == 0
        pos.y -= rndDistY * multByAngle;
      else
        pos.y += rndDistY * multByAngle;

    owner.blackBoard |> set(posParam, pos)

    return EBehResult ER_SUCCESS

[beh_node(name="getRandomPointAroundTarget")]
class GetRandomPointAroundTarget : BehNodeAdapter
  posParam : int = -1
  targetUnitId : int = -1
  targetUnitParam : int = -1
  radiusRange : float2 = float2(1.0)
  awayMinRadius : float = 5.0
  minDistanceFromAllies : float = 0.0
  minDistanceFromAlliesSq : float = 0.0
  maxTries : int = 10

  def override loadFromBlk(var data : DataBlock) : void
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3(0., 0., 0.))
    targetUnitParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetUnitParam", ""), 0);
    radiusRange = data |> datablock_getPoint2("radiusRange", radiusRange)
    awayMinRadius = data |> datablock_getReal("awayMinRadius", awayMinRadius)
    minDistanceFromAllies = data |> datablock_getReal("minDistanceFromAllies", minDistanceFromAllies)
    minDistanceFromAlliesSq = square(minDistanceFromAllies)
    maxTries = data |> datablock_getInt("maxTries", maxTries)

  def override init()
    targetUnitId = owner.blackBoard |> datablock_getInt(targetUnitParam)

  def override update(dt : float) : EBehResult
    if targetUnitId == 0
      return EBehResult ER_FAILED

    var targetPos = float3()
    var hasTargetPos = false
    query(EntityId(uint(targetUnitId))) <| $ [es] (ai_target : Target)
      targetPos = ai_target.targetPos
      hasTargetPos = true
    if !hasTargetPos
      return EBehResult ER_FAILED

    var agentShootPos = float3()
    var hasAgentPos = false
    query(beh_tree_eid(owner)) <| $ [es] (agent_dangers__standShootPos : float3)
      agentShootPos = agent_dangers__standShootPos
      hasAgentPos = true
    if !hasAgentPos
      return EBehResult ER_FAILED

    var agentTeam = TEAM_UNASSIGNED
    query(beh_tree_eid(owner)) <| $ [es] (team : int)
      agentTeam = team

    for _i in range(maxTries)
      var pos = targetPos
      let angle = rnd_float(0.0, TWOPI)
      let dist = rnd_float(radiusRange.x, radiusRange.y)
      pos.x += cos(angle) * dist
      pos.z += sin(angle) * dist

      let deltaFromAgent = pos.xz - agentShootPos.xz
      let distToAgentSq = dot(deltaFromAgent, deltaFromAgent)
      if distToAgentSq < square(awayMinRadius)
        let dirFromAgent = normalize(deltaFromAgent)
        pos.x = agentShootPos.x + dirFromAgent.x * awayMinRadius
        pos.z = agentShootPos.z + dirFromAgent.y * awayMinRadius

      if minDistanceFromAllies > 0.0
        var numAllies = 0
        for_each_entity_in_grid(ecs_hash("humans"), BSphere3(pos, minDistanceFromAllies), GridEntCheck BOUNDING) <| $(human_eid : EntityId)
          query(human_eid) <| $ [es(REQUIRE_NOT=deadEntity)] (isAlive : bool;
                                                              transform : float3x4;
                                                              team : int = TEAM_UNASSIGNED;
                                                              isInVehicleHidden : bool = false)
            if !isAlive || isInVehicleHidden
              return
            if distance_sq(transform[3], pos) > minDistanceFromAlliesSq
              return
            if team == agentTeam
              ++numAllies
        if numAllies > 0
          continue

      owner.blackBoard |> set(posParam, pos)
      return EBehResult ER_SUCCESS
    return EBehResult ER_FAILED

[beh_node(name="rotateToPoint")]
class RotateToPoint : BehNodeAdapter
  posParam : int = -1
  angleParam : int = -1
  aimSpeedCoef : float = 1.0
  aimViscosityCoef : float = 1.0
  pitchRange : float2 = float2(-90.0, 90.0)

  walker_agent__aimVelocity = float2()
  wishAimingSpeed : float = 16.
  vertAimingCoef : float = 1.0
  wishDir : float3

  def override loadFromBlk(var data : DataBlock) : void
    if datablock_find_param(data, "posParam") >= 0
      posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3(0., 0., 0.))
    elif datablock_find_param(data, "angleParam") >= 0
      angleParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "angleParam", ""), 0.)
    aimSpeedCoef = data |> datablock_getReal("aimSpeedCoef", aimSpeedCoef)
    aimViscosityCoef = data |> datablock_getReal("aimViscosityCoef", aimViscosityCoef)
    pitchRange = data |> datablock_getPoint2("pitchRange", pitchRange)

  def override init()
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (agent_dangers__standShootPos : float3;
                               walker_agent : EntityAgent;
                               walker_agent__minMaxAimSpeed : float2;
                               walker_agent__minMaxDist : float2)
      assume minMaxDist = walker_agent__minMaxDist
      assume minMaxAimSpeed = walker_agent__minMaxAimSpeed
      assume agentShootPos = agent_dangers__standShootPos
      if posParam >= 0
        let delta = owner.blackBoard |> datablock_getPoint3(posParam) - agentShootPos
        let dist = length(delta)
        let ratio = (minMaxAimSpeed.y - minMaxAimSpeed.x) * safeinv(minMaxDist.y - minMaxDist.x)
        wishAimingSpeed = clamp(minMaxAimSpeed.y - ratio * (dist - minMaxDist.x), minMaxAimSpeed.x, minMaxAimSpeed.y)
        wishAimingSpeed = deg_to_rad(wishAimingSpeed)
        wishDir = normalize(delta)
        let anglesAt = dir_to_angles(walker_agent.shootDir)
        var anglesTo = dir_to_angles(wishDir)
        let clampedPitch = clamp(anglesTo.y, deg_to_rad(pitchRange.x), deg_to_rad(pitchRange.y))
        if anglesTo.y != clampedPitch
          anglesTo.y = clampedPitch
          wishDir = angles_to_dir(anglesTo)
        vertAimingCoef = safediv(abs(anglesTo.y - anglesAt.y), abs(norm_s_ang(anglesTo.x - anglesAt.x)))
        vertAimingCoef = min(vertAimingCoef * 2.0, 1.0)
      else
        wishAimingSpeed = deg_to_rad(minMaxAimSpeed.x)
        vertAimingCoef = 1.0
        let turnAngle = (angleParam >= 0) ? (owner.blackBoard |> datablock_getReal(angleParam)) : 0.0
        if abs(turnAngle) < 0.0001
          wishDir = float3()
        else
          let shootDir = walker_agent.shootDir
          let angleDir = atan2(shootDir.z, shootDir.x) + turnAngle
          wishDir.x = cos(angleDir)
          wishDir.y = shootDir.y * 0.5
          wishDir.z = sin(angleDir)
          wishDir = normalize(wishDir)
    wishAimingSpeed *= aimSpeedCoef

  def override update(dt : float) : EBehResult
    if length_sq(wishDir) < 1e-3
      return EBehResult ER_SUCCESS

    var res = EBehResult ER_FAILED
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (var human_net_phys : HumanActor&;
                               walker_agent__gunAimOffsetCompensation : float;
                               walker_agent__breathOffsetCompensation : float;
                               walker_agent__aimViscosity : float;
                               walker_agent__velViscosity : float;
                               walker_agent__velFactor : float)
      assume phys = human_net_phys.phys
      let curAngles = dir_to_angles(phys.producedCT.wishShootDir)

      let wishAngles = dir_to_angles(wishDir)

      if abs(curAngles.x - wishAngles.x) <= 0.05 && abs(curAngles.y - wishAngles.y) <= 0.05
        phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType HCT_AIM, false)
        res = EBehResult ER_SUCCESS
        return

      let nowDir = phys.producedCT.wishShootDir
      var dir = calc_wish_approach_vel(dt, wishAimingSpeed, nowDir, wishDir,
                                       walker_agent__gunAimOffsetCompensation,
                                       walker_agent__breathOffsetCompensation,
                                       walker_agent__aimViscosity * aimViscosityCoef,
                                       walker_agent__velViscosity * aimViscosityCoef,
                                       walker_agent__velFactor,
                                       phys.currentState.gunAimOffset,
                                       phys.currentState.breathOffset,
                                       walker_agent__aimVelocity)

      let dy = dir.y - nowDir.y
      dir.y = nowDir.y + dy * vertAimingCoef

      phys.producedCT |> human_control_state_set_wish_shoot_dir(dir)
      phys.producedCT |> human_control_state_set_wish_look_dir(dir)
      phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType HCT_AIM, true)
      phys.producedCT |> human_control_state_set_lean_position(0.f)

      res = EBehResult ER_RUNNING

    return res

[beh_node(name="isSquadLeaderCrawl")]
class IsSquadLeaderCrawl : BehNodeAdapter
  def override update(dt : float) : EBehResult
    var res = EBehResult ER_FAILED
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (squad_member__squad : EntityId)
      query(squad_member__squad) <| $ [es] (squad__leader : EntityId)
        query(squad__leader) <| $ [es] (human_net_phys : HumanActor)
          assume squadLeaderPhys = human_net_phys.phys
          if determinate_stance(squadLeaderPhys.currentState) == STANCE_CRAWL
            res = EBehResult ER_SUCCESS
    return res

[beh_node(name="isSquadLeaderMoving")]
class IsSquadLeaderMoving : BehNodeAdapter
  def override update(dt : float) : EBehResult
    var res = EBehResult ER_FAILED
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (squad_member__squad : EntityId)
      query(squad_member__squad) <| $ [es] (squad__leader : EntityId)
        query(squad__leader) <| $ [es] (human_net_phys : HumanActor;
                                        isDowned : bool = false)
          if isDowned
            return
          assume currentState = human_net_phys.phys.currentState
          assume moveState = currentState.moveState
          if moveState == HUMoveState EMS_WALK || moveState == HUMoveState EMS_RUN || moveState == HUMoveState EMS_SPRINT
            res = EBehResult ER_SUCCESS
    return res

[beh_node(name="wasAttackedRecently")]
class WasAttackedRecently : BehNodeAdapter
  targetEidParam : int = -1
  minElapsedTime : float = 5.

  def override loadFromBlk(var data : DataBlock) : void
    minElapsedTime = datablock_getReal(data, "minElapsedTime", 5.);
    targetEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetUnitParam", ""), 0)

  def override update(dt : float) : EBehResult
    var res = EBehResult ER_FAILED

    query(beh_tree_eid(owner)) <| $ [es] (agent_dangers__lastHitReactionTime : float;
                                          agent_dangers__lastBulletReactionTime : float)
      let curTime = get_sync_time()

      if (curTime - agent_dangers__lastHitReactionTime < minElapsedTime)
        res = EBehResult ER_SUCCESS
        return

      if (curTime - agent_dangers__lastBulletReactionTime < minElapsedTime)
        res = EBehResult ER_SUCCESS
        return

    return res

[beh_node(name="isInTrainZone")]
class IsInTrainZone : BehNodeAdapter
  def override update(dt : float) : EBehResult
    var res = EBehResult ER_FAILED

    let agentEid = beh_tree_eid(owner)

    query(agentEid) <| $ [es] (beh_tree__isAgentInTrainZone : bool)
      if beh_tree__isAgentInTrainZone
        res = EBehResult ER_SUCCESS

    return res

[beh_node(name="isLeaderOnTrain")]
class IsLeaderOnTrain : BehNodeAdapter
  squadEid : EntityId = ecs::INVALID_ENTITY_ID

  def override loadFromBlk(var data : DataBlock) : void
    query(beh_tree_eid(owner)) <| $ [es] (squad_member__squad : EntityId)
      squadEid = squad_member__squad

  def override update(dt : float) : EBehResult
    var res = EBehResult ER_FAILED

    query(squadEid) <| $ [es] (squad__leader : ecs::EntityId)
      query(squad__leader) <| $ [es] (beh_tree__isAgentOnTrain : bool)
        if beh_tree__isAgentOnTrain
          res = EBehResult ER_SUCCESS

    return res

[beh_node(name="isLeaderAlive")]
class IsLeaderAlive : BehNodeAdapter
  squadEid : EntityId = ecs::INVALID_ENTITY_ID

  def override loadFromBlk(var data : DataBlock) : void
    query(beh_tree_eid(owner)) <| $ [es] (squad_member__squad : EntityId)
      squadEid = squad_member__squad

  def override update(dt : float) : EBehResult
    var res = EBehResult ER_FAILED

    query(squadEid) <| $ [es] (squad__leader : ecs::EntityId)
      query(squad__leader) <| $ [es] (isAlive : bool)
        if isAlive
          res = EBehResult ER_SUCCESS

    return res

[beh_node(name="isOnTrain")]
class IsOnTrain : BehNodeAdapter
  def override update(dt : float) : EBehResult
    var res = EBehResult ER_FAILED

    query(beh_tree_eid(owner)) <| $ [es] (beh_tree__isAgentOnTrain : bool)
      if beh_tree__isAgentOnTrain
        res = EBehResult ER_SUCCESS

    return res

def private findNearestPointToAgent(agentPos : float3;
                                    transform : float3x4;
                                    maxDistSq : float;
                                    points : Point3List;
                                    var res : float3&) : bool
  var minDstSq = FLT_MAX
  var minDstPt = float3()

  var found = false

  for i in iter_range(points)
    let worldPos = transform * points[i]
    let dstSq = length_sq(agentPos - worldPos)

    if dstSq <= maxDistSq && dstSq <= minDstSq
      minDstPt = points[i]
      minDstSq = dstSq

      found = true

  if found
    res = minDstPt
    return true

  return false

def private findNearestPointToAgentLeader(agentPos : float3;
                                          leaderPos : float3;
                                          transform : float3x4;
                                          maxDistSq : float;
                                          points : Point3List;
                                          var res : float3&) : bool
  var minDstSq = FLT_MAX
  var minDstPt = float3()

  var found = false

  for i in iter_range(points)
    let worldPos = transform * points[i]
    let toAgentDstSq = length_sq(agentPos - worldPos)

    if toAgentDstSq <= maxDistSq
      let toLeaderDstSq = length_sq(leaderPos - worldPos)
      if toLeaderDstSq <= minDstSq
        minDstPt = points[i]
        minDstSq = toLeaderDstSq

        found = true

  if found
    res = minDstPt
    return true

  return false

[beh_node(name="findTrainExitPoint")]
class FindTrainExitPoint : BehNodeAdapter
  posParam : int = -1
  cartEidParam : int = -1

  maxDistSq : float = 144.
  nearestToLeader : bool = false

  squadEid : EntityId = INVALID_ENTITY_ID

  def override loadFromBlk(var data : DataBlock) : void
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3(0., 0., 0.))
    cartEidParam = owner.blackBoard |> get_or_create("cartEidParam", 0)

    let maxDist = datablock_getReal(data, "maxDist", 12.)

    maxDistSq = maxDist * maxDist

    nearestToLeader = datablock_getBool(data, "nearestToLeader", false)

    if nearestToLeader
      query(beh_tree_eid(owner)) <| $ [es] (squad_member__squad : EntityId)
        squadEid = squad_member__squad

  def override update(dt : float) : EBehResult
    var res = EBehResult ER_FAILED

    let agentEid = beh_tree_eid(owner)

    query(agentEid) <| $ [es] (transform : float3x4)
      let agentPos = transform[3]
      let cartEid  = EntityId(uint(owner.blackBoard |> datablock_getInt(cartEidParam)))

      query(cartEid) <| $ [es] (ai_train__exit_points : Point3List;
                                transform aka cart_transform : float3x4)
        if !nearestToLeader
          var minDstPt = float3()

          if findNearestPointToAgent(agentPos, cart_transform, maxDistSq, ai_train__exit_points, minDstPt)
            owner.blackBoard |> set(posParam, minDstPt)

            res = EBehResult ER_SUCCESS
        else
          query(squadEid) <| $ [es] (squad__leader : ecs::EntityId)
            query(squad__leader) <| $ [es] (transform aka leader_transform : float3x4)
              var minDstPt = float3()

              if findNearestPointToAgentLeader(agentPos, leader_transform[3],
                                               cart_transform, maxDistSq, ai_train__exit_points, minDstPt)
                owner.blackBoard |> set(posParam, minDstPt)

                res = EBehResult ER_SUCCESS


    return res

[beh_node(name="findTrainNavPoint")]
class FindTrainNavPoint : BehNodeAdapter
  posParam : int = -1
  cartEidParam : int = -1
  navPtIdParam : int = -1

  maxDistSq : float = 144.

  agentTeam : int = TEAM_UNASSIGNED

  def override loadFromBlk(var data : DataBlock) : void
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3(0., 0., 0.))

    cartEidParam = owner.blackBoard |> get_or_create("cartEidParam", -1)
    navPtIdParam = owner.blackBoard |> get_or_create("navPtIdParam", -1)

    let maxDist = datablock_getReal(data, "maxDist", 12.)

    maxDistSq = maxDist * maxDist

    query(beh_tree_eid(owner)) <| $ [es] (team : int)
      agentTeam = team

  def override update(dt : float) : EBehResult
    var res = EBehResult ER_FAILED

    if agentTeam == TEAM_UNASSIGNED
      return res

    query(beh_tree_eid(owner)) <| $ [es] (transform : float3x4)
      let agentPos = transform[3]
      let cartEid = EntityId(uint(owner.blackBoard |> datablock_getInt(cartEidParam)))

      query(cartEid) <| $ [es] (ai_train__nav_points : Point3List;
                                var ai_train__held_nav_points : ecs::Array&;
                                transform aka cart_transform : float3x4)
        assume agentTeamHeldNavPoints = *(getRW_ecs_BoolList(ai_train__held_nav_points[agentTeam - 1]))
        for i in iter_range(ai_train__nav_points)
          let pos = cart_transform * ai_train__nav_points[i]
          if !agentTeamHeldNavPoints[i] && length_sq(agentPos - pos) <= maxDistSq
            owner.blackBoard |> set(posParam, ai_train__nav_points[i])
            owner.blackBoard |> set(navPtIdParam, i)

            agentTeamHeldNavPoints[i]  = true

            res = EBehResult ER_SUCCESS
            return

    return res

[beh_node(name="isNavPointValid")]
class IsNavPointValid : BehNodeAdapter
  cartEidParam : int = -1
  navPtIdParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    cartEidParam = owner.blackBoard |> get_or_create("cartEidParam", -1)
    navPtIdParam = owner.blackBoard |> get_or_create("navPtIdParam", -1)

  def override update(dt : float) : EBehResult
    var res = EBehResult ER_FAILED

    if (owner.blackBoard |> datablock_getInt(cartEidParam) != -1 &&
        owner.blackBoard |> datablock_getInt(navPtIdParam) != -1)
      res = EBehResult ER_SUCCESS

    return res


[beh_node(name="isNavPointOnTheRoofValid")]
class IsNavPointOnTheRoofValid : BehNodeAdapter
  cartEidParam : int = -1
  navPtRoofIdParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    cartEidParam = owner.blackBoard |> get_or_create("cartEidParam", -1)
    navPtRoofIdParam = owner.blackBoard |> get_or_create("navPtRoofIdParam", -1)

  def override update(dt : float) : EBehResult
    var res = EBehResult ER_FAILED

    if (owner.blackBoard |> datablock_getInt(cartEidParam) != -1 &&
        owner.blackBoard |> datablock_getInt(navPtRoofIdParam) != -1)
      res = EBehResult ER_SUCCESS

    return res

[beh_node(name="resetNavPoints")]
class ResetNavPoints : BehNodeAdapter
  cartEidParam : int = -1
  navPtIdParam : int = -1

  navPtRoofIdParam : int = -1

  resetCartEid : bool = true

  agentTeam : int = TEAM_UNASSIGNED

  def override loadFromBlk(var data : DataBlock) : void
    cartEidParam = owner.blackBoard |> get_or_create("cartEidParam", -1)
    navPtIdParam = owner.blackBoard |> get_or_create("navPtIdParam", -1)
    navPtRoofIdParam = owner.blackBoard |> get_or_create("navPtRoofIdParam", -1)

    resetCartEid = datablock_getBool(data, "resetCartEid", true)

    query(beh_tree_eid(owner)) <| $ [es] (team : int)
      agentTeam = team

  def override update(dt : float) : EBehResult
    if agentTeam == TEAM_UNASSIGNED
      return EBehResult ER_FAILED

    let cartEid  = EntityId(uint(owner.blackBoard |> datablock_getInt(cartEidParam)))
    query(cartEid) <| $ [es] (var ai_train__held_nav_points : ecs::Array&)
      let navPtId = owner.blackBoard |> datablock_getInt(navPtIdParam)
      if navPtId != -1
        assume agentTeamHeldNavPoints = *(getRW_ecs_BoolList(ai_train__held_nav_points[agentTeam - 1]))
        agentTeamHeldNavPoints[navPtId] = false

    query(cartEid) <| $ [es] (var ai_train__held_roof_nav_points : BoolList&)
      let navPtRoofId = owner.blackBoard |> datablock_getInt(navPtRoofIdParam)
      if navPtRoofId != -1
        ai_train__held_roof_nav_points[navPtRoofId] = false

    if resetCartEid
      owner.blackBoard |> set(cartEidParam, -1)

    owner.blackBoard |> set(navPtIdParam, -1)
    owner.blackBoard |> set(navPtRoofIdParam, -1)

    return EBehResult ER_SUCCESS

[beh_node(name="findTrainEnterPoint")]
class FindTrainEnterPoint : BehNodeAdapter
  initPos : bool = true
  posParam : int = -1
  cartEidParam : int = -1

  maxDistSq : float = 144.

  nearestToLeader : bool = false

  squadEid : ecs::EntityId = ecs::INVALID_ENTITY_ID

  def override loadFromBlk(var data : DataBlock) : void
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3(0., 0., 0.))
    cartEidParam = owner.blackBoard |> get_or_create("cartEidParam", 0)

    initPos = datablock_getBool(data, "init", true)

    let maxDist = datablock_getReal(data, "maxDist", 12.)
    maxDistSq = maxDist * maxDist

    nearestToLeader = datablock_getBool(data, "nearestToLeader", false)

    if nearestToLeader
      query(beh_tree_eid(owner)) <| $ [es] (squad_member__squad : EntityId)
        squadEid = squad_member__squad

  def override update(dt : float) : EBehResult
    var res = EBehResult ER_FAILED

    let agentEid = beh_tree_eid(owner)

    query(agentEid) <| $ [es] (transform : float3x4)
      let agentPos = transform[3]
      if initPos
        var minDstSq = FLT_MAX
        var minDstPt = float3()
        var minCartEid = INVALID_ENTITY_ID

        var found = false

        query() <| $ [es(REQUIRE=train)] (eid : EntityId;
                                          ai_train__enter_points : Point3List;
                                          transform aka cart_transform : float3x4)
          for i in iter_range(ai_train__enter_points)
            let pos = cart_transform * ai_train__enter_points[i]
            let toAgentDstSq = length_sq(agentPos - pos)
            if toAgentDstSq <= maxDistSq && toAgentDstSq <= minDstSq
              minDstPt = ai_train__enter_points[i]
              minDstSq = toAgentDstSq
              minCartEid = eid

              found = true

        if found
          owner.blackBoard |> set(posParam, minDstPt)
          owner.blackBoard |> set(cartEidParam, int(uint(minCartEid)))

          res = EBehResult ER_SUCCESS
      else
        let cartEid  = EntityId(uint(owner.blackBoard |> datablock_getInt(cartEidParam)))
        query(cartEid) <| $ [es] (ai_train__enter_points : Point3List;
                                  transform aka cart_transform : float3x4)
          if !nearestToLeader
            var minDstPt = float3()

            if findNearestPointToAgent(agentPos, cart_transform, maxDistSq, ai_train__enter_points, minDstPt)
              owner.blackBoard |> set(posParam, minDstPt)

              res = EBehResult ER_SUCCESS
          else
            query(squadEid) <| $ [es] (squad__leader : ecs::EntityId)
              query(squad__leader) <| $ [es] (transform aka leader_transform : float3x4)
                var minDstPt = float3()

                if findNearestPointToAgentLeader(agentPos, leader_transform[3],
                                                cart_transform, maxDistSq, ai_train__enter_points, minDstPt)
                  owner.blackBoard |> set(posParam, minDstPt)

                  res = EBehResult ER_SUCCESS

    return res

[beh_node(name="updateTrainLocalPoint")]
class UpdateTrainLocalPoint : BehNodeAdapter
  localPosParam : int = -1
  worldPosParam : int = -1
  cartEidParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    localPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "localPosParam", ""), float3(0., 0., 0.))
    worldPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "worldPosParam", ""), float3(0., 0., 0.))
    cartEidParam = owner.blackBoard |> get_or_create("cartEidParam", 0)

  def override update(dt : float) : EBehResult
    var res = EBehResult ER_FAILED
    let curPos = owner.blackBoard |> datablock_getPoint3(localPosParam)

    let cartEid = EntityId(uint(owner.blackBoard |> datablock_getInt(cartEidParam)))

    query(cartEid) <| $ [es] (transform : float3x4)
      let pos = transform * curPos

      owner.blackBoard |> set(worldPosParam, pos)

      res = EBehResult ER_SUCCESS

    return res

[beh_node(name="walkerClimb")]
class WalkerClimb : BehNodeAdapter
  duration : float = 1.
  curTime : float = 0.

  def override loadFromBlk(var data : DataBlock) : void
    duration = data |> datablock_getReal("duration", duration)

  def override init()
    curTime = get_sync_time()

  def override update(dt : float) : EBehResult
    var res = EBehResult ER_FAILED

    query(beh_tree_eid(owner)) <| $ [es] (human_net_phys__isUnderwater : bool;
                                          human_net_phys__isInAir : bool;
                                          human_net_phys__isClimbing : bool;
                                          human_net_phys__isSwimming : bool;
                                          var human_net_phys : HumanActor)
      if !(human_net_phys.phys.producedCT |> is_control_bit_set(HumanPhysControlType HCT_JUMP))
        if (!human_net_phys__isUnderwater &&
            !human_net_phys__isInAir &&
            !human_net_phys__isClimbing &&
            !human_net_phys__isSwimming)
          human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType HCT_JUMP, true)

      if curTime + duration <= get_sync_time()
        human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType HCT_JUMP, false)
        res = EBehResult ER_SUCCESS
      else
        res = EBehResult ER_RUNNING

    return res

  def override exit()
    curTime = 0.
    query(beh_tree_eid(owner)) <| $ [es] (var human_net_phys : HumanActor)
      human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType HCT_JUMP, false)

[beh_node(name="moveByDir")]
class MoveByDir : BehNodeAdapter
  duration : float = 1.
  curTime : float = 0.

  endPosParam : int = -1
  lookPosParam : int = -1

  distThresholdSq : float = 0.25

  def override loadFromBlk(var data : DataBlock) : void
    duration = data |> datablock_getReal("duration", duration)

    let distThreshold = data |> datablock_getReal("distThreshold", 0.5)
    distThresholdSq = distThreshold * distThreshold

    endPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "endPos", ""), float3())

    if datablock_find_param(data, "lookPosParam") >= 0
      lookPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "lookPosParam", ""), float3())

  def override init()
    curTime = get_sync_time()

  def override update(dt : float) : EBehResult
    var res = EBehResult ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (var human_net_phys : HumanActor;
                                          transform : float3x4)
      assume phys = human_net_phys.phys

      let curPos = transform[3]
      let endPos = owner.blackBoard |> datablock_getPoint3(endPosParam)

      let deltaPos = endPos - curPos
      if length_sq(deltaPos) < distThresholdSq
        phys.producedCT |> human_control_state_set_walk_speed(0.)
        phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType HCT_SPRINT, false)
        res = EBehResult ER_SUCCESS
        return

      let dir = normalize(deltaPos)

      var lookDir = dir
      if lookPosParam >= 0
        let lookPos = owner.blackBoard |> datablock_getPoint3(lookPosParam)
        lookDir = normalize(lookPos - curPos)

      phys.producedCT |> human_control_state_set_wish_shoot_dir(normalize(float3(lookDir.x, 0., lookDir.z)))
      phys.producedCT |> human_control_state_set_wish_look_dir(normalize(float3(lookDir.x, 0., lookDir.z)))

      phys.producedCT |> human_control_state_set_world_walk_dir(dir.xz, lookDir.xz)
      phys.producedCT |> human_control_state_set_walk_speed(1.)

      phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType HCT_SPRINT, true)

      if curTime + duration <= get_sync_time()
        phys.producedCT |> human_control_state_set_walk_speed(0.)
        phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType HCT_SPRINT, false)

        res = EBehResult ER_SUCCESS
      else
        res = EBehResult ER_RUNNING

    return res

  def override exit()
    curTime = 0.
    query(beh_tree_eid(owner)) <| $ [es] (var human_net_phys : HumanActor)
      human_net_phys.phys.producedCT |> human_control_state_set_walk_speed(0.)
      human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType HCT_SPRINT, false)


[beh_node(name="findAgentCart")]
class FindAgentCart : BehNodeAdapter
  cartEidParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    cartEidParam = owner.blackBoard |> get_or_create("cartEidParam", 0)

  def override update(dt : float) : EBehResult
    var res = EBehResult ER_FAILED
    var pos = float3()

    query(beh_tree_eid(owner)) <| $ [es] (transform : float3x4)
      pos = transform[3]

    var agentCartEid = INVALID_ENTITY_ID
    query() <| $ [es(REQUIRE=train)] (eid : EntityId;
                                      train_cart__offsetXZ : float;
                                      train_cart__minHeight : float;
                                      train_cart__maxHeight : float;
                                      collres : CollisionResource;
                                      transform : float3x4)
      let localPos = inverse(transform) * pos

      var box = collres.vFullBBox

      box.bmin.y = train_cart__minHeight
      box.bmax.y = train_cart__maxHeight

      box.bmin.x -= train_cart__offsetXZ
      box.bmax.x += train_cart__offsetXZ

      box.bmin.z -= train_cart__offsetXZ
      box.bmax.z += train_cart__offsetXZ

      if BBox3(box) & localPos
        agentCartEid = eid

        res = EBehResult ER_SUCCESS

    owner.blackBoard |> set(cartEidParam, int(uint(agentCartEid)))

    return res


[beh_node(name="isAgentCartEidValid")]
class IsAgentCartEidValid : BehNodeAdapter
  cartEidParam  : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    cartEidParam = owner.blackBoard |> get_or_create("cartEidParam", 0)

  def override update(dt : float) : EBehResult
    var res = EBehResult ER_FAILED
    var pos = float3()

    query(beh_tree_eid(owner)) <| $ [es] (transform : float3x4)
      pos = transform[3]

    let cartEid = EntityId(uint(owner.blackBoard |> datablock_getInt(cartEidParam)))
    query(cartEid) <| $ [es] (train_cart__minHeight : float;
                              train_cart__maxHeight : float;
                              train_cart__offsetXZ : float;
                              collres : CollisionResource;
                              transform : float3x4)
      let localPos = inverse(transform) * pos

      var box = collres.vFullBBox

      box.bmin.y = train_cart__minHeight
      box.bmax.y = train_cart__maxHeight

      box.bmin.x -= train_cart__offsetXZ
      box.bmax.x += train_cart__offsetXZ

      box.bmin.z -= train_cart__offsetXZ
      box.bmax.z += train_cart__offsetXZ

      if BBox3(box) & localPos
        res = EBehResult ER_SUCCESS

    return res

[beh_node(name="chooseRandomStance")]
class ChooseRandomStance : BehNodeAdapter
  stanceParam : int = -1

  minStance : int = STANCE_CRAWL
  maxStance : int = STANCE_STAND

  def override loadFromBlk(var data : DataBlock) : void
    stanceParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "stanceParam", ""), 0)
    minStance = datablock_getInt(data, "minStance", STANCE_CRAWL)
    maxStance = datablock_getInt(data, "maxStance", STANCE_STAND)

  def override update(dt : float) : EBehResult
    owner.blackBoard |> set(stanceParam, rnd_int(minStance, maxStance))
    return EBehResult ER_SUCCESS

[beh_node(name="isOnTheTrainRoof")]
class IsOnTheTrainRoof : BehNodeAdapter
  cartEidParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    cartEidParam = owner.blackBoard |> get_or_create("cartEidParam", 0)

  def override update(dt : float) : EBehResult
    var res = EBehResult ER_FAILED
    var pos = float3()

    query(beh_tree_eid(owner)) <| $ [es] (transform : float3x4)
      pos = transform[3]

    let cartEid = EntityId(uint(owner.blackBoard |> datablock_getInt(cartEidParam)))
    query(cartEid) <| $ [es] (train_cart__offsetXZ : float;
                              train_cart__roofHeight : float;
                              train_cart__maxHeight : float;
                              collres : CollisionResource;
                              transform : float3x4)
      let localPos = inverse(transform) * pos

      var box = collres.vFullBBox

      box.bmin.y = train_cart__roofHeight
      box.bmax.y = train_cart__maxHeight

      box.bmin.x -= train_cart__offsetXZ
      box.bmax.x += train_cart__offsetXZ

      box.bmin.z -= train_cart__offsetXZ
      box.bmax.z += train_cart__offsetXZ

      if BBox3(box) & localPos
        res = EBehResult ER_SUCCESS

    return res

[beh_node(name="findTrainNavPointOnTheRoof")]
class FindTrainNavPointOnTheRoof : BehNodeAdapter
  posParam     : int = -1
  cartEidParam : int = -1
  navPtRoofIdParam : int = -1

  maxDistSq : float = 144.

  def override loadFromBlk(var data : DataBlock) : void
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3(0., 0., 0.))

    cartEidParam = owner.blackBoard |> get_or_create("cartEidParam", -1)
    navPtRoofIdParam = owner.blackBoard |> get_or_create("navPtRoofIdParam", -1)

    let maxDist = datablock_getReal(data, "maxDist", 12.)

    maxDistSq = maxDist * maxDist

  def override update(dt : float) : EBehResult
    var res = EBehResult ER_FAILED

    let agentEid = beh_tree_eid(owner)

    query(agentEid) <| $ [es] (transform : float3x4)
      let agentPos = transform[3]
      let cartEid = EntityId(uint(owner.blackBoard |> datablock_getInt(cartEidParam)))

      query(cartEid) <| $ [es] (ai_train__roof_nav_points : Point3List;
                                var ai_train__held_roof_nav_points : BoolList&;
                                transform : float3x4)
        for i in iter_range(ai_train__roof_nav_points)
          let pos = transform * ai_train__roof_nav_points[i]
          if !ai_train__held_roof_nav_points[i] && length_sq(agentPos - pos) <= maxDistSq
            owner.blackBoard |> set(posParam, ai_train__roof_nav_points[i])
            owner.blackBoard |> set(navPtRoofIdParam, i)

            ai_train__held_roof_nav_points[i]  = true

            res = EBehResult ER_SUCCESS
            return

    return res

[beh_node(name="findTrainDangerPoint")]
class FindTrainDangerPoint : BehNodeAdapter
  posParam : int = -1
  cartEidParam : int = -1
  navPtRoofIdParam : int = -1

  maxDistSq : float = 144.

  def override loadFromBlk(var data : DataBlock) : void
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3(0., 0., 0.))

    cartEidParam = owner.blackBoard |> get_or_create("cartEidParam", -1)
    navPtRoofIdParam = owner.blackBoard |> get_or_create("navPtRoofIdParam", -1)

    let maxDist = datablock_getReal(data, "maxDist", 12.)

    maxDistSq = maxDist * maxDist

  def override update(dt : float) : EBehResult
    var res = EBehResult ER_FAILED

    let agentEid = beh_tree_eid(owner)

    query(agentEid) <| $ [es] (transform : float3x4)
      let agentPos = transform[3]
      let cartEid  = EntityId(uint(owner.blackBoard |> datablock_getInt(cartEidParam)))

      query(cartEid) <| $ [es] (ai_train__danger_points : Point3List;
                                transform aka cart_transform : float3x4)
        var minDstPt = float3()

        if findNearestPointToAgent(agentPos, cart_transform, maxDistSq, ai_train__danger_points, minDstPt)
          owner.blackBoard |> set(posParam, minDstPt)

          res = EBehResult ER_SUCCESS

    return res

[beh_node(name="checkDistanceToLeader")]
class CheckDistanceToLeader : BehNodeAdapter
  maxDistSq : float = 144.

  squadEid : EntityId = INVALID_ENTITY_ID

  def override loadFromBlk(var data : DataBlock) : void
    let maxDist = datablock_getReal(data, "maxDist", 12.)

    maxDistSq = maxDist * maxDist

    query(beh_tree_eid(owner)) <| $ [es] (squad_member__squad : EntityId)
      squadEid = squad_member__squad

  def override update(dt : float) : EBehResult
    var res = EBehResult ER_FAILED

    var agentPos = float3()
    query(beh_tree_eid(owner)) <| $ [es] (transform : float3x4)
      agentPos = transform[3]

    query(squadEid) <| $ [es] (squad__leader : ecs::EntityId)
      query(squad__leader) <| $ [es] (transform : float3x4)
        if (length_sq(transform[3] - agentPos) < maxDistSq)
          res = EBehResult ER_SUCCESS

    return res

[beh_node(name="calcDistance")]
class CalcDistance : BehNodeAdapter
  endPosParam   : int = -1
  startPosParam : int = -1
  distanceParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    endPosParam   = owner.blackBoard |> get_or_create(datablock_getStr(data, "endPosParam", ""), float3(0., 0., 0.))
    startPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "startPosParam", ""), float3(0., 0., 0.))

    distanceParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "distanceParam", ""), 0.)

  def override update(dt : float) : EBehResult
    let distance = distance(owner.blackBoard |> datablock_getPoint3(startPosParam),
      owner.blackBoard |> datablock_getPoint3(endPosParam))

    owner.blackBoard |> set(distanceParam, distance)

    return EBehResult ER_SUCCESS

[beh_node(name="giveAmmo")]
class GiveAmmo : BehNodeAdapter
  varId : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    varId = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetUnitParam", ""), 0.)

  def override update(dt : float) : EBehResult
    let targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(varId)))
    owner.blackBoard |> set(varId, 0)

    let agentEid = beh_tree_eid(owner)

    query(targetEid) <| $ [es] (transform aka target_transform : float3x4;
                                human_use_object__thresholdDist : float = 12.f)
      query(agentEid) <| $ [es] (transform aka agent_transform : float3x4)
        if length_sq(target_transform[3] - agent_transform[3]) > square(human_use_object__thresholdDist)
          return

        let pathSlop = 0.25
        let distToPath = 1.
        let extents = float3(distToPath, FLT_MAX, distToPath)

        if find_path(target_transform[3], agent_transform[3], extents, distToPath, pathSlop) != FindPathResult FPR_FULL
          return

        if is_server()
          sendEvent(agentEid, [[CmdUse requesterEid=targetEid]])
        else
          sendEvent(targetEid, [[HumanUseObjectRequest objectEid=agentEid]])

    return EBehResult ER_SUCCESS

[beh_node(name="getPointInTrainCapzone")]
class GetPointInTrainCapzone : BehNodeAdapter
  posParam   : int = -1

  maxDiffDistSq : float = 25.

  squadEid : EntityId = INVALID_ENTITY_ID

  def override loadFromBlk(var data : DataBlock) : void
    posParam   = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3(0., 0., 0.))

    let maxDiffDist = datablock_getReal(data, "maxDiffDist", 5.)

    maxDiffDistSq = maxDiffDist * maxDiffDist

    squadEid = get_Eid(beh_tree_eid(owner), "squad_member__squad") ?? INVALID_ENTITY_ID

  def override update(dt : float) : EBehResult
    var res = EBehResult ER_FAILED

    query(squadEid) <| $ [es] (squad__leader : EntityId)
      if squad__leader != beh_tree_eid(owner)
        return

      query() <| $ [es(REQUIRE=trainZone)] (capzone__hasNearestNavmeshPos : bool;
                                            capzone__nearestNavmeshPos : float3)
        if capzone__hasNearestNavmeshPos && maxDiffDistSq <= distance_sq(owner.blackBoard |> datablock_getPoint3(posParam), capzone__nearestNavmeshPos)
          owner.blackBoard |> set(posParam, capzone__nearestNavmeshPos)

          res = EBehResult ER_SUCCESS

    return res

[beh_node(name="resetShoulUseVehicleTrigger")]
class ResetShoulUseVehicleTrigger : BehNodeAdapter
  def override update(dt : float) : EBehResult

    query(beh_tree_eid(owner)) <| $ [es] (var beh_tree__shouldUseVehicleResetTrigger : bool&)
      beh_tree__shouldUseVehicleResetTrigger = false

    return EBehResult ER_SUCCESS

[beh_node(name="resetIsInVehicleTrigger")]
class ResetIsInVehicleTrigger : BehNodeAdapter
  def override update(dt : float) : EBehResult
    query(beh_tree_eid(owner)) <| $ [es] (var beh_tree__isInVehicleResetTrigger : bool&)
      beh_tree__isInVehicleResetTrigger = false

    return EBehResult ER_SUCCESS

[beh_node(name="resetUseBombTrigger")]
class ResetUseBombTrigger : BehNodeAdapter
  def override update(dt : float) : EBehResult
    query(beh_tree_eid(owner)) <| $ [es] (var beh_tree__useBombResetTrigger : bool&)
      beh_tree__useBombResetTrigger = false

    return EBehResult ER_SUCCESS


[beh_node(name="getAgentAIPos")]
class GetAgentAIPos : BehNodeAdapter
  outPosParam : int = -1

  def override loadFromBlk(data : DataBlock) : void
    outPosParam  = owner.blackBoard |> get_or_create(datablock_getStr(data, "outPosParam", ""), float3(0.0))

  def override update(dt : float) : EBehResult
    let agent = beh_tree_entity_agent(*owner)
    if outPosParam >= 0
      owner.blackBoard |> set(outPosParam, agent.pos)
    return EBehResult ER_SUCCESS

// 105, -105, -120, 120, 90, -90 degrees table
let GetPointAroundAIPos_cosMxSide = [[float[6]- 0.2588190451; -0.2588190451; -0.50000000000; -0.50000000000;  0.;  0.]]
let GetPointAroundAIPos_sinMxSide = [[float[6] + 0.9659258262; -0.9659258262; -0.86602540378; +0.86602540378;  1.; -1.]]
let GetPointAroundAIPos_cosMxForw = [[float[6] + 0.9659258262; +0.9659258262; +0.86602540378; +0.86602540378;  1.;  1.]]
let GetPointAroundAIPos_sinMxForw = [[float[6] + 0.2588190451; -0.2588190451; -0.50000000000; +0.50000000000;  0.;  0.]]

[beh_node(name="getPointAroundAIPos")]
class GetPointAroundAIPos : BehNodeAdapter
  dirParam     : int = -1
  outPosParam  : int = -1
  forwPosParam : int = -1
  resetParam   : int = -1
  fromPosParam : int = -1
  toPosParam   : int = -1

  counter    : int = 0
  radius     : float = 1.5

  initPos  : float3
  initDir  : float3
  stepDist : float
  sideCoef : float

  def override loadFromBlk(data : DataBlock) : void
    dirParam     = owner.blackBoard |> get_or_create(datablock_getStr(data, "dirParam", ""), float3(0.0))
    outPosParam  = owner.blackBoard |> get_or_create(datablock_getStr(data, "outPosParam", ""), float3(0.0))
    forwPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "forwPosParam", ""), float3(0.0))
    resetParam   = owner.blackBoard |> get_or_create(datablock_getStr(data, "resetAIPointsGeneratorParam", ""), 0)
    fromPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "fromPosParam", ""), float3(0.0))
    toPosParam   = owner.blackBoard |> get_or_create(datablock_getStr(data, "toPosParam", ""), float3(0.0))
    radius       = datablock_getReal(data, "radius", 1.5)

  def override init()
    if counter == 0 || owner.blackBoard |> datablock_getInt(resetParam) != 0
      owner.blackBoard |> set(resetParam, 0)
      let agent = beh_tree_entity_agent(*owner)
      initDir = normalize(x0z(owner.blackBoard |> datablock_getPoint3(dirParam)))
      initPos = agent.pos
      counter = 0

      let fromPos = owner.blackBoard |> datablock_getPoint3(fromPosParam)
      let wishPos = owner.blackBoard |> datablock_getPoint3(toPosParam)

      let dist = length(wishPos - initPos)
      stepDist = min(dist, radius)

      let dir = normalize(wishPos - fromPos)
      let norm = float2(dir.z, -dir.x)
      let offs = dot(norm, initPos.xz) - dot(norm, fromPos.xz)
      sideCoef = offs < 0.0 ? 1.0 : -1.0

  def override update(dt : float) : EBehResult
    if length_sq(initDir) < 1e-3
      counter = 0
      return EBehResult ER_FAILED

    let count = length(GetPointAroundAIPos_cosMxSide)
    if counter >= count
      counter = 0
      return EBehResult ER_FAILED

    let id = counter

    let ndx = initDir.x * GetPointAroundAIPos_cosMxSide[id] - initDir.z * GetPointAroundAIPos_sinMxSide[id] * sideCoef
    let ndz = initDir.x * GetPointAroundAIPos_sinMxSide[id] * sideCoef + initDir.z * GetPointAroundAIPos_cosMxSide[id]
    let newPos = initPos + float3(ndx, 0.0, ndz) * stepDist
    if outPosParam >= 0
      owner.blackBoard |> set(outPosParam, newPos)

    if forwPosParam >= 0
      let fdx = initDir.x * GetPointAroundAIPos_cosMxForw[id] - initDir.z * GetPointAroundAIPos_sinMxForw[id] * sideCoef
      let fdz = initDir.x * GetPointAroundAIPos_sinMxForw[id] * sideCoef + initDir.z * GetPointAroundAIPos_cosMxForw[id]
      let forwPos = newPos + float3(fdx, 0.0, fdz) * stepDist
      owner.blackBoard |> set(forwPosParam, forwPos)

    ++counter
    return EBehResult ER_SUCCESS


[beh_node(name="findCoverAroundPoint")]
class FindCoverAroundPoint : BehNodeAdapter
  centerParam   : int = -1
  coverPosParam : int = -1
  maxDistParam  : int = -1

  radius     : float = 5.0
  minDist    : float = 0.0

  possibleCosAngle   : float = 0.5
  possibleAngleParam : int = -1

  keepOldCoverChance : float = 0.9

  maxOccupied  : int = -1
  traceVisible : bool = false

  avoidLeaderActing : LeaderActingInfo

  def override loadFromBlk(var data : DataBlock) : void
    radius = datablock_getReal(data, "radius", 5.)
    minDist = datablock_getReal(data, "minDist", 0.0)

    let possibleAngle = datablock_getReal(data, "possibleAngle", 90.)
    possibleCosAngle  = cos(deg_to_rad(possibleAngle))
    if datablock_find_param(data, "possibleAngleParam") >= 0
      possibleAngleParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "possibleAngleParam", ""), 90.)

    let agent = beh_tree_entity_agent(*owner)
    centerParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "centerParam", ""), agent.pos)
    coverPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "coverPosParam", ""), agent.pos)
    let maxDistParamName = datablock_getStr(data, "radiusParam", "")
    if maxDistParamName != ""
      maxDistParam = owner.blackBoard |> get_or_create(maxDistParamName, radius)

    keepOldCoverChance = datablock_getReal(data, "keepOldCoverChance", 0.6)

    maxOccupied = datablock_getInt(data, "maxOccupied", maxOccupied)
    traceVisible = datablock_getBool(data, "traceVisible", traceVisible)

  def override init()
    if possibleAngleParam >= 0
      possibleCosAngle = cos(deg_to_rad(datablock_getReal(owner.blackBoard, possibleAngleParam)))

    let agentEid = beh_tree_eid(owner)
    avoidLeaderActing = get_squad_leader_acting_for_agent(agentEid)

  def override update(dt : float) : EBehResult
    var res = EBehResult ER_FAILED
    let visibleMap = get_global_visible_covers_map()

    let agentEid = beh_tree_eid(owner)
    query() <| $ [es] (var covers : CoversComponent&)
      query(agentEid) <| $ [es] (walker_agent : EntityAgent;
                                 team : int = TEAM_UNASSIGNED;
                                 squad_member__squad : EntityId = INVALID_ENTITY_ID;
                                 var cover_updater__heldCovers : ecs::IPoint2List&)
        var prevCoverId = int2(-1, 0)
        if length(cover_updater__heldCovers) > 0
          prevCoverId = cover_updater__heldCovers[0]

        var allowTight = false
        query(squad_member__squad) <| $ [es] (squad__formationSpread : int)
          if squad__formationSpread == int(SquadFormationSpread ESFN_CLOSEST)
            allowTight = true

        reset_covers(covers, cover_updater__heldCovers)

        let centerPos = owner.blackBoard |> datablock_getPoint3(centerParam)

        let maxDist = maxDistParam >= 0 ? (owner.blackBoard |> datablock_getReal(maxDistParam)) : radius
        let maxDistSq = square(maxDist)
        let minDistSq = square(minDist)

        var box : bbox3f
        box.bmax.xyz = centerPos + float3(maxDist, 2.5f, maxDist)
        box.bmin.xyz = centerPos - float3(maxDist, 0.5f, maxDist)

        let midPos = walker_agent.pos * 0.3 + centerPos * 0.7
        let likelyKeepCover = rnd_float(0.0, 1.0) < keepOldCoverChance

        let traceStartPos = centerPos + float3(0.0, 1.0, 0.0)
        let traceHeightUp = float3(0.0, 0.5, 0.0)

        var bestDistSq = FLT_MAX
        var bestCoverId = int2(-1, 0)
        var bestScore = 0
        var bestTight = true
        var bestOKDir = false
        var bestFound = false

        var dangerPoints : array<float3>
        get_danger_points(dangerPoints, agentEid, walker_agent.pos, team)

        let filterInfo = get_filter_covers_info()
        covers_box_cull(covers, box) <| $ [unused_argument(tm)] (id : int;
                                                                 tm : mat44f#)
          if bestFound
            return
          if tm.col3.xyz == float3() // was destroyed
            return
          if team != TEAM_UNASSIGNED && glob_vis_covers_map_has_other_teams(visibleMap, id, team)
            return

          assume cover     = covers.list[id]
          assume coverDesc = covers.coverDescs[id]
          if filter_cover(cover, coverDesc, box, maxOccupied, filterInfo)
            return

          let numSlots = length(coverDesc.slots)
          let isPrevCover = prevCoverId.x == id && likelyKeepCover

          var slotBestCoverId = int2(id, -1)
          var slotBestDistSq = bestDistSq
          var slotBestScore = bestScore
          var slotBestTight = bestTight
          var slotBestOKDir = bestOKDir
          for i in range(0, numSlots)
            if coverDesc.slots[i].numUsed > 0
              continue
            let isPrevCoverSlot = isPrevCover && i == prevCoverId.y
            let coverSlotPosBase = get_cover_slot_pos(cover, coverDesc, i)
            if is_conflict_with_squad_leader_acting(avoidLeaderActing, coverSlotPosBase, agentEid)
              continue
            let isTight = !allowTight && check_covers_nearby_occupied(coverSlotPosBase, id, i, covers.list, covers.coverDescs)
            let goodDir = check_cover_pos_vs_points(coverSlotPosBase, cover.dir, dangerPoints)
            if isTight && !slotBestTight && !isPrevCoverSlot
              continue
            let isBetterByDir = goodDir && !slotBestOKDir
            let isBetterByTight = !isTight && slotBestTight
            let isBetter = isPrevCoverSlot || isBetterByTight || isBetterByDir
            let extraScore = (isPrevCoverSlot ? 50 : 0) + (isTight ? 0 : 50) + (goodDir ? 101 : 0)
            let score = eval_cover_score_stay(cover, coverDesc, i) * 100 + extraScore
            if score < slotBestScore && !isBetter
              continue
            let coverSlotPos = coverSlotPosBase + traceHeightUp
            let coverSlotOfs = coverSlotPos - traceStartPos
            let cosAngle = dot(cover.dir, normalize(float3(coverSlotOfs.x, 0.0, coverSlotOfs.z)))
            if cosAngle < possibleCosAngle
              continue
            let distToCenterSq = length_sq(coverSlotOfs)
            let distFromAgentSq = distance_sq(midPos, coverSlotPos)
            if distToCenterSq < minDistSq || distToCenterSq > maxDistSq
              continue
            if distFromAgentSq > slotBestDistSq && score == slotBestScore && !isBetter
              continue
            if !is_point_safe(coverSlotPos, team)
              continue
            if traceVisible && !isPrevCoverSlot
              let dir = normalize(coverSlotOfs)
              var t1 = length(coverSlotOfs)
              var t2 = t1
              var norm : float3
              if (traceray_normalized(traceStartPos, dir, t1, norm, ETF_ALL)
               && traceray_normalized(traceStartPos + traceHeightUp, dir, t2, norm, ETF_ALL))
                continue
            slotBestDistSq = distFromAgentSq
            slotBestCoverId = int2(id, i)
            slotBestScore = score
            slotBestTight = isTight
            slotBestOKDir = goodDir
            if isPrevCoverSlot && !isTight
              bestDistSq = slotBestDistSq
              bestCoverId = slotBestCoverId
              bestScore = slotBestScore
              bestTight = slotBestTight
              bestOKDir = slotBestOKDir
              bestFound = true
              return
          if slotBestCoverId.y != -1
            assume cover2     = covers.list[slotBestCoverId.x]
            assume coverDesc2 = covers.coverDescs[slotBestCoverId.x]
            let coverAIPos = get_cover_slot_pos(cover2, coverDesc2, slotBestCoverId.y)
            if check_cover_pos_valid(coverAIPos)
              bestDistSq = slotBestDistSq
              bestCoverId = slotBestCoverId
              bestScore = slotBestScore
              bestTight = slotBestTight
              bestOKDir = slotBestOKDir

        if bestCoverId.x != -1
          assume cover     = covers.list[bestCoverId.x]
          assume coverDesc = covers.coverDescs[bestCoverId.x]

          push(cover_updater__heldCovers, bestCoverId)
          coverDesc.slots[bestCoverId.y].numUsed += 1
          if coverDesc.slots[bestCoverId.y].numUsed == 1
            coverDesc.numUsedSlots += 1

          let coverAIPos = get_cover_slot_pos(cover, coverDesc, bestCoverId.y)
          owner.blackBoard |> set(coverPosParam, coverAIPos)
          res = EBehResult ER_SUCCESS
    return res

[beh_node(name="onceUntilReset")]
class OnceUntilResetNode : BehNodeAdapter
  isDone : bool = false

  def override reset() : void
    isDone = false

  def override update(dt : float) : EBehResult
    if isDone
      return EBehResult ER_FAILED
    isDone = true
    return EBehResult ER_SUCCESS

[beh_node(name="findDangerousBomb")]
class FindDangerousBomb : BehNodeAdapter
  bombDangerousRadius : float = 15.
  bombDangerousTime : float = 3.
  dangerPosParam : int = -1
  radiusSquare : float = 0.

  def override loadFromBlk(var data : DataBlock) : void
    dangerPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "dangerPosParam", ""), float3())
    bombDangerousRadius = data |> datablock_getReal("bombDangerousRadius", bombDangerousRadius)
    bombDangerousTime = data |> datablock_getReal("bombDangerousTime", bombDangerousTime)
    radiusSquare = square(bombDangerousRadius)

  def override update(dt : float) : EBehResult
    let ownerEid = beh_tree_eid(owner)
    let botTransform = get_TMatrix(ownerEid, "transform")
    let botPos = (*botTransform)[3]

    let found = find_query() <| $ [es] (bomb_site__timeToExplosionLeft : float;
                                        transform : float3x4)
      let bombPos = transform[3]
      if bomb_site__timeToExplosionLeft > 0. && bomb_site__timeToExplosionLeft < bombDangerousTime && distance_sq(bombPos, botPos) < radiusSquare
        owner.blackBoard |> set(dangerPosParam, bombPos)
        return true
      return false
    if found
      return EBehResult ER_SUCCESS
    return EBehResult ER_FAILED

[beh_node(name="findSafeFromBombPos")]
class FindSafeFromBombPos : BehNodeAdapter
  bombDangerousRadius : float = 15.
  dangerPosParam : int = -1
  safePosParam : int = -1
  radiusSquare : float = 0.

  def override loadFromBlk(var data : DataBlock) : void
    dangerPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "dangerPosParam", ""), float3())
    safePosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "safePosParam", ""), float3())
    bombDangerousRadius = data |> datablock_getReal("bombDangerousRadius", bombDangerousRadius)
    radiusSquare = square(bombDangerousRadius)

  def override update(dt : float) : EBehResult
    let agent = beh_tree_entity_agent(*owner)
    let bombPos = owner.blackBoard |> datablock_getPoint3(dangerPosParam)
    let oldSafePos = owner.blackBoard |> datablock_getPoint3(safePosParam)
    if distance_sq(oldSafePos, bombPos) > square(bombDangerousRadius)
      return EBehResult ER_SUCCESS

    let dir = normalize(agent.pos - bombPos)
    let dirAngle = safe_asin(dir.y)
    let angles = [[auto 0.; -PI / 8.; PI / 8.; -PI / 4.; PI / 4.]]
    var newSafePos : float3
    var found = false

    for angle in angles
      let newDirAngle = dirAngle + angle
      newSafePos = bombPos + float3(sin(newDirAngle), 0.f, cos(newDirAngle)) * bombDangerousRadius * 1.2
      project_to_nearest_navmesh_point(newSafePos, 0.5)
      let extents = float3(0.5, FLT_MAX, 0.5)
      find_path(agent.pos, newSafePos, extents, 1.f, 0.25f) <| $(path)
        for pathPos in path
          if distance_sq(pathPos, bombPos) < square(bombDangerousRadius)
            continue
          newSafePos = pathPos
          found = true
          break
      if found
        owner.blackBoard |> set(safePosParam, newSafePos)
        return EBehResult ER_SUCCESS
    return EBehResult ER_FAILED

[beh_node(name="findWayBackToNavmesh")]
class FindWayBackToNavmesh : BehNodeAdapter
  radius = 3.0
  heightHalfOffset = 1.0
  traceHeight = 1.0
  outPosParam : int = -1
  angleStep : float = 30.0
  currentPolyIndex : int = 0
  currentTraceIndex : int = 0
  traceDist : float

  def override loadFromBlk(data : DataBlock) : void
    outPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outPosParam", ""), float3(0.0))
    angleStep = data |> datablock_getReal("angleStep", angleStep)

  def override init()
    currentPolyIndex = -1
    currentTraceIndex = 0
    query(beh_tree_eid(owner)) <| $ [es] (transform : float3x4;
                                          var walker_agent__getBackToNavmeshPolys : UInt64List&;
                                          var walker_agent__getBackToNavmeshTraces : Point3List&)
      walker_agent__getBackToNavmeshPolys |> clear()
      walker_agent__getBackToNavmeshTraces |> clear()
      find_polys_in_circle(transform[3], radius, heightHalfOffset) <| $(polyRefs)
        for polyRef in polyRefs
          walker_agent__getBackToNavmeshPolys |> push(polyRef)
      shuffle(walker_agent__getBackToNavmeshPolys)

  def override exit()
    query(beh_tree_eid(owner)) <| $ [es] (var walker_agent__getBackToNavmeshPolys : UInt64List&;
                                          var walker_agent__getBackToNavmeshTraces : Point3List&)
      walker_agent__getBackToNavmeshPolys |> clear()
      walker_agent__getBackToNavmeshTraces |> clear()

  def collect_traces_for_poly(agent_pos : float3; poly_ref : uint64; var res : Point3List&; var dist : float&)
    var triangle : NavMeshTriangle
    if get_triangle_by_poly(dtPolyRef(poly_ref), triangle)
      var minAzimuth = TWOPI
      var maxAzimuth = -TWOPI
      var maxDistSq = 0.0
      for vertex in [[float3[3] triangle.p0; triangle.p1; triangle.p2]]
        let azimuth = dir_to_angles(vertex - agent_pos).x
        minAzimuth = min(minAzimuth, azimuth)
        maxAzimuth = max(maxAzimuth, azimuth)
        maxDistSq = max(maxDistSq, distance_sq(agent_pos, vertex))
      dist = sqrt(maxDistSq)
      if maxAzimuth - minAzimuth > PI
        let shiftedMax = minAzimuth + TWOPI
        minAzimuth = maxAzimuth
        maxAzimuth = shiftedMax
      let halfArc = (maxAzimuth - minAzimuth) * 0.5
      let arcCenterAngle = minAzimuth + halfArc
      res |> push(angles_to_dir(float2(arcCenterAngle, 0.0)))
      res |> push(angles_to_dir(float2(minAzimuth, 0.0)))
      res |> push(angles_to_dir(float2(maxAzimuth, 0.0)))
      for i in range(halfArc / angleStep)
        res |> push(angles_to_dir(float2(arcCenterAngle + angleStep * float(i + 1), 0.0)))
        res |> push(angles_to_dir(float2(arcCenterAngle - angleStep * float(i + 1), 0.0)))

  def override update(dt : float) : EBehResult
    var agent = beh_tree_entity_agent(*owner)
    var res = EBehResult ER_FAILED
    query(agent.eid) <| $ [es] (walker_agent__getBackToNavmeshPolys : UInt64List;
                                var walker_agent__getBackToNavmeshTraces : Point3List&)
      if currentPolyIndex >= length(walker_agent__getBackToNavmeshPolys)
        return

      if currentTraceIndex >= length(walker_agent__getBackToNavmeshTraces)
        walker_agent__getBackToNavmeshTraces |> clear()
        currentTraceIndex = 0

        ++currentPolyIndex
        if currentPolyIndex < length(walker_agent__getBackToNavmeshPolys)
          let polyRef = walker_agent__getBackToNavmeshPolys[currentPolyIndex]
          collect_traces_for_poly(agent.pos, polyRef, walker_agent__getBackToNavmeshTraces, traceDist)
          shuffle(walker_agent__getBackToNavmeshTraces)
        res = EBehResult ER_RUNNING
        return

      let traceStart = agent.pos + float3(0., traceHeight, 0.)
      let traceDir = walker_agent__getBackToNavmeshTraces[currentTraceIndex]
      ++currentTraceIndex
      if !rayhit_normalized(traceStart, traceDir, traceDist, ETF_DEFAULT, -1)
        owner.blackBoard |> set(outPosParam, agent.pos + traceDir * traceDist)
        res = EBehResult ER_SUCCESS
        return
      res = EBehResult ER_RUNNING

    return res

[beh_node(name="isOnNavmesh")]
class IsOnNavmesh : BehNodeAdapter

  def override update(dt : float) : EBehResult
    let agent = beh_tree_entity_agent(*owner)
    let extents = 0.1
    var pos = agent.pos
    if project_to_nearest_navmesh_point(pos, extents) && abs(pos.y - agent.pos.y) < 0.5
      return EBehResult ER_SUCCESS
    return EBehResult ER_FAILED
