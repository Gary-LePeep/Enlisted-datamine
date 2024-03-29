require ecs
require ecs.common
require ecs.safe
require game.es.events
require DagorSystem
require GeomNodeTree
require AnimV20
require enlisted.events_enlisted
require game.es.attach_common

def skeleton_attach_with_remap_parent_impl(eid : EntityId;
                                           skeleton_attach__remapParentSlots : StringList;
                                           human_equipment__slots : Object;
                                           var slot_attach__attachedTo : EntityId&;
                                           var skeleton_attach__attachedTo : EntityId&;
                                           invalid_parent_eid = INVALID_ENTITY_ID)
  for slotName in skeleton_attach__remapParentSlots
    let possibleParent = human_equipment__slots[string(slotName)] ?as Object
    let possibleParentEid = possibleParent?.item ?? INVALID_ENTITY_ID
    if possibleParentEid == eid
      logerr("Entity try to attach to itself. Invalid slots in {skeleton_attach__remapParentSlots} for {eid} {getEntityTemplateName(eid)}")
      return
    if (!!possibleParentEid &&
        possibleParentEid != invalid_parent_eid &&
        has(possibleParentEid, "skeleton_attach__remapAffectSlots"))
      if slot_attach__attachedTo != possibleParentEid

        var list = getRW_ecs_EidList(slot_attach__attachedTo, "attaches_list")
        if list != null // remove eid from list for fix twitching attaches on change
          let idx = find_index(*list, eid)
          if idx > 0
            erase(*list, idx)

        slot_attach__attachedTo = possibleParentEid
        skeleton_attach__attachedTo = possibleParentEid
        sendEventImmediate(eid, [[CmdInitSkeletonAttach]])
      return


def remap_parent_reinit_impl(parent_attached_to : EntityId;
                             skeleton_attach__remapAffectSlots : StringList;
                             invalid_parent_eid = INVALID_ENTITY_ID)
  let baseParentEid = find_base_attach_parent(parent_attached_to)
  query(baseParentEid) <| $ [es] (human_equipment__slots : Object)
    for slotName in skeleton_attach__remapAffectSlots
      let affectSlot = human_equipment__slots[string(slotName)] ?as Object
      let affectEid = affectSlot?.item ?? INVALID_ENTITY_ID
      query(affectEid) <| $ [es(REQUIRE=skeletonAttachInited)] (skeleton_attach__remapParentSlots : StringList;
                                                                var slot_attach__attachedTo aka child_slot_attach__attachedTo : EntityId&;
                                                                var skeleton_attach__attachedTo : EntityId&)
        skeleton_attach_with_remap_parent_impl(affectEid,
                                               skeleton_attach__remapParentSlots,
                                               human_equipment__slots,
                                               child_slot_attach__attachedTo,
                                               skeleton_attach__attachedTo,
                                               invalid_parent_eid)


[es(tag=server, REQUIRE=skeletonAttachInited, on_appear)]
def skeleton_attach_with_remap_parent_reinit(evt : Event;
                                             slot_attach__attachedTo : EntityId;
                                             skeleton_attach__remapAffectSlots : StringList)
  remap_parent_reinit_impl(slot_attach__attachedTo, skeleton_attach__remapAffectSlots)

def skeleton_attach_with_remap_parent_remap_impl(attaches_list : EidList;
                                                 var animchar : AnimcharBaseComponent&;
                                                 var skeleton_attach__skeletonRecalcBranch : UInt8List;
                                                 var skeleton_attach__skeletonRemap : UInt16List)
  assume origNodeTree = *animchar.originalNodeTree
  for attachEid in attaches_list
    query(attachEid) <| $ [es] (skeleton_attach__skipParentsRemapNodes : StringList)
      assume nodeTree = *animchar.nodeTree
      for nodeName in skeleton_attach__skipParentsRemapNodes
        let nodeIdx = nodeTree |> geomtree_findNodeIndex(string(nodeName))
        if nodeIdx < 0
          continue
        geomtree_getNodeTm(nodeTree, nodeIdx) = geomtree_getNodeTm(origNodeTree, nodeIdx)
        let remapedNodesCount = length(skeleton_attach__skeletonRemap)
        for i in range(remapedNodesCount)
          if get_node_no(skeleton_attach__skeletonRemap[i]) == nodeIdx
            skeleton_attach__skeletonRemap |> erase(i)
            skeleton_attach__skeletonRecalcBranch |> push(uint8(nodeIdx))
            break// we have only one require idx!


[es(tag=gameClient, track=attaches_list, REQUIRE=skeleton_attach__skeletonRemap)]
def skeleton_attach_with_remap_parent_reinit_remap_track(evt : Event;
                                                         eid : EntityId;
                                                         attaches_list : EidList;
                                                         skeleton_attach__attachedTo : EntityId;
                                                         var animchar : AnimcharBaseComponent&;
                                                         var skeleton_attach__skeletonRecalcBranch : UInt8List;
                                                         var skeleton_attach__skeletonRemap : UInt16List)
  query(skeleton_attach__attachedTo) <| $ [es(REQUIRE=animchar)] ()
    sendEventImmediate(eid, [[CmdInitSkeletonAttach]])
  skeleton_attach_with_remap_parent_remap_impl(attaches_list, animchar,
                                               skeleton_attach__skeletonRecalcBranch,
                                               skeleton_attach__skeletonRemap)


[es(tag=gameClient, track=skeleton_attach__attachedTo, REQUIRE=(skeleton_attach__skeletonRemap, skeleton_attach__remapParentSlots))]
def skeleton_attach_with_remap_parent_reinit_attach_track(evt : Event;
                                                          eid : EntityId;
                                                          skeleton_attach__attachedTo : EntityId)
  query(skeleton_attach__attachedTo) <| $ [es(REQUIRE=animchar)] ()
    sendEventImmediate(eid, [[CmdInitSkeletonAttach]])

[es(tag=gameClient, on_appear, after=(skeleton_attach_init_es, skeleton_attach_reinit_es), REQUIRE=skeleton_attach__skeletonRemap)]
def skeleton_attach_with_remap_parent_reinit_remap_init(evt : Event;
                                                        attaches_list : EidList;
                                                        var animchar : AnimcharBaseComponent&;
                                                        var skeleton_attach__skeletonRecalcBranch : UInt8List;
                                                        var skeleton_attach__skeletonRemap : UInt16List)
  skeleton_attach_with_remap_parent_remap_impl(attaches_list, animchar,
                                               skeleton_attach__skeletonRecalcBranch,
                                               skeleton_attach__skeletonRemap)

[es(tag=server, REQUIRE=skeletonAttachInited, on_disappear)]
def skeleton_attach_with_remap_parent_disappear(evt : Event;
                                                eid : EntityId;
                                                slot_attach__attachedTo : EntityId;
                                                skeleton_attach__remapAffectSlots : StringList)
  remap_parent_reinit_impl(slot_attach__attachedTo, skeleton_attach__remapAffectSlots, eid)


[es(tag=server, on_appear, REQUIRE=skeletonAttachInited, track=slot_attach__attachedTo)]
def skeleton_attach_with_remap_parent(evt : Event;
                                      eid : EntityId;
                                      skeleton_attach__remapParentSlots : StringList;
                                      var slot_attach__attachedTo : EntityId&;
                                      var skeleton_attach__attachedTo : EntityId&)
  let baseParentEid = find_base_attach_parent(slot_attach__attachedTo)
  query(baseParentEid) <| $ [es] (human_equipment__slots : Object)
    skeleton_attach_with_remap_parent_impl(eid,
                                           skeleton_attach__remapParentSlots,
                                           human_equipment__slots,
                                           slot_attach__attachedTo,
                                           skeleton_attach__attachedTo)
