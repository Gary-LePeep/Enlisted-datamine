module team_narrator_events shared
require ecs

[event(broadcast)]
struct CmdTeamNarrator
  phrase : string
  replace : bool

[event(broadcast)]
struct CmdNarratorTextEvent
  event : string
  text : string
  myTeamScores : bool
