require ecs
require ecs.common
require DngNet
require vehicle
require DngWeapon
require game.utils.hero
require DngHuman
require HumanPhys
require game.es.events
require DagorInput
require TouchInput
require math.base
require DagorMath
require DagorMathUtils
require DngCamera
require DngInputControls
require enlisted.events_enlisted
require game.es.input.input_events
require common_shooter.es.input.turret_input_common
require common_shooter.es.weapon.turret_common
require common_shooter.events_common_shooter

let
  TRIGGER_MAIN = 0
  TRIGGER_SECONDARY = 1
  TRIGGER_MG = 2
  TRIGGER_GRENADE_LAUNCHER = 3

[es(tag=input, on_appear, on_event=EventOnGunCreated, track=vehicle__localControls)]
def track_turret_input(evt : Event; vehicle__localControls : VehicleControlsState; turret_control__gunEids : EidList)
  var hasFirstTurret = false
  var anyFirstTurret = INVALID_ENTITY_ID
  var firstTurret = INVALID_ENTITY_ID

  for turretNo, turretEid in iter_range(turret_control__gunEids), turret_control__gunEids
    let canControlTurret = can_control_turret(vehicle__localControls, turretNo)
    if canControlTurret && anyFirstTurret == INVALID_ENTITY_ID
      anyFirstTurret = turretEid
    if canControlTurret
      query(turretEid) <| $ [es(REQUIRE=isTurret, REQUIRE_NOT=gun__isLauncher)] (firstTurretInput : Tag const?)
        if firstTurretInput == null
          addSubTemplate(turretEid, "first_turret")
        hasFirstTurret = true
        firstTurret = turretEid
      if hasFirstTurret
        break

  if (!hasFirstTurret && anyFirstTurret != INVALID_ENTITY_ID)
    addSubTemplate(anyFirstTurret, "first_turret") <| $(var init)
      set(init, "isForestall", false)
    firstTurret = anyFirstTurret

  for turretNo, turretEid in iter_range(turret_control__gunEids), turret_control__gunEids
    query(turretEid) <| $ [es] (turretInput : Tag const?; firstTurretInput : Tag const?)
      if turretEid != firstTurret && firstTurretInput != null
        removeSubTemplate(turretEid, "first_turret")
      if can_control_turret(vehicle__localControls, turretNo)
        if turretInput == null
          addSubTemplate(turretEid, "turret_input")
      else
        if turretInput != null
          removeSubTemplate(turretEid, "turret_input")
        if firstTurretInput != null
          removeSubTemplate(turretEid, "first_turret")

[es(tag=input, REQUIRE=input__enabled)]
def turret_update_turret_aim_point(info : ParallelUpdateFrameDelayed;
                                   turret_control__gunEids : EidList;
                                   var isTurretAimPosValid : bool&;
                                   var turretAimPos : float3&)
  isTurretAimPosValid = false

  for turretEid in turret_control__gunEids
    query(turretEid) <| $ [es(REQUIRE=(resolvedTurret, firstTurretInput))] (turret_input__aimPos : float3; turret__disableAim : Tag const?)
      if turret__disableAim == null
        isTurretAimPosValid = true
        turretAimPos = turret_input__aimPos

[es(on_event=CmdSetVehicleShootDir)]
def vehicle_input_set_direction(evt : Event; turret_control__gunEids : EidList)
  for gunEid in turret_control__gunEids
    setOptional(gunEid, "turret__isGunDirInited", false)

[es(tag=input)]
def turret_update_aim_point_es(info : ParallelUpdateFrameDelayed; turret_control__gunEids : EidList)
  for gunEid in turret_control__gunEids
    query(gunEid) <| $ [es(REQUIRE=(resolvedTurret, firstTurretInput))] (turret__isGunDirInited : bool;
                                                                         turret_input__aimAngles : float2;
                                                                         var turret_input__aimPos : float3&)
      if turret__isGunDirInited
        turret_input__aimPos = calc_aim_pos(turret_input__aimAngles)

def set_look_dir_from_turret(turret_control__gunEids : EidList;
                             var camera__lookDir : float3&)
  let camTm = get_TMatrix(get_cur_cam_entity(), "transform")
  let camPos = camTm != null ? (*camTm)[3] : float3()

  for gunEid in turret_control__gunEids
    query(gunEid) <| $ [es(REQUIRE=(resolvedTurret, firstWatchedTurret))] (turret__isGunDirInited : bool; turret_input__aimPos : float3)
      if !turret__isGunDirInited
        return
      camera__lookDir = normalize(turret_input__aimPos - camPos)

[es(tag=input, REQUIRE_NOT=airplane, after=(vehicle_input_gunner_limits_control_es, vehicle_input_commander_limits_control_es))]
def turret_camera_look_dir_es(info : ParallelUpdateFrameDelayed;
                              turret_control__gunEids : EidList;
                              var camera__lookDir : float3&)
  set_look_dir_from_turret(turret_control__gunEids, camera__lookDir)

[es(tag=input, REQUIRE=airplane, after=(vehicle_input_gunner_limits_control_es, vehicle_input_commander_limits_control_es))]
def turret_camera_look_dir_plane(info : ParallelUpdateFrameDelayed;
                                 turret_control__gunEids : EidList;
                                 vehicleCameraType : int;
                                 var camera__lookDir : float3&)
  if vehicleCameraType != int(VehicleCameraType VEHICLE_CAMERA_DRIVER)
    set_look_dir_from_turret(turret_control__gunEids, camera__lookDir)

[es(tag=input, REQUIRE=heroVehicle, before=turret_aim_angles_to_look_dir_es)]
def human_vehicle_lock_turrets_input_es(evt : ParallelUpdateFrameDelayed;
                                        turret_control__gunEids : EidList;
                                        cockpit__eid : EntityId = INVALID_ENTITY_ID;
                                        vehicle_look__lockAllTurrentControll : bool = false;
                                        var turret_control__isInputLocked : bool&)
  query() <| $ [es(REQUIRE=hero)] (human_input__look : int;
                                   human_vehicle__occupiedSeatEid : EntityId;
                                   human_vehicle__isShootingPassenger : bool)
    let asLook = get_analog_stick_action_state(uint16(human_input__look))
    let isPeriscope = get_bool(cockpit__eid, "cockpit__isPeriscope") ?? false
    query(human_vehicle__occupiedSeatEid) <| $ [es] (seat__availableHatchControls : VehicleControlsState;
                                                     seat__isInHatch : bool;
                                                     seat__isHatchControlInversed : bool = false)
      let isInHatch = seat__isInHatch  ^^ seat__isHatchControlInversed
      let isFreeLook = asLook.bActive && (isInHatch || isPeriscope)
      let isLocalControlLocked = isFreeLook || human_vehicle__isShootingPassenger
      let needLockAllTurrets = vehicle_look__lockAllTurrentControll || human_vehicle__isShootingPassenger
      if turret_control__isInputLocked == isLocalControlLocked
        return
      for gunEid in turret_control__gunEids
        query(gunEid) <| $ [es] (turret__id : int; var turret_input__isLocalControlLocked : bool&)
          turret_control__isInputLocked = isLocalControlLocked
          turret_input__isLocalControlLocked = (isLocalControlLocked
            && (needLockAllTurrets || !can_control_turret(seat__availableHatchControls, turret__id)))

[es(tag=input, on_disappear, REQUIRE=heroVehicle)]
def human_vehicle_unlock_turrets_hero_leave_vehicle_input_es(evt : Event;
                                                             turret_control__gunEids : EidList;
                                                             var turret_control__isInputLocked : bool&)
  turret_control__isInputLocked = false
  for gunEid in turret_control__gunEids
    query(gunEid) <| $ [es] (var turret_input__isLocalControlLocked : bool&)
      turret_input__isLocalControlLocked = false

[es(tag=input, after=turret_camera_look_dir_es, before=human_look_dir_camera_in_vehicle_es)]
def turret_aim_angles_to_look_dir_es(info : ParallelUpdateFrameDelayed;
                                     turret_control__gunEids : EidList;
                                     camera__lookDir : float3)
  for gunEid in turret_control__gunEids
    query(gunEid) <| $ [es(REQUIRE=(resolvedTurret, firstTurretInput))] (turret__isGunDirInited : bool;
                                                                         turret__disableAim : Tag const?;
                                                                         var turret_input__aimAngles : float2&;
                                                                         var turret_input__aimPos : float3&)
      if !turret__isGunDirInited || turret__disableAim != null
        return
      turret_input__aimAngles = dir_to_angles(camera__lookDir)
      turret_input__aimPos = calc_aim_pos(turret_input__aimAngles)

      find_query() <| $ [es(REQUIRE=hero)] (var human_net_phys : HumanActor;
                                            var human_input__aimAngle : float2&;
                                            human_vehicle__occupiedSeatEid : EntityId;
                                            human_vehicle__isHoldingGunPassenger : bool;
                                            human_input__lastVehicleAngleDelta : float;
                                            isInVehicle : bool)
        human_input__aimAngle = turret_input__aimAngles
        if isInVehicle
          human_input__aimAngle.x = norm_s_ang(human_input__aimAngle.x + human_input__lastVehicleAngleDelta)
          if human_vehicle__isHoldingGunPassenger
            query(human_vehicle__occupiedSeatEid) <| $ [es] (seat__holdingGunPassengerVertLookLimit : float2)
              let vertLookLimit = deg_to_rad(seat__holdingGunPassengerVertLookLimit)
              human_input__aimAngle.y = clamp(human_input__aimAngle.y, vertLookLimit.x, vertLookLimit.y)
          turret_input__aimAngles = human_input__aimAngle

        let wishDir = angles_to_dir(human_input__aimAngle)
        assume ct = human_net_phys.phys.producedCT
        ct |> human_control_state_set_wish_shoot_dir(wishDir)
        ct |> human_control_state_set_wish_look_dir(wishDir)
        return true

def get_action_state_or(action : uint16; default_value : bool)
  let isTouchPressed = is_button_pressed(action)
  let state = get_digital_action_state(action)
  let isActive = state.bActive || isTouchPressed
  return isActive ? (state.bState || isTouchPressed) : default_value

[es(tag=input)]
def vehicle_input_grenade_launcher_input_triggered(evt : EventDaInputActionTriggered;
                                                   input__enabled : bool;
                                                   turret_control__gunEids : EidList;
                                                   turret_control__grenadeLauncherSalvoSize : int = 1;
                                                   vehicle_input__shootGrenadeLauncher : int)
  if input__enabled && int(evt.action) == vehicle_input__shootGrenadeLauncher
    let state = get_action_state_or(uint16(vehicle_input__shootGrenadeLauncher), false)
    release_weapon(turret_control__gunEids, state, TRIGGER_GRENADE_LAUNCHER, turret_control__grenadeLauncherSalvoSize)

[es(tag=input)]
def vehicle_input_grenade_launcher_input_terminated(evt : EventDaInputActionTerminated;
                                                    input__enabled : bool;
                                                    turret_control__gunEids : EidList;
                                                    vehicle_input__shootGrenadeLauncher : int)
  if input__enabled && int(evt.action) == vehicle_input__shootGrenadeLauncher
    stop_weapons(turret_control__gunEids, TRIGGER_GRENADE_LAUNCHER)

[es(tag=input)]
def vehicle_input_gunner_es(info : ParallelUpdateFrameDelayed;
                            input__enabled : bool;
                            turret_control__gunEids : EidList;
                            vehicle_input__aim : int;
                            vehicle_input__shoot : int;
                            vehicle_input__shootSecondary : int;
                            vehicle_input__shootMachinegun : int)
  if !input__enabled
    return

  var isShootingPassenger = false
  var isGyroAimEnabled = false
  var humanInputAim = int(BAD_ACTION_HANDLE)
  var humanInputAimDelta = int(BAD_ACTION_HANDLE)
  var isHumanInAim = false
  var isHumanInZoomView = false
  query() <| $ [es(REQUIRE=hero)] (human_vehicle__isShootingPassenger : bool;
                                   human_input__isGyroAimEnabled : bool;
                                   human_input__aim : int;
                                   human_input__aimDelta : int;
                                   human_net_phys : HumanActor)
    isShootingPassenger = human_vehicle__isShootingPassenger
    isGyroAimEnabled = human_input__isGyroAimEnabled
    humanInputAim = human_input__aim
    humanInputAimDelta = human_input__aimDelta
    isHumanInAim = human_net_phys.phys.appliedCT |> is_control_bit_set(HumanPhysControlType HCT_AIM)
    isHumanInZoomView = human_net_phys.phys.appliedCT |> is_control_bit_set(HumanPhysControlType HCT_ZOOM_VIEW)

  for gunEid in turret_control__gunEids
    query(gunEid) <| $ [es(REQUIRE=resolvedTurret)] (turret__triggerGroup : int;
                                                     var turret_input__shootFlag : bool&)
      if turret__triggerGroup == TRIGGER_MAIN
        turret_input__shootFlag = get_action_state_or(uint16(vehicle_input__shoot), turret_input__shootFlag)
      elif turret__triggerGroup == TRIGGER_SECONDARY
        turret_input__shootFlag = get_action_state_or(uint16(vehicle_input__shootSecondary), turret_input__shootFlag)
      elif turret__triggerGroup == TRIGGER_MG
        turret_input__shootFlag = get_action_state_or(uint16(vehicle_input__shootMachinegun), turret_input__shootFlag)

  let inputAim = uint16(isShootingPassenger ? humanInputAim : vehicle_input__aim)
  var aAim = get_analog_stick_action_state(inputAim)
  let touchAim = get_stick_value(inputAim)
  aAim.x = clamp(aAim.x + touchAim.x, -1.0, 1.0)
  aAim.y = clamp(aAim.y + touchAim.y, -1.0, 1.0)

  assume sens_scale = get_sens_scale()
  if isShootingPassenger
    let sensMult = isHumanInAim || isHumanInZoomView ? sens_scale.humanAiming : sens_scale.humanFpsCam
    aAim.x *= sensMult
    aAim.y *= sensMult
  else
    aAim.x *= sens_scale.vehicleCam
    aAim.y *= sens_scale.vehicleCam

  if isShootingPassenger && isGyroAimEnabled
    let asAimDelta = get_analog_stick_action_state(uint16(humanInputAimDelta))
    if asAimDelta.bActive
      aAim.x += asAimDelta.x
      aAim.y += asAimDelta.y

  apply_turret_input(turret_control__gunEids, aAim)

[es(tag=(server, input))]
def turret_input_local_es(info : UpdateStageUpdateInput;
                          eid : EntityId;
                          net_phys__currentStatePosition : float3;
                          vehicle__localControls : VehicleControlsState;
                          turret_control__gunEids : EidList)
  for gunEid in turret_control__gunEids
    query(gunEid) <| $ [es(REQUIRE=resolvedTurret)] (turret__id : int;
                                                     turret_input__shootFlag : bool;
                                                     turret_input__aimPos : float3;
                                                     turret_input__isLocalControlLocked : bool = false;
                                                     var turret_aim__shootAngles : float2&;
                                                     var turret_aim__shootFlag : bool&)
      let turretNo = turret__id

      if !can_control_turret(vehicle__localControls, turretNo)
        return

      let wasShooting = turret_aim__shootFlag
      let shootFlag = turret_input__shootFlag

      if turret_input__isLocalControlLocked
        turret_aim__shootFlag = false
        if wasShooting && !shootFlag
          sendEventImmediate(eid, [[EventOnTurretShooting isStart=false, turretNo=turretNo]])
        return

      turret_aim__shootAngles = turret_calc_shoot_angles(net_phys__currentStatePosition, turret_input__aimPos)
      turret_aim__shootFlag = shootFlag

      if !wasShooting && shootFlag
        sendEventImmediate(eid, [[EventOnTurretShooting isStart=true, turretNo=turretNo]])
      elif wasShooting && !shootFlag
        sendEventImmediate(eid, [[EventOnTurretShooting isStart=false, turretNo=turretNo]])

[es(tag=input)]
def vehicle_input_gunner_turret_with_group_es(info : ParallelUpdateFrameDelayed;
                                              eid : EntityId;
                                              input__enabled : bool;
                                              turret_control__gunEids : EidList)
  if !input__enabled
    return

  let vehicleEid = eid

  for gunEid in turret_control__gunEids
    query(gunEid) <| $ [es(REQUIRE=resolvedTurret, REQUIRE_NOT=turret__ignoreGroupTrigger)] (turret__groupHash : int; turret_input__shootFlag : bool)
      if !turret_input__shootFlag
        return

      let currentTurretGroup = turret__groupHash
      query() <| $ [es] (eid : EntityId; turret__groupHash : int; turret__owner : EntityId)
        if turret__owner == vehicleEid && turret__groupHash == currentTurretGroup
          let index = find_index(turret_control__gunEids, eid)
          if index >= 0
            setOptional(turret_control__gunEids[index], "turret_input__shootFlag", true)

[es(tag=input)]
def vehicle_next_bullet_type_input(evt : EventDaInputActionTriggered;
                                   eid : EntityId;
                                   input__enabled : bool;
                                   vehicle_input__mainNextBulletType : int;
                                   vehicle_input__secondaryNextBulletType : int)
  query() <| $ [es(REQUIRE=hero)] (human_vehicle__isShootingPassenger : bool)
    if human_vehicle__isShootingPassenger
      return

    if input__enabled && int(evt.action) == vehicle_input__mainNextBulletType
      send_net_event(eid, [[CmdNextBulletIdRequest triggerGroup = 0]])

    if input__enabled && int(evt.action) == vehicle_input__secondaryNextBulletType
      send_net_event(eid, [[CmdNextBulletIdRequest triggerGroup = 1]])

[es(tag=input)]
def vehicle_toggle_stabilizer_input(evt : EventDaInputActionTriggered;
                                    input__enabled : bool;
                                    turret_control__isStabilizerEnabled : bool;
                                    vehicle_input__toggleStabilizer : int)

  if input__enabled && int(evt.action) == vehicle_input__toggleStabilizer
    query() <| $ [es(REQUIRE=hero)] (eid : EntityId) // send to controlled entity
      send_net_event(eid, [[CmdRequestStabilizer enabled=!turret_control__isStabilizerEnabled]])
