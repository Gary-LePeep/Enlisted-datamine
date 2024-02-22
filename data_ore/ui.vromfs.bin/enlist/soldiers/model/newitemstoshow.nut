from "%enlSqGlob/ui/ui_library.nut" import *

let { mark_seen_objects } = require("%enlist/meta/clientApi.nut")
let { configs } = require("%enlist/meta/configs.nut")
let { prepareItems, preferenceSort } = require("items_list_lib.nut")
let { curArmy } = require("state.nut")
let {
  itemsByArmies, soldiersByArmies, commonArmy, outfitsByArmies
} = require("%enlist/meta/profile.nut")
let { collectSoldierData } = require("%enlist/soldiers/model/curSoldiersState.nut")
let { hasModalWindows } = require("%ui/components/modalWindows.nut")
let { gameProfile } = require("%enlist/soldiers/model/config/gameProfile.nut")
let { sourceProfileData } = require("%enlist/meta/sourceServProfile.nut")


let justPurchasedItems = mkWatched(persist, "justPurchasedItems", [])

let newItems = Computed(function() {
  let res = itemsByArmies.value.map(@(armyItems)
    armyItems.filter(@(item) !(item?.wasSeen ?? true)))
  return res
})

let newOutfits = Computed(function() {
  let res = outfitsByArmies.value.map(@(outfit)
    outfit.filter(@(item) !(item?.wasSeen ?? true)))
  return res
})

let newSoldiers = Computed(function() {
  let res = soldiersByArmies.value.map(@(armySoldiers)
    armySoldiers.filter(@(soldier) !(soldier?.wasSeen ?? true)))
  return res
})

let newItemsToShow = Computed(function() {
  let { campaignByArmyId = null } = gameProfile.value
  if (campaignByArmyId == null || "items_templates" not in configs.value)
    return null

  let commonArmyId = commonArmy.value
  let curArmyId = curArmy.value

  let armyByGuid = {}
  let itemsObjects = {}
  foreach (armyId, armyItems in newItems.value) {
    if (armyId != curArmyId && armyId != commonArmyId)
      foreach (guid, _ in armyItems)
        armyByGuid[guid] <- armyId
    itemsObjects.__update(armyItems)
  }
  let joinedItems = prepareItems(itemsObjects.keys(), itemsObjects)

  local soldiersObjects = {}
  foreach (armyId, armySoldiers in newSoldiers.value) {
    if (armyId != curArmyId && armyId != commonArmyId)
      continue // FIXME temporary do not show soldiers from other companies because of data access limits
    /*
      foreach (guid, _ in armySoldiers)
        armyByGuid[guid] <- armyId
    */
    soldiersObjects.__update(armySoldiers)
  }
  soldiersObjects = soldiersObjects.map(collectSoldierData)

  let outfitsObjects = {}
  foreach (armyId, armyItems in newOutfits.value) {
    if (armyId != curArmyId && armyId != commonArmyId)
      foreach (guid, _ in armyItems)
        armyByGuid[guid] <- armyId
    outfitsObjects.__update(armyItems)
  }
  let joinedOutfits = prepareItems(outfitsObjects.keys(), outfitsObjects)

  let allItems = [].extend(
    joinedItems.sort(preferenceSort),
    joinedOutfits,
    soldiersObjects.values().sort(preferenceSort))
  return allItems.len() > 0
    ? {
        header = loc("battleRewardTitle")
        allItems
        itemsGuids = itemsObjects.keys()
        outfitsGuids = outfitsObjects.keys()
        soldiersGuids = soldiersObjects.keys()
        armyByGuid
      }
    : null
})

function markSeenGuids(objs, guids) {
  foreach (guid in guids)
    if (guid in objs)
      objs[guid].wasSeen <- true
}

let isMarkSeenInProgress = Watched(false) //to ignore duplicate changes
function markNewItemsSeen() {
  if (isMarkSeenInProgress.value || newItemsToShow.value == null)
    return

  let { itemsGuids, soldiersGuids, outfitsGuids } = newItemsToShow.value
  isMarkSeenInProgress(true)

  let guids = [].extend(itemsGuids, soldiersGuids, outfitsGuids)
  mark_seen_objects(guids, @(_) isMarkSeenInProgress(false))

  //no need to wait for server answer to close this window
  sourceProfileData.mutate(function(profile) {
    let updSoldiers = profile.soldiers
    markSeenGuids(updSoldiers, soldiersGuids)
    profile.soldiers = clone updSoldiers

    let updItems = profile.items
    markSeenGuids(updItems, itemsGuids)
    profile.items = clone updItems

    let updOutfits = profile.soldiersOutfit
    markSeenGuids(updOutfits, outfitsGuids)
    profile.soldiersOutfit = clone updOutfits
  })
}

return {
  needNewItemsWindow = Computed(@() newItemsToShow.value != null && !hasModalWindows.value)
  newItemsToShow
  markNewItemsSeen
  justPurchasedItems
}
