module team_narrator_net_events shared
require ecs

[event(broadcast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdNetTeamNarrator
  team : int
  phrase : string
  replace : bool
