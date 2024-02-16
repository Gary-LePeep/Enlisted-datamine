from "%enlSqGlob/ui_library.nut" import *

let { isPlatformRelevant } = require("%dngscripts/platform.nut")
let { configs } = require("%enlist/meta/configs.nut")
let { purchasesCount, armies } = require("%enlist/meta/servProfile.nut")
let { gameProfile } = require("%enlist/soldiers/model/config/gameProfile.nut")
let { maxVersionStr, maxVersionInt } = require("%enlSqGlob/client_version.nut")
let { check_version } = require("%sqstd/version_compare.nut")
let { renameCommonArmies } = require("%enlSqGlob/renameCommonArmies.nut")

let unlocks = Computed(function() {
  let { shop_items = {}, locked_campaigns = [], locked_progress_campaigns = [] } = configs.value
  let open = {}
  let progress = {}
  foreach (camp in locked_campaigns)
    open[camp] <- []
  foreach (camp in locked_progress_campaigns)
    progress[camp] <- []

  foreach (id, item in shop_items) {
    foreach (camp in item?.campaigns ?? [])
      if (camp in open)
        open[camp].append(id)
    foreach (camp in item?.campaignsProgress ?? [])
      if (camp in progress)
        progress[camp].append(id)
  }

  return { open, progress }
})

let visibleCampaigns = Computed(function() {
  let armiesData = armies.value
  let legacyCampaignsList = []
  let unitedCampaignsList = []
  local hasActiveLegacyArmy = false
  foreach (campaignId in configs.value?.gameProfile.visibleCampaigns ?? []) {
    let campaign = gameProfile.value?.campaigns[campaignId] ?? {}
    if (campaign?.isUnited ?? false)
      unitedCampaignsList.append(campaignId)
    else {
      legacyCampaignsList.append(campaignId)
      foreach (armyId in campaign?.armies ?? []) {
        let { exp = 0, level = 0 } = armiesData?[armyId]
        if (exp > 0 || level > 0)
          hasActiveLegacyArmy = true
      }
    }
  }

  return hasActiveLegacyArmy ? legacyCampaignsList : unitedCampaignsList
})

let isUnlocked = @(campUnlocks, purchases)
  campUnlocks == null || campUnlocks.findindex(@(id) (purchases?[id].amount ?? 0) > 0) != null

let nullIfFitVersion = @(reqVersion, versionInt, versionStr) //FIXME: better to make new function to check version with int parameter
  reqVersion == "" || versionInt == 0 || check_version(reqVersion, versionStr)
    ? null
    : reqVersion

let hiddenCampaigns = Computed(@() (configs.value?.gameProfile.hideByPlatformCampaigns ?? {})
  .map(isPlatformRelevant)
  .filter(@(v) v))

let campaignsInfo = Computed(function() {
  let unlocked = []
  let locked = {}
  let lockedProgress = {}
  local { availableCampaigns = [], campaigns = {}, reqVersion = "" } = configs.value?.gameProfile
  availableCampaigns = availableCampaigns.filter(@(c) c not in hiddenCampaigns.value)
  reqVersion = nullIfFitVersion(reqVersion, maxVersionInt.value, maxVersionStr.value)
  let purchases = purchasesCount.value
  let { open, progress } = unlocks.value

  foreach (camp in availableCampaigns) {
    if (!isUnlocked(open?[camp], purchases))
      locked[camp] <- { reqPurchase = open[camp] }
    else {
      let reqVersionC = reqVersion
        ?? nullIfFitVersion(campaigns?[camp].reqVersion ?? "", maxVersionInt.value, maxVersionStr.value)
      if (reqVersionC == null)
        unlocked.append(camp)
      else
        locked[camp] <- { reqVersion = reqVersionC }
    }

    if (!isUnlocked(progress?[camp], purchases))
      lockedProgress[camp] <- progress[camp]
  }

  return { unlocked, locked, lockedProgress }
})

let function isUnited() {
  return renameCommonArmies.findvalue(function(_, armyId) {
    let { exp = 0, level = 0 } = armies.value?[armyId]
    return exp != 0 || level != 0
  }) == null
}

return {
  lockedCampaigns = Computed(@() campaignsInfo.value.locked)
  unlockedCampaigns = Computed(@() campaignsInfo.value.unlocked)
  lockedProgressCampaigns = Computed(@() campaignsInfo.value.lockedProgress)
  visibleCampaigns
  isUnited
}