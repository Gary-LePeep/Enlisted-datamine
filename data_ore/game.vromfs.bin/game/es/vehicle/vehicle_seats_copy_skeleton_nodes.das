require ecs
require ecs.common
require ecs.soa_template
require ecs.safe
require AnimV20
require GeomNodeTree
require enlisted.events_enlisted


[soa_template]
struct CopyNodesMap
  copy_skeleton_nodes__idxFrom : int
  copy_skeleton_nodes__idxTo : int


[soa_def]
def fill_nodes_map_recursive(node_name : string;
                             node_postfix : string;
                             animchar_to;
                             animchar_from;
                             var copy_nodes_map : CopyNodesMap_SOA&)
  assume tree_to = animchar_to.nodeTree
  assume tree_from = animchar_from.nodeTree
  let parentNodeIndexTo = *tree_to |> geomtree_findNodeIndex(node_name)
  let parentNodeIndexFrom = *tree_from |> geomtree_findNodeIndex("{node_name}{node_postfix}")
  if parentNodeIndexFrom >= 0
    copy_nodes_map |> push([[CopyNodesMap
      copy_skeleton_nodes__idxFrom = parentNodeIndexFrom,
      copy_skeleton_nodes__idxTo = parentNodeIndexTo
    ]])

  let childNodesCount = *tree_to |> geomtree_getChildCount(parentNodeIndexTo)
  for i in range(childNodesCount)
    let childNodeIndex = *tree_to |> geomtree_getChildNodeIdx(parentNodeIndexTo, uint(i))
    let childNodeName = *tree_to |> geomtree_getNodeName(childNodeIndex)
    fill_nodes_map_recursive(childNodeName, node_postfix, animchar_to, animchar_from, copy_nodes_map)


[soa_es, es(tag=render, track=human_vehicle__occupiedSeatEid)]
def init_seat_skeleton_nodes_to_copy(evt : Event;
                                     human_anim__vehicleSelected : EntityId;
                                     human_vehicle__occupiedSeatEid : EntityId;
                                     animchar aka copy_to_animchar : AnimcharBaseComponent;
                                     var copy_skeleton_nodes__copyFromEid : EntityId&;
                                     var copyNodesMap : CopyNodesMap_SOA&)
  copyNodesMap |> clear()
  copy_skeleton_nodes__copyFromEid = human_anim__vehicleSelected

  query(human_vehicle__occupiedSeatEid) <| $ [es] (seat__id : int)
    query(human_anim__vehicleSelected) <| $ [es] (animchar aka copy_from_animchar : AnimcharBaseComponent;
                                                  [[shared_comp]] vehicle_seats__seats : Array)
      let seatObj = vehicle_seats__seats[seat__id] as Object
      if seatObj == null
        return

      let nodesPostfix = seatObj?.copySkeletonNodesPostfix ?? ""

      let copySkeletonNodes = get_ecs_array(seatObj, "copySkeletonNodesRecursive")
      if copySkeletonNodes == null
        return

      for node in *copySkeletonNodes
        let nodeName = get_string(node, "")
        fill_nodes_map_recursive(nodeName, nodesPostfix, copy_to_animchar, copy_from_animchar, copyNodesMap)

[soa_es, es(tag=render, track=anim__attachHandsEntity, on_appear)]
def init_anim_recursive_coping_nodes(evt : Event;
                                     anim__attachHandsEntity : EntityId;
                                     anim__attachRecursiveList : StringList;
                                     anim__attachNodePostfix : string = "";
                                     animchar aka copy_to_animchar : AnimcharBaseComponent;
                                     var copy_skeleton_nodes__copyFromEid : EntityId&;
                                     var copyNodesMap : CopyNodesMap_SOA&)
  copyNodesMap |> clear()
  copy_skeleton_nodes__copyFromEid = anim__attachHandsEntity

  query(anim__attachHandsEntity) <| $ [es] (animchar aka copy_from_animchar : AnimcharBaseComponent)
    for node in anim__attachRecursiveList
      fill_nodes_map_recursive(string(node), anim__attachNodePostfix, copy_to_animchar, copy_from_animchar, copyNodesMap)

[es(tag=render, on_appear)]
def init_anim_recursive_coping_nodes_on_create_obj(evt : Event;
                                                   eid : EntityId;
                                                   anim__attachEntityTo : EntityId;
                                                   animchar aka copy_from_animchar : AnimcharBaseComponent)
  query(anim__attachEntityTo) <| $ [soa_blk, es] (anim__attachRecursiveList : StringList;
                                                  anim__attachNodePostfix : string = "";
                                                  animchar aka copy_to_animchar : AnimcharBaseComponent;
                                                  var copy_skeleton_nodes__copyFromEid : EntityId&;
                                                  var copyNodesMap : CopyNodesMap_SOA&)
    copyNodesMap |> clear()
    copy_skeleton_nodes__copyFromEid = eid
    for node in anim__attachRecursiveList
      fill_nodes_map_recursive(string(node), anim__attachNodePostfix, copy_to_animchar, copy_from_animchar, copyNodesMap)


[soa_es, es(tag=render, after=animchar_es, before=slot_attach_init_tms_es)]
def animchar_copy_nodes_from_other_animchar(info : ParallelUpdateFrameDelayed;
                                            animchar__visible : bool;
                                            copy_skeleton_nodes__copyFromEid : EntityId;
                                            copyNodesMap : CopyNodesMap_SOA;
                                            var animchar aka copy_to_animchar : AnimcharBaseComponent;
                                            var animchar_node_wtm : AnimcharNodesMat44;
                                            var animchar_render__root_pos : vec4f&;
                                            invisibleUpdatableAnimchar : Tag const?)
  if !animchar__visible || length(copyNodesMap) == 0
    return
  query(copy_skeleton_nodes__copyFromEid) <| $ [es] (animchar aka copy_from_animchar : AnimcharBaseComponent)
    for node in copyNodesMap
      var newTm : float3x4
      *copy_from_animchar.nodeTree |> geomtree_getNodeWtmScalar(node.copy_skeleton_nodes__idxFrom, newTm)
      *copy_to_animchar.nodeTree |> geomtree_setNodeWtmScalar(node.copy_skeleton_nodes__idxTo, newTm)
    if invisibleUpdatableAnimchar == null
      animchar_copy_nodes(copy_to_animchar, animchar_node_wtm, animchar_render__root_pos)
