from "%enlSqGlob/ui/ui_library.nut" import *

let { rate_mission } = require("%enlist/meta/clientApi.nut")
let { missionRates } = require("%enlist/meta/profile.nut")


let isMissionsRatingOpened = mkWatched(persist, "isMissionsRatingOpened", false)


enum RatesStatus {
  UNDEFINED = 0
  BAN = 1
  DISLIKE = 2
  LIKE = 3
}


let missionRatesCfg = [
  {
    id = "western_front"
    locId = "front/western"
    campaigns = ["normandy", "berlin", "tunisia"]
    limits = {
      [RatesStatus.BAN] = 3,
      [RatesStatus.DISLIKE] = 6,
      [RatesStatus.LIKE] = 9
    }
  }
  {
    id = "eastern_front"
    locId = "front/eastern"
    campaigns = ["stalingrad", "moscow"]
    limits = {
      [RatesStatus.BAN] = 2,
      [RatesStatus.DISLIKE] = 4,
      [RatesStatus.LIKE] = 6
    }
  }
  {
    id = "pacific_front"
    locId = "front/pacific"
    campaigns = ["pacific"]
    limits = {
      [RatesStatus.BAN] = 1,
      [RatesStatus.DISLIKE] = 2,
      [RatesStatus.LIKE] = 3
    }
  }
]


let missionRatesData = Computed(@() missionRates.value.map(@(rateData) rateData.rate))

return {
  isMissionsRatingOpened
  missionRatesData
  RatesStatus
  missionRatesCfg
  callRate = rate_mission
  getMissionRate = @(rates, id) rates?[id] ?? RatesStatus.UNDEFINED
}
