require ecs
require AnimV20
require DngDm
require DagorShaders
require DagorMaterials

[es(tag=render, on_appear, REQUIRE=cockpitEntity)]
def init_cockpit_material_es(evt : Event;
                             var animchar_render : AnimcharRendComponent&;
                             cockpit__simplifiedRender : bool = false)
  let cockpitVarId = get_shader_variable_id("simplified_vehicle_cockpit_render", false)
  recreate_material(animchar_render) <| $(mat)
    mat |> set_int_param(cockpitVarId, cockpit__simplifiedRender ? 1 : 0)