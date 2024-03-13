options no_aot
require ecs
require ecs.common
require AnimV20
require DagorSystem
require GeomNodeTree

[es(tag=render, on_event=ParallelUpdateFrameDelayed)]
def vehicle_seats_effectors_debug(evt : Event;
                                  transform : float3x4;
                                  ik_effector_name : string;
                                  var ik_ffector__relativeTm : float3x4)
  query() <| $ [es(REQUIRE=heroVehicle)] (animchar : AnimcharBaseComponent;
                                          [[shared_comp]] vehicle_seats__seats : Array;
                                          var vehicle_seats__effectors : Array)
    if vehicle_seats__seats.empty
      return
    for i, seat in iter_range(vehicle_seats__seats), vehicle_seats__seats
      let seatObj = get_ecs_object(seat)
      if seatObj == null
        continue

      var obj = getRW_ecs_object(vehicle_seats__effectors[i])
      if obj == null
        logerr("auto effectors works only with inited vehicle_seats__effectors component")
        continue

      let effectors = get_ecs_object(seatObj, "effectors")
      if effectors == null
        continue

      for field in *effectors
        if ik_effector_name == field.key
          let effObj = get_ecs_object(field.value)
          if effObj == null
            continue

          let nodeName = get_string(effObj, "node", "")
          if nodeName == ""
            logerr("incorrect node name for calculating relative matrix")

          let nodeIndex = geomtree_findNodeIndex(*animchar.nodeTree, nodeName)

          var relNodeTm : float3x4
          var tm = transform
          tm[0] = tm[2]
          tm[2] = transform[0]
          geomtree_getNodeWtmScalar(*animchar.nodeTree, nodeIndex, relNodeTm)
          ik_ffector__relativeTm = inverse(relNodeTm) * tm

          using() <| $(var effector_obj : Object)
            set(effector_obj, "node_id", nodeIndex)
            set(effector_obj, "tm", ik_ffector__relativeTm)
            set(*obj, field.key, effector_obj)
