from "%enlSqGlob/ui/ui_library.nut" import *

let { soldiersByArmies } = require("%enlist/meta/profile.nut")
let { curArmy, curArmiesList, getItemIndex, curArmyLimits } = require("state.nut")
let { getLinkedSquadGuid } = require("%enlSqGlob/ui/metalink.nut")

let allReserveSoldiers = Computed(function() {
  let soldiersList = soldiersByArmies.value
  let res = {}
  foreach (armyId in curArmiesList.value) {
    res[armyId] <- (soldiersList?[armyId] ?? {})
      .filter(@(s) getLinkedSquadGuid(s) == null)
      .values()
      .sort(@(a, b) getItemIndex(a) <=> getItemIndex(b))
  }
  return res
})

let curArmyReserve = Computed(@() allReserveSoldiers.value?[curArmy.value] ?? [])

let curArmyReserveCapacity = Computed(@() curArmyLimits.value.soldiersReserve)

let hasCurArmyReserve = Computed(@() curArmyReserve.value.len() < curArmyReserveCapacity.value)

return {
  allReserveSoldiers
  curArmyReserve
  curArmyReserveCapacity
  hasCurArmyReserve
}
