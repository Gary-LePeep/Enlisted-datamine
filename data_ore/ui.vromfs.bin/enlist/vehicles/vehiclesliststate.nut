from "%enlSqGlob/ui/ui_library.nut" import *

let JB = require("%ui/control/gui_buttons.nut")
let { showMsgbox } = require("%enlist/components/msgbox.nut")
let {
  getFirstLinkByType, getObjectsByLink, getLinkedArmyName
} = require("%enlSqGlob/ui/metalink.nut")
let { itemsByArmies } = require("%enlist/meta/profile.nut")
let { curArmy, squadsByArmy, vehicleBySquad } = require("%enlist/soldiers/model/state.nut")
let { addShopItems, findItemByGuid } = require("%enlist/soldiers/model/items_list_lib.nut")
let allowedVehicles = require("allowedVehicles.nut")
let { squadsCfgById } = require("%enlist/soldiers/model/config/squadsConfig.nut")
let { trimUpgradeSuffix } = require("%enlSqGlob/ui/itemsInfo.nut")
let { curSection, jumpToArmyGrowth } = require("%enlist/mainMenu/sectionsState.nut")
let { set_vehicle_to_squad } = require("%enlist/meta/clientApi.nut")
let { curGrowthByItem} = require("%enlist/growth/growthState.nut")
let { itemToShopItem } = require("%enlist/soldiers/model/cratesContent.nut")
let { curArmyItemsPrefiltered } = require("%enlist/shop/armyShopState.nut")
let { isChangesBlocked, showBlockedChangesMessage } = require("%enlist/quickMatchQueue.nut")
let { updateBROnVehicleChange } = require("%enlist/soldiers/armySquadTier.nut")

let CAN_USE                    = 0
let AVAILABLE_IN_GROWTH        = 0x01
let CAN_PURCHASE               = 0x02
let IS_BUSY_BY_SQUAD           = 0x04
let LOCKED                     = 0x10
let CANT_USE                   = 0x20 //never can use for this squad

let viewVehicle = mkWatched(persist, "viewVehicle")
let selectVehParams = mkWatched(persist, "selectVehParams", {})

let vehicleClear = @() selectVehParams.mutate(@(v) v.clear())

curSection.subscribe(@(_) vehicleClear())

let curSquad = Computed(function() {
  let { armyId = null, squadId = null } = selectVehParams.value
  if (armyId == null || squadId == null)
    return null

  return (squadsByArmy.value?[armyId] ?? []).findvalue(@(s) s.squadId == squadId)
})

let curSquadArmy = Computed(@() curSquad.value == null ? null : getLinkedArmyName(curSquad.value))

let curVehicleType = Computed(function() {
  let { armyId = null, squadId = null } = selectVehParams.value
  if (armyId == null || squadId == null)
    return null

  return squadsCfgById.value?[armyId][squadId].vehicleType
})

let getVehicleSquad = @(vehicle) getFirstLinkByType(vehicle, "curVehicle")
let findSelVehicle = @(vehicleList, squadGuid) getObjectsByLink(vehicleList, squadGuid, "curVehicle")?[0].guid

function calcVehicleStatus(vehicle, vehicles, growthByItem, itemLinks, shopItems, vehByOwner) {
  let { basetpl } = vehicle
  let trimmed = trimUpgradeSuffix(basetpl)
  let isAllowed = trimmed in vehicles
  let growthId = growthByItem?[trimmed]
  let shopItemId = (itemLinks?[basetpl] ?? [])
    .findvalue(@(id) id in shopItems)

  local flags = CAN_USE
  if (!isAllowed)
    flags = flags | CANT_USE
  else if (vehicle?.isShopItem) {
    flags = flags | LOCKED
    if (basetpl in vehByOwner)
      flags = flags | IS_BUSY_BY_SQUAD
    else if (growthId != null)
      flags = flags | AVAILABLE_IN_GROWTH
    else if (shopItemId != null)
      flags = flags | CAN_PURCHASE
  }

  let res = { flags }
  if (flags == CAN_USE)
    res.__update({
      canUse = true
      statusText = loc("squad/vehicles")
    })
  if (flags & CANT_USE)
    res.__update({
      isHiddenInGroup = true
      statusText = loc("hint/notAllowedForCurSquad")
    })
  else if (flags & AVAILABLE_IN_GROWTH)
    res.__update({
      growthId
      statusText = loc("itemDemandsHeader/canObtainInGrowth")
    })
  else if (flags & CAN_PURCHASE)
    res.__update({
      shopItemId // TODO: Need to jump to item in shop section
      statusText = loc("itemDemandsHeader/canObtainInShop_yes")
    })
  else if (flags & IS_BUSY_BY_SQUAD)
    res.__update({
      owners = vehByOwner[basetpl]
      statusText = loc("itemDemandsHeader/busyBySquad")
    })
  else if (flags & LOCKED)
    res.statusText <- loc("hint/unknowVehicleReceive")

  return res
}

let vehicleSort = @(vehicles, curVeh)
  vehicles.sort(@(a, b) (b == curVeh) <=> (a == curVeh)
    || (a?.status.flags ?? 0) <=> (b?.status.flags ?? 0)
    || (a?.tier ?? 0) <=> (b?.tier ?? 0)
    || a.basetpl <=> b.basetpl
    || (a?.guid ?? "") <=> (b?.guid ?? ""))


let curArmyVehicles = Computed(function() {
  let armyId = curArmy.value
  return (itemsByArmies.value?[armyId] ?? {}).filter(@(i) i?.itemtype == "vehicle")
})


let vehicles = Computed(function() {
  local res = []
  let squadGuid = curSquad.value?.guid
  let vehicleType = curVehicleType.value
  if (squadGuid == null || vehicleType == null)
    return res

  let armyId = getLinkedArmyName(curSquad.value)
  let curVehicles = curArmyVehicles.value
  let vehByOwner = {}
  foreach (item in curVehicles) {
    if (item?.itemsubtype != vehicleType)
      continue

    let tpl = trimUpgradeSuffix(item.basetpl)
    let ownerGuid = getVehicleSquad(item)
    if (ownerGuid == null || ownerGuid == squadGuid)
      res.append(item)
    if (ownerGuid != null)
      vehByOwner[tpl] <- (vehByOwner?[tpl] ?? []).append(ownerGuid)
  }

  let selectedGuid = findSelVehicle(res, squadGuid)
  let haveTmpls = res.reduce(@(r, v) r.rawset(trimUpgradeSuffix(v.basetpl), true), {})
  let filterFunc = @(tplId, tpl) tpl?.itemtype == "vehicle"
    && (tpl?.itemsubtype ?? "") == vehicleType
    && (tpl?.upgradeIdx ?? 0) == 0
    && trimUpgradeSuffix(tplId) not in haveTmpls

  addShopItems(res, armyId, filterFunc)

  let allowed = allowedVehicles.value?[armyId][curSquad.value?.squadId] ?? {}
  let growthByItem = curGrowthByItem.value
  let itemLinks = itemToShopItem.value?[armyId] ?? {}
  let shopItems = curArmyItemsPrefiltered.value
  res = res.map(@(vehicle) vehicle.__merge({
    status = calcVehicleStatus(vehicle, allowed, growthByItem, itemLinks, shopItems, vehByOwner)
  }))
  vehicleSort(res, res.findvalue(@(v) v.guid == selectedGuid))
  return res
})

let selectedVehicle = Computed(function() {
  let vList = vehicles.value
  let squadGuid = curSquad.value?.guid
  if (!squadGuid || vList.len() == 0)
    return null

  let guid = findSelVehicle(vList.filter(@(v) v?.isShopItem != true), squadGuid)
  return guid ? findItemByGuid(vList, guid) : null
})

if (viewVehicle.value != null) {
  let cur = viewVehicle.value
  let new = cur?.isShopItem ? vehicles.value.findvalue(@(item) item?.basetpl == cur.basetpl)
    : cur?.guid ? findItemByGuid(vehicles.value, cur.guid)
    : cur ? vehicles.value[0]
    : null
  viewVehicle(new ?? selectedVehicle.value)
}

selectedVehicle.subscribe(@(v) viewVehicle(v))

function setVehicleToSquad(squadGuid, vehicleGuid) {
  if (vehicleBySquad.value?[squadGuid] == vehicleGuid)
    return

  set_vehicle_to_squad(vehicleGuid, squadGuid, @(_) updateBROnVehicleChange(squadGuid))
}

function selectVehicle(vehicle) {
  if (isChangesBlocked.value) {
    showBlockedChangesMessage()
    return
  }
  let { canUse = false, statusText = null, growthId = null } = vehicle?.status
  if (!canUse) {
    let buttons = [{
      text = loc("Close"), isCancel = true, customStyle = { hotkeys = [[$"^{JB.B} | Esc"]] }
    }]
    if (growthId != null)
      buttons.append({
        text = loc("GoToGrowth")
        action = @() jumpToArmyGrowth(growthId)
        customStyle = { hotkeys = [["^J:Y"]] }
      })
    return showMsgbox({
      text = statusText
      buttons
    })
  }

  let squad = curSquad.value
  if (squad != null)
    setVehicleToSquad(squad.guid, vehicle?.guid)

  vehicleClear()
}

let hasSquadVehicle = @(squadCfg) (squadCfg?.vehicleType ?? "") != ""

let squadsWithVehicles = Computed(function() {
  let { armyId = null } = selectVehParams.value
  if (!armyId)
    return null

  let armyConfig = squadsCfgById.value?[armyId]
  return (squadsByArmy.value?[armyId] ?? [])
    .filter(@(squad) hasSquadVehicle(armyConfig?[squad.squadId]))
})

let curSquadId = Computed(@()
  selectVehParams.value?.squadId ?? squadsWithVehicles.value?[0].squadId)

function setCurSquadId(id) {
  let { squadId = null } = selectVehParams.value
  if (squadId != null && squadId != id)
    selectVehParams.mutate(@(params) params.__update({ squadId = id }))
}

return {
  viewVehicle
  selectedVehicle
  selectVehParams
  vehicles
  squadsWithVehicles
  curSquad
  curSquadId
  setCurSquadId
  curSquadArmy

  vehicleClear
  selectVehicle
  hasSquadVehicle
  getVehicleSquad

  AVAILABLE_IN_GROWTH
  IS_BUSY_BY_SQUAD
  CAN_PURCHASE
  LOCKED
  CANT_USE
  CAN_USE
}