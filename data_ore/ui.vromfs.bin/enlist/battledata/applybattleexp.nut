from "%enlSqGlob/ui/ui_library.nut" import *

let { eventbus_subscribe } = require("eventbus")
let { reward_single_player_mission } = require("%enlist/meta/clientApi.nut")

function chargeExp(data) {
  let { singleMissionRewardId, armyId, squadsExp, soldiersExp } = data
  reward_single_player_mission(singleMissionRewardId, armyId, squadsExp.keys(), soldiersExp.keys())
}

eventbus_subscribe("charge_battle_exp_rewards", @(data) chargeExp(data))
