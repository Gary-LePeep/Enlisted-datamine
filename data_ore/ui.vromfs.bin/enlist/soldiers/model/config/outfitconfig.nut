
from "%enlSqGlob/ui_library.nut" import *

let { configs } = require("%enlist/meta/configs.nut")
let { getLinkedArmyName, getLinkedSquadGuid, isLinkedTo, isObjectHaveLinkTypeToAny
} = require("%enlSqGlob/ui/metalink.nut")
let { soldiersOutfit, armies } = require("%enlist/meta/servProfile.nut")
let { squads } = require("%enlist/meta/profile.nut")
let { curArmy, armySquadsById, curSquadId } = require("%enlist/soldiers/model/state.nut")
let { squadsCfgById } = require("%enlist/soldiers/model/config/squadsConfig.nut")

let LOCKED_DRESS_UP_SLOTS = { head = true, hair = true }

let isObjAvailableForCampaign = @(item, campaignId)
  isLinkedTo(item, campaignId)
  || isObjectHaveLinkTypeToAny(item, LOCKED_DRESS_UP_SLOTS)

let outfitSchemes = Computed(@() configs.value?.outfit_schemes ?? {})
let outfitShopTypes = Computed(@() configs.value?.outfit_shop ?? {})

//TODO: Rename: allOutfitByArmy -> all purchased 'premium' outfit
let allOutfitByArmy = Computed(@()
  soldiersOutfit.value.reduce(function(res, outfit) {
    let armyId = getLinkedArmyName(outfit)
    if (armyId not in res)
      res[armyId] <- []
    res[armyId].append(outfit)
    return res
  }, {}))


let getOutfitIdByCampaign = function(squadsCfg, armyId, squadId, campaignId = null) {
  let { soldierTemplatePreset = {} } = squadsCfg?[armyId][squadId]
  if (soldierTemplatePreset.len() == 1)
    return soldierTemplatePreset.values()[0]

  local suitableCampaignId = campaignId
  if (campaignId not in soldierTemplatePreset) {
    let { campaignReplaceTemplate = {} } = armies.value[armyId]
    if (campaignId in campaignReplaceTemplate)
      suitableCampaignId = campaignReplaceTemplate[campaignId]
  }

  return soldierTemplatePreset?[suitableCampaignId] ?? ""
}

let getSquadCampainOutfit = @(armyId, squadId, armySquadsInfo)
  armySquadsInfo?[armyId][squadId].campaignOutfit ?? ""

let getCustomizeScheme = function(squadsCfg, configsVal, armyId, squadId, campaignId = null) {
  let outfitPresetId = getOutfitIdByCampaign(squadsCfg, armyId, squadId, campaignId)
  return configsVal?.outfit_schemes[outfitPresetId] ?? {}
}

let isOutfitAllowedByCampaign = function(outfit, soldier, configsVal) {
  if (!soldier)
    return false

  let armyId = getLinkedArmyName(soldier)
  let squadGuid = getLinkedSquadGuid(soldier)
  let { squadId = "" } = squads.value?[squadGuid]
  let campaignOutfit = getSquadCampainOutfit(armyId, squadId, armySquadsById.value)
  if (!isObjAvailableForCampaign(outfit, campaignOutfit))
    return false

  let scheme = getCustomizeScheme(squadsCfgById.value, configsVal, armyId, squadId, campaignOutfit)
  let slotId = outfit?.links[soldier.guid] ?? ""
  if (slotId == "")
    return false
  return (scheme?[slotId] ?? []).contains(outfit.basetpl)
}

//TODO: Rename: cur army unused outfits
let curArmyOutfit = Computed(function() {
  let armyId = curArmy.value
  let squadId = curSquadId.value
  let campaignOutfit = getSquadCampainOutfit(armyId, squadId, armySquadsById.value)
  return (allOutfitByArmy.value?[armyId] ?? [])
    .filter(function(outfit) {
      if ((outfit?.links ?? {}).len() <= 1)
        return true

      return campaignOutfit == "" || isObjAvailableForCampaign(outfit, campaignOutfit)
  })
})

return {
  outfitSchemes
  outfitShopTypes
  allOutfitByArmy
  curArmyOutfit
  isOutfitAllowedByCampaign
  getCustomizeScheme
  getOutfitIdByCampaign
  getSquadCampainOutfit
  isObjAvailableForCampaign
  LOCKED_DRESS_UP_SLOTS
}