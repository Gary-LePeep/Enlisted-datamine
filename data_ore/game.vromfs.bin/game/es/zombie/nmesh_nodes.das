options always_export_initializer = true

require app
require ecs
require DagorSystem
require BehNodes
require DagorDataBlock
require pathfinder
require game.es.zombie.moving_zone_common
require common_shooter.es.ai.attract_point_common
require math.base
require DagorMath
require DagorRandom
require debug.logerr_once
require strings
require danetlibs.pathfinder.main.pathfinder_common
require level
require DngWalkerai
require game.events_game
require danetlibs.navmesh_phys.main.nphys_common

[beh_node(name="setBlind")]
class SetBlind : BehNodeAdapter
  blindnessTimeEndParam : int = -1
  duration : float2 = float2(1f)

  def override loadFromBlk(var data : DataBlock) : void
    blindnessTimeEndParam = owner.blackBoard |> get_or_create("blindness.timeEnd", 0f)
    duration = data |> datablock_getPoint2("duration", duration)

  def override update(dt : float) : EBehResult
    owner.blackBoard |> set(blindnessTimeEndParam, get_sync_time() + rnd_float(duration.x, duration.y))
    return EBehResult ER_SUCCESS


[beh_node(name="nMeshfindInsideZonePos")]
class NMeshfindInsideZonePos : BehNodeAdapter
  posParam : string
  posParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("posParam", posParam, posParamHash, thisNode)

  def override update(dt : float) : EBehResult
    var res = EBehResult ER_FAILED
    let eid = beh_tree_eid(owner)
    var resPos : float3
    let zone = get_moving_zone(get_moving_zone_generation())
    if find_random_point_around_circle(zone.pos, zone.radius, resPos)
      res = EBehResult ER_SUCCESS
      if !eid |> has(posParam, posParamHash)
        logerr_once("{eid}: entity without output param '{posParam}:{posParamHash}' / {*thisNode |> beh_node_hierarchy_name(true)}")
      setOptional(eid, posParam, posParamHash, resPos)
    return res

[beh_node(name="nFindAttractPosition")]
class NFindAttractPosition : BehNodeAdapter
  radius : float = 30f
  navRadius : float = 3f
  reusePrevPosDistSq : float = 4f
  posParam : string
  posParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("posParam", posParam, posParamHash, thisNode)
    radius = data |> datablock_getReal("radius", radius)
    navRadius = data |> datablock_getReal("navRadius", navRadius)

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    var result = EBehResult ER_FAILED
    query(eid) <| $ [es] (transform : float3x4; var attract_position__eid : EntityId&)
      let res = get_nearest_attract_point(transform[3], 0ul, radius, attract_position__eid, reusePrevPosDistSq, false)
      if res is pos
        if !eid |> has(posParam, posParamHash)
          logerr_once("{eid}: entity without output param '{posParam}:{posParamHash}' / {*thisNode |> beh_node_hierarchy_name(true)}")
        else
          attract_position__eid = (res as pos).eid
          var resPos = (res as pos).targetPos
          project_to_nearest_navmesh_point(resPos, navRadius)
          setOptional(eid, posParam, posParamHash, resPos)
          result = EBehResult ER_SUCCESS
    return result


[beh_node(name="nMeshFindPointInRegion")]
class NMeshFindPointInRegion : BehNodeAdapter
  posParam : string
  [[hidden]] posParamHash : uint
  regionParam : int = -1
  tries : int = 2
  radius : float = 2f

  def override loadFromBlk(var data : DataBlock) : void
    tries = data |> datablock_getInt("tries", tries)
    radius = data |> datablock_getReal("radius", radius)
    regionParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "regionParam", ""), "")
    data |> load_ecs_param("posParam", posParam, posParamHash, thisNode)

  def override update(dt : float) : EBehResult
    var agentPos : float3
    let eid = beh_tree_eid(owner)
    let hasPos = query(eid) <| $ [es] (transform : float3x4)
      agentPos = transform[3]
    if !hasPos
      return EBehResult ER_FAILED

    var res = EBehResult ER_FAILED
    find_query() <| $ [es] (level_regions : LevelRegions)
      let regionName = owner.blackBoard |> datablock_getStr(regionParam)
      for region in level_regions
        if region.name == regionName
          let foundPos = find_nav_point_around(agentPos, region.randomPoint, radius, tries) <| $(pos)
            return region |> spline_region_checkPoint(pos.xz)

          if foundPos is pos
            res = EBehResult ER_SUCCESS
            if !has(eid, posParam, posParamHash)
              logerr_once("{eid}: entity without output param '{posParam}:{posParamHash}' / {*thisNode |> beh_node_hierarchy_name(true)}")
            setOptional(eid, posParam, posParamHash, foundPos as pos)
            return true
          break
      return true

    return res

[beh_node(name="handleCarObstacle")]
class HandleCarObstacle : BehNodeAdapter
  traceDist : float = 1.0

  def override loadFromBlk(var data : DataBlock)
    traceDist = data |> datablock_getReal("traceDist", traceDist)
    let eid = beh_tree_eid(owner)
    if !(query(eid) <| $ [es(REQUIRE=(navmesh_phys__wishLookDir,
                                      agent_dangers__standShootPos,
                                      walker_agent__standShootLocalPos,
                                      agent_obstacles))] {})
      logerr("{eid}: <{getEntityTemplateName(eid)}> HandleCarObstacle is missing fields and will not function {*thisNode |> beh_node_hierarchy_name(true)}")

  def override update(dt : float) : EBehResult
    var res : EBehResult = EBehResult ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (transform : float3x4;
                                          path_corridor__corners : Point3List;
                                          walker_agent__standShootLocalPos : float3;
                                          agent_obstacles : AgentObstacles;
                                          push_object__vehicleEnergyScale = 1000.f)
      let scale = float3(length(transform[0]), length(transform[1]), length(transform[2]))
      let carObstacle = trace_obstacles_along_path(agent_obstacles,
                                                    transform[3],
                                                    path_corridor__corners,
                                                    walker_agent__standShootLocalPos * scale,
                                                    traceDist) <| $(obstacle : ObstacleEx)
        return obstacle.eid |> has("vehicle")

      if carObstacle != INVALID_ENTITY_ID
        sendEvent(carObstacle, [[CmdVehiclePushPhys energyScaledDir=transform[1] * push_object__vehicleEnergyScale, arm = transform[3], duration = 0.0]])
        res = EBehResult ER_SUCCESS
    return res
