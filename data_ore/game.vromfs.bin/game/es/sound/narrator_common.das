module narrator_common shared
require ecs
require game.utils.team
require team_narrator.modules.team_narrator_events
require strings


def show_narrator_text_event(event : string; text : string; is_ally : bool)
  if !empty(event)
    broadcastEvent([[CmdNarratorTextEvent event=event, text=text, myTeamScores=is_ally]])


def private try_play_narrator_phrase(phrase : string)
  var isPhraseExist = false
  let heroTeam = get_local_player_team()
  find_query() <| $ [es] (team__id : int; team__narrator : Object)
    if team__id != heroTeam
      return false
    if team__narrator[phrase] != null
      isPhraseExist = true
      broadcastEvent([[CmdTeamNarrator phrase=phrase, replace=false]])
    return true
  return isPhraseExist


def play_narrator_major_event(event : string; text : string; is_ally : bool; phrase : string)
  try_play_narrator_phrase(phrase)
  show_narrator_text_event(event, text, is_ally)


def try_play_narrator_major_event(event : string; text : string; is_ally : bool; phrase : string)
  if try_play_narrator_phrase(phrase)
    show_narrator_text_event(event, text, is_ally)
    return true
  return false
