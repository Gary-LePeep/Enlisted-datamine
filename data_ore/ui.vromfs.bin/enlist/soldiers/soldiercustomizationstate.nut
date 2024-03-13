from "%enlSqGlob/ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { isInBattleState } = require("%enlSqGlob/inBattleState.nut")
let { soldiersLook } = require("%enlist/meta/servProfile.nut")
let { outfitShopTypes, curArmyOutfit, allOutfitByArmy, getCustomizeScheme, getSquadCampainOutfit,
  isObjAvailableForCampaign
} = require("%enlist/soldiers/model/config/outfitConfig.nut")
let { findItemTemplate, allItemTemplates
} = require("%enlist/soldiers/model/all_items_templates.nut")
let { appearanceToRender } = require("%enlist/scene/soldier_tools.nut")
let { curSoldierInfo } = require("%enlist/soldiers/model/curSoldiersState.nut")
let { change_outfit } = require("%enlist/meta/clientApi.nut")
let rand = require("%sqstd/rand.nut")()
let { showMsgbox } = require("%enlist/components/msgbox.nut")
let { armySquadsById } = require("%enlist/soldiers/model/state.nut")
let { isLinkedTo, getFirstLinkByType } = require("%enlSqGlob/ui/metalink.nut")
let { squadsCfgById } = require("%enlist/soldiers/model/config/squadsConfig.nut")
let { logerr } = require("dagor.debug")
let JB = require("%ui/control/gui_buttons.nut")
let { configs } = require("%enlist/meta/configs.nut")
let { debounce } = require("%sqstd/timers.nut")

let isCustomizationWndOpened = Watched(false)
let currentItemPart = mkWatched(persist, "currentItemPart", "")
let curCustomizationItem = mkWatched(persist, "curCustomizationItem", null)
let customizationToApply = mkWatched(persist, "customizationToApply", {})
let customizedSoldierInfo = Computed(@() isInBattleState.value ? null : curSoldierInfo.value)

let resetSoldierRender = debounce(@() appearanceToRender(null), 0.1)

customizationToApply.subscribe(function(v) {
  if (customizedSoldierInfo.value == null || v.len() <= 0) {
    resetSoldierRender()
    return
  }
  appearanceToRender(v)
})

function increment(table, template) {
  table[template] <- 1 + (table?[template] ?? 0)
  return table
}

let freeItemsBySquad = Computed(function() {
  let { armyId = null } = customizedSoldierInfo.value
  if (armyId == null)
    return {}

  let squadItems = {}
  // curArmyOutfit is a subset of allOutfitByArmy.value[armyId]
  // all outfit is checked in case the soldiers have equipped items from the wrong campaings
  // TODO: find out whether it is needed
  let linkedItems = allOutfitByArmy.value?[armyId] ?? []
  // count all items: unequipped
  linkedItems.each(function(outfit) {
    if (outfit.links.len() <= 1)
      increment(squadItems, outfit.basetpl)
  })
  return squadItems
})

let freeItemsForSoldier = Computed(function() {
  let { armyId = null, squadId = null, guid = null } = customizedSoldierInfo.value
  if (armyId == null)
    return {}

  // write result for current soldier: squad items + default items + equipped items
  let result = clone freeItemsBySquad.value
  let campaignOutfit = getSquadCampainOutfit(armyId, squadId, armySquadsById.value)

  let defLook = soldiersLook.value
  let defaultItems = defLook?[guid].items ?? {}
  defaultItems.each(@(val) increment(result, val))

  let linkedItems = allOutfitByArmy.value?[armyId] ?? []
  linkedItems.each(function(outfit) {
    if (isLinkedTo(outfit, guid) && isLinkedTo(outfit, campaignOutfit))
      increment(result, outfit.basetpl)
  })

  return result
})

let itemsToBuy = Computed(@()
  customizationToApply.value
    .filter(@(item) item != "" && item not in (freeItemsForSoldier.value ?? {})))

let selectedItemsPrice = Computed(function() {
  let { armyId = null, squadId = null, guid = null } = customizedSoldierInfo.value
  let res = {}
  if (armyId == null || squadId == null || guid == null)
    return res

  let campaignOutfit = getSquadCampainOutfit(armyId, squadId, armySquadsById.value)
  let itemTypes = configs.value?.outfit_shop ?? {}
  let allItems = getCustomizeScheme(squadsCfgById.value, configs.value,
    armyId, squadId, campaignOutfit)

  allItems.each(@(val) val.each(function(item) {
    let { itemsubtype = null } = findItemTemplate(allItemTemplates, armyId, item)
    let curItemPrice = itemTypes?[itemsubtype]
    let isHidden = (curItemPrice ?? {}).findvalue(@(v) v?.isZeroHidden) != null
    if (curItemPrice != null && !isHidden)
      res[item] <- curItemPrice
  }))

  return res
})

let curSoldierItemsPrice = Computed(function() {
  return selectedItemsPrice.value?.filter(@(_, key) key not in (freeItemsForSoldier.value ?? {}))
})

let premiumItemsCount = Computed(function() {
  let res = {}
  let { armyId = null, squadId = null, guid = null} = customizedSoldierInfo.value
  if (armyId == null || guid == null)
    return res

  let campaignOutfit = getSquadCampainOutfit(armyId, squadId, armySquadsById.value)
  let linkedItems = allOutfitByArmy.value?[armyId] ?? []
  foreach (item in linkedItems)
    if (item.links.len() == 1
      || (isLinkedTo(item, guid) && isObjAvailableForCampaign(item, campaignOutfit)))
        increment(res, item.basetpl)
  return res
})

let lookCustomizationParts = [
  {
    locId = "appearance/helmet"
    slotName = "helmet"
  },
  {
    locId = "appearance/head"
    slotName = "head"
  },
  {
    locId = "appearance/tunic"
    slotName = "tunic"
  },
  {
    locId = "appearance/gloves"
    slotName = "gloves"
  },
  {
    locId = "appearance/pants"
    slotName = "pants"
  }]

let availableCItem = Computed(function() {
  let res = []
  let { armyId = null, squadId = null, guid = null } = customizedSoldierInfo.value
  if (armyId == null || squadId == null || guid == null)
    return res

  let campaignOutfit = getSquadCampainOutfit(armyId, squadId, armySquadsById.value)

  local curSoldierItems = (clone soldiersLook.value?[guid].items) ?? {}
  let premiumToOverride = allOutfitByArmy.value?[armyId] ?? []
  foreach (item in premiumToOverride)
    if (isLinkedTo(item, guid) && isObjAvailableForCampaign(item, campaignOutfit)) {
      let slot = item.links[guid]
      curSoldierItems[slot] <- item.basetpl
    }
  curSoldierItems = curSoldierItems.__merge(customizationToApply.value)

  let itemScheme = getCustomizeScheme(squadsCfgById.value, configs.value, armyId, squadId, campaignOutfit)
  let templates = {}
  let DB = ecs.g_entity_mgr.getTemplateDB()
  foreach (part in lookCustomizationParts) {
    let { slotName } = part
    if (itemScheme?[slotName] == null || itemScheme[slotName].len() == 1)
      continue

    let iconAttachments = []
    let lookItem = curSoldierItems?[slotName]
    let lookItemTemplate = findItemTemplate(allItemTemplates, armyId, lookItem)
    let itemTemplate = lookItemTemplate?.gametemplate ?? ""
    let slotTemplates = lookItemTemplate?.slotTemplates ?? {}
    if (slotTemplates.len() > 0)
      foreach (key, val in slotTemplates) {
        if (val == "")
          continue
        local templ = templates?[val]
        if (templ == null) {
          templ = DB.getTemplateByName(val)
          templates[val] <- templ
        }
        if (templ == null) {
          if (DB.size() != 0)
            logerr($"Not found look template for {val} at {key} slot")
          continue
        }
        iconAttachments.append({
          animchar = templ.getCompValNullable("animchar__res") ?? ""
          slot = key
          active = templ.getCompValNullable("isActivated") ?? ""
        })
      }

    res.append({
      item = lookItem
      itemTemplate
      iconAttachments
    }.__update(part))
  }
  return res
})

let oldSoldiersLook = Computed(function() {
  let { armyId = null, guid = null, squadId = null } = customizedSoldierInfo.value
  if (armyId == null || guid == null || squadId == null)
    return {}

  let res = {}

  let campaignOutfit = getSquadCampainOutfit(armyId, squadId, armySquadsById.value)
  let itemScheme = getCustomizeScheme(squadsCfgById.value, configs.value, armyId, squadId, campaignOutfit)
  let curSoldierItems = clone soldiersLook.value?[guid].items
  let premiumToOverride = allOutfitByArmy.value?[armyId] ?? []
  foreach (item in premiumToOverride)
    if (isLinkedTo(item, guid) && isObjAvailableForCampaign(item, campaignOutfit)) {
      let slot = item.links[guid]
      curSoldierItems[slot] <- item.basetpl
    }

  foreach (part in lookCustomizationParts) {
    let { slotName } = part
    if (itemScheme?[slotName] == null || itemScheme[slotName].len() == 1)
      continue

    res[slotName] <- curSoldierItems?[slotName] ?? ""
  }

  return res
})

oldSoldiersLook.subscribe(@(v) curCustomizationItem(v?[currentItemPart.value]))

let createItemsPerSlotWatch = @() Computed(function() {
  let { armyId = null, squadId = null, guid = null } = customizedSoldierInfo.value
  let defaultItems = soldiersLook.value?[guid].items
  if (defaultItems == null || armyId == null || squadId == null || guid == null)
    return []

  let itemTypes = configs.value?.outfit_shop ?? {}
  let curItemPart = currentItemPart.value
  if (curItemPart == "")
    return []

  let defaultItem = defaultItems?[curItemPart]

  let campaignOutfit = getSquadCampainOutfit(armyId, squadId, armySquadsById.value)
  let allItems = getCustomizeScheme(squadsCfgById.value, configs.value, armyId, squadId, campaignOutfit)
  local res = clone (allItems?[curItemPart] ?? [])
  let curPrice = curSoldierItemsPrice.value
  local defItemInScheme = null
  let freeItems = freeItemsForSoldier.value

  res = res
    .filter(function(val) {
      let { itemsubtype = null } = findItemTemplate(allItemTemplates, armyId, val)
      let curItemPrice = itemTypes?[itemsubtype] ?? {}
      let isItemDefault = defaultItem == val
      if (isItemDefault) {//completely ignore default item, we put it on top
        defItemInScheme = val
        return false
      }
      if (val != "" && curItemPrice.len() <= 0)
        return false
      let isHidden = curItemPrice.findvalue(@(v) v?.isZeroHidden) != null
      if (!isHidden || val in freeItems)
        return true
      return val in curPrice
    })
    .sort(@(a,b) b in freeItems <=> a in freeItems
      || (curPrice?[a].len() ?? 0) > 0 <=> (curPrice?[b].len() ?? 0) > 0)

  if (defItemInScheme != null)
    res.insert(0, defItemInScheme) //default item must be always on top
  return res
})

let itemsInfo = Computed(function() {
  let { armyId = null, squadId = null } = customizedSoldierInfo.value
  if (armyId == null || squadId == null)
    return {}

  let campaignOutfit = getSquadCampainOutfit(armyId, squadId, armySquadsById.value)
  let allItems = getCustomizeScheme(squadsCfgById.value, configs.value, armyId, squadId, campaignOutfit)
  let templates = {}
  let DB = ecs.g_entity_mgr.getTemplateDB()

  let result = allItems.reduce(function(res, itemsBySlots, itemSlot) {
    itemsBySlots.each(function(item) {
      if (item == "")
        return
      let { gametemplate = "", slotTemplates = {} } = findItemTemplate(allItemTemplates, armyId, item)
      let iconAttachments = []
      foreach (key, val in slotTemplates) {
        if (val == "")
          continue
        local templ = templates?[val]
        if (templ == null) {
          templ = DB.getTemplateByName(val)
          templates[val] <- templ
        }
        if (templ == null) {
          if (DB.size() != 0)
            logerr($"Not found items template for {val} at {key} slot")
          continue
        }
        iconAttachments.append({
          animchar = templ.getCompValNullable("animchar__res") ?? ""
          slot = key
          active = templ.getCompValNullable("isActivated") ?? ""
        })
      }
      res[item] <- { gametemplate, iconAttachments, itemSlot }
    })
    return res
  }, {})
  return result
})


function closeCustomizationWnd() {
  currentItemPart("")
  curCustomizationItem(null)
  customizationToApply({})
  isCustomizationWndOpened(false)
}

function getAvailableItem(possibleItems, soldierGuid,
    slot, itemTpl = "", usedGuids = {}) {
  local alreadyEquipped = false
  local candidateItem = null
  // look through all possible items and save the first available item as candidateItem
  // keep iteration to find if there is an item already equipped to this soldier
  foreach(item in possibleItems) {
    if (itemTpl != "" && item.basetpl != itemTpl)
      continue

    let sGuid = getFirstLinkByType(item, slot)
    if (sGuid == soldierGuid) {
      alreadyEquipped = true
      candidateItem = item
      break
    }
    if (candidateItem != null)
      continue
    if (sGuid == null && item.guid not in usedGuids) {
      candidateItem = item
    }
  }

  return { alreadyEquipped, itemGuid = candidateItem?.guid ?? "" }
}


function saveOutfit(needCloseWnd = true, calleeCb = null) {
  let { guid = null, armyId = null, squadId = null } = customizedSoldierInfo.value
  let applyItems = customizationToApply.value
  if ( guid == null || applyItems.findindex(@(item, slot)
      item != oldSoldiersLook.value?[slot]) == null) {
    if (needCloseWnd)
      closeCustomizationWnd()
    return true
  }

  if (itemsToBuy.value.len() > 0) {
    let self = calleeCb ?? callee()
    showMsgbox({
      text = needCloseWnd ? loc("msg/leaveAppearanceConfirm") : loc("msg/cancelOutfitChanges")
      buttons = [
        { text = needCloseWnd ? loc("Yes") : loc("Ok"),
          action = function() {
            customizationToApply({})
            self()
          },
          isCurrent = true }
        { text = loc("Cancel"), isCancel = true, customStyle = { hotkeys = [[$"^{JB.B} | Esc"]] } }
      ]
    })
    return false
  }

  let prem = {}
  let premList = curArmyOutfit.value ?? []
  foreach (slot, outfitTmpl in customizationToApply.value) {
    if (outfitTmpl == "")
      prem[slot] <- ""
    else {
      let { itemGuid, alreadyEquipped } = getAvailableItem(premList, guid, slot, outfitTmpl)
      if (!alreadyEquipped)
        prem[slot] <- itemGuid
    }
  }

  let campaignOutfit = getSquadCampainOutfit(armyId, squadId, armySquadsById.value)
  change_outfit(guid, {}, prem, campaignOutfit)
  if (needCloseWnd)
    closeCustomizationWnd()
  return true
}

function blockOnClick(slotName) {
  currentItemPart(slotName)
  isCustomizationWndOpened(true)
}

function itemBlockOnClick(item) {
  if (item == "") {
    curCustomizationItem("")
    customizationToApply.mutate(@(v) v[currentItemPart.value] <- "")
    return
  }
  curCustomizationItem(item)
  customizationToApply.mutate(@(v) v[currentItemPart.value] <- item)
}

console_register_command(function() {
  if (customizedSoldierInfo.value == null) {
    console_print("Please select soldier for customization")
    return
  }

  let { guid, armyId, squadId } = customizedSoldierInfo.value
  let campaignOutfit = getSquadCampainOutfit(armyId, squadId, armySquadsById.value)
  let scheme = getCustomizeScheme(squadsCfgById.value, configs.value, armyId, squadId, campaignOutfit)

  let premList = curArmyOutfit.value ?? []
  let outfitTypes = configs.value?.outfit_shop ?? {}
  let free = {}
  let prem = {}
  foreach (slotId, list in scheme) {
    let freeAvail = []
    let premAvail = []
    foreach (outfitTmpl in list) {
      if (outfitTmpl == "")
        freeAvail.append(outfitTmpl)
      else {
        let prems = premList
          .filter(@(outfit) outfit.basetpl == outfitTmpl)
          .map(@(outfit) outfit.guid)
        if (prems.len() > 0)
          premAvail.extend(prems)
        else {
          let { itemsubtype = "" } = findItemTemplate(allItemTemplates, armyId, outfitTmpl)
          if (itemsubtype not in outfitTypes)
            freeAvail.append(outfitTmpl)
        }
      }
    }
    if (freeAvail.len() > 0)
      free[slotId] <- freeAvail[rand.rint(0, freeAvail.len() - 1)]
    if (premAvail.len() > 0)
      prem[slotId] <- premAvail[rand.rint(0, premAvail.len() - 1)]
  }
  change_outfit(guid, free, prem, campaignOutfit, console_print)
}, "outfit.applyRandom")

return {
  isCustomizationWndOpened
  closeCustomizationWnd
  availableCItem
  currentItemPart
  lookCustomizationParts
  createItemsPerSlotWatch
  curCustomizationItem
  blockOnClick
  itemBlockOnClick
  outfitShopTypes

  saveOutfit
  increment
  getAvailableItem

  customizedSoldierInfo
  customizationToApply
  oldSoldiersLook
  itemsInfo
  itemsToBuy
  freeItemsBySquad
  freeItemsForSoldier
  premiumItemsCount
  selectedItemsPrice
  curSoldierItemsPrice
}
