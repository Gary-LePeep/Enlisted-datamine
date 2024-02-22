options no_aot
require ecs
require DagorSystem
require debug.logerr_once

def attach_entity_info(parent_eid : EntityId; child_eid : EntityId)
  return "Parent: {parent_eid}<{getEntityTemplateName(parent_eid)}>, Child: {child_eid}<{getEntityTemplateName(child_eid)}>"

[es(tag=dev, on_appear, REQUIRE=slot_attach, REQUIRE_NOT=skeleton_attach__attachedTo)]
def slot_attach_validate_update_order(evt : Event)
  query() <| $ [es(REQUIRE=slot_attach, REQUIRE_NOT=skeleton_attach__attachedTo)] (eid : EntityId; slot_attach__attachedTo : EntityId; slot_attach__secondaryUpdate : Tag const?)
    let isChildSecondary = slot_attach__secondaryUpdate != null
    query(slot_attach__attachedTo) <| $ [es(REQUIRE=slot_attach, REQUIRE_NOT=skeleton_attach__attachedTo)] (slot_attach__secondaryUpdate : Tag const?)
      assume isParentSecondary = slot_attach__secondaryUpdate != null
      if isChildSecondary && isParentSecondary
        logerr_once("Both parent and child attachment is marked as slot_attach__secondaryUpdate! Update order is not defined. {attach_entity_info(slot_attach__attachedTo, eid)}")
      elif !isChildSecondary && !isParentSecondary
        logerr_once("Child attachment is not marked as slot_attach__secondaryUpdate! Update order is not defined. {attach_entity_info(slot_attach__attachedTo, eid)}")
      elif !isChildSecondary && isParentSecondary
        logerr_once("Parent attachment is marked as slot_attach__secondaryUpdate, but the child is not! Update order will be wrong. {attach_entity_info(slot_attach__attachedTo, eid)}")
