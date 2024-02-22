from "%enlSqGlob/ui/ui_library.nut" import *

let { fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let { modeCardSize, panelBgColor, modeNameBlockHeight, smallPadding, defTxtColor, accentColor,
  defItemBlur, darkTxtColor
} = require("%enlSqGlob/ui/designConst.nut")
let { sceneWithCameraAdd, sceneWithCameraRemove } = require("%enlist/sceneWithCamera.nut")
let { selectedCampaign, curCampaign } = require("%enlist/meta/curCampaign.nut")
let { curArmies, curArmiesList, selectArmy } = require("%enlist/soldiers/model/state.nut")
let armiesPresentation = require("%enlSqGlob/ui/armiesPresentation.nut")
let { mkArmyIcon } = require("%enlist/soldiers/components/armyPackage.nut")
let { widgetUserName } = require("%enlist/components/userName.nut")
let { visibleCampaigns } = require("%enlist/meta/campaigns.nut")
let defSceneWrap = require("%enlist/defSceneWrap.nut")
let { commonWndParams } = require("%enlist/navigation/commonWndParams.nut")
let { allArmiesInfo } = require("%enlist/soldiers/model/config/gameProfile.nut")
let { getArmyName } = require("%enlist/campaigns/armiesConfig.nut")

let gapCards = hdpx(32)
let nameBlockSize = [modeCardSize[0], modeNameBlockHeight]

let defTxtStyle = freeze({ color = defTxtColor }.__update(fontBody))
let hoverTxtStyle = freeze({ color = darkTxtColor }.__update(fontBody))

let isOpened = Computed(@()
  (selectedCampaign.value != null || visibleCampaigns.value.len() == 1)
  && curArmies.value?[curCampaign.value] == null)

let getArmyImage = @(armyId) armiesPresentation?[armyId].promoImage ?? $"ui/soldiers/{armyId}.avif"

let mkText = @(text, style = {}) {
  rendObj = ROBJ_TEXT
  text
}.__update(style ?? fontBody)

let mkArmyImage = @(image, sf) {
  rendObj = ROBJ_IMAGE
  size = flex()
  keepAspect = KEEP_ASPECT_FILL
  imageHalign = ALIGN_CENTER
  imageValign = ALIGN_TOP
  image = Picture(image)
  fallbackImage = Picture("ui/soldiers/army_default.avif")
  transform = { scale = sf & S_HOVER ? [1.05, 1.05] : [1, 1] }
  transitions = [ { prop = AnimProp.scale, duration = 0.4, easing = OutQuintic } ]
}

let mkArmyName = @(armyId, sf) @() {
  watch = allArmiesInfo
  rendObj = ROBJ_WORLD_BLUR
  size = [flex(), nameBlockSize[1]]
  fillColor = sf & S_HOVER ? accentColor : panelBgColor
  color = defItemBlur
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  vplace = ALIGN_BOTTOM
  padding = [0, smallPadding]
  children = mkText(getArmyName(armyId), sf & S_HOVER ? hoverTxtStyle : defTxtStyle)
}

let mkArmyButton = @(armyId) watchElemState(@(sf) {
  rendObj = ROBJ_BOX
  size = modeCardSize
  fillColor = Color(50,50,50)
  behavior = Behaviors.Button
  onClick = @() selectArmy(armyId)
  clipChildren = true
  children = [
    mkArmyImage(getArmyImage(armyId), sf),
    mkArmyName(armyId, sf),
    mkArmyIcon(armyId)
  ]
})

let mkChooseArmyBlock = @() {
  size = flex()
  children = [
    {
      size = flex()
      flow = FLOW_VERTICAL
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      gap = gapCards
      children = [
        mkText(loc("choose_army"), defTxtStyle)
        @() {
          watch = curArmiesList
          gap = gapCards
          flow = FLOW_HORIZONTAL
          children = curArmiesList.value.map(mkArmyButton)
        }
      ]
    }
    widgetUserName
  ]
}

let changeArmyWndBody = {
  size = flex()
  halign = ALIGN_CENTER
  children = mkChooseArmyBlock
}.__update(commonWndParams)


let chooseArmyScene = defSceneWrap(changeArmyWndBody, { maxWidth = sw(100) })

function open() {
  sceneWithCameraAdd(chooseArmyScene, "armory")
}

if (isOpened.value == true)
  open()

isOpened.subscribe(function(v) {
  if (v == true)
    open()
  else
    sceneWithCameraRemove(chooseArmyScene)
})

return isOpened
