from "%enlSqGlob/ui/ui_library.nut" import *

let { fontBody, fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let {round_by_value} = require("%sqstd/math.nut")
let { blinkUnseenIcon } = require("%ui/components/unseenSignal.nut")
let { showMsgbox } = require("%enlist/components/msgbox.nut")
let { markSeenUpgrades, curUnseenAvailableUpgrades, isUpgradeUsed
} = require("model/unseenUpgrades.nut")
let { defLockedSlotBgColor, defTxtColor, activeTxtColor, blurBgColor,
  blurBgFillColor, unitSize, midPadding, smallPadding, tinyOffset
} = require("%enlSqGlob/ui/designConst.nut")
let { safeAreaBorders } = require("%enlist/options/safeAreaState.nut")
let { isGamepad } = require("%ui/control/active_controls.nut")
let { Flat, PrimaryFlat } = require("%ui/components/textButton.nut")
let { Bordered } = require("%ui/components/txtButton.nut")
let { makeVertScroll } = require("%ui/components/scrollbar.nut")
let { statusIconCtor } = require("%enlSqGlob/ui/itemPkg.nut")
let { ItemNotifiers } = require("components/itemComp.nut")
let { mkItemDemands, mkItemListDemands } = require("model/mkItemDemands.nut")
let { sceneWithCameraAdd, sceneWithCameraRemove } = require("%enlist/sceneWithCamera.nut")
let { itemTypesInSlots } = require("model/all_items_templates.nut")
let closeBtnBase = require("%ui/components/closeBtn.nut")
let { mkViewItemDetails, lockedInfo } = require("components/itemDetailsComp.nut")
let { curUpgradeDiscount, campPresentation } = require("%enlist/campaigns/campaignConfig.nut")
let { setTooltip, normalTooltipTop } = require("%ui/style/cursors.nut")
let spinner = require("%ui/components/spinner.nut")
let mkHeader = require("%enlist/components/mkHeader.nut")
let mkToggleHeader = require("%enlist/components/mkToggleHeader.nut")

let { requestCratesContent } = require("%enlist/soldiers/model/cratesContent.nut")
let defcomps = require("%enlSqGlob/ui/defcomps.nut")
let mkItemWithMods = require("mkItemWithMods.nut")
let { mkSoldierInfo } = require("mkSoldierInfo.nut")
let { soldierClasses } = require("%enlSqGlob/ui/soldierClasses.nut")
let { getSoldierItemSlots, getEquippedItemGuid, armySquadsById
} = require("%enlist/soldiers/model/state.nut")
let { campItemsByLink } = require("%enlist/meta/profile.nut")
let { isItemActionInProgress } = require("model/itemActions.nut")
let { jumpToArmyProgress, jumpToArmyGrowth } = require("%enlist/mainMenu/sectionsState.nut")
let { curHoveredItem, changeCameraFov } = require("%enlist/showState.nut")
let { focusResearch, findResearchesUpgradeUnlock, findSlotUnlockRequirement, getClosestResearch
} = require("%enlist/researches/researchesFocus.nut")
let { allResearchStatus } = require("%enlist/researches/researchesState.nut")
let { getSortedGrowthsByResearch } = require("%enlist/growth/growthState.nut")
let { unequipItem, unequipBySlot } = require("%enlist/soldiers/unequipItem.nut")
let { slotItems, otherSlotItems, prevItems, selectParams, selectParamsArmyId, curEquippedItem,
  viewItem, paramsForPrevItems, openSelectItem, trySelectNext, curInventoryItem, checkSelectItem,
  selectItem, itemClear, markLastViewedSlot, selectNextSlot, selectPreviousSlot, ItemCheckResult
} = require("model/selectItemState.nut")
let { soldierSlotsTiersEquipped } = require("model/unseenWeaponry.nut")
let { curSoldierInfo } = require("%enlist/soldiers/model/curSoldiersState.nut")
let hoverHoldAction = require("%darg/helpers/hoverHoldAction.nut")
let { openUpgradeItemMsg, openDisposeItemMsg } = require("components/modifyItemComp.nut")
let { curArmySquadsUnlocks, scrollToCampaignLvl } = require("model/armyUnlocksState.nut")
let { mkItemUpgradeData, mkItemDisposeData } = require("model/mkItemModifyData.nut")
let gotoResearchUpgradeMsgBox = require("researchUpgradeMsgBox.nut")
let { justPurchasedItems } = require("model/newItemsToShow.nut")
let { getShopItemsCmp } = require("%enlist/shop/armyShopState.nut")
let { mkOnlinePersistentFlag } = require("%enlist/options/mkOnlinePersistentFlag.nut")
let openArmoryTutorial = require("%enlist/tutorial/armoryTutorial.nut")
let isNewbie = require("%enlist/unlocks/isNewbie.nut")
let { isDetailsFull, detailsModeCheckbox } = require("%enlist/items/detailsMode.nut")
let { isObjGuidBelongToRentedSquad } = require("%enlist/soldiers/model/squadInfoState.nut")
let { showRentedSquadLimitsBox } = require("%enlist/soldiers/components/squadsComps.nut")
let clickShopItem = require("%enlist/shop/clickShopItem.nut")
let { mkPresetEquipBlock } = require("%enlist/preset/presetEquipUi.nut")
let { isChangesBlocked } = require("%enlist/quickMatchQueue.nut")
let { sound_play } = require("%dngscripts/sound_system.nut")

const ADD_CAMERA_FOV_MIN = -15
const ADD_CAMERA_FOV_MAX = 15


let armoryWndOpenFlag = mkOnlinePersistentFlag("armoryWndOpenFlag")
let armoryWndHasBeenOpend = armoryWndOpenFlag.flag
let markSeenArmoryTutorial = armoryWndOpenFlag.activate
let waitingSpinner = spinner(hdpx(25))

let getItemSelectKey = @(item) item?.isShopItem ? item?.basetpl : item?.guid
let unseenIcon =  blinkUnseenIcon(0.8).__update({ hplace = ALIGN_RIGHT })

let selectedKey = Watched(null)
viewItem.subscribe(function(item) {
  selectedKey(getItemSelectKey(item))
  changeCameraFov(0)
})

let selectedSlot = Computed(function() {
  let { ownerGuid = null, slotType = null, slotId = null } = selectParams.value
  local guid = null
  if (ownerGuid && slotType)
    guid = getEquippedItemGuid(campItemsByLink.value, ownerGuid, slotType, slotId)
  return guid ?? "_".concat(ownerGuid, slotType, slotId)
})

let defStatusCtor = function(item, soldierWatch) {
  let demandsWatch = mkItemDemands(item)
  return @() {
    watch = [demandsWatch, soldierWatch]
    children = statusIconCtor(demandsWatch.value)
  }
}

function txt(text) {
  let children = (type(text) == "string")
    ? defcomps.txt({text}.__update(fontSub))
    : defcomps.txt(text)
  return { children }
}

let activeItemParams = {
  statusCtor = defStatusCtor
}

let blockedItemParams = {
  bgColor = defLockedSlotBgColor
  statusCtor = defStatusCtor
  canEquip = false
  onDoubleClickCb = null
}

let prevItemParams = {
  statusCtor = defStatusCtor
  selectedKey = selectedSlot
  onClickCb = function(data) {
    let prev = paramsForPrevItems.value
    let { soldierGuid = "" } = data
    if (soldierGuid != "") //data.item is item mod
      openSelectItem({
        armyId = prev?.armyId
        ownerGuid = soldierGuid
        slotType = data.slotType
        slotId = data.slotId
      })
    else
      curInventoryItem(data.item)
  }
  canEquip = false
  onDoubleClickCb = unequipItem
}

function processItemDrop(item, checkInfo) {
  let { result, soldier = null, slotType = null, soldierClass = null, level = null } = checkInfo
  let buttons = [{ text = loc("Ok"), isCancel = true }]
  local text = ""
  if (result == ItemCheckResult.NEED_RESEARCH) {
    let { research = null, squadId = null } = findSlotUnlockRequirement(soldier, slotType)
    if (research != null) {
      text = loc("slotClassResearch", { soldierClass })
      buttons.append({
        text = loc("GoToResearch")
        action = @() focusResearch(research)
        isCurrent = true })
    }
    else if (squadId != null) {
      let unlock = curArmySquadsUnlocks.value
        .findvalue(@(u) u.unlockType == "squad" && u.unlockId == squadId)
      if (unlock != null) {
        text = loc("obtainAtLevel", { level = unlock.level })
        buttons.append({
          text = loc("GoToArmyLeveling")
          action = function() {
            scrollToCampaignLvl(unlock.level)
            jumpToArmyProgress()
          }
          isCurrent = true })
      }
    }

  } else if (result == ItemCheckResult.WRONG_CLASS){
    text = loc("Not available for class", { soldierClass })

  } else if (result == ItemCheckResult.NEED_LEVEL){
    text = loc("obtainAtLevel", { level })
    buttons.append({
      text = loc("GoToArmyLeveling")
      action = function() {
        scrollToCampaignLvl(level)
        jumpToArmyProgress()
      }
      isCurrent = true })

  } else if (result == ItemCheckResult.IN_SHOP) {
    // open purchase window instead of message box
    let shopItemsCmp = getShopItemsCmp(item.basetpl).value?[0]
    if (shopItemsCmp)
      clickShopItem(shopItemsCmp)
    return
  }
  showMsgbox({ text, buttons })
}

let dropExceptionCb = function(dropItem) {
  let checkDropItem = checkSelectItem(dropItem)
  if (checkDropItem)
    processItemDrop(dropItem, checkDropItem)
}

let mkStdCtorData = @(itemSize) {
  size = itemSize
  itemsInRow = 1
  ctor = @(item, override) mkItemWithMods({
    isXmb = true
    item = item
    itemSize
    canDrag = !!item?.basetpl
    selectedKey = selectedKey
    selectKey = getItemSelectKey(item)
    onClickCb = @(data) data.item == item ? curInventoryItem(item)
      : (item?.guid ?? "") != "" ? openSelectItem({ // data.item is mod of item
          armyId = selectParamsArmyId.value
          ownerGuid = item.guid
          slotType = data.slotType
          slotId = data.slotId
        })
      : null
    onDropExceptionCb = dropExceptionCb
    onDoubleClickCb = function(data) {
      if (data.item != item)
        return
      let checkSelectInfo = checkSelectItem(item)
      if (checkSelectInfo){
        processItemDrop(item, checkSelectInfo)
        return
      }
      selectItem(item)
      trySelectNext()
      sound_play("ui/inventory_item_place")
    }
  }.__update(override))
}

let defaultCtorData = mkStdCtorData([3.8 * unitSize, 2.2 * unitSize]).__update({ itemsInRow = 2 })

let mainWeaponCtorData = mkStdCtorData([9.0 * unitSize, 2.2 * unitSize])

let getCtorData = @(typesInSlots, itemType)
  itemType in typesInSlots.mainWeapon ? mainWeaponCtorData : defaultCtorData

let mkItemsList = @(listWatch, itemParamsOverride) function() {
  itemParamsOverride.soldierGuid <- curSoldierInfo.value?.guid
  let items = listWatch.value
  let ctorData = getCtorData(itemTypesInSlots.value, items?[0].itemtype)
  let { size, itemsInRow } = ctorData
  let itemContainerWidth = itemsInRow * size[0] + (itemsInRow - 1) * midPadding
  return wrap(
    items.map(@(item) (getCtorData(itemTypesInSlots.value, item?.itemtype) ?? ctorData).ctor(item, itemParamsOverride)),
    { width = itemContainerWidth, hGap = smallPadding, vGap = smallPadding, hplace = ALIGN_CENTER }
  ).__update({ watch = [listWatch, itemTypesInSlots, curSoldierInfo] })
}

let sortDemandsOrder = @(d) d?.canObtainInShop == true ? 2000
  : d?.classLimit != null ? 1500
  : "levelLimit" in d ? 1000 - d.levelLimit
  : 0

function sortByDemands(a, b) {
  return (b == "") <=> (a == "")
    || sortDemandsOrder(b) <=> sortDemandsOrder(a)
}

function mkDemandHeader(demand) {
  let key = demand.keys()?[0]
  let value = demand?[key]
  let suffix = value == true ? "_yes"
    : value == false ? "_no"
    : ""
  return {
    rendObj = ROBJ_TEXT
    size = [flex(), SIZE_TO_CONTENT]
    margin = [tinyOffset, 0, 0, 0]
    text = demand?.lockTxt ?? loc($"itemDemandsHeader/{key}{suffix}", demand)
    color = defTxtColor
  }.__update(fontSub)
}

let mkItemsGroupedList = kwarg(@(listWatch, overrideParams, newWatch, onlyNew = false,
  noHeaders = false
) function() {
    overrideParams.soldierGuid <- curSoldierInfo.value?.guid

    let newList = newWatch.value
    let itemsToDisplay = listWatch.value
      .filter(@(i) !onlyNew || newList.contains(i.guid))

    let itemsWithDemands = mkItemListDemands(itemsToDisplay)
    let itemsDemands = itemsWithDemands.value
    let ctorData = getCtorData(itemTypesInSlots.value, itemsDemands?[0].item.itemtype)
    let { size, itemsInRow } = ctorData
    let itemContainerWidth = itemsInRow * size[0] + (itemsInRow - 1) * midPadding

    let { ownerGuid = null, slotType = null } = selectParams.value
    let isShowClassesHint = slotType == "primary" || slotType == "secondary"
    let groupedItems = {}
    foreach (data in itemsDemands) {
      let { item, demands = "" } = data
      groupedItems[demands] <- (groupedItems?[demands] ?? []).append(item)
    }
    let children = []
    let demandsOrdered = groupedItems.keys().sort(sortByDemands)
    foreach (demand in demandsOrdered) {
      if (demand != "" && !noHeaders)
        children.append(mkDemandHeader(demand))

      let itemsList = groupedItems[demand].map(function(item) {
          let ctor = (getCtorData(itemTypesInSlots.value, item?.itemtype) ?? ctorData).ctor
          let { tier = 0, isShopItem = false } = item
          let notifierState = Computed(@() !isShopItem
            && tier > (soldierSlotsTiersEquipped.value?[ownerGuid][slotType] ?? -1)
              ? ItemNotifiers.BETTER_ITEM : ItemNotifiers.EMPTY)
          return ctor(item,
            overrideParams.__merge({
              isNew = onlyNew
              isShowClassesHint
              notifierState
            }))
        })

      children.append(wrap(itemsList, {
        width = itemContainerWidth, hGap = smallPadding, vGap = smallPadding, hplace = ALIGN_CENTER
      }))
    }
    return {
      watch = [listWatch, itemTypesInSlots, curSoldierInfo, itemsWithDemands, selectParams]
      size = [itemContainerWidth, SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      gap = smallPadding
      children = children
    }
  })

let armoryList = mkItemsGroupedList({
  listWatch = slotItems
  overrideParams = activeItemParams
  newWatch = justPurchasedItems
})
let otherList = mkItemsGroupedList({
  listWatch = otherSlotItems
  overrideParams = blockedItemParams
  newWatch = justPurchasedItems
  noHeaders = true
})
let otherListNewOnly = mkItemsGroupedList({
  listWatch = otherSlotItems
  overrideParams = blockedItemParams
  newWatch = justPurchasedItems
  onlyNew = true
})

let prevArmory = mkItemsList(prevItems, prevItemParams)

function onBackAction() {
  markLastViewedSlot()
  itemClear()
}

let backButton = Bordered(loc("mainmenu/btnBack"), onBackAction,
  { margin = [0, midPadding, 0, 0] })

function mkChooseButtonUi(item) {
  return function() {
    let res = { watch = [curEquippedItem, isItemActionInProgress, isChangesBlocked] }
    let equippedItem = curEquippedItem.value
    if (item == equippedItem
        || (equippedItem == null && item?.basetpl == null)
        || checkSelectItem(item) != null)
      return res
    return res.__update({
      margin = [0, 0, 0, midPadding]
      children = PrimaryFlat(
        loc("mainmenu/btnSelect"),
        @() selectItem(item),
        {
          margin = 0
          hotkeys = [[ "^J:Y" ]]
          isEnabled = !isItemActionInProgress.value && !isChangesBlocked.value
        }.__update(fontBody)
      )
    })
  }
}


function mkObtainButton(item) {
  if (item == null || item?.basetpl == null)
    return null

  let demands = mkItemDemands(item)
  let shopItemsCmp = getShopItemsCmp(item.basetpl)
  let isWrongClass = checkSelectItem(item)?.result == ItemCheckResult.WRONG_CLASS

  return function() {
    let { levelLimit = null } = demands.value
    let shopItem = shopItemsCmp.value?[0]
    return {
      watch = [demands, shopItemsCmp, isItemActionInProgress]
      margin = [0, 0, 0, midPadding]
      children = levelLimit != null ? Flat(loc("GoToArmyLeveling"),
          function() {
            scrollToCampaignLvl(item.unlocklevel)
            jumpToArmyProgress()
          },
          {
            margin = 0
            hotkeys = [["^J:X"]]
            isEnabled = !isItemActionInProgress.value
          }
        )
      : shopItem != null ? Flat(loc("btn/buy"),
          function() {
            let crates = shopItem?.crates ?? []
            requestCratesContent(crates)
            clickShopItem(shopItem, isWrongClass)
          },
          {
            margin = 0
            hotkeys = [["^J:X"]]
            isEnabled = !isItemActionInProgress.value
          }
        )
      : null
  }}
}

let mkListToggleHeader = @(sClass, flag) mkToggleHeader(flag
  loc("Not available for class", { soldierClass = loc(soldierClasses?[sClass].locId ?? "unknown") }))

function otherItemsBlock() {
  let res = { watch = [curSoldierInfo, otherSlotItems] }
  if (otherSlotItems.value.len() == 0)
    return res

  let isListExpanded = Watched(false)
  let sClass = curSoldierInfo.value?.sClass ?? "unknown"
  return res.__update({
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = smallPadding
    children = [
      mkListToggleHeader(sClass, isListExpanded)
      @() {
        watch = isListExpanded
        children = isListExpanded.value ? otherList : otherListNewOnly
      }
    ]
  })
}

let mkItemsListBlock = @(children) {
  size = [SIZE_TO_CONTENT, flex()]
  padding = [midPadding, smallPadding]
  rendObj = ROBJ_WORLD_BLUR_PANEL
  color = blurBgColor
  fillColor = blurBgFillColor
  behavior = [Behaviors.DragAndDrop]
  xmbNode = XmbContainer({
    canFocus = false
    scrollSpeed = 5.0
    isViewport = true
  })
  children = makeVertScroll(children, {
    size = [SIZE_TO_CONTENT, flex()]
    needReservePlace = false
  })
  canDrop = @(data) data?.slotType != null
  onDrop = @(data) unequipItem(data)
}

let itemsListBlock = @() {
  size = [SIZE_TO_CONTENT, flex()]
  watch = [slotItems, otherSlotItems]
  children = slotItems.value.len() > 0 || otherSlotItems.value.len() > 0
    ? mkItemsListBlock({
        flow = FLOW_VERTICAL
        children = [
          armoryList
          otherItemsBlock
        ]
      })
    : null
}

let prevItemsListBlock = @() {
  size = [SIZE_TO_CONTENT, flex()]
  watch = prevItems
  children = prevItems.value.len()
    ? mkItemsListBlock(prevArmory)
    : null
}

// TODO same as vehicleDetails.ui.nut, should be joined in one module
let openResearchGrowthMsgbox = @(growth) showMsgbox({
  text = loc("itemUpgradeNoSquad", { squad = loc($"squad/{growth.reward.squadId}") })
  buttons = [
    {
      text = loc("GoToGrowth")
      action = @() jumpToArmyGrowth(growth.id)
      isCurrent = true
    }
    { text = loc("Close"), isCancel = true }
  ]
})

let openResearchUpgradeMsgbox = @(research) showMsgbox({
  text = loc("itemUpgradeResearch")
  buttons = [
    {
      text = loc("mainmenu/btnResearch")
      action = @() focusResearch(research)
      isCurrent = true
    }
    { text = loc("Close"), isCancel = true }
  ]
})


function mkUpgradeBtn(item) {
  let upgradeDataWatch = mkItemUpgradeData(item)
  return function() {
    let res = {
      watch = [upgradeDataWatch, curUnseenAvailableUpgrades, isUpgradeUsed,
        curUpgradeDiscount, campPresentation, isItemActionInProgress]
    }
    let upgradeData = upgradeDataWatch.value
    if (!upgradeData.isUpgradable)
      return res

    let { isResearchRequired, armyId, hasEnoughOrders, upgradeMult, itemBaseTpl } = upgradeData

    if (isResearchRequired) {
      local researchCb = null
      let researches = findResearchesUpgradeUnlock(armyId, item)
      let growthList = getSortedGrowthsByResearch(armyId, researches?[0])
      let squads = growthList.map(@(v) v.reward.squadId)
      let researchedSquad = squads.findvalue(@(squad) squad in armySquadsById.value?[armyId])
      let growth = growthList?[0]

      if (researchedSquad == null && growth != null)
        researchCb = @() openResearchGrowthMsgbox(growth)
      else {
        let research = getClosestResearch(armyId, researches, allResearchStatus.value?[armyId] ?? {})
        if (research != null)
          researchCb = @() openResearchUpgradeMsgbox(research)
      }

      return researchCb == null ? res : res.__update({
        margin = [0, 0, 0, midPadding]
        children = Flat(loc("btn/upgrade"), researchCb, {
          margin = 0
          cursor = normalTooltipTop
          onHover = @(on) setTooltip(on ? loc("tip/btnUpgrade") : null)
          isEnabled = !isItemActionInProgress.value
        })
      })
    }

    let bCtor = hasEnoughOrders ? PrimaryFlat : Flat
    let discount = round_by_value(100 - upgradeMult * 100, 1).tointeger()
    let upgradeMultInfo = discount <= 0 ? null : txt({
      text = loc("upgradeDiscount", { discount })
      color = activeTxtColor
    }).__update(curUpgradeDiscount.value > 0.0 ? {
      rendObj = ROBJ_SOLID
      color = campPresentation.value?.darkColor
    } : {})
    return res.__update({
      flow = FLOW_VERTICAL
      gap = midPadding
      halign = ALIGN_CENTER
      margin = [0, 0, 0, midPadding]
      children = [
        upgradeMultInfo
        {
          children = [
            bCtor(loc("btn/upgrade"),
              function() {
                if (isObjGuidBelongToRentedSquad(item?.guid))
                  showRentedSquadLimitsBox()
                else
                  openUpgradeItemMsg(item, upgradeData)
              },
              {
                margin = 0
                cursor = normalTooltipTop
                onHover = function(on) {
                  if (!isUpgradeUsed.value && item?.basetpl in curUnseenAvailableUpgrades.value)
                    hoverHoldAction("unseenUpdate", itemBaseTpl,
                      @(tpl) markSeenUpgrades(selectParamsArmyId.value, [tpl]))(on)
                  setTooltip(on ? loc("tip/btnUpgrade") : null)
                }
                isEnabled = !isItemActionInProgress.value
              })
            !isUpgradeUsed.value && item?.basetpl in curUnseenAvailableUpgrades.value
              ? unseenIcon
              : null
          ]
        }
      ]
    })
  }
}

function mkDisposeBtn(item) {
  let disposeDataWatch = mkItemDisposeData(item)
  return function() {
    let res = { watch = [disposeDataWatch, isItemActionInProgress] }
    let disposeData = disposeDataWatch.value
    if (!disposeData.isDisposable)
      return res

    let { disposeMult, isDestructible = false, isRecyclable = false } = disposeData

    let bonus = round_by_value(disposeMult * 100 - 100, 1).tointeger()
    let disposeMultInfo = bonus <= 0 ? null : txt({
      text = loc("disposeBonus", { bonus })
      color = activeTxtColor
    })
    return res.__update({
      flow = FLOW_VERTICAL
      gap = midPadding
      halign = ALIGN_CENTER
      margin = [0, 0, 0, midPadding]
      children = [
        disposeMultInfo
        Flat(loc(isRecyclable ? "btn/recycle" : isDestructible ? "btn/dispose" : "btn/downgrade"),
          @() openDisposeItemMsg(item, disposeData), {
            cursor = normalTooltipTop
            onHover = @(on)
              setTooltip(on ? loc(isRecyclable ? "tip/btnRecycle"
                  : isDestructible ? "tip/btnDispose"
                  : "tip/btnDowngrade")
                : null)
            margin = 0
            isEnabled = !isItemActionInProgress.value
          })
      ]
    })
  }
}

let waitingSpinnerUi = @() {
  watch = isItemActionInProgress
  size = [SIZE_TO_CONTENT, flex()]
  margin = midPadding
  children = isItemActionInProgress.value ? waitingSpinner : null
}

let buttonsUi = @() {
  watch = viewItem
  hplace = ALIGN_RIGHT
  flow = FLOW_HORIZONTAL
  valign = ALIGN_BOTTOM
  children = [
    waitingSpinnerUi
    mkDisposeBtn(viewItem.value)
    mkUpgradeBtn(viewItem.value)
    mkObtainButton(viewItem.value)
    mkChooseButtonUi(viewItem.value)
  ]
}

function mkDemandsInfo(item) {
  if (item == null)
    return null

  let demandsWatch = mkItemDemands(item)
  return @() {
    watch = demandsWatch
    size = [flex(), SIZE_TO_CONTENT]
    padding = smallPadding
    children = lockedInfo(demandsWatch.value)
  }
}


let infoBlock = @() {
  watch = viewItem
  size = flex()
  flow = FLOW_VERTICAL
  valign = ALIGN_BOTTOM
  halign = ALIGN_RIGHT
  gap = midPadding
  children = [
    mkViewItemDetails(viewItem.value, isDetailsFull, fsh(80))
    mkDemandsInfo(viewItem.value)
    detailsModeCheckbox
    buttonsUi
  ]
}


let animations = [
  { prop = AnimProp.opacity, from = 0, to = 1, duration = 0.5, play = true, easing = OutCubic }
  { prop = AnimProp.translate, from =[-hdpx(150), 0], play = true, to = [0, 0], duration = 0.2, easing = OutQuad }
  { prop = AnimProp.opacity, from = 1, to = 0, duration = 0.2, playFadeOut = true, easing = OutCubic }
  { prop = AnimProp.translate, from =[0, 0], playFadeOut = true, to = [-hdpx(150), 0], duration = 0.2, easing = OutQuad }
]

function getItemSlot(item, soldier) {
  if (!item || !soldier)
    return null
  let ownerGuid = soldier.guid
  let itemSlot = getSoldierItemSlots(ownerGuid, campItemsByLink.value)
    .findvalue(@(slot) slot.item?.guid == item?.guid)
  if (!itemSlot)
    return null
  local { slotType, slotId } = itemSlot
  if (slotId == null) {
    let equipScheme = soldier?.equipScheme ?? {}
    slotId = slotType
    slotType = equipScheme.findindex(@(val) slotType in val)
    if (slotType == null)
      return null
  }
  return {
    ownerGuid = ownerGuid
    slotType = slotType
    slotId = slotId
  }
}

let quickEquipHotkeys = function() {
  let item = curHoveredItem.value
  let res = { watch = [isGamepad, curHoveredItem] }
  if (!isGamepad.value || item == null)
    return res

  let soldier = curSoldierInfo.value
  let slot = getItemSlot(item, soldier)
  return slot != null
    // quick uneqip
    ? res.__update({
        children = {
          key = $"unequip_{item?.guid}"
          hotkeys = [["^J:Y", {
            description = loc("equip/quickUnequip")
            action = function() {
              unequipBySlot(slot)
              openSelectItem(slot.__merge({ armyId = selectParamsArmyId.value }))
            }
          }]]
        }
      })
    // quick equip
    : res.__update({
        children = {
          key = $"equip_{item?.guid}"
          hotkeys = [["^J:Y", {
            description = loc("equip/quickEquip")
            action = function() {
              let checkSelectInfo = checkSelectItem(item)
              if (checkSelectInfo){
                processItemDrop(item, checkSelectInfo)
                return
              }
              selectItem(item)
            }
          }]]
        }
      })
}

let itemsContent = [
  {
    size = flex()
    flow = FLOW_HORIZONTAL
    gap = smallPadding
    animations = animations
    transform = {}
    children = [
      mkSoldierInfo({
        soldierInfoWatch = curSoldierInfo
        isMoveRight = false
        selectedKeyWatch = selectedSlot
        onDoubleClickCb = unequipItem
        dropExceptionCb
        onResearchClickCb = gotoResearchUpgradeMsgBox
      })
      prevItemsListBlock
      itemsListBlock
      {
        size = flex()
        children = [
          infoBlock
          mkPresetEquipBlock()
        ]
        behavior = Behaviors.DragAndDrop
        onDrop = @(data) unequipItem(data)
        canDrop = @(data) data?.slotType != null
        skipDirPadNav = true
      }
    ]
    hotkeys = [
      ["^Tab | J:RB", { action = selectNextSlot, description = loc("equip/nextSlot") }],
      ["^L.Shift Tab | R.Shift Tab | J:LB", { action = selectPreviousSlot, description = loc("equip/prevSlot") }]
    ]
  }
  quickEquipHotkeys
]

let selectItemScene = @() {
  watch = safeAreaBorders
  size = [sw(100), sh(100)]
  flow = FLOW_VERTICAL
  key = "selectItemScene"
  onAttach = function() {
    if (armoryWndHasBeenOpend.value && isNewbie.value){
      openArmoryTutorial()
      markSeenArmoryTutorial()
    }
  }
  padding = safeAreaBorders.value
  behavior = [Behaviors.MenuCameraControl, Behaviors.TrackMouse]
  onMouseWheel = function(mouseEvent) {
    changeCameraFov(mouseEvent.button * 5, ADD_CAMERA_FOV_MIN, ADD_CAMERA_FOV_MAX)
  }
  children = [
    @() {
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      margin = [midPadding, 0]
      watch = selectParamsArmyId
      children = [
        backButton
        mkHeader({
          armyId = selectParamsArmyId.value
          textLocId = "Choose item"
          closeButton = closeBtnBase({ onClick = onBackAction })
        })
      ]
    }
    {
      size = flex()
      flow = FLOW_VERTICAL
      children = itemsContent
    }
  ]
}

function open() {
  sceneWithCameraAdd(selectItemScene, "armory")
}

if (selectParams.value)
  open()

selectParams.subscribe(function(p) {
  if (p == null)
    sceneWithCameraRemove(selectItemScene)
  else
    open()
})
