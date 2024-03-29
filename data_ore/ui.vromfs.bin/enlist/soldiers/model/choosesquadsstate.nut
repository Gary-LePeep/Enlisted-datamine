from "%enlSqGlob/ui/ui_library.nut" import *

let serverTime = require("%enlSqGlob/userstats/serverTime.nut")
let { jumpToArmyProgress } = require("%enlist/mainMenu/sectionsState.nut")
let { soldiersBySquad, squadsByArmy, chosenSquadsByArmy, vehicleBySquad, limitsByArmy,
  armyLimitsDefault, curArmy, lockedSquadsByArmy
} = require("state.nut")
let { set_squad_order, sell_squad } = require("%enlist/meta/clientApi.nut")
let { squadsCfgById, allSquadTypes } = require("%enlist/soldiers/model/config/squadsConfig.nut")
let { soldiersStatuses } = require("readySoldiers.nut")
let { READY } = require("%enlSqGlob/readyStatus.nut")
let { allSquadsLevels } = require("%enlist/researches/researchesState.nut")
let { markSeenSquads } = require("unseenSquads.nut")
let msgbox = require("%enlist/components/msgbox.nut")
let { trimUpgradeSuffix, getItemName } = require("%enlSqGlob/ui/itemsInfo.nut")
let { curCampaign } = require("%enlist/meta/curCampaign.nut")
let { addPopup } = require("%enlSqGlob/ui/popup/popupsState.nut")
let { sendBigQueryUIEvent } = require("%enlist/bigQueryEvents.nut")
let armiesPresentation = require("%enlSqGlob/ui/armiesPresentation.nut")
let squadsPresentation = require("%enlSqGlob/ui/squadsPresentation.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { growthSquadsByArmy, curGrowthConfig } = require("%enlist/growth/growthState.nut")
let { allItemTemplates } = require("%enlist/soldiers/model/all_items_templates.nut")
let { needNewItemsWindow } = require("newItemsToShow.nut")


let justGainSquadId = Watched(null)
let selectedSquadId = Watched(null)
let previewSquads = Watched(null)
let squadsArmy = mkWatched(persist, "squadsArmy")
let curChoosenSquads = Computed(@() chosenSquadsByArmy.value?[squadsArmy.value] ?? [])
let curUnlockedSquads = Computed(@() squadsByArmy.value?[squadsArmy.value] ?? [])

let chosenSquads = mkWatched(persist, "chosen", [])
let reserveSquads = mkWatched(persist, "reserve", [])
let displaySquads = Computed(@() previewSquads.value ?? clone chosenSquads.value)

let unlockedSquads = Computed(@() (clone chosenSquads.value).extend(reserveSquads.value))
let slotsCount = Computed(@() chosenSquads.value.len())
let focusedSquads = mkWatched(persist, "focused", {})


let sellableSquadsCfg = Computed(function() {
  let res = {}
  foreach (armyId, armySquadsCfg in squadsCfgById.value) {
    res[armyId] <- {}
    foreach (squadId, squadCfg in armySquadsCfg) {
      let { battleExpBonus = 0, silverSellCost = 0 } = squadCfg
      if (battleExpBonus == 0 && silverSellCost > 0)
        res[armyId][squadId] <- silverSellCost
    }
  }
  return res
})


let sellableSquads = Computed(function() {
  let res = {}
  let unlocked = unlockedSquads.value.filter(@(s) s != null)
  if (unlocked.len() == 0)
    return res

  let armyId = curArmy.value
  let sellableCfg = sellableSquadsCfg.value?[armyId] ?? {}
  let growthSquads = growthSquadsByArmy.value?[armyId] ?? {}

  foreach (squad in unlocked) {
    let { squadId } = squad
    if (squadId in growthSquads)
      continue

    let silverSellCost = sellableCfg?[squadId] ?? 0
    if (silverSellCost > 0)
      res[squadId] <- silverSellCost
  }

  return res
})

focusedSquads.subscribe(@(focused) reserveSquads.mutate(@(v) v
  .reduce(@(list, sq) sq.squadId in focused
    ? list.insert(0, sq)  // warning disable: -unwanted-modification
    : list.append(sq), []) // warning disable: -unwanted-modification
  ))

let close = @() squadsArmy(null)

curCampaign.subscribe(function(_) {
  if (squadsArmy.value == null)
    return
  close()
  addPopup({
    id = "close_squads_manage"
    text = loc("msg/closeSquadManageOnCampaignChange")
  })
})


function getGrowthData(growthId, isPremium, growthCfgs, templates) {
  if (growthId == null)
    return null

  let { col = 0, reward = null } = growthCfgs?[growthId]
  let { itemTemplate = null } = reward

  let res = { growthId, col }
  if (itemTemplate == null)
    return res

  let item = templates?[itemTemplate]
  if (item != null) {
    let lock = isPremium ? "growth/reqToBuyGrowth" : "growth/reqToResearchGrowth"
    res.lockTxt <- loc(lock, { reqText = getItemName(item) })
  }
  return res
}

let curArmyLockedSquadsData = Computed(function() {
  let armyId = curArmy.value
  let growthCfgs = curGrowthConfig.value
  let growthLinks = growthSquadsByArmy.value?[armyId] ?? {}
  let templates = allItemTemplates.value?[armyId] ?? {}
  let armyPremIcon = armiesPresentation?[armyId].premIcon

  let squadsRes = (lockedSquadsByArmy.value?[armyId] ?? [])
    .map(function(squad) {
      let { squadId } = squad
      let { battleExpBonus = 0 } = squadsCfgById.value?[armyId][squadId]
      let isPremium = battleExpBonus > 0
      let growthData = getGrowthData(growthLinks?[squadId], isPremium, growthCfgs, templates)
      local { premIcon = null } = squadsPresentation?[armyId][squadId]
      if (isPremium)
        premIcon = premIcon ?? armyPremIcon

      return squad.__merge({
        premIcon
        isPremium
        growthData
      })
    })
    .filter(@(s) s.growthData != null)
    .sort(@(a, b) b.isPremium <=> a.isPremium)

  return squadsRes
})

let squadsArmyLimits = Computed(@() limitsByArmy.value?[squadsArmy.value] ?? armyLimitsDefault)
let maxSquadsInBattle = Computed(@() squadsArmyLimits.value.maxSquadsInBattle)


let prepareSquad = @(squad, cfg, squadsLevel) squad.__merge({
  level = squadsLevel?[squad.squadId] ?? 0
  manageLocId = squad?.manageLocId ?? cfg?.manageLocId
  icon = squad?.icon ?? cfg?.icon
  vehicle = squad?.vehicle
  squadSize = squad?.squadSize ?? soldiersBySquad.value?[squad.guid].len() ?? 0
  battleExpBonus = cfg?.battleExpBonus ?? 0
})

let preparedSquads = Computed(function() {
  let visOrdered = clone curChoosenSquads.value
  foreach (squad in curUnlockedSquads.value)
    if (curChoosenSquads.value.indexof(squad) == null)
      visOrdered.append(squad)
  return visOrdered.map(@(squad) prepareSquad(squad, squadsCfgById.value?[squadsArmy.value][squad.squadId], allSquadsLevels.value))
})

function updateSquadsList(_ = null) {
  let all = preparedSquads.value
  if (all.len() == 0) {
    chosenSquads.mutate(@(v) v.clear())
    reserveSquads.mutate(@(v) v.clear())
    return
  }
  let byId = {}
  all.each(@(s) byId[s.squadId] <- s)
  local chosen = chosenSquads.value.map(@(s) byId?[s?.squadId])
  let chosenCount = chosen.filter(@(s) s != null).len()
  local reserve = reserveSquads.value.map(@(s) byId?[s.squadId])
    .filter(@(s) s != null)

  if (chosenCount == 0 && reserve.len() == 0) { //new list, or just opened window
    let amount = curChoosenSquads.value.len()
    chosen = all.slice(0, amount)
    reserve = all.slice(amount)

    let gainSquadId = justGainSquadId.value
    if (gainSquadId != null) {
      let gainSquadIdx = chosen.findindex(@(s) s.squadId == gainSquadId)
      if (gainSquadIdx != null)
        reserve = [chosen.remove(gainSquadIdx)].extend(reserve)
    }
  }
  else {
    let left = clone byId
    chosen.each(function(s) { if (s != null) left.$rawdelete(s.squadId) })
    reserve.each(function(s) { if (s.squadId in left) left.$rawdelete(s.squadId) })
    foreach (squad in all)
      if (squad.squadId in left)
        reserve.append(squad)
  }

  if (chosen.len() != maxSquadsInBattle.value)
    chosen.resize(maxSquadsInBattle.value)

  chosenSquads(chosen)
  reserveSquads(reserve)
}
updateSquadsList()
foreach (v in [preparedSquads, maxSquadsInBattle]) v.subscribe(updateSquadsList)

preparedSquads.subscribe(function(uSquads) {
  if (uSquads.findvalue(@(s) s.squadId == selectedSquadId.value) != null)
    return
  selectedSquadId(uSquads?[0].squadId)
})

function moveIndex(list, idxFrom, idxTo) {
  let res = clone list
  let val = res.remove(idxFrom)
  res.insert(idxTo, val)
  return res
}

let getSquadType = @(squadType) allSquadTypes.value.findvalue(@(s) s.squadType == squadType)

let squadPlaceReasonData = {
  limit = {
    type = "limit"
    getErrorText = @() loc("msg/cantTakeExpiredSquad")
  }
  squadTypeZero = @(squadType) {
    type = $"{squadType}Zero"
    squadType
    getErrorText = @() loc($"msg/{squadType}IsZero")
  }
  squadTypeFull = @(squadType, maxSquads) {
    type = $"{squadType}Full"
    squadType
    getErrorText = @() loc($"msg/{squadType}Full", { maxSquads })
  }
  squadTypeLimit = @(squadType, count) {
    type = $"{squadType}Limit"
    squadType
    getErrorText = @() loc($"msg/SquadTypeLimit", {
      squad = getSquadType(squadType)?.nameText ?? ""
      count
    })
  }
}

let getSquadTypeLimitId = @(vehicleType) vehicleType == "bike" ? "maxBikeSquads"
  : vehicleType == "truck" ? "maxTransportSquads"
  : vehicleType != "" ? "maxVehicleSquads"
  : "maxInfantrySquads"

function isSquadExpired(squad) {
  let { expireTime = 0 } = squad
  return expireTime > 0 && expireTime < serverTime.value
}

function getCantTakeSquadReasonData(squad, squadsList, idxTo) {
  if (isSquadExpired(squad))
    return squadPlaceReasonData.limit()

  let { vehicleType = "", squadType } = squad
  let typeId = getSquadTypeLimitId(vehicleType)
  let maxType = squadsArmyLimits.value[typeId]

  local curCount = 0
  foreach (idx, s in squadsList) {
    if (s == null || idx == idxTo)
      continue

    let squadTypeId = getSquadTypeLimitId(s?.vehicleType ?? "")
    if (typeId == squadTypeId)
      ++curCount
  }
  if (curCount >= maxType)
    return squadPlaceReasonData.squadTypeFull(typeId, maxType)

  local typeLimits = squadsArmyLimits.value?.squadTypeLimits[squadType] ?? 0
  if (typeLimits > 0 && squad.battleExpBonus <= 0.0) {
    local curType = 0
    foreach (idx, s in squadsList) {
      if (s == null || idx == idxTo)
        continue

      if (s.battleExpBonus <= 0.0 && squadType == s.squadType) {
        ++curType
        if (curType > typeLimits)
          return squadPlaceReasonData.squadTypeLimit(squadType, typeLimits)
      }
    }
  }

  return null
}

let getCantTakeReason = @(squad, squadsList, idxTo)
  getCantTakeSquadReasonData(squad, squadsList, idxTo)?.getErrorText()

function sendSquadActionToBQ(eventType, squadGuid, squadId) {
  sendBigQueryUIEvent("squad_management", null, {
    eventType
    squadGuid
    squadId
    army = squadsArmy.value
  })
}

function changeSquadOrderByUnlockedIdx(idxFrom, idxTo) {
  let watchFrom = idxFrom < maxSquadsInBattle.value ? chosenSquads : reserveSquads
  if (idxFrom >= maxSquadsInBattle.value)
    idxFrom -= maxSquadsInBattle.value
  let { guid = null } = watchFrom.value?[idxFrom]
  let squadIdFrom = watchFrom.value?[idxFrom].squadId
  let watchTo = idxTo < maxSquadsInBattle.value ? chosenSquads : reserveSquads
  if (idxTo >= maxSquadsInBattle.value)
    idxTo -= maxSquadsInBattle.value

  if (watchFrom == watchTo) {
    watchFrom(moveIndex(watchFrom.value, idxFrom, idxTo))
    markSeenSquads(squadsArmy.value, [squadIdFrom])
    sendSquadActionToBQ("change_order", guid, squadIdFrom)
    return
  }
  if (watchFrom == chosenSquads) {
    if (chosenSquads.value[idxFrom] == null)
      return
    reserveSquads.mutate(@(list) list.insert(idxTo, chosenSquads.value[idxFrom]))
    chosenSquads.mutate(function(list) { list[idxFrom] = null })
    markSeenSquads(squadsArmy.value, [squadIdFrom])
    sendSquadActionToBQ("move_to_reserve", guid, squadIdFrom)
    return
  }

  if (idxFrom not in reserveSquads.value)
    return

  let cantChangeReason = getCantTakeReason(reserveSquads.value[idxFrom], chosenSquads.value, idxTo)
  if (cantChangeReason == null) {
    let prevSquad = chosenSquads.value[idxTo]
    chosenSquads.mutate(@(list) list[idxTo] = reserveSquads.value[idxFrom])
    reserveSquads.mutate(function(list) {
      if (prevSquad)
        list[idxFrom] = prevSquad
      else
        list.remove(idxFrom)
    })
    markSeenSquads(squadsArmy.value, [squadIdFrom])
    sendSquadActionToBQ("move_to_squad", guid, squadIdFrom)
    return
  }

  sendSquadActionToBQ("failed_management", guid, squadIdFrom)
  msgbox.show({
    uid = "change_squad_order"
    text = cantChangeReason
  })
}

function changeList() {
  let squadId = selectedSquadId.value
  if (squadId == null)
    return

  local idx = chosenSquads.value.findindex(@(s) s?.squadId == squadId)
  if (idx != null) {
    markSeenSquads(squadsArmy.value, [squadId])
    reserveSquads.mutate(@(v) v.insert(0, chosenSquads.value[idx]))
    chosenSquads.mutate(function(v) { v[idx] = null })
    return
  }

  idx = reserveSquads.value.findindex(@(s) s.squadId == squadId)
  if (idx == null)
    return

  let newIdx = chosenSquads.value.findindex(@(s) s == null)
  if (newIdx == null) {
    msgbox.show({ text = loc("msg/battleSquadsFull") })
    return
  }
  let cantChangeReason = getCantTakeReason(reserveSquads.value[idx], chosenSquads.value, newIdx)
  if (cantChangeReason != null) {
    msgbox.show({
      uid = "change_squad_order"
      text = cantChangeReason
    })
    return
  }

  markSeenSquads(squadsArmy.value, [squadId])
  chosenSquads.mutate(function(v) { v[newIdx] = reserveSquads.value[idx] })
  reserveSquads.mutate(@(v) v.remove(idx))
}

function findLastIndexToTakeSquad(squad) {
  let res = chosenSquads.value.findindex(@(s) s == null)
  if (res != null && getCantTakeReason(squad, chosenSquads.value, res) == null)
    return res

  for(local i = chosenSquads.value.len() - 1; i >= 0; i--)
    if (getCantTakeReason(squad, chosenSquads.value, i) == null)
      return i

  return -1
}

let selectedSquad = Computed(@()
  curUnlockedSquads.value.findvalue(@(squad) squad.squadId == selectedSquadId.value))

let selectedSquadSoldiers = Computed(function() {
  if (needNewItemsWindow.value)
    return null

  let squadGuid = selectedSquad.value?.guid
  if (squadGuid == null)
    return null

  let statuses = soldiersStatuses.value
  return (soldiersBySquad.value?[squadGuid] ?? [])
    .filter(@(soldier) statuses?[soldier?.guid] == READY)
})

let selSquadVehicleGameTpl = Computed(@()
  trimUpgradeSuffix(vehicleBySquad.value?[selectedSquad.value?.guid].gametemplate))

function applyAndCloseImpl() {
  let armyId = squadsArmy.value
  let guids = unlockedSquads.value.filter(@(s) s != null).map(@(s) s.guid)
  let ids = unlockedSquads.value.filter(@(s) s != null).map(@(s) s.squadId)
  markSeenSquads(armyId, ids)
  set_squad_order(armyId, guids)
  close()
}

function sellSquad(armyId, squadGuid, silverCost) {
  sell_squad(armyId, squadGuid, silverCost)
}

function applyAndClose() {
  let selCount = chosenSquads.value.filter(@(s) s != null).len()
  if (selCount >= curChoosenSquads.value.len())
    applyAndCloseImpl()
  else
    msgbox.show({
      text = loc("msg/notFullSquadsAtApply")
      buttons = [
        { text = loc("Ok"), action = applyAndCloseImpl, isCurrent = true }
        { text = loc("Cancel"), isCancel = true, customStyle = { hotkeys = [[$"^{JB.B} | Esc"]] } }
      ]
    })
}

function focusSquad(squadId) {
  if (squadId not in focusedSquads.value)
    focusedSquads.mutate(@(v) v.__merge({ [squadId] = true }))
}

function unfocusSquad(squadId) {
  if (squadId in focusedSquads.value)
    focusedSquads.mutate(@(v) v.$rawdelete(squadId))
}

function closeAndOpenCampaign() {
  jumpToArmyProgress()
  close()
}

function getUnlockedSquadsBySquadIds(squadIdsList) {
  return squadIdsList
    .map(@(squadId) unlockedSquads.value.findvalue(@(squad) squad?.squadId == squadId))
    .filter(@(squad) squad != null)
}

console_register_command(function(squadId) {
  if (squadId in focusedSquads.value)
    unfocusSquad(squadId)
  else
    focusSquad(squadId)
  console_print($"{squadId} toggled to", focusedSquads.value)
}, "meta.toggleFocusSquad")

return {
  openChooseSquadsWnd = function(army, selSquadId, isNew = false) {
    selectedSquadId(selSquadId)
    justGainSquadId(isNew ? selSquadId : null)
    squadsArmy(army)
  }
  closeChooseSquadsWnd = close
  applyAndClose
  closeAndOpenCampaign
  squadsArmy
  squadsArmyLimits
  maxSquadsInBattle
  unlockedSquads
  sellableSquads
  curArmyLockedSquadsData
  chosenSquads
  reserveSquads
  previewSquads
  displaySquads
  slotsCount
  changeSquadOrderByUnlockedIdx
  moveIndex
  changeList
  getCantTakeReason
  findLastIndexToTakeSquad
  focusedSquads
  focusSquad
  unfocusSquad

  selectedSquadId
  selectedSquad
  selectedSquadSoldiers
  selSquadVehicleGameTpl
  sendSquadActionToBQ
  getUnlockedSquadsBySquadIds
  isSquadExpired
  getCantTakeSquadReasonData
  sellSquad
}