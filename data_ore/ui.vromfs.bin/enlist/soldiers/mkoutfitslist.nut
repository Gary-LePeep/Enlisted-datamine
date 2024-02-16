from "%enlSqGlob/ui_library.nut" import *

let logO = require("%sqstd/log.nut")().with_prefix("[OUTFITS] ")
let { squadsCfgById } = require("%enlist/soldiers/model/config/squadsConfig.nut")
let { defBgColor, commonBtnHeight, soldierWndWidth, bigPadding, smallPadding } = require("%enlSqGlob/ui/viewConst.nut")
let { panelBgColor, hoverPanelBgColor, selectedPanelBgColor, defTxtColor, titleTxtColor
} = require("%enlSqGlob/ui/designConst.nut")
let { Bordered } = require("%ui/components/txtButton.nut")
let modalPopupWnd = require("%ui/components/modalPopupWnd.nut")
let { fontBody, fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let { stateChangeSounds } = require("%ui/style/sounds.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { set_squad_outfit_preset } = require("%enlist/meta/clientApi.nut")
let { getLinkedSquadGuid } = require("%enlSqGlob/ui/metalink.nut")
let { armySquadsById } = require("%enlist/soldiers/model/state.nut")
let { getCampaignTitle } = require("%enlSqGlob/ui/itemsInfo.nut")


let WND_UID = "outfits_list"
let CAMPAIGNS_ORDER = [ "moscow", "berlin", "stalingrad", "pacific", "normandy", "tunisia", "ardennes" ]

let selectedOutfitCampaign = Watched("")

let defTxtStyle = { color = defTxtColor }.__update(fontBody)
let selectedTxtStyle = { color = titleTxtColor }.__update(fontBody)
let hintTxtStyle = { color = defTxtColor }.__update(fontSub)

let slotBGColor = @(sf, isSelected = false) sf & S_HOVER ? hoverPanelBgColor
  : isSelected ? selectedPanelBgColor
  : panelBgColor

let textStyle = @(sf, isSelected = false) sf & S_HOVER ? selectedTxtStyle
  : isSelected ? selectedTxtStyle
  : defTxtStyle

let close = @() modalPopupWnd.remove(WND_UID)

let function open(event, squadGuid, soldierTemplatePreset) {
  let { l, b } = event.targetRect

  return modalPopupWnd.add([l, b], {
    uid = WND_UID
    popupHalign = ALIGN_LEFT
    popupValign = ALIGN_TOP
    popupFlow = FLOW_VERTICAL
    moveDuration = min(0.12 + 0.03 * soldierTemplatePreset.len(), 0.3)
    padding = 0
    fillColor = defBgColor
    children = @() {
      size = [soldierWndWidth - 2*bigPadding, SIZE_TO_CONTENT]
      rendObj = ROBJ_BOX
      fillColor = defBgColor
      flow = FLOW_VERTICAL
      children =  CAMPAIGNS_ORDER
        .filter(@(val) val in soldierTemplatePreset)
        .map(function(campaignId) {
          let isSelected = Computed(@() campaignId == selectedOutfitCampaign.value)

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

              selectedOutfitCampaign(campaignId)
              set_squad_outfit_preset(squadGuid, campaignId)
              close()
            }
            children = {
              rendObj = ROBJ_TEXT
              text = getCampaignTitle(campaignId)
            }.__update(textStyle(sf, isSelected.value))
          })
        })
    }
    hotkeys = [[$"^{JB.B} | Esc", { action = close }]]
  })
}

let mkOutfitsListButton = @(soldier, canOpenCb = null) function() {
  let squadGuid = getLinkedSquadGuid(soldier)
  if (squadGuid == null) {
    logO("not found squad guid for soldier", soldier)
    return null
  }

  let { armyId, squadId } = soldier
  let { campaignOutfit = "" } = armySquadsById.value[armyId][squadId]

  selectedOutfitCampaign(campaignOutfit)

  let { soldierTemplatePreset = {} } = squadsCfgById.value?[armyId][squadId]
  if (soldierTemplatePreset.len() <= 1)
    return { watch = [squadsCfgById] }

  return {
    watch = [ squadsCfgById, armySquadsById ]
    size = [flex(), SIZE_TO_CONTENT]
    halign = ALIGN_CENTER
    flow = FLOW_VERTICAL
    gap = smallPadding
    children = [
      {
        rendObj = ROBJ_TEXT
        text = loc("appearance/mode")
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

          open(event, squadGuid, soldierTemplatePreset)
        },
        {
          btnWidth = flex()
          hint = {
            rendObj = ROBJ_TEXT
            text = loc("outfits/hint")
          }.__update(hintTxtStyle)
        }
      )
    ]
  }
}

return {
  mkOutfitsListButton
  selectedOutfitCampaign
}