from "%enlSqGlob/ui/ui_library.nut" import *

let {
  upgrade_items_count, equip_item, swap_items, equip_by_list, dispose_items_count, mass_equip
} = require("%enlist/meta/clientApi.nut")
let { isChangesBlocked, showBlockedChangesMessage } = require("%enlist/quickMatchQueue.nut")
let { updateBROnItemChange } = require("%enlist/soldiers/armySquadTier.nut")
let { updateArmoryIndex } = require("%enlist/soldiers/model/unseenWeaponry.nut")

let isItemActionInProgress = Watched(false)

let mkActionCb = @(cb, soldierGuid = null) function(res) {
  isItemActionInProgress(false)
  if (soldierGuid != null)
    updateBROnItemChange(soldierGuid)
  updateArmoryIndex(res)
  cb?(res)
}

function upgradeItem(guidsTbl, spendItemGuids, cb = null) {
  if (isItemActionInProgress.value)
    return
  isItemActionInProgress(true)
  upgrade_items_count(guidsTbl, spendItemGuids, mkActionCb(cb))
}

function equipItem(itemGuid, slotType, slotId, targetGuid, cb = null) {
  if (isChangesBlocked.value) {
    showBlockedChangesMessage()
    return
  }
  if (isItemActionInProgress.value)
    return
  isItemActionInProgress(true)
  equip_item(targetGuid, itemGuid, slotType, slotId, mkActionCb(cb, targetGuid))
}

function swapItems(soldierGuid1, slotType1, slotId1, soldierGuid2, slotType2, slotId2){
  if (isItemActionInProgress.value)
    return
  isItemActionInProgress(true)
  swap_items(soldierGuid1, slotType1, slotId1, soldierGuid2, slotType2, slotId2,
    mkActionCb(null, soldierGuid1))
}

function equipByList(sGuid, equipList, cb = null) {
  if (isItemActionInProgress.value)
    return
  isItemActionInProgress(true)
  equip_by_list(sGuid, equipList, mkActionCb(cb, sGuid))
}

function massEquipItems(equipListBySoldier, cb = null) {
  if (isItemActionInProgress.value)
    return
  isItemActionInProgress(true)
  mass_equip(equipListBySoldier, mkActionCb(cb))
}

function disposeItem(guidsTbl, cb = null) {
  if (isItemActionInProgress.value)
    return

  isItemActionInProgress(true)
  dispose_items_count(guidsTbl, mkActionCb(cb))
}

return {
  isItemActionInProgress
  upgradeItem
  equipItem
  swapItems
  equipByList
  massEquipItems
  disposeItem
}
