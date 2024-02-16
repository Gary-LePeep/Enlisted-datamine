require ecs
require soundEvent
require enlisted.events_enlisted
require team_narrator.modules.team_narrator_events
require team_narrator_net.modules.team_narrator_net_events
require team_narrator.modules.team_narrator_common
require game.events_game
require game.utils.hero
require game.utils.team
require app


[es(tag=sound)]
def team_narrator_cmd_team_start(evt : CmdNetTeamNarrator;
                                 team__id : int)
  if team__id == get_local_player_team()
    ecs::query() <| $ [es] (var team_narrator__event : SoundEvent&; var team_narrator__queue : Array&; var team_narrator__history : Object&)
      start_narrator(evt.phrase, is_teams_friendly(evt.team, team__id), evt.replace, team__id, team_narrator__event, team_narrator__queue, team_narrator__history)


[es(tag=sound)]
def team_narrator_start(evt : CmdTeamNarrator; var team_narrator__event : SoundEvent&; var team_narrator__queue : Array&; var team_narrator__history : Object&)
  let isOurTeam = true
  start_narrator(evt.phrase, isOurTeam, evt.replace, get_local_player_team(), team_narrator__event, team_narrator__queue, team_narrator__history)


[es(tag=sound)]
def team_narrator_round_result(evt : EventTeamRoundResult; var team_narrator__event : SoundEvent&; var team_narrator__queue : Array&; var team_narrator__history : Object&)
  let isOurTeam = evt.team == get_local_player_team()
  if isOurTeam
    let replace = true
    start_narrator(evt.isWon ? "win" : "lose", isOurTeam, replace, evt.team, team_narrator__event, team_narrator__queue, team_narrator__history)

[es(tag=sound)]
def team_narrator_low_score(evt : EventTeamLowScore; var team_narrator__event : SoundEvent&; var team_narrator__queue : Array&; var team_narrator__history : Object&)
  let localPlayerTeam = get_local_player_team()
  let isAllies = is_teams_friendly(localPlayerTeam, evt.teamId)
  let replace = false
  start_narrator("loosingScores", isAllies, replace, evt.teamId, team_narrator__event, team_narrator__queue, team_narrator__history)

[es(tag=sound)]
def team_narrator_lose_half_score(evt : EventTeamLoseHalfScore; var team_narrator__event : SoundEvent&; var team_narrator__queue : Array&; var team_narrator__history : Object&)
  let localPlayerTeam = get_local_player_team()
  let isAllies = is_teams_friendly(localPlayerTeam, evt.teamId)
  let replace = false
  start_narrator("loseHalfScores", isAllies, replace, evt.teamId, team_narrator__event, team_narrator__queue, team_narrator__history)
