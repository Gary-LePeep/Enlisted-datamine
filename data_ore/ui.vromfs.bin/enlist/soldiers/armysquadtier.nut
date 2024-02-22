from "%enlSqGlob/ui/ui_library.nut" import *

let { campItemsByLink } = require("%enlist/meta/profile.nut")
let { curArmy, curArmiesList, soldiersBySquad, chosenSquadsByArmy,
  curCampSquads, getSoldierByGuid, vehicleBySquad
} = require("model/state.nut")
let { allMembersState, isSquadLeader } = require("%enlist/squad/squadState.nut")
let curSquadId = require("%enlist/squad/squadState.nut").squadId
let { itemTypesInSlots } = require("%enlist/soldiers/model/all_items_templates.nut")
let { nestWatched } = require("%dngscripts/globalState.nut")
let { getFirstLinkByType } = require("%enlSqGlob/ui/metalink.nut")
let userInfo = require("%enlSqGlob/userInfo.nut")

let allArmiesTiers = nestWatched("allArmiesTiers", {})

local BRInfoBySquads = nestWatched("BRInfoBySquads", {})
local BRByArmies = nestWatched("BRByArmies", {})
const TIERS = 6

let getLiveArmyBR = @(watchVal, armyId) watchVal?[armyId] ?? 1
let getArmyBR = @(armyId) getLiveArmyBR(BRByArmies.value, armyId)

function getWeaponSoldierBR(soldierGuid) {
  let { mainWeapon } = itemTypesInSlots.value
  let res = []
  foreach (slotType, itemsList in campItemsByLink.value?[soldierGuid] ?? {})
    foreach (item in itemsList)
      if (slotType == "secondary" || slotType == "primary" || item?.itemtype in mainWeapon)
        res.append(item?.growthTier ?? 1)
  return res
}

function getSoldierBR(soldierGuid) {
  local maxBR = 1
  foreach (br in getWeaponSoldierBR(soldierGuid))
    maxBR = max(maxBR, br)
  return maxBR
}

function getLiveSquadBR(watchVal, squadId) {
  if (squadId not in watchVal) {
    log($"No battle data rating for {squadId}")
    return 1
  }

  for (local i = TIERS - 1; i > 0; i--) {
    if (watchVal[squadId][i] > 0)
      return i
  }
  return 1
}

let getSquadBR = @(squadId) getLiveSquadBR(BRInfoBySquads.value, squadId)

function collectSquadInfo(squad) {
  let squadGuid = squad?.guid
  if (squadGuid == null)
    log("collectSquadInfo: empty squad data")

  let result = array(TIERS, 0)

  let vehicle = vehicleBySquad.value?[squadGuid]
  let vehicleBR = max(1, vehicle?.growthTier ?? 0)
  result[vehicleBR] += 1

  foreach (soldier in soldiersBySquad.value?[squadGuid] ?? []) {
    foreach (br in getWeaponSoldierBR(soldier.guid))
      result[br] += 1
  }
  return result
}

function updateSquadInfoMutiple(squads, forceRecalc = false) {
  let newWatchTable = clone BRInfoBySquads.value
  local hasChanges = false
  foreach (squad in squads) {
    let { squadId } = squad
    if (forceRecalc || squadId not in newWatchTable) {
      newWatchTable[squadId] <- collectSquadInfo(squad)
      hasChanges = true
    }
  }
  if (hasChanges)
    BRInfoBySquads(newWatchTable)
}

function writeBRForArmy(armyId, br) {
  BRByArmies.mutate(@(v) v[armyId] <- br)
}

function updateBRForArmy(armyId) {
  local br = 1
  foreach (squad in (chosenSquadsByArmy.value?[armyId] ?? [])) {
    br = max(br, getSquadBR(squad.squadId))
  }
  writeBRForArmy(armyId, br)
}

function updateBRForSquad(squad) {
  let { squadId } = squad
  if (squadId not in BRInfoBySquads.value) {
    log($"Squad {squadId} not found in the rating table. Update ignored")
    return
  }
  let weaponInfo = collectSquadInfo(squad)
  BRInfoBySquads.mutate(@(v) v[squadId] <- weaponInfo)

  let squadBR = getSquadBR(squadId)
  let armyId = curArmy.value
  let armyBR = getArmyBR(armyId)
  if (squadBR > armyBR)
    writeBRForArmy(armyId, squadBR)
  else
    updateBRForArmy(armyId)
}

function updateCurrentArmyInfo(armyId) {
  if ((armyId ?? "") == "")
    return
  let squads = chosenSquadsByArmy.value?[armyId] ?? []
  updateSquadInfoMutiple(squads, true)
  updateBRForArmy(armyId)
}

function updateOtherArmies() {
  foreach (armyId in curArmiesList.value) {
    if (armyId != curArmy.value)
      updateCurrentArmyInfo(armyId)
  }
}

// Perform a full update and export the data for teammates
function updateBROnMatchStart() {
  updateCurrentArmyInfo(curArmy.value)
  updateOtherArmies()
  allArmiesTiers({
    armies = BRByArmies.value
    player = userInfo.value.name
  })
}

// when the game starts
curArmiesList.subscribe(function(_) {
  updateCurrentArmyInfo(curArmy.value)
  defer(updateOtherArmies)
})

// Recalculate:
// soldier management, changing selected squads, and changing weapons/vehicles
let calcBROnSoldierChange = updateBRForSquad

// when selected squads change: we subscribe to the data on all armies
// so it doesn't recalcuate when the current army changes
chosenSquadsByArmy.subscribe(function(_) {
  // recalculate if a squad was bought
  // process if selected squads changed
  updateCurrentArmyInfo(curArmy.value)
})

function updateBROnItemChange(targetGuid) {
  let soldier = getSoldierByGuid(targetGuid)
  if (soldier == null)
    // target is not a soldier. Not an error: some items can equip and unequip mods
    return
  let squadGuid = getFirstLinkByType(soldier, "squad")
  if (squadGuid == null) // soldier is in reserve
    return
  let squad = curCampSquads.value?[squadGuid]
  updateBRForSquad(squad)
}

function updateBROnVehicleChange(squadGuid) {
  let squad = curCampSquads.value?[squadGuid]
  updateBRForSquad(squad)
}

let maxMatesArmiesTiers = Computed(function(prev) {
  if (prev == FRP_INITIAL)
    prev = {}

  let membersList = allMembersState.value ?? {}
  let res = {}
  foreach (id, member in membersList) {
    let { armiesTiers = {}, ready = false } = member
    let isLeader = isSquadLeader.value && id == curSquadId.value
    if (armiesTiers.len() == 0 || (!isLeader && !ready))
      continue

    let { armies, player } = armiesTiers
    let memberArmies = isLeader ? BRByArmies.value : armies
    memberArmies.each(function(armyTier, armyId) {
      local { tier = 0, players = [] } = res?[armyId]
      if (tier == armyTier)
        players.append(player)
      else if (tier < armyTier) {
        players = [player]
        tier = armyTier
      }
      res[armyId] <- { tier, players }
    })
  }
  return isEqual(prev, res) ? prev : res
})

return {
  allArmiesTiers
  maxMatesArmiesTiers

  BRInfoBySquads
  BRByArmies

  getArmyBR
  getLiveArmyBR
  getSquadBR
  getLiveSquadBR
  getSoldierBR
  loadBRForAllSquads = updateSquadInfoMutiple

  updateBROnMatchStart
  calcBROnSoldierChange
  updateBROnItemChange
  updateBROnVehicleChange
}
