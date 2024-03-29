let scoreSquads = {
  kills = 30
  longRangeKills = 10
  defenseKills = 15
  attackKills = 15
  tankKills = 150
  apcKills = 100
  planeKills = 350
  aiPlaneKills = 265
  captures = 150
  assists = 15
  tankKillAssists = 25
  apcKillAssists = 20
  planeKillAssists = 30
  aiPlaneKillAssists = 25
  reviveAssists = 70
  healAssists = 20
  crewKillAssists = 15
  crewTankKillAssists = 75
  crewApcKillAssists = 50
  crewPlaneKillAssists = 180
  crewAiPlaneKillAssists = 135
  tankKillAssistsAsCrew = 15
  apcKillAssistsAsCrew = 10
  planeKillAssistsAsCrew = 20
  aiPlaneKillAssistsAsCrew = 15
  builtStructures = 4
  builtGunKills = 18
  builtGunKillAssists = 6
  builtGunTankKills = 45
  builtGunApcKills = 30
  builtGunTankKillAssists = 15
  builtGunApcKillAssists = 10
  builtGunPlaneKills = 90
  builtGunAiPlaneKills = 70
  builtGunPlaneKillAssists = 30
  builtGunAiPlaneKillAssists = 25
  builtBarbwireActivations = 6
  builtAmmoBoxRefills = 18
  builtMedBoxRefills = 45
  builtCapzoneFortificationActivations = 6
  builtRallyPointUses = 35
  ownedMobileSpawnUses = 50
  hostedOnSoldierSpawns = 15
  vehicleRepairs = 55
  vehicleExtinguishes = 55
  landings = 100
  barrageBalloonDestructions = 15
  enemyBuiltFortificationDestructions = 6
  enemyBuiltGunDestructions = 55
  enemyBuiltUtilityDestructions = 55

  // penalty
  friendlyHits = -30
  friendlyKills = -70
  friendlyKillsSamePlayer2Add = 0
  friendlyKillsSamePlayer3Add = -70
  friendlyKillsSamePlayer4Add = -140
  friendlyKillsSamePlayer5AndMoreAdd = -280
  friendlyTankHits = -25
  friendlyTankKills = -200
  friendlyApcHits = -20
  friendlyApcKills = -125
  friendlyPlaneHits = -50
  friendlyPlaneKills = -400

  // gun game
  gunGameLevelup = 1000
}

let expSquads = scoreSquads.__merge({
  killed = 60 //suicide does not count
})

let scoreAlone = scoreSquads.__merge({
  // Crew score is zero in no bots mode
  crewKillAssists = 0
  crewTankKillAssists = 0
  crewPlaneKillAssists = 0
  crewAiPlaneKillAssists = 0
  tankKillAssistsAsCrew = 0
  planeKillAssistsAsCrew = 0
  aiPlaneKillAssistsAsCrew = 0
})

let expAlone = scoreAlone.__merge({
  killed = 60 //suicide does not count
  // TODO correct score points needed
})

return {
  expSquads
  expAlone
  scoreSquads
  scoreAlone
}