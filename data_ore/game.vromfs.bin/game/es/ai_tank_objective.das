require ecs
require ecs.safe
require app
require pathfinder
require danetlibs.pathfinder.main.pathfinder_common
require game.es.events
require math.base
require math.random
require Dacoll
require enlisted.events_enlisted
require DagorSystem

enum CapzoneInitStep
  AIM_INSIDE
  AIM_OUTSIDE
  NO_AIM
  FINISHED


[es(tag=server, on_event=EventLevelLoaded)]
def init_ai_tank_objective_positions_es(evt : Event;
                                        ai_tank_objective__initStateUpdateInterval : float;
                                        var ai_tank_objective__nextInitStepUpdateAt : float&;
                                        var ai_tank_objective__positionCountsPerType : IntList&)
  ai_tank_objective__nextInitStepUpdateAt = get_sync_time() + ai_tank_objective__initStateUpdateInterval
  for _i in range(int(CapzoneInitStep FINISHED))
    ai_tank_objective__positionCountsPerType |> push(0)


[es(tag=server, on_event=EventLevelLoaded)]
def init_ai_tank_custom_objectives_es(evt : Event)
  using() <| $(var positions : Object&)
    query() <| $ [es] (ai_tank_objective__positionId : int;
                       transform : float3x4)
      let idStr = "{ai_tank_objective__positionId}"
      let position = positions[idStr]
      if position != null
        logerr("init_ai_tank_custom_objectives_es: ignoring an AI tank objective position with id={ai_tank_objective__positionId} because this id is already in use")
        return
      set(positions, idStr, transform[3])

    query() <| $ [es] (ai_tank_objective__positionIds : IntList;
                       ai_tank_objective__aimAtPositionIds : IntList;
                       var ai_tank_objective__positions : Point3List&;
                       var ai_tank_objective__aimAtPositions : Point3List&)
      for posId, aimAtPosId in ai_tank_objective__positionIds, ai_tank_objective__aimAtPositionIds
        let pos = positions["{posId}"]
        let aimAtPos = positions["{aimAtPosId}"]
        var success = true
        if pos == null
          logerr("init_ai_tank_custom_objectives_es: nonexistent ID in ai_tank_objective__positionIds ({posId})")
          success = false
        if aimAtPos == null
          logerr("init_ai_tank_custom_objectives_es: nonexistent ID in ai_tank_objective__aimAtPositionIds ({aimAtPosId})")
          success = false
        if success
          push(ai_tank_objective__positions, *(pos ?as float3))
          push(ai_tank_objective__aimAtPositions, *(aimAtPos ?as float3))

def try_generate_ai_tank_objective_position(aim_at_pos : float3;
                                            radius_range : float2;
                                            var out_pos : float3&;
                                            check_ray_hit : bool;
                                            max_slope : float;
                                            height_above_ground : float)
  let phi     = rnd_float(0.0, TWOPI)
  let theta   = rnd_float(0.0, max_slope)
  let radius  = rnd_float(radius_range)

  var cosPhi = 0.
  var sinPhi = 0.
  sincos(phi, sinPhi, cosPhi)

  let sinTheta = sin(theta)

  let airPos = aim_at_pos + float3(radius * cosPhi, height_above_ground + radius * sinTheta, radius * sinPhi)

  var t = 100.0
  var matId = -1
  if tracedown_normalized(airPos, t, matId, ETF_ALL)
    let groundPos = airPos + t * float3(0, -1, 0) + float3(0.0, height_above_ground, 0.0)
    let offs = groundPos - aim_at_pos
    let dist = length(offs)
    let dir = normalize(offs)
    var polyRef : NavMeshTriangle
    if get_triangle_by_pos_ex(NM_EXT_1, groundPos, 1f, polyRef, height_above_ground + 0.1)
      if !check_ray_hit || !rayhit_normalized(aim_at_pos, dir, dist, ETF_DEFAULT, -1)
        out_pos = groundPos
        return true
  return false


[es(tag=server, no_order)]
def fill_capzone_tank_positions_es(event : ParallelUpdateFrameDelayed;
                                   transform : float3x4;
                                   capzone__insideNavmeshPositions : Point3List;
                                   capzone__outsideNavmeshPositions : Point3List;
                                   ai_tank_objective__initStateUpdateInterval : float;
                                   ai_tank_objective__radiusRange : float2;
                                   ai_tank_objective__maxPositionCountsPerType : IntList;
                                   ai_tank_objective__initTryCountPerFrame : int;
                                   ai_tank_objective__maxSlope : float;
                                   ai_tank_objective__heightAboveGround : float;
                                   var ai_tank_objective__positionCountsPerType : IntList&;
                                   var ai_tank_objective__initStep : int&;
                                   var ai_tank_objective__positions : Point3List&;
                                   var ai_tank_objective__aimAtPositions : Point3List&;
                                   var ai_tank_objective__nextInitStepUpdateAt : float&;
                                   var ai_tank_objective__probabilityPerPositionType : FloatList&)
  if ai_tank_objective__initStep == int(CapzoneInitStep FINISHED) || empty(ai_tank_objective__positionCountsPerType) || !pathfinder_is_loaded_ex(NM_EXT_1)
    return

  let curTime = get_sync_time()
  var tries = ai_tank_objective__initTryCountPerFrame

  while tries > 0 && ai_tank_objective__initStep < int(CapzoneInitStep FINISHED)
    if ((curTime >= ai_tank_objective__nextInitStepUpdateAt) ||
        (ai_tank_objective__positionCountsPerType[ai_tank_objective__initStep] >= ai_tank_objective__maxPositionCountsPerType[ai_tank_objective__initStep]) ||
        (ai_tank_objective__initStep == int(CapzoneInitStep AIM_INSIDE) && empty(capzone__insideNavmeshPositions)) ||
        (ai_tank_objective__initStep == int(CapzoneInitStep AIM_OUTSIDE) && empty(capzone__outsideNavmeshPositions)))
      ai_tank_objective__initStep += 1
      ai_tank_objective__nextInitStepUpdateAt = curTime + ai_tank_objective__initStateUpdateInterval
      continue

    tries -= 1

    var aimAtPos : float3
    var tankPos : float3
    var checkRayHit = true
    if ai_tank_objective__initStep == int(CapzoneInitStep AIM_INSIDE)
      aimAtPos = capzone__insideNavmeshPositions[rnd_int(0, length(capzone__insideNavmeshPositions) - 1)]
    elif ai_tank_objective__initStep == int(CapzoneInitStep AIM_OUTSIDE)
      aimAtPos = capzone__outsideNavmeshPositions[rnd_int(0, length(capzone__outsideNavmeshPositions) - 1)]
    else // NO_AIM
      aimAtPos = transform[3]
      checkRayHit = false
    if try_generate_ai_tank_objective_position(aimAtPos, ai_tank_objective__radiusRange, tankPos, checkRayHit, ai_tank_objective__maxSlope, ai_tank_objective__heightAboveGround)
      ai_tank_objective__positions |> push(tankPos)
      ai_tank_objective__aimAtPositions |> push(aimAtPos)
      ai_tank_objective__positionCountsPerType[ai_tank_objective__initStep] += 1

  if ai_tank_objective__initStep == int(CapzoneInitStep FINISHED)
    var validTypesCount = 0
    for i in range(int(CapzoneInitStep FINISHED))
      if ai_tank_objective__positionCountsPerType[i] > 0
        validTypesCount++
    if validTypesCount == 0
      return

    for i in range(int(CapzoneInitStep FINISHED))
      if ai_tank_objective__positionCountsPerType[i] > 0
        continue
      let probInc = ai_tank_objective__probabilityPerPositionType[i] / float(validTypesCount)
      ai_tank_objective__probabilityPerPositionType[i] = 0.0
      for j in range(int(CapzoneInitStep FINISHED))
        if ai_tank_objective__positionCountsPerType[j] <= 0
          continue
        ai_tank_objective__probabilityPerPositionType[j] += probInc
