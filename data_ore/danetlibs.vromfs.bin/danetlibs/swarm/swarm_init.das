options no_aot

require app
require ecs.fs
require ECSGlobalTags


[export]
def load_swarm(base_path : string) : bool
  var ok = true

  ok = load_sub_folder(base_path, "main") && ok

  if ecs_has_tag("render") || app::get_game_name() == "aot"
    ok = load_sub_folder(base_path, "render") && ok

  return ok



