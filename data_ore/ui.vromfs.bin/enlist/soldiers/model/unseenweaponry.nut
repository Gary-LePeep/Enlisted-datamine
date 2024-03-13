from "%enlSqGlob/ui/ui_library.nut" import *

let { settings, onlineSettingUpdated } = require("%enlist/options/onlineSettings.nut")
let { curArmiesList, itemsByArmies, campItemsByLink, curCampSoldiers
} = require("%enlist/meta/profile.nut")
let { chosenSquadsByArmy, armoryByArmy, soldiersBySquad, canChangeEquipmentInSlot
} = require("state.nut")
let { equipSchemesByArmy } = require("all_items_templates.nut")
let { classSlotLocksByArmy } = require("%enlist/researches/researchesSummary.nut")
let { debounce } = require("%sqstd/timers.nut")
let { getLinkedArmyName } = require("%enlSqGlob/ui/metalink.nut")
let { allItemTemplates, findItemTemplate } = require("%enlist/soldiers/model/all_items_templates.nut")
let { trimUpgradeSuffix } = require("%enlSqGlob/ui/itemsInfo.nut")

const WEAPONRY_SEEN_ID = "seen/weaponry" // DEPRECATED
onlineSettingUpdated.subscribe(function(value) {
  if (value && WEAPONRY_SEEN_ID in settings.value)
    settings.mutate(@(v) v.$rawdelete(WEAPONRY_SEEN_ID))
})

const SEEN_ID = "seen/soldierSlots"
let SLOTS = ["primary", "side", "secondary", "melee",
  "backpack", "grenade", "mine", "flask_usable", "binoculars_usable",
  "antitank", "flamethrower", "mortar"]
let SLOTS_MAP = SLOTS.reduce(@(res, slotName) res.rawset(slotName, true), {})

let seen = Computed(@() settings.value?[SEEN_ID]) //<soldierGuid> = { <slot> = tier }
let betterWeaponrySoldier = Watched({})

let reduceFn = function(result, value) {
  result[value] <- true
  return result
}

// index for the itemtypes that need to be in the index
let itemTypesForSlots = Computed(function() {
  let res = {}
  foreach (armyId in curArmiesList.value) {
    let allItemtypes = {}
    let allItems = {}
    foreach (_, scheme in equipSchemesByArmy.value?[armyId] ?? {}) {
      foreach (slotId in SLOTS) {
        if (slotId not in scheme)
          continue
        let { itemTypes = [], items = [] } = scheme[slotId]
        allItemtypes.__update(itemTypes.reduce(reduceFn, {}))
        allItems.__update(items.reduce(reduceFn, {}))
      }
    }
    res[armyId] <- {
      itemTypes = allItemtypes
      items = allItems
    }
  }
  return res
})

function bestTier(currentTier, slotConfig, byTpl, byItemType) {
  let { itemTypes = [], items = [] } = slotConfig

  foreach (itemType in itemTypes) {
    let tiers = byItemType?[itemType].len() ?? -1
    local maxTier = -1
    for (local i = tiers - 1; i >= 0; i--)
      if ((byItemType?[itemType][i].len() ?? 0) > 0) {
        maxTier = i
        break
      }
    if (maxTier > currentTier)
      return maxTier
  }

  foreach (basetpl in items) {
    if (basetpl not in byTpl)
      continue
    let maxTier = byTpl[basetpl].reduce(@(res, value) res = max(res, value), -1)
    if (maxTier > currentTier)
      return maxTier
  }

  return currentTier
}

function addArmoryItemToIndex(item, armyId, byTpl, byItemType) {
  let { guid, basetpl } = item
  let { itemtype = "", tier = 0 } = findItemTemplate(allItemTemplates, armyId, basetpl)
  // do not add irrelevant items
  let itemsToIndex = itemTypesForSlots.value?[armyId]
  let tpl = trimUpgradeSuffix(basetpl)
  if (itemtype not in itemsToIndex?.itemTypes && tpl not in itemsToIndex?.items)
    return

  if (tpl not in byTpl)
    byTpl[tpl] <- {}
  byTpl[tpl][guid] <- tier

  let length = tier + 1
  let itemTypeList = byItemType?[itemtype] ?? array(length) // array of item count indexed by tier
  if (itemTypeList.len() < length)
    itemTypeList.resize(length)

  if (itemTypeList[tier] == null)
    itemTypeList[tier] = {}
  itemTypeList[tier][guid] <- true
  byItemType[itemtype] <- itemTypeList
}

function removeArmoryItemFromIndex(item, armyId, byTpl, byItemType) {
  let { guid, basetpl } = item
  let { itemtype, tier = 0 } = findItemTemplate(allItemTemplates, armyId, basetpl)

  let tpl = trimUpgradeSuffix(basetpl)
  byTpl?[tpl].$rawdelete(guid)
  byItemType?[itemtype][tier].$rawdelete(guid)
}

function removeGuids(guidsToRemove, armyCache) {
  let { byTpl = {}, byItemType = {} } = armyCache
  local removedSuccess = false

  foreach (baseTpl, guidsTbl in byTpl) {
    let newTbl = guidsTbl.filter(@(_, guid) guid not in guidsToRemove)
    if (newTbl.len() != guidsTbl.len()) {
      byTpl[baseTpl] = newTbl
      removedSuccess = true
    }
  }

  foreach (tiers in byItemType)
    foreach (idx, guidsTbl in tiers) {
      if (guidsTbl == null)
        continue
      let newTbl = guidsTbl.filter(@(_, guid) guid not in guidsToRemove)
      if (newTbl.len() != guidsTbl.len()) {
        tiers[idx] = newTbl
        removedSuccess = true
      }
    }
  return removedSuccess
}

let inventoryTiersCache = Watched({})
function createIndex() {
  foreach (armyId in curArmiesList.value) {
    let byItemType = {} // { itemtype = [ null null { guid = true } ] }. index in the array = item tier
    let byTpl = {} // { basetpl = { guid = tier } }

    foreach (item in (armoryByArmy.value?[armyId] ?? []))
      addArmoryItemToIndex(item, armyId, byTpl, byItemType)

    inventoryTiersCache.mutate(@(value) value[armyId] <- { byTpl, byItemType })
  }
}

let slotsLinkTiers = Computed(function() {
  let res = {}
  let itemsList = itemsByArmies.value
  foreach (armyId in curArmiesList.value) {
    foreach (item in itemsList?[armyId] ?? {}) {
      let tier = item?.tier ?? 0
      foreach (linkTo, linkSlot in item.links)
        if (linkSlot in SLOTS_MAP) {
          if (linkTo not in res)
            res[linkTo] <- {}
          let slotsTiers = res[linkTo]
          slotsTiers[linkSlot] <- linkSlot in slotsTiers ? min(slotsTiers[linkSlot], tier) : tier
        }
    }
  }
  return res
})

function getSoldierFixedWeapon(soldierGuid) {
  let weapon = {}
  foreach (slotType, itemsList in campItemsByLink.value?[soldierGuid] ?? {}) {
    if (itemsList?[0].isFixed)
      weapon[slotType] <- true
  }
  return weapon
}

function recalcUnseen() {
  let markedSoldiers = {}

  foreach (armyId in curArmiesList.value) {
    let classLocks = classSlotLocksByArmy.value?[armyId]
    let equipSchemes = equipSchemesByArmy.value?[armyId]
    let { byTpl = {}, byItemType = {} } = inventoryTiersCache.value?[armyId]

    foreach (squad in chosenSquadsByArmy.value?[armyId] ?? []) {
      foreach (soldier in soldiersBySquad.value?[squad.guid] ?? []) {
        let scheme = equipSchemes?[soldier?.equipSchemeId]
        let fixedWeapon = getSoldierFixedWeapon(soldier.guid)

        let betterSlots = {}
        foreach (slotId in SLOTS) {
          if (slotId not in scheme)
            continue

          if ((fixedWeapon.len() > 0 && (slotId in fixedWeapon))
              || (classLocks?[soldier?.sClass] ?? []).contains(slotId)
              || !canChangeEquipmentInSlot(soldier?.sClass, slotId))
            continue

          let equippedTier = slotsLinkTiers.value?[soldier.guid][slotId] ?? -1 // -1 for empty
          let tier = bestTier(equippedTier, scheme?[slotId], byTpl, byItemType)

          if (tier > equippedTier)
            betterSlots[slotId] <- equippedTier
        }
        if (betterSlots.len() > 0)
          markedSoldiers[soldier.guid] <- betterSlots
      }
    }
  }
  betterWeaponrySoldier(markedSoldiers)
}

let recalcUnseenDebounced = debounce(recalcUnseen, 0.01)
foreach (v in [seen, chosenSquadsByArmy,
    soldiersBySquad, classSlotLocksByArmy, inventoryTiersCache])
  v.subscribe(@(_) recalcUnseenDebounced())
// no subscription to slotsLinkTiers because it changes together with inventoryTiersCache

itemTypesForSlots.subscribe(function(value) {
  if (value.len() > 0)
    createIndex() // when data is ready
})

// create index and recalc unseen after script reload
createIndex()
recalcUnseen()

function clearSeenSlot(item) {
  let armyId = getLinkedArmyName(item)
  let { basetpl } = item
  let { itemtype, tier = 0 } = findItemTemplate(allItemTemplates, armyId, basetpl)
  let tpl = trimUpgradeSuffix(basetpl)

  settings.mutate(function(value) {
    if (SEEN_ID not in value)
      value[SEEN_ID] <- {}

    let equipSchemes = equipSchemesByArmy.value?[armyId]
    foreach (squad in chosenSquadsByArmy.value?[armyId] ?? [])
      foreach (soldier in soldiersBySquad.value?[squad.guid] ?? []) {

        let scheme = equipSchemes?[soldier?.equipSchemeId]
        if (scheme == null || soldier.guid not in value[SEEN_ID])
          continue

        let fixedWeapon = getSoldierFixedWeapon(soldier.guid)
        let hasFixedWeapon = fixedWeapon.len() > 0
        let soldierData = value[SEEN_ID]?[soldier.guid] ?? {}

        foreach (slotType, slotData in scheme) {
          if (slotType not in soldierData || (hasFixedWeapon && (slotType in fixedWeapon)))
            continue

          let { itemTypes = [], items = [] } = slotData
          if (itemTypes.contains(itemtype) || items.contains(tpl)) {
            if (soldierData[slotType] <= tier)
              soldierData.$rawdelete(slotType)
            break
          }
        }
        value[SEEN_ID][soldier.guid] <- soldierData
      }
  })
}

function markSeenSlot(armyId, ownerGuid, slotType) {
  let soldier = curCampSoldiers.value?[ownerGuid]
  if (soldier == null)
    return

  let scheme = equipSchemesByArmy.value?[armyId][soldier?.equipSchemeId]

  let { byTpl = {}, byItemType = {} } = inventoryTiersCache.value?[armyId]
  let tierFromInventory = bestTier(-1, scheme?[slotType], byTpl, byItemType)
  if (tierFromInventory == (settings.value?[SEEN_ID][ownerGuid][slotType] ?? -1))
    return

  settings.mutate(function(value) {
    let seenTbl = clone value?[SEEN_ID] ?? {}
    let soldierData = clone seenTbl?[ownerGuid] ?? {}
    seenTbl[ownerGuid] <- soldierData
    soldierData[slotType] <- tierFromInventory
    value[SEEN_ID] <- seenTbl
  })
}

function markInventorySlotsSeen() {
  settings.mutate(function(value) {
    if (SEEN_ID not in value)
      value[SEEN_ID] <- {}

    foreach (armyId in curArmiesList.value) {
      let equipSchemes = equipSchemesByArmy.value?[armyId]

      foreach (squad in chosenSquadsByArmy.value?[armyId] ?? [])
        foreach (soldier in soldiersBySquad.value?[squad.guid] ?? []) {

          let scheme = equipSchemes?[soldier?.equipSchemeId]
          if (scheme == null)
            continue

          let fixedWeapon = getSoldierFixedWeapon(soldier.guid)
          let hasFixedWeapon = fixedWeapon.len() > 0
          let soldierData = value[SEEN_ID]?[soldier.guid] ?? {}

          foreach (slotType, _ in scheme) {
            if (hasFixedWeapon && (slotType in fixedWeapon))
              continue

            let equippedTier = slotsLinkTiers.value?[soldier.guid][slotType] ?? -1
            soldierData[slotType] <- equippedTier
          }
          value[SEEN_ID][soldier.guid] <- soldierData
        }
    }
  })
}

function resetSeen() {
  settings.mutate(function(value) {
    value.$rawdelete(SEEN_ID)
  })
}

console_register_command(markInventorySlotsSeen, "meta.markSeenSlots")
console_register_command(resetSeen, "meta.resetSeenSlots")
console_register_command(createIndex, "meta.indexInventory")
console_register_command(recalcUnseen, "meta.recalcUnseen")
console_register_command(@() debugTableData(seen.value), "meta.printSavedSeenSlots")

function itemOperation(item, fn) {
  let armyId = getLinkedArmyName(item)
  let { byTpl = {}, byItemType = {} } = inventoryTiersCache.value?[armyId]
  fn(item, armyId, byTpl, byItemType)
}

function updateArmoryIndex(result) {
  foreach (_, item in result?.items ?? {}) {
    if (item.links.len() == 1) { // not equipped
      itemOperation(item, addArmoryItemToIndex)
      clearSeenSlot(item)
    } else
      itemOperation(item, removeArmoryItemFromIndex)
  }

  let guidsToRemove = (result?.removed.items ?? []).reduce(reduceFn, {})
  if (guidsToRemove.len() == 0)
    return

  foreach (tiersCache in inventoryTiersCache.value)
    if (removeGuids(guidsToRemove, tiersCache))
      break
}

let soldiersUpgradeAlerts = Computed(function() {
  let res = {}
  foreach (soldierGuid, slotData in betterWeaponrySoldier.value) {
    foreach (slotType, _ in slotData) {
      if (slotType not in seen.value?[soldierGuid]) {
        res[soldierGuid] <- true
        break
      }
    }
  }
  return res
})

return {
  betterWeaponrySoldier
  markSeenSlot
  soldierSlotsTiersEquipped = slotsLinkTiers
  soldierSeenSlots = seen
  soldiersUpgradeAlerts
  updateArmoryIndex
}
