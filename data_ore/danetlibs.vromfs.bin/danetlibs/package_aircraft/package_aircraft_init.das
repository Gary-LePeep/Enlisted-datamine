options no_aot

require app
require ecs.fs
require ECSGlobalTags


[export]
def load_package_aircraft(base_path : string) : bool
  var ok = true

  if ecs_has_tag("input") || app::get_game_name() == "aot"
    ok = load_sub_folder(base_path, "input") && ok

  if typeinfo(builtin_module_exists TargetSignature)
    ok = load_sub_folder(base_path, "weapons") && ok

  ok = load_sub_folder(base_path, "es") && ok

  return ok