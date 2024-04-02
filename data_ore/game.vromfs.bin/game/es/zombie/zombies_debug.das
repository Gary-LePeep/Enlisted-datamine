options no_aot
require ecs
require DagorConsole
require game.es.net_console_macro

[net_console_cmd(name="zombie.set_cur_wave")]
def zombie_set_cur_wave(cur_wave : int)
  query() <| $ [es] (var entity_spawner__curWaveId : int&)
    entity_spawner__curWaveId = cur_wave


[net_console_cmd(name="zombie.kill_alive")]
def zombie_kill_alive()
  query() <| $ [es(REQUIRE=zombie)] (var hitpoints__hp : float&;
                                     hitpoints__deathHpThreshold = 0.f)
    hitpoints__hp = hitpoints__deathHpThreshold - 1.