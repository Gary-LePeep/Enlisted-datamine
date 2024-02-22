from "%enlSqGlob/ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { getLinkedArmyName, getLinkedSquadGuid } = require("%enlSqGlob/ui/metalink.nut")
let { mkSoldierPhotoName } = require("%enlSqGlob/ui/soldierPhoto.nut")
let { getWeapTemplates, mkEquipment, getItemAnimationBlacklist } = require("%enlist/scene/soldier_tools.nut")
let { getIdleAnimState } = require("%enlSqGlob/animation_utils.nut")
let { getSoldierItem } = require("%enlist/soldiers/model/state.nut")

  // TODO remove overrideOutfit and isLarge that currently unused
function collectSoldierPhoto(soldier, soldiersOutfit, overrideOutfit = [], isLarge = false) {
  if (soldier?.photo != null)
    return soldier

  let { guid = null, equipScheme = {}, gametemplate = null } = soldier
  let equipmentInfo = []
  let equipment = mkEquipment(soldier, equipScheme, soldiersOutfit, overrideOutfit)
  if (equipment != null) {
    foreach (slot, equip in equipment) {
      if (!equip || !equip.gametemplate)
        continue
      equipmentInfo.append({
        slot = slot
        tpl = equip.gametemplate
      })
    }
  }

  let weapTemplates = getWeapTemplates(guid, equipScheme)
  let soldierTemplate = gametemplate
    ? ecs.g_entity_mgr.getTemplateDB().getTemplateByName(gametemplate)
    : null
  let overridedIdleAnims = soldierTemplate?.getCompValNullable("animation__overridedIdleAnims")
  let overridedSlotsOrder = soldierTemplate?.getCompValNullable("animation__overridedSlotsOrder").getAll()

  let animation = getIdleAnimState({
    weapTemplates
    itemTemplates = getItemAnimationBlacklist(soldier, guid, equipScheme, soldiersOutfit)
    overridedIdleAnims
    overridedSlotsOrder
    seed = guid?.hash() ?? 0
  })

  return soldier.__merge({
    photo = mkSoldierPhotoName(gametemplate, equipmentInfo, animation, isLarge)
  })
}

function collectSoldierDataImpl(
  soldier, perksDataV, curCampSquadsV, armiesV, classesCfgV, campItemsV, soldiersOutfit,
  soldiersPremiumItems, soldierSchemesV, maxTrainByClassV
) {
  let { guid = null, sClass = null, basetpl = null, tier = 1 } = soldier
  if (guid == null)
    return soldier

  let armyId = getLinkedArmyName(soldier)
  let perks = perksDataV?[guid]
  let { exp = 0 } = perks

  let { kind = sClass } = classesCfgV?[sClass] //kind by default is sClass to compatibility with 16.02.2021 pserver version
  let { country = null } = (soldierSchemesV?[armyId] ?? {})
    .findvalue(@(data) basetpl == data.gametemplate)
  return collectSoldierPhoto(soldier.__merge({
    primaryWeapon = getSoldierItem(guid, "primary", campItemsV)
      ?? getSoldierItem(guid, "secondary", campItemsV)
      ?? getSoldierItem(guid, "side", campItemsV)
    country = country ?? armiesV?[armyId].country
    level = tier
    maxLevel = max(tier, (maxTrainByClassV?[sClass] ?? 0) + 1)
    exp
    armyId
    squadId = curCampSquadsV?[getLinkedSquadGuid(soldier)].squadId
    sKind = kind
  }), soldiersOutfit, soldiersPremiumItems)
}

return {
  collectSoldierPhoto
  collectSoldierDataImpl
}