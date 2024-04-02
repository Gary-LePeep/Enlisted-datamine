from "%enlSqGlob/ui/ui_library.nut" import *

let { slotsIncrease } = require("%enlist/meta/profile.nut")

function countSlots(equipScheme, slotsIncreaseTbl) {
  let baseSlots = equipScheme.map(@(s) s?.listSize ?? 0).filter(@(s) s > 0)
  return baseSlots.map(@(val, slotType) val + (slotsIncreaseTbl?[slotType] ?? 0))
}

let soldierSlotsCount = @(soldierGuid, equipScheme, slotsIncreaseTbl = null)
  countSlots(equipScheme, slotsIncreaseTbl ?? slotsIncrease.value?[soldierGuid])

let mkSoldierSlotsComp = @(soldierGuid, equipScheme, slotsIncreaseTbl = null)
  Computed(@() countSlots(equipScheme, slotsIncreaseTbl ?? slotsIncrease.value?[soldierGuid]))

return {
  soldierSlotsCount
  mkSoldierSlotsComp
}