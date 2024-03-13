from "%enlSqGlob/ui/ui_library.nut" import *
let anoDecoratorUi = require("anoDecoratorUi.nut")
let { visibleCampaigns } = require("%enlist/meta/campaigns.nut")
let { smallOffset } = require("%enlSqGlob/ui/designConst.nut")
let { anoProfileData } = require("anoProfileState.nut")
let { mkMapsListUi, mkPlayerStatistics } = require("profilePkg.nut")

return @() {
  size = flex()
  flow = FLOW_VERTICAL
  gap = smallOffset
  children = [
    anoDecoratorUi()
    {
      size = flex()
      flow = FLOW_HORIZONTAL
      gap = smallOffset
      children = [
        mkMapsListUi(visibleCampaigns)
        mkPlayerStatistics(anoProfileData)
      ]
    }
  ]
}