from "%enlSqGlob/ui/ui_library.nut" import *

let { fontHeading2, fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let { txt } = require("%enlSqGlob/ui/defcomps.nut")
let { makeVertScroll, thinStyle } = require("%ui/components/scrollbar.nut")
let { boosterItems, allBoosters } = require("%enlist/soldiers/model/boosters.nut")
let { disabledTxtColor, smallPadding, smallOffset, blurBgFillColor,
  accentColor, blockedTxtColor, darkBgColor } = require("%enlSqGlob/ui/designConst.nut")
let { mkXpBooster, mkBoosterExpireInfo } = require("%enlist/components/mkXpBooster.nut")
let { getCampaignTitle } = require("%enlSqGlob/ui/itemsInfo.nut")
let { abs } = require("math")

let emptyBoostersText = txt({
  text = loc("profile/boostersIsEmpty")
  hplace = ALIGN_CENTER
  color = disabledTxtColor
}).__update(fontHeading2)

function mkBooster(boosterBase) {
  let { campaignLimit, expMul = 0 } = boosterBase
  let limitText = campaignLimit.len() == 0 ? loc("allCampaigns")
    : ", ".join(campaignLimit.map(@(c) getCampaignTitle(c.id)))
  let typeText = expMul > 0 ? $"booster/expBonusTitle"
    : "booster/expPenaltyTitle"
  let isPenalty = expMul < 0
  let valueText = isPenalty ? "booster/expPenaltyVal" : "booster/expBonusVal"
  return {
    xmbNode = XmbNode({
      canFocus = true
      wrap = false
      isGridLine=true
      scrollToEdge = [false, true]
    })
    behavior = Behaviors.Button
    size = [hdpx(400), hdpx(170)]
    margin = [0, 0, 0, hdpx(110)]
    children = [
      {
        size = flex()
        flow = FLOW_VERTICAL
        children = [
          {
            rendObj = ROBJ_SOLID
            size = [flex(), SIZE_TO_CONTENT]
            color = darkBgColor
            padding = [hdpx(5), 0, hdpx(5), hdpx(110)]
            children = mkBoosterExpireInfo(boosterBase,
              true,
              {
                margin = [0, smallOffset]
                flow = FLOW_HORIZONTAL
              }
            )
          }
          {
            rendObj = ROBJ_SOLID
            size = [flex(), SIZE_TO_CONTENT]
            color = blurBgFillColor
            flow = FLOW_VERTICAL
            padding = [0, 0, 0, hdpx(110)]
            children = [
              txt({
                text = limitText
                margin = [hdpx(7), 0]
              }).__update(fontSub)
              txt(loc(typeText)).__update(fontSub)
              txt({
                text = loc(valueText, {exp = abs(boosterBase.expMul * 100).tostring()})
                color = boosterBase.expMul > 0 ? accentColor : blockedTxtColor
                margin = [hdpx(14), 0]
              }).__update(fontHeading2)
              txt({
                padding = [0, 0, hdpx(20), 0]
                text = loc("booster/allTypes")
              }).__update(fontSub)
            ]
          }
        ]
      }
      mkXpBooster({
        size = [hdpx(170), hdpx(200)]
        pos = [-hdpx(90), 0]
        margin = 0
      }, isPenalty)
    ]
  }
}

let boostersListUi = function() {
  let components = allBoosters.value.map(@(boosterBase)
    mkBooster(boosterBase))

  let boostersList = wrap(components, {
    width = sh(100)
    vGap = hdpx(75)
  })
  let scrollBoostersList = makeVertScroll({
      size = [flex(), SIZE_TO_CONTENT]
      padding = [hdpx(40), 0]
      halign = ALIGN_CENTER
      flow = FLOW_VERTICAL
      children = boostersList
    },
    { styling = thinStyle }
  )

  return {
    xmbNode = XmbContainer({
      canFocus = false
      isGridLine=true
      scrollSpeed = [0, 2.0]
      scrollToEdge = [false, true]
    })
    rendObj = ROBJ_BOX
    watch = [boosterItems, allBoosters]
    size = flex()
    valign = components.len() ? ALIGN_TOP : ALIGN_CENTER
    padding = smallPadding
    children = components.len() ? scrollBoostersList : emptyBoostersText
  }
}

return {
  size = flex()
  children = boostersListUi
}
