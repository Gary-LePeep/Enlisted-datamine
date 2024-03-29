require ecs
require app
require ecs.common
require game.es.events
require AnimV20
require vehicle
require math.base
require game.es.vehicle.vehicle_events
require enlisted.events_enlisted
require DagorSystem
require GeomNodeTree
require EffectorData

[es(tag=render, on_appear)]
def vehicle_seats_effectors_init(evt : Event;
                                 eid : EntityId;
                                 animchar : AnimcharBaseComponent;
                                 [[shared_comp]] vehicle_seats__seats : Array;
                                 var vehicle_seats__effectors : Array)
  if vehicle_seats__seats.empty
    return
  for seat in vehicle_seats__seats
    // get object seat
    let seatObj = get_ecs_object(seat)
    if seatObj == null
      return

    push_to_array(vehicle_seats__effectors) <| $(var obj : Object)
      let effectors = get_ecs_object(seatObj, "effectors")
      if effectors == null
        return
      for field in *effectors
        let nodeValue = get_string(field.value, "")
        if nodeValue != ""
          let index = geomtree_findNodeIndex(*animchar.nodeTree, nodeValue)
          if index < 0
            logerr("can't find node index for {field.key} equal {nodeValue} in {eid}<{getEntityTemplateName(eid)}>")
            continue
          using() <| $(var effector_obj : Object)
            set(effector_obj, "node_id", index)
            set(obj, field.key, effector_obj)
        else
          let effectorObj = get_ecs_object(field.value)
          if effectorObj != null
            let nodeTm = get_TMatrix(effectorObj, "rel_tm")
            if nodeTm != null
              let nodeName = get_string(effectorObj, "node", "") // if node doesn't set in config we use root node for calculate effectors
              var nodeIndex = 0
              if nodeName != ""
                nodeIndex = geomtree_findNodeIndex(*animchar.nodeTree, nodeName)
              if nodeIndex < 0
                logerr("can't find node index for {field.key} equal {nodeName} in {eid}<{getEntityTemplateName(eid)}>")
                continue
              using() <| $(var effector_obj : Object)
                set(effector_obj, "node_id", nodeIndex)
                set(effector_obj, "tm", *nodeTm)
                set(obj, field.key, effector_obj)


[es(tag=render, on_appear, track=seat__ownerEid)]
def human_init_vehicle_auto_effectors(evt : Event;
                                      seat__ownerEid : EntityId;
                                      vehicle_seats_auto_effectors__inited : bool;
                                      var vehicle_seats_auto_effectors__initAtTime : float&;
                                      effectors__morphStateTime : float = 1.0)
  if vehicle_seats_auto_effectors__inited
    return
  if !!seat__ownerEid
    if !(get_bool(seat__ownerEid, "isInVehicleHidden") ?? true)
      vehicle_seats_auto_effectors__initAtTime = get_sync_time() + effectors__morphStateTime
      addSubTemplate(seat__ownerEid, "effectors_initializer")
  else
    vehicle_seats_auto_effectors__initAtTime = -1.

[es(tag=render, on_appear, track=human_vehicle__isHoldingGunPassenger)]
def human_init_soldier_vehicle_auto_effectors(evt : Event;
                                              eid : EntityId;
                                              isInVehicleHidden : bool;
                                              human_vehicle__isHoldingGunPassenger : bool;
                                              human_vehicle__occupiedSeatEid : EntityId)
  query(human_vehicle__occupiedSeatEid) <| $ [es] (vehicle_seats_auto_effectors__inited : bool;
                                                   var vehicle_seats_auto_effectors__initAtTime : float&;
                                                   effectors__morphStateTime : float = 1.0)
    if vehicle_seats_auto_effectors__inited
      return
    if !isInVehicleHidden
      if !human_vehicle__isHoldingGunPassenger
        vehicle_seats_auto_effectors__initAtTime = get_sync_time() + effectors__morphStateTime
        addSubTemplate(eid, "effectors_initializer")
      else
        vehicle_seats_auto_effectors__initAtTime = -1.
        removeSubTemplate(eid, "effectors_initializer")

[es(tag=render, on_appear, track=seats_hatch_nodes__openPos)]
def human_hatch_vehicle_auto_effectors(evt : Event;
                                       seats_hatch_nodes__openPos : float;
                                       seat__ownerEid : EntityId;
                                       vehicle_seats_auto_effectors__inited : bool;
                                       var vehicle_seats_auto_effectors__initAtTime : float&;
                                       effectors__morphStateTime : float = 1.0)
  if vehicle_seats_auto_effectors__inited
    return
  if !!seat__ownerEid && !(get_bool(seat__ownerEid, "isInVehicleHidden") ?? true) && !(get_bool(seat__ownerEid, "human_vehicle__isHoldingGunPassenger") ?? false)
    if seats_hatch_nodes__openPos ==  1.
      vehicle_seats_auto_effectors__initAtTime = get_sync_time() + effectors__morphStateTime
      addSubTemplate(seat__ownerEid, "effectors_initializer")
    else
      vehicle_seats_auto_effectors__initAtTime = -1.
      removeSubTemplate(seat__ownerEid, "effectors_initializer")

[es(tag=render, after=(human_anim_es, animchar_es))]
def human_vehicle_init_auto_effectors(evt : ParallelUpdateFrameDelayed;
                                      eid : EntityId;
                                      seat__id : int;
                                      seat__ownerEid : EntityId;
                                      seat__vehicleEid : EntityId;
                                      vehicle_seats_auto_effectors__initAtTime : float&;
                                      seats_attach_nodes__nodeId : int;
                                      vehicle_seats_auto_effectors__effectorNames : StringList;
                                      vehicle_seats_auto_effectors__humanNodes : StringList;
                                      vehicle_seats_auto_effectors__vehicleAttachNodes : StringList;
                                      var vehicle_seats_auto_effectors__inited : bool&;
                                      seats_hatch_nodes__isValid = false;
                                      seats_hatch_nodes__openPos = -1.)
  if !seat__ownerEid || vehicle_seats_auto_effectors__inited || vehicle_seats_auto_effectors__initAtTime < 0.f || vehicle_seats_auto_effectors__initAtTime > evt.curTime
    return
  if seats_hatch_nodes__isValid && seats_hatch_nodes__openPos != 1.
    return
  query(seat__ownerEid) <| $ [es(REQUIRE=animchar__considerAsVisible)] (animchar aka owner_animchar : AnimcharBaseComponent;
                                                                        human_vehicle__occupiedSeatEid : EntityId;
                                                                        human_vehicle__isHoldingGunPassenger : bool;
                                                                        isInVehicleHidden : bool)
    if human_vehicle__occupiedSeatEid != eid || isInVehicleHidden || human_vehicle__isHoldingGunPassenger
      return
    query(seat__vehicleEid) <| $ [es] (animchar aka vehicle_animchar : AnimcharBaseComponent;
                                       var vehicle_seats__effectors : Array)
      let autoEffectorsCount = length(vehicle_seats_auto_effectors__effectorNames)
      if length(vehicle_seats_auto_effectors__humanNodes) != autoEffectorsCount || length(vehicle_seats_auto_effectors__vehicleAttachNodes) != autoEffectorsCount
        logerr("incorrect nodes set in vehicle_seats_auto_effectors__humanNodes in {eid}<{getEntityTemplateName(eid)}>")
        return
      var effectors = getRW_ecs_object(vehicle_seats__effectors[seat__id])
      if effectors == null
        logerr("auto effectors works only with inited vehicle_seats__effectors component")
        return

      vehicle_seats_auto_effectors__inited = true
      removeSubTemplate(seat__ownerEid, "effectors_initializer")
      for effName, effRelNode, effNode in vehicle_seats_auto_effectors__effectorNames, vehicle_seats_auto_effectors__vehicleAttachNodes, vehicle_seats_auto_effectors__humanNodes

        var effRelNodeId = seats_attach_nodes__nodeId
        if effRelNode != ""
          let relNode = geomtree_findNodeIndex(*animchar.nodeTree, string(effRelNode))
          if relNode >= 0
            effRelNodeId = relNode
        if effRelNodeId < 0
          return

        if get_ecs_object(*effectors, string(effName)) != null
          continue

        let index = geomtree_findNodeIndex(*owner_animchar.nodeTree, string(effNode))
        if index < 0
          logerr("can't find node index {effNode} in {eid}<{getEntityTemplateName(eid)}>")
          continue

        var nodeWtm : float3x4
        geomtree_getNodeWtmScalar(*owner_animchar.nodeTree, index, nodeWtm)

        var relNodeTm : float3x4
        geomtree_getNodeWtmScalar(*vehicle_animchar.nodeTree, effRelNodeId, relNodeTm)

        let relTM = inverse(relNodeTm) * nodeWtm
        using() <| $(var effector_obj : Object)
          set(effector_obj, "node_id", effRelNodeId)
          set(effector_obj, "tm", relTM)
          set(*effectors, string(effName), effector_obj)

[es(tag=render, before=before_animchar_update_sync, after=(human_anim_es, vehicle_seats_hatch_es))]
def human_vehicle_effectors(info : ParallelUpdateFrameDelayed;
                            animchar : AnimcharBaseComponent;
                            vehicle_seats__effectors : Array;
                            vehicle_seats__seatEids : EidList;
                            transform : float3x4)
  if vehicle_seats__effectors.empty
    return
  let vehicleTm = transform
  var vehicleRootTm : float3x4
  geomtree_getNodeWtmRelScalar(*animchar.nodeTree, 0, vehicleRootTm)
  for seatOwnerNo, seatEid in iter_range(vehicle_seats__seatEids), vehicle_seats__seatEids
    let ownerEid = get_Eid(seatEid, "seat__ownerEid") ?? INVALID_ENTITY_ID
    query(ownerEid) <| $ [es] (var animchar_effectors__effectorsState : Object;
                               transform : float3x4;
                               isInVehicle : bool;
                               human_vehicle__isHoldingGunPassenger : bool;
                               isInVehicleHidden : bool)
      if !isInVehicle || isInVehicleHidden
        return
      let effectors = get_ecs_object(vehicle_seats__effectors[seatOwnerNo])
      if effectors == null
        return
      for field in *effectors
        let effectorName = field.key
        var effector = getNullableRW_EffectorData(animchar_effectors__effectorsState, effectorName)

        if effector == null
          continue
        if human_vehicle__isHoldingGunPassenger
          effector.weight = 0.
          continue

        effector.weight = 1.
        if (get_bool(seatEid, "seats_hatch_nodes__isValid") ?? false) && !(get_bool(seatEid, "seats_hatch_effectors__useInSeat") ?? false)
          let hatchProgress = get_float(seatEid, "seats_hatch_nodes__openPos") ?? 0.
          effector.weight = hatchProgress == 1.0 ? 1. : 0.

        let vehicleWofs = geomtree_calc_optimal_wofs(vehicleTm[3])
        let d_wofs = vehicleWofs - geomtree_calc_optimal_wofs(transform[3])
        var vehicleLocalWtm = vehicleTm
        vehicleLocalWtm[3] = vehicleTm[3] - vehicleWofs
        let effectorObj = get_ecs_object(*effectors, effectorName)
        if effectorObj != null
          let effectorNodeIdx = get_int(*effectorObj, "node_id") ?? -1
          geomtree_getNodeWtmRelScalar(*animchar.nodeTree, effectorNodeIdx, effector.wtm)
          let relTm = get_TMatrix(*effectorObj, "tm")
          if relTm != null
            effector.wtm = effector.wtm * (*relTm)
          effector.wtm = vehicleLocalWtm * (inverse(vehicleRootTm) * effector.wtm)
          effector.position = effector.wtm[3] + d_wofs
          effector.wtm[3] = effector.position

[es(tag=render, track=seat__ownerEid)]
def clear_effectors_on_seat_change(evt : Event; seat__ownerEid : EntityId)
  query(seat__ownerEid) <| $ [es] (var animchar_effectors__effectorsState : Object)
    for effName in animchar_effectors__effectorsState
      var effector = getNullableRW_EffectorData(animchar_effectors__effectorsState, effName.key)
      if effector != null
        effector.weight = 0f

[es(tag=render, track=isInVehicle, REQUIRE=isInVehicle)]
def clear_effectors_on_vehicle_exit(evt : Event; var animchar_effectors__effectorsState : Object)
  for effName in animchar_effectors__effectorsState
    var effector = getNullableRW_EffectorData(animchar_effectors__effectorsState, effName.key)
    if effector != null
      effector.weight = 0f
