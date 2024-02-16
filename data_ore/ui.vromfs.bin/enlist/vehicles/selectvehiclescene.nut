from "%enlSqGlob/ui_library.nut" import *

let { fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let { safeAreaBorders } = require("%enlist/options/safeAreaState.nut")
let { sceneWithCameraAdd, sceneWithCameraRemove } = require("%enlist/sceneWithCamera.nut")
let {
  vehicles, squadsWithVehicles, viewVehicle, selectedVehicle, selectVehicle, selectVehParams,
  curSquadId, setCurSquadId, CANT_USE, LOCKED, vehicleClear, getVehicleSquad
} = require("vehiclesListState.nut")
let { getSquadConfig } = require("%enlist/soldiers/model/state.nut")
let {
  smallPadding, bigPadding, blurBgColor, blurBgFillColor, vehicleListCardSize, defTxtColor
} = require("%enlSqGlob/ui/viewConst.nut")
let { txt } = require("%enlSqGlob/ui/defcomps.nut")
let scrollbar = require("%ui/components/scrollbar.nut")
let vehiclesListCard = require("vehiclesListCard.ui.nut")
let vehicleDetails = require("vehicleDetails.ui.nut")
let closeBtnBase = require("%ui/components/closeBtn.nut")
let mkHeader = require("%enlist/components/mkHeader.nut")
let mkToggleHeader = require("%enlist/components/mkToggleHeader.nut")
let mkCurSquadsList = require("%enlSqGlob/ui/mkSquadsList.nut")
let {
  isDmViewerEnabled, onDmViewerMouseMove, dmViewerPanelUi
} = require("%enlist/vehicles/dmViewer.nut")
let { changeCameraFov } = require("%enlist/showState.nut")
let { getLiveSquadBR, loadBRForAllSquads, BRInfoBySquads
} = require("%enlist/soldiers/armySquadTier.nut")

const ADD_CAMERA_FOV_MIN = -25
const ADD_CAMERA_FOV_MAX = 45


let showNotAvailable = Watched(false)
selectVehParams.subscribe(@(_) showNotAvailable(false))

let function createSquadHandlers(squads) {
  squads.each(@(squad)
    squad.__update({
      onClick = @() setCurSquadId(squad.squadId)
      isSelected = Computed(@() curSquadId.value == squad.squadId)
    })
  )
}

let notAvailableHeader = mkToggleHeader(showNotAvailable, loc("header/notAvailableVehicles"))

let sortByStatus = @(a, b) (b != LOCKED) <=> (a != LOCKED) || a <=> b

let function mkStatusHeader(status) {
  let { statusTextShort = null, statusText = null, isHiddenInGroup = false } = status
  let text = isHiddenInGroup ? null : (statusTextShort ?? statusText)
  return text == null ? null
    : {
        rendObj = ROBJ_TEXT
        size = [flex(), SIZE_TO_CONTENT]
        margin = [smallPadding, 0, 0, 0]
        text
        color = defTxtColor
        behavior = [Behaviors.Marquee, Behaviors.Button]
        scrollOnHover = true
      }.__update(fontSub)
}

let function groupByStatus(itemsList) {
  let groupedItems = {}
  foreach (item in itemsList) {
    let { statusText = "" } = item.status
    groupedItems[statusText] <- (groupedItems?[statusText] ?? []).append(item)
  }
  let children = []
  let itemsOrdered = groupedItems.values().sort(@(a, b)
    sortByStatus(a[0].status.flags, b[0].status.flags))
  foreach (items in itemsOrdered) {
    children.append(mkStatusHeader(items[0].status))
    foreach (item in items)
      children.append(vehiclesListCard({
        item
        onClick = @(item_) viewVehicle(item_)
        onDoubleClick = @(item_) selectVehicle(item_)
      }))
  }
  return children
}

let function vehiclesList() {
  let available = []
  let unavailable = []
  foreach (vehicle in vehicles.value) {
    // ignore selected for the other squads or the current squad
    if (getVehicleSquad(vehicle) != null)
      continue
    if (!(vehicle.status.flags & CANT_USE))
      available.append(vehicle)
    else
      unavailable.append(vehicle)
  }

  let children = groupByStatus(available)
  if (unavailable.len() > 0) {
    children.append(notAvailableHeader)
    if (showNotAvailable.value)
      children.extend(groupByStatus(unavailable))
  }
  return {
    watch = [vehicles, showNotAvailable]
    size = [vehicleListCardSize[0], SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = bigPadding
    children
  }
}

let currentVehicle = @() {
  watch = selectedVehicle
  children = vehiclesListCard({
    item = selectedVehicle.value
    onClick = @(item) viewVehicle(item)
  })
}

let vehiclesBlock = {
  size = [SIZE_TO_CONTENT, flex()]
  rendObj = ROBJ_WORLD_BLUR_PANEL
  color = blurBgColor
  fillColor = blurBgFillColor
  padding = bigPadding
  flow = FLOW_VERTICAL
  stopMouse = true
  gap = smallPadding
  children = [
    {
      rendObj = ROBJ_TEXT
      text = loc("squad/vehicle")
      color = defTxtColor
    }.__update(fontSub)
    currentVehicle
    scrollbar.makeVertScroll(vehiclesList, {
      size = [SIZE_TO_CONTENT, flex()]
      needReservePlace = false
    })
  ]
}

let function mkSquadName(squadId, armyId) {
  let squadConfig = getSquadConfig(squadId, armyId)
  return squadConfig != null
    ? txt(loc(squadConfig?.titleLocId ?? ""))
    : null
}

let vehicleListWithBR = Computed(@()
  (squadsWithVehicles.value ?? [])
    .map(@(squad)
      squad.__merge({ battleRating = getLiveSquadBR(BRInfoBySquads.value, squad.squadId) })
    ))

let selectVehicleContent = {
  size = flex()
  flow = FLOW_VERTICAL
  gap = bigPadding
  children = [
    @() {
      watch = selectVehParams
      children = mkSquadName(selectVehParams.value?.squadId, selectVehParams.value?.armyId)
    }
    @() {
      size = flex()
      flow = FLOW_HORIZONTAL
      gap = bigPadding
      watch = vehicleListWithBR

      behavior = Behaviors.MenuCameraControl

      children = [
        mkCurSquadsList({
          curSquadsList = vehicleListWithBR
          curSquadId
          setCurSquadId
          createHandlers = createSquadHandlers
        })
        vehiclesBlock
        {
          size = flex()
          children = dmViewerPanelUi
        }
        {
          size = [SIZE_TO_CONTENT, flex()]
          halign = ALIGN_RIGHT
          children = vehicleDetails
        }
      ]
    }
  ]
}

let selectVehicleScene = @() {
  watch = [safeAreaBorders, isDmViewerEnabled]
  size = [sw(100), sh(100)]
  flow = FLOW_VERTICAL
  padding = safeAreaBorders.value
  behavior = Behaviors.TrackMouse
  onMouseMove = function(mouseEvent) {
    if (isDmViewerEnabled.value)
      onDmViewerMouseMove(mouseEvent)
  }
  onMouseWheel = function(mouseEvent) {
    changeCameraFov(mouseEvent.button * 5, ADD_CAMERA_FOV_MIN, ADD_CAMERA_FOV_MAX)
  }
  children = [
    @() {
      size = [flex(), SIZE_TO_CONTENT]
      watch = selectVehParams
      children = mkHeader({
        armyId = selectVehParams.value?.armyId
        textLocId = "Choose vehicle"
        closeButton = closeBtnBase({ onClick = vehicleClear })
      })
    }
    {
      size = flex()
      flow = FLOW_VERTICAL
      children = selectVehicleContent
    }
  ]
}

viewVehicle.subscribe(@(_v) changeCameraFov(0))

let function open() {
  viewVehicle(selectedVehicle.value)
  sceneWithCameraAdd(selectVehicleScene, "vehicles")
  loadBRForAllSquads(squadsWithVehicles.value ?? [])
}

if (selectVehParams.value?.armyId != null
    && selectVehParams.value?.squadId != null
    && !(selectVehParams.value?.isCustomMode ?? false))
  open()

selectVehParams.subscribe(function(p) {
  let { armyId = null, squadId = null, isCustomMode = false, isHitcamMode = false } = p
  if (armyId != null && squadId != null && !isCustomMode && !isHitcamMode)
    open()
  else {
    sceneWithCameraRemove(selectVehicleScene)
    if (!isCustomMode && !isHitcamMode)
      viewVehicle(null)
  }
})
