from "%enlSqGlob/ui/ui_library.nut" import *

let { fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let { round_by_value } = require("%sqstd/math.nut")
let defcomps = require("%enlSqGlob/ui/defcomps.nut")
let { Flat, PrimaryFlat } = require("%ui/components/textButton.nut")
let { statusIconLocked, statusIconBlocked, hintText
} = require("%enlSqGlob/ui/itemPkg.nut")
let {
  viewVehicle, selectVehicle, selectedVehicle, selectVehParams,
  vehicleClear, squadsWithVehicles, setCurSquadId,
  CAN_USE, CANT_USE, CAN_PURCHASE, AVAILABLE_IN_GROWTH, IS_BUSY_BY_SQUAD
} = require("vehiclesListState.nut")
let { isGamepad } = require("%ui/control/active_controls.nut")
let { focusResearch, findResearchesUpgradeUnlock, getClosestResearch
} = require("%enlist/researches/researchesFocus.nut")
let { allResearchStatus } = require("%enlist/researches/researchesState.nut")
let { getSortedGrowthsByResearch } = require("%enlist/growth/growthState.nut")
let { jumpToArmyGrowth } = require("%enlist/mainMenu/sectionsState.nut")
let { mkViewItemDetails } = require("%enlist/soldiers/components/itemDetailsComp.nut")
let spinner = require("%ui/components/spinner.nut")
let { isItemActionInProgress } = require("%enlist/soldiers/model/itemActions.nut")
let { showMsgbox } = require("%enlist/components/msgbox.nut")
let { blinkUnseenIcon } = require("%ui/components/unseenSignal.nut")
let hoverHoldAction = require("%darg/helpers/hoverHoldAction.nut")
let { mkItemUpgradeData, mkItemDisposeData
} = require("%enlist/soldiers/model/mkItemModifyData.nut")
let { markSeenUpgrades, curUnseenAvailableUpgrades, isUpgradeUsed
} = require("%enlist/soldiers/model/unseenUpgrades.nut")
let { curUpgradeDiscount, campPresentation } = require("%enlist/campaigns/campaignConfig.nut")
let { setTooltip, normalTooltipTop } = require("%ui/style/cursors.nut")
let { openUpgradeItemMsg, openDisposeItemMsg
} = require("%enlist/soldiers/components/modifyItemComp.nut")
let { getShopItemsCmp, curArmyShopItems, openAndHighlightItems
} = require("%enlist/shop/armyShopState.nut")
let { isDmViewerEnabled } = require("%enlist/vehicles/dmViewer.nut")
let { inventoryItemDetailsWidth, disabledBdColor, defBdColor, commonBorderRadius,
  midPadding, smallPadding, textBgBlurColor, activeTxtColor
} = require("%enlSqGlob/ui/designConst.nut")
let { safeAreaBorders } = require("%enlist/options/safeAreaState.nut")
let { mkSquadIcon } = require("%enlSqGlob/ui/squadsUiComps.nut")
let { armySquadsById } = require("%enlist/soldiers/model/state.nut")
let { isChangesBlocked } = require("%enlist/quickMatchQueue.nut")


let unseenIcon = blinkUnseenIcon(0.8).__update({ hplace = ALIGN_RIGHT })
let waitingSpinner = spinner(hdpx(25))

function txt(text) {
  return type(text) == "string"
    ? defcomps.txt({text}.__update(fontSub))
    : defcomps.txt(text)
}

let mkStatusRow = @(text, icon) {
  size = [flex(), SIZE_TO_CONTENT]
  padding = [smallPadding, 0]
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  gap = smallPadding
  children = [
    hintText(text)
    icon
  ]
}


let mkVehOwnersUi = @(owners) owners.len() == 0 ? null
  : function() {
      let vehSquads = squadsWithVehicles.value
      return {
        watch = [squadsWithVehicles]
        children = owners.map(function(guid) {
          let squad = vehSquads.findvalue(@(v) v.guid == guid)
          return squad == null ? null
            : watchElemState(@(sf) {
                rendObj = ROBJ_BOX
                borderWidth = hdpx(1)
                borderRadius = commonBorderRadius
                borderColor = sf & S_HOVER ? defBdColor : disabledBdColor
                behavior = Behaviors.Button
                onClick = @() setCurSquadId(squad.squadId)
                children = mkSquadIcon(squad?.icon, {
                  size = [hdpxi(50), hdpxi(50)]
                  margin = smallPadding
                })
              })
        })
      }
    }

function vehicleStatusRow(item) {
  let { flags, statusText = "", owners = [] } = item.status
  if (item == null || flags == CAN_USE)
    return null

  if (IS_BUSY_BY_SQUAD & flags) {
    return mkStatusRow(statusText, mkVehOwnersUi(owners))
  }

  return mkStatusRow(statusText, CANT_USE & flags ? statusIconBlocked : statusIconLocked)
}

let backButton = Flat(loc("mainmenu/btnBack"), vehicleClear,
  { margin = [0, midPadding, 0, 0] })

// TODO same as selectItemScene.nut, should be joined in one module
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
        curUpgradeDiscount, campPresentation]
    }
    let upgradeData = upgradeDataWatch.value
    if (!upgradeData.isUpgradable)
      return res

    res.margin <- [0, midPadding, 0, 0]
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
        children = Flat(loc("btn/upgrade"), researchCb, {
          margin = 0
          cursor = normalTooltipTop
          onHover = @(on) setTooltip(on ? loc("tip/btnUpgradeVehicle") : null)
          hotkeys = [["^J:X"]]
        })
      })
    }

    let discount = round_by_value(100 - upgradeMult * 100, 1).tointeger()
    let bCtor = hasEnoughOrders ? PrimaryFlat : Flat
    let upgradeMultInfo = upgradeMult == 1.0 ? null
      : txt({
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
      children = [
        upgradeMultInfo
        {
          children = [
            bCtor(loc("btn/upgrade"),
              @() openUpgradeItemMsg(item, upgradeData), {
                margin = 0
                cursor = normalTooltipTop
                onHover = function(on) {
                  if (!isUpgradeUsed.value && item?.basetpl in curUnseenAvailableUpgrades.value)
                    hoverHoldAction("unseenUpdate", itemBaseTpl,
                      @(tpl) markSeenUpgrades(selectVehParams.value?.armyId, [tpl]))(on)
                  setTooltip(on ? loc("tip/btnUpgrade") : null)
                }
                hotkeys = [["^J:X"]]
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
    let res = { watch = [disposeDataWatch] }
    let disposeData = disposeDataWatch.value
    if (!disposeData.isDisposable)
      return res

    res.margin <- [0, midPadding, 0, 0]
    let { disposeMult, isDestructible = false, isRecyclable = false } = disposeData

    let bCtor = Flat
    let bonus = round_by_value(disposeMult * 100 - 100, 1).tointeger()
    let disposeMultInfo = disposeMult == 1.0 ? null : txt({
      text = loc("disposeBonus", { bonus })
      color = activeTxtColor
    })
    return res.__update({
      flow = FLOW_VERTICAL
      gap = midPadding
      halign = ALIGN_CENTER
      children = [
        disposeMultInfo
        bCtor(loc(isRecyclable ? "btn/recycle" : isDestructible ? "btn/dispose" : "btn/downgrade"),
          @() openDisposeItemMsg(item, disposeData), {
            margin = 0
            cursor = normalTooltipTop
            onHover = @(on)
              setTooltip(on ? loc(isRecyclable ? "tip/btnRecycle"
                  : isDestructible ? "tip/btnDispose"
                  : "tip/btnDowngrade")
                : null)
          })
      ]
    })
  }
}


let btnStyle = {
  margin = [0, midPadding, 0, 0]
  hotkeys = [[ "^J:Y" ]]
}

function mkChooseButton(curVehicle, selVehicle, isBlocked = false) {
  if (curVehicle.basetpl == (selVehicle?.basetpl ?? "") || curVehicle == null)
    return null

  let { flags = 0, growthId = null } = curVehicle.status
  if (flags == CAN_USE)
    return PrimaryFlat(loc("mainmenu/btnSelect"), @() selectVehicle(curVehicle), btnStyle.__merge({
      isEnabled = !isBlocked
    }))

  else if (flags & AVAILABLE_IN_GROWTH)
    return Flat(loc("GoToGrowth"), @() jumpToArmyGrowth(growthId), btnStyle )

  else if (flags & CAN_PURCHASE) {
    let { basetpl } = curVehicle
    let shopItemsCmp = getShopItemsCmp(basetpl)
    return Flat(loc("GoToShop"),
      @() openAndHighlightItems(shopItemsCmp.value, curArmyShopItems.value), btnStyle)
  }

  return null
}

let animations = [
  { prop = AnimProp.opacity, from = 0, to = 1, duration = 0.3, easing = OutCubic,
    play = true, trigger = "vehicleDetailsAnim"}
  { prop = AnimProp.translate, from =[0, hdpx(100)], to = [0, 0], duration = 0.15, easing = OutQuad,
    play = true, trigger = "vehicleDetailsAnim"}
]

let manageButtons = @() {
  watch = [viewVehicle, selectedVehicle, isGamepad, isChangesBlocked]
  flow = FLOW_VERTICAL
  halign = ALIGN_RIGHT
  gap = midPadding
  children = {
    rendObj = ROBJ_WORLD_BLUR_PANEL
    color = textBgBlurColor
    flow = FLOW_HORIZONTAL
    padding = [midPadding, 0, midPadding, midPadding]
    valign = ALIGN_BOTTOM
    children = isItemActionInProgress.value
      ? [waitingSpinner]
      : [
          mkUpgradeBtn(viewVehicle.value)
          mkDisposeBtn(viewVehicle.value)
          mkChooseButton(viewVehicle.value, selectedVehicle.value, isChangesBlocked.value)
        ]
      .append(isGamepad.value
        ? null
        : backButton)
  }
}

local lastVehicleTpl = null
return function() {
  let res = { watch = [ viewVehicle, isDmViewerEnabled] }
  let vehicle = viewVehicle.value
  if (vehicle == null)
    return res

  if (lastVehicleTpl != vehicle?.basetpl) {
    lastVehicleTpl = vehicle?.basetpl
    anim_start("vehicleDetailsAnim")
  }

  return res.__update({
    size = [inventoryItemDetailsWidth, flex()]
    flow = FLOW_VERTICAL
    gap = hdpx(30)
    valign = ALIGN_BOTTOM
    halign = ALIGN_RIGHT
    transform = {}
    animations = animations
    children = !isDmViewerEnabled.value
      ? [
          {
          size = flex()
          flow = FLOW_VERTICAL
          valign = ALIGN_BOTTOM
          gap = midPadding
          children = [
            mkViewItemDetails(viewVehicle.value, Watched(true),
              fsh(75) - safeAreaBorders.value[0] - safeAreaBorders.value[2])
            vehicleStatusRow(vehicle)
          ]
        }
        manageButtons
      ]
      : manageButtons
  })
}


