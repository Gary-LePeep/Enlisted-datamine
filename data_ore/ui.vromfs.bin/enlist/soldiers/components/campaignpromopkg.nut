from "%enlSqGlob/ui/ui_library.nut" import *

let { fontHeading2, fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let { kindIcon } = require("%enlSqGlob/ui/soldiersUiComps.nut")
let sClassesCfg = require("%enlist/soldiers/model/config/sClassesConfig.nut")
let { titleTxtColor, activeTxtColor, midPadding, defTxtColor, commonBtnHeight, accentTitleTxtColor,
} = require("%enlSqGlob/ui/designConst.nut")
let { itemTypeIcon } = require("itemTypesData.nut")
let { CAMPAIGN_NONE } = require("%enlist/campaigns/campaignConfig.nut")
let { getConfig } = require("%enlSqGlob/ui/campaignPromoPresentation.nut")

let btnSizeSmall = [hdpx(330), commonBtnHeight]
let btnSizeBig = [hdpx(400), commonBtnHeight]
let mainBgColor = Color(98, 98, 80)
let primeColor = Color(146, 10, 1)
let receivedColor = Color(98, 98, 80)
let unavailableColor = Color(96, 96, 96)
let progressBarWidth = hdpxi(787)

let rewardToScroll = Watched(null)

let mkText = @(txt, style = {}) {
  rendObj = ROBJ_TEXT
  color = defTxtColor
  text = txt
}.__update(fontBody, style)

function mkSquadName(params) {
  let { nameLocId = "", titleLocId = "", sClass = null, itemType = null, itemSubType = null } = params
  return {
    flow = FLOW_HORIZONTAL
    gap = midPadding
    padding = [midPadding * 2, midPadding * 4]
    minWidth = hdpx(300)
    valign = ALIGN_CENTER
    children = [
      sClass == null
        ? itemTypeIcon(itemType, itemSubType, { size = [hdpxi(55), hdpxi(55)] })
        : kindIcon(sClassesCfg.value?[sClass].kind ?? sClass, hdpx(55), null, titleTxtColor)
      {
        flow = FLOW_VERTICAL
        children = [
          mkText(loc(nameLocId), { color = accentTitleTxtColor }).__update(fontBody)
          mkText(loc(titleLocId), { color = titleTxtColor }).__update(fontHeading2)
        ]
      }
    ]
  }
}

let headerBgImage = {
  size = flex()
  rendObj = ROBJ_IMAGE
  image = Picture($"!ui/gameImage/base_header_bar.svg:{hdpxi(150)}:4:K?Ac")
}

function campaignName(params) {
  let { hasReceived, isPrimeSquad = false, campaignGroup = CAMPAIGN_NONE } = params
  let isFreemiumMode = campaignGroup != CAMPAIGN_NONE
  let { color = null, darkColor = null } = getConfig(campaignGroup)
  return {
    vplace = ALIGN_CENTER
    flow = FLOW_VERTICAL
    pos = [-hdpx(23), 0]
    size = [flex(), SIZE_TO_CONTENT]
    children = [
      {
        children = [
          headerBgImage.__merge({
            color = isPrimeSquad ? primeColor
              : isFreemiumMode ? color
              : hasReceived ? receivedColor
              : unavailableColor
          })
          mkSquadName(params)
        ]
      }
      {
        rendObj = ROBJ_VECTOR_CANVAS
        size = [hdpx(15), hdpx(15)]
        lineWidth = 0
        color = 0
        fillColor = isPrimeSquad ? Color(69, 24, 24)
          : isFreemiumMode ? darkColor
          : Color(54, 54, 45)
        commands = [
          [VECTOR_POLY, 0,0, 100,0, 100,100]
        ]
      }
    ]}
}

let mkReceivedBanner = @(bgColor) {
  size = [hdpx(180), hdpx(180)]
  hplace = ALIGN_RIGHT
  clipChildren = true
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = {
    size = [hdpx(300), hdpx(50)]
    pos = [hdpx(20), -hdpx(20)]
    transform = {rotate = 45}
    rendObj = ROBJ_SOLID
    color = bgColor
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = {
      rendObj = ROBJ_TEXT
      text = loc("squads/received")
    }.__update(fontBody)
  }
}

let infoBtnSize = hdpxi(20)
let weapInfoBtn =  @(sf) {
  rendObj = ROBJ_IMAGE
  size = [infoBtnSize, infoBtnSize]
  hplace = ALIGN_RIGHT
  vplace = ALIGN_TOP
  margin = midPadding
  image =  Picture("{0}:{1}:{1}:K".subst("ui/skin#info/info_icon.svg", infoBtnSize))
  color = sf & S_ACTIVE ? activeTxtColor
    : sf & S_HOVER ? titleTxtColor
    : activeTxtColor
}

return {
  campaignName
  btnSizeSmall
  btnSizeBig
  receivedCommon = mkReceivedBanner(mainBgColor)
  receivedFreemium = @(campaignGroup) mkReceivedBanner(getConfig(campaignGroup)?.color)
  weapInfoBtn
  progressBarWidth
  rewardToScroll
}