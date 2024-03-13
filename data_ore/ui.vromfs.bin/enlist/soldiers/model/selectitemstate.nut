from "%enlSqGlob/ui/ui_library.nut" import *

let { equipSlotTbl } = require("config/equipGroups.nut")
let { getEquippedItemGuid, objInfoByGuid, armoryByArmy,
  getScheme, getItemOwnerSoldier, curCampItems, getSoldierItemSlots, getDemandingSlots,
  armies, curArmy
} = require("%enlist/soldiers/model/state.nut")
let { campItemsByLink, soldiersByArmies, curCampSoldiers } = require("%enlist/meta/profile.nut")
let { equipItem, massEquipItems } = require("%enlist/soldiers/model/itemActions.nut")
let { classSlotLocksByArmy } = require("%enlist/researches/researchesSummary.nut")
let { allItemTemplates, findItemTemplate, itemTypesInSlots
} = require("%enlist/soldiers/model/all_items_templates.nut")
let { prepareItems, addShopItems, itemsSort } = require("%enlist/soldiers/model/items_list_lib.nut")
let { soldierClasses } = require("%enlSqGlob/ui/soldierClasses.nut")
let soldierSlotsCount = require("soldierSlotsCount.nut")
let { logerr } = require("dagor.debug")
let { getLinkedArmyName } = require("%enlSqGlob/ui/metalink.nut")
let { getObjectName, trimUpgradeSuffix } = require("%enlSqGlob/ui/itemsInfo.nut")
let { curSection } = require("%enlist/mainMenu/sectionsState.nut")
let { room, roomIsLobby } = require("%enlist/state/roomState.nut")
let { isObjGuidBelongToRentedSquad } = require("squadInfoState.nut")
let { showRentedSquadLimitsBox } = require("%enlist/soldiers/components/squadsComps.nut")
let { itemToShopItem, getShopListForItem } = require("%enlist/soldiers/model/cratesContent.nut")
let { curArmyItemsPrefiltered } = require("%enlist/shop/armyShopState.nut")
let { curSoldierInfo } = require("%enlist/soldiers/model/curSoldiersState.nut")
let { markSeenSlot } = require("unseenWeaponry.nut")

const MAX_ITEM_BR = 5

let selectParamsList = mkWatched(persist, "selectParamsList", [])
let selectParams = Computed(@() selectParamsList.value.len() ? selectParamsList.value.top() : null)
let selectParamsArmyId = Computed(@() selectParams.value?.armyId)

let autoSelectTemplate = Watched(null)

let curEquippedItem = Computed(function() {
  let { ownerGuid = null, slotType = null, slotId = null } = selectParams.value
  if (ownerGuid == null || slotType == null)
    return null
  let guid = getEquippedItemGuid(campItemsByLink.value, ownerGuid, slotType, slotId)
  return objInfoByGuid.value?[guid]
})

let curInventoryItem = Watched(null)
curCampItems.subscribe(@(_) curInventoryItem(null))

let viewItem = Computed(@() curInventoryItem.value ?? curEquippedItem.value) // last selected or current item
let isWeaponFixed = Computed(@() curEquippedItem.value?.isFixed ?? false)

function excludeItems(item, curArmyShopItemsPrefV, curArmyV, allItemTemplatesV, itemToShopItemV){
  if (item.guid != "" || item?.isShowDebugOnly)
    return true
  let tpl = item.basetpl
  let shopItemIds = getShopListForItem(tpl, curArmyV, itemToShopItemV, allItemTemplatesV)
  return (shopItemIds.len() >= 1 && shopItemIds[0] in curArmyShopItemsPrefV)
}

function calcItems(params, objInfoByGuidV, armoryByArmyV, curArmyShopItemsPrefV,
  itemToShopItemV, allItemTemplatesV) {
  let { armyId = null, filterFunc = @(_tplId, _tpl) true } = params
  if (!armyId)
    return []

  local itemsList = prepareItems((armoryByArmyV?[armyId] ?? [])
    .filter(@(item)
      item && filterFunc(item.basetpl, findItemTemplate(allItemTemplates, armyId, item.basetpl))),
      objInfoByGuidV)
  addShopItems(itemsList, armyId, @(tplId, tpl)
    filterFunc(tplId, tpl) && (tpl?.upgradeIdx ?? 0) == 0)
  itemsList = itemsList.filter(@(item)
    excludeItems(item, curArmyShopItemsPrefV, armyId, allItemTemplatesV, itemToShopItemV))
  return itemsList.sort(itemsSort)
}

function calcOther(params, armoryByArmyV, itemTypesInSlotsV) {
  let { slotType = null, armyId = null, filterFunc = @(_tplId, _tpl) true } = params
  if (!armyId)
    return []

  let allTypes = itemTypesInSlotsV?[slotType]
  local otherList = (armoryByArmyV?[armyId] ?? [])
    .filter(@(item) item
      && !filterFunc(item.basetpl, findItemTemplate(allItemTemplates, armyId, item.basetpl))
      && allTypes?[item?.itemtype])

  otherList = prepareItems(otherList, objInfoByGuid.value)
  addShopItems(otherList, armyId, @(tplId, tpl)
    (allTypes?[tpl.itemtype] ?? false) && !filterFunc(tplId, tpl) && (tpl?.upgradeIdx ?? 0) == 0)
  otherList.sort(itemsSort)
  return otherList
}

let slotItems = Computed(@() isWeaponFixed.value ? []
  : calcItems(selectParams.value, objInfoByGuid.value, armoryByArmy.value,
      curArmyItemsPrefiltered.value, itemToShopItem.value, allItemTemplates.value))

let inventoryItems = Computed(function() {
  let res = {}
  foreach (item in slotItems.value)
    if (!(item?.isShopItem ?? false))
      res[item.basetpl] <- item
  return res
})

let otherSlotItems = Computed(@() isWeaponFixed.value ? []
  : calcOther(selectParams.value, armoryByArmy.value, itemTypesInSlots.value))

let mkDefaultFilterFunc = function(showItemTypes = [], showItems = []) {
  let isFilterTypes = (showItemTypes?.len() ?? 0) != 0
  return (showItems?.len() ?? 0) != 0
    ? (isFilterTypes
      ? @(tmpl, item) showItems.indexof(trimUpgradeSuffix(tmpl)) != null
          || showItemTypes.indexof(item?.itemtype) != null
      : @(tmpl, _) showItems.indexof(trimUpgradeSuffix(tmpl)) != null)
    : (isFilterTypes
      ? @(_, item) showItemTypes.indexof(item?.itemtype) != null
      : @(_0, _1) true)
}

let paramsForPrevItems = Computed(function() {
  let { soldierGuid = null, ownerGuid = null, armyId = null } = selectParams.value
  if (soldierGuid != null)
    return null

  let ownerItem = objInfoByGuid.value?[ownerGuid]
  if (ownerItem == null)
    return null

  return {
    armyId = armyId
    ownerGuid = ownerGuid
    soldierGuid = soldierGuid
    filterFunc = mkDefaultFilterFunc([ownerItem?.itemtype])
    ownerName = getObjectName(ownerItem)
  }
})

let prevItems = Computed(@()
  calcItems(paramsForPrevItems.value, objInfoByGuid.value, armoryByArmy.value,
    curArmyItemsPrefiltered.value, itemToShopItem.value, allItemTemplates.value)
    .filter(@(item) "guid" in item))


function markLastViewedSlot() {
  if (selectParamsList.value.len() > 0) {
    let { armyId, soldierGuid, slotType } = selectParamsList.value.top()
    markSeenSlot(armyId, soldierGuid, slotType)
  }
}

function openSelectItem(armyId, ownerGuid, slotType, slotId) {
  if (ownerGuid == null)
    return
  let ownerItem = objInfoByGuid.value?[ownerGuid]
  if (!ownerItem) {
    logerr($"Not found item info to select item {ownerGuid}")
    return
  }
  let scheme = getScheme(ownerItem, slotType)
  if (!scheme) {
    // FIXME: now this situation can happens when bayonet has selected
    // We need to take this case into account in the code
    //logerr($"Not found scheme for item {ownerGuid} slotType {slotType}")
    return
  }

  let soldierGuid = ownerGuid in curCampSoldiers.value
    ? ownerGuid
    : getItemOwnerSoldier(ownerGuid)?.guid

  markLastViewedSlot()

  let params = {
    armyId
    ownerGuid
    soldierGuid
    slotType
    slotId
    scheme
    filterFunc = mkDefaultFilterFunc(scheme?.itemTypes, scheme?.items)
    ownerName = getObjectName(ownerItem)
  }
  selectParamsList.mutate(function(l) {
    let idx = l.findindex(@(p) p?.soldierGuid == soldierGuid)
    if (idx != null)
      l.resize(idx)
    l.append(params)
  })
  curInventoryItem(null) // clear current selected inventory item on slot item selection
}

function selectInsideListSlot(dir, doWrap) {
  local { armyId, ownerGuid, slotType, slotId } = selectParams.value
  let curScheme = curSoldierInfo.value?.equipScheme ?? {}
  let size = soldierSlotsCount(ownerGuid, curScheme).value?[slotType] ?? 0

  if (size <= 1)
    return false
  slotId = slotId + dir
  if (doWrap)
    slotId = (slotId + size) % size
  else if (slotId < 0 || slotId >= size)
    return false

  openSelectItem(armyId, ownerGuid, slotType, slotId)
  return true
}

function selectSlot(dir) {
  let params = selectParams.value
  if (params == null || selectInsideListSlot(dir, false))
    return

  local { slotType } = params
  let { equipScheme = {}, sClass = "unknown" } = curSoldierInfo.value
  let { armyId, ownerGuid } = params
  let lockedSlotList = classSlotLocksByArmy.value?[armyId][sClass] ?? []

  let availableSlotTypes = equipSlotTbl
    .keys()
    .filter(@(sType) sType in equipScheme
      && !equipScheme[sType]?.isDisabled
      && !equipScheme[sType]?.isLocked
      && !lockedSlotList.contains(sType))
    .sort(@(a, b)
      (equipScheme[a]?.uiOrder ?? 0) <=> (equipScheme[b]?.uiOrder ?? 0)) //warning disable: -unwanted-modification

  local slotIdx = availableSlotTypes.indexof(slotType)
  if (slotIdx == null)
    return

  slotIdx += dir
  if (slotIdx < 0 || slotIdx >= availableSlotTypes.len())
    return

  slotType = availableSlotTypes[slotIdx]
  let subslotsCount = soldierSlotsCount(curSoldierInfo.value?.guid, equipScheme).value?[slotType] ?? 0
  let slotId = subslotsCount < 1 ? -1
    : dir < 0 ? subslotsCount - 1
    : 0

  openSelectItem(armyId, ownerGuid, slotType, slotId)
}

function itemClear() {
  if (selectParamsList.value.len() > 0)
    selectParamsList.mutate(@(l) l.remove(l.len() - 1))
  if (selectParams.value == null)
    curInventoryItem(null) // clear current item on exit
}

curSection.subscribe(@(_) itemClear())

enum ItemCheckResult {
  NEED_RESEARCH = 0
  WRONG_CLASS = 1
  NEED_LEVEL = 2
  IN_SHOP = 3
}

function checkSelectItem(item) {
  let { basetpl = null, itemtype = null, isShopItem = false, unlocklevel = 0 } = item
  let soldier = curSoldierInfo.value
  if (basetpl == null || soldier == null)
    return null

  let trimmed = trimUpgradeSuffix(basetpl)

  let armyId = getLinkedArmyName(soldier)
  let armyLevel = armies.value?[armyId].level ?? 0

  let { sClass = "unknown", equipScheme = {} } = soldier
  let sClassLoc = loc(soldierClasses?[sClass].locId ?? "unknown")

  let { slotType = null,scheme = {} } = selectParams.value
  let slotsLocked = classSlotLocksByArmy.value?[armyId][sClass] ?? []
  if (slotsLocked.indexof(slotType) != null)
    return {
      result = ItemCheckResult.NEED_RESEARCH
      soldierClass = sClassLoc
      soldier
      slotType
    }

  let itemTypes = equipScheme?[slotType].itemTypes ?? []
  let itemList = scheme?.items ?? []
  if ((itemTypes.len() != 0 || itemList.len() != 0)
    && itemTypes.indexof(itemtype) == null
    && itemList.indexof(trimmed) == null)
    return {
      result = ItemCheckResult.WRONG_CLASS
      soldierClass = sClassLoc
    }

  if (isShopItem){
    if (unlocklevel > 0 && unlocklevel > armyLevel)
      return {
        result = ItemCheckResult.NEED_LEVEL
        level = unlocklevel
      }

    return {
      result = ItemCheckResult.IN_SHOP
    }
  }

  return null
}

function selectItem(item, cb = null) {
  // do not equip same item
  if (item?.basetpl == curEquippedItem.value?.basetpl)
    return

  let { slotType = null, slotId = null, ownerGuid = null } = selectParams.value

  if (ownerGuid != null && isObjGuidBelongToRentedSquad(ownerGuid)) {
    showRentedSquadLimitsBox()
    return
  }

  equipItem(item?.guid, slotType, slotId, ownerGuid, cb)
}

let defaultSortOrder = {
  explosion_pack = 6
  impact_grenade = 5
  incendiary_grenade = 4
  grenade = 3
  molotov = 2
  antipersonnel_mine = 2
  antitank_mine = 1
  smoke_grenade = 1
  medkits = 1
}

let classSortOrder = {
  tanker = { repair_kit = 2 }
  sniper = { smoke_grenade = 5 }
  engineer = { shovel = 2 }
  assault = { assault_rifle = 4, assault_semi = 3, submgun = 2, shotgun = 1 }
}

let unwantedTypes = { boltaction_noscope = true }

function getBetterItem(items, count, sortFunc) {

  let betterTypeAndTier = @(a, b) ((b?.itemtype ?? "") not in unwantedTypes)
      <=> ((a?.itemtype ?? "") not in unwantedTypes)
    || (b?.growthTier ?? 0) <=> (a?.growthTier ?? 0)
    || sortFunc(a, b)
    || (b?.tier ?? 0) <=> (a?.tier ?? 0)
    || (a?.guid ?? "") <=> (b?.guid ?? "")

  return items.sort(betterTypeAndTier).slice(0, count) //warning disable: -unwanted-modification
}

let getWorseItem = @(items, count, _sortFunc = null) items
  .sort(@(a, b) (a?.tier ?? 0) <=> (b?.tier ?? 0)) //warning disable: -unwanted-modification
  .slice(0, count)

let getBR = @(item) item?.growthTier ?? 1

function getItemForSlot(soldier, inventory, slotType, count, chooseFunc, armyId, maxBR) {
  let sortOrder = defaultSortOrder.__merge(classSortOrder?[soldier.sClass] ?? {})
  let sortFunc = @(a, b) (sortOrder?[b?.itemtype] ?? 0) <=> (sortOrder?[a?.itemtype] ?? 0)

  let { itemTypes = [], items = [] } = getScheme(soldier, slotType)
  if (itemTypes.len() == 0 && items.len() == 0)
    return null

  let filterCb = mkDefaultFilterFunc(itemTypes, items)

  let itemsList = inventory
    .filter(@(item) !(item?.isFixed ?? false) && getBR(item) <= maxBR
      && filterCb(item.basetpl, findItemTemplate(allItemTemplates, armyId, item.basetpl)))
  return chooseFunc(itemsList, count, sortFunc)
}

let sameTypeTier = @(item1, item2) item1 != null && item2 != null
  && item1.itemtype == item2.itemtype
  && (item1?.growthTier ?? 0) == (item2?.growthTier ?? 0)
  && (item1?.tier ?? 0) == (item2?.tier ?? 0)

function getAlternativeEquipList(soldier, chooseFunc, excludeSlots, maxBR) {
  let armyId = getLinkedArmyName(soldier)
  let slotsItems = getSoldierItemSlots(soldier.guid, campItemsByLink.value)
    .filter(@(i) !(excludeSlots.findindex(@(v) v.slotType == i.slotType) != null
      && excludeSlots.findindex(@(v) v.slotId == i.slotId) != null))

  let sortOrder = defaultSortOrder.__merge(classSortOrder?[soldier.sClass] ?? {})
  let sortFunc = @(a, b)
    (sortOrder?[b.itemtype] ?? 0) <=> (sortOrder?[a.itemtype] ?? 0)

  let equipList = []
  foreach (slotsItem in slotsItems) {
    let { slotType, slotId } = slotsItem
    let chosenItem = slotsItem?.item
    if (chosenItem?.isFixed ?? false)
      continue

    let itemsFromInventory = getItemForSlot(soldier, armoryByArmy.value?[armyId] ?? [],
      slotType, 1, chooseFunc, armyId, maxBR)

    if (itemsFromInventory.len() == 0) {
      // offer to unequip the current item if it has higher BR
      if (maxBR < getBR(chosenItem)) {
        let required = getDemandingSlots(soldier.guid, slotType,
          objInfoByGuid.value?[soldier.guid], campItemsByLink.value)
        if (required.len() <= 0)
          equipList.append({ slotType, slotId, guid = "" })
      }
      continue
    }

    local candidateItem = itemsFromInventory.top() // best with the given maxBR
    if (maxBR >= getBR(chosenItem)) {
      // the best between the equipped and found
      candidateItem = chooseFunc([chosenItem, candidateItem], 1, sortFunc).top()
    }

    if (!sameTypeTier(chosenItem, candidateItem))
      equipList.append({ slotType, slotId, guid = candidateItem.guid })
  }
  return equipList
}

let curCanUnequipSoldiersList = Computed(function() {
  let res = {}
  let itemsByLink = campItemsByLink.value
  let infoByGuid = objInfoByGuid.value
  let soldiers = soldiersByArmies.value?[curArmy.value] ?? {}
  foreach (guid, _ in soldiers) {
    let slotsItems = getSoldierItemSlots(guid, itemsByLink)
    foreach (slotsItem in slotsItems) {
      let { slotType } = slotsItem
      let demands = getDemandingSlots(guid, slotType, infoByGuid?[guid], itemsByLink)
      if (demands.len() == 0 || demands.filter(@(i) i != null).len() > 1) {
        res[guid] <- true
        break
      }
    }
  }
  return res
})

let AUTO_SLOTS = [
  "grenade", "inventory", "mine", "binoculars_usable", "flask_usable"
]

function cleanByValues(src, val) {
  foreach (key in src.keys())
    if (src[key] == val)
      src.$rawdelete(key)
}

function getEmptyNeededSlots(slotsItems, equipScheme) {
  let slotToGroup = {}
  foreach (slotType, slot in equipScheme) {
    let { atLeastOne = "" } = slot
    if (atLeastOne != "")
      slotToGroup[slotType] <- atLeastOne
  }
  foreach (item in slotsItems)
    if (item.slotType in slotToGroup)
      cleanByValues(slotToGroup, slotToGroup[item.slotType])
  return slotToGroup
}

function getPossibleEquipList(soldier, maxBR) {
  let { guid = null, equipScheme = {} } = soldier
  let slotsItems = getSoldierItemSlots(guid, campItemsByLink.value)
  let soldierSlotsCountTbl = soldierSlotsCount(guid, equipScheme).value
  let emptySlotsTypes = getEmptyNeededSlots(slotsItems, equipScheme)

  local freeSlots = {}
  foreach (slotType, count in soldierSlotsCountTbl) {
    freeSlots[slotType] <- {}
    for (local i = 0; i < count; i++) {
      freeSlots[slotType][i] <- true
    }
  }

  foreach (equippedItem in slotsItems) {
    let { slotType, slotId } = equippedItem
    if (slotType in freeSlots)
      if (slotId == -1)
        freeSlots[slotType].clear()
      else if (slotId in freeSlots[slotType])
        freeSlots[slotType].$rawdelete(slotId)
  }

  let reqSlotsList = AUTO_SLOTS.filter(@(slotType)
    slotType in freeSlots && freeSlots[slotType].len() > 0)

  let equipList = []
  if (reqSlotsList.len() == 0 && emptySlotsTypes.len() == 0)
    return equipList

  let armyId = getLinkedArmyName(soldier)
  let inventory = armoryByArmy.value?[armyId] ?? []

  foreach (slotType in reqSlotsList) {
    let slotList = freeSlots?[slotType] ?? {}
    if (slotList.len() == 0)
      continue

    let chosenItems = getItemForSlot(soldier, inventory, slotType, slotList.len(),
      getBetterItem, armyId, maxBR)

    let emptySlots = slotList.keys()
    foreach (i, newItem in chosenItems) {
      // slotId != array index in chosenItems
      equipList.append({ slotType, slotId = emptySlots[i], guid = newItem.guid })
    }
  }

  // find better weapon for empty slots
  foreach (slotType in emptySlotsTypes.keys()) {
    let newItemList = getItemForSlot(soldier, inventory, slotType, 1,
      getBetterItem, armyId, maxBR)

    if (newItemList.len() > 0 && slotType in emptySlotsTypes) {
      cleanByValues(emptySlotsTypes, emptySlotsTypes[slotType])
      foreach (newItem in newItemList)
        equipList.append({ slotType, slotId = -1, guid = newItem.guid })
    }
  }

  return equipList
}

let calcRatingByTypeTier = @(sortOrder, item)
  (sortOrder?[item?.itemtype] ?? 0) * 16 + (item?.tier ?? 0)

function addReplacementItem(toReplace, sortOrder, ownerGuid, slotType, slotsItem) {
  if (toReplace == null || (slotsItem?.item.isFixed ?? false))
    return
  // {
  //  melee => { 1 => {soldier => item}, 2 => { soldier => item } }
  //  primary => {} ...
  // }
  local slotTypeData = toReplace?[slotType]
  if (slotTypeData == null) {
    slotTypeData = {}
    toReplace[slotType] <- slotTypeData
  }

  let itemRating = calcRatingByTypeTier(sortOrder, slotsItem.item)
  if (itemRating == 0)
    return

  local itemRatingData = slotTypeData?[itemRating]
  if (itemRatingData == null) {
    itemRatingData = {}
    slotTypeData[itemRating] <- itemRatingData
  }
  itemRatingData[ownerGuid] <- slotsItem.item.guid
}

function getPossibleUnequipList(ownerGuid, toReplace = null, sortOrder = null) {
  let itemsByLink = campItemsByLink.value
  let infoByGuid = objInfoByGuid.value
  let equipList = []
  let unequipped = {}
  let slotsItems = getSoldierItemSlots(ownerGuid, itemsByLink)
  foreach (slotsItem in slotsItems) {
    if (slotsItem?.item.isFixed ?? false)
      continue

    let { slotType, slotId } = slotsItem
    let listByDemands = getDemandingSlots(ownerGuid, slotType, infoByGuid?[ownerGuid], itemsByLink)
    if (listByDemands.len() > 0
      && listByDemands.filter(@(i) i != null && i not in unequipped).len() <= 1) {
        addReplacementItem(toReplace, sortOrder, ownerGuid, slotType, slotsItem)
        continue
      }

    equipList.append({
      slotType, slotId, guid = ""
    })
    unequipped[slotsItem.item.guid] <- true
  }
  return equipList
}

function getWorst(itemList, keysSorted, scheme, objInfoByGuidVal) {
  foreach(key in keysSorted) {
    if (key not in itemList)
      continue
    let itemListByKey = itemList[key]
    if (itemListByKey.len() == 0) {
      itemList.$rawdelete(key)
      continue
    }
    foreach (guid, _ in itemListByKey) {
      let item = objInfoByGuidVal[guid]
      if (scheme.itemTypes.contains(item?.itemtype)
        || (scheme?.items ?? [])
          .findvalue(@(itemTpl) item?.basetpl.startswith(itemTpl)) != null )
        return { replacementGuid = guid, newitemRating = key }
    }
  }
  return { replacementGuid = null, newitemRating = -1 }
}

let excludeTypes = {
  medbox = true
  building_tool = true
  launcher = true
  mortar = true
  flaregun = true
  flamethrower = true
  antitank_rifle = true
  rifle_at_grenade_launcher = true
  infantry_launcher = true
}

function calcExchange(equipLists, toReplace, armoryItems) {
  // make table { assault => primary, sword => melee } etc
  let itemTypesToSlotType = {}
  let slots = { primary = "mainWeapon", melee = "melee" }
  foreach (slotName, itemType in slots) {
    foreach (itemtype, _ in (itemTypesInSlots.value?[itemType] ?? {})) {
      if (itemtype in excludeTypes)
        continue
      itemTypesToSlotType[itemtype] <- slotName
    }
  }

  let sortOrder = defaultSortOrder
  let armoryList = {}
  foreach (item in armoryItems) {
    let slotType = itemTypesToSlotType?[item?.itemtype] ?? ""
    if (slotType == "")
      continue

    let itemRating = calcRatingByTypeTier(sortOrder, item)
    local slotTypeData = armoryList?[slotType]
    if (slotTypeData == null) {
      slotTypeData = {}
      armoryList[slotType] <- slotTypeData
    }
    local itemRatingData = slotTypeData?[itemRating]
    if (itemRatingData == null) {
      itemRatingData = {}
      slotTypeData[itemRating] <- itemRatingData
    }
    itemRatingData[item.guid] <- true
  }

  // we take the best equipped item and replace it with the worst from the armory
  // repeat until the best equipped is the same as the worst in the armory, or armory is empty
  foreach (slotType, byitemRating in toReplace) {

    let armoryOrder = (armoryList?[slotType] ?? {}).keys().sort(@(a, b) a <=> b)
    let equipped = byitemRating.keys().sort(@(a, b) b <=> a)

    foreach(itemRating in equipped) {
      foreach (soldierGuid, itemGuid in byitemRating[itemRating]) {

        let soldier = objInfoByGuid.value?[soldierGuid]
        let scheme = getScheme(soldier, slotType)

        let { replacementGuid, newitemRating } = getWorst(armoryList?[slotType] ?? {},
          armoryOrder, scheme, objInfoByGuid.value)
        if (replacementGuid == null || itemRating <= newitemRating)
          continue
        equipLists[soldierGuid].append({
          slotType, slotId = -1, guid = replacementGuid
        })
        armoryList[slotType][newitemRating].$rawdelete(replacementGuid)
        if (itemRating not in armoryList[slotType])
          armoryList[slotType][itemRating] <- {}
        armoryList[slotType][itemRating][itemGuid] <- true
      }
    }
  }
  return equipLists
}

function massUnequipSoldierList(soldierList, equipLists, toReplace) {
  foreach (soldier in soldierList) {
    let soldierGuid = soldier.guid
    let sortOrder = defaultSortOrder.__merge(classSortOrder?[soldier.sClass] ?? {})
    equipLists[soldierGuid] <- getPossibleUnequipList(soldierGuid, toReplace, sortOrder)
  }
}

function massUnequipArmyReserve(reserveSquadsVal, soldiersBySquadVal, armoryByArmyVal, cb) {
  let equipLists = {}
  let toReplace = {}
  foreach(squad in reserveSquadsVal) {
    massUnequipSoldierList(soldiersBySquadVal?[squad.guid] ?? [], equipLists, toReplace)
  }
  let squad = reserveSquadsVal.findvalue(@(_) true)
  let armyId = squad != null ? getLinkedArmyName(squad) : ""
  let equipListsBySoldier = calcExchange(equipLists, toReplace, armoryByArmyVal?[armyId] ?? [])
  if (equipListsBySoldier.len() > 0)
    massEquipItems(equipListsBySoldier, cb)
}


function massUnequipReserve(soldierList, armoryByArmyVal) {
  let equipLists = {}
  let toReplace = {}
  massUnequipSoldierList(soldierList, equipLists, toReplace)
  let soldier = soldierList.findvalue(@(_) true)
  let armyId = soldier != null ? getLinkedArmyName(soldier) : ""
  let equipListsBySoldier = calcExchange(equipLists, toReplace, armoryByArmyVal?[armyId] ?? [])
  if (equipListsBySoldier.len() > 0)
    massEquipItems(equipListsBySoldier)
}

let closeNeeded = keepref(Computed(@() room.value != null && !roomIsLobby.value
  && !(room.value?.gameStarted ?? false)))

closeNeeded.subscribe(@(v) v ? itemClear() : null)

return {
  viewItem
  curInventoryItem
  curEquippedItem
  selectParams
  selectParamsArmyId
  inventoryItems
  slotItems
  otherSlotItems //items fit to current slot, but not fit to current soldier class
  paramsForPrevItems
  prevItems //when choose mod of not equipped item from items list

  openSelectItem = kwarg(openSelectItem)
  trySelectNext = @() selectInsideListSlot(1, true)
  selectNextSlot = @() selectSlot(1)
  selectPreviousSlot = @() selectSlot(-1)
  itemClear
  markLastViewedSlot
  checkSelectItem
  selectItem
  ItemCheckResult

  curCanUnequipSoldiersList
  getPossibleEquipList
  getPossibleUnequipList
  getAlternativeEquipList
  getBetterItem
  getWorseItem
  autoSelectTemplate
  massUnequipArmyReserve
  massUnequipReserve

  MAX_ITEM_BR
}
