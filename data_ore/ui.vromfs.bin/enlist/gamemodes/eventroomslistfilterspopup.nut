from "%enlSqGlob/ui/ui_library.nut" import *
from "eventRoomsListFilter.nut" import *
let { fontSub, fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let { midPadding, smallPadding, defTxtColor } = require("%enlSqGlob/ui/designConst.nut")
let { localGap } = require("eventModeStyle.nut")
let modalPopupWnd = require("%ui/components/modalPopupWnd.nut")
let mkOptionRow = require("components/mkOptionRow.nut")
let faComp = require("%ui/components/faComp.nut")
let { isModAvailable } = require("sandbox/customMissionState.nut")

let WND_UID = "eventFiltersPopup"
let isRoomFilterOpened = Watched(false)
let columnWidth = hdpx(440)
let rowHeight = hdpx(38)
let circleSize = [hdpxi(18), hdpxi(18)]
let locOn = loc($"option/on")
let locOff = loc($"option/off")

let OPTS_LIST = "opts_list"

let modsFilter = {
  optType = OPTS_LIST
  innerOption = optModRooms
}

let roomsCheckboxBlock = [
  {
    locId = "rooms/Rooms"
    optType = OPTS_LIST
    innerOption = optFullRooms
  }
  {
    optType = OPTS_LIST
    innerOption = optPasswordRooms
  }
].append(isModAvailable.value ? modsFilter : null )

let columns = [
  [ optMode, optDifficulty ].extend(roomsCheckboxBlock),
  [ optArmiesA, optArmiesB ],
  [ optCluster, optCrossplay ]
]

let widthPopup = columnWidth*columns.len()

let bTxt = @(text) {
  rendObj = ROBJ_TEXT
  color = defTxtColor
  text
}.__update(fontBody)

let mkBlock = @(headerText, children) {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  children = [
    headerText == null ? null :{
      size = [flex(), rowHeight]
      valign = ALIGN_BOTTOM
      padding = [0, midPadding, smallPadding, midPadding]
      rendObj = ROBJ_TEXT
      color = 0xFF808080
      text = headerText
    }.__update(fontSub)
    children
  ]
}

let mkCheckIcon = @(watched) @() {
  watch = watched
  size = [SIZE_TO_CONTENT, flex()]
  flow = FLOW_HORIZONTAL
  halign = ALIGN_RIGHT
  valign = ALIGN_CENTER
  children = watched.value ? faComp("check", {valign = ALIGN_CENTER}) : null
}


let checkCircleIconOn = Picture($"!ui/skin#on_radiobutton.svg:{circleSize[0]}:{circleSize[1]}:K")
let checkCircleIconOff = Picture($"!ui/skin#off_radiobutton.svg:{circleSize[0]}:{circleSize[1]}:K")

let mkCheckCircleIcon = @(v) {
  size = circleSize
  rendObj = ROBJ_IMAGE
  image = v ? checkCircleIconOn : checkCircleIconOff
}

let mkCircleCheck = @(watched) @() {
  watch = watched
  size = [SIZE_TO_CONTENT, flex()]
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  halign = ALIGN_RIGHT
  padding = [midPadding, 0]
  gap = hdpx(5)
  children = [
    bTxt(locOn)
    mkCheckCircleIcon(watched.value)
    { size = [midPadding, flex()]}
    bTxt(locOff)
    mkCheckCircleIcon(!watched.value)
  ]
}

function mkCheckbox(opt) {
  let { locId, curValue, setValue } = opt
  return mkOptionRow(
    loc(locId),
    mkCircleCheck(curValue),
    {
      onClick = @() setValue(!curValue.value)
      size = [flex(), rowHeight]
    }
  )
}

let mkSelectOption = @(opt) function () {
  let { locId, curValues, allValues, valToString = @(v) v, action } = opt
  let res = { watch = allValues }
  if (allValues.value == null || allValues.value.len() <= 1)
    return res

  let children = allValues.value.map(function (value) {
    let isChecked = Computed(@() curValues.value.contains(value))
    return mkOptionRow(
      loc(valToString(value)),
      mkCheckIcon(isChecked),
      {
        onClick = @() action(value)
        gap = null
        size = [flex(), rowHeight]
      }
    )
  })

  return res.__update({
    watch = allValues
    size = [flex(), SIZE_TO_CONTENT]
    children = mkBlock(loc(locId),
      {
        flow = FLOW_VERTICAL
        size = [flex(), SIZE_TO_CONTENT]
        children = children
      }
    )
  })
}

let mkSelectSingle = @(opt) mkSelectOption(opt.__merge({
  action = @(value) opt?.setValue([value])
}))

let mkSelectMultiple = @(opt) mkSelectOption(opt.__merge({
  action = function (value) {
    let { toggleValue, curValues } = opt
    toggleValue(value, !curValues.value.contains(value))
  }
}))

function mkOptsList(opt) {
  return mkBlock(
    loc(opt?.locId),
    {
      size = [flex(), SIZE_TO_CONTENT]
      children = mkCheckbox(opt.innerOption)
    }
  )
}

function mkRow(option) {
  let { optType = null } = option
  if (optType == null)
    return null
  let ctor = {
    [OPTS_LIST] = mkOptsList,
    [OPT_RADIO] = mkSelectSingle,
    [OPT_MULTISELECT] = mkSelectMultiple
  }?[optType]

  return ctor?(option)
}


let mkColumn = @(rows) {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  children = rows.map(mkRow)
}

let content = {
    size = [widthPopup, SIZE_TO_CONTENT]
    padding = [0, midPadding, midPadding, midPadding]
    stopMouse = true
    flow = FLOW_HORIZONTAL
    gap = midPadding
    children = columns.map(mkColumn)
  }

let openEventFiltersPopup = @(event)
  modalPopupWnd.add(event.targetRect, {
    uid = WND_UID
    children = content
    popupOffset = localGap
    popupHalign = ALIGN_LEFT
    onAttach = @() isRoomFilterOpened(true)
    onDetach = @() isRoomFilterOpened(false)
  })

let closeEventFiltersPopup = @() modalPopupWnd.remove(WND_UID)

function toggleEventFiltersPopup(event) {
  if (isRoomFilterOpened.value)
    closeEventFiltersPopup()
  else
    openEventFiltersPopup(event)
}

return {
  openEventFiltersPopup
  closeEventFiltersPopup
  toggleEventFiltersPopup
  isRoomFilterOpened
}