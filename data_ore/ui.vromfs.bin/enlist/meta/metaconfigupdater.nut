from "%enlSqGlob/ui_library.nut" import *
let { update_meta_config } = require("%enlist/meta/clientApi.nut")
let { metaConfig } = require("%enlist/meta/servProfile.nut")
let { sourceProfileData } = require("%enlist/meta/sourceServProfile.nut")

enum ProhibitionStatus {
  Undefined = "Undefined"
  Allowed = "Allowed"
  Prohibited = "Prohibited"
}

let metaGen = Watched(0)

let isLootBoxProhibited = Computed(@() (metaConfig.value?.prohibitingLootbox
  ?? ProhibitionStatus.Prohibited) == ProhibitionStatus.Prohibited)

local function setProhibitingLootbox(state) {
  let metaCfg = clone metaConfig.value
  metaCfg.prohibitingLootbox <- state
  sourceProfileData.mutate(@(profile) profile.metaConfig = metaCfg)
  update_meta_config(metaCfg, @(_) metaGen(metaGen.value + 1))
}

return {
  isLootBoxProhibited
  ProhibitionStatus
  setProhibitingLootbox
  metaGen
}