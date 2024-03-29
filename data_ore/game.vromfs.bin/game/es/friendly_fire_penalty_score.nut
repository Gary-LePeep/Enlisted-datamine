import "%dngscripts/ecs.nut" as ecs
let calcScoringPlayerScore = require("%scripts/game/utils/calcPlayerScore.nut")
let { isNoBotsMode } = require("%enlSqGlob/missionType.nut")

let friendlyFireKickQuery = ecs.SqQuery("friendlyFireKickQuery", { comps_ro = [["game_option__friendlyFireKick", ecs.TYPE_BOOL]] })

let getFriendlyFireOpt = @() friendlyFireKickQuery.perform(@(_eid, comp) comp.game_option__friendlyFireKick) ?? true

ecs.register_es("count_friendly_fire_penalty", {
    function onChange(_, comp) {
      if (getFriendlyFireOpt())
        comp["scoring_player__friendlyFirePenalty"] = calcScoringPlayerScore(comp, isNoBotsMode())
    }
  },
  { comps_track = [
      ["scoring_player__friendlyHits", ecs.TYPE_INT],
      ["scoring_player__friendlyKills", ecs.TYPE_INT],
      ["scoring_player__friendlyKillsSamePlayer2Add", ecs.TYPE_INT],
      ["scoring_player__friendlyKillsSamePlayer3Add", ecs.TYPE_INT],
      ["scoring_player__friendlyKillsSamePlayer4Add", ecs.TYPE_INT],
      ["scoring_player__friendlyKillsSamePlayer5AndMoreAdd", ecs.TYPE_INT],
      ["scoring_player__friendlyTankHits", ecs.TYPE_INT],
      ["scoring_player__friendlyTankKills", ecs.TYPE_INT],
      ["scoring_player__friendlyApcHits", ecs.TYPE_INT],
      ["scoring_player__friendlyApcKills", ecs.TYPE_INT],
      ["scoring_player__friendlyPlaneHits", ecs.TYPE_INT],
      ["scoring_player__friendlyPlaneKills", ecs.TYPE_INT],
    ],
    comps_rw = [
      ["scoring_player__friendlyFirePenalty", ecs.TYPE_INT],
    ]
  },
  { tags="server"}
)