options no_aot

require ecs
require ecs.fs
require app
require ECSGlobalTags


[export]
def load_weapons(base_path : string) : bool
  var ok = true

  if ecs_has_tag("render") || app::get_game_name() == "aot"
    ok = load_sub_folder(base_path, "main") && ok

  return ok


