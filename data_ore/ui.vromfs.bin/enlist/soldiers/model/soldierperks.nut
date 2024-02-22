from "%enlSqGlob/ui/ui_library.nut" import *

let u = require("%sqstd/underscore.nut")
let { curArmiesList, getSoldiersByArmy, curCampSquads, chosenSquadsByArmy, curCampaign
} = require("state.nut")
let { getLinkedSquadGuid } = require("%enlSqGlob/ui/metalink.nut")
let { use_soldier_levelup_orders } = require("%enlist/meta/clientApi.nut")
let serverPerks = require("%enlist/meta/servProfile.nut").soldierPerks
let { configs } = require("%enlist/meta/configs.nut")
let { getPerkPointsInfo } = require("%enlist/meta/perks/perkTreePkg.nut")
let perksList = require("%enlist/meta/perks/perksList.nut")
let sClassesCfg = require("%enlist/soldiers/model/config/sClassesConfig.nut")


let perksData = Computed(function() {
  let { perkSlotsByTiers = [], perkSchemes = {} } = configs.value
  let maxLevelByTier = perkSlotsByTiers.map(@(levels) levels.reduce(@(res, l) res + l, 0))
  return serverPerks.value.map(function(p) {
    let { slots = [],  sTier = 1, perkSchemeId = "" } = p //compatibility with enlisted_0_1_17_X
    let scheme = perkSchemes?[perkSchemeId] ?? []
    return p.__merge({
      maxLevel = maxLevelByTier?[sTier] ?? 1
      tiers = scheme.map(@(tierCfg, idx) tierCfg.__merge({
        slots = (clone (slots?[idx] ?? []))
          .resize(perkSlotsByTiers?[sTier][idx] ?? 0, "")
      }))
    })
  })
})

function getTotalPerkValue(perksListTable, perksStatsTable, perks, perkName) {
  local sum = 0.0
  foreach (tier in perks?.tiers ?? [])
    foreach (perkId in tier?.slots ?? [])
      if (tier?.perks?.indexof?(perkId) != null) {
        let stats = perksListTable?[perkId].stats ?? {}
        sum += stats?[perkName]
          ? stats[perkName] * perksStatsTable[perkName].base_power
          : 0.0
      }
  return sum
}

let notChoosenPerkSoldiers = Watched({})
let notChoosenPerkSquads = Watched({})
let notChoosenPerkArmies = Watched({})

function updateNotChosenPerks(...) {
  let pList = perksList.value
  let pData = perksData.value
  let classesCfg = sClassesCfg.value
  let { perkTrees = {}, perkTreesSpecial = {} } = configs.value

  let soldiersList = {}
  let squadsList = {}
  let armiesList = {}

  foreach (armyId in curArmiesList.value) {
    armiesList[armyId] <- 0
    squadsList[armyId] <- {}
    let chosenSquads = chosenSquadsByArmy.value?[armyId]
    if (chosenSquads == null)
      continue

    foreach (soldier in getSoldiersByArmy(armyId)) {
      let { guid, sClass } = soldier
      let perks = pData?[guid]
      let tree = perkTrees?[perkTreesSpecial?[sClass] ?? classesCfg?[sClass].kind] ?? []

      let ppInfo = getPerkPointsInfo(pList, perks)
      let availPoints = {}
      foreach(pointId, count in ppInfo.total)
        availPoints[pointId] <- count - (ppInfo.used?[pointId] ?? 0)

      foreach (perkId in tree) {
        let perk = pList[perkId]
        if ((perk.available ?? 1) > (perks?.perks[perkId] ?? 0))
          foreach (pointId, pointReq in perk.cost) {
            let pointHave = availPoints?[pointId] ?? 0
            if (pointReq > 0 && pointHave >= pointReq)
              soldiersList[guid] <- (soldiersList?[guid] ?? 0) + pointHave
          }
      }

      let squadId = curCampSquads.value?[getLinkedSquadGuid(soldier)].squadId
      if (squadId == null)
        continue

      squadsList[armyId][squadId] <- (squadsList[armyId]?[squadId] ?? 0) + 1

      if (chosenSquads.findindex(@(s) s?.squadId == squadId) != null)
        armiesList[armyId]++
    }
  }

  if (!u.isEqual(armiesList, notChoosenPerkArmies.value))
    notChoosenPerkArmies(armiesList)
  if (!u.isEqual(soldiersList, notChoosenPerkSoldiers.value))
    notChoosenPerkSoldiers(soldiersList)
  if (!u.isEqual(squadsList, notChoosenPerkSquads.value))
    notChoosenPerkSquads(squadsList)
}
updateNotChosenPerks()

//no need to subscribe on armies, soldier can not change army
foreach (w in [perksData, curCampaign, chosenSquadsByArmy])
  w.subscribe(updateNotChosenPerks)


function useSoldierLevelupOrders(guid, barterData) {
  use_soldier_levelup_orders(guid, barterData)
}

return {
  notChoosenPerkArmies
  notChoosenPerkSquads
  notChoosenPerkSoldiers

  perksData
  getTotalPerkValue
  useSoldierLevelupOrders
}
