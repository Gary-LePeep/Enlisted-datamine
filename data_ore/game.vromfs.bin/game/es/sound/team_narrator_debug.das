options no_aot
require ecs
require DagorConsole
require team_narrator.modules.team_narrator_events
require team_narrator_net.modules.team_narrator_net_events
require game.utils.team
require soundSystem
require DngNet


[console_cmd(name="team_narrator.local_team")]
def team_narrator_debug_console_narrator_start()
  sound_debug("local player team id is {get_local_player_team()}")


[console_cmd(name="team_narrator.cmd")]
def team_narrator_debug_console_narrator_start(phrase : string)
  broadcastEvent([[CmdTeamNarrator phrase=phrase, replace=false]])


[console_cmd(name="team_narrator.net_cmd")]
def team_narrator_debug_console_narrator_team_start(team : int; phrase : string)
  sound_debug("local player team id is {get_local_player_team()}")
  broadcast_net_event([[CmdNetTeamNarrator team=team, phrase=phrase, replace=false]])


[console_cmd(name="team_narrator.player_team_net_cmd")]
def team_narrator_debug_console_narrator_player_team_start(phrase : string)
  broadcast_net_event([[CmdNetTeamNarrator team=get_local_player_team(), phrase=phrase, replace=false]])


[console_cmd(name="team_narrator.enemy_team_net_cmd")]
def team_narrator_debug_console_narrator_enemy_team_start(phrase : string)
  let heroTeamId = get_local_player_team()
  find_query() <| $ [es] (team__id : int)
    if team__id != heroTeamId && team__id != TEAM_UNASSIGNED
      broadcast_net_event([[CmdNetTeamNarrator team=team__id, phrase=phrase, replace=false]])
      return true
    return false
