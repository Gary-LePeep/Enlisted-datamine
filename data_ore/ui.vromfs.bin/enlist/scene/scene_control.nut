import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui/ui_library.nut" import *

let { DBGLEVEL } = require("dagor.system")
let { Point2, Point3, TMatrix } = require("dagor.math")
let {
  vehTplInVehiclesScene, vehDataInVehiclesScene, cameraFovDelta,
  itemInArmory, itemInArmoryAttachments, needWeaponCameraAngle, soldierInSoldiers,
  currentNewItem, currentNewItemAttachments, scene,
  squadCampaignVehicleFilter, isVehicleSceneVisible
} = require("%enlist/showState.nut")
let { nestWatched } = require("%dngscripts/globalState.nut")
let { curCampItems, objInfoByGuid, curSquad } = require("%enlist/soldiers/model/state.nut")
let { curSquadSoldiersReady } = require("%enlist/soldiers/model/readySoldiers.nut")
let {
  selectedSquadSoldiers, selSquadVehicleGameTpl
} = require("%enlist/soldiers/model/chooseSquadsState.nut")
let {EventLevelLoaded} = require("gameevents")
let { soldierViewGen, createSoldier, appearanceToRender} = require("soldier_tools.nut")
let { createVehicle } = require("vehicle_tools.nut")
let { doFadeBlack, registerFadeBlackActions } = require("%enlist/fadeToBlack.nut")
let { transformItem, transformItemRelative } = require("transformItem.nut")
let { setDmViewerTarget } = require("%enlist/vehicles/dmViewer.nut")
let { setDecalTarget } = require("%enlist/vehicles/decorViewer.nut")
let { viewVehDecorators } = require("%enlist/vehicles/customizeState.nut")
let { selectVehParams } = require("%enlist/vehicles/vehiclesListState.nut")
let { soldiersLook } = require("%enlist/meta/servProfile.nut")
let { allOutfitByArmy, isOutfitAllowedByCampaign } = require("%enlist/soldiers/model/config/outfitConfig.nut")
let { viewTemplates } = require("%enlist/items/itemCollageState.nut")
let { selectedCampaign } = require("%enlist/meta/curCampaign.nut")
let { enginObjectToPlace } = require("machinegun_tools.nut")
let { setItemTransformFunc } = require("item_tools.nut")
let { configs } = require("%enlist/meta/configs.nut")
let { getItemIndex } = require("%enlSqGlob/ui/metalink.nut")


/*
  TODO:
  - rework:
    - create scene and resources by scene + what to watch in watch and how. to make possible creation of vehicle + squad, as well
  - we want to show weapon \ weapon mods if weapon is selected or we want to choose new weapon
  ? if you are wating too long and not touching mouse\keyboard\gamepad - start scenic cameras
  - scenic cameras should start not from first, but random one
*/

//!----- quick and dirty set cameras ---
let setCameraQuery = ecs.SqQuery("setCameraQuery", {
  comps_rw = [
    ["transform", ecs.TYPE_MATRIX],
    ["fov", ecs.TYPE_FLOAT],
    ["menu_cam__target", ecs.TYPE_EID],
    ["menu_cam__dirInited", ecs.TYPE_BOOL],
    ["menu_cam__initialDir", ecs.TYPE_POINT3],
    ["menu_cam__offset", ecs.TYPE_POINT3],
    ["menu_cam__offsetMult", ecs.TYPE_POINT3],
    ["menu_cam__limitYaw", ecs.TYPE_POINT2],
    ["menu_cam__limitPitch", ecs.TYPE_POINT2],
    ["menu_cam__shouldRotateTarget", ecs.TYPE_BOOL],
  ],
  comps_rq = ["camera__active"], comps_no=["scene"]})
let setDofQuery = ecs.SqQuery("setDofQuery", {
  comps_rw = [
    ["dof__on", ecs.TYPE_BOOL],
    ["dof__nearDofStart", ecs.TYPE_FLOAT],
    ["dof__nearDofEnd", ecs.TYPE_FLOAT],
    ["dof__nearDofAmountPercent", ecs.TYPE_FLOAT],
    ["dof__farDofStart", ecs.TYPE_FLOAT],
    ["dof__farDofEnd", ecs.TYPE_FLOAT],
    ["dof__farDofAmountPercent", ecs.TYPE_FLOAT],
    ["dof__bokehShape_kernelSize", ecs.TYPE_FLOAT],
    ["dof__bokehShape_bladesCount", ecs.TYPE_FLOAT],
    ["dof__minCheckDistance", ecs.TYPE_FLOAT],
    ["dof__is_filmic", ecs.TYPE_BOOL],
    ["dof__focusDistance", ecs.TYPE_FLOAT],
    ["dof__sensorHeight_mm", ecs.TYPE_FLOAT],
    ["dof__focalLength_mm", ecs.TYPE_FLOAT],
    ["dof__fStop", ecs.TYPE_FLOAT],
  ]
  comps_rq=[["is_dof", ecs.TYPE_TAG]]
})
let findScenicCamQuery = ecs.SqQuery("findScenicCamQuery", {
  comps_ro = [
    ["transform", ecs.TYPE_MATRIX],
    ["fov", ecs.TYPE_FLOAT],
    ["menu_cam__target", ecs.TYPE_EID, ecs.INVALID_ENTITY_ID],
    ["menu_cam__offset", ecs.TYPE_POINT3, Point3(0.0, 0.0, 0.0)],
    ["menu_cam__offsetMult", ecs.TYPE_POINT3, Point3(0.0, 0.0, 0.0)],
    ["menu_cam__limitYaw", ecs.TYPE_POINT2, Point2(0.0, 0.0)],
    ["menu_cam__limitPitch", ecs.TYPE_POINT2, Point2(0.0, 0.0)],
    ["menu_cam__shouldRotateTarget", ecs.TYPE_BOOL, false],
    ["scene", ecs.TYPE_STRING]
  ]})
let findScenicDofDistQuery = ecs.SqQuery("findScenicDofDistQuery", {comps_ro = [
    ["dof__on", ecs.TYPE_BOOL],
    ["scene", ecs.TYPE_STRING],
    ["dof__nearDofStart", ecs.TYPE_FLOAT],
    ["dof__nearDofEnd", ecs.TYPE_FLOAT],
    ["dof__nearDofAmountPercent", ecs.TYPE_FLOAT],
    ["dof__farDofStart", ecs.TYPE_FLOAT],
    ["dof__farDofEnd", ecs.TYPE_FLOAT],
    ["dof__farDofAmountPercent", ecs.TYPE_FLOAT],
    ["dof__bokehShape_kernelSize", ecs.TYPE_FLOAT],
    ["dof__bokehShape_bladesCount", ecs.TYPE_FLOAT],
    ["dof__minCheckDistance", ecs.TYPE_FLOAT],
    ["dof__is_filmic", ecs.TYPE_BOOL],
    ["dof__focusDistance", ecs.TYPE_FLOAT],
    ["dof__sensorHeight_mm", ecs.TYPE_FLOAT],
    ["dof__focalLength_mm", ecs.TYPE_FLOAT],
    ["dof__fStop", ecs.TYPE_FLOAT],
  ]})

function setDofDist(dof_comp){
  setDofQuery.perform(function(_eid, post_fx_comp){
    post_fx_comp.dof__on = dof_comp["dof__on"]
    post_fx_comp.dof__nearDofStart = dof_comp["dof__nearDofStart"]
    post_fx_comp.dof__nearDofEnd = dof_comp["dof__nearDofEnd"]
    post_fx_comp.dof__nearDofAmountPercent = dof_comp["dof__nearDofAmountPercent"]
    post_fx_comp.dof__farDofStart = dof_comp["dof__farDofStart"]
    post_fx_comp.dof__farDofEnd = dof_comp["dof__farDofEnd"]
    post_fx_comp.dof__farDofAmountPercent = dof_comp["dof__farDofAmountPercent"]
    post_fx_comp.dof__bokehShape_kernelSize = dof_comp["dof__bokehShape_kernelSize"]
    post_fx_comp.dof__bokehShape_bladesCount = dof_comp["dof__bokehShape_bladesCount"]
    post_fx_comp.dof__minCheckDistance = dof_comp["dof__minCheckDistance"]
    post_fx_comp.dof__is_filmic = dof_comp["dof__is_filmic"]
    post_fx_comp.dof__focusDistance = dof_comp["dof__focusDistance"]
    post_fx_comp.dof__sensorHeight_mm = dof_comp["dof__sensorHeight_mm"]
    post_fx_comp.dof__focalLength_mm = dof_comp["dof__focalLength_mm"]
    post_fx_comp.dof__fStop = dof_comp["dof__fStop"]
  })
}

let cameraOffset = Watched([0, 0, 0])
console_register_command(function(x, y, z) {
  cameraOffset([x, y, z])
}, "setCameraOffset")


function mkOffsetTMatrix(tm, offset) {
  local newTm = TMatrix(tm)
  newTm[3] = Point3(
    tm[3].x + offset[0],
    tm[3].y + offset[1],
    tm[3].z + offset[2]
  )
  return newTm
}

let setMenuItemFovProportion = ecs.SqQuery("setMenuItemFovProportion", {
  comps_rw = [
    ["menu_item__cameraCenterOffsetProportion", ecs.TYPE_FLOAT],
  ]
})

local curCameraFov = 0

function setCamera(cameraComps) {
  let camOffset = cameraOffset.value
  setCameraQuery.perform(function(_eid, comp){
    foreach (k, v in cameraComps)
      if (k in comp) {
        if (k == "transform")
          comp[k] = mkOffsetTMatrix(v, camOffset)
        else if (k == "fov") {
          comp[k] = curCameraFov + cameraFovDelta.value
          let fovProportion = 1.0 + (cameraFovDelta.value / curCameraFov)
          setMenuItemFovProportion(@(_eid, comps) comps.menu_item__cameraCenterOffsetProportion = fovProportion)
        }
        else
          comp[k] = v
      }
  })
}

//!----- quick and dirty create entities for preview ---

function createEntity(template, transform, callback = null, extraTemplates=[], attachTemplates=[]){
  if (template) {
    template = "+".join([template].extend(extraTemplates))
    let eid = ecs.g_entity_mgr.createEntity(template, { transform = transform }, callback)
    local attachesEids = ecs.CompEidList()
    foreach(attach in attachTemplates) {
      let attachEid = ecs.g_entity_mgr.createEntity(attach, {
        ["slot_attach__attachedTo"] = ecs.EntityId(eid),
        ["slot_attach__visible"] = true
      }, null)
      attachesEids.append(ecs.EntityId(attachEid))
    }
    return {eid, attachesEids}
  }
  return {eid = ecs.INVALID_ENTITY_ID}
}

let logg = DBGLEVEL !=0 ? log_for_user : log
function makeWeaponTemplate(template){
  if (template == null || template == "")
    return null

  let templ = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(template)
  local itemTemplate = templ?.getCompValNullable("item__template")
    ?? templ?.getCompValNullable("ammo_holder__templateName")
  if (itemTemplate==null){
    if (templ?.getCompValNullable("animchar__res") != null)
      itemTemplate = template
    else {
      logg("Incorrect template found for weapon meta-template:", template)
      return null
    }
  }
  return ecs.makeTemplate({
    baseTemplate = itemTemplate ?? template, addTemplates = ["item_in_world", "menu_item"]
  })
}

function setCameraTargetInScene(targetEid){
  setCamera({["menu_cam__target"] = targetEid})
}

function setDmViewerInScene(targetEid){
  setDmViewerTarget(targetEid)
}

function setDecalTargetInScene(targetEid){
  setDecalTarget(targetEid)
}

function resetCameraDirection(){
  setCamera({["menu_cam__dirInited"] = false})
}

cameraFovDelta.subscribe(@(v) setCamera({ ["fov"] = v }))

let cameraTarget = mkWatched(persist, "cameraTarget", ecs.INVALID_ENTITY_ID)
let isFadeDone = mkWatched(persist, "isFadeDone", false)

let visibleScene = Watched(scene.value)

function recreateStubFunc(...){
  logg("Incorrect recreate cb function")
}

function makeShowScene(sceneDesc, name){
  let {
    compName, watch, transformItemFunc = transformItem,
    createEntityFunc = createEntity, reInitEntityFunc = recreateStubFunc,
    shouldResetCameraDirection = Watched(false),
    recreateVersionNo = Watched(0),
    recreateSoldier = false
  } = sceneDesc
  let query = ecs.SqQuery($"query{compName}", {
    comps_ro = [["transform", ecs.TYPE_MATRIX]]
    comps_rw = [
      [ compName, ecs.TYPE_EID ],
      [ "item_attaches", ecs.TYPE_EID_LIST, null ]
    ]
  })
  let visibleWatch = Computed(@() visibleScene.value == name ? watch.value : null)
  let isSceneFading = Computed(@() visibleScene.value == name && !isFadeDone.value)
  function updateEntity(...) {
    let data = visibleWatch.value
    if (isSceneFading.value)
      return
    function update(_baseEid, comp){
      if (!recreateSoldier || comp[compName] == ecs.INVALID_ENTITY_ID) {
        let {eid, attachesEids = ecs.CompEidList()} = createEntityFunc(data, transformItemFunc(comp["transform"], data))
        ecs.g_entity_mgr.destroyEntity(comp[compName])
        comp[compName] = eid
        if (comp.item_attaches != null) {
          foreach (attach in comp.item_attaches)
            ecs.g_entity_mgr.destroyEntity(attach)
          comp.item_attaches = attachesEids
        }
      }
      else {
        let newSoldierEid = reInitEntityFunc(data, transformItemFunc(comp["transform"], data), null, comp[compName])
        if (newSoldierEid != ecs.INVALID_ENTITY_ID)
          comp[compName] = newSoldierEid
      }
      cameraTarget(comp[compName])
      if (shouldResetCameraDirection.value)
        resetCameraDirection()
    }
    query.perform(update)
  }
  let showScene = sceneDesc.__merge({
    visibleWatch
    isSceneFading
    query
    updateEntity
  })
  visibleWatch.subscribe(updateEntity)
  isSceneFading.subscribe(updateEntity)
  shouldResetCameraDirection.subscribe(updateEntity)
  recreateVersionNo.subscribe(updateEntity)
  let subscribeFunc = @(_) visibleScene.value == name ? updateEntity() : null
  foreach (w in (showScene?.slaveWatches ?? []))
    w.subscribe(subscribeFunc)
  return showScene
}

let transformByItemtype = @(transform, template) needWeaponCameraAngle.value
  ? transformItem(transform, template)
  : transformItemRelative(transform, template)

let objectsToObserve = {
  soldiers = {
    compName = "menu_char_to_control",
    createEntityFunc = @(guid, transform, callback = null) {
      eid = createSoldier({
        guid
        transform
        callback
        soldiersLookVal = soldiersLook.value
        premiumItems = allOutfitByArmy.value.map(
          @(outfitsList) outfitsList.filter(
            @(outfit) isOutfitAllowedByCampaign(
              outfit, objInfoByGuid.value?[guid], configs.value)
        ))
    })}
    watch = soldierInSoldiers
    slaveWatches = [ curCampItems, soldierViewGen, soldiersLook, allOutfitByArmy,
      objInfoByGuid, configs ]
  },
  soldiers_quarters = {
    compName = "menu_char_to_control",
    createEntityFunc = @(guid, transform, callback = null) {
      eid = createSoldier({
        guid
        transform
        callback
        soldiersLookVal = soldiersLook.value
        premiumItems = allOutfitByArmy.value.map(
          @(outfitsList) outfitsList.filter(
            @(outfit) isOutfitAllowedByCampaign(
              outfit, objInfoByGuid.value?[guid], configs.value)
        ))
    })}
    watch = soldierInSoldiers
    slaveWatches = [ curCampItems, soldierViewGen, soldiersLook, allOutfitByArmy,
      objInfoByGuid, configs ]
  },
  soldier_customization = {
    compName = "menu_char_to_control",
    recreateSoldier = true
    createEntityFunc = @(guid, transform, callback = null) {
      eid = createSoldier({
        guid
        transform
        callback
        soldiersLookVal = soldiersLook.value
        premiumItems = allOutfitByArmy.value.map(
          @(outfitsList) outfitsList.filter(
            @(outfit) isOutfitAllowedByCampaign(
              outfit, objInfoByGuid.value?[guid], configs.value)
        ))
        customizationOvr = appearanceToRender.value
    })}
    reInitEntityFunc = @(guid, transform, callback = null, reInitEid = ecs.INVALID_ENTITY_ID)
      createSoldier({
        guid
        transform
        callback
        soldiersLookVal = soldiersLook.value
        premiumItems = allOutfitByArmy.value.map(
          @(outfitsList) outfitsList.filter(
            @(outfit) isOutfitAllowedByCampaign(
              outfit, objInfoByGuid.value?[guid], configs.value)
        ))
        customizationOvr = appearanceToRender.value
        reInitEid
      })
    watch = soldierInSoldiers
    slaveWatches = [ curCampItems, soldierViewGen, appearanceToRender, soldiersLook,
      allOutfitByArmy, objInfoByGuid ]
  },
  soldier_in_middle = {
    compName = "menu_char_to_control",
    createEntityFunc = @(guid, transform, callback = null) {
      eid = createSoldier({
        guid
        transform
        callback
        soldiersLookVal = soldiersLook.value
        premiumItems = allOutfitByArmy.value.map(
          @(outfitsList) outfitsList.filter(
            @(outfit) isOutfitAllowedByCampaign(
              outfit, objInfoByGuid.value?[guid], configs.value)
        ))
        isDisarmed = true
    })}
    watch = soldierInSoldiers
    slaveWatches = [ curCampItems, soldierViewGen, soldiersLook, allOutfitByArmy,
      objInfoByGuid, configs ]
  },
  vehicles = {
    compName = "menu_vehicle_to_control",
    createEntityFunc = @(template, transform, callback = null) {
      eid = createVehicle({
        template,
        transform,
        callback,
        customazation = viewVehDecorators.value,
        extraTemplates = ["menu_vehicle"]
    })}
    transformItemFunc = @(transform, ...) transform
    watch = vehTplInVehiclesScene
    slaveWatches = [viewVehDecorators]
    shouldResetCameraDirection = Computed(@()
      !(selectVehParams.value?.isCustomMode ?? false))
    recreateVersionNo = Computed(@() selectVehParams.value?.recreateVersionNo)
  },
  aircrafts = {
    compName = "menu_aircraft_to_control",
    transformItemFunc = @(transform, ...) transform
    watch = vehTplInVehiclesScene
    shouldResetCameraDirection = Watched(true)
  },
  aircrafts_floating = {
    compName = "menu_aircraft_floating_to_control",
    transformItemFunc = @(transform, ...) transform
    watch = vehTplInVehiclesScene
    shouldResetCameraDirection = Watched(true)
  },
  armory = {
    compName = "menu_weapon_to_control",
    transformItemFunc = transformByItemtype
    createEntityFunc = @(template, transform, callback=null)
      createEntity(makeWeaponTemplate(template), transform, callback, [], itemInArmoryAttachments.value)
    watch = itemInArmory
    shouldResetCameraDirection = Watched(true)
    slaveWatches = [itemInArmoryAttachments, needWeaponCameraAngle]
  },
  items_inventory = {
    compName = "menu_shop_items_to_control"
    transformItemFunc = setItemTransformFunc
    createEntityFunc = @(template, transform, callback=null)
      createEntity(makeWeaponTemplate(template), transform, callback, [], itemInArmoryAttachments.value)
    watch = itemInArmory
    shouldResetCameraDirection = Watched(true)
    slaveWatches = [itemInArmoryAttachments]
  },
  inv_items = {
    compName = "menu_inv_items_to_control"
    watch = Watched(null)
    shouldResetCameraDirection = Watched(true)
  },
  new_items = {
    compName = "menu_new_items_to_control"
    transformItemFunc = transformItemRelative
    createEntityFunc = @(template, transform, callback=null)
      createEntity(makeWeaponTemplate(template), transform, callback, [], currentNewItemAttachments.value)
    watch = currentNewItem
    shouldResetCameraDirection = Watched(true)
  },
  shop_items = {
    compName = "menu_shop_items_to_control"
    transformItemFunc = transformByItemtype
    createEntityFunc = @(template, transform, callback=null)
      createEntity(makeWeaponTemplate(template), transform, callback, [], currentNewItemAttachments.value)
    watch = currentNewItem
    shouldResetCameraDirection = Watched(true)
    slaveWatches = [needWeaponCameraAngle]
  },
  battle_pass = {
    compName = "menu_battle_pass_to_control",
    createEntityFunc = @(template, transform, callback=null)
      createEntity(makeWeaponTemplate(template), transform, callback)
    watch = currentNewItem
    shouldResetCameraDirection = Watched(true)
  }
}.map(makeShowScene)

function updateSceneObjects(...) {
  if (!isFadeDone.value)
    return

  setCameraTargetInScene(cameraTarget.value)
  setDmViewerInScene(cameraTarget.value)
  setDecalTargetInScene(cameraTarget.value)
}

foreach (v in [cameraTarget, isFadeDone, scene])
  v.subscribe(updateSceneObjects)

registerFadeBlackActions({
  change_camera = kwarg(function(cameraComps, curScene) {
    curCameraFov = cameraComps?["fov"] ?? 0
    cameraFovDelta(0)

    setCamera(cameraComps)
    updateSceneObjects()
    visibleScene(curScene)
    findScenicDofDistQuery.perform(@(_dof_eid, dof_comp) dof_comp.scene == curScene ? setDofDist(dof_comp) : null)
    isFadeDone(true)
  })
})

function processScene(...) {
  let curScene = scene.value
  if (!curScene)
    return
  isFadeDone(false)
  local cameraNotFound = true
  findScenicCamQuery.perform(function(_eid,comp) {
    if (comp.scene != curScene)
      return
    cameraNotFound = false
    let cameraComps = {
      ["menu_cam__dirInited"] = false,
      ["menu_cam__initialDir"] = comp.transform.getcol(2),
    }
    foreach (k, v in comp)
      cameraComps[k] <- v
    doFadeBlack({ fadein = 0.33, fadeout = 0.4, action = "change_camera",
      params = { cameraComps, curScene } })
  })
  if (cameraNotFound)
    isFadeDone(true)
}
foreach(v in [scene, cameraOffset])
  v.subscribe(processScene)

function posComparator(a, b) {
  if (a.filter == b.filter)
    return a.order <=> b.order
  if (a.filter.len() < b.filter.len())
    return 1
  return -1
}

let gettransforms = @(query, posFilter) ecs.query_map(query, @(_eid, comp) {
    transform = comp["transform"]
    order = comp["priority_order"]
    isSiting = comp?.isSiting ?? false
    filter = comp?.menuPosFilter ?? ""
  })
  .filter(@(pos) pos.filter == "" || pos.filter == posFilter)
  .sort(posComparator)

let destroyEntityByQuery = @(query) query.perform(@(eid, _comp)
  ecs.g_entity_mgr.destroyEntity(eid))

/*
  background objects in squads
  todo:
   - add animated cameras
*/

local lastShownSquadToPlace = []
let currentSquadToPlace = Computed(function() {
  local newSquad = selectedSquadSoldiers.value
  if (!newSquad && soldierInSoldiers.value)
    return null

  newSquad = newSquad ?? curSquadSoldiersReady.value
  if (newSquad.len() != 0 && !isEqual(lastShownSquadToPlace, newSquad))
    lastShownSquadToPlace = newSquad
  return lastShownSquadToPlace
})

let vehicleToPlace = Computed(function() {
  log($"[scene_control] vehicleToPlace {selectedSquadSoldiers.value} {selSquadVehicleGameTpl.value} {vehTplInVehiclesScene.value}")
  let vehicle = selectedSquadSoldiers.value
    ? selSquadVehicleGameTpl.value
    : vehTplInVehiclesScene.value
  return vehicle ? [vehicle] : null
})

let createdSoldiers = nestWatched("createdSoldiers", [])

let squadPlacesQuery = ecs.SqQuery("squadPlaces", {
  comps_ro = [
    ["transform", ecs.TYPE_MATRIX],
    ["priority_order", ecs.TYPE_INT, 0],
    ["menuPosFilter", ecs.TYPE_STRING],
    ["isSiting", ecs.TYPE_BOOL],
  ]
  comps_rq = ["menu_soldier_respawnbase"]
})
let menuBackgroundSoldiersQuery = ecs.SqQuery("menuBackgroundSoldiersQuery", {
  comps_rq = ["background_menu_soldier"]
})

let createdVehicles = nestWatched("createdVehicles", [])
let vehiclesPlacesQuery = ecs.SqQuery("vehiclePlaces", {
  comps_ro = [
    ["transform", ecs.TYPE_MATRIX],
    ["priority_order", ecs.TYPE_INT, 0],
    ["menuPosFilter", ecs.TYPE_STRING]
  ]
  comps_rq = ["menu_vehicle_respawnbase"]
})
let menuBackgroundVehiclesQuery = ecs.SqQuery("menuBackgroundVehiclesQuery", {
  comps_rq = ["background_menu_vehicle"]
})

let createdEnginObjects = nestWatched("createdEnginObjects", [])
let enginObjectsPlacesQuery = ecs.SqQuery("enginObjectPlaces", {
  comps_ro = [
    ["transform", ecs.TYPE_MATRIX],
    ["priority_order", ecs.TYPE_INT, 0],
    ["menuPosFilter", ecs.TYPE_STRING]
  ]
  comps_rq = ["menu_machinegun_respawnbase"]
})


let createdItems = nestWatched("createdItems", [])
let itemsPlacesQuery = ecs.SqQuery("itemPlaces", {
  comps_ro = [
    ["transform", ecs.TYPE_MATRIX],
    ["priority_order", ecs.TYPE_INT, 0]
  ]
  comps_rq = ["menu_item_respawnbase"]
})
let menuBackgroundItemsQuery = ecs.SqQuery("menuBackgroundItemsQuery", {
  comps_rq = ["background_menu_item"]
})

//we duplicate state of created objects by creating with tag and store it in script.
//While it is enough to have it only in script it is not enough to have it in entities, because createEntity is Async and if state is changed in a one frame twice
//objects of first change will be not destroyed (they do not have tags).
let mkReplaceObjectsFunc = @(name, placesQuery, objectsQuery, createFunc, createdList, placesFilter = null)
  function replaceObjects(objects) {
    createdList.value.each(@(eid) ecs.g_entity_mgr.destroyEntity(eid))
    destroyEntityByQuery(objectsQuery)
    log($"[scene_control] replacingObjects {name} prev_count={createdList.value.len()} new_count={objects?.len()}")
    let oldTemplateName = ecs.g_entity_mgr.getEntityTemplateName(createdList.value?[0] ?? ecs.INVALID_ENTITY_ID)
    log($"[scene_control] createdList[0]={oldTemplateName} objects[0]={objects?[0]}")
    if (objects == null)
      return
    let places = gettransforms(placesQuery, placesFilter?.value ?? "")
    createdList(objects
      .slice(0, min(places.len(), objects.len()))
      .map(@(obj, i) createFunc(obj, places[i])))
  }


let poseUniqueFactors = [13, 17, 19, 23, 29, 31, 37]

function getObjectPoseIndex(object) {
  if ("links" not in object)
    return null

  let { squadId = null } = curSquad.value
  if (squadId == null)
    return null

  let squadHash = squadId.hash()
  let uniqueFactor = poseUniqueFactors[squadHash % poseUniqueFactors.len()]
  return uniqueFactor * (getItemIndex(object) + 1)
}

let replaceSoldiers = mkReplaceObjectsFunc("soldiers",
  squadPlacesQuery,
  menuBackgroundSoldiersQuery,
  @(object, place) createSoldier({
    guid = object?.guid
    transform = mkOffsetTMatrix(place.transform, cameraOffset.value)
    isSiting = place.isSiting
    soldiersLookVal = soldiersLook.value
    premiumItems = allOutfitByArmy.value.map(
      @(outfitsList) outfitsList.filter(
        @(outfit) isOutfitAllowedByCampaign(
          outfit, objInfoByGuid.value?[object?.guid], configs.value)
    ))
    extraTemplates = ["background_menu_soldier"]
    poseIndex = getObjectPoseIndex(object)
  }),
  createdSoldiers,
  squadCampaignVehicleFilter
)

let replaceVehicles = mkReplaceObjectsFunc("vehicles",
  vehiclesPlacesQuery,
  menuBackgroundVehiclesQuery,
  function(object, place) {
    let entityId = createVehicle({
      template = object
      transform = mkOffsetTMatrix(place.transform, cameraOffset.value)
      customazation = vehDataInVehiclesScene.value
      extraTemplates = ["background_menu_vehicle"]
    })
    setDecalTargetInScene(entityId)
    return entityId
  },
  createdVehicles,
  squadCampaignVehicleFilter
)

let replaceEnginObject = mkReplaceObjectsFunc("enginObject",
  enginObjectsPlacesQuery,
  menuBackgroundVehiclesQuery,
  @(object, place) createVehicle({
    template = object
    transform = mkOffsetTMatrix(place.transform, cameraOffset.value)
  }),
  createdEnginObjects,
  selectedCampaign
)

let replaceInvItems = mkReplaceObjectsFunc("items",
  itemsPlacesQuery,
  menuBackgroundItemsQuery,
  @(template, place) template == "" ? ecs.INVALID_ENTITY_ID
    : createEntity(makeWeaponTemplate(template), place.transform),
  createdItems)

registerFadeBlackActions({
  replace_soldiers     = @() replaceSoldiers(currentSquadToPlace.value)
  replace_vehicles     = @() replaceVehicles(vehicleToPlace.value)
  replace_engin_object = @() replaceEnginObject(enginObjectToPlace.value)
  replace_inv_items    = @() replaceInvItems(viewTemplates.value)
})


let currentSquadToPlaceReplace = @(...)
  doFadeBlack({ fadein = 0.2, fadeout = 0.6, action = "replace_soldiers" })
let vehicleToPlaceReplace = @(...)
  doFadeBlack({ fadein = 0.2, fadeout = 0.3, action = "replace_vehicles" })
let itemsToPlaceReplace = @(...)
  doFadeBlack({ fadein = 0.2, fadeout = 0.3, action = "replace_inv_items" })
let enginObjectToPlaceReplace = @(...)
  doFadeBlack({ fadein = 0.2, fadeout = 0.3, action = "replace_engin_object" })


foreach(v in [currentSquadToPlace, squadCampaignVehicleFilter, cameraOffset, soldiersLook])
  v.subscribe(currentSquadToPlaceReplace)

foreach(v in [vehicleToPlace, squadCampaignVehicleFilter, cameraOffset, isVehicleSceneVisible])
  v.subscribe(vehicleToPlaceReplace)

foreach(v in [enginObjectToPlace, selectedCampaign, cameraOffset])
  v.subscribe(enginObjectToPlaceReplace)


viewTemplates.subscribe(itemsToPlaceReplace)

//trigger on level loaded
ecs.register_es("setscene_es", {
    [EventLevelLoaded] = function(_evt, _eid, _comp) {
      processScene()
      objectsToObserve.each(@(v) v.updateEntity())
      currentSquadToPlaceReplace()
      vehicleToPlaceReplace()
      enginObjectToPlaceReplace()
   }
})

