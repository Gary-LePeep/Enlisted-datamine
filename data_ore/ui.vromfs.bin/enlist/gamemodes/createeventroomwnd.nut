from "%enlSqGlob/ui_library.nut" import *
from "createEventRoomState.nut" import *

let { fontSub, fontBody, fontHeading2 } = require("%enlSqGlob/ui/fontsStyle.nut")
let { logerr } = require("dagor.debug")
let { blurBgColor, defInsideBgColor, blurBgFillColor, smallOffset, isWide
} = require("%enlSqGlob/ui/viewConst.nut")
let { bigPadding, defTxtColor, smallPadding, titleTxtColor, brightAccentColor, darkTxtColor,
  midPadding, maxContentWidth, selectedPanelBgColor
  } = require("%enlSqGlob/ui/designConst.nut")
let { chooseRandom } = require("%sqstd/rand.nut")
let {addModalWindow, removeModalWindow} = require("%ui/components/modalWindows.nut")
let closeBtn = require("%ui/components/closeBtn.nut")
let textInput = require("%ui/components/textInput.nut")
let spinnerList = require("%ui/components/spinnerList.nut")
let { mkWindowHeader, txtColor, teamsColors, armyIconSize
} = require("%enlist/gameModes/eventModesPkg.nut")
let { Bordered, Flat } = require("%ui/components/txtButton.nut")
let spinner = require("%ui/components/spinner.nut")
let { localGap, localPadding, rowHeight } = require("eventModeStyle.nut")
let mkOptionRow = require("components/mkOptionRow.nut")
let mkWindowTab = require("%enlist/components/mkWindowTab.nut")
let { makeVertScroll, thinStyle } = require("%ui/components/scrollbar.nut")
let {sound_play} = require("%dngscripts/sound_system.nut")
let faComp = require("%ui/components/faComp.nut")
let { getImagesFromMissions, typeToLocId, missionTypes, MissionType
} = require("%enlSqGlob/ui/missionsPresentation.nut")
let getMissionInfo = require("getMissionInfo.nut")
let { setTooltip } = require("%ui/style/cursors.nut")
let tooltipBox = require("%ui/style/tooltipBox.nut")
let { isGamepad } = require("%ui/control/active_controls.nut")
let { mkHotkey } = require("%ui/components/uiHotkeysHint.nut")
let { lobbyPresets, openSaveWindow, openChooseWindow
} = require("%enlist/mpRoom/saveChooseLobbySettings.nut")
let { modPath, receivedModInfos, isModAvailable } = require("sandbox/customMissionState.nut")
let openCustomMissionWnd = require("sandbox/customMissionWnd.nut")
let { isXboxOne, isPS4, is_console } = require("%dngscripts/platform.nut")
let msgbox = require("%enlist/components/msgbox.nut")
let { premiumImage } = require("%enlist/currency/premiumComp.nut")
let premiumWnd = require("%enlist/currency/premiumWnd.nut")
let { mkArmyIcon } = require("%enlist/soldiers/components/armyPackage.nut")

enum TabsIds {
  EVENT_ID
  ARMY_ID
  MISSION_ID
}

let teams = [
  {
    teamLocId = "teamA"
    armyOpt = optArmiesA
    index = 0
  }
  {
    teamLocId = "teamB"
    armyOpt = optArmiesB
    index = 1
  }
]

let armyImages = freeze({
  ussr = "ui/soldiers/ussr/squad_ussr_mgun_3_image.avif"
  ger = "ui/soldiers/germany/axis_stalingrad_assault_2_image.avif"
  usa = "ui/soldiers/usa/allies_pacific_assault_2_image.avif"
  jap = "ui/soldiers/japan/axis_pacific_assault_3_image.avif"
})

const WND_UID = "editEventGm"
let CARDS_PER_ROW = isWide ? 3 : 2
let ARMIES_PER_ROW = 4
let ARMIES_ITEMS_ROW = 2
let IMAGE_RATIO = isWide ? 16.0 / 9.0 : 4.0 / 3.0
let contentHeight = hdpxi(650)
let infoRowsToShow = 3
let wndWidth = min(maxContentWidth, sw(95))
let campaignsBlockWidth = hdpx(456)
let contentWidth = wndWidth - campaignsBlockWidth - localPadding * 3
let armyContentWidth = wndWidth - localPadding * 2
let missionsCardWidth = ((contentWidth - localPadding * (CARDS_PER_ROW - 1))
  / CARDS_PER_ROW).tointeger()
let armyCardWidth = ((armyContentWidth - localPadding * (ARMIES_PER_ROW - 1))
  / ARMIES_PER_ROW).tointeger()
let missionsBlockHeight = hdpxi(500)
let missionsCardHeight = hdpxi(234)
let missionImageSize = [missionsCardWidth, missionsCardHeight / 2]
let armyImageSize = [armyCardWidth, (armyCardWidth / IMAGE_RATIO).tointeger()]
let waitingSpinner = spinner()

let prevGenPlatform = isXboxOne ? "xbox"
  : isPS4 ? "sony"
  : null

let curTabIdx = mkWatched(persist, "curTabIdx", 0)
let selectedMissionType = Watched(MissionType.INVASION)

let function selectAll() {
  optArmiesA.setValue(optArmiesA.cfg.value.values)
  optArmiesB.setValue(optArmiesB.cfg.value.values)
}
let function unselectAll() {
  optArmiesA.setValue([])
  optArmiesB.setValue([])
}

let activeTabIds = Computed(function() {
  let tabs = [TabsIds.EVENT_ID]
  if (modPath.value == "" && !isInRoom.value) {
    tabs.append(TabsIds.ARMY_ID)
    tabs.append(TabsIds.MISSION_ID)
  }
  return tabs
})

activeTabIds.subscribe(function(v) {
  if (curTabIdx.value >= v.len())
    curTabIdx(0)
})

let baseOptions = [
  optIsPrivate
  optMode
  optDifficulty
  optMaxPlayers
  optBotCount
  optCampaigns
  optCluster
  optCrossplay
  optPassword
]

let function curTabById(id) {
  let idx = activeTabIds.value.indexof(id)
  if (idx != null)
    curTabIdx(idx)
}

let armiesInfoBlocks = [
  {
    option = optArmiesA
    onClick = @() curTabById(TabsIds.ARMY_ID)
  }
  {
    option = optArmiesB
    onClick = @() curTabById(TabsIds.ARMY_ID)
  }
]


let close = @() isEditEventRoomOpened(false)

let locOn = loc($"option/on")
let locOff = loc($"option/off")
let defBoolToString = @(val) val ? locOn : locOff
let mkValueText = @(curValue, valToString, overrideText = null) @() {
  watch = curValue
  rendObj = ROBJ_TEXT
  color = defTxtColor
  text = overrideText ?? valToString?(curValue.value) ?? curValue.value
}.__update(fontBody)

let optionCtor = {
  [OPT_LIST] = @(opt, cfg, isInactive = false) (cfg.values.len() <= 1 || isInactive)
    ? mkValueText(opt.curValue, opt?.valToString)
    : spinnerList({
        curValue = opt.curValue, setValue = opt.setValue, allValues = cfg.values,
        valToString = opt?.valToString
      }),

  [OPT_CHECKBOX] = @(opt, cfg, isInactive = false) (cfg.values.len() <= 1 || isInactive)
    ? mkValueText(opt.curValue, opt?.valToString ?? defBoolToString)
    : spinnerList({
        curValue = opt.curValue, setValue = opt.setValue, allValues = cfg.values
        valToString = opt?.valToString ?? defBoolToString
      }),

  [OPT_EDITBOX] = @(opt, cfg, isInactive = false) isInactive
    ? mkValueText(opt.curValue, @(v) v, opt?.optDummy)
    : textInput(opt?.savedValue ?? opt.curValue,
      { maxChars = cfg?.maxChars, placeholder = opt?.placeholder, setValue = opt.setValue,
        textmargin = [hdpx(6), hdpx(2)], password = opt?.password, charMaskTypes = opt?.charMaskTypes})
}

let optionRequirement = mkOptionRow(
  loc("password/req"),
  premiumImage(hdpx(40)), { valign = ALIGN_CENTER },
  premiumWnd)

let mkOption = @(option) function () {
  let res = { watch = [option.cfg] }
  let cfg = option.cfg.value
  if (cfg == null)
    return res

  let { isEditAllowed = true } = option
  let { optType, locId = null, isHidden = false } = cfg
  let hintText = loc($"{locId}/hint", "")

  return {
    watch = [option.cfg, isInRoom]
    size = [ flex(), SIZE_TO_CONTENT]
    children = isHidden ? optionRequirement
      : mkOptionRow(locId, {
          size = [ pw(40), flex() ]
          valign = ALIGN_CENTER
          children = optionCtor?[optType](option, cfg, (isInRoom.value && !isEditAllowed))
        }, {
          onHover = hintText == "" ? null
            : @(on) setTooltip(on ? tooltipBox({
                rendObj = ROBJ_TEXT
                color = defTxtColor
                text = hintText
              }.__update(fontSub)) : null)
        })
  }
}

let function mkMultiSelect(opt, cfg, ctor) {
  if (cfg == null)
    return []

  let { optType, values = [] } = cfg
  if (optType != OPT_MULTISELECT) {
    logerr($"Option {opt.id} support only multiselect mode in UI. (current option type: {optType})")
    return []
  }

  let {
    curValue, valToString = @(v) v, typeToString = @(v) v, toggleValue
  } = opt
  return values.map(@(value) ctor(
    valToString(value),
    typeToString(value),
    @(isChecked) toggleValue(value, isChecked),
    Computed(@() (curValue.value ?? []).contains(value)),
    value
  ))
}

let mkArmyImg = @(armyId) {
  rendObj = ROBJ_IMAGE
  size = armyImageSize
  keepAspect = KEEP_ASPECT_FILL
  imageHalign = ALIGN_CENTER
  imageValign = ALIGN_TOP
  image = Picture($"{armyImages[armyId]}:{armyImageSize[0]}:{armyImageSize[1]}:K")
  fallbackImage = Picture("ui/soldiers/army_default.avif")
  transitions = [ { prop = AnimProp.scale, duration = 0.4, easing = OutQuintic } ]
}

let cardTextBlock = @(label, typeTxt, sf, isSelected, params = {}) {
  rendObj = ROBJ_SOLID
  flow = FLOW_VERTICAL
  size = flex()
  halign = ALIGN_RIGHT
  color = sf & S_HOVER ? defInsideBgColor : blurBgFillColor
  padding = bigPadding
  children = [
    {
      rendObj = ROBJ_TEXTAREA
      size = flex()
      behavior = Behaviors.TextArea
      color = txtColor(sf)
      text = label
    }.__update(fontHeading2, params?.label ?? {})
    {
      size = [flex(), SIZE_TO_CONTENT]
      gap = smallPadding
      vplace = ALIGN_BOTTOM
      valign = ALIGN_CENTER
      children = [
        typeTxt == null ? null
          : {
              rendObj = ROBJ_TEXT
              color = txtColor(sf)
              text = typeTxt
            }.__update(fontBody)
        {
          size = [smallOffset, SIZE_TO_CONTENT]
          hplace = ALIGN_RIGHT
          children = isSelected.value ? faComp("check") : null
        }
      ]
    }.__update(params?.sign ?? {})
  ]
}.__update(params)

let mkArmySelectBlock = @(label, _typeTxt, setValue, isSelected, value)
  watchElemState(@(sf) {
    watch = isSelected
    key = isSelected
    size = [armyCardWidth, armyCardWidth / IMAGE_RATIO]
    behavior = Behaviors.Button
    valign = ALIGN_CENTER
    function onClick() {
      setValue(!isSelected.value)
      sound_play(isSelected.value ? "ui/enlist/flag_set" : "ui/enlist/flag_unset")
    }
    children = [
      mkArmyImg(value)
      cardTextBlock(label, null, sf, isSelected, {
        flow = FLOW_HORIZONTAL
        vplace = ALIGN_BOTTOM
        size = [flex(), SIZE_TO_CONTENT]
        minHeight = hdpx(48)
        label = { size = [flex(), SIZE_TO_CONTENT] }
        sign = { size = [SIZE_TO_CONTENT, flex()] }
      })
    ]
  })

let allertSign = {
  rendObj = ROBJ_IMAGE
  size = [hdpx(30), hdpx(25)]
  image = Picture($"ui/uiskin/attention.avif")
  margin = bigPadding
  behavior = Behaviors.Button
  hplace = ALIGN_RIGHT
  onHover = @(on) setTooltip(on ? tooltipBox({
    rendObj = ROBJ_TEXT
    color = defTxtColor
    text = loc("singleMissionAlert")
  }.__update(fontSub)) : null)
}

optMissions.curValue.subscribe(function(v) {
  if (prevGenPlatform) {
    let missionsWithAlert = []
    foreach (mission in v) {
      let { prevGenAlert = [] } = getMissionInfo(mission)
      if (prevGenAlert.contains(prevGenPlatform))
        missionsWithAlert.append(mission)
    }

    let count = missionsWithAlert.len()
    if (count > 0)
      msgbox.show({ text = count > 1
        // TODO show names of all problematic missions to tell the player how to fix it
        ? loc("manyMissionsAlert")
        : loc("singleMissionAlert")})
  }
})

let function mkMissionCard(label, typeTxt, setValue, isSelected, value) {
  let { image, prevGenAlert = [] } = getMissionInfo(value)
  let resampledImage = $"{image}:{missionImageSize[0]}:{missionImageSize[1]}:K"
  let hasPrevgen = prevGenAlert.contains(prevGenPlatform)
  return watchElemState(@(sf) {
    watch = isSelected
    size = [missionsCardWidth, missionsCardHeight]
    behavior = Behaviors.Button
    flow = FLOW_VERTICAL
    function onClick() {
      setValue(!isSelected.value)
      sound_play(isSelected.value ? "ui/enlist/flag_set" : "ui/enlist/flag_unset")
    }
    children = [
      {
        rendObj = ROBJ_IMAGE
        size = missionImageSize
        image = Picture(resampledImage)
        keepAspect = KEEP_ASPECT_FILL
        children = hasPrevgen ? allertSign : null
      }
      cardTextBlock(label, typeTxt, sf, isSelected)
    ]
  })
}

let function mkSelectArmyUi(items) {
  function renderRow() {
    let res = []
    local idx = 0
    while (idx < items.len()) {
      res.append({
        flow = FLOW_HORIZONTAL
        gap = localPadding
        children = items.slice(idx, idx + ARMIES_ITEMS_ROW)
      })
      idx += ARMIES_ITEMS_ROW
    }
    return res
  }
  return {
    size = [armyContentWidth / 2, SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = localGap
    children = renderRow()
  }
}

let mkSelectUi = @(children, cfg) {
  size = [flex(), SIZE_TO_CONTENT]
  watch = [cfg, selectedMissionType]
  children
}

let mkSelectArmy = @(options, content) function() {
  let cfg = {
    optType = OPT_MULTISELECT
    values = options.cfg.value.values
  }
  let children = mkSelectArmyUi(mkMultiSelect(options, cfg, content))

  return mkSelectUi(children, options.cfg)
}

let mkSelectMission = @(options, content, wrapP = null) function() {
  let cfg = {
    optType = OPT_MULTISELECT
    values = options.cfg.value.values.filter(function(blk) {
      let info = getMissionInfo(blk)
      return info.type == selectedMissionType.value
    })
  }

  let children = makeVertScroll({ children = wrap(mkMultiSelect(options, cfg, content), wrapP) }, {
    size = [SIZE_TO_CONTENT, missionsBlockHeight]
    styling = thinStyle
    rootBase = {
      key = "battlepassUnlocksRoot"
      behavior = Behaviors.Pannable
      wheelStep = 0.82
    }
  })

  return mkSelectUi(children, options.cfg)
}

let baseOptionsList = {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  children = baseOptions.map(mkOption)
}

let roomInfoRow = @(block) function() {
  let { option, onClick } = block
  let res = { watch = [option.cfg, option.curValue] }
  let chosenValues = []
  let currentValue = option.curValue.value
  if (option.cfg.value?.optType != OPT_MULTISELECT)
    return res

  let {values, locId} = option.cfg.value
  if (option.cfg.value.values.len() == 1)
    chosenValues.append(option.valToString(values[0]))
  else if (currentValue.len() == values.len() || currentValue.len() == 0)
    chosenValues.append(loc("options/any"))
  else {
    foreach (idx, val in currentValue) {
      if (idx >= infoRowsToShow)
        break
      chosenValues.append(option.valToString(val))
    }
    let count = currentValue.len() - infoRowsToShow
    if (count > 0)
      chosenValues.append(loc("options/andMore", { count }))
  }


  return res.__update({
    size = [flex(), SIZE_TO_CONTENT]
    margin = [smallPadding, 0]
    gap = localGap
    minHeight = rowHeight
    children = watchElemState(@(sf) {
      rendObj = ROBJ_SOLID
      color = sf & S_HOVER ? defInsideBgColor : blurBgFillColor
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      behavior = Behaviors.Button
      skipDirPadNav = true
      padding = [0, bigPadding]
      onClick
      children = [
        {
          rendObj = ROBJ_TEXT
          size = [SIZE_TO_CONTENT, rowHeight]
          text = loc(locId)
          hplace = ALIGN_CENTER
          valign = ALIGN_CENTER
          color = titleTxtColor
        }.__update(fontBody)
        {
          size = [flex(), SIZE_TO_CONTENT]
          flow = FLOW_VERTICAL
          gap = localGap
          children = chosenValues.map(@(text) {
            rendObj = ROBJ_TEXT
            size = [flex(), hdpx(40)]
            clipChildren = true
            behavior = Behaviors.Marquee
            valign = ALIGN_CENTER
            color = defTxtColor
            text
          }.__update(fontBody))
        }
      ]
    })
  })
}

let modMissionTitle = is_console ? null : watchElemState(@(sf) {
  rendObj = ROBJ_SOLID
  watch = [modPath, receivedModInfos]
  color = sf & S_HOVER ? defInsideBgColor : blurBgFillColor
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_HORIZONTAL
  behavior = Behaviors.Button
  padding = [0, bigPadding]
  valign = ALIGN_CENTER
  margin = [smallPadding, 0]
  minHeight = rowHeight
  onClick = openCustomMissionWnd
  children = modPath.value == ""
    ? {
        rendObj = ROBJ_TEXT
        text = loc("mods/noActive")
      }.__update(fontBody)
    : [
        {
          rendObj = ROBJ_TEXT
          size = [flex(), SIZE_TO_CONTENT]
          color = titleTxtColor
          text = loc("Mods")
        }.__update(fontBody)
        {
          rendObj = ROBJ_TEXT
          size = [flex(3), SIZE_TO_CONTENT]
          clipChildren = true
          behavior = Behaviors.Marquee
          color = defTxtColor
          halign = ALIGN_RIGHT
          text = receivedModInfos.value?[modPath.value].title
        }.__update(fontBody)
      ]
})

let armyInfoBlock = @(block, team) function() {
  let { option, onClick } = block
  let res = { watch = [option.cfg, option.curValue] }
  if (option.cfg.value?.optType != OPT_MULTISELECT)
    return res

  let { locId, values } = option.cfg.value
  let { defBgColor, hoverBgColor } = teamsColors[team]
  let armiesToShow = option.curValue.value.len() == 0 ? values : option.curValue.value
  return res.__update({
    size = [flex(), SIZE_TO_CONTENT]
    margin = [smallPadding, 0]
    gap = bigPadding
    children = watchElemState(@(sf) {
      rendObj = ROBJ_SOLID
      color = sf & S_HOVER ? hoverBgColor : defBgColor
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      behavior = Behaviors.Button
      skipDirPadNav = true
      padding = [0, bigPadding]
      onClick
      children = [
        {
          rendObj = ROBJ_TEXT
          size = [SIZE_TO_CONTENT, rowHeight]
          text = loc(locId)
          hplace = team == 0 ? ALIGN_LEFT : ALIGN_RIGHT
          valign = ALIGN_CENTER
          color = titleTxtColor
        }.__update(fontBody)
        {
          size = [flex(), SIZE_TO_CONTENT]
          flow = FLOW_HORIZONTAL
          gap = smallPadding
          halign = team == 0 ? ALIGN_LEFT : ALIGN_RIGHT
          children = armiesToShow.map(@(v) mkArmyIcon(v, armyIconSize))
        }
      ]
    })
  })
}

let armiesSettingsInfo = {
  flow = FLOW_HORIZONTAL
  size = [flex(), SIZE_TO_CONTENT]
  halign = ALIGN_CENTER
  borderWidth = 0
  gap = midPadding
  children = armiesInfoBlocks.map(@(v, team) armyInfoBlock(v, team))
}

let missionSettingsInfo = {
  size = [flex(), SIZE_TO_CONTENT]
  halign = ALIGN_CENTER
  borderWidth = 0
  children = roomInfoRow({
    option = optMissions
    onClick = @() curTabById(TabsIds.MISSION_ID)
  })
}

let mainSettingsInfo = @() {
  watch = [isInRoom, isModAvailable, modPath]
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  borderWidth = 0
  children = [
    modPath.value == "" ? armiesSettingsInfo : null
    missionSettingsInfo
  ].append(isInRoom.value || !isModAvailable.value ? null : modMissionTitle)
}

let applyButton = @(locId) Flat(loc(locId), editEventRoom, {
  style = {
    defBgColor = brightAccentColor
    defTxtColor = darkTxtColor
  }
  hotkeys = [["^J:X", { description = { skip = true }}]]
})

let function toggleMissionsFilter(missionType) {
  selectedMissionType(missionType)
}

let mkMissionsByType = @() Computed(function() {
  let values = optMissions.cfg.value?.values ?? []
  let missions = {}
  values.each(function(blk) {
    let infoType = getMissionInfo(blk).type
    if (infoType not in missions)
      missions[infoType] <- []
    missions[infoType].append(blk)
  })

  return missions
})

let function mkMissionTypeSelectRow(missionType, missionsByType) {
  let isSelected = Computed(@() selectedMissionType.value == missionType)
  let amountTotal = Computed(@() (missionsByType.value?[missionType] ?? []).len())
  let amountSelected = Computed(function() {
    local amount = 0
    let current = optMissions.curValue.value
    let missions = missionsByType.value?[missionType] ?? []
    missions.each(function(blk) {
      if (current.contains(blk))
        amount++
    })
    return amount
  })
  return watchElemState(@(sf) {
    rendObj = ROBJ_SOLID
    watch = [isSelected, optMissions.curValue, optMissions.cfg]
    size = [campaignsBlockWidth, rowHeight]
    flow = FLOW_HORIZONTAL
    behavior = Behaviors.Button
    color = isSelected.value ? selectedPanelBgColor
      : sf & S_HOVER ? defInsideBgColor
      : blurBgFillColor
    valign = ALIGN_CENTER
    function onClick() {
      toggleMissionsFilter(missionType)
      sound_play("ui/enlist/flag_set")
    }
    margin = [smallPadding, 0]
    padding = [0, bigPadding]
    children = [
      {
        rendObj = ROBJ_TEXTAREA
        size = [flex(), SIZE_TO_CONTENT]
        behavior = Behaviors.TextArea
        color = isSelected.value ? defTxtColor : txtColor(sf)
        text = loc(typeToLocId[missionType] ?? missionType)
      }.__update(fontBody)
      @() {
        watch = [amountTotal, amountSelected]
        rendObj = ROBJ_TEXT
        color = isSelected.value ? defTxtColor : txtColor(sf)
        text = amountSelected.value == 0 ? ""
          : loc("options/missionsAmount", { selected = amountSelected.value,
              total = amountTotal.value })
      }.__update(fontBody)
    ]
  })
}

let campaignsFiltersBlock = function() {
  let missionsByType = mkMissionsByType()
  return {
    size = [campaignsBlockWidth, SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    children = missionTypes.map(@(id) mkMissionTypeSelectRow(id, missionsByType))
  }
}

let mkAllCurrentValuesButton = @(option) function() {
  let res = { watch = [option.cfg, option.curValue, selectedMissionType] }
  let { values = [], optType = null } = option.cfg.value

  let selectedType = selectedMissionType.value
  let missionValues = values.filter(@(blk) getMissionInfo(blk).type == selectedType)

  if (optType != OPT_MULTISELECT)
    return res
  local hasSelected = false
  local hasUnselected = false
  let curList = option.curValue.value
  if (curList != null) {
    foreach (m in missionValues) {
      if (curList.contains(m))
        hasSelected = true
      else
        hasUnselected = true
    }
  }
  if (!hasSelected && !hasUnselected)
    return res

  let function removeMissionValues() {
    option.setValue((curList ?? []).filter(@(blk) !missionValues.contains(blk)))
  }

  let function addMissionValues() {
    let toAdd = []
    missionValues.each(function(blk) {
      if (!(curList ?? []).contains(blk))
        toAdd.append(blk)
    })
    toAdd.extend(curList ?? [])
    option.setValue(toAdd)
  }

  return res.__update({
    gap = localGap
    flow = FLOW_HORIZONTAL
    pos = [campaignsBlockWidth + localPadding, 0]
    children = [
      !hasUnselected ? null
        : Bordered(loc("SelectAll"), addMissionValues, { hotkeys = [["^J:LT"]] })
      !hasSelected ? null
        : Bordered(loc("DeselectAll"), removeMissionValues, { hotkeys = [["^J:RT"]] })
    ]
  })
}

let function allArmyValuesButtons() {
  let armiesToChoose = optArmiesA.cfg.value.values.len() + optArmiesB.cfg.value.values.len()
  let selectedArmiesCount = optArmiesA.curValue.value.len() + optArmiesB.curValue.value.len()
  let hasSelected = selectedArmiesCount > 0
  let hasUnselected = selectedArmiesCount < armiesToChoose
  return {
    watch = [optArmiesA.cfg, optArmiesB.cfg, optArmiesA.curValue, optArmiesB.curValue]
    gap = localGap
    flow = FLOW_HORIZONTAL
    children = [
      hasUnselected ? Bordered(loc("SelectAll"), selectAll, { hotkeys = [["^J:LT"]] }) : null
      hasSelected ? Bordered(loc("DeselectAll"), unselectAll, { hotkeys = [["^J:RT"]] }) : null
    ]
  }
}

let lobbyPresetsButtons = @() {
  watch = [lobbyPresets, modPath]
  flow = FLOW_HORIZONTAL
  gap = localGap
  children = modPath.value != "" ? null : [
    Bordered(loc("Save settings"), openSaveWindow, { hotkeys = [["^J:LT"]] }),
    (lobbyPresets.value?.len() ?? 0) == 0 ? null
      : Bordered(loc("Choose settings"), openChooseWindow, { hotkeys = [["^J:RT"]] })
  ]
}

let gameStartButtons = @() {
  watch = [isInRoom, isModAvailable, optMaxPlayers.curValue, modPath]
  hplace = ALIGN_RIGHT
  flow = FLOW_HORIZONTAL
  gap = localGap
  children = [
    !isModAvailable.value || isInRoom.value || is_console
      ? null
      : Bordered(loc("Mods"), openCustomMissionWnd)
    modPath.value != "" && optMaxPlayers.curValue.value <= 1
      ? applyButton("Start local")
      : applyButton(isInRoom.value ? "changeAttributesRoom" : "createRoom")
  ]
}

let function mkArmiesBlock(team, content) {
  let { index, teamLocId } = team
  return {
    size = flex()
    flow = FLOW_VERTICAL
    gap = bigPadding
    halign = ALIGN_CENTER
    children = [
      {
        rendObj = ROBJ_SOLID
        size = [flex(), rowHeight]
        color = teamsColors[index].defBgColor
        padding = [0, localGap]
        children = {
          rendObj = ROBJ_TEXT
          text = loc(teamLocId)
          color = titleTxtColor
          vplace = ALIGN_CENTER
          hplace = index == 0 ? ALIGN_LEFT : ALIGN_RIGHT
        }.__update(fontBody)
      }
      content
    ]
  }
}

let wrapParams = {
  width = contentWidth
  hGap = localPadding
  vGap = localGap
  halign = ALIGN_CENTER
}

let tabsData = {
  [TabsIds.EVENT_ID] = {
    locId = "events/setting"
    content = {
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_HORIZONTAL
      gap = localPadding
      children = [
        baseOptionsList
        mainSettingsInfo
      ]
    }
    buttons = [
      lobbyPresetsButtons
      gameStartButtons
    ]
  },

  [TabsIds.ARMY_ID] = {
    locId = "options/armies"
    content = {
      size = flex()
      flow = FLOW_HORIZONTAL
      gap = localPadding
      children = teams.map(@(team)
        mkArmiesBlock(team, mkSelectArmy(team.armyOpt, mkArmySelectBlock)))
    }
    buttons = [
      allArmyValuesButtons
      gameStartButtons
    ]
  },

  [TabsIds.MISSION_ID] = {
    locId = "options/missions"
    content = {
      flow = FLOW_HORIZONTAL
      gap = localPadding
      size = flex()
      children = [
        campaignsFiltersBlock
        mkSelectMission(optMissions, mkMissionCard, wrapParams)
      ]
    }
    buttons = [
      mkAllCurrentValuesButton(optMissions)
      gameStartButtons
    ]
  }
}

let function switchTab(delta) {
  local newIdx = curTabIdx.value + delta
  let len = activeTabIds.value.len()
  if (newIdx > len-1)
    newIdx = 0
  else if (newIdx < 0)
    newIdx = len-1
  if (newIdx >= 0 && newIdx < len)
    curTabIdx(newIdx)
}

let headerTabs = @() {
  watch = [activeTabIds, curTabIdx, isGamepad, optMissions.cfg]
  flow = FLOW_HORIZONTAL
  size = [flex(), SIZE_TO_CONTENT]
  gap = localPadding
  margin = [localGap, 0,0,0]
  valign = ALIGN_CENTER
  children = activeTabIds.value
    .map(@(tabId, idx)
      mkWindowTab(loc(tabsData[tabId].locId), @() curTabIdx(idx), idx == curTabIdx.value))
    .insert(0, isGamepad.value && curTabIdx.value != 0 && activeTabIds.value.len() > 1
      ? mkHotkey("^J:LB", @() switchTab(-1))
      : null)
    .append(isGamepad.value && curTabIdx.value + 1 < activeTabIds.value.len()
      ? mkHotkey("^J:RB", @() switchTab(1))
      : null)
}

let createRoomContent = @() {
  watch = [curTabIdx, activeTabIds]
  flow = FLOW_VERTICAL
  gap = localGap
  halign = ALIGN_CENTER
  size = [flex(), contentHeight]
  children = [
    headerTabs
    tabsData?[activeTabIds.value?[curTabIdx.value]].content
  ]
}

let wndButtons = @() {
  watch = [isEditInProgress, curTabIdx, activeTabIds]
  size = [flex(), SIZE_TO_CONTENT]
  vplace = ALIGN_BOTTOM
  children = isEditInProgress.value
    ? waitingSpinner
    : tabsData?[activeTabIds.value?[curTabIdx.value]].buttons
}

let createRoomWnd = @() {
  watch = isInRoom
  rendObj = ROBJ_WORLD_BLUR_PANEL
  size = [wndWidth, SIZE_TO_CONTENT]
  padding = localPadding
  maxWidth = maxContentWidth
  color = blurBgColor
  flow = FLOW_VERTICAL
  children = [
    mkWindowHeader(
      isInRoom.value ? loc("changeAttributesRoom") : loc("createRoom"),
      chooseRandom(getImagesFromMissions()),
      closeBtn({ onClick = close })
        .__update({ margin = [bigPadding, 0] })
    )
    createRoomContent
    wndButtons
  ]
}

let function open() {
  currentPassword("")
  return addModalWindow({
    key = WND_UID
    rendObj = ROBJ_WORLD_BLUR_PANEL
    fillColor = defInsideBgColor
    size = flex()
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    children = createRoomWnd
    onClick = @() null
  })
}

if (isEditEventRoomOpened.value)
  open()
isEditEventRoomOpened.subscribe(@(v) v ? open() : removeModalWindow(WND_UID))
