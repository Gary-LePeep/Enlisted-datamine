from "%enlSqGlob/ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { iconByGameTemplate } = require("%enlSqGlob/ui/itemsInfo.nut")
let { mkArmyIcon } = require("%enlist/soldiers/components/armyPackage.nut")

let { Point2 } = require("dagor.math")
let { CmdShootGunScreenSpace } = require("dasevents")
let JB = require("%ui/control/gui_buttons.nut")
let { safeAreaBorders } = require("%enlist/options/safeAreaState.nut")
let { selectVehParams } = require("vehiclesListState.nut")
let { Bordered } = require("%ui/components/textButton.nut")
let {
  sceneWithCameraAdd, sceneWithCameraRemove
} = require("%enlist/sceneWithCamera.nut")

let {
  smallPadding, bigPadding, sidePadding, defSlotBgColor,
  squadSlotBgIdleColor, squadSlotBgHoverColor, squadSlotBgActiveColor
} = require("%enlSqGlob/ui/designConst.nut")

let comboBox = require("%ui/components/combobox.nut")
let { normal } = require("%ui/style/cursors.nut")
let slider = require("%ui/components/slider.nut")
let { txt } = require("%enlSqGlob/ui/defcomps.nut")
let { mkHitcamData, initWeaponList, selWeaponEid } = require("hitcamState.nut")
let { hangar_simulate_shot } = require("das.hitcam")
let { HitcamResult } = require("%enlSqGlob/dasenums.nut")
let { closeDmViewerMode } = require("dmViewer.nut")


let MAX_PROJECTILE_DISTANCE = 2000

let hangarHitcamShotResult = Watched(HitcamResult.EMPTY)

let setXrayModeQuery = ecs.SqQuery("setXrayModeQuery",
  { comps_rw = [ ["xray_context__isPictureInPicture", ecs.TYPE_BOOL] ]})

function resetVehicle() {
  selectVehParams.mutate(@(v) v.recreateVersionNo <- (v?.recreateVersionNo ?? 0) + 1)
}

function actionsOnClose() {
  resetVehicle()
  selectVehParams.mutate(@(v) v.isHitcamMode = false)
  setXrayModeQuery(@(_, comp) comp.xray_context__isPictureInPicture = true)
}

function close() {
  actionsOnClose()
}

let resetBtn = Bordered(loc("hitcam/ResetBtn"), resetVehicle, {
  margin = 0
})

let backBtn = Bordered(loc("BackBtn"), close, {
  margin = 0
  hotkeys = [[ $"^{JB.B} | Esc", { description = loc("BackBtn") }]]
})


let colorNotPenetrated = Color(245, 30, 30)
let colorIneffective = Color(150, 150, 140)
let colorEffective = Color(30, 255, 30)
let colorPossibleEffective = Color(230, 230, 20)
let colorMiss = Color(150, 150, 140)

function getCrosshairColor(hitResult) {
  if (hitResult == HitcamResult.EFFECTIVE)
    return colorEffective
  else if ( hitResult == HitcamResult.POSSIBLE_EFFECTIVE)
    return colorPossibleEffective
  else if ( hitResult == HitcamResult.NOT_PENETRATE || hitResult == HitcamResult.RICOCHET)
    return colorNotPenetrated
  else if ( hitResult == HitcamResult.INEFFECTIVE)
    return colorIneffective
  else if ( hitResult == HitcamResult.EMPTY)
    return colorMiss
  return colorMiss
}

let crosshairSize = hdpx(42)
let crosshair = Cursor(@() {
  rendObj = ROBJ_VECTOR_CANVAS
  size = [crosshairSize, crosshairSize]
  hotspot = [crosshairSize/2, crosshairSize/2]
  watch = [hangarHitcamShotResult]
  color = getCrosshairColor(hangarHitcamShotResult.value)
  transform = { pivot = [0, 0] }
  commands = [
    [VECTOR_WIDTH, max(1.1, hdpx(1.2))],
    [VECTOR_LINE, 0, 50, 100, 50],
    [VECTOR_LINE, 50, 0, 50, 100],
  ]
})


let getCurrentVehicleQuery = ecs.SqQuery("getCurrentVehicleQuery", {
  comps_ro = [["menu_vehicle_to_control", ecs.TYPE_EID]]
})


let slotBgColor = @(sf, isSelected)
  sf & S_HOVER ? squadSlotBgHoverColor
    : isSelected ? squadSlotBgActiveColor
    : squadSlotBgIdleColor

let comboBoxStyle = { style = { fillColor = defSlotBgColor } }
let ammoImgSize = [hdpxi(60), hdpxi(60)]

function mkAmmo(ammo, gunName, gunTemplateId, weaponId, ammoIndex) {
  let { aType, slot } = ammo
  let isSelected = Computed(@() gunTemplateId == weaponId.value && slot == ammoIndex.value)
  return watchElemState(@(sf) {
    watch = isSelected
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    padding = [0, bigPadding]
    rendObj = ROBJ_BOX
    fillColor = slotBgColor(sf, isSelected.value)
    borderWidth = isSelected.value ? 1 : 0
    borderColor = 0xFF999999
    behavior = Behaviors.Button
    onClick = function() {
      weaponId(gunTemplateId)
      ammoIndex(slot)
    }
    children = [
      {
        size = [flex(), SIZE_TO_CONTENT]
        vplace = ALIGN_CENTER
        rendObj = ROBJ_TEXTAREA
        behavior = Behaviors.TextArea
        text = aType == null ? gunName : loc($"{aType}/name/short")
      }
      {
        size = ammoImgSize
        rendObj = ROBJ_IMAGE
        imageHalign = ALIGN_RIGHT
        imageValign = ALIGN_CENTER
        image = ammo.icon.image
        color = ammo.icon.color
        keepAspect = KEEP_ASPECT_FIT
      }
    ]
  })
}

let vehImgSize = [hdpxi(300), hdpxi(200)]
let vehCardSize = [hdpxi(380), hdpxi(220)]

let hitcamScene = function() {
  closeDmViewerMode()
  initWeaponList()
  setXrayModeQuery(@(_, comp) comp.xray_context__isPictureInPicture = false)

  let {
    hitcamArmiesList, hitcamVehiclesList, hitcamAmmoList,
    hitcamArmyId, hitcamVehicleId, weaponId, ammoIndex, shotDistance
  } = mkHitcamData()

  function analyzeShot(event) {
    let target = getCurrentVehicleQuery(@(_, comp) comp.menu_vehicle_to_control) ?? ecs.INVALID_ENTITY_ID
    if (target == ecs.INVALID_ENTITY_ID)
      return

    let screenPos = Point2(event.screenX, event.screenY)
    let gunEid = selWeaponEid.value
    let distance = shotDistance.value
    let result = hangar_simulate_shot(target, gunEid, ammoIndex.value, distance, screenPos)
    hangarHitcamShotResult(result)
  }

  function makeShot(event) {
    if ((weaponId.value ?? "") != "")
      ecs.g_entity_mgr.broadcastEvent(CmdShootGunScreenSpace({
        gunTemplate = $"{weaponId.value}+xray_activator"
        bulletNo = ammoIndex.value
        distance = shotDistance.value
        screenPos = Point2(event.screenX, event.screenY)
      }))
  }


  let selectedInfoUi = {
    size = vehCardSize
    rendObj = ROBJ_SOLID
    color = defSlotBgColor
    borderWidth = 1
    children = [
      @() {
        watch = hitcamVehicleId
        size = flex()
        children = iconByGameTemplate(hitcamVehicleId.value, {
          width = vehImgSize[0]
          height = vehImgSize[1]
        })
      }
      @() {
        watch = hitcamArmyId
        hplace = ALIGN_RIGHT
        children = mkArmyIcon(hitcamArmyId.value)
      }
    ]
  }

  let armiesListUi =  {
    size = [flex(), hdpxi(40)]
    children = comboBox(hitcamArmyId, hitcamArmiesList, comboBoxStyle)
  }

  let vehiclesListUi = {
    size = [flex(), hdpxi(40)]
    children = comboBox(hitcamVehicleId, hitcamVehiclesList, comboBoxStyle)
  }

  let weaponsListUi = @() {
    watch = hitcamAmmoList
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = smallPadding
    margin = [sidePadding, 0]
    children = hitcamAmmoList.value.map(function(weapon) {
      let { gunName, gunTemplateId, ammoData } = weapon
      return {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_VERTICAL
        gap = smallPadding
        children = ammoData.map(@(ammo) mkAmmo(ammo, gunName, gunTemplateId, weaponId, ammoIndex))
      }
    })
  }

  let shotDistanceUi = {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    children = [
      @() {
        watch = shotDistance
        children = txt(loc("hitcam/distance", { distance = shotDistance.value })),
      }
      {
        size = [flex(), hdpxi(30)]
        children = slider.Horiz(shotDistance, { min = 0, max = MAX_PROJECTILE_DISTANCE })
      }
    ]
  }

  return {
    cursor = crosshair
    size = flex()
    children = @() {
      watch = safeAreaBorders
      size = flex()
      padding = safeAreaBorders.value
      behavior = [Behaviors.MenuCameraControl, Behaviors.Button, Behaviors.TrackMouse]
      onMouseMove = analyzeShot
      onClick = makeShot
      children = {
        cursor = normal
        size = [vehCardSize[0], flex()]
        flow = FLOW_VERTICAL
        gap = smallPadding
        children = [
          {
            size = [flex(), SIZE_TO_CONTENT]
            flow = FLOW_HORIZONTAL
            gap = bigPadding
            margin = [sidePadding, 0]
            children = [backBtn, resetBtn]
          }
          selectedInfoUi
          armiesListUi
          vehiclesListUi
          weaponsListUi
          shotDistanceUi
        ]
      }
    }
  }
}

if (selectVehParams.value?.isHitcamMode ?? false)
  sceneWithCameraAdd(hitcamScene, "vehicles")

selectVehParams.subscribe(function(v) {
  if (v?.isHitcamMode ?? false)
    sceneWithCameraAdd(hitcamScene, "vehicles")
  else
    sceneWithCameraRemove(hitcamScene)
})
