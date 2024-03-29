from "%enlSqGlob/ui/ui_library.nut" import *

let { get_setting_by_blk_path } = require("settings")
let { DBGLEVEL } = require("dagor.system")
let {nestWatched} = require("%dngscripts/globalState.nut")


let hasProfileCard = nestWatched("hasProfileCard", true)
let hasMedals = nestWatched("hasMedals", true)
let hasCustomGames = nestWatched("hasCustomGames", true)
let showEventsWidget = nestWatched("showEventsWidget", true)
let hasUserLogs = nestWatched("hasUserLogs", DBGLEVEL > 0)
let showModsInCustomRoomCreateWnd = nestWatched("showMods", true)
let hasVehicleCustomization = nestWatched( "hasVehicleCustomization", true)
let isOffersVisible = nestWatched("isOffersVisible", true)
let hasUsermail = nestWatched("hasUsermail", DBGLEVEL > 0)
let showReplayTabInProfile = nestWatched("showReplayTabInProfile", true)
let showUserProfile = nestWatched("showUserProfile", DBGLEVEL > 0)
let multiPurchaseAllowed = nestWatched("multiPurchaseAllowed", true)
let PSNAllowShowQRCodeStore = nestWatched("PSNAllowShowQRCodeStore", false)
let canRentSquad = nestWatched("canRentSquad", false)
let hasMassVehDecorPaste = nestWatched("hasMassVehDecorPaste", true)
let hasCampaignPromo = nestWatched("hasCampaignPromo", false)
let hasAutoCluster = nestWatched("hasAutoCluster", false)
let allowReconnect = nestWatched("allowReconnect", true)
let hasHitCamera = nestWatched("hasHitCamera", DBGLEVEL > 0)
let hasGpuBenchmark = nestWatched("hasGpuBenchmark", false)
let hasMissionLikes = nestWatched("hasMissionLikes", DBGLEVEL > 0)


let features = {
  hasProfileCard
  hasMedals
  hasUserLogs
  hasCustomGames
  showEventsWidget
  showModsInCustomRoomCreateWnd
  hasVehicleCustomization
  isOffersVisible
  hasUsermail
  showReplayTabInProfile
  showUserProfile
  multiPurchaseAllowed
  PSNAllowShowQRCodeStore
  canRentSquad
  hasMassVehDecorPaste
  hasCampaignPromo
  hasAutoCluster
  allowReconnect
  hasHitCamera
  hasGpuBenchmark
  hasMissionLikes
}

foreach (featureId, featureFlag in features)
  featureFlag(get_setting_by_blk_path($"features/{featureId}") ?? featureFlag.value)

console_register_command(
  @(name) name in features ? console_print($"{name} = {features[name].value}") : console_print($"FEATURE NOT EXIST {name}"),
  "feature.has")

console_register_command(
  function(name) {
    if (name not in features)
      return console_print($"FEATURE NOT EXIST {name}")
    let feature = features[name]
    feature(!feature.value)
    console_print($"Feature {name} changed to {feature.value}")
  }
  "feature.toggle")

return freeze(features)