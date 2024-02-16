from "%enlSqGlob/ui_library.nut" import *

let { nestWatched } = require("%dngscripts/globalState.nut")

let { armies, curCampSquads, curSquadSoldiersInfo } = require("state.nut")
let { collectSoldierDataImpl } = require("%enlist/soldiers/model/collectSoldierData.nut")
let { perksData } = require("soldierPerks.nut")
let { campItemsByLink, curCampSoldiers } = require("%enlist/meta/profile.nut")
let { soldiersLook } = require("%enlist/meta/servProfile.nut")
let { allOutfitByArmy, isOutfitAllowedByCampaign } = require("%enlist/soldiers/model/config/outfitConfig.nut")
let sClassesCfg = require("config/sClassesConfig.nut")
let { configs } = require("%enlist/meta/configs.nut")
let { set_soldier_outfit_preset } = require("%enlist/meta/clientApi.nut")
let { maxTrainByClass } = require("%enlist/soldiers/model/config/soldierTrainingConfig.nut")


let curSoldierIdx = nestWatched("curSoldierIdx", null)
let defSoldierGuid = nestWatched("defSoldierGuid", null)


let collectSoldierData = @(soldier) collectSoldierDataImpl(
  soldier, perksData.value, curCampSquads.value, armies.value,
  sClassesCfg.value, campItemsByLink.value, soldiersLook.value,
  allOutfitByArmy.value.map(
    @(outfitsList) outfitsList.filter(
      @(outfit) isOutfitAllowedByCampaign(outfit, soldier, configs.value)
  )), configs.value?.soldierSchemes ?? {}, maxTrainByClass.value
)

let curSoldiersDataList = Computed(@() curSquadSoldiersInfo.value.map(@(soldier) collectSoldierDataImpl(
  soldier, perksData.value, curCampSquads.value, armies.value,
  sClassesCfg.value, campItemsByLink.value, soldiersLook.value,
  allOutfitByArmy.value.map(
    @(outfitsList) outfitsList.filter(
      @(outfit) isOutfitAllowedByCampaign(outfit, soldier, configs.value)
  )), configs.value?.soldierSchemes ?? {}, maxTrainByClass.value
)))

let curSoldierInfo = Computed(@() curSoldiersDataList.value?[curSoldierIdx.value]
  ?? collectSoldierData(curCampSoldiers.value?[defSoldierGuid.value])
)

let curSoldierGuid = Computed(@() curSoldierInfo.value?.guid)


let mkSoldiersData = @(soldier) soldier instanceof Watched
  ? Computed(@() collectSoldierDataImpl(
      soldier.value, perksData.value, curCampSquads.value, armies.value,
      sClassesCfg.value, campItemsByLink.value, soldiersLook.value,
      allOutfitByArmy.value.map(
        @(outfitsList) outfitsList.filter(
          @(outfit) isOutfitAllowedByCampaign(outfit, soldier.value, configs.value)
      )), configs.value?.soldierSchemes ?? {}, maxTrainByClass.value
    ))
  : Computed(@() collectSoldierDataImpl(
      soldier, perksData.value, curCampSquads.value, armies.value,
      sClassesCfg.value, campItemsByLink.value, soldiersLook.value,
      allOutfitByArmy.value.map(
        @(outfitsList) outfitsList.filter(
          @(outfit) isOutfitAllowedByCampaign(outfit, soldier, configs.value)
      )), configs.value?.soldierSchemes ?? {}, maxTrainByClass.value
    ))

console_register_command(@(campaignId) set_soldier_outfit_preset(curSoldierGuid.value ?? "", campaignId), "meta.dressUpCurSoldierForCampaign")

return {
  curSoldierIdx
  defSoldierGuid

  curSoldierInfo
  curSoldiersDataList
  curSoldierGuid

  collectSoldierData
  mkSoldiersData
}