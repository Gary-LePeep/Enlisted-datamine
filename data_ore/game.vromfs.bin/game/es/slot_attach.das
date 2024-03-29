require ecs
require DagorMath
require AnimV20
require GeomNodeTree
require enlisted.events_enlisted


def slot_attach_init_tms_impl(dt : float;
                              slot_attach__slotId : int;
                              slot_attach__attachedTo : EntityId;
                              var attachmentAnimChar : AnimcharBaseComponent&;
                              disableUpdate : Tag const?;
                              var animchar_node_wtm : AnimcharNodesMat44?;
                              var animchar_render__root_pos : vec4f?;
                              animchar__visible : bool = true;
                              slot_attach__calcAnim : bool = true;
                              slot_attach__rotTm : float3x4 const?)
  let rotTm = slot_attach__rotTm ?? float3x4()
  if slot_attach__slotId < 0 || !slot_attach__attachedTo
    return
  var tmpTm : mat44f
  query(slot_attach__attachedTo) <| $ [es] (animchar : AnimcharBaseComponent;
                                            animchar__actOnDemand : Tag const?;
                                            animchar__updatable : bool = true)
    if animchar__updatable || animchar__actOnDemand != null
      let slotNodeWtm = animchar_getSlotNodeWtm(animchar, slot_attach__slotId)
      let slotNodeTm = animchar_getAttachmentTm(animchar, slot_attach__slotId)
      if slotNodeWtm != null && slotNodeTm != null
        if slot_attach__rotTm != null
          tmpTm = mat44f((float3x4(*slotNodeWtm) * *slot_attach__rotTm) * float3x4(*slotNodeTm))
          var attachTm : float3x4;
          attachTm[0] = float3(tmpTm.col0.x, tmpTm.col0.y, tmpTm.col0.z)
          attachTm[1] = float3(tmpTm.col1.x, tmpTm.col1.y, tmpTm.col1.z)
          attachTm[2] = float3(tmpTm.col2.x, tmpTm.col2.y, tmpTm.col2.z)
          attachTm = attachTm * rotTm
          let pos = tmpTm.col3
          tmpTm = mat44f(attachTm)
          tmpTm.col3 = pos
        else
          tmpTm = mat44f(float3x4(*slotNodeWtm) * float3x4(*slotNodeTm))

      let wtmOfs = *animchar.nodeTree |> geomtree_getWtmOfs()
      animchar_setTmWithOfs(attachmentAnimChar, tmpTm, wtmOfs)
      if animchar__visible
        animchar_act(attachmentAnimChar, dt,  disableUpdate == null && slot_attach__calcAnim)
      else
        animchar_recalc_wtm(attachmentAnimChar)
      if (animchar_node_wtm != null && animchar_render__root_pos != null)
        animchar_copy_nodes(attachmentAnimChar, *animchar_node_wtm, *animchar_render__root_pos);

[es(after=visual_offset_updater_es)]
def slot_attach_init_tms_es(info : ParallelUpdateFrameDelayed)
  //no_animchar_attachments_ecs_query
  query() <| $ [es(REQUIRE_NOT=animchar)] (slot_attach__slotId : int;
                                           slot_attach__attachedTo : EntityId;
                                           var transform : float3x4)
    if slot_attach__slotId < 0 || !slot_attach__attachedTo
      return
    query(slot_attach__attachedTo) <| $ [es] (animchar : AnimcharBaseComponent;
                                              animchar__actOnDemand : Tag const?;
                                              animchar__updatable : bool = true)
      if !animchar__updatable && animchar__actOnDemand != null
        return
      var tmpTm : mat44f
      if animchar_initAttachmentTmAndNodeWtm(animchar, slot_attach__slotId, tmpTm)
        let wtmOfs = *animchar.nodeTree |> geomtree_getWtmOfs()
        transform = float3x4(tmpTm)
        transform[3] += wtmOfs
  broadcastEventImmediate([[SlotAttachUpdateEvent dt=info.dt]]); //require for use different priority on update, with parallel for on first

[es(REQUIRE_NOT=(menuPoseTm, slot_attach__secondaryUpdate), REQUIRE=(slot_attach, slot_attach__slotName), parallel_for=4)]
def slot_attach_first_priority_update_es(info : SlotAttachUpdateEvent;
                                         slot_attach__slotId : int;
                                         slot_attach__attachedTo : EntityId;
                                         var animchar : AnimcharBaseComponent;
                                         disableUpdate : Tag const?;
                                         var animchar_node_wtm : AnimcharNodesMat44?;
                                         var animchar_render__root_pos : vec4f?;
                                         animchar__visible : bool = true;
                                         slot_attach__calcAnim : bool = true;
                                         slot_attach__rotTm : float3x4 const?)
  slot_attach_init_tms_impl(info.dt, slot_attach__slotId, slot_attach__attachedTo, animchar, disableUpdate,
                            animchar_node_wtm, animchar_render__root_pos, animchar__visible, slot_attach__calcAnim,
                            slot_attach__rotTm);


[es(after=slot_attach_first_priority_update_es, REQUIRE_NOT=menuPoseTm, REQUIRE=(slot_attach, slot_attach__secondaryUpdate, slot_attach__slotName))]
def slot_attach_secondary_priority_update_es(info : SlotAttachUpdateEvent;
                                             slot_attach__slotId : int;
                                             slot_attach__attachedTo : EntityId;
                                             var animchar : AnimcharBaseComponent;
                                             disableUpdate : Tag const?;
                                             var animchar_node_wtm : AnimcharNodesMat44?;
                                             var animchar_render__root_pos : vec4f?;
                                             animchar__visible : bool = true;
                                             slot_attach__calcAnim : bool = true;
                                             slot_attach__rotTm : float3x4 const?)
  slot_attach_init_tms_impl(info.dt, slot_attach__slotId, slot_attach__attachedTo, animchar, disableUpdate,
                            animchar_node_wtm, animchar_render__root_pos, animchar__visible, slot_attach__calcAnim,
                            slot_attach__rotTm);
