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

require HumanPhys
require DngHuman
require DngWalkerai
require walkerai
require game.es.ai.walker_common
require game.utils.team

require Gun
require DngWeapon
require DaWeapons
require DaWeaponProps

require dm
require DngDm
require BallisticsProps
require BallisticsDm

require AnimV20
require CollRes

require enlisted.game.es.squad_behaviour_command_common
require common_shooter.es.ai.common_shooter_walker_nodes_common
require common_shooter.es.ai.ai_weapons_common
require common_shooter.es.human_attached_gun_common
require common_shooter.es.interactable_common
require game.es.ai.enlisted_combat_ai_common
require game.es.vehicle.vehicle_seats_common
require game.es.dm_ai_common

require common_shooter.events_common_shooter
require game.es.events


[beh_node(name="isAggressiveBehaviour")]
class IsAggressiveBehaviour : BehNodeAdapter
  def override update(dt : float) : EBehResult
    var res = EBehResult ER_FAILED

    let agentEid = beh_tree_eid(owner)

    query(agentEid) <| $ [es] (squad_member__squad : EntityId)
      query(squad_member__squad) <| $ [es] (squad__squadBehaviour : int)
        if squad__squadBehaviour == int(SquadBehaviour ESB_AGGRESSIVE)
          res = EBehResult ER_SUCCESS

    return res

[beh_node(name="startAim")]
class StartAim : BehNodeAdapter

  def override update(dt : float) : EBehResult
    query(beh_tree_eid(owner)) <| $ [es] (var human_net_phys : HumanActor&)
      assume ct = human_net_phys.phys.producedCT
      ct |> human_control_state_set_control_bit(HumanPhysControlType HCT_AIM, true)
    return EBehResult ER_SUCCESS

[beh_node(name="stopAim")]
class StopAim : BehNodeAdapter

  def override update(dt : float) : EBehResult
    query(beh_tree_eid(owner)) <| $ [es] (var human_net_phys : HumanActor&)
      assume ct = human_net_phys.phys.producedCT
      ct |> human_control_state_set_control_bit(HumanPhysControlType HCT_AIM, false)
    return EBehResult ER_SUCCESS

[beh_node(name="canHoldWeaponInVehicle")]
class CanHoldWeaponInVehicle : BehNodeAdapter

  def override update(dt : float) : EBehResult
    return (get_bool(beh_tree_eid(owner), "human_vehicle__canHoldWeapon") ?? false) ? EBehResult ER_SUCCESS : EBehResult ER_FAILED


[beh_node(name="assignStationaryGun")]
class AssignStationaryGun : BehNodeAdapter
  gunEidParam = -1
  assignForTime : float = 5.0

  def override loadFromBlk(data : DataBlock) : void
    gunEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "gunEidParam", ""), 0)
    assignForTime = datablock_getReal(data, "assignForTime", assignForTime)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    if agentEid == INVALID_ENTITY_ID
      return EBehResult ER_FAILED

    let gunEid = EntityId(uint(owner.blackBoard |> datablock_getInt(gunEidParam)))
    if gunEid == INVALID_ENTITY_ID
      return EBehResult ER_FAILED

    var res = EBehResult ER_FAILED
    query(gunEid) <| $ [es] (var stationary_gun__botAssignedEid : EntityId&;
                             var stationary_gun__botAssignedTimeout : float&)
      var alreadyAssigned = false
      let curTime = get_sync_time()
      query(stationary_gun__botAssignedEid) <| $ [es] (isAlive : bool; beh_tree__enabled : bool; possessedByPlr : EntityId)
        if isAlive && beh_tree__enabled && possessedByPlr == INVALID_ENTITY_ID && curTime < stationary_gun__botAssignedTimeout
          if stationary_gun__botAssignedEid != agentEid
            alreadyAssigned = true
      if !alreadyAssigned
        stationary_gun__botAssignedEid = agentEid
        stationary_gun__botAssignedTimeout = curTime + assignForTime
        res = EBehResult ER_SUCCESS
    return res

[beh_node(name="hasStationaryGunAssigned")]
class HasStationaryGunAssigned : BehNodeAdapter
  gunEidParam = -1
  allowAliveGuns : bool = true
  allowDeadGuns : bool = false

  def override loadFromBlk(data : DataBlock) : void
    gunEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "gunEidParam", ""), 0)
    allowAliveGuns = datablock_getBool(data, "allowAliveGuns", allowAliveGuns)
    allowDeadGuns = datablock_getBool(data, "allowDeadGuns", allowDeadGuns)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    if agentEid == INVALID_ENTITY_ID
      return EBehResult ER_FAILED

    let gunEid = EntityId(uint(owner.blackBoard |> datablock_getInt(gunEidParam)))
    if gunEid == INVALID_ENTITY_ID
      return EBehResult ER_FAILED

    var res = EBehResult ER_FAILED
    query(gunEid) <| $ [es] (stationary_gun__botAssignedEid : EntityId;
                             stationary_gun__botAssignedTimeout : float;
                             isAlive : bool)
      if stationary_gun__botAssignedEid == agentEid && get_sync_time() < stationary_gun__botAssignedTimeout
        if (isAlive && allowAliveGuns) || (!isAlive && allowDeadGuns)
          res =  EBehResult ER_SUCCESS
    return res

[beh_node(name="blacklistStationaryGun")]
class BlacklistStationaryGun : BehNodeAdapter
  gunEidParam = -1

  def override loadFromBlk(data : DataBlock) : void
    gunEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "gunEidParam", ""), 0)

  def override update(dt : float) : EBehResult
    let gunEid = EntityId(uint(owner.blackBoard |> datablock_getInt(gunEidParam)))
    if gunEid == INVALID_ENTITY_ID
      return EBehResult ER_FAILED

    query(gunEid) <| $ [es] (var stationary_gun__botsBlacklisted : int&)
      stationary_gun__botsBlacklisted += 1

    return EBehResult ER_SUCCESS


[beh_node(name="attachToStationaryGun")]
class AttachToStationaryGun : BehNodeAdapter
  radius : float = 2.0
  gunEidParam = -1

  def override loadFromBlk(data : DataBlock) : void
    if datablock_find_param(data, "gunEidParam") >= 0
      gunEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "gunEidParam", ""), 0)
    radius = datablock_getReal(data, "radius", radius)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    let gunEid = gunEidParam >= 0 ? EntityId(uint(owner.blackBoard |> datablock_getInt(gunEidParam))) : find_gun_to_attach(agentEid, radius, true)
    if gunEid == INVALID_ENTITY_ID
      return EBehResult ER_FAILED
    sendEvent(gunEid, [[CmdUse requesterEid=agentEid]])
    return EBehResult ER_SUCCESS

[beh_node(name="isAttachedToStationaryGun")]
class IsAttachedToStationaryGun : BehNodeAdapter
  gunEidParam = -1

  def override loadFromBlk(data : DataBlock) : void
    if datablock_find_param(data, "gunEidParam") >= 0
      gunEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "gunEidParam", ""), 0)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    var res = EBehResult ER_FAILED
    query(agentEid) <| $ [es] (human_attached_gun__attachedGunEid : EntityId)
      if gunEidParam >= 0
        let gunEid = EntityId(uint(owner.blackBoard |> datablock_getInt(gunEidParam)))
        if !!human_attached_gun__attachedGunEid && gunEid == human_attached_gun__attachedGunEid
          res = EBehResult ER_SUCCESS
      else
        if !!human_attached_gun__attachedGunEid
          res = EBehResult ER_SUCCESS
    return res

[beh_node(name="detachFromStationaryGun")]
class DetachFromStationaryGun : BehNodeAdapter

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    var attachedGunEid = INVALID_ENTITY_ID
    query(agentEid) <| $ [es] (human_attached_gun__attachedGunEid : EntityId)
      attachedGunEid = human_attached_gun__attachedGunEid
    if attachedGunEid == INVALID_ENTITY_ID
      return EBehResult ER_SUCCESS // already detached
    sendEvent(attachedGunEid, [[CmdUse requesterEid=agentEid]]) // request detach
    return EBehResult ER_SUCCESS


[beh_node(name="findStationaryGun")]
class FindStationaryGun : BehNodeAdapter
  radius : float = 10.0
  posOffset = float3(0.0, 0.0, 0.0)
  posParam = -1

  gunEidOutParam = -1
  gunAITypeOutParam = -1

  extraChecks : bool = false
  rangeAITypes : int2 = int2(0, -1)
  skipAssignedToSelf : bool = false
  skipAssignedToOthers : bool = true
  skipDeadGuns : bool = true
  skipAliveGuns : bool = false
  maxBlacklisted : int = 2
  targetEidParam = -1
  traceTargets : bool = true
  maxTraces : int = 3
  requireEnemySide : bool = false
  requireTargets : int = 0
  hiddenTargets : bool = false
  rangeLimits : float2 =  float2(0, -1)

  def override loadFromBlk(data : DataBlock) : void
    if datablock_find_param(data, "posParam") >= 0
      posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3())
    radius = datablock_getReal(data, "radius", radius)
    posOffset = datablock_getPoint3(data, "posOffset", posOffset)

    if datablock_find_param(data, "gunEidOutParam") >= 0
      gunEidOutParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "gunEidOutParam", ""), 0)
    if datablock_find_param(data, "gunAITypeOutParam") >= 0
      gunAITypeOutParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "gunAITypeOutParam", ""), 0)

    extraChecks = datablock_getBool(data, "extraChecks", extraChecks)
    rangeAITypes = datablock_getIPoint2(data, "rangeAITypes", rangeAITypes)
    skipAssignedToSelf = datablock_getBool(data, "skipAssignedToSelf", skipAssignedToSelf)
    skipAssignedToOthers = datablock_getBool(data, "skipAssignedToOthers", skipAssignedToOthers)
    skipDeadGuns = datablock_getBool(data, "skipDeadGuns", skipDeadGuns)
    skipAliveGuns = datablock_getBool(data, "skipAliveGuns", skipAliveGuns)
    maxBlacklisted = datablock_getInt(data, "maxBlacklisted", maxBlacklisted)
    if datablock_find_param(data, "targetEidParam") >= 0
      targetEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetEidParam", ""), 0)
    traceTargets = datablock_getBool(data, "traceTargets", traceTargets)
    maxTraces = datablock_getInt(data, "maxTraces", maxTraces)
    requireEnemySide = datablock_getBool(data, "requireEnemySide", requireEnemySide)
    requireTargets = datablock_getInt(data, "requireTargets", requireTargets)
    hiddenTargets = datablock_getBool(data, "hiddenTargets", hiddenTargets)
    rangeLimits = datablock_getPoint2(data, "rangeLimits", rangeLimits)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    if agentEid == INVALID_ENTITY_ID
      return EBehResult ER_FAILED

    var playerTeam = -1
    var agentPos = float3()
    if requireEnemySide
      query(agentEid) <| $ [es] (squad_member__playerEid : EntityId; transform : float3x4)
        agentPos = transform[3]
        query(squad_member__playerEid) <| $ [es] (team : int)
          playerTeam = team

    var targetEid = INVALID_ENTITY_ID
    if targetEidParam >= 0
      targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetEidParam)))
      if targetEid == INVALID_ENTITY_ID
        return EBehResult ER_FAILED

    let curTime = get_sync_time()

    var gunAIType = 0
    let gunEid = find_interactable(ecs_hash("interactable"), beh_tree_eid(owner), radius, true) <| $(gun_eid : EntityId)
      if !can_shoot_from_attached_gun(gun_eid)
        return false
      if !extraChecks
        return true

      var filtered = false
      query(gun_eid) <| $ [es] (isAlive : bool = false;
                                specialAIStGunType : int = 0;
                                stationary_gun__botAssignedEid : EntityId = INVALID_ENTITY_ID;
                                stationary_gun__botAssignedTimeout : float = 0.0;
                                stationary_gun__botsBlacklisted : int = 0)
        if (!isAlive && skipDeadGuns) || (isAlive && skipAliveGuns)
          filtered = true
          return
        if stationary_gun__botsBlacklisted >= maxBlacklisted
          filtered = true
          return
        gunAIType = specialAIStGunType
        if gunAIType < rangeAITypes.x || (rangeAITypes.y >= 0 && gunAIType > rangeAITypes.y)
          filtered = true
          return
        let assignedEid = stationary_gun__botAssignedEid
        if !!assignedEid && curTime < stationary_gun__botAssignedTimeout
          if (assignedEid == agentEid && skipAssignedToSelf) || (assignedEid != agentEid && skipAssignedToOthers)
            filtered = true
      if filtered
        return false

      var traced = false
      if !!targetEid && !check_attached_gun_target(gun_eid, targetEid, traceTargets, traced)
        return false

      if requireEnemySide && playerTeam >= 1
        var numPos = 0
        let gunDir = get_attached_gun_ai_aim_to_dir(gun_eid)
        query() <| $ [es(REQUIRE=respbase, REQUIRE_NOT=customRespawnBase)] (active : bool; team : int; transform aka spawn_transform : float3x4; respawnbaseType : string)
          if !active || respawnbaseType != "human" || is_teams_friendly(team, playerTeam)
            return
          let respPos = spawn_transform[3]
          if dot(gunDir, normalize(respPos - agentPos)) > 0.5
            ++numPos
        if numPos <= 0
          return false

      if requireTargets > 0 && !(requireTargets == 1 && !!targetEid)
        var fireRange = MOUNTED_GUN_DEFAULT_FIRE_RANGE
        query(gun_eid) <| $ [es] (mounted_gun__aiFireRange : float2)
          fireRange = mounted_gun__aiFireRange
        let needTargets = requireTargets - (!!targetEid ? 1 : 0)
        var gotTargets = 0
        var leftTraces = maxTraces
        query(agentEid) <| $ [es] (agent_dangers : AgentDangers)
          for danger in agent_dangers.dangers
            if danger.distance < fireRange.x || danger.distance > fireRange.y
              continue
            if !danger.traceable && !(hiddenTargets && is_attached_gun_hidden_target_incoming(gun_eid, danger.eid))
              continue

            let targetOK = check_attached_gun_target(gun_eid, danger.eid, leftTraces > 0, traced)
            if traced
              leftTraces -= 1
            if !targetOK
              continue
            gotTargets += 1
            if gotTargets >= needTargets
              break
        if gotTargets < needTargets
          return false
      return true

    var res = EBehResult ER_FAILED
    query(gunEid) <| $ [es] (transform : float3x4)
      if posParam >= 0
        owner.blackBoard |> set(posParam, transform * posOffset)
      if gunEidOutParam >= 0
        owner.blackBoard |> set(gunEidOutParam, int(uint(gunEid)))
      if gunAITypeOutParam >= 0
        owner.blackBoard |> set(gunAITypeOutParam, gunAIType)
      res = EBehResult ER_SUCCESS
    return res


[beh_node(name="findNextTargetForStationaryGun")]
class FindNextTargetForStationaryGun : BehNodeAdapter
  gunEidParam = -1
  targetEidOutParam = -1
  minTimeInFrustum : float = 2.0
  iterParam = -1
  maxTraces : int = 3

  def override loadFromBlk(data : DataBlock) : void
    gunEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "gunEidParam", ""), 0)
    targetEidOutParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetEidOutParam", ""), 0)
    minTimeInFrustum = datablock_getReal(data, "minTimeInFrustum", minTimeInFrustum)
    iterParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "gunIter", "stGunTgtIter"), 0)
    maxTraces = datablock_getInt(data, "maxTraces", maxTraces)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    if agentEid == INVALID_ENTITY_ID
      return EBehResult ER_FAILED

    let gunEid = EntityId(uint(owner.blackBoard |> datablock_getInt(gunEidParam)))
    if gunEid == INVALID_ENTITY_ID
      return EBehResult ER_FAILED
    if !can_shoot_from_attached_gun(gunEid)
      return EBehResult ER_FAILED

    var iterValue = owner.blackBoard |> datablock_getInt(iterParam)
    var targetEid = INVALID_ENTITY_ID

    let curTime = get_sync_time()

    query(agentEid) <| $ [es] (agent_dangers : AgentDangers)
      let numDangers = length(agent_dangers.dangers)
      if iterValue < 0 || iterValue >= numDangers
        iterValue = 0
      if numDangers <= 0
        return
      let startIterValue = iterValue
      var leftTraces = maxTraces
      var leftDangers = numDangers
      while leftDangers > 0 && leftTraces > 0
        leftDangers -= 1
        let dangerIdx = iterValue
        iterValue = (iterValue + 1) % numDangers
        assume danger = agent_dangers.dangers[dangerIdx]
        if danger.traceable && curTime - danger.inFrustumTime >= minTimeInFrustum
          var traced = false
          let targetOK = check_attached_gun_target(gunEid, danger.eid, true, traced)
          if traced
            leftTraces -= 1
          if targetOK
            targetEid = danger.eid
            break
        if iterValue == startIterValue
          break

    owner.blackBoard |> set(iterParam, iterValue)
    owner.blackBoard |> set(targetEidOutParam, int(uint(targetEid)))

    return !!targetEid ? EBehResult ER_SUCCESS : EBehResult ER_FAILED

[beh_node(name="checkStationaryGunTarget")]
class CheckStationaryGunTarget : BehNodeAdapter
  gunEidParam = -1
  targetEidParam = -1
  traceHit : bool = false

  def override loadFromBlk(data : DataBlock) : void
    gunEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "gunEidParam", ""), 0)
    targetEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetEidParam", ""), 0)
    traceHit = datablock_getBool(data, "traceHit", traceHit)

  def override update(dt : float) : EBehResult
    let gunEid = EntityId(uint(owner.blackBoard |> datablock_getInt(gunEidParam)))
    if gunEid == INVALID_ENTITY_ID
      return EBehResult ER_FAILED
    if !can_shoot_from_attached_gun(gunEid)
      return EBehResult ER_FAILED

    let targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetEidParam)))
    if targetEid == INVALID_ENTITY_ID
      return EBehResult ER_FAILED

    var traced = false
    if !check_attached_gun_target(gunEid, targetEid, traceHit, traced)
      return EBehResult ER_FAILED
    return EBehResult ER_SUCCESS

[beh_node(name="getStationaryGunInfo")]
class GetStationaryGunInfo : BehNodeAdapter
  gunEidParam = -1
  posOffset : float3  = float3(0.0, 0.0, 0.0)
  posOutParam = -1
  gunAITypeOutParam = -1
  lookPosOutParam = -1
  lookRandYawRange : float2 = float2(-1.0, 1.0)
  lookRandPitchRange : float2 = float2(-1.0, 1.0)
  lookRandDistRange : float2 = float2(0.0, 1.0)

  def override loadFromBlk(data : DataBlock) : void
    gunEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "gunEidParam", ""), 0)
    posOffset = datablock_getPoint3(data, "posOffset", posOffset)
    if datablock_find_param(data, "posOutParam") >= 0
      posOutParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posOutParam", ""), float3())
    if datablock_find_param(data, "gunAITypeOutParam") >= 0
      gunAITypeOutParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "gunAITypeOutParam", ""), 0)
    if datablock_find_param(data, "lookPosOutParam") >= 0
      lookPosOutParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "lookPosOutParam", ""), float3())
    lookRandYawRange = datablock_getPoint2(data, "lookRandYawRange", lookRandYawRange)
    lookRandPitchRange = datablock_getPoint2(data, "lookRandPitchRange", lookRandPitchRange)
    lookRandDistRange = datablock_getPoint2(data, "lookRandDistRange", lookRandDistRange)

  def override update(dt : float) : EBehResult
    let gunEid = EntityId(uint(owner.blackBoard |> datablock_getInt(gunEidParam)))
    if gunEid == INVALID_ENTITY_ID
      return EBehResult ER_FAILED

    var hasData = false
    var gunTransform = IDENT_TM
    var gunAIType = 0
    query(gunEid) <| $ [es] (transform : float3x4; specialAIStGunType : int = 0)
      hasData = true
      gunTransform = transform
      gunAIType = specialAIStGunType
    if !hasData
      return EBehResult ER_FAILED

    if posOutParam >= 0
      owner.blackBoard |> set(posOutParam, gunTransform * posOffset)

    if gunAITypeOutParam >= 0
      owner.blackBoard |> set(gunAITypeOutParam, gunAIType)

    if lookPosOutParam >= 0
      let kYaw = rnd_float(lookRandYawRange.x, lookRandYawRange.y)
      let kPitch = rnd_float(lookRandPitchRange.x, lookRandPitchRange.y)
      let kDist = rnd_float(lookRandDistRange.x, lookRandDistRange.y)
      var lookPos = float3()
      if !get_attached_gun_ai_aim_point(lookPos, gunEid, kYaw, kPitch, kDist)
        return EBehResult ER_FAILED
      owner.blackBoard |> set(lookPosOutParam, lookPos)

    return EBehResult ER_SUCCESS

[beh_node(name="isAllyPlayerNear")]
class IsAllyPlayerNear : BehNodeAdapter
  radius : float = 1.0

  def override loadFromBlk(data : DataBlock) : void
    radius = datablock_getReal(data, "radius", radius)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    var isAllyNear = false
    query(agentEid) <| $ [es] (transform aka agent_transform : float3x4; squad_member__playerEid : EntityId)
      var playerTeam = -1
      query(squad_member__playerEid) <| $ [es] (team : int)
        playerTeam = team
      if playerTeam > 0
        let radiusSq = square(radius)
        for_each_entity_in_grid(ecs_hash("humans"), BSphere3(agent_transform[3], radius), GridEntCheck BOUNDING) <| $(that_eid : EntityId)
          if agentEid == that_eid
            return
          query(that_eid) <| $ [es] (transform aka that_transform : float3x4; possessedByPlr : EntityId; beh_tree__enabled : bool)
            if !beh_tree__enabled && distance_sq(agent_transform[3], that_transform[3]) < radiusSq
              query(possessedByPlr) <| $ [es(REQUIRE_NOT=playerIsBot)] (team aka that_team : int)
                if is_teams_friendly(playerTeam, that_team)
                  isAllyNear = true
    return isAllyNear ? EBehResult ER_SUCCESS : EBehResult ER_FAILED


[beh_node(name="passedTimeSinceControlledByPlayer")]
class PassedTimeSinceControlledByPlayer : BehNodeAdapter
  time : float = 5.0

  def override loadFromBlk(var data : DataBlock) : void
    time = data |> datablock_getReal("time", time)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    var timePassed = true
    query(agentEid) <| $ [es] (human_weap__lastTimeInfiniteAmmoEnabled : float = 0.0)
      if human_weap__lastTimeInfiniteAmmoEnabled > 0.0
        timePassed = get_sync_time() > human_weap__lastTimeInfiniteAmmoEnabled + time
    return timePassed ? EBehResult ER_SUCCESS : EBehResult ER_FAILED

[beh_node(name="checkReloadWeapon")]
class CheckReloadWeapon : BehNodeAdapter
  checkOnly : bool = false
  enoughAmmoRatio : float = 0.0

  skipEnemyNearRadius : float = -1.0
  skipEnemyDeltaHeights : float2 = float2(-2.0, 3.0)
  waitReloadFinish : bool = true

  def override loadFromBlk(var data : DataBlock) : void
    checkOnly = data |> datablock_getBool("checkOnly", checkOnly)
    enoughAmmoRatio = data |> datablock_getReal("enoughAmmoRatio", enoughAmmoRatio)

    skipEnemyNearRadius = data |> datablock_getReal("skipEnemyNearRadius", skipEnemyNearRadius)
    skipEnemyDeltaHeights = data |> datablock_getPoint2("skipEnemyDeltaHeights", skipEnemyDeltaHeights)
    waitReloadFinish = data |> datablock_getBool("waitReloadFinish", waitReloadFinish)

  def override update(dt : float) : EBehResult
    let ownerEid = beh_tree_eid(owner)
    let reload = check_human_reload(ownerEid, enoughAmmoRatio)
    if checkOnly
      return reload != 0 ? EBehResult ER_SUCCESS : EBehResult ER_FAILED
    if reload > 0
      return waitReloadFinish ? EBehResult ER_RUNNING : EBehResult ER_SUCCESS
    if reload < 0
      if skipEnemyNearRadius > 1.0 && check_hostile_humans_nearby(ownerEid, skipEnemyNearRadius, skipEnemyDeltaHeights)
        return EBehResult ER_SUCCESS
      query(ownerEid) <| $ [es] (human_weap__currentGunEid : EntityId)
        let atTime = get_sync_time()
        sendEventImmediate(ownerEid, [[CmdRequestReload atTime=atTime, gunEid=human_weap__currentGunEid, isQuick=false]])
      return waitReloadFinish ? EBehResult ER_RUNNING : EBehResult ER_SUCCESS
    return EBehResult ER_SUCCESS

[beh_node(name="decideOnAttackTarget")]
class DecideOnAttackTarget : BehNodeAdapter
  checkOnly : bool = false

  targetEidParam = -1
  targetSeeTimeParam = -1
  targetAcceptTime : float = 0.3

  lastTargetEidParam = -1
  lastTargetSeenParam = -1
  lastTargetTimeParam = -1
  forgetTargetTime : float = 7.5

  hunchLevelParam = -1
  prevHunchTimeParam = -1
  hunchTimeForDist1 = float3(3.0, 5.0, 60.)
  hunchTimeForDist2 = float3(1.0, 2.5, 25.)
  hunchTimeForDist3 = float3(0.5, 1.0, 5.)
  hunchDistDiv12 : float = 0.0
  hunchDistDiv23 : float = 0.0

  stillBackTimeRange = float2(0.4, 0.8)
  stillSideTimeRange = float2(0.2, 0.7)
  turnExactBackChance = 0.5
  turnExactSideChance = 0.8

  followTurnAngleRange = float2(50.0, 70.0)
  sideTurnAngleRange = float2(70.0, 110.0)
  backTurnAngleRange = float2(110.0, 150.0)
  deviateExactAngle : float = 10.0
  backAngle : float = 135.0

  focusBackTimeRange = float2(0.3, 0.5)
  focusSideTimeRange = float2(0.25, 0.4)
  focusAheadTimeRange = float2(0.2, 0.3)
  focusProneAddTimeRange = float2(0.2, 0.5)
  refocusTimeRange = float2(0.1, 0.2)

  stillTimeOutParam = -1
  turnAngleOutParam = -1
  focusTimeOutParam = -1

  def override loadFromBlk(data : DataBlock) : void
    checkOnly = datablock_getBool(data, "checkOnly", checkOnly)

    targetEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetParam", ""), 0)
    targetSeeTimeParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetSeeTimeParam", ""), -1.0)

    lastTargetEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "lastTargetEidParam", "lastTargetEid"), 0)
    lastTargetSeenParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "lastTargetSeenParam", "lastTargetSeen"), false)
    lastTargetTimeParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "lastTargetTimeParam", "lastTargetTime"), 0.0)

    hunchLevelParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "hunchLevelParam", "hunchLevel"), 0.0)
    prevHunchTimeParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "prevHunchTimeParam", "prevHunchTime"), -1.0)
    hunchDistDiv12 = safeinv(hunchTimeForDist1.z - hunchTimeForDist2.z)
    hunchDistDiv23 = safeinv(hunchTimeForDist2.z - hunchTimeForDist3.z)

    followTurnAngleRange *= DEG_TO_RAD
    sideTurnAngleRange *= DEG_TO_RAD
    backTurnAngleRange *= DEG_TO_RAD
    deviateExactAngle *= DEG_TO_RAD
    backAngle *= DEG_TO_RAD

    stillTimeOutParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "stillTimeOutParam", ""), 0.0)
    turnAngleOutParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "turnAngleOutParam", ""), 0.0)
    focusTimeOutParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "focusTimeOutParam", ""), 0.0)

  def override update(dt : float) : EBehResult
    var agent = beh_tree_entity_agent(*owner)

    let targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetEidParam)))
    if targetEid == INVALID_ENTITY_ID
      return EBehResult ER_FAILED

    var lastTargetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(lastTargetEidParam)))
    var lastTargetSeen = owner.blackBoard |> datablock_getBool(lastTargetSeenParam)
    let lastTargetTime = owner.blackBoard |> datablock_getReal(lastTargetTimeParam)

    let curTime = get_sync_time()
    if curTime - lastTargetTime  > forgetTargetTime
      lastTargetEid = INVALID_ENTITY_ID
      lastTargetSeen = false

    let targetSeeTime = owner.blackBoard |> datablock_getReal(targetSeeTimeParam)
    if targetSeeTime >= 0.0 && curTime - targetSeeTime >= targetAcceptTime
      var focusTime = 0.0
      if targetEid != lastTargetEid
        owner.blackBoard |> set(lastTargetEidParam, int(uint(targetEid)))
        focusTime = rnd_float(focusAheadTimeRange.x, focusAheadTimeRange.y)
      elif !lastTargetSeen
        focusTime = rnd_float(refocusTimeRange.x, refocusTimeRange.y)

      query(targetEid) <| $ [es] (human_net_phys : HumanActor)
        if human_net_phys.phys.currentState.isCrawl
          focusTime += rnd_float(focusProneAddTimeRange.x, focusProneAddTimeRange.y)

      if !checkOnly
        owner.blackBoard |> set(lastTargetSeenParam, true)
        owner.blackBoard |> set(lastTargetTimeParam, curTime)

        owner.blackBoard |> set(prevHunchTimeParam, -1.0)
        owner.blackBoard |> set(hunchLevelParam, 0.0)

        owner.blackBoard |> set(stillTimeOutParam, 0.0)
        owner.blackBoard |> set(turnAngleOutParam, 0.0)
        owner.blackBoard |> set(focusTimeOutParam, focusTime)
      return EBehResult ER_SUCCESS

    if !checkOnly
      owner.blackBoard |> set(lastTargetSeenParam, false)

    var hasTargetPos = false
    var targetPos = float3()
    query(targetEid) <| $ [es] (transform : float3x4)
      hasTargetPos = true
      targetPos = transform[3]

    var targetCrawl = false
    query(targetEid) <| $ [es] (human_net_phys : HumanActor)
      targetCrawl = human_net_phys.phys.currentState.isCrawl

    if targetEid == lastTargetEid
      var turnAngle = 0.0
      if hasTargetPos && lastTargetSeen
        let delta = targetPos - agent.pos
        let angleTo = atan2(delta.z, delta.x)
        let angleDir = atan2(agent.shootDir.z, agent.shootDir.x)
        turnAngle = rnd_float(followTurnAngleRange.x, followTurnAngleRange.y)
        if angle_diff(angleDir, angleTo) < 0.0
          turnAngle = -turnAngle
      else
        turnAngle = rnd_float(-PI, PI)

      var focusTime = rnd_float(refocusTimeRange.x, refocusTimeRange.y)
      if targetCrawl
        focusTime += rnd_float(focusProneAddTimeRange.x, focusProneAddTimeRange.y)

      if !checkOnly
        owner.blackBoard |> set(stillTimeOutParam, 0.0)
        owner.blackBoard |> set(turnAngleOutParam, turnAngle)
        owner.blackBoard |> set(focusTimeOutParam, focusTime)
      return EBehResult ER_SUCCESS

    let dist = hasTargetPos ? distance(targetPos, agent.pos) : 0.0
    var time = 0.0
    if dist > hunchTimeForDist1.z
      time = rnd_float(hunchTimeForDist1.x, hunchTimeForDist1.y)
    elif dist > hunchTimeForDist2.z
      let ratio = (dist - hunchTimeForDist2.z) * hunchDistDiv12
      let time1 = rnd_float(hunchTimeForDist1.x, hunchTimeForDist1.y)
      let time2 = rnd_float(hunchTimeForDist2.x, hunchTimeForDist2.y)
      time = lerp(time2, time1, ratio)
    elif dist > hunchTimeForDist3.z
      let ratio = (dist - hunchTimeForDist3.z) * hunchDistDiv23
      let time2 = rnd_float(hunchTimeForDist2.x, hunchTimeForDist2.y)
      let time3 = rnd_float(hunchTimeForDist3.x, hunchTimeForDist3.y)
      time = lerp(time3, time2, ratio)
    else
      time = rnd_float(hunchTimeForDist3.x, hunchTimeForDist3.y)

    let prevHunchTime = owner.blackBoard |> datablock_getReal(prevHunchTimeParam)
    let deltaTime = (prevHunchTime >= 0.0) ? (curTime - prevHunchTime) : 0.0
    let hunchAdd = time > 0.0 ? (deltaTime / time) : 1.0
    let wasHunchLevel = owner.blackBoard |> datablock_getReal(hunchLevelParam)
    var newHunchLevel = min(1.0, wasHunchLevel + hunchAdd)
    if newHunchLevel != wasHunchLevel && !checkOnly
      owner.blackBoard |> set(hunchLevelParam, newHunchLevel)
    if prevHunchTime != curTime && !checkOnly
      owner.blackBoard |> set(prevHunchTimeParam, curTime)

    if newHunchLevel < 1.0
      return EBehResult ER_FAILED // ignore target until hunchLevel >= 1.0

    var stillTime = 0.0
    var turnAngle = 0.0
    var focusTime = 0.0

    if hasTargetPos
      let delta = targetPos - agent.pos
      let angleTo = atan2(delta.z, delta.x)
      let angleDir = atan2(agent.shootDir.z, agent.shootDir.x)

      let angleDiff = angle_diff(angleDir, angleTo)
      if abs(angleDiff) > backAngle
        stillTime = rnd_float(stillBackTimeRange.x, stillBackTimeRange.y)
        focusTime = rnd_float(focusBackTimeRange.x, focusBackTimeRange.y)
        if rnd_float(0.0, 1.0) < turnExactBackChance
          turnAngle = angleDiff + rnd_float(-deviateExactAngle, deviateExactAngle)
        else
          turnAngle = rnd_float(backTurnAngleRange.x, backTurnAngleRange.y)
          if angleDiff < 0.0
            turnAngle = -turnAngle
          if rnd_float(0.0, 1.0) < 0.5
            turnAngle = -turnAngle
      else
        stillTime = rnd_float(stillSideTimeRange.x, stillSideTimeRange.y)
        focusTime = rnd_float(focusSideTimeRange.x, focusSideTimeRange.y)
        if rnd_float(0.0, 1.0) < turnExactSideChance
          turnAngle = angleDiff + rnd_float(-deviateExactAngle, deviateExactAngle)
        else
          turnAngle = rnd_float(sideTurnAngleRange.x, sideTurnAngleRange.y)
          if angleDiff < 0.0
            turnAngle = -turnAngle
          if rnd_float(0.0, 1.0) < 0.5
            turnAngle = -turnAngle
    else
      // fallback (target with no transform?)
      stillTime = 0.0
      turnAngle = rnd_float(-PI, PI)
      focusTime = rnd_float(focusBackTimeRange.x, focusBackTimeRange.y)

    if focusTime > 0.0 && targetCrawl
      focusTime += rnd_float(focusProneAddTimeRange.x, focusProneAddTimeRange.y)

    if lastTargetEid != INVALID_ENTITY_ID
      owner.blackBoard |> set(lastTargetEidParam, int(uint(INVALID_ENTITY_ID))) // hunch searching, not target yet

    if !checkOnly
      newHunchLevel = 0.5
      owner.blackBoard |> set(hunchLevelParam, newHunchLevel)

      owner.blackBoard |> set(stillTimeOutParam, stillTime)
      owner.blackBoard |> set(turnAngleOutParam, turnAngle)
      owner.blackBoard |> set(focusTimeOutParam, focusTime)
    return EBehResult ER_SUCCESS

[beh_node(name="fixLookDirPos")]
class FixLookDirPos : BehNodeAdapter
  posParam = -1
  goodLookDist : float = 5.0

  def override loadFromBlk(var data : DataBlock) : void
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3())
    goodLookDist = data |> datablock_getReal("goodLookDist", goodLookDist)

  def override update(dt : float) : EBehResult
    if posParam < 0
      return EBehResult ER_SUCCESS

    let agentEid = beh_tree_eid(owner)
    var hasFromPos = false
    var fromPos = float3()
    query(agentEid) <| $ [es] (transform : float3x4; walker_agent : EntityAgent)
      fromPos = transform[3]
      fromPos.y = walker_agent.shootFrom[STANCE_STAND].y
      hasFromPos = true
    if !hasFromPos
      return EBehResult ER_SUCCESS

    let toPos = owner.blackBoard |> datablock_getPoint3(posParam)

    var dir = toPos - fromPos
    dir.y = 0.0
    dir = normalize(dir)

    var norm : float3
    var dist = goodLookDist
    if !traceray_normalized(fromPos, dir, dist, norm, ETF_ALL)
      return EBehResult ER_SUCCESS

    let dir2 = float3(dir.z, 0.0, -dir.x)
    let dir2a = normalize(dir + dir2)
    var dist2a = goodLookDist
    if !traceray_normalized(fromPos, dir2a, dist2a, norm, ETF_ALL)
      owner.blackBoard |> set(posParam, fromPos + dir2a * goodLookDist)
      return EBehResult ER_SUCCESS

    let dir3 = float3(-dir.z, 0.0, dir.x)
    let dir3a = normalize(dir + dir3)
    var dist3a = goodLookDist
    if !traceray_normalized(fromPos, dir3a, dist3a, norm, ETF_ALL)
      owner.blackBoard |> set(posParam, fromPos + dir3a * goodLookDist)
      return EBehResult ER_SUCCESS

    var dist2 = goodLookDist
    if !traceray_normalized(fromPos, dir2, dist2, norm, ETF_ALL)
      owner.blackBoard |> set(posParam, fromPos + dir2 * goodLookDist)
      return EBehResult ER_SUCCESS

    var dist3 = goodLookDist
    if !traceray_normalized(fromPos, dir3, dist3, norm, ETF_ALL)
      owner.blackBoard |> set(posParam, fromPos + dir3 * goodLookDist)
      return EBehResult ER_SUCCESS

    if dist < dist2a
      dist = dist2a
      dir = dir2a
    if dist < dist3a
      dist = dist3a
      dir = dir3a
    if dist < dist3
      dist = dist3
      dir = dir3
    if dist < dist2
      dist = dist2
      dir = dir2

    owner.blackBoard |> set(posParam, fromPos + dir * goodLookDist)
    return EBehResult ER_SUCCESS


[beh_node(name="isCurrentWeaponRequiresLongAiming")]
class IsCurrentWeaponRequiresLongAiming : BehNodeAdapter
  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    var result = false
    query(agentEid) <| $ [es] (human_weap__currentGunEid : EntityId)
      query(human_weap__currentGunEid) <| $ [es] (specialAIWeaponType : int)
        if specialAIWeaponType == int(SpecialAIWeaponType ROCKET_LAUNCHERS)
          result = true
        elif specialAIWeaponType == int(SpecialAIWeaponType ANTI_TANK_RIFLES)
          result = true
    return result ? EBehResult ER_SUCCESS : EBehResult ER_FAILED


[beh_node(name="findWeaponSlotWithSpecAIType")]
class FindWeaponSlotWithSpecAIType : BehNodeAdapter
  outParam = -1
  specWeapAIType : int = 0
  minAmmo : int = 0

  def override loadFromBlk(var data : DataBlock) : void
    outParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "toParam", ""), -1)
    minAmmo = datablock_getInt(data, "minAmmo", minAmmo)

    let weapTypeName = datablock_getStr(data, "specAIWeapTypeName", "")
    for i in range(length(SPECIAL_AI_WEAPON_TYPE_NAMES))
      if weapTypeName == SPECIAL_AI_WEAPON_TYPE_NAMES[i]
        specWeapAIType = i

  def override update(dt : float) : EBehResult
    var found = false
    query(beh_tree_eid(owner)) <| $ [es] (human_weap__gunEids : EidList)
      for slot_index, gunEid in iter_range(human_weap__gunEids), human_weap__gunEids
        if minAmmo > 0 && !check_ai_gun_has_min_ammo(gunEid, minAmmo)
          continue
        if !check_ai_gun_has_spec_ai_type(gunEid, specWeapAIType)
          continue
        owner.blackBoard |> set(outParam, slot_index)
        found = true
        break
    return found ? EBehResult ER_SUCCESS : EBehResult ER_FAILED


[beh_node(name="findWeaponSlotWithTag")]
class FindWeaponSlotWithTag : BehNodeAdapter
  outParam : int = -1
  tag : string = ""
  tagHash : uint
  minAmmo : int = 0

  def override loadFromBlk(var data : DataBlock) : void
    outParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "toParam", "preferedWeapon"), -1)
    tag = datablock_getStr(data, "tag", "")
    tagHash = ecs_hash(tag)
    minAmmo = datablock_getInt(data, "minAmmo", minAmmo)

  def override update(dt : float) : EBehResult
    if tag == ""
      return EBehResult ER_FAILED
    var found = false
    query(beh_tree_eid(owner)) <| $ [es] (human_weap__gunEids : EidList)
      for slot_index, gunEid in iter_range(human_weap__gunEids), human_weap__gunEids
        if !has(gunEid, tag, tagHash)
          continue
        if minAmmo > 0 && !check_ai_gun_has_min_ammo(gunEid, minAmmo)
          continue
        owner.blackBoard |> set(outParam, slot_index)
        found = true
        break
    return found ? EBehResult ER_SUCCESS : EBehResult ER_FAILED


[beh_node(name="findPiercableEnemyVehicle")]
class FindPiercableEnemyVehicle : BehNodeAdapter
  inTargerEidParam  = -1

  outTargetEidParam = -1
  outLocalPosParam = -1
  outShootStanceParam = -1
  outShootLocalPosParam = -1

  weaponSlotParam = -1
  shootStances : int3 = int3(2, 2, 2)
  chanceTryNotPenetrate : float = 10.0
  chanceToTargetHumanPlayer : float = 0.2

  ignoreMoving : bool = true
  ignoreMovingSpeed : float = 10.0
  ignoreWithNoCrew : bool = false

  distanceErrorCoef : float = 1.1
  randOffset : float2 = float2(0.35, 0.15)
  withSecondaryChance : float = 0.25

  wideTraceRadius : float = 0.25
  wideTraceOffsetUp : float = 0.0
  wideTraceDistance : float = 5.0

  maxTargetsProcessed : int = 5
  maxPointsPerTarget : int = 5

  runTeam : int = 0
  runTeamEid : EntityId = INVALID_ENTITY_ID
  runAgentTransform : float3x4 = float3x4()
  runAgentShootUpPos : float3 = float3()
  runAgentShootForwPos : float3 = float3()
  runAgentShootDownPos : float3 = float3()
  runShootVel : float = 0.0
  runShellId : int = -1
  runDamageId : int = -1
  runBallisticsId : int = -1
  runBallisticCoef : float = 1.0
  runShootRange : float2 = float2()
  runTicketIdx : int = -1

  runStep : int = 0
  runIndex1 : int = 0
  runIndex2 : int = 0
  runTargetNoPierceCheck : bool = false
  runTargetScore : float = 0.0
  runShootPos : float3 = float3()
  runShootStance : int = -1
  runBestEid : EntityId = INVALID_ENTITY_ID
  runBestScore : float = 0.0
  runBestLocalPos : float3 = float3()
  runBestShootPos : float3 = float3()
  runBestStance : int = -1

  SCAN_TICKET_TIMEOUT = 1.0
  BASE_SCORE_VALUE = 100000.0
  TANK_SCORE_MULTIPLIER = 5.0

  STEP_INIT_CHECK = 1
  STEP_TRACE_TARGETS = 2
  STEP_DONE = 3

  def override loadFromBlk(var data : DataBlock) : void
    if datablock_find_param(data, "inTargerEidParam") >= 0
      inTargerEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "inTargerEidParam", ""), 0)

    outTargetEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outTargetEidParam", ""), 0)
    outLocalPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outLocalPosParam", ""), float3())
    if datablock_find_param(data, "outShootStanceParam") >= 0
      outShootStanceParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outShootStanceParam", ""), 1)
    if datablock_find_param(data, "outShootLocalPosParam") >= 0
      outShootLocalPosParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outShootLocalPosParam", ""), float3())

    weaponSlotParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "weaponSlotParam", ""), -1)
    shootStances = datablock_getIPoint3(data, "shootStances", shootStances)
    if datablock_find_param(data, "shootStance") >= 0
      let stance = datablock_getInt(data, "shootStance", 1)
      shootStances = int3(stance, stance, stance)

    chanceTryNotPenetrate = datablock_getReal(data, "chanceTryNotPenetrate", chanceTryNotPenetrate)

    let KM_H_IN_M_S = 1000.0 / 3600.0
    ignoreMoving = datablock_getBool(data, "ignoreMoving", ignoreMoving)
    ignoreMovingSpeed = datablock_getReal(data, "ignoreMovingSpeed", ignoreMovingSpeed)
    ignoreMovingSpeed *= KM_H_IN_M_S

    ignoreWithNoCrew = datablock_getBool(data, "ignoreWithNoCrew", ignoreWithNoCrew)

    distanceErrorCoef = datablock_getReal(data, "distanceErrorCoef", distanceErrorCoef)

    wideTraceRadius = datablock_getReal(data, "wideTraceRadius", wideTraceRadius)
    wideTraceOffsetUp = datablock_getReal(data, "wideTraceOffsetUp", wideTraceOffsetUp)
    wideTraceDistance = datablock_getReal(data, "wideTraceDistance", wideTraceDistance)

    maxTargetsProcessed = datablock_getInt(data, "maxTargetsProcessed", maxTargetsProcessed)
    maxPointsPerTarget = datablock_getInt(data, "maxPointsPerTarget", maxPointsPerTarget)

    chanceToTargetHumanPlayer = datablock_getReal(data, "chanceToTargetHumanPlayer", chanceToTargetHumanPlayer)

  def override init() : void
    runStep = STEP_INIT_CHECK
    clear_targets()

  def override exit() : void
    runStep = STEP_INIT_CHECK
    clear_targets()

  def clear_targets()
    query(beh_tree_eid(owner)) <| $ [es] (var beh_tree__runEidList : EidList&; var beh_tree__runPosList : Point3List&)
      beh_tree__runEidList |> clear()
      beh_tree__runPosList |> clear()

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    let curTime = get_sync_time()

    if runStep == STEP_INIT_CHECK
      var gunEid = INVALID_ENTITY_ID
      let gunSlot = owner.blackBoard |> datablock_getInt(weaponSlotParam)
      query(agentEid) <| $ [es] (transform : float3x4; human_weap__gunEids : EidList; team : int; walker_agent : EntityAgent)
        if gunSlot >= 0 && gunSlot < length(human_weap__gunEids)
          let checkGunEid = human_weap__gunEids[gunSlot]
          query(checkGunEid) <| $ [es] (combatFiringRange : float2; gun__curShellId : ShellPropIds; combatBallisticCoef : float = 0.0)
            gunEid = checkGunEid
            runShootVel = 50.0
            shell_start_get_props(int(gun__curShellId.shellId)) <| $(shellStartProps : ShellStartProps)
              runShootVel = shellStartProps.speed
            runShellId = int(gun__curShellId.shellId)
            runDamageId = int(gun__curShellId.damageId)
            runBallisticsId = int(gun__curShellId.ballisticsId)
            runBallisticCoef = combatBallisticCoef
            runShootRange = combatFiringRange
            runAgentTransform = transform
            let invTr = inverse(transform)
            runAgentShootUpPos = invTr * walker_agent.shootFrom[shootStances.x]
            runAgentShootForwPos = invTr * walker_agent.shootFrom[shootStances.y]
            runAgentShootDownPos = invTr * walker_agent.shootFrom[shootStances.z]
            runTeam = team
      if gunEid == INVALID_ENTITY_ID
        return EBehResult ER_FAILED

      runTeamEid = INVALID_ENTITY_ID
      find_query() <| $ [es] (eid : EntityId; team__id : int)
        if team__id == runTeam
          runTeamEid = eid
          return true
        return false
      if runTeamEid == INVALID_ENTITY_ID
        return EBehResult ER_FAILED

      runTicketIdx = -1
      query(runTeamEid) <| $ [es] (team_bots__maxFarTracesAtOnce : int;
                                   var team_bots__farTracersEids : EidList&;
                                   var team_bots__farTracersTimeouts : FloatList&)
        for i in iter_range(team_bots__farTracersEids)
          if team_bots__farTracersEids[i] == agentEid || team_bots__farTracersTimeouts[i] < curTime
            team_bots__farTracersEids[i] = agentEid
            team_bots__farTracersTimeouts[i] = curTime + SCAN_TICKET_TIMEOUT
            runTicketIdx = i
            break
        let numAllocated = length(team_bots__farTracersEids)
        if runTicketIdx < 0 && numAllocated < team_bots__maxFarTracesAtOnce
          runTicketIdx = numAllocated
          team_bots__farTracersEids |> push(agentEid)
          team_bots__farTracersTimeouts |> push(curTime + SCAN_TICKET_TIMEOUT)
      if runTicketIdx < 0
        return EBehResult ER_FAILED

      var numTargets = 0
      query(agentEid) <| $ [es] (var beh_tree__runEidList : EidList&)
        beh_tree__runEidList |> clear()

        let findRadius = runShootRange.y * distanceErrorCoef
        let minDistSq = square(safediv(runShootRange.x, distanceErrorCoef))
        let maxDistSq = square(findRadius)
        let maxVelSq = square(ignoreMovingSpeed)

        if inTargerEidParam >= 0
          let targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(inTargerEidParam)))
          if targetEid != INVALID_ENTITY_ID
            beh_tree__runEidList |> push(targetEid)
            ++numTargets

        if numTargets == 0
          for_each_entity_in_grid(ecs_hash("vehicles"), BSphere3(runAgentTransform[3], findRadius), GridEntCheck BOUNDING) <| $(that_eid : EntityId)
            query(that_eid) <| $ [es(REQUIRE_NOT=airplane)] (transform : float3x4; team : int; ai_target : Target)
              if that_eid == agentEid
                return
              if !ai_target.isAlive || team <= 0 || is_teams_friendly(team, runTeam)
                return
              if ignoreMoving && length_sq(ai_target.velocity) > maxVelSq
                return
              let distSq = distance_sq(transform[3], runAgentTransform[3])
              if distSq < minDistSq || distSq > maxDistSq
                return
              if ignoreWithNoCrew && !is_vehicle_with_alive_crew(that_eid)
                return
              beh_tree__runEidList |> push(that_eid)
              ++numTargets

          if rnd_float(0.0, 1.0) < chanceToTargetHumanPlayer
            query(agentEid) <| $ [es] (agent_dangers : AgentDangers)
              for danger in agent_dangers.dangers
                if !danger.traceable || danger.distance < runShootRange.x || danger.distance > runShootRange.y
                  continue
                var dangerOK = false
                query(danger.eid) <| $ [es] (transform : float3x4; isAlive : bool = true; isDowned : bool = false; isInVehicleHidden : bool = false; beh_tree__enabled : bool)
                  let LOOKING_TO_AGENT_COS = 0.8
                  if !beh_tree__enabled && isAlive && !isDowned && !isInVehicleHidden && dot(transform[0], normalize(runAgentTransform[3] - transform[3])) > LOOKING_TO_AGENT_COS
                    dangerOK = true
                if dangerOK
                  beh_tree__runEidList |> push(danger.eid)
                  ++numTargets

        if length(beh_tree__runEidList) > 1
          shuffle(beh_tree__runEidList)
        if length(beh_tree__runEidList) > maxTargetsProcessed
          beh_tree__runEidList |> resize(maxTargetsProcessed)

      if numTargets <= 0
        return EBehResult ER_FAILED
      runStep = STEP_TRACE_TARGETS
      runIndex1 = 0
      runIndex2 = 0
      runBestEid = INVALID_ENTITY_ID
      runBestScore = 0.0
      runBestLocalPos = float3()
      runBestShootPos = float3()
      runBestStance = shootStances.y
      return EBehResult ER_RUNNING

    if runStep == STEP_TRACE_TARGETS
      query(runTeamEid) <| $ [es] (var team_bots__farTracersEids : EidList&;
                                   var team_bots__farTracersTimeouts : FloatList&)
        if runTicketIdx >= 0 && runTicketIdx < length(team_bots__farTracersEids)
          team_bots__farTracersEids[runTicketIdx] = agentEid
          team_bots__farTracersTimeouts |> push(curTime + SCAN_TICKET_TIMEOUT)

      var done = false
      query(agentEid) <| $ [es] (beh_tree__runEidList : EidList; var beh_tree__runPosList : Point3List&)
        let numTargets = length(beh_tree__runEidList)
        while runIndex1 < numTargets
          let targetEid = beh_tree__runEidList[runIndex1]

          if runIndex2 == 0
            query(targetEid) <| $ [es] (transform : float3x4; isTank : Tag const?; dm_ai__pointsYRange : float2 = float2(0.0, 2.0))
              beh_tree__runPosList |> clear()

              let midPoint = transform * float3(0.0, (dm_ai__pointsYRange.x + dm_ai__pointsYRange.y) * 0.5, 0.0)

              let agentDir = normalize(midPoint.xz - runAgentTransform[3].xz)
              runAgentTransform[0] = float3(agentDir.x, 0.0, agentDir.y)
              runAgentTransform[1] = float3(0.0, 1.0, 0.0)
              runAgentTransform[2] = cross(runAgentTransform[0], runAgentTransform[1])

              let midCheckAgentShootPos = runAgentTransform * runAgentShootDownPos
              let midDelta = midPoint - midCheckAgentShootPos
              let midDir = normalize(midDelta)

              let SHOOT_CLING_SIN = 0.05
              if midDir.y > SHOOT_CLING_SIN
                runShootPos = runAgentTransform * runAgentShootUpPos
                runShootStance = shootStances.x
              elif midDir.y < -SHOOT_CLING_SIN
                runShootPos = runAgentTransform * runAgentShootDownPos
                runShootStance = shootStances.z
              else
                runShootPos = runAgentTransform * runAgentShootForwPos
                runShootStance = shootStances.y

              let targetPoint = transform * float3(0.0, dm_ai__pointsYRange.y, 0.0)
              let targetDelta = targetPoint - runShootPos
              let targetDir = normalize(targetDelta)
              let targetDist = length(targetDelta)

              runTargetScore = safediv(BASE_SCORE_VALUE, targetDist)
              if isTank != null
                runTargetScore *= TANK_SCORE_MULTIPLIER

              if runBestEid != INVALID_ENTITY_ID && runBestScore >= runTargetScore
                return

              let noCrew = ignoreWithNoCrew || !is_vehicle_with_alive_crew(targetEid)
              var targetDMAIPoints : array<TargetDMAIPoint>
              pick_target_dm_ai_points(targetDMAIPoints, maxPointsPerTarget, runShootPos, targetEid, noCrew, randOffset, /*allow_from_front*/ false, withSecondaryChance)
              for point in targetDMAIPoints
                push(beh_tree__runPosList, point.worldPos)

              runTargetNoPierceCheck = false
              if empty(beh_tree__runPosList)
                runTargetNoPierceCheck = has(targetEid, "human")
                if !runTargetNoPierceCheck
                  return
                beh_tree__runPosList |> push(midPoint)

              var dist = targetDist
              var norm : float3
              if traceray_normalized(runShootPos, targetDir, dist, norm, ETF_DEFAULT)
                beh_tree__runPosList |> clear()
                return

              let pt1 = runShootPos + float3(0.0, wideTraceOffsetUp, 0.0) - targetDir * wideTraceRadius
              let pt2 = pt1 + targetDir * (wideTraceDistance + wideTraceRadius)
              var queryOut = ShapeQueryOutput()
              if sphere_cast(pt1, pt2, wideTraceRadius, queryOut)
                beh_tree__runPosList |> clear()
                return

          let numPoints = length(beh_tree__runPosList)
          if runIndex2 >= numPoints
            runIndex2 = 0
            ++runIndex1
            break

          let targetHitPos = beh_tree__runPosList[runIndex2]
          ++runIndex2

          query(targetEid) <| $ [es] (transform : float3x4)
            var aimShootHitPos = targetHitPos
            if runTargetNoPierceCheck || trace_pierce_shot(aimShootHitPos, runShootPos, targetHitPos, runShootVel, runShellId, runDamageId, runBallisticsId, runBallisticCoef, targetEid, chanceTryNotPenetrate)
              runIndex2 = numPoints
              if runBestEid == INVALID_ENTITY_ID || runBestScore < runTargetScore
                runBestEid = targetEid
                runBestScore = runTargetScore
                runBestLocalPos = inverse(transform) * aimShootHitPos
                runBestShootPos = inverse(runAgentTransform) * runShootPos
                runBestStance = runShootStance

          if runIndex2 >= numPoints
            runIndex2 = 0
            ++runIndex1
        done = runIndex1 >= numTargets
      if !done
        return EBehResult ER_RUNNING
      runStep = STEP_DONE

    clear_targets()

    if outTargetEidParam >= 0
      owner.blackBoard |> set(outTargetEidParam, int(uint(runBestEid)))
    if outLocalPosParam >= 0
      owner.blackBoard |> set(outLocalPosParam, runBestLocalPos)
    if outShootStanceParam >= 0
      owner.blackBoard |> set(outShootStanceParam, runBestStance)
    if outShootLocalPosParam >= 0
      owner.blackBoard |> set(outShootStanceParam, runBestStance)

    return runBestEid != INVALID_ENTITY_ID ? EBehResult ER_SUCCESS : EBehResult ER_FAILED
