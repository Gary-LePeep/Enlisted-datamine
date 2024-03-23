from "%enlSqGlob/ui/ui_library.nut" import *

let { curCampSquads, soldiersBySquad, squadsByArmy, objInfoByGuid, curArmy } = require("state.nut")
let { defSoldierGuid, collectSoldierData } = require("%enlist/soldiers/model/curSoldiersState.nut")
let { manage_squad_soldiers, update_profile, lastRequests, swap_soldiers_equipment
} = require("%enlist/meta/clientApi.nut")
let { dismissReserveSoldiers } = require("soldierActions.nut")
let { allReserveSoldiers } = require("reserve.nut")
let { READY, TOO_MUCH_CLASS, NOT_FIT_CUR_SQUAD, NOT_READY_BY_EQUIP, invalidEquipSoldiers
} = require("readySoldiers.nut")
let { getLinkedArmyName } = require("%enlSqGlob/ui/metalink.nut")
let squadsParams = require("squadsParams.nut")
let { debounce } = require("%sqstd/timers.nut")
let { soldierClasses } = require("%enlSqGlob/ui/soldierClasses.nut")
let msgbox = require("%enlist/components/msgbox.nut")
let sClassesCfg = require("config/sClassesConfig.nut")
let { curSection} = require("%enlist/mainMenu/sectionsState.nut")
let { getClosestResearch, focusResearch } = require("%enlist/researches/researchesFocus.nut")
let { armiesResearches, allResearchStatus, RESEARCHED, GROUP_RESEARCHED
} = require("%enlist/researches/researchesState.nut")
let { sendBigQueryUIEvent } = require("%enlist/bigQueryEvents.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { unseenSoldiers, markSoldierSeen } = require("%enlist/soldiers/model/unseenSoldiers.nut")
let { isChangesBlocked, showBlockedChangesMessage } = require("%enlist/quickMatchQueue.nut")
let { calcBROnSoldierChange } = require("%enlist/soldiers/armySquadTier.nut")

let curSquadSoldierIdx = Watched(null)
let selectedSoldierGuid = Watched(null)
selectedSoldierGuid.subscribe(@(v) defSoldierGuid(v))
let isPurchaseWndOpend = Watched(false)

let soldiersSquadGuid = mkWatched(persist, "soldiersSquadGuid")
let soldiersArmy = Computed(function() {
  let squadObj = curCampSquads.value?[soldiersSquadGuid.value]
  return squadObj != null ? getLinkedArmyName(squadObj) : null
})
let soldiersSquad = Computed(@() (squadsByArmy.value?[soldiersArmy.value] ?? [])
  .findvalue(@(s) s.guid == soldiersSquadGuid.value))
let curSquadSoldiers = Computed(@() soldiersBySquad.value?[soldiersSquadGuid.value] ?? [])
let curReserveSoldiers = Computed(@() allReserveSoldiers.value?[soldiersArmy.value] ?? [])

let squadSoldiers = mkWatched(persist, "chosen", [])
let reserveSoldiers = mkWatched(persist, "reserve", [])
let soldiersSquadParams = Computed(@() squadsParams.value?[soldiersArmy.value][soldiersSquad.value?.squadId])
let maxSoldiersInBattle = Computed(@() soldiersSquadParams.value?.size ?? 1)

let selectedSoldier = Computed(function() {
  let guid = selectedSoldierGuid.value
  return squadSoldiers.value.findvalue(@(s) s?.guid == guid)
    ?? reserveSoldiers.value.findvalue(@(s) s?.guid == guid)
})

let ignoreStatuses = { [GROUP_RESEARCHED] = true, [RESEARCHED] = true }
let squadKindResearches = Computed(function() {
  let { squadId = null } = soldiersSquad.value
  if (squadId == null)
    return {}

  let armyId = soldiersArmy.value
  let statuses = allResearchStatus.value?[armyId] ?? {}
  let researchesBySKind = {}
  foreach (research in armiesResearches.value?[armyId].researches ?? {})
    foreach (sKind, amount in (research?.effect.squad_class_limit[squadId] ?? {}))
      if (amount > 0 && !(ignoreStatuses?[statuses?[research.research_id]] ?? false)) {
        if (sKind not in researchesBySKind)
          researchesBySKind[sKind] <- []
        researchesBySKind[sKind].append(research)
      }
  return researchesBySKind.map(@(list) getClosestResearch(armyId, list, statuses))
})

function calcSoldiersStatuses(squadParams, chosen, reserve, invalidEquip, kindResearches) {
  let maxClasses = squadParams?.maxClasses ?? {}
  let leftClasses = clone maxClasses

  let res = {}
  foreach (soldier in chosen) {
    if (soldier == null)
      continue
    let { sKind } = soldier
    local status = NOT_FIT_CUR_SQUAD | TOO_MUCH_CLASS
    if ((leftClasses?[sKind] ?? 0) > 0) {
      leftClasses[sKind]--
      status = READY
    }
    else if ((maxClasses?[sKind] ?? 0) > 0)
      status = TOO_MUCH_CLASS

    if (invalidEquip?[soldier.guid])
      status = status | NOT_READY_BY_EQUIP

    res[soldier.guid] <- status
  }
  foreach (soldier in reserve) {
    let { sKind = null } = soldier
    local status
    if ((maxClasses?[sKind] ?? 0) <= 0)
      status = sKind in kindResearches ? TOO_MUCH_CLASS
        : NOT_FIT_CUR_SQUAD | TOO_MUCH_CLASS
    else
      status = (leftClasses?[sKind] ?? 0) <= 0 ? TOO_MUCH_CLASS : READY
    if (invalidEquip?[soldier.guid])
      status = status | NOT_READY_BY_EQUIP
    res[soldier.guid] <- status
  }
  return res
}

let soldiersStatuses = Computed(@() calcSoldiersStatuses(soldiersSquadParams.value,
  squadSoldiers.value, reserveSoldiers.value, invalidEquipSoldiers.value, squadKindResearches.value))


function updateSoldiersList(sort = false) {
  if (curSquadSoldiers.value.len() == 0 && curReserveSoldiers.value.len() == 0) {
    squadSoldiers.mutate(@(v) v.clear())
    reserveSoldiers.mutate(@(v) v.clear())
    return
  }
  let byGuid = {}
  curSquadSoldiers.value.each(@(s) byGuid[s.guid] <- s)
  curReserveSoldiers.value.each(@(s) byGuid[s.guid] <- s)

  local chosen = squadSoldiers.value.map(@(s) byGuid?[s?.guid])
  let chosenCount = chosen.filter(@(s) s != null).len()
  local reserve = reserveSoldiers.value.map(@(s) byGuid?[s.guid])
    .filter(@(s) s != null)

  local needSort = sort
  if (chosenCount == 0 && reserve.len() == 0) { //new list, or just opened window
    chosen = clone curSquadSoldiers.value
    reserve = clone curReserveSoldiers.value
    needSort = true
  }
  else {
    chosen.each(function(s) { if (s != null) byGuid.$rawdelete(s.guid) })
    reserve.each(@(s) byGuid.$rawdelete(s.guid))
    foreach (soldier in curSquadSoldiers.value)
      if (soldier.guid in byGuid)
        reserve.append(soldier)

    foreach (soldier in curReserveSoldiers.value)
      if (soldier.guid in byGuid)
        reserve.append(soldier)
  }

  let count = maxSoldiersInBattle.value
  if (chosen.len() < count)
    chosen.resize(count)
  else if (chosen.len() > count) {
    reserve = chosen.slice(count).extend(reserve)
    chosen = chosen.slice(0, count)
  }

  let objInfo = objInfoByGuid.value
  let mkSoldierData = @(s) s == null ? s : (collectSoldierData(objInfo?[s.guid] ?? s))
  chosen = chosen.map(mkSoldierData)
  reserve = reserve.map(mkSoldierData)

  if (needSort) {
    let statuses = calcSoldiersStatuses(soldiersSquadParams.value,
      chosen, reserve, invalidEquipSoldiers.value, squadKindResearches.value)
    reserve.sort(@(a, b) statuses[a.guid] <=> statuses[b.guid]
      || b.level <=> a.level
      || a.sKind <=> b.sKind
      || a.sClass <=> b.sClass)
  }

  squadSoldiers(chosen)
  reserveSoldiers(reserve)
}

updateSoldiersList()
let updateSoldiersListDebounced = debounce(@() updateSoldiersList(), 0.05)
let updateSoldiersListAndSortDebounced = debounce(@() updateSoldiersList(true), 0.05)
foreach (v in [curSquadSoldiers, curReserveSoldiers, maxSoldiersInBattle, objInfoByGuid])
  v.subscribe(@(_) updateSoldiersListDebounced())

function moveIndex(list, idxFrom, idxTo) {
  let res = clone list
  let val = res.remove(idxFrom)
  res.insert(idxTo, val)
  return res
}

let getSClassName = @(sClass) loc(soldierClasses?[sClass].locId ?? "unknown")

function getCantTakeReason(soldier, soldiersList, idxTo) {
  let { sKind } = soldier
  let reqResearch = squadKindResearches.value?[sKind]
  let maxClass = soldiersSquadParams.value?.maxClasses[sKind] ?? 0
  if (maxClass <= 0)
    return {
      msgText = loc("msg/maxClassInSquadIsZero", {
        sClass = getSClassName(sKind)
      })
      reqResearch
    }

  let tgtKind = soldiersList?[idxTo].sKind
  if (sKind == tgtKind)
    return null

  let count = soldiersList.filter(@(s) s?.sKind == sKind).len()
  if (count < maxClass)
    return null

  return {
    msgText = loc("msg/maxClassInSquadIsFull", {
      sClass = getSClassName(sKind), count = maxClass
    })
    reqResearch
  }
}

function getCanTakeSlots(soldier, soldiersList) {
  let { sKind } = soldier
  let maxClass = soldiersSquadParams.value?.maxClasses[sKind] ?? 0
  if (maxClass <= 0)
    return array(soldiersList.len(), false)

  let classCount = soldiersList.filter(@(s) s?.sKind == sKind).len()
  if (classCount != maxClass)
    return array(soldiersList.len(), classCount < maxClass)
  return soldiersList.map(@(s) s?.sKind == sKind)
}

function isTransferAvailable(soldier, isFromReserve = false) {
  if (soldier == null)
    return true
  let { sClass } = soldier
  if (sClassesCfg.value?[sClass].isTransferLocked ?? false) {
    msgbox.show({
      text = loc(isFromReserve ? "msg/cantReplaceClassSoldier" : "msg/cantMoveClassSoldier",
        { sClass = getSClassName(sClass) })
    })
    return false
  }
  return true
}

function sendSoldierActionToBQ(eventType, soldier, squadGuid = "") {
  let { guid, level, sClass } = soldier
  sendBigQueryUIEvent("soldier_management", null, {
    eventType
    squadGuid
    army = soldiersArmy.value
    soldierGuid = guid
    soldierLevel = level
    soldierClass = sClass
  })
}

function changeSoldierOrderByIdx(idxFrom, idxTo) {
  if (isChangesBlocked.value) {
    showBlockedChangesMessage()
    return
  }
  let watchFrom = idxFrom < maxSoldiersInBattle.value ? squadSoldiers : reserveSoldiers
  if (idxFrom >= maxSoldiersInBattle.value)
    idxFrom -= maxSoldiersInBattle.value
  let watchTo = idxTo < maxSoldiersInBattle.value ? squadSoldiers : reserveSoldiers
  if (idxTo >= maxSoldiersInBattle.value)
    idxTo -= maxSoldiersInBattle.value
  if (watchFrom == watchTo) {
    sendSoldierActionToBQ("change_order", watchFrom.value[idxFrom], soldiersSquadGuid.value)
    watchFrom(moveIndex(watchFrom.value, idxFrom, idxTo))
    return
  }

  if (watchFrom == squadSoldiers) {
    let squadSoldier = squadSoldiers.value?[idxFrom]
    if (squadSoldier == null)
      return

    if (!isTransferAvailable(squadSoldier))
      return

    reserveSoldiers.mutate(@(list) list.insert(idxTo, squadSoldiers.value[idxFrom]))
    squadSoldiers.mutate(@(list) list[idxFrom] = null)
    return
  }

  let reserveSoldier = reserveSoldiers.value[idxFrom]
  let cantChangeReason = getCantTakeReason(reserveSoldier, squadSoldiers.value, idxTo)
  if (cantChangeReason == null) {
    let prevSoldier = squadSoldiers.value[idxTo]
    if (!isTransferAvailable(prevSoldier, true))
      return

    sendSoldierActionToBQ("move_to_squad", reserveSoldier, soldiersSquadGuid.value)
    squadSoldiers.mutate(@(list) list[idxTo] = reserveSoldier)
    reserveSoldiers.mutate(function(list) {
      if (prevSoldier != null)
        list[idxFrom] = prevSoldier
      else
        list.remove(idxFrom)
    })
    if (reserveSoldier.equipSchemeId == prevSoldier?.equipSchemeId)
      msgbox.show({
        text = loc("swapSoldiersEquipmentConfirm")
        buttons = [
          { text = loc("Yes"), action = function() {
            swap_soldiers_equipment(reserveSoldier.guid, prevSoldier.guid)
          }}
          { text = loc("No"), isCancel = true}
        ]
      })
    return
  }

  local { msgText, reqResearch } = cantChangeReason
  let buttons = [{ text = loc("Ok"), isCurrent = true }]
  if (reqResearch != null) {
    buttons.append({
      text = loc("GoToResearch")
      action = @() focusResearch(reqResearch)
    })
    msgText = "{0}\n\n{1}".subst(msgText, loc("msg/needResearchToAddClassToSquad"))
  }

  sendSoldierActionToBQ("failed_management", reserveSoldier, soldiersSquadGuid.value)
  msgbox.show({
    text = msgText
    buttons
  })
}

function moveCurSoldier(direction) {
  let guid = selectedSoldierGuid.value
  if (guid == null)
    return
  foreach (watch in [squadSoldiers, reserveSoldiers]) {
    let list = watch.value
    let idx = list.findindex(@(s) s?.guid == guid)
    if (idx == null)
      continue
    let newIdx = idx + direction
    if (newIdx in list)
      watch(moveIndex(list, idx, newIdx))
    break
  }
}

function soldierToReserveByIdx(idx) {
  if (isChangesBlocked.value) {
    showBlockedChangesMessage()
    return
  }
  if (idx == null)
    return

  if (!isTransferAvailable(squadSoldiers.value[idx]))
    return

  sendSoldierActionToBQ("move_to_reserve", squadSoldiers.value[idx])
  reserveSoldiers.mutate(@(v) v.insert(0, squadSoldiers.value[idx]))
  squadSoldiers.mutate(@(v) v[idx] = null)
}

function curSoldierToReserve() {
  let guid = selectedSoldierGuid.value
  if (guid == null)
    return

  let idx = squadSoldiers.value.findindex(@(s) s?.guid == guid)
  soldierToReserveByIdx(idx)
}

function soldierToSquadByIdx(idx) {
  if (isChangesBlocked.value) {
    showBlockedChangesMessage()
    return
  }
  if (idx == null)
    return

  let newIdx = squadSoldiers.value.findindex(@(s) s == null)
  if (newIdx == null) {
    msgbox.show({ text = loc("msg/squadSoldiersFull") })
    return
  }

  let cantChangeReason = getCantTakeReason(reserveSoldiers.value[idx],
    squadSoldiers.value, newIdx)
  if (cantChangeReason == null) {
    squadSoldiers.mutate(@(v) v[newIdx] = reserveSoldiers.value[idx])
    reserveSoldiers.mutate(@(v) v.remove(idx))
    return
  }

  local { msgText, reqResearch } = cantChangeReason
  let buttons = [{ text = loc("Ok"), isCurrent = true }]
  if (reqResearch != null) {
    buttons.append({
      text = loc("GoToResearch")
      action = @() focusResearch(reqResearch)
    })
    msgText = "{0}\n\n{1}".subst(msgText, loc("msg/needResearchToAddClassToSquad"))
  }

  msgbox.show({
    uid = "change_soldiers_order"
    text = msgText
    buttons
  })
}

function curSoldierToSquad() {
  if (isChangesBlocked.value) {
    showBlockedChangesMessage()
    return
  }
  let guid = selectedSoldierGuid.value
  if (guid == null)
    return

  let idx = reserveSoldiers.value.findindex(@(s) s.guid == guid)
  soldierToSquadByIdx(idx)
}

let close = function() {
  selectedSoldierGuid(null)
  soldiersSquadGuid(null)
  isPurchaseWndOpend(false)
  markSoldierSeen(curArmy.value, unseenSoldiers.value.keys())
}

function applySoldierManageImpl(cb) {
  let minCount = soldiersSquad.value?.size ?? 1
  squadSoldiers(squadSoldiers.value.filter(@(s) s != null))
  for(local i = squadSoldiers.value.len() - 1; i >= 0; i--) {
    let soldier = squadSoldiers.value[i]
    let { isTransferLocked = false } = sClassesCfg.value?[soldier.sClass]
    if (soldiersStatuses.value?[soldier.guid] == READY || isTransferLocked)
      continue
    squadSoldiers.mutate(@(v) v.remove(i))
    reserveSoldiers.mutate(@(v) v.insert(0, soldier))
  }
  for(local i = squadSoldiers.value.len(); i < minCount; i++) {
    let idx = reserveSoldiers.value.findindex(@(s) soldiersStatuses.value?[s.guid] == READY)
    if (idx == null)
      break
    let soldier = reserveSoldiers.value[idx]
    let { isTransferLocked = false } = sClassesCfg.value?[soldier.sClass]
    if (isTransferLocked)
      continue
    reserveSoldiers.mutate(@(v) v.remove(idx))
    squadSoldiers.mutate(@(v) v.append(soldier))
  }

  let newSquadSoldiers = squadSoldiers.value
  let selectedGuid = selectedSoldierGuid.value
  let inSquadIdx = newSquadSoldiers.findindex(@(s) s.guid == selectedGuid)
  if (inSquadIdx != null)
    curSquadSoldierIdx(inSquadIdx)
  else if ((curSquadSoldierIdx.value ?? 0) >= newSquadSoldiers.len())
    curSquadSoldierIdx(null)

  if (curSquadSoldiers.value.len() == squadSoldiers.value.len()) {
    local hasChanges = false
    foreach (idx, soldier in curSquadSoldiers.value)
      if (soldier.guid != squadSoldiers.value[idx].guid) {
        hasChanges = true
        break
      }
    if (!hasChanges) {
      cb()
      return
    }
  }

  log($"manage_squad_soldiers: armyId = {soldiersArmy.value}, squadGuid = {soldiersSquadGuid.value}")
  log($"To squad ({squadSoldiers.value.len()}) = ", squadSoldiers.value.map(@(s) s.guid))
  log($"To reserve ({reserveSoldiers.value.len()}) = ", reserveSoldiers.value.map(@(s) s.guid))
  log("lastRequests: ")
  debugTableData(lastRequests.value, { recursionLevel = 7 })
  let squadGuid = soldiersSquadGuid.value // to capture value: when the cb is called, it's null
  manage_squad_soldiers(soldiersArmy.value,
    soldiersSquadGuid.value,
    squadSoldiers.value.map(@(s) s.guid),
    reserveSoldiers.value.map(@(s) s.guid),
    function(res) {
      if (res?.error == null) {
        calcBROnSoldierChange(curCampSquads.value?[squadGuid])
        return
      }
      //usually this error mean that soldiers list of client and server is not the same.
      log($"Request update_profile after fail change soldiers order")
      update_profile()
    })
  cb()
}

function checkSquadStatus() {
  let selCount = squadSoldiers.value.filter(@(s) s != null).len()
  let readyCount = squadSoldiers.value
    .filter(@(s) s != null && soldiersStatuses.value?[s.guid] == READY)
    .len()
  let hasReady = reserveSoldiers.value
    .findvalue(@(s) soldiersStatuses.value?[s.guid] == READY) != null
  let minCount = soldiersSquad.value?.size ?? 1
  return readyCount < minCount && hasReady ? loc("msg/notFullSoldiersAtApply", { minCount })
    : readyCount < selCount ? loc("msg/haveUnreadySoldiers", { count = selCount - readyCount })
    : null
}

function applySoldierManage(cb = @() null) {
  let msg = checkSquadStatus()
  if (msg == null)
    applySoldierManageImpl(cb)
  else
    msgbox.show({
      text = msg
      buttons = [
        { text = loc("Ok"), action = @() applySoldierManageImpl(cb), isCurrent = true }
        { text = loc("Cancel"), isCancel = true, customStyle = { hotkeys = [[$"^{JB.B} | Esc"]] } }
      ]
    })
}

let isDismissInProgress = Watched(false)
function dismissSoldiers(armyId, guidsList) {
  if (isDismissInProgress.value)
    return

  isDismissInProgress(true)
  dismissReserveSoldiers(armyId, guidsList, @(_) isDismissInProgress(false))
}

curSection.subscribe(@(_) soldiersSquad.value == null ? null
  : checkSquadStatus() == null ? applySoldierManageImpl(close)
  : close())

return {
  openChooseSoldiersWnd = function(squadGuid, selSoldierGuid = null) {
    soldiersSquadGuid(squadGuid)
    selectedSoldierGuid(selSoldierGuid)
  }
  closeChooseSoldiersWnd = close
  applySoldierManage
  updateSoldiersListAndSort = updateSoldiersListAndSortDebounced

  soldiersArmy
  soldiersSquad
  maxSoldiersInBattle
  soldiersSquadParams
  squadSoldiers
  reserveSoldiers
  soldiersStatuses
  selectedSoldierGuid
  selectedSoldier

  changeSoldierOrderByIdx
  moveIndex
  moveCurSoldier
  soldierToReserveByIdx
  curSoldierToReserve
  soldierToSquadByIdx
  curSoldierToSquad
  getCanTakeSlots
  dismissSoldiers
  isDismissInProgress
  curSquadSoldierIdx
  isPurchaseWndOpend
}
