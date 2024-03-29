require ecs
require game.es.events
require pathfinder
require math.base

[es(tag=server, REQUIRE=vehicleSpawnValidation, REQUIRE_NOT=spawn_validation__spreadDir, on_appear)]
def vehicle_spawn_validate(evt : Event;
                           eid : EntityId;
                           transform : float3x4;
                           spawn_validation__spreadDistance : float;
                           spawn_validation__useNavmesh : bool = false)
  let createdVehicleEid = eid
  var wishPos = transform[3]

  var vehiclesPos : array<float3>
  query() <| $ [es(REQUIRE=vehicle)] (eid : EntityId; transform : float3x4)
    if eid == createdVehicleEid
      return
    push(vehiclesPos, transform[3])

  var shouldTeleport = false

  for _i in range(0, 6)
    var isWorking = false
    for pos in vehiclesPos
      var dist = wishPos - pos
      dist.y = 0.0
      var len = length(dist)
      if len == 0.0
        len = 1.0
        dist = float3(1.0, 0.0, 0.0)
      if len < spawn_validation__spreadDistance
        dist = dist * (1.0 / len)
        wishPos = wishPos + dist * ((spawn_validation__spreadDistance - len) + 1.)
        shouldTeleport = true
        isWorking = true
    if !isWorking
      break

  if shouldTeleport
    if spawn_validation__useNavmesh
      project_to_nearest_navmesh_point(wishPos, spawn_validation__spreadDistance)
    var wishTm = transform
    wishTm[3] = wishPos
    sendEventImmediate(createdVehicleEid, [[CmdTeleportEntity newTm=wishTm, hard=false]])

[es(REQUIRE=vehicleSpawnValidation, on_appear, on_event=EventOnEntityTeleported)]
def vehicle_spawn_validate_directed(evt : Event;
                                    eid : EntityId;
                                    transform : float3x4;
                                    spawn_validation__spreadDistance : float;
                                    spawn_validation__additionalHeight : float;
                                    var spawn_validation__isValidated : bool&;
                                    spawn_validation__spreadDir : float3)
  if spawn_validation__isValidated
    return

  let createdVehicleEid = eid
  var wishPos = transform[3]
  var rotTm = transform
  rotTm[3] = float3()
  let worldSpreadDir = rotTm * spawn_validation__spreadDir
  var vehiclesPos : array<float3>
  query() <| $ [es(REQUIRE=vehicle)] (eid : EntityId; transform : float3x4)
    if eid == createdVehicleEid
      return
    push(vehiclesPos, transform[3])
  let distSq = square(spawn_validation__spreadDistance)
  var findNewPos = false
  var noObstacle = false
  while (!noObstacle)
    noObstacle = true
    for pos in vehiclesPos
      if distance_sq(wishPos, pos) < distSq
        wishPos += worldSpreadDir
        findNewPos = true
        noObstacle = false
        break

  if findNewPos
    var wishTm = transform
    wishTm[3] = wishPos
    wishTm[3][1] += spawn_validation__additionalHeight
    spawn_validation__isValidated = true
    sendEventImmediate(createdVehicleEid, [[CmdTeleportEntity newTm=wishTm, hard=false]])
