require ecs
require DagorMath
require AnimV20
require GeomNodeTree
require enlisted.events_enlisted

[es(tag=gameClient, on_appear)]
def menu_pose_tm_init_es(evt : Event; animchar : AnimcharBaseComponent; menuPoseNodeName : string; var menuPoseTm : float3x4&)
  identity(menuPoseTm)
  let nodeIdx = geomtree_findNodeIndex(*animchar.nodeTree, menuPoseNodeName)
  if nodeIdx != -1
    var nodeTm : float3x4
    geomtree_getNodeWtmRelScalar(*animchar.nodeTree, nodeIdx, nodeTm)
    menuPoseTm[3] = float3(nodeTm[3].x, nodeTm[3].z, -nodeTm[3].y)

[es(tag=gameClient, after=visual_offset_updater_es, before=slot_attach_init_tms_es, REQUIRE=slot_attach)]
def slot_attach_apply_tm_correction_es(info : ParallelUpdateFrameDelayed;
                                       menuPoseTm : float3x4;
                                       disableUpdate : Tag const?;
                                       slot_attach__slotId : int;
                                       slot_attach__attachedTo : EntityId;
                                       var animchar aka base_animchar : AnimcharBaseComponent;
                                       var animchar_node_wtm : AnimcharNodesMat44?;
                                       var animchar_render__root_pos : vec4f?)
  query(slot_attach__attachedTo) <| $ [es] (animchar aka attachedTo_animchar : AnimcharBaseComponent)
    let slotNodeWtm = animchar_getSlotNodeWtm(attachedTo_animchar, slot_attach__slotId)
    let slotNodeTm = animchar_getAttachmentTm(attachedTo_animchar, slot_attach__slotId)
    if (slotNodeTm != null && slotNodeWtm != null)
      let nodeTm = menuPoseTm * float3x4(*slotNodeTm)
      let resTm =  float3x4(*slotNodeWtm) * nodeTm
      let resTm44 = mat44f(resTm)
      let wtmOfs = *attachedTo_animchar.nodeTree |> geomtree_getWtmOfs()
      animchar_setTmWithOfs(base_animchar, resTm44, wtmOfs)
      animchar_setTmRel(base_animchar, resTm44)
      animchar_act(base_animchar, info.dt, disableUpdate == null)
      if (animchar_node_wtm != null && animchar_render__root_pos != null)
        animchar_copy_nodes(base_animchar, *animchar_node_wtm, *animchar_render__root_pos)
