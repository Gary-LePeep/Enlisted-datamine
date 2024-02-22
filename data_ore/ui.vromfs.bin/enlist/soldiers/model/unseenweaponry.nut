from "%enlSqGlob/ui/ui_library.nut" import *

let { settings, onlineSettingUpdated } = require("%enlist/options/onlineSettings.nut")
let { curArmiesList, itemsByArmies, campItemsByLink } = require("%enlist/meta/profile.nut")
let { chosenSquadsByArmy, armoryByArmy, soldiersBySquad, canChangeEquipmentInSlot } = require("state.nut")
let { equipSchemesByArmy } = require("all_items_templates.nut")
let { classSlotLocksByArmy } = require("%enlist/researches/researchesSummary.nut")
let { debounce } = require("%sqstd/timers.nut")
let { trimUpgradeSuffix } = require("%enlSqGlob/ui/itemsInfo.nut")

const SEEN_ID = "seen/weaponry"
let SLOTS = ["primary", "side", "secondary", "melee",
  "backpack", "grenade", "mine", "flask_usable", "binoculars_usable",
  "antitank", "flamethrower", "mortar"]
let SLOTS_MAP = SLOTS.reduce(@(res, slotName) res.rawset(slotName, true), {})

let seen = Computed(@() settings.value?[SEEN_ID]) //<armyId> = { <basetpl> = true }

let unseenArmiesWeaponry = Watched({})
let unseenSquadsWeaponry = Watched({})
let unseenSoldiersWeaponry = Watched({})

let notEquippedTiers = Computed(function() {
  let res = {}
  foreach (armyId in curArmiesList.value) {
    let itemsList = armoryByArmy.value?[armyId] ?? []
    let byTpl = {} //<basetpl> = <tier>
    let byItemType = {} //<itemtype> = { <basetpl> = <tier> }
    foreach (item in itemsList) {
      if (item.basetpl in byTpl)
        continue
      let { basetpl, itemtype = "", tier = 0 } = item
      byTpl[basetpl] <- tier
      if (itemtype not in byItemType)
        byItemType[itemtype] <- {}
      byItemType[itemtype][basetpl] <- tier
    }
    res[armyId] <- { byTpl, byItemType }
  }
  return res
})

let unseenTiers = Computed(@() !onlineSettingUpdated.value ? {}
  : notEquippedTiers.value.map(function(tiers, armyId) {
    local { byTpl, byItemType } = tiers
    let armySeen = seen.value?[armyId]
    byTpl = byTpl.filter(@(_, basetpl) basetpl not in armySeen)
    byItemType = byItemType
      .map(@(tplList)
        tplList.filter(@(_, basetpl) basetpl not in armySeen)
          .reduce(@(res, tier) max(res, tier), -1))
    return { byTpl, byItemType }
  }))

let unseenEquipSlotsTiers = Computed(@()
  unseenTiers.value.map(function(tiers, armyId) {
    let res = {} //<schemeId> = { <slotId> = <maxUnseenTier> }
    let { byTpl, byItemType } = tiers
    if (byTpl.len() == 0)
      return res

    foreach (schemeId, scheme in equipSchemesByArmy.value?[armyId] ?? {}) {
      let unseenSlots = {}
      foreach (slotId in SLOTS) {
        if (slotId not in scheme)
          continue
        let { itemTypes = [], items = [] } = scheme[slotId]
        local maxTier = -1
        foreach (iType in itemTypes)
          maxTier = max(maxTier, byItemType?[iType] ?? -1)
        foreach (tpl in items)
          maxTier = max(maxTier, byTpl?[tpl] ?? -1)
        if (maxTier >= 0)
          unseenSlots[slotId] <- maxTier
      }
      if (unseenSlots.len() > 0)
        res[schemeId] <- unseenSlots
    }
    return res
  }))

let slotsLinkTiers = Computed(function() {
  let res = {}
  let itemsList = itemsByArmies.value
  foreach (armyId in curArmiesList.value) {
    res[armyId] <- {}
    foreach (item in itemsList?[armyId] ?? {}) {
      if ("tier" not in item)
        continue
      foreach (linkTo, linkSlot in item.links)
        if (linkSlot in SLOTS_MAP) {
          if (linkTo not in res[armyId])
            res[armyId][linkTo] <- {}
          let slotsTiers = res[armyId][linkTo]
          slotsTiers[linkSlot] <- linkSlot in slotsTiers ? min(slotsTiers[linkSlot], item.tier) : item.tier
        }
    }
  }
  return res
})

let unseenUpgradesByWeapon = Computed(function() {
  let res = {}
  foreach (armyId, data in unseenTiers.value) {
    res[armyId] <- {}
    foreach (weaponTpl, _unseenTier in data.byTpl) {
      let basicTpl = trimUpgradeSuffix(weaponTpl)
      if (basicTpl not in res[armyId])
        res[armyId][basicTpl] <- {}
      res[armyId][basicTpl][weaponTpl] <- true
    }
  }
  return res
})

function getSoldierFixedWeapon(soldierGuid) {
  let weapon = {}
  foreach (slotType, itemsList in campItemsByLink.value?[soldierGuid] ?? {}) {
    if (itemsList?[0].isFixed)
      weapon[slotType] <- true
  }
  return weapon
}

function recalcUnseen() {
  let unseenArmies = {}
  let unseenSquads = {}
  let unseenSoldiers = {}

  foreach (armyId, schemes in unseenEquipSlotsTiers.value) {
    unseenArmies[armyId] <- 0
    let armyLinkTiers = slotsLinkTiers.value?[armyId]
    let classLocks = classSlotLocksByArmy.value?[armyId]
    foreach (squad in chosenSquadsByArmy.value?[armyId] ?? []) {
      local unseenSoldiersCount = 0
      foreach (soldier in soldiersBySquad.value?[squad.guid] ?? []) {
        let unseenSlots = schemes?[soldier?.equipSchemeId]
        if (unseenSlots == null)
          continue

        let fixedWeapon = getSoldierFixedWeapon(soldier.guid)
        let hasFixedWeapon = fixedWeapon.len() > 0
        let unseenSoldier = {}
        foreach (slotId, tier in unseenSlots) {
          if (hasFixedWeapon && (slotId in fixedWeapon))
            continue

          if (tier > (armyLinkTiers?[soldier.guid][slotId] ?? -1)
              && !(classLocks?[soldier?.sClass] ?? []).contains(slotId)
              && canChangeEquipmentInSlot(soldier?.sClass, slotId))
            unseenSoldier[slotId] <- true
        }
        if (unseenSoldier.len() == 0)
          continue

        unseenSoldiersCount++
        unseenArmies[armyId]++
        unseenSoldiers[soldier.guid] <- unseenSoldier
      }
      unseenSquads[squad.guid] <- unseenSoldiersCount
    }
  }

  unseenArmiesWeaponry(unseenArmies)
  unseenSquadsWeaponry(unseenSquads)
  unseenSoldiersWeaponry(unseenSoldiers)
}
recalcUnseen()
let recalcUnseenDebounced = debounce(recalcUnseen, 0.01)
unseenEquipSlotsTiers.subscribe(@(_) recalcUnseenDebounced())
chosenSquadsByArmy.subscribe(@(_) recalcUnseenDebounced())
soldiersBySquad.subscribe(@(_) recalcUnseenDebounced())
slotsLinkTiers.subscribe(@(_) recalcUnseenDebounced())
classSlotLocksByArmy.subscribe(@(_) recalcUnseenDebounced())

function markWeaponrySeen(armyId, basetpl) {
  if (!onlineSettingUpdated.value || (seen.value?[armyId][basetpl] ?? false))
    return

  settings.mutate(function(set) {
    let saved = clone (set?[SEEN_ID] ?? {})
    let armySaved = clone (saved?[armyId] ?? {})
    armySaved[basetpl] <- true
    saved[armyId] <- armySaved
    set[SEEN_ID] <- saved
  })
}

function markWeaponryListSeen(armyId, basetpls) {
  if (!onlineSettingUpdated.value)
    return

  let armySaved = clone settings.value?[SEEN_ID][armyId] ?? {}
  let lastCount = armySaved.len()
  basetpls.each(@(tpl) armySaved[tpl] <- true)
  if (lastCount == armySaved.len())
    return

  settings.mutate(function(set) {
    let saved = clone (set?[SEEN_ID] ?? {})
    saved[armyId] <- armySaved
    set[SEEN_ID] <- saved
  })
}

function markNotFreeWeaponryUnseen() {
  let seenData = seen.value ?? {}
  if (seenData.len() == 0)
    return false

  local hasChanges = false
  let newSeen = clone seenData
  foreach (armyId, tiers in notEquippedTiers.value) {
    if (armyId not in newSeen)
      continue

    let { byTpl } = tiers
    let armySeen = newSeen[armyId].filter(@(_, tpl) tpl in byTpl)
    if (armySeen.len() < newSeen[armyId].len()) {
      newSeen[armyId] = armySeen
      hasChanges = true
    }
  }

  if (hasChanges)
    settings.mutate(@(set) set[SEEN_ID] <- newSeen)
  return hasChanges
}

local needIgnoreSelfUpdateUnseen = false
unseenSoldiersWeaponry.subscribe(function(_) {
  if (!onlineSettingUpdated.value || itemsByArmies.value.len() == 0)
    return
  if (needIgnoreSelfUpdateUnseen)
    needIgnoreSelfUpdateUnseen = false
  else
    needIgnoreSelfUpdateUnseen = markNotFreeWeaponryUnseen()
})

return {
  unseenTiers
  unseenArmiesWeaponry
  unseenSquadsWeaponry
  unseenSoldiersWeaponry
  unseenUpgradesByWeapon

  markWeaponrySeen
  markWeaponryListSeen
  markNotFreeWeaponryUnseen
}
