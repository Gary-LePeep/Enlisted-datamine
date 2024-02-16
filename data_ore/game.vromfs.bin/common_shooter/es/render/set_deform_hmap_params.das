require ecs
require AnimV20
require DngDm
require DagorShaders
require DagorMaterials
require DagorMath

[es(tag=render, on_appear)]
def set_deform_hmap_params_es(evt : Event;
                              var animchar_render : AnimcharRendComponent&;
                              vehicle_tracks__surface_pressure_mult : float)
  let paramsVarId = get_shader_variable_id("deform_hmap_pressure", true)
  recreate_material(animchar_render) <| $(mat)
    mat |> set_real_param(paramsVarId, vehicle_tracks__surface_pressure_mult)