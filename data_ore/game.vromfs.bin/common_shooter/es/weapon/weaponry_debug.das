options no_aot
require ecs
require DagorConsole


[console_cmd(name="app.debug_projectiles")]
def force_crosshair_debug_cmd(state : int = -1)
  query() <| $ [es] (var gun__projectileDebug : bool&)
    if state < 0
      gun__projectileDebug = !gun__projectileDebug
    elif state == 0
      gun__projectileDebug = false
    else
      gun__projectileDebug = true


[console_cmd(name="human_weap.forceJamReload")]
def human_weap_force_jam_reload()
  let found = find_query() <| $ [es(REQUIRE=human_weap_reload_force_params)] (var human_weap_reload_force_params__force_jam : bool&)
    human_weap_reload_force_params__force_jam = !human_weap_reload_force_params__force_jam
    console_print("forceJamReload = {human_weap_reload_force_params__force_jam}")
    return true
  if !found
    createEntity("human_weap_reload_force_params") <| $(var init)
      set(init, "human_weap_reload_force_params__force_jam", true)
    console_print("forceJamReload = true")


[console_cmd(name="human_weap.forceAltReload")]
def human_weap_force_alt_reload()
  let found = find_query() <| $ [es(REQUIRE=human_weap_reload_force_params)] (var human_weap_reload_force_params__force_alt : bool&)
    human_weap_reload_force_params__force_alt = !human_weap_reload_force_params__force_alt
    console_print("forceAltReload = {human_weap_reload_force_params__force_alt}")
    return true
  if !found
    createEntity("human_weap_reload_force_params") <| $(var init)
      set(init, "human_weap_reload_force_params__force_alt", true)
    console_print("forceAltReload = true")
