from "%enlSqGlob/ui_library.nut" import *
from "%enlist/gameModes/createEventRoomState.nut" import *

let JB = require("%ui/control/gui_buttons.nut")
let tooltipBox = require("%ui/style/tooltipBox.nut")
let getMissionInfo = require("%enlist/gameModes/getMissionInfo.nut")
let textButton = require("%ui/components/textButton.nut")
let { fontSub, fontBody, fontTitle } = require("%enlSqGlob/ui/fontsStyle.nut")
let { settings, onlineSettingUpdated } = require("%enlist/options/onlineSettings.nut")
let { setTooltip } = require("%ui/style/cursors.nut")
let { addModalWindow, removeModalWindow } = require("%ui/components/modalWindows.nut")
let { tinyOffset, smallOffset, smallPadding, defInsideBgColor,
  activeBgColor, idleBgColor, defBgColor, defTxtColor, titleTxtColor
} = require("%enlSqGlob/ui/viewConst.nut")
let { mkArmySimpleIcon } = require("%enlist/soldiers/components/armyPackage.nut")
let { show } = require("%ui/components/msgbox.nut")
let { isEventModesOpened } = require("%enlist/gameModes/eventModesState.nut")

const MAX_MISSIONS = 6

let baseOptions = [
  optIsPrivate
  optMode
  optDifficulty
  optMaxPlayers
  optBotCount
  optVoteToKick
  optCluster
  optCrossplay
  optArmiesA
  optArmiesB
  optMissions
]

const WND_UID = "saveChooseLobbySettingsWnd"
const SLOTS_COUNT = 5
const PRESETS_ID = "mpRoom/presets"

let slotSize = [hdpx(140), hdpx(140)]
let slotColor = @(sf) sf & S_HOVER ? activeBgColor : idleBgColor

let lobbyPresets = Computed(@() settings.value?[PRESETS_ID])
let function removePresets() {
  if (PRESETS_ID in settings.value)
    settings.mutate(@(v) delete v[PRESETS_ID])
  show({ text = loc("lobby/presetsRenew") })
}

isEventModesOpened.subscribe(function(opened) {
  if (!opened || !onlineSettingUpdated.value)
    return
  let needToRenewPresets = (settings.value?[PRESETS_ID] ?? [])
    .findvalue(@(preset) optArmiesA.id not in preset) != null
  if (needToRenewPresets)
    removePresets()
})

let separator = { size = [flex(), tinyOffset] }

let mkParamName = @(txt) {
  rendObj = ROBJ_TEXT
  color = defTxtColor
  text = txt
}.__update(fontSub)

let mkParamVal = @(txt) {
  rendObj = ROBJ_TEXT
  hplace = ALIGN_RIGHT
  color = titleTxtColor
  text = txt
}.__update(fontSub)

let mkParamList = @(list, bottomTxt = null) {
  rendObj = ROBJ_TEXTAREA
  size = [flex(), SIZE_TO_CONTENT]
  behavior = Behaviors.TextArea
  halign = ALIGN_RIGHT
  color = titleTxtColor
  text = bottomTxt == null ? list : "{0}\n{1}".subst(list, bottomTxt)
}

let function savePreset(idx) {
  let res = {}
  foreach (opt in baseOptions)
    res[opt.id] <- opt.curValue.value
  settings.mutate(function(set) {
    let saved = clone (set?[PRESETS_ID] ?? {})
    saved[idx.tostring()] <- res
    set[PRESETS_ID] <- saved
  })
  removeModalWindow(WND_UID)
}

let function choosePreset(idx) {
  let preset = lobbyPresets.value?[idx.tostring()] ?? {}
  foreach (opt in baseOptions) {
    let { id } = opt
    if (id in preset)
      opt.setValue(preset[id])
  }
  removeModalWindow(WND_UID)
}

let function mkBaseOptRow(opt, preset) {
  let { id, cfg, valToString } = opt
  let val = preset?[id]
  return val == null ? null
    : @() {
        watch = cfg
        size = [flex(), SIZE_TO_CONTENT]
        children = [
          mkParamName(loc(cfg.value.locId))
          mkParamVal(valToString(val))
        ]
      }
}

let function mkArmiesList(opt, preset) {
  let { id, cfg } = opt
  let val = clone preset?[id]
  let armiesToShow = val.sort(@(a, b) a <=> b)
  return @() {
    watch = cfg
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    gap = { size = flex() }
    valign = ALIGN_CENTER
    children = [
      mkParamName(loc(cfg.value.locId))
      armiesToShow.len() == 0
        ? mkParamVal(loc("option/all"))
        : {
            flow = FLOW_HORIZONTAL
            gap = smallPadding
            children = armiesToShow.map(@(c) mkArmySimpleIcon(c, fontSub.fontSize))
          }
    ]
  }
}

let mkMissionText = function(m) {
  let mCfg = getMissionInfo(m)
  let mName = loc(mCfg.locId)
  let mTypeLocId = mCfg.typeLocId
  return mTypeLocId == null ? mName
    : loc("missionNameWithType", { mName, mType = loc(mTypeLocId) })
}

let function mkMissionList(list) {
  let { cfg } = optMissions
  let visList = list.len() <= MAX_MISSIONS ? list
    : list.slice(0, MAX_MISSIONS)
  let bottomTxt = list.len() <= MAX_MISSIONS ? null
    : loc("options/andMore", { count = list.len() - MAX_MISSIONS })
  return @() {
    watch = cfg
    size = [flex(), SIZE_TO_CONTENT]
    children = [
      mkParamName(loc(cfg.value.locId))
      list.len() == 0
        ? mkParamVal(loc("option/all"))
        : mkParamList("\n".join(visList.map(@(m) mkMissionText(m))), bottomTxt)
    ]
  }
}

let mkPresetInfo = @(preset, bottomTxt) {
  size = [hdpx(550), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  children = (preset == null ? [] // -unwanted-modification
    : [
        mkParamName(loc("lobbyPresetHeader")).__update(fontBody)
        separator
        mkBaseOptRow(optMode, preset)
        mkBaseOptRow(optDifficulty, preset)
        mkBaseOptRow(optMaxPlayers, preset)
        mkBaseOptRow(optBotCount, preset)
        mkBaseOptRow(optCluster, preset)
        separator
        mkArmiesList(optArmiesA, preset)
        mkArmiesList(optArmiesB, preset)
        mkMissionList(preset?[optMissions.id] ?? [])
        separator
        separator
      ]).append({
          rendObj = ROBJ_TEXTAREA
          size = [flex(), SIZE_TO_CONTENT]
          behavior = Behaviors.TextArea
          color = titleTxtColor
          text = bottomTxt
        }.__update(fontBody))
}

let function mkPresetSlot(curPresets, idx, onClick, bottomTxt) {
  let slotId = idx.tostring()
  let preset = curPresets?[slotId]
  return watchElemState(@(sf) {
    rendObj = ROBJ_BOX
    size = slotSize
    borderWidth = hdpx(1)
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    fillColor = defBgColor
    borderColor = slotColor(sf)
    behavior = Behaviors.Button
    onHover = @(on) setTooltip(on ? tooltipBox(mkPresetInfo(preset, bottomTxt)) : null)
    onClick
    children = {
      rendObj = ROBJ_TEXT
      text = preset == null ? loc("presetEmpty") : (idx + 1).tostring()
      color = slotColor(sf)
    }.__update(preset == null ? fontSub : fontTitle)
  })
}

let windowParams = {
  key = WND_UID
  rendObj = ROBJ_WORLD_BLUR_PANEL
  fillColor = defInsideBgColor
  size = flex()
  flow = FLOW_VERTICAL
  gap = smallOffset
  valign = ALIGN_CENTER
  halign = ALIGN_CENTER
  onClick = @() null
}

let closeButton = textButton(loc("Cancel"), @() removeModalWindow(WND_UID), {
  hplace = ALIGN_CENTER
  hotkeys = [[$"^{JB.B} | Esc"]]
})

let openSaveWindow = @() addModalWindow({
  children = [
    mkParamVal(loc("header/saveLobbyPreset"))
      .__update(fontBody, { hplace = ALIGN_CENTER })
    function() {
      let curPresets = lobbyPresets.value
      let curSlotsCount = (curPresets ?? []).len()
      return {
        watch = lobbyPresets
        flow = FLOW_HORIZONTAL
        gap = smallPadding
        children = array(min(curSlotsCount + 1, SLOTS_COUNT))
          .map(function(_, idx) {
            let bottomTxt = loc("clickToSavePreset", {
              presetName = (idx + 1).tostring()
            })
            return mkPresetSlot(curPresets, idx, @() savePreset(idx), bottomTxt)
          })
      }
    }
    closeButton
  ]
}.__update(windowParams))

let openChooseWindow = @() addModalWindow({
  children = [
    mkParamVal(loc("header/chooseLobbyPreset"))
      .__update(fontBody, { hplace = ALIGN_CENTER })
    function() {
      let curPresets = lobbyPresets.value
      let curSlotsCount = (curPresets ?? []).len()
      return {
        watch = lobbyPresets
        flow = FLOW_HORIZONTAL
        gap = smallPadding
        children = array(curSlotsCount)
          .map(function(_, idx) {
            let bottomTxt = loc("clickToChoosePreset", {
              presetName = (idx + 1).tostring()
            })
            return mkPresetSlot(curPresets, idx, @() choosePreset(idx), bottomTxt)
          })
      }
    }
    closeButton
  ]
}.__update(windowParams))

console_register_command(@() settings
  .mutate(@(s) delete s[PRESETS_ID]), "meta.resetLobbyPresets")

return {
  openSaveWindow
  openChooseWindow
  lobbyPresets
}