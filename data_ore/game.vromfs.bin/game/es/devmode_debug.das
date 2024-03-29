options no_aot
require ecs
require DagorDataBlock
require DagorConsole
require DagorSystem
require enlisted.events_enlisted
require ecs.ecs_template


[ecs_template]
struct hero_spawned_once
  hero_spawned_once : Tag

// Please, note that apply_dev_mode_* divided into several es systems to avoid situations
// when the whole dev mode stops to function because of some missing components. This is critical for Sandbox!

[es(REQUIRE=player)]
def apply_dev_mode_resp_inactive_timeout(evt : EventApplyDevMode;
                                         var respawner__respawnWhenInactiveTimeout : float&)
  respawner__respawnWhenInactiveTimeout = 60.0

[es(REQUIRE=player)]
def apply_dev_mode_resp_time(evt : EventApplyDevMode;
                             var respawner__respTime : float&;
                             var respawner__canSpawnMinTime : float&;
                             var respawner__missionStartDelay : float&)
  respawner__respTime = 0.0
  respawner__canSpawnMinTime = 0.0
  respawner__missionStartDelay = 0.0

[es(REQUIRE=player)]
def apply_dev_mode_artillery(evt : EventApplyDevMode;
                             var artillery__baseInterval : float&;
                             var artillery__baseSpawnDelay : float&;
                             var artillery__missionStartDelay : float&)
  artillery__baseInterval = 0.0
  artillery__baseSpawnDelay = 0.0
  artillery__missionStartDelay = 0.0

[es(REQUIRE=player)]
def apply_dev_mode_revive_points(evt : EventApplyDevMode;
                                 var squads__revivePointsAfterDeath : int&)
  squads__revivePointsAfterDeath = 100

[es(REQUIRE=player)]
def apply_dev_mode_suicide_rate(evt : EventApplyDevMode;
                                var squads__suicideRate : float&;
                                var squads__suicideRateThresholdForPenalty : float&)
  squads__suicideRate = 0.0
  squads__suicideRateThresholdForPenalty = 999.0

[es(REQUIRE=player)]
def apply_dev_mode_first_spawn_delays(evt : EventApplyDevMode;
                                      var squads__firstSpawnDelayByType : Object&)
  squads__firstSpawnDelayByType |> set("aircraft", 0.0)
  squads__firstSpawnDelayByType |> set("aircraft_fighter", 0.0)
  squads__firstSpawnDelayByType |> set("aircraft_assault", 0.0)


[es]
def apply_dev_mode_resp_times(evt : EventApplyDevMode;
                              var respTime : int&)
  respTime = 0


[console_cmd(name="sandbox.enable_devmode", hint="Removes different gameplay cooldowns and limitations for easier testing.")]
def enable_devmode_cmd()
  broadcastEvent([[EventApplyDevMode]])



def private is_devmode_enabled_in_settings()
  if get_DAGOR_DBGLEVEL() <= 0
    return false
  return dgs_get_settings() |> datablock_get_block_by_name("debug") |> datablock_getBool("devmodeEnabled", false)

// squads__suicideRate is added to the player on creation in suicide_penalty.das
// we want to apply dev cooldowns only after all components of the player have already appeared
[es(on_appear, REQUIRE=squads__suicideRate)]
def apply_devmode_on_player_got_suicide_penalty(evt : Event)
  if is_devmode_enabled_in_settings()
    broadcastEvent([[EventApplyDevMode]])

[es(on_appear, REQUIRE=player)]
def apply_devmode_on_player_creation(evt : Event)
  if is_devmode_enabled_in_settings()
    broadcastEvent([[EventApplyDevMode]])

def exec_commands_from_block_name(name : string)
  let cmds = dgs_get_settings() |> datablock_get_block_by_name(name)
  if cmds == null
    return
  for i in 0u..cmds.paramCount
    if *cmds |> datablock_getParamType(i) == int(DataBlockParamType TYPE_STRING)
      console_command(*cmds |> datablock_getStr(int(i)))

[es(tag=dev, on_event=EventLevelLoaded)]
def exec_console_commands_on_level_load(evt : Event)
  exec_commands_from_block_name("execute_cmds_on_load")

[es(tag=dev, on_appear, REQUIRE=hero)]
def exec_console_commands_on_fisrt_player_spawn(evt : Event)
  let isFirstHeroSpawn = !(find_query() <| $ [es(REQUIRE=hero_spawned_once)] () => true)
  if !isFirstHeroSpawn
    return
  createEntity("hero_spawned_once")
  exec_commands_from_block_name("execute_cmds_on_spawn")
