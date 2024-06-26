from "%enlSqGlob/ui/ui_library.nut" import *

let { fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let spinner = require("%ui/components/spinner.nut")
let { Bordered } = require("%ui/components/txtButton.nut")
let {
  commonBorderRadius, disabledBgColor, leftAppearanceAnim, defItemBlur, fullTransparentBgColor,
  smallPadding, midPadding, defTxtColor
} = require("%enlSqGlob/ui/designConst.nut")
let { curArmy, objInfoByGuid, squadsByArmy, canChangeEquipmentInSlot
} = require("model/state.nut")
let { classSlotLocksByArmy } = require("%enlist/researches/researchesSummary.nut")
let { equipSlotRows } = require("model/config/equipGroups.nut")
let { openSelectItem } = require("model/selectItemState.nut")
let mkItemWithMods = require("mkItemWithMods.nut")
let { ItemNotifiers } = require("components/itemComp.nut")
let { mkSoldierSlotsComp } = require("model/soldierSlotsCount.nut")
let { getLinkedArmyName, getLinkedSquadGuid } = require("%enlSqGlob/ui/metalink.nut")
let { betterWeaponrySoldier, soldierSeenSlots } = require("model/unseenWeaponry.nut")
let { campItemsByLink } = require("%enlist/meta/profile.nut")
let { getErrorSlots } = require("%enlSqGlob/ui/itemsInfo.nut")
let { isItemActionInProgress } = require("model/itemActions.nut")
let { getItemSlotsWithPreset } = require("%enlist/preset/presetEquipUtils.nut")
let { togglePresetEquipBlock, previewPreset } = require("%enlist/preset/presetEquipUi.nut")
let { goodManageData } = require("%enlist/shop/armyShopState.nut")
let { manageBlinkingObject } = require("%enlSqGlob/ui/blinkingIcon.nut")


//const opacityForDisabledItems = 0.3
//const MAX_ITEMS_IN_ROW = 4
//const MAX_SLOT_TYPES_IN_ROW = 3
let waitingSpinner = spinner(hdpx(25))

function openEquipMenu(p /*onClick params from mkItem*/) {
  openSelectItem({
    armyId = curArmy.value
    ownerGuid = p?.soldierGuid
    slotType = p?.slotType
    slotId = p?.slotId
  })
}

let mkItem = @(params) mkItemWithMods(params)
  .__merge({ size = [flex(), params.itemSize[1]] })

function collectSlots(slotType, totalSlots, slotsItems, soldierGuid) {
  let soldierData = objInfoByGuid.value?[soldierGuid]
  local isAvailable = true
  if (soldierData && slotType) {
    let armyId = getLinkedArmyName(soldierData)
    let { sClass = "unknown" } = soldierData
    isAvailable = (classSlotLocksByArmy.value?[armyId][sClass] ?? []).indexof(slotType) == null
  }

  let emptySlot = { item = null, slotType = slotType, slotId = -1, isLocked = !isAvailable,
    canDrag = true }
  let slots = slotsItems.filter(@(s) s.slotType == slotType)
    .map(@(s) emptySlot.__merge(s))
  if (totalSlots <= 0)
    return slots.len() > 0 ? slots : [emptySlot]

  let slotsMap = {}
  slots.each(@(s) slotsMap[s.slotId] <- s)
  return array(totalSlots).map(@(_, slotId) slotId < totalSlots
    ? slotsMap?[slotId] ?? emptySlot.__merge({ slotId = slotId })
    : emptySlot.__merge({ slotId = slotId, isLocked = true }))
}

let lockIconSize = hdpxi(32)
let lockObjSize = hdpx(50)

let mkLockedBlock = @(color) {
  rendObj = ROBJ_WORLD_BLUR
  size = flex()
  fillColor = color
  color = defItemBlur
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = [
    {
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(2)
      color = fullTransparentBgColor
      opacity = 0.05
      commands = [[ VECTOR_LINE, 0, 0, 100, 100 ], [ VECTOR_LINE, 0, 100, 100, 0 ]]
    }
    {
      size = [lockObjSize, lockObjSize]
      rendObj = ROBJ_VECTOR_CANVAS
      commands = [[ VECTOR_ELLIPSE, 50, 50, 50, 50 ]]
      fillColor = color
      color
    }
    {
      rendObj = ROBJ_IMAGE
      size = array(2, lockIconSize)
      image = Picture($"ui/skin#locked_icon.svg:{lockIconSize}:{lockIconSize}:K")
      color = fullTransparentBgColor
      opacity = 0.05
    }
  ]
}


let mkDisabledSlot = @(slotSize) {
  size = slotSize
  rendObj = ROBJ_BOX
  fillColor = disabledBgColor
  borderRadius = commonBorderRadius
  children = mkLockedBlock(disabledBgColor)
}

let mkParatrooperSlot = @(slotSize, headerText) {
  flow = FLOW_VERTICAL
  children = [
    headerText == "" ? null
      : {
          size = [flex(), SIZE_TO_CONTENT]
          children = {
            rendObj = ROBJ_TEXT
            text = headerText
          }.__update(fontSub)
        }
    {
      size = slotSize
      rendObj = ROBJ_BOX
      fillColor = 0x40052060
      borderRadius = commonBorderRadius

      children = {
        rendObj = ROBJ_TEXT
        text = loc("slot/equipInBattle")
        margin = smallPadding
        color = defTxtColor
        vplace = ALIGN_BOTTOM
        hplace = ALIGN_LEFT
        opacity = 0.5
      }.__update(fontSub)
    }
  ]
}


function mkSlot(rowIdx, slotData, guid) {
  let { slotSize, slotCtor = null, scheme = null } = slotData
  let key = $"slot_{guid}_{rowIdx}"

  if (slotData?.isParatrooperSlot)
    return mkParatrooperSlot(slotSize, loc(slotData.headerLocId))
      .__update({ key }, leftAppearanceAnim(0.05 * rowIdx))
  if (scheme == null || slotCtor == null)
    return mkDisabledSlot(slotSize).__update({ key }, leftAppearanceAnim(0.05 * rowIdx))

  return slotCtor(slotData)
    .__update(leftAppearanceAnim(0.05 * rowIdx), { key } )
}


function mkSlotsList(slotData, soldier, canManage, slotsCount, slotsItems,
  maxSlotIndex, slotCtor, objectsByGuid
) {
  let { slotType, slotSize, slotImg, hasName = false, headerLocId = "" } = slotData

  let { equipScheme = {}, guid, sClass } = soldier

  let availableType = slotType in equipScheme
    ? slotType
    : equipScheme.findindex(@(v) v?.ingameWeaponSlot == slotType)

  if (availableType == null)
    return []

  let errorSlotTypes = getErrorSlots(slotsItems, equipScheme)

  let curSlotsCount = slotsCount.value?[availableType] ?? 0
  let scheme = equipScheme?[availableType]
  let { isDisabled = false } = scheme
  let hasWarning = errorSlotTypes?[availableType] ?? false

  let needShowUnseenIcon = canChangeEquipmentInSlot(sClass, availableType)

  local isParatrooperSlot = false
  if (slotType == "secondary") {
    let squadGuid = getLinkedSquadGuid(soldier)
    let soldierSquad = squadsByArmy.value?[curArmy.value].findvalue(@(v) v.guid == squadGuid)
    isParatrooperSlot = soldierSquad?.isParatroopers ?? false
  }

  let slotsList = collectSlots(availableType, max(curSlotsCount, maxSlotIndex), slotsItems, guid)
  slotsList.each(function(s) {
    let item = objectsByGuid?[s.item?.guid] ?? s.item
    s.__update({
      item, scheme, isDisabled, hasWarning, canManage, soldierGuid = guid,
      slotSize, slotCtor, hasName, headerLocId, slotImg, isParatrooperSlot
      itemSize = slotSize
      isLocked = s.isLocked || s.slotId >= curSlotsCount
    })
    if (needShowUnseenIcon) {
      s.notifierState <- Computed(@() availableType not in (betterWeaponrySoldier.value?[guid] ?? {})
        ? ItemNotifiers.EMPTY
        : availableType in soldierSeenSlots.value?[guid]
          ? ItemNotifiers.BETTER_ITEM
          : ItemNotifiers.UNSEEN_BETTER_ITEM
        )
    }
  })
  return slotsList
}


let mkEquipRow = @(equipRow, rowIdx, soldier, canManage, slotsCount, slotsItems,
    slotCtor, manageSlotType)
  function() {
    let slotsList = []
    let { guid } = soldier

    foreach (slotData in equipRow) {
      if ("slotType" in slotData)
        slotsList.extend(
          mkSlotsList(slotData, soldier, canManage, slotsCount, slotsItems, 0,
            slotCtor, objInfoByGuid.value)
        )
      else {
        let { unitedSlots = [], slots = 1 } = slotData
        foreach (sData in unitedSlots) {
          slotsList.extend(
            mkSlotsList(sData, soldier, canManage, slotsCount, slotsItems, slots,
              slotCtor, objInfoByGuid.value)
          )
        }
      }
    }

    return {
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_HORIZONTAL
      gap = midPadding
      valign = ALIGN_BOTTOM
      watch = [objInfoByGuid, campItemsByLink, previewPreset]
      children = slotsList.map(function(slot) {
        let hasManageBlink = slot?.slotType == manageSlotType
        return {
          size = [flex(), SIZE_TO_CONTENT]
          children = [
            mkSlot(rowIdx, slot, guid)
            hasManageBlink ? manageBlinkingObject : null
          ]
        }
      })
    }
  }

let mkEquipPresetBtn = @() {
  watch = isItemActionInProgress
  size = [flex(), SIZE_TO_CONTENT]
  halign = ALIGN_CENTER
  children = isItemActionInProgress.value
    ? waitingSpinner
    : Bordered(loc("preset/equip/open"), togglePresetEquipBlock, {
        btnWidth = flex()
      })
}

let soldierEquip = @(soldier, canManage = true, selectedKeyWatch = Watched(null),
  onDoubleClickCb = null, onResearchClickCb = null, dropExceptionCb = null
) function() {
    let itemCtor = @(p) mkItem(p.__merge({
      onClickCb = openEquipMenu
      selectedKey = selectedKeyWatch
      onDoubleClickCb = onDoubleClickCb
      onDropExceptionCb = dropExceptionCb
      onResearchClickCb = onResearchClickCb
    }))

    let slotsCount = mkSoldierSlotsComp(soldier.value.guid, soldier.value?.equipScheme ?? {})
    let slotsItems = getItemSlotsWithPreset(soldier.value,
      campItemsByLink.value, previewPreset.value)

    let { manageSlotType = null } = goodManageData.value
    local rowIdx = 0
    let children = equipSlotRows.map(@(slotGroup) {
      flow = FLOW_VERTICAL
      gap = midPadding
      size = [flex(), SIZE_TO_CONTENT]
      children = slotGroup.map(@(equipRow)
        mkEquipRow(equipRow, rowIdx++, soldier.value, canManage,
          slotsCount, slotsItems, itemCtor, manageSlotType))
    })

    children.append(mkEquipPresetBtn)

    return {
      watch = [soldier, previewPreset, goodManageData]
      flow = FLOW_VERTICAL
      size = flex()
      gap = midPadding
      children = [
        {
          size = flex()
          gap = midPadding * 2
          flow = FLOW_VERTICAL
          children
        }
      ]
    }
}

return kwarg(soldierEquip)