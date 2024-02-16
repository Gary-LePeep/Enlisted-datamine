from "%enlSqGlob/ui_library.nut" import *

let { logerr } = require("dagor.debug")
let { round_by_value } = require("%sqstd/math.nut")
let { do_research, change_research, buy_change_research, buy_squad_exp, add_army_squad_exp_by_id
} = require("%enlist/meta/clientApi.nut")
let profile = require("%enlist/meta/profile.nut")
let { researchProgress, squadProgress } = profile
let { configs } = require("%enlist/meta/configs.nut")
let { toIntegerSafe } = require("%sqstd/string.nut")
let { curArmiesList, armySquadsById, curSquadId, curArmy, armyItemCountByTpl,
  curCampItems
} = require("%enlist/soldiers/model/state.nut")
let { allItemTemplates } = require("%enlist/soldiers/model/all_items_templates.nut")
let { squadsCfgById } = require("%enlist/soldiers/model/config/squadsConfig.nut")
let squadsPresentation = require("%enlSqGlob/ui/researchSquadsPresentation.nut")
let prepareResearch = require("researchesPresentation.nut")
let recalcMultiResearchPos = require("recalcMultiResearchPos.nut")
let getPayItemsData = require("%enlist/soldiers/model/getPayItemsData.nut")
let { disabledSectionsData } = require("%enlist/mainMenu/disabledSections.nut")
let { isResearchesOpened } = require("%enlist/mainMenu/sectionsState.nut")
let { get_setting_by_blk_path } = require("settings")
let hideLockedResearches = get_setting_by_blk_path("hideLockedResearches") ?? false


const CHANGE_RESEARCH_TPL = "research_change_order"

let hasResearchesSection = Computed(@() !(disabledSectionsData.value?.RESEARCHES ?? false))

let isBuyLevelInProgress = Watched(false)
let isResearchInProgress = Watched(false)
let viewSquadId = Watched(curSquadId.value)
curSquadId.subscribe(@(squadId) viewSquadId(squadId))
isResearchesOpened.subscribe(@(val) val ? viewSquadId(curSquadId.value) : null)


let changeResearchBalance = Computed(@() armyItemCountByTpl.value?[CHANGE_RESEARCH_TPL] ?? 0)
let changeResearchGoldCost = Computed(@() configs.value?.gameProfile.changeResearchGoldCost ?? 0)

let configResearches = Computed(function() {
  let src = configs.value?.researches ?? {}
  let res = {}
  foreach (armyId, armyConfig in src) {
    let presentList = squadsPresentation?[armyId]
    let armyPages = {}
    res[armyId] <- {
      squads = armyConfig?.squads
      pages = armyPages
    }
    foreach (squadId, pageList in armyConfig?.pages ?? {})
      armyPages[squadId] <- pageList.map(function(page, idx) {
        page = (page ?? {}).__merge(presentList?[idx] ?? {})
        page.tables <- (page?.tables ?? {})
          .filter(@(r) !hideLockedResearches || !(r?.isLocked ?? false))
        return page
      })
  }
  return res
})

let armiesResearches = Computed(function() {
  let res = {}
  foreach (armyId, armyConfig in configResearches.value) {
    let researchesMap = {}
    foreach (squadPages in armyConfig.pages)
      foreach (page in squadPages)
        foreach (research in page.tables)
          researchesMap[research.research_id] <- research

    res[armyId] <- {
      squads = armyConfig.squads
      pages = armyConfig.pages //pages by squadId
      researches = researchesMap
    }
  }
  return res
})

let selectedResearch = Watched(null)
let selectedTable = mkWatched(persist,"selectedTable", 0)

let LOCKED = 1
let DEPENDENT = 2
let NOT_ENOUGH_EXP = 3
let GROUP_RESEARCHED = 4
let CAN_RESEARCH = 5
let RESEARCHED = 6

let squadResearchPages = Computed(function() {
  let armyId = curArmy.value
  let squadId = viewSquadId.value
  let squadTables = armiesResearches.value?[armyId].pages?[squadId]
  if (!squadTables)
    return null

  return squadTables.map(function(config) {
    let pageContext = {
      armyId
      squadId
      squadsCfg = squadsCfgById.value
      alltemplates = allItemTemplates.value
    }
    let researchList = config.tables.values()
      .sort(@(a, b) a.line <=> b.line || a.tier <=> b.tier)
      .map(@(research) prepareResearch(research, pageContext))
      .reduce(function(res, r) {
        res[r.research_id] <- r
        return res
      }, {})
      // TODO
      // The following: values().sort().reduce() come from the old version of this code
      // Removing these calls makes the researches of the same type trade places in the result graph
      // Should be fixed
    recalcMultiResearchPos(researchList)
    return researchList
  })
})

let tableStructure = Computed(function() {
  let armyId = curArmy.value
  let squadId = viewSquadId.value
  let curResearches = armiesResearches.value?[armyId]
  let ret = {
    armyId = armyId
    squadId = squadId
    tiersTotal = 0
    minTier = 0
    rowsTotal = 0
    researches = {}
    pages = []
  }

  if (!curResearches)
    return ret

  let pages = curResearches.pages?[squadId]
  if (pages == null)
    return ret

  ret.pages = pages
  ret.researches = squadResearchPages.value?[selectedTable.value] ?? {}

  local minTier = -1
  local maxTier = -1
  local rowsTotal = 0
  foreach (def in ret.researches) {
    let tier = round_by_value(def.tier, 1)
    minTier = minTier < 0 ? tier : min(tier, minTier)
    maxTier = max(tier, maxTier)
    rowsTotal = max(def.line, rowsTotal)
  }
  ret.__update({ minTier, tiersTotal = maxTier - minTier + 1, rowsTotal })
  return ret
})

let isOpenResearch = @(research, researched)
  (research?.requirements ?? []).findindex(@(id) !researched?[id]) == null

let isResearched = @(research, researched) research.research_id in researched

let function calcResearchedGroups(researches, researched) {
  let res = {}
  foreach (rId, val in researched) {
    if (!val)
      continue
    let { squadIdList = {}, squad_id = "", page_id = 0, multiresearchGroup = 0 } = researches?[rId]
    if (multiresearchGroup <= 0)
      continue

    if (squadIdList.len() == 0 && squad_id != "")
      squadIdList[squad_id] <- true

    foreach (squadId, _ in squadIdList) {
      if (squadId not in res)
        res[squadId] <- {}
      if (page_id not in res[squadId])
        res[squadId][page_id] <- {}
      res[squadId][page_id][multiresearchGroup] <- true
    }
  }
  return res
}

let isSquadLocked = function(squads, research) {
  foreach (squadId, _ in research?.squadIdList ?? {}) {
    if (squadId in squads)
      return false
  }
  if ((research?.squad_id ?? "") in squads)
    return false
  return true
}

let function researchStatusArmy
    (armyResearches, researched, progress, squads, selectedSquadId = null) {
  let groups = calcResearchedGroups(armyResearches, researched)
  return armyResearches.map(function(research) {
    let squad_id = research?.squad_id ??
      (selectedSquadId in research.squadIdList
        ? selectedSquadId
        : research.squadIdList.keys().top())
    return isResearched(research, researched) ? RESEARCHED
      : (research?.isLocked ?? false) ? LOCKED
      : (research?.multiresearchGroup ?? 0) > 0
          && (groups?[squad_id][research?.page_id ?? 0][research.multiresearchGroup] ?? false)
        ? GROUP_RESEARCHED
      : isSquadLocked(squads, research) || !isOpenResearch(research, researched) ? DEPENDENT
      : (research?.price ?? 0) <= (progress?[squad_id].points ?? 0) ? CAN_RESEARCH
      : NOT_ENOUGH_EXP
  })
}

let allResearchStatus = Computed(function() {
  let res = {}
  let allArmiesResearches = armiesResearches.value
  let progress = squadProgress.value
  foreach (armyId in curArmiesList.value) {
    let armyResearches = allArmiesResearches?[armyId].researches ?? {}
    let researched = researchProgress.value
    let squads = armySquadsById.value?[armyId] ?? {}
    res[armyId] <- researchStatusArmy(armyResearches, researched, progress, squads)
  }
  return res
})

let researchStatuses = Computed(function() {
  // as in allResearchStatus with selectedSquadId specified
  let armyId = curArmy.value
  let armyResearches = armiesResearches.value?[armyId].researches ?? {}
  let researched = researchProgress.value
  let squads = armySquadsById.value?[armyId] ?? {}
  return researchStatusArmy(armyResearches, researched, squadProgress.value,
    squads, viewSquadId.value)
})

let allSquadsPoints = Computed(@() squadProgress.value.map(@(p) p.points))
let allSquadsLevels = Computed(@() squadProgress.value.map(@(p) p.level))

let curSquadProgress = Computed(function() {
  let squadCfg = armiesResearches.value?[curArmy.value].squads[viewSquadId.value]
  let { levels  = [] } = squadCfg
  let res = {
    level = 0
    exp = 0
    points = 0
    nextLevelExp = 0
    levelCost = 0
    maxLevel = levels.len()
  }.__update(squadProgress.value?[viewSquadId.value] ?? {})

  let levelExp = levels?[res.level].exp ?? 0
  let levelCost = levels?[res.level].levelCost ?? 0
  let needExp = levelExp - res.exp

  res.nextLevelExp = levelExp
  if (levelExp > 0 && needExp > 0 && levelCost > 0)
    res.levelCost = max(levelCost * needExp / levelExp, 1)

  return res
})

let function addArmySquadExp(armyId, exp, squadId) {
  if (armyId not in armySquadsById.value) {
    logerr($"Unable to charge exp for army {armyId}")
    return
  }

  add_army_squad_exp_by_id(armyId, exp, squadId)
}

let function researchAction(researchId) {
  if (isResearchInProgress.value || researchStatuses.value?[researchId] != CAN_RESEARCH)
    return
  isResearchInProgress(true)
  do_research(tableStructure.value.armyId, researchId, @(_) isResearchInProgress(false))
}

let function changeResearch(researchFrom, researchTo) {
  if (isResearchInProgress.value
      || researchStatuses.value?[researchTo] != GROUP_RESEARCHED
      || researchStatuses.value?[researchFrom] != RESEARCHED)
    return
  let payData = getPayItemsData({ [CHANGE_RESEARCH_TPL] = 1 }, curCampItems.value)
  if (payData == null)
    return
  isResearchInProgress(true)
  change_research(tableStructure.value.armyId, researchFrom, researchTo, payData,
    @(_) isResearchInProgress(false))
}

let function buyChangeResearch(researchFrom, researchTo) {
  if (isResearchInProgress.value
      || researchStatuses.value?[researchTo] != GROUP_RESEARCHED
      || researchStatuses.value?[researchFrom] != RESEARCHED)
    isResearchInProgress(true)
  buy_change_research(tableStructure.value.armyId, researchFrom, researchTo, changeResearchGoldCost.value,
    @(_) isResearchInProgress(false))
}

let closestTargets = Computed(function() {
  let list = squadResearchPages.value
  if (!list)
    return null

  return list.map(function(researches) {
    local pageTop = null
    foreach (r in researches) {
      let status = researchStatuses.value?[r.research_id]
      if (status != CAN_RESEARCH && status != NOT_ENOUGH_EXP)
        continue

      let { line, tier } = r
      if (pageTop == null || line < pageTop.line || (line == pageTop.line && tier < pageTop.tier))
        pageTop = r
    }
    return pageTop
  })
})

let function buySquadLevel(cb = null) {
  if (isBuyLevelInProgress.value)
    return

  let { nextLevelExp = 0, exp = 0, levelCost = 0 } = curSquadProgress.value
  let needExp = nextLevelExp - exp
  if (needExp <= 0 || levelCost <= 0)
    return

  isBuyLevelInProgress(true)
  buy_squad_exp(curArmy.value, viewSquadId.value, needExp, levelCost,
    function(res) {
      isBuyLevelInProgress(false)
      cb?(res?.error == null)
    })
}

let function findAndSelectClosestTarget(...) {
  let tableResearches = tableStructure.value.researches
    .values()
    .sort(@(a, b) a.line <=> b.line || a.tier <=> b.tier)
  local isLockedByCampaignLvl = false
  foreach (val in tableResearches) {
    let status = researchStatuses.value?[val.research_id]
    if (status == CAN_RESEARCH || status == NOT_ENOUGH_EXP) {
      selectedResearch(val)
      return
    }
  }
  selectedResearch({
    isLockedByCampaignLvl
    research_id = ""
    name = "researches/allResearchesResearchedName"
    description = "researches/allResearchesResearchedDescription"
  })
}


let mkCurRequirements = @() Computed(function() {
  let res = {}
  foreach (research in tableStructure.value.researches) {
    let { research_id, requirements = [] } = research
    if (requirements.len() > 0)
      foreach (requirementId in requirements)
        res[requirementId] <- (res?[requirementId] ?? []).append(research_id)
  }
  return res
})

let mkCurResearchChains = @(curRequirements) Computed(function() {
  let allRequirements = curRequirements.value
  let res = {}
  foreach (research in tableStructure.value.researches) {
    let { research_id } = research
    local nextRes = research_id
    res[research_id] <- []
    while (nextRes != null) {
      res[research_id].append(nextRes)
      nextRes = allRequirements?[nextRes]?[0]
    }
  }
  return res
})

let function isNamesSimilar(nameA, nameB) {
  let nameArrA = nameA.split("_")
  let nameArrB = nameB.split("_")
  if (nameArrA.len() != nameArrB.len() || nameArrA.len() < 2)
    return false
  if (toIntegerSafe(nameArrA.top(), -1, false) < 0 || toIntegerSafe(nameArrB.top(), -1, false) < 0)
    return false
  nameArrA.resize(nameArrA.len() - 1)
  nameArrB.resize(nameArrB.len() - 1)
  return "_".join(nameArrA) == "_".join(nameArrB)
}

let validateMainResearch = @(curRes, mainRes, chainLen)
  curRes == null ? null
    : chainLen > 1 || (chainLen == 1 && isNamesSimilar(curRes, mainRes)) ? curRes
    : null

let function mkViewStructure() {
  let curRequirements = mkCurRequirements()
  let curResearchChaines = mkCurResearchChains(curRequirements)
  return Computed(function() {
    let { researches } = tableStructure.value
    let allRequirements = curRequirements.value
    let allChaines = curResearchChaines.value

    local columns = []
    local hasTemplatesLine = false
    let templateCount = {}
    local order=0
    // iterate through all of the starting nodes
    foreach (baseResId, baseRes in researches) {
      if ((baseRes?.requirements.len() ?? 0) > 0)
        continue
      local mainRes = baseResId
      // iterate through all nodes connected to the starting one
      while (mainRes != null) {
        let research = researches[mainRes]
        let followResearches = allRequirements?[mainRes] ?? []
        let { gametemplate = null, requirements = [] } = research
        if (requirements.len() == 0)
          order += 100
        columns.append({
          main = mainRes
          order = order++
          children = []
          template = gametemplate
          tplCount = 0
          toChildren = 0
        })
        if (gametemplate != null) {
          hasTemplatesLine = true
          templateCount[gametemplate] <- (templateCount?[gametemplate] ?? 0) + 1
        }
        let hasMultResearches = followResearches.findvalue(@(resId)
          (researches?[resId].multiresearchGroup ?? 0) > 0) != null
        mainRes = followResearches.len() > 1
          ? followResearches.findvalue(function(resId) {
              // return true if there is a connected research that requires a new column
              if ((researches?[resId].multiresearchGroup ?? 0) > 0)
                return false
              if ((allRequirements?[resId].len() ?? 0) > 1)
                return true
              let currChain = allChaines?[resId] ?? []
              return currChain.len() > 2
                || (currChain.len() == 2 && (isNamesSimilar(mainRes, resId) || hasMultResearches))
            })
          : validateMainResearch(followResearches?[0], mainRes,
              allChaines?[followResearches?[0]].len() ?? 0)
      }
    }

    columns.sort(@(a,b) a.order <=> b.order )

    foreach (idx, column in columns) {
      let { main } = column
      let nextMain = columns?[idx + 1].main
      foreach (resId in allRequirements?[main] ?? []) {
        if (resId == nextMain)
          continue
        let { multiresearchGroup = 0 } = researches[resId]
        if (multiresearchGroup == 0)
          column.children.append({
            multiresearchGroup
            children = allChaines?[resId] ?? []
          })
        else {
          let cIdx = column.children
            .findindex(@(r) (r?.multiresearchGroup ?? 0) == multiresearchGroup)
          if (cIdx == null)
            column.children.append({ multiresearchGroup, children = [resId] })
          else
            column.children[cIdx].children.append(resId)
        }
      }
    }
    let maxChildHeight = [0, 0]
    let childCount = []
    foreach (column in columns) {
      let { template } = column
      if (template != "" && template in templateCount) {
        column.tplCount = templateCount[template]
        delete templateCount[template]
      }
      if ("children" not in column) {
        childCount.append(0, 0)
        continue
      }
      let prevCountTop = childCount?[childCount.len() - 2] ?? 0
      let prevCountBtm = childCount?[childCount.len() - 1] ?? 0
      let childTop = column?.children[0]
      let childBtm = column?.children[1]
      let countTop = (childTop?.multiresearchGroup ?? 0) == 0
        ? min((childTop?.children ?? []).len(), 1)
        : childTop.children.len()
      let countBtm = (childBtm?.multiresearchGroup ?? 0) == 0
        ? min((childBtm ?? []).len(), 1)
        : childBtm.children.len()
      let heightTop = max(maxChildHeight[0],
        (childTop?.multiresearchGroup ?? 0) == 0 ? (childTop?.children ?? []).len() : 1)
      let heightBtm = max(maxChildHeight[1],
        (childBtm?.multiresearchGroup ?? 0) == 0 ? (childBtm?.children ?? []).len() : 1)
      if (prevCountTop + countTop < 5 && prevCountBtm + countBtm < 5) {
        childCount.append(countTop, countBtm)
        maxChildHeight[0] = heightTop
        maxChildHeight[1] = heightBtm
      }
      else {
        column.children.clear()
        column.children.append(childBtm, childTop)
        childCount.append(countBtm, countTop)
        maxChildHeight[0] = heightBtm
        maxChildHeight[1] = heightTop
      }
    }
    local toChildren = 0
    for (local i = columns.len() - 1; i >= 0 ; i--) {
      let column = columns[i]
      if (column.children.findvalue(@(ch) ch != null) != null)
        toChildren = 0
      else
        toChildren++
      column.toChildren = toChildren
    }
    return { columns, maxChildHeight, hasTemplatesLine }
  })
}


researchStatuses.subscribe(findAndSelectClosestTarget)
tableStructure.subscribe(findAndSelectClosestTarget)
findAndSelectClosestTarget()

console_register_command(
  function(exp) {
    if (curArmy.value && viewSquadId.value != null) {
      addArmySquadExp(curArmy.value, exp, viewSquadId.value)
      log_for_user($"Add exp for {curArmy.value} / {viewSquadId.value}")
    } else
      log_for_user("Army or squad is not selected")
  },
  "meta.addCurSquadExp")

return {
  hasResearchesSection
  closestTargets
  configResearches
  armiesResearches
  selectedTable
  tableStructure
  selectedResearch
  viewArmy = curArmy
  viewSquadId

  allResearchStatus
  researchStatuses
  allSquadsLevels
  allSquadsPoints
  squadProgress
  curSquadProgress
  changeResearchBalance
  changeResearchGoldCost

  researchAction
  changeResearch
  buyChangeResearch
  isResearchInProgress
  isBuyLevelInProgress
  addArmySquadExp
  buySquadLevel

  mkViewStructure

  LOCKED
  DEPENDENT
  NOT_ENOUGH_EXP
  GROUP_RESEARCHED
  CAN_RESEARCH
  RESEARCHED

  CHANGE_RESEARCH_TPL
  BALANCE_ATTRACT_TRIGGER = "army_balance_attract"
}
