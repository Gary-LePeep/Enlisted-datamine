options no_aot = true//since this is merely loader
require app
require ecs
require DagorSystem



[init]
def load
  var ok = true

  if app::get_game_name() == "aot" || (get_DAGOR_DBGLEVEL() > 0 && find_index(get_command_line_arguments(), "--das-no-linter") == -1)
    ok = load_das("%danetlibs/dascript_base/linter.das") && ok

  if app::get_game_name() == "aot"
    assert(ok)
