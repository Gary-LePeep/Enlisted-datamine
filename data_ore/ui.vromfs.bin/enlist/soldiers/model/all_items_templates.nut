from "%enlSqGlob/ui/ui_library.nut" import *

let { configs } = require("%enlist/meta/configs.nut")
let {hasClientPermission} = require("%enlSqGlob/client_user_rights.nut")
let { getLinkedArmyName } = require("%enlSqGlob/ui/metalink.nut")

let templatesCombined = Computed(function() {
  let all = {}
  let { boosters = {}, items_templates = {} } = configs.value
  foreach (armyId, armyTemplates in items_templates) {
    if (armyId not in all)
      all[armyId] <- {}
    foreach (key, item in armyTemplates)
      all[armyId][key] <- (all[armyId]?[key] ?? {}).__merge(item, boosters?[key] ?? {})
  }
  return all
})

let equipSchemesByArmy = Computed(function() {
  let tblDisabled = freeze({ isDisabled = true })
  let emptyArray = freeze([])
  let schemesAll = {}
  let equipSchemes = configs.value?.equip_schemes ?? {}
  foreach (armyId, armyTemplates in templatesCombined.value) {
    let templatesTypes = {}
    foreach(tpl in armyTemplates)
      templatesTypes[tpl.itemtype] <- true

    schemesAll[armyId] <- equipSchemes.map(@(scheme) scheme.map(function(slot) {
      let { items = emptyArray, itemTypes = emptyArray } = slot
      local availItemOrType = items.findvalue(@(itemTpl) itemTpl in armyTemplates)
        ?? itemTypes.findvalue(@(it) it in templatesTypes)
      return availItemOrType == null ? slot.__merge(tblDisabled) : slot
    }))
  }
  return schemesAll
})

let isDebugShow = hasClientPermission("debug_items_show")

let allItemTemplates = Computed(@() templatesCombined.value.map(function(armyTemplates, armyId) {
  let equipSchemes = equipSchemesByArmy.value?[armyId] ?? {}
  return armyTemplates
    .filter(@(tpl) !(tpl?.isShowDebugOnly ?? false) || isDebugShow.value)
    .map(function(tpl) {
      let { slot = "", equipSchemeId = null } = tpl
      if (slot == "" && "slot" in tpl)
        tpl.$rawdelete("slot")
      if (equipSchemeId in equipSchemes)
        tpl.equipScheme <- equipSchemes[equipSchemeId]
      return tpl
    })
  }))

function findItemTemplate(templates, army, tpl) {
  return templates.value?[army][tpl]
}

function findItemTemplateByItemInfo(templates, itemInfo) {
  return findItemTemplate(templates, getLinkedArmyName(itemInfo), itemInfo?.basetpl)
}

let singleSlotItemTypes = @(subSchemeGetter) function(scheme, resTypes) {
  let { itemTypes = [] } = subSchemeGetter(scheme)
  foreach (iType in itemTypes)
    resTypes[iType] <- true
}

let slotTypesConfig = {
  function mainWeapon(scheme, resTypes) {
    foreach (key, slotData in scheme)
      if (["primary", "secondary"].contains(slotData?.ingameWeaponSlot) && key != "medbox") {
        let { itemTypes = [] } = slotData
        foreach (iType in itemTypes)
          resTypes[iType] <- true
      }
  }
  primary = singleSlotItemTypes(@(scheme) scheme?.primary)
  secondary = singleSlotItemTypes(@(scheme) scheme?.secondary)
  melee = singleSlotItemTypes(@(scheme) scheme?.melee)
}

let itemTypesInSlots = Computed(function() {
  let equipSchemes = configs.value?.equip_schemes ?? {}
  return slotTypesConfig.map(function(handler) {
    let resTypes = {}
    equipSchemes.each(@(s) handler(s, resTypes))
    return resTypes
  })
})

return {
  templatesCombined
  equipSchemesByArmy
  allItemTemplates
  findItemTemplate
  findItemTemplateByItemInfo
  itemTypesInSlots
}
