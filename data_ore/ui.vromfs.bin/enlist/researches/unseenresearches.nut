from "%enlSqGlob/ui_library.nut" import *

let {
  hasResearchesSection, allResearchStatus, armiesResearches, viewArmy,
  CAN_RESEARCH, RESEARCHED
} = require("researchesState.nut")
let { isCurCampaignProgressUnlocked } = require("%enlist/meta/curCampaign.nut")
let { curArmyData } = require("%enlist/soldiers/model/state.nut")
let { settings } = require("%enlist/options/onlineSettings.nut")


const SEEN_ID = "seen/researches"
let seenSettings = Computed(@() settings.value?[SEEN_ID] ?? {})

enum SeenMarks {
  NOT_SEEN = 0
  OPENED = 1
  SEEN = 2
}

let getSeenStatus = @(val) val == true || val == SeenMarks.SEEN ? SeenMarks.SEEN
  : val == SeenMarks.OPENED ? SeenMarks.OPENED
  : SeenMarks.NOT_SEEN

let seenResearches = Computed(function() {
  let seen = {}
  let opened = {}
  foreach(armyId, armySeen in seenSettings.value)
    foreach(key, seenData in armySeen) {
      if (getSeenStatus(seenData) != SeenMarks.NOT_SEEN) {
        if (armyId not in opened)
          opened[armyId] <- {}
        opened[armyId][key] <- true
      }
      if (getSeenStatus(seenData) == SeenMarks.SEEN) {
        if (armyId not in seen)
          seen[armyId] <- {}
        seen[armyId][key] <- true
      }
    }
  let unseen = {}
  let unopened = {}
  foreach (armyId, armyResearches in allResearchStatus.value){
    foreach (id, status in armyResearches) {
      if (status != CAN_RESEARCH)
        continue
      if (!(seen?[armyId][id] ?? false))
        unseen[id] <- status
      if (!(opened?[armyId][id] ?? false))
        unopened[id] <- status
    }
  }

  return { seen, opened, unseen, unopened }
})

let function markSeen(armyId, researchesList, isOpened = false) {
  let filtered = researchesList.filter(@(id) id in seenResearches.value?.unseen[armyId])
  if (filtered.len() == 0)
    return

  let mark = isOpened ? SeenMarks.OPENED : SeenMarks.SEEN
  let saved = seenSettings.value
  let armySaved = saved?[armyId] ?? {}
  //clear all researched from seen in profile
  let armyNewData = armySaved.filter(@(_, id)
    (allResearchStatus.value?[armyId][id] ?? RESEARCHED) != RESEARCHED)
  foreach (id in filtered)
    armyNewData[id] <- mark
  settings.mutate(function(s) {
    let newSaved = clone saved
    newSaved[armyId] <- armyNewData
    s[SEEN_ID] <- newSaved
  })
}

let function resetSeen() {
  let reseted = seenSettings.value.len()
  if (reseted > 0)
    settings.mutate(@(s) delete s[SEEN_ID])
  return reseted
}


let curUnseenResearches = Computed(function() {
  if (!hasResearchesSection.value || !isCurCampaignProgressUnlocked.value)
    return null

  let armyId = curArmyData.value?.guid
  if (armyId == null)
    return null

  return {
    hasUnseen = (seenResearches.value?.unseen[armyId].len() ?? 0) > 0
    hasUnopened = (seenResearches.value?.unopened[armyId].len() ?? 0) > 0
  }
})


let mkCurUnseenResearchesBySquads = @() Computed(function() {
  let unseen = seenResearches.value?.unseen[viewArmy.value]
  let res = {}
  foreach(r in armiesResearches.value?[viewArmy.value].researches ?? {})
    if (r.research_id in unseen) {
      let { squad_id = "" } = r
      if (squad_id != "") {
        res[squad_id] <- true
      } else {
        foreach (squadId in r.squadIdList)
          res[squadId] <- true
      }
    }


  return res
})


console_register_command(@() console_print("Reseted armies count = {0}".subst(resetSeen())), "meta.resetSeenResearches")

return {
  markSeen
  seenResearches
  curUnseenResearches
  mkCurUnseenResearchesBySquads
}
