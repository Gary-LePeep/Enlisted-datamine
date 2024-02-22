from "%enlSqGlob/ui/ui_library.nut" import *

let { DBGLEVEL } = require("dagor.system")
let { configs } = require("%enlist/meta/configs.nut")
let { campaignsByArmy, wallposters } = require("%enlist/meta/profile.nut")
let { getWPPresentation } = require("wallpostersPresentation.nut")
let { add_wallposter } = require("%enlist/meta/clientApi.nut")
let { allArmiesInfo } = require("%enlist/soldiers/model/config/gameProfile.nut")


let wpIdSelected = Watched(null)

let wallpostersCfg = Computed(function() {
  let campaigns = campaignsByArmy.value
  let armies = allArmiesInfo.value
  let wpReceived = {}
  foreach (wp in wallposters.value)
    wpReceived[wp.tpl] <- true

  let res = []
  foreach (armyId, wpData in configs.value?.wallpostersCfg ?? {})
    foreach (wallposterTpl, wallposter in wpData ?? {}) {
      let { isNotOwnedHidden = false } = wallposter
      let hasReceived = wallposterTpl in wpReceived
      let armyInfo = armies?[armyId]
      res.append({
        armyId = armyInfo ? armyId : null
        armyLocId = armyInfo ? $"country/{armyInfo.country}" : armyId
        wallposterTpl
        isNotOwnedHidden
        hasReceived
        isHidden = isNotOwnedHidden && !hasReceived
        campaignId = campaigns?[armyId].id
        campaignTitle = campaigns?[armyId].title
      }.__update(getWPPresentation(wallposterTpl)))
    }
  res.sort(@(a, b) a.armyId <=> b.armyId || a.wallposterTpl <=> b.wallposterTpl)
  return res
})

let wpCfgFiltered = Computed(@()
  wallpostersCfg.value.filter(@(wp) !wp.isHidden || DBGLEVEL != 0))

let isWpHidden = Computed(@() wpCfgFiltered.value.len() == 0)

console_register_command(@(id) add_wallposter(id), "meta.addWallposter")

return {
  wallpostersCfg
  wpCfgFiltered
  wpIdSelected
  isWpHidden
}
