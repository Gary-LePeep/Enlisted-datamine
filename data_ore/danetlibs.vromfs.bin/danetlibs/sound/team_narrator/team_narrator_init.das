options no_aot

require app
require ecs.fs
require ECSGlobalTags


[export]
def load_team_narrator(base_path : string) : bool
  var ok = true

  if ecs_has_tag("sound") || app::get_game_name() == "aot"
    ok = load_sub_folder(base_path, "modules") && ok
    ok = load_sub_folder(base_path, "es") && ok

  return ok



