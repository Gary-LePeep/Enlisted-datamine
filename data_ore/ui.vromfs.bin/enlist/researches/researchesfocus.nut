from "%enlSqGlob/ui/ui_library.nut" import *

let prepareResearch = require("researchesPresentation.nut")
let { jumpToResearches } = require("%enlist/mainMenu/sectionsState.nut")
let { getLinkedArmyName } = require("%enlSqGlob/ui/metalink.nut")
let {
  configResearches, armiesResearches, allResearchStatus,
  viewSquadId, selectedTable, selectedResearch,
  NOT_ENOUGH_EXP, CAN_RESEARCH, RESEARCHED
} = require("researchesState.nut")
let { armySquadsById } = require("%enlist/soldiers/model/state.nut")
let { squadsCfgById } = require("%enlist/soldiers/model/config/squadsConfig.nut")
let { allItemTemplates } = require("%enlist/soldiers/model/all_items_templates.nut")
let { growthSquadsByArmy } = require("%enlist/growth/growthState.nut")



let researchToShow = Watched(null)

let getClosestResearch = @(army_id, researches, statuses) researches //FIXME: Better not to merge armyId here, and detect it by research
    .map(@(res) res.__merge({ army_id, status = statuses?[res.research_id] }))
    .filter(@(res) res.status != RESEARCHED)
    .reduce(@(res, val) (res.status != CAN_RESEARCH && val.status == CAN_RESEARCH)
        || (res.status != NOT_ENOUGH_EXP && val.status == NOT_ENOUGH_EXP)
        || (res.line >= val.line && res.tier >= val.tier)
      ? val : res)

function focusResearch(research) {
  let { army_id = null, squadIdList = {},
    page_id = 0, research_id = null } = research
  let researchData = armiesResearches.value?[army_id].researches[research_id]
  if (squadIdList.len() == 0 || researchData == null)
    return

  local squadToOpen = squadIdList
    .findindex(@(_, squadId) squadId in armySquadsById.value?[army_id])

  jumpToResearches()
  // do not switch army, because all visible researches are belong to the current army
  viewSquadId(squadToOpen)
  selectedTable(page_id)

  let context = {
    armyId = army_id
    squadId = squadToOpen
    squadsCfg = squadsCfgById.value
    alltemplates = allItemTemplates.value
  }
  let preparedResearch = prepareResearch(clone researchData, context)
  selectedResearch(preparedResearch)
  researchToShow(preparedResearch)
}

function findResearchById(research_id) {
  foreach (army_id, armyConfig in configResearches.value)
    foreach (squad_id, squadList in armyConfig?.pages ?? {}) {
      let resFound = squadList.findvalue(@(res) research_id in (res?.tables ?? {}))
      if (resFound != null)
        return {
          army_id
          squadIdList = [squad_id]
          page_id = resFound?.page_id ?? 0
          research_id
        }
    }
  return null
}

let hasResearchSquad = @(armyId, researchData) researchData.squadIdList
  .findvalue(@(_, squadId) squadId in armySquadsById.value?[armyId]) != null

function findResearchesByFunc(armyId, checkFunc) {
  let researches = []
  let allResearches = armiesResearches.value?[armyId].researches ?? {}
  foreach (researchData in allResearches)
    if (checkFunc(researchData))
      researches.append(researchData)

  return researches
}

function findClosestResearch(armyId, checkFunc) {
  let researches = findResearchesByFunc(armyId, checkFunc)
  return getClosestResearch(armyId, researches, allResearchStatus.value?[armyId] ?? {})
}


function findSlotUnlockRequirement(soldier, slotType) {
  if (soldier == null || slotType == null)
    return null

  let armyId = getLinkedArmyName(soldier)
  let statuses = allResearchStatus.value?[armyId] ?? {}
  let { sClass = "unknown" } = soldier
  let researches = findResearchesByFunc(armyId, @(researchData)
    (researchData?.effect.slot_unlock[sClass] ?? []).contains(slotType))

  let availResearches = researches.filter(@(r) hasResearchSquad(armyId, r))

  if (availResearches.len() > 0)
    return { research = getClosestResearch(armyId, availResearches, statuses) }
  if (researches.len() > 0) {
    let research = researches.top()
    return { squadId = research?.squadIdList.keys().top() }
  }
  return null
}

function findResearchesUpgradeUnlock(armyId, item) {
  if (item == null)
    return null
  let upgradetpl = item?.upgradeitem
  return findResearchesByFunc(armyId, @(researchData)
    (researchData?.effect.weapon_upgrades ?? []).contains(upgradetpl))
}

function findResearchTrainClass(soldier) {
  if (soldier == null)
    return null
  let armyId = getLinkedArmyName(soldier)
  let { sClass = "unknown" } = soldier
  let researches = findResearchesByFunc(armyId, @(r) (r?.effect.class_training[sClass] ?? 0) > 0)
    .filter(@(research) research.squadIdList
      .findvalue(@(_, squadId) squadId in growthSquadsByArmy.value?[armyId]) != null)
  return getClosestResearch(armyId, researches, allResearchStatus.value?[armyId] ?? {})
}

console_register_command(@(researchId)
  focusResearch(findResearchById(researchId)), "meta.focusResearch")

return {
  researchToShow
  focusResearch
  findSlotUnlockRequirement
  findResearchesUpgradeUnlock
  findResearchTrainClass
  findClosestResearch
  getClosestResearch
  hasResearchSquad
}
