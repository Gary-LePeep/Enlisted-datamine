from "%enlSqGlob/ui_library.nut" import *

let {
  settings, onlineSettingUpdated
} = require("%enlist/options/onlineSettings.nut")
let { soldiersByArmies } = require("%enlist/meta/profile.nut")
let { curArmy } = require("state.nut")

const SEEN_ID = "seenData/soldiers"

let seenData = Computed(@() settings.value?[SEEN_ID])

let unseen = Computed(@() onlineSettingUpdated.value
  ? soldiersByArmies.value.map(function(list, armyId) {
      let seenSoldiers = seenData.value?[armyId] ?? {}
      return list.reduce(function(res, soldier) {
        let guid = soldier.guid
        if (!(guid in seenSoldiers))
          res[guid] <- true
        return res
      }, {})
    })
  : {})

let unseenCurrent = Computed(@() unseen.value?[curArmy.value] ?? {})

let function changeStatus(armyId, soldierGuids, needDelete = false) {
  let update = {}
  let data = seenData.value?[armyId]
  foreach (guid in typeof soldierGuids == "array" ? soldierGuids : [soldierGuids]) {
    if ((guid not in data && !needDelete) || (guid in data && needDelete))
      update[guid] <- true
  }
  if (update.len() == 0)
    return

  settings.mutate(function(set) {
    let saved = clone set?[SEEN_ID] ?? {}
    let armySaved = clone saved?[armyId] ?? {}
    if (needDelete)
      update.each(@(_, key) delete armySaved[key])
    else
      armySaved.__update(update)
    saved[armyId] <- armySaved
    set[SEEN_ID] <- saved
  })
}

let markSoldiersSeen = @(armyId, soldierGuids) changeStatus(armyId, soldierGuids)
let markSoldiersUnseen = @(armyId, soldierGuids) changeStatus(armyId, soldierGuids, true)

console_register_command(function() {
  settings.mutate(function(s) {
    if (SEEN_ID in s)
      delete s[SEEN_ID]
  })
}, "meta.resetSeenSoldiers")

return {
  unseenSoldiers = unseenCurrent
  markSoldierSeen = markSoldiersSeen
  markSoldierUnseen = markSoldiersUnseen
}
