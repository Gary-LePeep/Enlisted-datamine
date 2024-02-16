require ecs
require enlisted.events_enlisted
require team_narrator_net.modules.team_narrator_net_events
require game.utils.team
require game.es.stat_bq_common
require DngNet

[es(tag=server, REQUIRE=bomb_site__operator)]
def bomb_site_net_narrator_planting(evt : EventBombSitePlanting)
  query(evt.bombSiteOperator) <| $ [es] (team : int)
    broadcast_net_event([[CmdNetTeamNarrator team=team, phrase="bombPlanting", replace=false]])

[es(tag=server, REQUIRE=bomb_site__operator)]
def bomb_site_net_narrator_planted(evt : EventBombSitePlanted)
  query(evt.bombSiteOperator) <| $ [es] (team : int)
    broadcast_net_event([[CmdNetTeamNarrator team=team, phrase="bombPlanted", replace=false]])

[es(tag=server, REQUIRE=bomb_site__operator)]
def bomb_site_net_narrator_defusing(evt : EventBombSiteDefusing)
  query(evt.bombSiteOperator) <| $ [es] (team : int)
    broadcast_net_event([[CmdNetTeamNarrator team=team, phrase="bombDefusing", replace=false]])

[es(tag=server, REQUIRE=bomb_site__operator)]
def bomb_site_net_narrator_defused(evt : EventBombSiteDefused)
  query(evt.bombSiteOperator) <| $ [es] (team : int)
    broadcast_net_event([[CmdNetTeamNarrator team=team, phrase="bombDefused", replace=false]])
