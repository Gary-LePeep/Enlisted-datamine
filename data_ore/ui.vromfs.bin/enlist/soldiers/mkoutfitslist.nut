from "%enlSqGlob/ui/ui_library.nut" import *

let { squadsCfgById } = require("%enlist/soldiers/model/config/squadsConfig.nut")
let { panelBgColor, hoverPanelBgColor, selectedPanelBgColor, defTxtColor, titleTxtColor,
  squadSlotBgHoverColor, squadSlotBgIdleColor, defBgColor, commonBtnHeight,
  soldierWndWidth, midPadding, smallPadding, listCtors
} = require("%enlSqGlob/ui/designConst.nut")
let { Bordered } = require("%ui/components/txtButton.nut")
let modalPopupWnd = require("%ui/components/modalPopupWnd.nut")
let { fontBody, fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let { stateChangeSounds } = require("%ui/style/sounds.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { set_squad_outfit_preset } = require("%enlist/meta/clientApi.nut")
let { getLinkedArmyName } = require("%enlSqGlob/ui/metalink.nut")
let { armySquadsById } = require("%enlist/soldiers/model/state.nut")
let { getCampaignTitle } = require("%enlSqGlob/ui/itemsInfo.nut")
let { getSquadCampainOutfit } = require("%enlist/soldiers/model/config/outfitConfig.nut")
let { utf8ToUpper } = require("%sqstd/string.nut")
let faComp = require("%ui/components/faComp.nut")


let WND_UID = "outfits_list"
let CAMPAIGNS_ORDER = [ "moscow", "berlin", "stalingrad", "pacific", "normandy", "tunisia", "ardennes" ]

let defTxtStyle = { color = defTxtColor }.__update(fontBody)
let selectedTxtStyle = { color = titleTxtColor }.__update(fontBody)

let slotBGColor = @(sf, isSelected = false) sf & S_HOVER ? hoverPanelBgColor
  : isSelected ? selectedPanelBgColor
  : panelBgColor

let outfitTextStyle = @(sf, isSelected = false) sf & S_HOVER ? selectedTxtStyle
  : isSelected ? selectedTxtStyle
  : defTxtStyle

let squadButtonBGColor = @(sf) sf & S_HOVER ? squadSlotBgHoverColor
  : squadSlotBgIdleColor

let squadButtonTitleTextColor = listCtors.nameColor
let squadButtonOutfitNameColor = listCtors.weaponColor

let close = @() modalPopupWnd.remove(WND_UID)

let open = @(popupParams, squadGuid, soldierTemplatePreset, selectedOutfitCampaign)
  modalPopupWnd.add(popupParams.startPoint, {
    uid = WND_UID
    popupHalign = ALIGN_LEFT
    popupValign = ALIGN_TOP
    popupFlow = popupParams.popupFlow
    moveDuration = min(0.12 + 0.03 * soldierTemplatePreset.len(), 0.3)
    padding = 0
    fillColor = defBgColor
    children = @() {
      size = [soldierWndWidth - 2*midPadding, SIZE_TO_CONTENT]
      rendObj = ROBJ_BOX
      fillColor = defBgColor
      flow = FLOW_VERTICAL
      children = CAMPAIGNS_ORDER
        .filter(@(val) val in soldierTemplatePreset)
        .map(function(campaignId) {
          let isSelected = Computed(@() campaignId == selectedOutfitCampaign)

          return watchElemState(@(sf) {
            watch = isSelected
            behavior = Behaviors.Button
            rendObj = ROBJ_BOX
            size = [flex(), commonBtnHeight]
            flow = FLOW_HORIZONTAL
            valign = ALIGN_CENTER
            halign = ALIGN_CENTER
            sound = stateChangeSounds
            fillColor = slotBGColor(sf, isSelected.value)
            onClick = function() {
              if (isSelected.value) {
                close()
                return
              }

              set_squad_outfit_preset(squadGuid, campaignId)
              close()
            }
            children = {
              rendObj = ROBJ_TEXT
              text = getCampaignTitle(campaignId)
            }.__update(outfitTextStyle(sf, isSelected.value))
          })
        })
    }
    hotkeys = [[$"^{JB.B} | Esc", { action = close }]]
  })


let mkOutfitsListButton = @(squadInfo, canOpenCb = null) function() {
  let armyId = getLinkedArmyName(squadInfo)
  let { guid, squadId } = squadInfo

  let { soldierTemplatePreset = {} } = squadsCfgById.value?[armyId][squadId]
  if (soldierTemplatePreset.len() <= 1)
    return { watch = [squadsCfgById] }

  let campaignOutfit = getSquadCampainOutfit(armyId, squadId, armySquadsById.value)
  let text = loc("appearance/mode")
  return {
    watch = [ squadsCfgById, armySquadsById ]
    size = [flex(), SIZE_TO_CONTENT]
    halign = ALIGN_CENTER
    flow = FLOW_VERTICAL
    gap = smallPadding
    children = [
      {
        rendObj = ROBJ_TEXT
        text
        color = titleTxtColor
        hplace = ALIGN_CENTER
      }.__update(fontSub)
      Bordered(
        getCampaignTitle(campaignOutfit),
        function(event) {
          if (canOpenCb != null) {
            let recEvent = event
            let self = callee()
            if (!canOpenCb?(@() self(recEvent)))
              return
          }

          open({
            startPoint = [event.targetRect.l, event.targetRect.b]
            popupFlow = FLOW_VERTICAL
          }, guid, soldierTemplatePreset, campaignOutfit)
        },
        { btnWidth = flex() }
      )
    ]
  }
}

let mkSquadListOufitButton = function(squadInfo) {
  let armyId = getLinkedArmyName(squadInfo)
  let { guid, squadId } = squadInfo
  let text = "".concat(utf8ToUpper(loc("outfits/label")), loc("ui/colon"))

  return watchElemState(function(sf) {
    let { soldierTemplatePreset = {} } = squadsCfgById.value?[armyId][squadId]
    if (soldierTemplatePreset.len() <= 1)
      return { watch = [squadsCfgById] }

    let campaignOutfit = getSquadCampainOutfit(armyId, squadId, armySquadsById.value)
    let campaignText = getCampaignTitle(campaignOutfit)
    return {
      watch = [ squadsCfgById, armySquadsById ]
      size = [flex(), SIZE_TO_CONTENT]
      rendObj = ROBJ_BOX
      behavior = Behaviors.Button
      flow = FLOW_HORIZONTAL
      fillColor = squadButtonBGColor(sf)
      onClick = @(event) open({
        startPoint = [event.targetRect.r + smallPadding, event.targetRect.t]
        popupFlow = FLOW_HORIZONTAL
      }, guid, soldierTemplatePreset, campaignOutfit)
      children = [
        {
          flow = FLOW_VERTICAL
          size = [flex(), SIZE_TO_CONTENT]
          valign = ALIGN_CENTER
          margin = smallPadding
          children = [
            {
              rendObj = ROBJ_TEXT
              text
              color = squadButtonTitleTextColor(sf, false)
              hplace = ALIGN_LEFT
            }.__update(fontSub)
            {
              rendObj = ROBJ_TEXT
              text = campaignText
              color = squadButtonOutfitNameColor(sf, false)
              hplace = ALIGN_LEFT
            }.__update(fontSub)
          ]
        }
        {
          size = [hdpxi(36), flex()]
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          children = faComp("angle-right", {
            fontSize = hdpxi(36)
            color = squadButtonTitleTextColor(sf, false)
          })
        }
      ]
    }
  })
}

return {
  mkOutfitsListButton
  mkSquadListOufitButton
}