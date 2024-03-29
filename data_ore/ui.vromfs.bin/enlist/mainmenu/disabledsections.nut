from "%enlSqGlob/ui/ui_library.nut" import *

let { fontHeading1, fontHeading2 } = require("%enlSqGlob/ui/fontsStyle.nut")
let msgbox = require("%enlist/components/msgbox.nut")
let { curCampaign } = require("%enlist/meta/curCampaign.nut")
let { gameProfile } = require("%enlist/soldiers/model/config/gameProfile.nut")
let { defBgColor, hoverBgColor } = require("%enlSqGlob/ui/designConst.nut")

let disabledSectionsData = Computed(function() {
  let campaign = curCampaign.value
  let disabledList = gameProfile.value?.campaigns[campaign].disabledSections ?? []
  return disabledList.reduce(@(res, key) res.rawset(key, true), {})
})

let hasShopSection = Computed(@() !(disabledSectionsData.value?.LOGISTICS ?? false))

let mkDisabledOptionMsgbox = @(locId = "menu/lockedByCampaignDesc")
  msgbox.show({ text = loc(locId) })

let mkDisabledSectionBlock = kwarg(@(headerLocId = null, descLocId = null) {
  rendObj = ROBJ_BOX
  size = [flex(), fsh(50)]
  vplace = ALIGN_CENTER
  fillColor = defBgColor
  borderWidth = [hdpx(1), 0]
  borderColor = hoverBgColor
  children = {
    size = flex()
    flow = FLOW_VERTICAL
    gap = hdpx(50)
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = [
      headerLocId == null ? null
        : {
            text = loc(headerLocId)
            rendObj = ROBJ_TEXT
          }.__update(fontHeading1)
      descLocId == null ? null
        : {
            rendObj = ROBJ_TEXTAREA
            behavior = Behaviors.TextArea
            size = [sw(50), SIZE_TO_CONTENT]
            halign = ALIGN_CENTER
            color = Color(200,200,200)
            text = loc(descLocId)
          }.__update(fontHeading2)
    ]
    animations = [
      { prop = AnimProp.opacity, from = 0, to = 0, duration = 0.1, play = true,
        easing = InOutCubic }
      { prop = AnimProp.opacity, from = 0, to = 1, duration = 0.3, play = true,
        easing = InOutCubic, delay = 0.1 }
    ]
  }
  transform = { pivot = [0.5, 0.5] }
  animations = [{
    prop = AnimProp.scale, from = [1,0], to = [1,1], duration = 0.2, play = true,
    easing = InOutCubic }
  ]
})

return {
  disabledSectionsData
  mkDisabledSectionBlock
  mkDisabledOptionMsgbox
  hasShopSection
}
