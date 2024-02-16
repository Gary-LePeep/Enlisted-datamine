require ecs
require game.utils.team
require team_narrator_net.modules.team_narrator_net_events
require DngNet

[es(tag=server, on_appear)]
def artillery_net_narrator_appear(evt : Event;
                                  artillery_net_narrator__phrase : string;
                                  artillery__offender : EntityId)
  let team = get_int(artillery__offender, "team") ?? TEAM_UNASSIGNED
  broadcast_net_event([[CmdNetTeamNarrator team=team, phrase=artillery_net_narrator__phrase, replace=false]])
