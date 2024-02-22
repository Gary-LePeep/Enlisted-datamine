require ecs
require app
require pathfinder
require danetlibs.pathfinder.main.pathfinder_common
require game.es.events
require math.base
require math.random
require Dacoll
require enlisted.events_enlisted


enum CapzoneInitStep
  AIM_INSIDE
  AIM_OUTSIDE
  NO_AIM
  FINISHED


[es(tag=server, on_event=EventLevelLoaded)]
def init_capzones_tank_positions_es(evt : Event;
                                    capzone_tanks__initStateUpdateInterval : float;
                                    var capzone_tanks__nextInitStepUpdateAt : float&;
                                    var capzone_tanks__positionCountsPerType : IntList&)
  capzone_tanks__nextInitStepUpdateAt = get_sync_time() + capzone_tanks__initStateUpdateInterval
  for _i in range(int(CapzoneInitStep FINISHED))
    capzone_tanks__positionCountsPerType |> push(0)


def try_generate_capzone_tank_position(aim_at_pos : float3;
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
                                   capzone_tanks__initStateUpdateInterval : float;
                                   capzone_tanks__radiusRange : float2;
                                   capzone_tanks__maxPositionCountsPerType : IntList;
                                   capzone_tanks__initTryCountPerFrame : int;
                                   capzone_tanks__maxSlope : float;
                                   capzone_tanks__heightAboveGround : float;
                                   var capzone_tanks__positionCountsPerType : IntList&;
                                   var capzone_tanks__initStep : int&;
                                   var capzone_tanks__positions : Point3List&;
                                   var capzone_tanks__aimAtPositions : Point3List&;
                                   var capzone_tanks__nextInitStepUpdateAt : float&)
  if capzone_tanks__initStep == int(CapzoneInitStep FINISHED) || empty(capzone_tanks__positionCountsPerType) || !pathfinder_is_loaded_ex(NM_EXT_1)
    return

  let curTime = get_sync_time()
  var tries = capzone_tanks__initTryCountPerFrame

  while tries > 0 && capzone_tanks__initStep < int(CapzoneInitStep FINISHED)
    if ((curTime >= capzone_tanks__nextInitStepUpdateAt) ||
        (capzone_tanks__positionCountsPerType[capzone_tanks__initStep] >= capzone_tanks__maxPositionCountsPerType[capzone_tanks__initStep]) ||
        (capzone_tanks__initStep == int(CapzoneInitStep AIM_INSIDE) && empty(capzone__insideNavmeshPositions)) ||
        (capzone_tanks__initStep == int(CapzoneInitStep AIM_OUTSIDE) && empty(capzone__outsideNavmeshPositions)))
      capzone_tanks__initStep += 1
      capzone_tanks__nextInitStepUpdateAt = curTime + capzone_tanks__initStateUpdateInterval
      continue

    tries -= 1

    var aimAtPos : float3
    var tankPos : float3
    var checkRayHit = true
    if capzone_tanks__initStep == int(CapzoneInitStep AIM_INSIDE)
      aimAtPos = capzone__insideNavmeshPositions[rnd_int(0, length(capzone__insideNavmeshPositions) - 1)]
    elif capzone_tanks__initStep == int(CapzoneInitStep AIM_OUTSIDE)
      aimAtPos = capzone__outsideNavmeshPositions[rnd_int(0, length(capzone__outsideNavmeshPositions) - 1)]
    else // NO_AIM
      aimAtPos = transform[3]
      checkRayHit = false
    if try_generate_capzone_tank_position(aimAtPos, capzone_tanks__radiusRange, tankPos, checkRayHit, capzone_tanks__maxSlope, capzone_tanks__heightAboveGround)
      capzone_tanks__positions |> push(tankPos)
      capzone_tanks__aimAtPositions |> push(aimAtPos)
      capzone_tanks__positionCountsPerType[capzone_tanks__initStep] += 1
