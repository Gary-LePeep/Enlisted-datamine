from "%enlSqGlob/ui/ui_library.nut" import *

let { bindSquadROVar } = require("%enlist/squad/squadManager.nut")
let { curArmy, curCampaign } = require("%enlist/soldiers/model/state.nut")
let { matchRandomTeam } = require("%enlist/quickMatch.nut")
let { currentGameModeId } = require("%enlist/gameModes/gameModeState.nut")
let { unlockedCampaigns } = require("%enlist/meta/campaigns.nut")
let { allArmiesTiers } = require("%enlist/soldiers/armySquadTier.nut")

bindSquadROVar("curArmy", curArmy)
bindSquadROVar("curCampaign", curCampaign)
bindSquadROVar("isTeamRandom", matchRandomTeam)
bindSquadROVar("gameModeId", currentGameModeId)
bindSquadROVar("unlockedCampaigns", unlockedCampaigns)
bindSquadROVar("armiesTiers", allArmiesTiers)
