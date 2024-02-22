from "%enlSqGlob/ui/ui_library.nut" import *

let { mkOnlineSaveData } = require("%enlSqGlob/mkOnlineSaveData.nut")
let { squadLeaderState, isInSquad, isSquadLeader } = require("%enlist/squad/squadState.nut")
let { unlockedCampaigns, visibleCampaigns, lockedProgressCampaigns } = require("campaigns.nut")
let { gameProfile } = require("%enlist/soldiers/model/config/gameProfile.nut")
let { nestWatched } = require("%dngscripts/globalState.nut")
let { getCampaignTitle } = require("%enlSqGlob/ui/itemsInfo.nut")

const COMMON_CAMPAIGN = "common"

let curCampaignStorage = mkOnlineSaveData(COMMON_CAMPAIGN)
let setCurCampaign = curCampaignStorage.setValue
let curCampaignStored = curCampaignStorage.watch
let roomCampaign = nestWatched("roomCampaign", null)
let campaignOverride = nestWatched("campaignOverride", []) //squad leader campaign still will be more important
let topCampaignOverride = Computed(@() campaignOverride.value?[campaignOverride.value.len() - 1].campaign)

let selectedCampaign = Computed(function() {
  let campaign = roomCampaign.value ?? topCampaignOverride.value ?? curCampaignStored.value
  return visibleCampaigns.value.contains(campaign)
    && unlockedCampaigns.value.contains(campaign) ? campaign : null
})

let curCampaign = Computed(@()
  (roomCampaign.value != null
      || isSquadLeader.value
      || !unlockedCampaigns.value.contains(squadLeaderState.value?.curCampaign)
    ? null
    : squadLeaderState.value?.curCampaign)
  ?? selectedCampaign.value
  ?? visibleCampaigns.value?[0])

let curCampaignConfig = Computed(@() gameProfile.value?.campaigns[curCampaign.value])
let curCampaignLocId = Computed(@() getCampaignTitle(curCampaign.value))

function addCurCampaignOverride(id, campaign) {
  let cfg = campaignOverride.value.findvalue(@(c) c.id == id)
  if (cfg == null)
    campaignOverride.mutate(@(o) o.append({ id, campaign }))
  else if (campaign != cfg.campaign)
    campaignOverride.mutate(function(_) { cfg.campaign = campaign })
}

function removeCurCampaignOverride(id) {
  let idx = campaignOverride.value.findindex(@(c) c.id == id)
  if (idx != null)
    campaignOverride.mutate(@(o) o.remove(idx))
}

return {
  curCampaignStored
  selectedCampaign
  setCurCampaign
  setRoomCampaign = @(campaign) roomCampaign(campaign)
  curCampaign
  curCampaignConfig
  curCampaignLocId
  canChangeCampaign = Computed(@() !isInSquad.value || isSquadLeader.value)
  isCurCampaignProgressUnlocked = Computed(@() curCampaign.value not in lockedProgressCampaigns.value)
  addCurCampaignOverride
  removeCurCampaignOverride
  COMMON_CAMPAIGN
}
