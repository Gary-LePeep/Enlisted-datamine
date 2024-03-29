from "%enlSqGlob/ui/ui_library.nut" import *

let cursors = require("%ui/style/cursors.nut")
let { fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let { makeVertScroll, thinStyle } = require("%ui/components/scrollbar.nut")
let STATUS = require("%enlSqGlob/readyStatus.nut")
let { slotBaseSize, smallPadding, midPadding, defTxtColor, panelBgColor
} = require("%enlSqGlob/ui/designConst.nut")
let { note } = require("%enlSqGlob/ui/defcomps.nut")
let mkSoldierCard = require("%enlSqGlob/ui/mkSoldierCard.nut")
let mkVehicleSeats = require("%enlSqGlob/squad_vehicle_seats.nut")


let emptySlot = @(cb) {
  behavior = Behaviors.Button
  onClick = cb
  size = slotBaseSize
  rendObj = ROBJ_SOLID
  color = panelBgColor
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = [
    {
      rendObj = ROBJ_TEXT
      text = loc("squad/soldierFreeSlot")
      color = defTxtColor
    }.__update(fontSub)
  ]
}

let mkSoldierSlot = kwarg(function(soldier, idx, curSoldierIdxWatch,
  canDeselect = true, addCardChild = null, isFreemiumMode = false, thresholdColor = 0,
  soldiersReadyWatch = Watched(null), defSoldierGuidWatch = Watched(null),
  seatsOrder = [], expToLevelWatch = Watched([])
) {
  let isSelectedWatch = Computed(function() {
    if (curSoldierIdxWatch.value == idx)
      return true
    let sGuid = defSoldierGuidWatch.value
    return sGuid != null && soldier.guid == sGuid
  })

  let group = ElemGroup()
  return watchElemState(function(sf) {
    let soldiersReadyInfo = soldiersReadyWatch.value
    let soldierStatus = soldiersReadyInfo?[soldier.guid] ?? STATUS.READY
    let hasWeaponWarning = (soldierStatus & STATUS.NOT_READY_BY_EQUIP) != 0
    let isFaded = soldierStatus != STATUS.READY
    let outOfVehicSize = (soldierStatus & STATUS.OUT_OF_VEHICLE) != 0
    let seatInfo = seatsOrder?[idx]

    let chContent = {
      xmbNode = XmbNode()
      vplace = ALIGN_CENTER
      children = mkSoldierCard({
        soldierInfo = soldier
        expToLevel = expToLevelWatch.value
        size = slotBaseSize
        group = group
        sf = sf
        isSelected = isSelectedWatch.value
        isFaded = isFaded
        isClassRestricted = (soldierStatus & STATUS.TOO_MUCH_CLASS) != 0
        hasAlertStyle = hasWeaponWarning
        hasWeaponWarning = hasWeaponWarning
        addChild = addCardChild
        isFreemiumMode = isFreemiumMode
        thresholdColor
      })
    }

    return {
      watch = [soldiersReadyWatch, isSelectedWatch, expToLevelWatch]
      group = group
      key = $"slot{soldier?.guid}{idx}"
      flow = FLOW_VERTICAL
      behavior = Behaviors.Button
      onHover = outOfVehicSize
        ? @(on) cursors.setTooltip(on ? loc("soldier/status/outOfVehicleCrewSize") : null)
        : null
      onClick = function() {
        if (soldier?.canSpawn ?? true) {
          defSoldierGuidWatch(null)
          curSoldierIdxWatch(canDeselect && idx == curSoldierIdxWatch.value ? null : idx)
        }
      }
      sound = {
        hover = "ui/enlist/button_highlight"
        click = "ui/enlist/button_click"
        active = "ui/enlist/button_action"
      }
      children = [
        seatInfo ? note(loc(seatInfo.locName)) : null
        chContent
      ]
    }
  })
})

function mkSoldiersBlock(params) {
  let {
    soldiersListWatch, curSoldierIdxWatch, vehicleInfo = Watched(null), addCardChild = null,
    emptySlotsNum = 0, emptySlotHandler = null
  } = params
  return function() {
    let seatsOrder = mkVehicleSeats(vehicleInfo.value)
    let unitsInVehicle = seatsOrder.len()
    let soldiers = soldiersListWatch.value
    let children = soldiers.slice(0, unitsInVehicle).map(@(soldier, idx)
      mkSoldierSlot(params.__merge({ soldier, idx, addCardChild, seatsOrder }), KWARG_NON_STRICT))

    if (unitsInVehicle < soldiers.len()) {
      children.extend(soldiers.slice(unitsInVehicle).map(@(soldier, idx)
        mkSoldierSlot(params.__merge({
          soldier
          idx = idx + unitsInVehicle
          addCardChild
          seatsOrder }),
        KWARG_NON_STRICT)))
    }

    for (local i = 0; i < emptySlotsNum; i++) {
      children.append(emptySlot(emptySlotHandler))
    }

    return {
      watch = [soldiersListWatch, curSoldierIdxWatch, vehicleInfo]
      size = [slotBaseSize[0], SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      behavior = Behaviors.Button
      gap = smallPadding
      onClick = function() {
        if (params?.canDeselect ?? false)
          curSoldierIdxWatch(null)
      }
      children = children
    }
  }
}

let mkVehicleBlock = @(hasVehicleWatch, curVehicleUi) function() {
  let res = { watch = hasVehicleWatch }
  if (!hasVehicleWatch.value)
    return res

  return res.__update({
    size = [flex(), SIZE_TO_CONTENT]
    margin = [0, 0, midPadding, 0]
    children = {
      flow = FLOW_VERTICAL
      gap = smallPadding
      size = [flex(), SIZE_TO_CONTENT]
      children = curVehicleUi
    }
  })
}

let mkMainSoldiersBlock = @(params) {
  size = [slotBaseSize[0], flex()]
  flow = FLOW_VERTICAL
  gap = smallPadding
  children = [
    params?.headerBlock
    params?.outfitBlock
    {
      size = flex()
      flow = FLOW_VERTICAL
      children = [
        "hasVehicleWatch" not in params ? null
          : mkVehicleBlock(params.hasVehicleWatch, params.curVehicleUi)
        makeVertScroll(mkSoldiersBlock(params), {
          size = [SIZE_TO_CONTENT, flex()], styling = thinStyle
        })
      ]
    }
    params?.bottomObj
  ]
}

return mkMainSoldiersBlock
