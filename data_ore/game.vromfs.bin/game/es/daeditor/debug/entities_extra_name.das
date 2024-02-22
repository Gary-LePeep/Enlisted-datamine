require ecs
require ecs.ecs_quirrel
require danetlibs.imgui_daeditor.imgui.daEditor.ecs_inspectors_common
require debugapi


[quirrel_bind(module_name="das.daeditor")]
def get_entity_extra_name(eid : EntityId)
  var extraName = ""
  query(eid) <| $ [es] (ri_extra__name : string = "";
                        floatingRiGroup__resName : string = "";
                        ri_gpu_object__name : string = "";
                        groupName : string = "")
    let compsUsedAsExtraName = [[auto
      ri_extra__name;
      floatingRiGroup__resName;
      ri_gpu_object__name;
      groupName
    ]]
    // select first non empty one
    for comp in compsUsedAsExtraName
      if comp != ""
        extraName = comp
        return

  return extraName

def get_entity_extra_name_out(eid : EntityId; var out_string : string?)
  *out_string = get_entity_extra_name(eid)

[init, export]
def init_entity_extra_name_getter()
  unsafe
    lock_debug_agent() <| $()
      start_ecs_inspectors_agent()
      if not_in_ecs_inspectors_context() && !is_in_aot()
        set_entity_name_getter(@@get_entity_extra_name_out, this_context())
