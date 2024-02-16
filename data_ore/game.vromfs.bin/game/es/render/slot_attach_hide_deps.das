require ecs
require AnimV20
require game.es.attach_common
require enlisted.events_enlisted

def enable_node_by_name(node_name : string; enable : bool; var animchar_render : AnimcharRendComponent&)
  let nodeId = ronamemapex_get_name_id((*(*animchar_render.sceneInstance).lodsResource).names.node, node_name)
  animchar_render.sceneInstance |> scene_instance_show_node(nodeId, enable)

def update_attach_item_nodes_deps(attach__slotsDeps : Object;
                                  human_equipment__slots : Object;
                                  var animchar_render : AnimcharRendComponent&)
  for group in attach__slotsDeps
    let slotDepsInfo = get_ecs_object(group.value)
    if slotDepsInfo != null
      let depsSlotNames = get_ecs_StringList(*slotDepsInfo, "slots")
      if depsSlotNames == null
        continue

      var itemExist = false
      for slotName in *depsSlotNames
        let itemDeps = get_ecs_object(human_equipment__slots[string(slotName)])
        if itemDeps == null
          continue
        let itemDepsEid = get_Eid(itemDeps, "item") ?? INVALID_ENTITY_ID
        if !!itemDepsEid
          itemExist = true
          break

      let enableNodes = get_ecs_StringList(*slotDepsInfo, "enableNodes")
      let disableNodes = get_ecs_StringList(*slotDepsInfo, "disableNodes")
      if enableNodes != null
        for node in *enableNodes
          enable_node_by_name(string(node), itemExist, animchar_render)
      if disableNodes != null
        for node in *disableNodes
          enable_node_by_name(string(node), !itemExist, animchar_render)

[es(tag=render, on_appear, track=human_equipment__slots)]
def init_attach_slot_deps_es(evt : Event;
                             human_equipment__slots : Object)
  for it in human_equipment__slots
    let obj = get_ecs_object(it.value)
    if obj == null
      continue
    let itemEid = get_Eid(obj, "item") ?? INVALID_ENTITY_ID
    query(itemEid) <| $ [es] (attach__slotsDeps : Object;
                              var animchar_render : AnimcharRendComponent&)
      update_attach_item_nodes_deps(attach__slotsDeps, human_equipment__slots, animchar_render)

[es(tag=render, on_appear)]
def init_attachments_visible_nodes_on_attach_create(evt : Event;
                                                    attach__slotsDeps : Object;
                                                    slot_attach__attachedTo : EntityId;
                                                    var animchar_render : AnimcharRendComponent&)
  let baseParentEid = find_base_attach_parent(slot_attach__attachedTo)
  query(baseParentEid) <| $ [es] (human_equipment__slots : Object)
    update_attach_item_nodes_deps(attach__slotsDeps, human_equipment__slots, animchar_render)