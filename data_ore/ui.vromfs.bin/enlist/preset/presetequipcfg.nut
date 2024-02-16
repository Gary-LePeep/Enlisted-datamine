from "%enlSqGlob/ui_library.nut" import *

let { mkOnlineSaveData } = require("%enlSqGlob/mkOnlineSaveData.nut")
let { hasPremium } = require("%enlist/currency/premium.nut")
let { getKindCfg } = require("%enlSqGlob/ui/soldierClasses.nut")
let { getRomanNumeral } = require("%sqstd/math.nut")
let { curArmy, armoryByArmy, getSoldierItemSlots
} = require("%enlist/soldiers/model/state.nut")
let { trimUpgradeSuffix } = require("%enlSqGlob/ui/itemsInfo.nut")
let { getPossibleUnequipList, getAlternativeEquipList, getPossibleEquipList,
  getBetterItem, getWorseItem, MAX_ITEM_BR
} = require("%enlist/soldiers/model/selectItemState.nut")
let { campaignsByArmy } = require("%enlist/meta/profile.nut")
let { renameCommonArmies } = require("%enlSqGlob/renameCommonArmies.nut")
let renameCommonTemplatesWeapons = require("%enlist/configs/renameCommonTemplatesWeapons.nut")
let { onlineSettingUpdated } = require("%enlist/options/onlineSettings.nut")
let { armies } = require("%enlist/meta/servProfile.nut")
let { isUnited } = require("%enlist/meta/campaigns.nut")

let { configs } = require("%enlist/meta/configs.nut")

// equipment presets = {
//  moscow_allies = {
//      tanker = [
//         {
//            name = "Preset 1 for Tanker"
//            items = [ {slotType = ..., slotId = ..., itemTpl = ...}, ... ]
//         }
//         {
//            name = "Preset 2 for Tanker"
//            items = [ {slotType = ..., slotId = ..., itemTpl = ...}, ... ]
//         }
//      }
//      sniper = [ ... ]
//   }
// }

let equipmentPresetsStorage = mkOnlineSaveData("presetEquipment", @() {})
let setEquipmentPreset = equipmentPresetsStorage.setValue
let equipmentPresetWatch = equipmentPresetsStorage.watch

const SLOT_COUNT = 6
const SLOT_COUNT_MAX = 10
let slotCount = Computed(@() hasPremium.value ? SLOT_COUNT_MAX : SLOT_COUNT)

let minimumEquipList = function(soldier, _items, notFoundItemsWatch, _maxBR) {
  let unequipList = getPossibleUnequipList(soldier.guid)
  let changeEquipList = getAlternativeEquipList(soldier, getWorseItem, unequipList, MAX_ITEM_BR)
    .extend(unequipList)
  notFoundItemsWatch({})
  return changeEquipList
}

let bestEquipList = function(soldier, _items, notFoundItemsWatch, maxBR) {
  maxBR = maxBR ?? MAX_ITEM_BR
  let toAddEquipList = getPossibleEquipList(soldier, maxBR)
  let changeEquipList = getAlternativeEquipList(soldier, getBetterItem, [], maxBR)
    .extend(toAddEquipList)

  notFoundItemsWatch({})
  return changeEquipList
}


let itemListByTpl = function(itemTpl) {
  let inventory = armoryByArmy.value?[curArmy.value] ?? []
  let availableItems = inventory
    .filter(@(item) itemTpl == trimUpgradeSuffix(item.basetpl))
    .sort(@(a, b) (b?.tier ?? 0) <=> (a?.tier ?? 0))
  return availableItems
}

let selectedEquipList = function(presetList, slot) {
  let presetVal = presetList?[slot]
  if (presetVal == null)
    return null

  return function(soldier, campItemsByLinkVal, notFoundItemsWatch, _maxBR) {
    let presetSlots = {}
    presetVal.items.each(@(slotData) presetSlots[slotData.slotType] <-
      (presetSlots?[slotData.slotType] ?? 0) + 1 )

    let toReplace = []
    let changeEquipList = []
    let slotsItems = getSoldierItemSlots(soldier.guid, campItemsByLinkVal)
    foreach (equippedItem in slotsItems) {
      let { slotType, slotId } = equippedItem
      let presetItem = presetVal.items.findvalue(@(i)
        i.slotType == slotType && i.slotId == slotId)
      if (presetItem == null) {
        changeEquipList.append({
          item = null
          slotType
          slotId
        })
        continue
      }

      presetSlots[slotType] -= 1
      if (trimUpgradeSuffix(equippedItem?.item.basetpl) == presetItem.itemTpl
        || (equippedItem?.item.isFixed ?? false) ) {
          continue
      }
      toReplace.append(slotType)
    }

    slotsItems.each(function(item) {
      if (item.slotType in presetSlots && presetSlots[item.slotType] == 0)
        delete presetSlots[item.slotType]
    })

    let notFoundTbl = {}

    foreach (slotType in toReplace.extend(presetSlots.keys())) {
      let presetItems = presetVal.items.filter(@(i) i.slotType == slotType)
        .sort(@(a,b) a.slotId <=> b.slotId) //warning disable: -unwanted-modification
      local availableItems = {}

      foreach (presetItem in presetItems) {
        let { itemTpl } = presetItem
        if (itemTpl not in availableItems) {
          availableItems[itemTpl] <- itemListByTpl(presetItem.itemTpl)
        }

        let itemData = clone presetItem
        if (availableItems[itemTpl].len() == 0) {
          itemData.shopItem <- itemTpl
          notFoundTbl[itemTpl] <- (notFoundTbl?[itemTpl] ?? 0) + 1
        } else {
          let item = availableItems[itemTpl].pop()
          itemData.item <- item
        }
        changeEquipList.append(itemData)
      }
    }

    notFoundItemsWatch(notFoundTbl)
    return changeEquipList
  }
}

let updateStorage = function(presetTbl, armyId, sKind, slot, newData) {
  local storage = clone presetTbl ?? {}
  let armyStorage = clone storage?[armyId] ?? {}
  storage[armyId] <- armyStorage
  let kindStorage = clone armyStorage?[sKind] ?? array(SLOT_COUNT_MAX)
  armyStorage[sKind] <- kindStorage
  if (kindStorage.len() <= slot)
    kindStorage.resize(SLOT_COUNT_MAX)

  let presetData = kindStorage[slot] ?? {}
  kindStorage[slot] = freeze(presetData.__merge(newData))
  setEquipmentPreset(storage)
}

let savePreset = @(presetTbl, slot) function(soldier, campItemsByLinkVal) {
  if (soldier == null) {
    return false
  }

  let { armyId, sKind } = soldier
  let slotsItems = getSoldierItemSlots(soldier.guid, campItemsByLinkVal)
  let presetData = {
    name = presetTbl?[armyId][sKind][slot].name ?? loc("preset/equip/name",
      { order = getRomanNumeral(slot + 1), kind = loc(getKindCfg(sKind).locId) })
    items = slotsItems.apply(@(equippedItem) {
      slotType = equippedItem.slotType
      slotId = equippedItem.slotId
      itemTpl = trimUpgradeSuffix(equippedItem.item.basetpl)
    })
  }

  updateStorage(presetTbl, armyId, sKind, slot, presetData)
  return true
}

let slotsIncrease = function(presetList, index) {
  let items = presetList?[index].items ?? []
  let result = {}
  items.each(function(slotData) {
    foreach (slotType, tplsList in configs.value?.equip_slot_increase ?? {})
      if (slotData.itemTpl in tplsList)
        result[slotType] <- tplsList[slotData.itemTpl]
  })
  return items.len() == 0 ? null : result
}

let renamePreset = function(presetTbl, presetList, slot) {
  if (presetList?[slot] == null)
    return null

  return @(soldier, name)
    updateStorage(presetTbl, soldier.armyId, soldier.sKind, slot, { name })
}

let function deleteSlot(presetTbl, armyId, sKind, slot) {
  let presets = clone presetTbl
  let armyStorage = clone presets[armyId]
  presets[armyId] = armyStorage
  let kindStorage = clone armyStorage[sKind]
  armyStorage[sKind] = kindStorage

  kindStorage.remove(slot)
  setEquipmentPreset(presets)
}

let deletePreset = function(presetTbl, presetList, slot) {
  if (presetList?[slot] == null)
    return null

  return function(soldier) {
    let { armyId, sKind } = soldier
    deleteSlot(presetTbl, armyId, sKind, slot)
  }
}

let function movePresetsToUnited() {
  let campaigns = campaignsByArmy.value

  let presets = {}
  foreach (armyId, oldClasses in equipmentPresetWatch.value) {
    let unitedArmy = renameCommonArmies?[armyId]
    if (!unitedArmy)
      continue

    local newClasses = presets?[unitedArmy]
    if (newClasses == null) {
      newClasses = {}
      presets[unitedArmy] <- newClasses
    }

    let campaignId = campaigns?[armyId].id ?? armyId
    let armyPresets = renameCommonTemplatesWeapons?[armyId]

    foreach (classId, oldPresets in oldClasses) {
      local newPresets = newClasses?[classId]
      if (!newPresets) {
        newPresets = [].resize(SLOT_COUNT_MAX, null)
        newClasses[classId] <- newPresets
      }

      foreach (oldPreset in oldPresets) {
        if (!oldPreset)
          continue

        newPresets.append({
          name = oldPreset.name
          campaign = campaignId
          items = oldPreset.items.map(@(item) {
            slotType = item.slotType
            slotId = item.slotId
            itemTpl = armyPresets?[item.itemTpl] ?? item.itemTpl
          })
        })
      }
    }
  }

  if (presets.len() > 0)
    setEquipmentPreset(presets)
}

let isProfileDataReady = keepref(Computed(@() onlineSettingUpdated.value && armies.value.len() > 0))
isProfileDataReady.subscribe(function(v) {
  if (!v)
    return

  isProfileDataReady.unsubscribe(callee())
  if (isUnited())
    movePresetsToUnited()
})

console_register_command(@() movePresetsToUnited(), "presets.equipment.move_to_united")
console_register_command(@() console_print("Presets: ", equipmentPresetWatch.value),
  "presets.equipment.list")
console_register_command(@() setEquipmentPreset(null), "presets.equipment.reset")
console_register_command(@() setEquipmentPreset({}), "presets.equipment.clear")
console_register_command(function() {
  let presets = clone equipmentPresetWatch.value
  foreach (armyId in renameCommonArmies) {
    if (armyId in presets) {
      delete presets[armyId]
      console_print("Preset deleted: ", armyId)
    }
  }
  setEquipmentPreset(presets)
}, "presets.equipment.clear_united")

return {
  SLOT_COUNT
  SLOT_COUNT_MAX
  slotCount
  slotsIncrease
  minimumEquipList
  bestEquipList
  selectedEquipList
  equipmentPresetWatch
  savePreset
  renamePreset
  deletePreset
}
