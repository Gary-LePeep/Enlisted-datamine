from "%enlSqGlob/ui/ui_library.nut" import *
let decoratorUi = require("decoratorUi.nut")
let { unlockedCampaigns } = require("%enlist/meta/campaigns.nut")
let { configs } = require("%enlist/meta/configs.nut")
let { userstatStats } = require("%enlSqGlob/userstats/userstat.nut")
let { smallOffset } = require("%enlSqGlob/ui/designConst.nut")
let { mkMapsListUi, mkPlayerStatistics } = require("profilePkg.nut")
let { playerRank, markOpenedRank } = require("%enlist/profile/rankState.nut")

let mkPlayerCardUi = @(campaigns) function() {
  return {
    size = flex()
    watch = campaigns
    flow = FLOW_HORIZONTAL
    gap = smallOffset
    children = [
      mkMapsListUi(campaigns)
      mkPlayerStatistics(userstatStats)
    ]
  }
}


return function() {
  let notEmptyStatisticCampaigns = Computed(function(prev) {
    if (prev == FRP_INITIAL)
      prev = []
    let { campaigns = {} } = configs.value?.gameProfile
    let res = []
    foreach (camp in unlockedCampaigns.value) {
      let armiesCamp = campaigns?[camp].armies ?? []
      foreach (army in armiesCamp) {
        let battles = userstatStats.value?.stats["global"][army.id].battles ?? 0
        if (battles > 0) {
          res.append(camp)
          break
        }
      }
    }
    return isEqual(prev, res) ? prev : res
  })

  return {
    size = flex()
    flow = FLOW_VERTICAL
    gap = smallOffset
    onDetach = @() markOpenedRank(playerRank.value?.rank ?? 0)
    children = [
      decoratorUi
      mkPlayerCardUi(notEmptyStatisticCampaigns)
    ]
  }
}
