from "%enlSqGlob/ui/ui_library.nut" import *

let { Bordered } = require("%ui/components/txtButton.nut")
let { fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let { slotBaseSize } = require("%enlSqGlob/ui/viewConst.nut")
let { bigPadding, smallPadding, defTxtColor } = require("%enlSqGlob/ui/designConst.nut")
let { blinkingIcon, manageBlinkingObject } = require("%enlSqGlob/ui/blinkingIcon.nut")
let { curArmy, curSquadId, curSquad, curSquadParams, curVehicle, objInfoByGuid
} = require("model/state.nut")
let { perkLevelsGrid } = require("%enlist/meta/perks/perksExp.nut")
let { curArmyReserve, needSoldiersManageBySquad } = require("model/reserve.nut")
let { perksData } = require("model/soldierPerks.nut")
let { unseenSquadsVehicle } = require("%enlist/vehicles/unseenVehicles.nut")
let { vehicleCapacity, isSquadRented, buyRentedSquad } = require("model/squadInfoState.nut")
let { curSoldierInfo, curSoldiersDataList, curSoldierIdx } = require("%enlist/soldiers/model/curSoldiersState.nut")
let { curSquadSoldiersStatus } = require("model/readySoldiers.nut")
let mkMainSoldiersBlock = require("%enlSqGlob/ui/mkSoldiersList.nut")
let mkCurVehicle = require("%enlSqGlob/ui/mkCurVehicle.nut")
let {
  mkAlertIcon, REQ_MANAGE_SIGN
} = require("%enlSqGlob/ui/soldiersUiComps.nut")
let { Notifiers, markNotifierSeen } = require("%enlist/tutorial/notifierTutorial.nut")
let squadHeader = require("components/squadHeader.nut")
let {
  hasSquadVehicle, selectVehParams
} = require("%enlist/vehicles/vehiclesListState.nut")
let { openChooseSoldiersWnd } = require("model/chooseSoldiersState.nut")
let { disabledSectionsData } = require("%enlist/mainMenu/disabledSections.nut")
let sClassesConfig = require("model/config/sClassesConfig.nut")
let mkVehicleSeats = require("%enlSqGlob/squad_vehicle_seats.nut")
let { vehDecorators } = require("%enlist/meta/profile.nut")
let { campPresentation, needFreemiumStatus } = require("%enlist/campaigns/campaignConfig.nut")
let { setTooltip } = require("%ui/style/cursors.nut")
let { getLinkedArmyName } = require("%enlSqGlob/ui/metalink.nut")
let { unseenSoldierShopItems } = require("%enlist/shop/soldiersPurchaseState.nut")
let { smallUnseenNoBlink } = require("%ui/components/unseenComps.nut")
let { mkAlertInfo } = require("model/soldiersState.nut")
let { curSection, mainSectionId } = require("%enlist/mainMenu/sectionsState.nut")
let { goodManageData } = require("%enlist/shop/armyShopState.nut")
let { txt } = require("%enlSqGlob/ui/defcomps.nut")
let { mkSquadListOufitButton } = require("%enlist/soldiers/mkOutfitsList.nut")


function mkSquadInfo() {
  let vehicleInfo = Computed(function() {
    let vehGuid = curVehicle.value
    if (vehGuid == null)
      return null

    let skin = (vehDecorators.value ?? {})
      .findvalue(@(d) d.cType == "vehCamouflage" && d.vehGuid == vehGuid)

    let override = skin == null ? {} : { skin }
    let vehicle = objInfoByGuid.value?[vehGuid]
    return vehicle == null ? null : vehicle.__merge(override)
  })


  function openChooseVehicle(event) {
    if (event.button >= 0 && event.button <= 2)
      selectVehParams.mutate(@(params) params.__update({
        armyId = curArmy.value
        squadId = curSquadId.value
        isCustomMode = false
        isHitcamMode = false
      }))
  }


  let allowedReserve = Computed(function() {
    let { maxClasses = null } = curSquadParams.value
    if (maxClasses == null)
      return 0
    let classesCfgV = sClassesConfig.value
    return curArmyReserve.value.reduce(function(res, s) {
      let kind = s?.sKind ?? classesCfgV?[s.sClass].kind
      return (maxClasses?[kind] ?? 0) > 0 ? res + 1 : res
    }, 0)
  })


  function manageSoldiersBtn() {
    let squad = curSquad.value
    let { guid = null, squadId = null } = squad
    let armyId = getLinkedArmyName(squad)
    let needSoldiersManage = needSoldiersManageBySquad.value?[guid] ?? false
    let hasUnseesSoldiers = unseenSoldierShopItems.value.len() > 0
    let res = {
      watch = [
        needSoldiersManageBySquad, curSquad, disabledSectionsData,
        unseenSoldierShopItems, allowedReserve, goodManageData
      ]
    }
    let hasManageBlink = "squadId" in goodManageData.value
    let count = allowedReserve.value
    let countText = count == 0
      ? loc("soldier/manageButton")
      : loc("soldier/manageButtonWithCount", { count })
    return (disabledSectionsData.value?.SOLDIERS_MANAGING ?? false) ? res
      : res.__update({
        size = [flex(), SIZE_TO_CONTENT]
        children = [
          Bordered(countText,
            function() {
              if (isSquadRented(squad)) {
                buyRentedSquad({ armyId, squadId, hasMsgBox = true })
                return
              }
              markNotifierSeen(Notifiers.SOLDIER)
              openChooseSoldiersWnd(curSquad.value?.guid, curSoldierInfo.value?.guid)
            }, {
              fgChild = {
                flow = FLOW_HORIZONTAL
                hplace = ALIGN_RIGHT
                vplace = ALIGN_TOP
                gap = smallPadding
                padding = smallPadding
                children = [
                  needSoldiersManage ? mkAlertIcon(REQ_MANAGE_SIGN, Computed(@() true)) : null
                  hasUnseesSoldiers
                    ? smallUnseenNoBlink.__merge({ size = [hdpxi(15), hdpxi(15)], fontSize = hdpxi(14) })
                    : null
                ]
              }
              hotkeys = [["^J:LS.Tilted"]]
              onHover = @(on) setTooltip(on && needSoldiersManage ? loc("msg/canAddSoldierToSquad") : null)
              btnWidth = flex()
            }
          )
          hasManageBlink ? manageBlinkingObject : null
        ]
      })
  }

  let curSquadUnseenVehicleCount = Computed(@() unseenSquadsVehicle.value?[curSquad.value?.guid].len() ?? 0)
  function unseenVehiclesMark() {
    let res = { watch = curSquadUnseenVehicleCount }
    if (curSquadUnseenVehicleCount.value > 0)
      res.__update(blinkingIcon("arrow-up", curSquadUnseenVehicleCount.value))
    return res
  }

  let freeSeatsInVehicle = Computed(function() {
    let seatsOrder = mkVehicleSeats(vehicleInfo.value)
    return seatsOrder.slice(curSoldiersDataList.value.len())
  })

  let wrapParams = {
    width = slotBaseSize[0] - bigPadding *2
    hGap = smallPadding
    vGap = smallPadding
    halign = ALIGN_CENTER
  }

  function freeSeatsBlock(freeSeats) {
    if (freeSeats.len() == 0)
      return null
    let uniqSeats = {}
    let seatsToShow = []
    foreach(seat in freeSeats) {
      let { locName } = seat
      if (locName not in uniqSeats) {
        uniqSeats[locName] <- true
        let seatsCount = freeSeats.reduce(function(res, v) {
          if (v.locName == locName)
            res++
          return res
        }, 0)
        local seatText = seatsCount < 2 ? loc(locName)
          : $"{loc(locName)} {loc("common/amountShort", { count = seatsCount })}"
        if (seatsToShow.len() > 0)
          seatText = $", {seatText}"
        seatsToShow.append(seatText)
      }
    }
    return {
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      padding = [0, bigPadding]
      halign = ALIGN_CENTER
      children = [
        {
          rendObj = ROBJ_TEXT
          hplace = ALIGN_CENTER
          text = loc("vehicle_seats/freeSeats")
          color = defTxtColor
        }.__update(fontSub)
        wrap(seatsToShow.map(txt), wrapParams)
      ]
    }
  }


  return function() {
    let res = { watch = [
      curSquad, perksData, vehicleInfo, freeSeatsInVehicle,
      curSoldiersDataList, needFreemiumStatus, campPresentation
    ] }
    if (curSquad.value == null)
      return res

    return res.__update({
      size = [SIZE_TO_CONTENT, flex()]
      function onDetach() {
        if (curSection.value != mainSectionId)
          curSoldierIdx(null)
      }
      function onAttach() {
        if ("soldierIdx" in goodManageData.value)
          gui_scene.setTimeout(0.5, @() curSoldierIdx(goodManageData.value.soldierIdx))
      }
      children = mkMainSoldiersBlock({
        soldiersListWatch = curSoldiersDataList
        expToLevelWatch = Computed(@() perkLevelsGrid.value?.expToLevel)
        hasVehicleWatch = Computed(@() hasSquadVehicle(curSquad.value))
        vehicleInfo
        curSoldierIdxWatch = curSoldierIdx
        soldiersReadyWatch = curSquadSoldiersStatus
        isFreemiumMode = needFreemiumStatus.value
        thresholdColor = campPresentation.value?.color
        curVehicleUi = mkCurVehicle({
          openChooseVehicle
          vehicleInfo
          topRightChild = unseenVehiclesMark
          soldiersList = curSoldiersDataList
        })
        canDeselect = true
        addCardChild = mkAlertInfo
        headerBlock = squadHeader({
          curSquad = curSquad
          curSquadParams = curSquadParams
          soldiersList = curSoldiersDataList
          vehicleCapacity = vehicleCapacity
          soldiersStatuses = curSquadSoldiersStatus
        })
        outfitBlock = mkSquadListOufitButton(curSquad.value)
        bottomObj = {
          size = [flex(), SIZE_TO_CONTENT]
          margin = vehicleInfo.value != null ? null : [bigPadding, 0, 0, 0]
          flow = FLOW_VERTICAL
          gap = smallPadding
          children = [
            freeSeatsBlock(freeSeatsInVehicle.value)
            manageSoldiersBtn
          ]
        }
      })
    })
  }
}

return {mkSquadInfo}
