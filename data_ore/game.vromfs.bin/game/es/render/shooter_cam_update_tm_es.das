require ecs
require ecs.common
require DagorMath
require math
require math.base
require level
require Dacoll
require game.es.battle_area_common

let REPLAY_CAMERA_MOVE_DT = 100.

[es(tag=render, after=shooter_cam_act_es, before=after_camera_sync)]
def shooter_cam_clamp_tau_es(info : UpdateStageInfoAct;
                             camera__tauPos : float;
                             camera__active : bool;
                             shooter_cam__tauOnChange : float;
                             var shooter_cam__wasAlternative : bool&;
                             var shooter_cam__tauInc : float&;
                             shooter_cam__alternative_settings = false)
  if !camera__active || is_level_loading()
    return

  if shooter_cam__wasAlternative != shooter_cam__alternative_settings
    shooter_cam__tauInc = max(camera__tauPos, max(shooter_cam__tauInc, shooter_cam__tauOnChange))
  shooter_cam__wasAlternative = shooter_cam__alternative_settings

[es(tag=render, after=shooter_cam_clamp_tau_es, before=after_camera_sync)]
def shooter_cam_tau_move_scalar_es(info : UpdateStageInfoAct;
                                   camera__active : bool;
                                   var shooter_cam__tauInc : float&)
  if !camera__active || is_level_loading()
    return
  shooter_cam__tauInc = move_to_scalar(shooter_cam__tauInc, 0.f, info.dt, 0.4f)

[es(tag=render, after=shooter_cam_clamp_tau_es, before=shooter_cam_tau_move_scalar_es)]
def shooter_cam_rotate_es(info : UpdateStageInfoAct;
                          camera__active : bool;
                          camera__target : EntityId;
                          camera__vertOffset : float;
                          shooter_cam__tauInc : float;
                          var shooter_cam__lastDir : float3&;
                          var transform aka camera_transform : float3x4;
                          shooter_camera__forceStabilized = false;
                          replayCamera : Tag const?)
  if !camera__active || is_level_loading()
    return
  let dt = replayCamera == null ? info.dt : REPLAY_CAMERA_MOVE_DT
  query(camera__target) <| $ [es] (transform : float3x4;
                                   camera__isStabilized = true;
                                   camera__isRotateInGlobal = false;
                                   camera__relative_roll_angle = 0.f; // if not stabilized
                                   camera__relative_angle = float2(0.f, 0.f);
                                   camera__lookDir = float3(1.f, 0.f, 0.f))
    var wishQ = dir_to_quat(camera__lookDir)
    if length_sq(camera__relative_angle) > 0.f
      var relativeQuat : quat
      euler_to_quat(camera__relative_angle.x, camera__relative_angle.y, camera__relative_roll_angle, relativeQuat)
      let worldDir = relativeQuat * camera__lookDir
      wishQ = camera__isRotateInGlobal ? dir_to_quat(worldDir) : (wishQ * relativeQuat)

    let lastQ = normalize(approach(dir_to_quat(shooter_cam__lastDir), wishQ, dt, shooter_cam__tauInc))
    let lastDir = quat_get_forward(lastQ)
    shooter_cam__lastDir = lastDir
    let stabVec = !camera__isStabilized && !shooter_camera__forceStabilized ? transform[1] : float3(0.f, 1.f, 0.f)

    let dir0 = normalize(cross(stabVec, lastDir))
    let dir2 = quat(dir0, camera__vertOffset) * lastDir
    camera_transform[0] = dir0
    camera_transform[2] = dir2
    camera_transform[1] = normalize(cross(dir2, dir0)) // up

[es(tag=render, after=shooter_cam_clamp_tau_es, before=shooter_cam_tau_move_scalar_es)]
def shooter_cam_update_tm_es(info : UpdateStageInfoAct;
                             var fov : float&;
                             var transform aka camera_transform : float3x4;
                             var shooter_cam__lastPos : float3&;
                             var shooter_cam__lastAnimTmOffset : float3&;
                             var camera__accuratePos : DPoint3&;
                             var isHeroCockpitCam : bool&;
                             var camera__totalMagnification : float&;
                             var shooter_cam__isLastPosValid : bool&;
                             var shooter_cam__velMain : float3&;
                             var shooter_cam__velAnim : float3&;
                             var shooter_cam__lastOffsDistMult : float&;
                             var camera__prevOffset : float3&;
                             var camera__posOnlyBaseOffset : DPoint3&;
                             fovSettings : float;
                             camera__target : EntityId;
                             camera__active : bool;
                             camera__offset : float3;
                             camera__pivotPos : float3;
                             camera__velTau : float;
                             camera__velFactor : float;
                             camera__tau : float;
                             camera__tmToAnimRatio : float;
                             camera__animTau : float;
                             shooter_cam__tauInc : float;
                             shooter_cam__rayMatId : int;
                             shooter_cam__moveInSpd = 2.f;
                             shooter_cam__moveOutSpd = 2.f;
                             shooter_cam__offset = float3(0.f, 0.f, 0.f);
                             shooter_cam__additionalOffset = float3(0.f, 0.f, 0.f);
                             shooter_cam__tauMult = 1.f;
                             shooter_cam__velTauMult = 1.f;
                             shooter_cam__magnificationMult = 1.f;
                             replay_cam__tpsOffsetMultiplierVehicle = 2.5f;
                             shooter_cam__offset_multiplier = 1.f;
                             replayCamera : Tag const?)
  if !camera__active || is_level_loading()
    return
  let dt = replayCamera == null ? info.dt : REPLAY_CAMERA_MOVE_DT
  query(camera__target) <| $ [es] (transform aka target_transform : float3x4;
                                   camera__look_at : DPoint3;
                                   camera__magnification = 1.f;
                                   camera__tauMult = 1.f;
                                   isInVehicle = false;
                                   human_cam__isIndoor = false;
                                   human_cam__indoorOffs = float3(0f);
                                   isTpsView = false;
                                   human_cam__viscosity = 1f;
                                   human_cam__horizontalOffsetMult = 1f;
                                   isAlive = true;
                                   isDowned = false;
                                   camera__fallenGroundDistance = 0.3f)
    assert(camera__magnification > 0.0f)
    let baseOffset = camera__offset + shooter_cam__offset + shooter_cam__additionalOffset
    var offset = baseOffset
    var vehicleOffsetMult = 1.
    isHeroCockpitCam = length_sq(offset) == 0f // exactly zero, we switch to a cockpit cam in that case
    if isTpsView && !isInVehicle && !isHeroCockpitCam
      // Indoor offset
      offset = human_cam__isIndoor ? offset + human_cam__indoorOffs : offset
      // Horizontal offset
      offset.x *= human_cam__horizontalOffsetMult
      offset = approach(camera__prevOffset, offset, dt, human_cam__viscosity)

    if isTpsView && isInVehicle
      vehicleOffsetMult = replay_cam__tpsOffsetMultiplierVehicle
    camera__prevOffset = offset

    let magnification = isTpsView ? 1. : (camera__magnification * shooter_cam__magnificationMult)
    fov = rad_to_deg(atan(tan(deg_to_rad(fovSettings * 0.5f)) * safeinv(magnification))) * 2.f
    camera__totalMagnification = magnification

    let lookAtPos = length_sq(camera__look_at) != 0. ? camera__look_at : DPoint3(target_transform[3])
    var velMain = DPoint3(shooter_cam__velMain)
    var wishPos = lookAtPos

    let animTmOffset = lookAtPos - DPoint3(target_transform[3])
    var velAnim = DPoint3(shooter_cam__velAnim)
    var wishPosAnim = animTmOffset

    if shooter_cam__isLastPosValid
      let velTau = camera__velTau * shooter_cam__velTauMult

      let tau = (camera__tau * shooter_cam__tauMult + shooter_cam__tauInc) * camera__tauMult
      wishPos = approach_vel(DPoint3(shooter_cam__lastPos), lookAtPos, dt, tau, velMain, velTau, camera__velFactor)

      let taua = (camera__animTau + shooter_cam__tauInc) * camera__tauMult
      wishPosAnim = approach_vel(DPoint3(shooter_cam__lastAnimTmOffset), animTmOffset, dt, taua, velAnim, velTau, camera__velFactor)

    shooter_cam__lastPos = float3(wishPos)
    shooter_cam__velMain = float3(velMain)

    shooter_cam__lastAnimTmOffset = float3(wishPosAnim)
    shooter_cam__velAnim = float3(velAnim)

    shooter_cam__isLastPosValid = true

    wishPos = wishPos * (1.f - camera__tmToAnimRatio) + (wishPosAnim + DPoint3(target_transform[3])) * camera__tmToAnimRatio

    var cameraOffs = rotate(camera_transform, offset * shooter_cam__offset_multiplier * vehicleOffsetMult)
    let cameraBaseOffs = rotate(camera_transform, baseOffset * shooter_cam__offset_multiplier * vehicleOffsetMult)
    let cameraOffsLenSq = length_sq(cameraOffs)

    var pivotOffs = rotate(camera_transform, camera__pivotPos)
    let sphereRad = 0.1f
    if length_sq(pivotOffs) > 1e-4f && cameraOffsLenSq > 1e-4f
      // do additional check to original pivot from this one
      var queryOut = ShapeQueryOutput()
      if sphere_cast(float3(wishPos), float3(wishPos + DPoint3(pivotOffs)), sphereRad, queryOut, shooter_cam__rayMatId)
        pivotOffs = rotate(camera_transform, (camera__pivotPos * queryOut.t))

    var wishDistMult = 1.f
    if cameraOffsLenSq > 1e-4f
      var queryOut = ShapeQueryOutput()
      if sphere_cast(float3(wishPos + DPoint3(pivotOffs)), float3(wishPos + DPoint3(cameraOffs)), sphereRad, queryOut, shooter_cam__rayMatId)
        //This will result in camera position approaching the same location (save for sphereRad) as the collision point returned by sphere_cast
        let wishOffs = DPoint3(queryOut.res) - wishPos - DPoint3(pivotOffs)
        wishDistMult = safediv(max(length(wishOffs) - sphereRad, 0.f), length(cameraOffs - pivotOffs))

    var multSpd = shooter_cam__moveInSpd
    if wishDistMult > shooter_cam__lastOffsDistMult
      multSpd = shooter_cam__moveOutSpd
    shooter_cam__lastOffsDistMult = move_to_scalar(shooter_cam__lastOffsDistMult, wishDistMult, dt, multSpd)
    cameraOffs = lerp(pivotOffs, cameraOffs, float3(shooter_cam__lastOffsDistMult))
    camera__posOnlyBaseOffset = approach(camera__posOnlyBaseOffset, wishPos + DPoint3(cameraBaseOffs), dt, shooter_cam__tauInc)
    camera__accuratePos = approach(camera__accuratePos, wishPos + DPoint3(cameraOffs), dt, shooter_cam__tauInc)

    if (!isAlive || isDowned) && camera__fallenGroundDistance > 0.f
      let tracePoint = float2(float(camera__accuratePos.x), float(camera__accuratePos.z))
      let lMeshHeight = traceht_lmesh(tracePoint)
      let minHeight = camera__fallenGroundDistance + lMeshHeight

      let inLandmeshHole = find_query() <| $ [es(REQUIRE=underground_zone)] (transform aka hole_transform : float3x4)
        return is_point_in_box_zone(float3(camera__accuratePos), hole_transform)

      if !inLandmeshHole && camera__accuratePos.y < double(minHeight)
        camera__accuratePos.y = double(minHeight)

    camera_transform[3] = float3(camera__accuratePos)

[es(tag=render, after=shooter_cam_update_tm_es, before=shooter_cam_tau_move_scalar_es)]
def shooter_cam_vehicle_update_tm_es(info : UpdateStageInfoAct;
                                     camera__target : EntityId;
                                     camera__active : bool;
                                     camera__tau : float;
                                     shooter_cam__tauInc : float;
                                     shooter_cam__tauMult = 1.f;
                                     replayCamera : Tag const?;
                                     var transform aka camera_transform : float3x4;
                                     var camera__accuratePos : DPoint3&;
                                     var shooter_cam__lastVehicleOffset : float3&)
  if !camera__active || is_level_loading()
    return
  query(camera__target) <| $ [es] (camera__look_at : DPoint3;
                                   human_anim__vehicleSelected : EntityId;
                                   camera__tauMult : float = 1.f;
                                   isInVehicle : bool;
                                   isTpsView : bool)
    if !isInVehicle || isTpsView
      return
    let dt = replayCamera == null ? info.dt : REPLAY_CAMERA_MOVE_DT
    query(human_anim__vehicleSelected) <| $ [es] (transform aka vehicle_transform : float3x4)
      let vehiclePos = DPoint3(vehicle_transform[3])
      let wishVehicleOffset = camera__look_at - vehiclePos

      let tau = (camera__tau * shooter_cam__tauMult + shooter_cam__tauInc) * camera__tauMult
      let lastVehicleOffset = approach(DPoint3(shooter_cam__lastVehicleOffset), wishVehicleOffset, dt, tau)

      shooter_cam__lastVehicleOffset = float3(lastVehicleOffset)

      camera__accuratePos = vehiclePos + DPoint3(shooter_cam__lastVehicleOffset)
      camera_transform[3] = float3(camera__accuratePos)
