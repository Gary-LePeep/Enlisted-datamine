from "%enlSqGlob/ui/ui_library.nut" import *

let { fontawesome } = require("%enlSqGlob/ui/fontsStyle.nut")
let { rowHeight, defInputStyle, hoverInputStyle, textState, bgState, innerBtnStyle, closeBtnStyle
} = require("equipDesign.nut")
let { leftAppearanceAnim, defSlotBgColor, commonBtnHeight, panelBgColor
} = require("%enlSqGlob/ui/designConst.nut")

let { getRomanNumeral } = require("%sqstd/math.nut")
let { setTooltip } = require("%ui/style/cursors.nut")
let { FAButton, Flat } = require("%ui/components/txtButton.nut")
let { premiumImage } = require("%enlist/currency/premiumComp.nut")
let tooltipCtor = require("%ui/style/tooltipCtor.nut")
let { stateChangeSounds } = require("%ui/style/sounds.nut")
let { showNotFoundMsg } = require("%enlist/preset/notFoundMsg.nut")

let { addPopup } = require("%enlSqGlob/ui/popup/popupsState.nut")
let { curSoldierInfo } = require("%enlist/soldiers/model/curSoldiersState.nut")
let { presetEquipList, notFoundPresetItems, applyEquipmentPreset, saveEquipmentPreset,
  filterAndRenamePreset, PreviewState, PresetTarget, isWaitingObsceneFilterForIdx
} = require("%enlist/preset/presetEquipUtils.nut")
let fa = require("%ui/components/fontawesome.map.nut")
let JB = require("%ui/control/gui_buttons.nut")

let { isGamepad } = require("%ui/control/active_controls.nut")
let textInput = require("%ui/components/textInput.nut")
let spinner = require("%ui/components/spinner.nut")
let { makeVertScroll } = require("%ui/components/scrollbar.nut")
let premiumWnd = require("%enlist/currency/premiumWnd.nut")

let MAX_NAME_LEN = 20

let frameColors = {
  [PreviewState.OK] = Color(20,255,10),
  [PreviewState.ERROR] = Color(255,150,150),
  [PreviewState.NONE] = null
}

let waitingSpinner = {
  rendObj = ROBJ_SOLID
  size = [flex(), rowHeight]
  vplace = ALIGN_CENTER
  color = panelBgColor
  children = spinner(commonBtnHeight/2)
}

let previewHighlightColor = @(previewState) frameColors[previewState ?? PreviewState.NONE]

let applyPresetTarget = Watched("soldier")
let previewPreset = Watched(null)

let processResult = @(text) addPopup({
  id = "preset_equip"
  text
})

function presetAction(presetCfg, presetTarget) {
  if (presetCfg?.isLockedPrem) {
    premiumWnd()
    return
  }

  if (presetCfg?.onClick != null) {
    presetCfg.onClick()
    return
  }

  if (presetCfg?.fnApply == null) {
    return
  }

  if (presetTarget != PresetTarget.SOLDIER) {
    processResult("[applyEquipmentPreset] not implemented")
    return
  }

  if (notFoundPresetItems.value.len() > 0)
    showNotFoundMsg(notFoundPresetItems.value, @() applyEquipmentPreset(presetCfg, presetTarget))
  else
    applyEquipmentPreset(presetCfg, presetTarget)
}

let actionBtn = @(icon, action, hint, onHover = null) FAButton(icon, action, {
  btnWidth = rowHeight
  btnHeight = rowHeight
  onHover = function(on) {
    if (onHover != null)
      onHover(on)
    setTooltip(!on ? null : tooltipCtor({ rendObj = ROBJ_TEXT, text = hint }))
  }
}.__update(innerBtnStyle))

let btnSavePreset = @(presetCfg) presetCfg?.fnSave == null ? null
  : actionBtn("save",
      function() {
        saveEquipmentPreset(presetCfg)
        processResult(loc("preset/equip/saved"))
      },
      loc("squads/presets/save"))

let btnApplyPreset = @(presetCfg, presetTarget)
  ((presetCfg?.isLockedPrem ?? false) || presetCfg?.fnApply == null) ? null
    : actionBtn("check",
        @() presetAction(presetCfg, presetTarget),
        loc("squads/presets/apply"),
        @(on) previewPreset(on ? presetCfg : null))


function mkPresetButtons(presetCfg, presetTarget) {
  let buttons = []
  for (local i=1; i<=5; i++) {
    let name = getRomanNumeral(i)
    let text = loc("squads/presets/applyBR", { BR = name })
    let config = presetCfg.__merge({ maxBR = i })
    buttons.append(
      Flat(name, @() presetAction(config, presetTarget), {
        btnWidth = rowHeight
        btnHeight = rowHeight
        onHover = function(on) {
          previewPreset(on ? config : null)
          setTooltip(!on ? null : tooltipCtor({ rendObj = ROBJ_TEXT, text }))
        }
      }.__update(innerBtnStyle)))
  }
  return buttons
}

let selectedRenameSlot = Watched(-1)
let renameTextWatch = Watched("")

let btnRenamePreset = @(presetCfg, idx, textWatch) presetCfg?.fnRename == null ? null
  : actionBtn("pencil",
      function() {
        textWatch(presetCfg.locId)
        selectedRenameSlot(idx)
      },
      loc("squads/presets/rename"))

let btnDeletePreset = @(presetCfg, _idx) presetCfg?.fnDelete == null ? null
  : actionBtn("remove",
      @() presetCfg.fnDelete(curSoldierInfo.value),
      loc("squads/presets/delete"))

let stopRenameAction = function() {
  renameTextWatch("")
  selectedRenameSlot(-1)
}

let mkRenameSlot = function(presetCfg, textWatch, idx) {
  let applyRename = function() {
    filterAndRenamePreset(presetCfg, textWatch.value, idx)
    stopRenameAction()
  }
  return watchElemState(@(sf) {
    size = [flex(), rowHeight]
    flow = FLOW_HORIZONTAL
    valign = ALIGN_BOTTOM
    rendObj = ROBJ_BOX
    behavior = Behaviors.Button
    onHover = @(on) previewPreset(on ? presetCfg : null)
    children = [
      textInput.Underlined(textWatch, {
        size = [flex(), rowHeight]
        margin = 0
        textmargin = 0
        placeholderTextMargin = 0
        valignText = ALIGN_CENTER
        placeholder = presetCfg.locId
        maxChars = MAX_NAME_LEN
        onEscape = stopRenameAction
        onReturn = applyRename
        onChange = @(val) textWatch(val)
        onAttach = @(elem) set_kb_focus(elem)
        onImeFinish = function(applied) {
          if (!applied)
            return
          applyRename()
        }
      }.__update(sf & S_HOVER ? hoverInputStyle : defInputStyle))
      actionBtn("check", applyRename, loc("squads/presets/apply"))
    ]
  }.__update(bgState(sf, false)))
}

function mkPresetSlot(presetCfg, presetTarget, idx) {
  let { hasBRButtons = false } = presetCfg
  let buttons = {
    flow = FLOW_HORIZONTAL
    children = hasBRButtons
      ? mkPresetButtons(presetCfg, presetTarget)
      : [
          btnApplyPreset(presetCfg, presetTarget)
          btnRenamePreset(presetCfg, idx, renameTextWatch)
          btnDeletePreset(presetCfg, idx)
          btnSavePreset(presetCfg)
        ]
  }
  return watchElemState(@(sf) {
    size = [flex(), rowHeight]
    flow = FLOW_HORIZONTAL
    rendObj = ROBJ_BOX
    behavior = Behaviors.Button
    key = $"equipPreset{idx}"
    children = [
      {
        size = flex()
        behavior = Behaviors.Button
        onHover = @(on) previewPreset(on ? presetCfg : null)
        onClick = @() presetAction(presetCfg, presetTarget)
        sound = stateChangeSounds
        flow = FLOW_HORIZONTAL
        children = [
          {
            rendObj = ROBJ_TEXT
            size = flex()
            valign = ALIGN_CENTER
            behavior = Behaviors.Marquee
            text = presetCfg.locId
            scrollOnHover = true
          }.__update(textState(sf, presetCfg?.isLockedPrem ?? false))
          presetCfg?.isLockedPrem ? premiumImage(rowHeight * 0.7, { pos = [0, hdpx(7)]}) : null
        ]
      }
      hasBRButtons || (sf & S_HOVER) ? buttons : null
    ]
  }.__update(bgState(sf, presetCfg?.isLockedPrem ?? false)))
}

function makePresetList(presetCfgList, presetTarget) {
  let presetList = presetCfgList.map(function(presetCfg, idx) {
    let isRenaming = Computed(@() selectedRenameSlot.value == idx)
    let isWaiting = Computed(@() isWaitingObsceneFilterForIdx.value == idx)
    return @() {
      watch = [isRenaming, isWaiting]
      size = [flex(), SIZE_TO_CONTENT]
      children = isWaiting.value ? waitingSpinner
        : isRenaming.value ? mkRenameSlot(presetCfg, renameTextWatch, idx)
        : mkPresetSlot(presetCfg, presetTarget, idx)
    }
  })
  return presetList
}

let presetEquipOpened = Watched(false)

let closeBtn = {
  rendObj = ROBJ_TEXT
  vplace = ALIGN_TOP
  hplace = ALIGN_RIGHT
  behavior = Behaviors.Button
  text = fa["close"]
  font = fontawesome.font
  hotkeys = [[ $"^{JB.B} | Esc" ]]
  onClick = @() presetEquipOpened(false)
}.__update(closeBtnStyle)

let presetsListContent = @() {
  watch = [presetEquipList, applyPresetTarget]
  flow = FLOW_VERTICAL
  size = [flex(), SIZE_TO_CONTENT]
  children = makePresetList(presetEquipList.value, applyPresetTarget.value)
}

let presetEquipButtons = {
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  size = flex()
  children = makeVertScroll(presetsListContent)
  onAttach = function() {
    if (isGamepad.value)
      move_mouse_cursor("equipPreset0")
  }
}

let presetBlock = @() {
  watch = [presetEquipOpened, curSoldierInfo]
  size = [SIZE_TO_CONTENT, flex()]
  children = curSoldierInfo.value != null && presetEquipOpened.value ? {
    flow = FLOW_VERTICAL
    size = [hdpxi(415), flex()]
    children = [
      {
        rendObj = ROBJ_BOX
        size = [flex(), SIZE_TO_CONTENT]
        fillColor = defSlotBgColor
        children = closeBtn
      }
      presetEquipButtons
    ]
    key = "__anim_preset"
  }.__update(leftAppearanceAnim(0)) : null
}

let mkPresetEquipBlock = function() {
  defer(@() presetEquipOpened(false))
  return presetBlock
}

let togglePresetEquipBlock = @() presetEquipOpened(!presetEquipOpened.value)

return {
  closeEquipPresets = @() presetEquipOpened(false)
  togglePresetEquipBlock
  mkPresetEquipBlock
  previewPreset
  previewHighlightColor
}
