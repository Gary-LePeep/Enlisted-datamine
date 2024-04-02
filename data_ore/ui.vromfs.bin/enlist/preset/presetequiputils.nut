from "%enlSqGlob/ui/ui_library.nut" import *

let { curArmy, getSoldierItemSlots, objInfoByGuid } = require("%enlist/soldiers/model/state.nut")
let { curSoldierInfo } = require("%enlist/soldiers/model/curSoldiersState.nut")
let { campItemsByLink, curCampSoldiers } = require("%enlist/meta/profile.nut")
let { getLinkedArmyName, getLinkedSquadGuid } = require("%enlSqGlob/ui/metalink.nut")
let sClassesCfg = require("%enlist/soldiers/model/config/sClassesConfig.nut")
let { equipByList } = require("%enlist/soldiers/model/itemActions.nut")
let { SLOT_COUNT_MAX, slotCount, minimumEquipList, bestEquipList, selectedEquipList,
  equipmentPresetWatch, savePreset, renamePreset, deletePreset
} = require("presetEquipCfg.nut")
let { trimUpgradeSuffix } = require("%enlSqGlob/ui/itemsInfo.nut")
let { allItemTemplates, findItemTemplate
} = require("%enlist/soldiers/model/all_items_templates.nut")
let { mkShopItem } = require("%enlist/soldiers/model/items_list_lib.nut")
let { classSlotLocksByArmy } = require("%enlist/researches/researchesSummary.nut")
let { getRomanNumeral } = require("%sqstd/math.nut")
let obsceneFilter = require("%enlSqGlob/obsceneFilter.nut")
let popupsState = require("%enlSqGlob/ui/popup/popupsState.nut")
let premiumWnd = require("%enlist/currency/premiumWnd.nut")
let { isChangesBlocked, showBlockedChangesMessage } = require("%enlist/quickMatchQueue.nut")

let notFoundItems = Watched({})

enum PreviewState {
  OK = "replace"
  ERROR = "noReplace"
  NONE = "none"
}

enum PresetTarget {
  SOLDIER = "soldier"
  SQUAD = "squad"
  ALL = "all"
}

let autoPresets = [
  { locId = loc("autoEquip"), fnApply = bestEquipList, hasBRButtons = true }
  { locId = loc("removeAllEquipment"), fnApply = minimumEquipList }
]

let presetSlotName = @(preset, index) preset?.campaign
  ? loc("squads/presets/united", { campaign = loc($"{preset.campaign}/full"),
      name = preset.name })
  : (preset?.name ?? loc("btn/preset/name", { count = getRomanNumeral(index + 1) }))

let mkSlotDesc = @(presetTbl, presetList, i) {
  locId = presetSlotName(presetList?[i], i)
  fnApply = selectedEquipList(presetList, i)
  fnRename = i < SLOT_COUNT_MAX ? renamePreset(presetTbl, presetList, i) : null
  fnDelete = i >= SLOT_COUNT_MAX ? deletePreset(presetTbl, presetList, i) : null
  fnSave = i < SLOT_COUNT_MAX ? savePreset(presetTbl, i) : null
}

let mkSlotPrem = @(presetList, i) {
  locId = presetList?[i].name ?? loc("btn/preset/locked")
  onClick = @() premiumWnd()
  fnApply = selectedEquipList(presetList, i)
  isLockedPrem = true
}

let presetEquipList = Computed(function() {
  let allPresets = clone autoPresets
  let armyId = curArmy.value
  let sKind = curSoldierInfo.value?.sKind
  let presetsCount = equipmentPresetWatch.value?[armyId][sKind].len() ?? SLOT_COUNT_MAX
  for (local i = 0; i < presetsCount; i++) {
    let idx = i
    allPresets.append(i < slotCount.value || i >= SLOT_COUNT_MAX
      ? mkSlotDesc(equipmentPresetWatch.value,
          equipmentPresetWatch.value?[armyId][sKind], idx)
      : mkSlotPrem(equipmentPresetWatch.value?[armyId][sKind], idx))
  }
  return allPresets
})

let isWaitingObsceneFilterForIdx = Watched(-1)
let shopItemByTemplateData = function(itemTpl) {
  let templateId = trimUpgradeSuffix(itemTpl)
  let template = findItemTemplate(allItemTemplates, curArmy.value, templateId)
  if (template == null)
    return null
  return mkShopItem(templateId, template, curArmy.value)
}

let canEquip = @(slotData)
  !(slotData?.shopItem != null || (slotData?.item.isFixed ?? false))

let expandedSlotTypes = ["inventory", "grenade"]

let isLocked = @(lockedSlots, slotData, needRemoveExpanded)
  lockedSlots.contains(slotData.slotType)
    || (needRemoveExpanded && expandedSlotTypes.contains(slotData.slotType) && slotData.slotId > 0)

let makePreviewList = function(soldier, slotsItems, changeEquipList) {
  if (changeEquipList.len() == 0)
    return slotsItems

  let lockedSlots = classSlotLocksByArmy.value?[getLinkedArmyName(soldier)][soldier.sClass] ?? []
  let removeExpanded = lockedSlots.contains("backpack")

  foreach(slotData in changeEquipList) {
    // existing autoequip functions forms a list with guids
    // and do not assign item and previewState
    if (slotData?.item == null) {
      let item = slotData?.shopItem == null
        ? slotData?.guid == null ? null : objInfoByGuid.value?[slotData.guid]
        : shopItemByTemplateData(slotData.shopItem)
      slotData.item <- item
    }
    // end actions to adapt for existing functions

    slotData.previewState <- canEquip(slotData) && !isLocked(lockedSlots, slotData, removeExpanded)
      ? PreviewState.OK : PreviewState.ERROR

    let equippedItem = slotsItems.findvalue(@(i)
      i.slotType == slotData.slotType && i.slotId == slotData.slotId)

    if (equippedItem == null)
      slotsItems.append(slotData)
    else
      equippedItem.__update(slotData)
  }

  return slotsItems
}

let getItemSlotsWithPreset = function(soldier, campItemsByLinkVal, previewPresetVal) {
  let changeEquipList = previewPresetVal?.fnApply(soldier, campItemsByLinkVal,
    notFoundItems, previewPresetVal?.maxBR) ?? []
  let slotsItems = getSoldierItemSlots(soldier.guid, campItemsByLinkVal)
  return makePreviewList(soldier, slotsItems, changeEquipList)
}

let applyEquipmentToSoldier = function(presetCfg, soldier, notFoundItemsWatch) {

  let changeEquipList = presetCfg?.fnApply(soldier, campItemsByLink.value,
    notFoundItemsWatch, presetCfg?.maxBR) ?? []

  if (changeEquipList.len() > 0) {
    let lockedSlots = classSlotLocksByArmy.value?[getLinkedArmyName(soldier)][soldier.sClass] ?? []
    let removeExpanded = lockedSlots.contains("backpack")

    equipByList(soldier.guid, changeEquipList
      .filter(@(slotData) canEquip(slotData) && !isLocked(lockedSlots, slotData, removeExpanded))
      .map(@(i) {
        guid = i?.guid ?? (i?.item.guid ?? "")
        slotType = i.slotType
        slotId = i.slotId
      }
    ))
  }
}

let getSoldierKind = @(sClass) sClassesCfg.value?[sClass].kind ?? sClass

let targetFilters = {
  [PresetTarget.SOLDIER] = @(soldier, guid, _sKind, _squad) soldier.guid == guid,
  [PresetTarget.SQUAD] = @(soldier, _guid, sKind, squad) getLinkedSquadGuid(soldier) == squad
    && getSoldierKind(soldier.sClass) == sKind,
  [PresetTarget.ALL] = @(soldier, _guid, sKind, _squad) getSoldierKind(soldier.sClass) == sKind
}

let applyEquipmentPreset = function(presetCfg, target) {
  if (isChangesBlocked.value) {
    showBlockedChangesMessage()
    return
  }
  let checkFn = targetFilters?[target] ?? targetFilters[PresetTarget.SOLDIER]

  let { guid = null, sKind = null } = curSoldierInfo.value
  let squadId = getLinkedSquadGuid(curSoldierInfo.value)
  foreach (soldier in curCampSoldiers.value) {
    if (checkFn(soldier, guid, sKind, squadId))
      applyEquipmentToSoldier(presetCfg, soldier, notFoundItems)
  }
}

let saveEquipmentPreset = function(presetCfg) {
  return presetCfg?.fnSave(curSoldierInfo.value, campItemsByLink.value) ?? false
}


function filterAndRenamePreset(presetCfg, newName, idx) {
  if (isWaitingObsceneFilterForIdx.value >= 0)
    return
  isWaitingObsceneFilterForIdx(idx)
  obsceneFilter(newName, function(filteredPresetName) {
    isWaitingObsceneFilterForIdx(-1)
    if (filteredPresetName != newName) {
      return popupsState.addPopup({
        id = "prohibited_presetName"
        text = loc("prohibitedPresetname")
        styleName = "error"
      })
    }
    return presetCfg?.fnRename(curSoldierInfo.value, newName) ?? false
  })
}


console_register_command(function(slot) {
    if (curSoldierInfo.value == null)
      log("Soldier not selected")
    saveEquipmentPreset(presetEquipList.value?[slot])
  }, "meta.saveEquipPreset")

console_register_command(function(slot, target) {
    applyEquipmentPreset(presetEquipList.value?[slot], target)
  },
  "meta.applyEquipPreset")

return {
  applyEquipmentPreset
  saveEquipmentPreset
  filterAndRenamePreset
  isWaitingObsceneFilterForIdx
  PresetTarget
  presetEquipList
  notFoundPresetItems = notFoundItems
  getItemSlotsWithPreset
  shopItemByTemplateData
  PreviewState
}
