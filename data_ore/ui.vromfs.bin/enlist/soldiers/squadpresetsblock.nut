from "%enlSqGlob/ui/ui_library.nut" import *

let { defTxtColor, selectedTxtColor, disabledTxtColor, squadElemsBgColor,
  squadElemsBgHoverColor, commonBtnHeight, midPadding, titleTxtColor, darkPanelBgColor
} = require("%enlSqGlob/ui/designConst.nut")
let { fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let { availablePresetsCount, MAX_PRESETS_COUNT, squadsPresetWatch
} = require("%enlist/squadPresets/squadPresetsState.nut")
let { createSquadsPreset, updateSquadsPreset, deleteSquadsPreset, renameSquadsPreset,
  applySquadsPreset } = require("%enlist/squadPresets/squadPresetsUtils.nut")
let { premiumImage } = require("%enlist/currency/premiumComp.nut")
let premiumWnd = require("%enlist/currency/premiumWnd.nut")
let { FAButton } = require("%ui/components/textButton.nut")
let { stateChangeSounds, buttonSound } = require("%ui/style/sounds.nut")
let modalPopupWnd = require("%ui/components/modalPopupWnd.nut")
let { chosenSquads, getUnlockedSquadsBySquadIds, maxSquadsInBattle, squadsArmy, previewSquads
} = require("%enlist/soldiers/model/chooseSquadsState.nut")
let { setTooltip } = require("%ui/style/cursors.nut")
let textInput = require("%ui/components/textInput.nut")
let JB = require("%ui/control/gui_buttons.nut")
let obsceneFilter = require("%enlSqGlob/obsceneFilter.nut")
let popupsState = require("%enlSqGlob/ui/popup/popupsState.nut")
let spinner = require("%ui/components/spinner.nut")
let { makeVertScroll } = require("%ui/components/scrollbar.nut")

let ROW_HEIGHT = commonBtnHeight
let ADDITIONAL_ICON_SIZE = ROW_HEIGHT * 0.6
let MAX_NAME_LEN = 30

let waitingSpinner = {
  rendObj = ROBJ_SOLID
  size = [flex(), ROW_HEIGHT]
  vplace = ALIGN_CENTER
  color = squadElemsBgColor
  children = spinner(commonBtnHeight/2)
}

let selectedRenameSlot = Watched(-1)
let renameTextWatch = Watched("")
let isWaitingObsceneFilterForIdx = Watched(-1)


let presetsListWatch = Computed(function() {
  if (!squadsArmy.value)
    return null

  let totalSlots = availablePresetsCount.value
  let presets = clone squadsPresetWatch.value?[squadsArmy.value] ?? []

  let presetsList = presets
    .resize(max(MAX_PRESETS_COUNT, presets.len()), null) //warning disable: -unwanted-modification
    .map(@(val, idx) idx >= totalSlots && idx < MAX_PRESETS_COUNT
      ? val == null
        ? { isPremium = true } //empty slot
        : val.__merge({ isPremium = true }) //used slot when player have prem
      : clone val
    )

  return presetsList
})

let getSlotTextColor = @(sf, isDisabled = false) sf & S_HOVER ? selectedTxtColor
  : isDisabled ? disabledTxtColor
  : defTxtColor

let getSlotBGColor = @(sf) sf & S_HOVER ? squadElemsBgHoverColor : squadElemsBgColor
let getInputColor = @(sf) sf & S_HOVER
  ? {
      backGroundColor = squadElemsBgHoverColor
      textColor = selectedTxtColor
    }
  : {
      backGroundColor = squadElemsBgColor
      textColor = defTxtColor
    }


let buttonsList = [
  {
    locId = "squads/presets/apply"
    fontIcon = "check"
    showPreset = true
    isVisible = @(_idx, presetInfo) presetInfo != null
    action = @(idx, _presetInfo) applySquadsPreset(squadsArmy.value, idx)
  }
  {
    locId = "squads/presets/save"
    fontIcon = "floppy-o"
    action = function(idx, presetInfo) {
      let squadIds = chosenSquads.value
        .map(@(squadBlock) squadBlock?.squadId)
        .filter(@(v) v != null)
      if (presetInfo == null)
        createSquadsPreset(squadsArmy.value, idx, squadIds)
      else
        updateSquadsPreset(squadsArmy.value, idx, squadIds)
    }
    skipForOldPresets = true
  }
  {
    locId = "squads/presets/rename"
    fontIcon = "pencil"
    isVisible = @(_idx, presetInfo) presetInfo != null
    action = function(idx, _presetInfo) {
      if (selectedRenameSlot.value == idx)
        selectedRenameSlot(-1)
      else
        selectedRenameSlot(idx)
    }
    skipForOldPresets = true
  }
  {
    locId = "squads/presets/delete"
    fontIcon = "remove"
    isVisible = @(_idx, presetInfo) presetInfo != null
    action = @(idx, _presetInfo) deleteSquadsPreset(squadsArmy.value, idx)
  }
]

let saveNewName = @(idx) renameSquadsPreset(squadsArmy.value, idx, renameTextWatch.value)
let resetRenameState = function() {
  renameTextWatch("")
  selectedRenameSlot(-1)
}

function filterAndSetPreset(presetToSet, idx) {
  if (isWaitingObsceneFilterForIdx.value >= 0)
    return
  isWaitingObsceneFilterForIdx(idx)
  obsceneFilter(presetToSet, function(filteredPresetName) {
    isWaitingObsceneFilterForIdx(-1)
    if (filteredPresetName != presetToSet) {
      return popupsState.addPopup({
        id = "prohibited_presetName"
        text = loc("prohibitedPresetname")
        styleName = "error"
      })
    }
    saveNewName(idx)
  })
}

let renameButtonsList = [{
  locId = "squads/presets/apply"
  fontIcon = "check"
  action = function(idx, presetInfo) {
    filterAndSetPreset(presetInfo.name, idx)
    resetRenameState()
  }
}]


let switchPresetOnHover = function(on, presetInfo) {
  if (!on || presetInfo?.preset == null) {
    previewSquads(null)
    return
  }

  let squads = getUnlockedSquadsBySquadIds(presetInfo.preset)
  if (squads.len() < maxSquadsInBattle.value)
    squads.resize(maxSquadsInBattle.value, null)
  previewSquads(squads)
}

let actionButton = @(action, idx, presetInfo) (action?.isVisible(idx, presetInfo) ?? true)
  ? FAButton(action.fontIcon, @() action.action(idx, presetInfo), {
      size = [ROW_HEIGHT, ROW_HEIGHT]
      hplace = ALIGN_CENTER
      onHover = function(on) {
        setTooltip(on ? loc(action.locId) : null)
        if (action?.showPreset)
          switchPresetOnHover(on, presetInfo)
      }
      hint = {
        rendObj = ROBJ_TEXTAREA
        behavior = Behaviors.TextArea
        text = loc(action.locId)
      }.__update(fontBody)
    })
  : null


let getDefaultPresetSlotName = @(presetInfo) !presetInfo?.name
  ? loc("squads/presets/empty")
  : presetInfo?.campaign ? loc("squads/presets/united",
      { campaign = loc($"{presetInfo.campaign}/full"), name = presetInfo.name })
  : presetInfo.name

let mkInputBlock = @(idx, presetInfo) watchElemState(@(sf) {
  size = [flex(), ROW_HEIGHT]
  flow = FLOW_HORIZONTAL
  valign = ALIGN_BOTTOM
  rendObj = ROBJ_BOX
  behavior = Behaviors.Button
  fillColor = getSlotBGColor(sf)
  onHover = @(on) switchPresetOnHover(on, presetInfo)
  children = [textInput.Underlined(renameTextWatch, {
      size = [flex(), ROW_HEIGHT]
      padding = [0, 0, 0, midPadding]
      margin = 0
      textmargin = 0
      placeholderTextMargin = 0
      valignText = ALIGN_CENTER
      placeholder = getDefaultPresetSlotName(presetInfo)
      maxChars = MAX_NAME_LEN
      colors = getInputColor(sf)
      onHover = @(on) switchPresetOnHover(on, presetInfo)
      onEscape = resetRenameState
      onReturn = function() {
        filterAndSetPreset(renameTextWatch.value, idx)
        resetRenameState()
      }
      onChange = @(val) renameTextWatch(val)
      onAttach = @() renameTextWatch(getDefaultPresetSlotName(presetInfo))
      onImeFinish = function(applied) {
        if (!applied)
          return

        filterAndSetPreset(renameTextWatch.value, idx)
        resetRenameState()
      }
      xmbNode = XmbNode()
    }.__update(fontBody))
  ].extend(renameButtonsList.map(@(action) actionButton(action, idx, presetInfo)))
})

function mkPresetSlot(idx, presetInfo = null) {
  let isRenaming = Computed(@() selectedRenameSlot.value == idx)
  let isWaiting = Computed(@() isWaitingObsceneFilterForIdx.value == idx)
  return @() {
    watch = [isRenaming, isWaiting]
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    rendObj = ROBJ_BOX
    behavior = Behaviors.Button
    children = isWaiting.value ? waitingSpinner
      : isRenaming.value ? mkInputBlock(idx, presetInfo)
      : watchElemState(@(sf) {
          size = [flex(), ROW_HEIGHT]
          flow = FLOW_HORIZONTAL
          rendObj = ROBJ_BOX
          behavior = Behaviors.Button
          fillColor = getSlotBGColor(sf)
          children = [
            {
              size = flex()
              padding = [0, 0, 0, midPadding]
              behavior = [Behaviors.Button, Behaviors.Marquee]
              onHover = @(on) switchPresetOnHover(on, presetInfo)
              onDoubleClick = @() applySquadsPreset(squadsArmy.value, idx)
              sound = stateChangeSounds
              valign = ALIGN_CENTER
              rendObj = ROBJ_TEXT
              text = getDefaultPresetSlotName(presetInfo)
              color = getSlotTextColor(sf)
              scrollOnHover = true
            }.__update(fontBody)
          ].extend(sf & S_HOVER
            ? buttonsList.map(@(action) idx >= MAX_PRESETS_COUNT && action?.skipForOldPresets ? null
                : actionButton(action, idx, presetInfo))
            : [])
        })
  }
}


let mkPremiumPresetSlot = @(presetInfo) watchElemState(@(sf) {
  behavior = Behaviors.Button
  rendObj = ROBJ_BOX
  fillColor = getSlotBGColor(sf)
  onClick = premiumWnd
  size = [flex(), ROW_HEIGHT]
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  sound = buttonSound
  onHover = @(on) switchPresetOnHover(on, presetInfo)
  children = [
    {
      size = [SIZE_TO_CONTENT, flex()]
      padding = [0, midPadding, 0, midPadding]
      valign = ALIGN_CENTER
      rendObj = ROBJ_TEXT
      text = getDefaultPresetSlotName(presetInfo)
      color = getSlotTextColor(sf, true)
    }.__update(fontBody)
    premiumImage(ADDITIONAL_ICON_SIZE, { color = sf & S_HOVER ? titleTxtColor : defTxtColor  })
  ]
})

let WND_UID = "squadsPresetsViewOld"
let close = function() {
  if (selectedRenameSlot.value >= 0)
    selectedRenameSlot(-1)
  else
    modalPopupWnd.remove(WND_UID)
}

let presetsListContent = @() {
  watch = presetsListWatch
  rendObj = ROBJ_BOX
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  fillColor = darkPanelBgColor
  children = presetsListWatch.value.map(function(item, idx) {
    if (item?.isPremium)
      return mkPremiumPresetSlot(item)

    return mkPresetSlot(idx, item)
  })
}

return {
  open = function(event) {
    let presetsAmount = Computed(@() presetsListWatch.value?.len())
    return modalPopupWnd.add([event.targetRect.r + midPadding, 0], {
      uid = WND_UID
      popupHalign = ALIGN_LEFT
      popupValign = ALIGN_TOP
      popupFlow = FLOW_VERTICAL
      moveDuration = min(0.12 + 0.03 * MAX_PRESETS_COUNT, 0.3)
      padding = 0
      rendObj = null
      size = [hdpx(600), sh(85)]
      valign = ALIGN_BOTTOM
      children = @() {
        watch = presetsAmount
        size = [hdpx(600), min(calc_comp_size(presetsListContent)[1], sh(80))]
        children = makeVertScroll(presetsListContent, {
          maxHeight = sh(80)
        })
      }
      hotkeys = [[$"^{JB.B} | Esc", { action = close }]]
    })
  }
}