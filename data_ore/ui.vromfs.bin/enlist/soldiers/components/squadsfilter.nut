from "%enlSqGlob/ui_library.nut" import *

let { Transp } = require("%ui/components/textButton.nut")
let modalPopupWnd = require("%ui/components/modalPopupWnd.nut")
let { midPadding, defSlotBgColor, hoverSlotBgColor,
  darkTxtColor, defTxtColor, smallBtnHeight, titleTxtColor,
  commonBtnHeight } = require("%enlSqGlob/ui/designConst.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { squadTypeIcon } = require("%enlSqGlob/ui/squadsUiComps.nut")
let { allSquadTypes } = require("%enlist/soldiers/model/config/squadsConfig.nut")
let textButtonTextCtor = require("%ui/components/textButtonTextCtor.nut")
let faComp = require("%ui/components/faComp.nut")

let WND_UID = "squadsFilter"
let iSize = hdpxi(22)
let btnWidth = hdpx(330)
let checkFontSize = hdpx(14)
let selectorHeight = commonBtnHeight
let textColor = @(sf, isSelected = false, isDisabled = false) isDisabled ? 0xFF6E7272
  : isSelected || (sf & S_HOVER) ? darkTxtColor : defTxtColor
let iconColor = @(sf, isSelected = false, isDisabled = false) isDisabled ? 0xFF6E7272
  : isSelected || (sf & S_HOVER) ? darkTxtColor : titleTxtColor
let fillColor = @(sf, isSelected = false, isDisabled = false) isDisabled ? defSlotBgColor
  : isSelected || (sf & S_HOVER) ? hoverSlotBgColor : defSlotBgColor

let function getCountSquadTypes(squadsList) {
  let squadTypes = {}
  foreach(squad in squadsList)
    squadTypes[squad.squadType] <- (squadTypes?[squad.squadType] ?? 0) + 1
  return squadTypes
}

let function updateSquadTypes(res, squadsList, defValue = null) {
  foreach(squad in squadsList)
    if (squad.squadType not in res)
      res[squad.squadType] <- defValue
  return res
}

let mkFilterIcon = @(iconSize = iSize, override = {}) {
  size = [iconSize, iconSize]
  rendObj = ROBJ_IMAGE
  image = Picture("{0}:{1}:{1}:K".subst("ui/skin#filter_icon.svg", iconSize))
  keepAspect = KEEP_ASPECT_FIT
}.__update(override)

let mkIconBtnFilter = @(squadType, sf) @() {
  watch = squadType
  children = squadType.value
    ? squadTypeIcon(squadType.value, iSize, { color = iconColor(sf) })
    : mkFilterIcon(iSize, { color = textColor(sf) })
}

let mkIconCheck = @(isSelected, color) !isSelected ? null
  : faComp("check", {color, fontSize = checkFontSize})

let close = function() {
  modalPopupWnd.remove(WND_UID)
}

let resetFilter = @(watchFilter) watchFilter({})
let setFilter = @(watchFilter, squadType) watchFilter({ [squadType] = true })
let clearFilter = @(watchFilter, squadType) watchFilter.mutate(@(f) delete f[squadType])

let styleSelector = {
  rendObj = ROBJ_SOLID
  size = [flex(), selectorHeight]
  minWidth = btnWidth
  behavior = Behaviors.Button
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  padding = [0, midPadding]
}

let function mkSquadSelector(watchFilter, squadTypeInfo, squadsCount) {
  let squadType = squadTypeInfo.squadType
  let nameLocText = squadTypeInfo.nameText
  let isSelected = Computed(@() squadType in watchFilter.value)
  let typeCount = Computed(@() squadsCount.value?[squadType] ?? 0)
  let isDisabled = Computed(@() squadType not in squadsCount.value)
  return watchElemState(function(sf) {
    let color = textColor(sf, isSelected.value, isDisabled.value)
    return {
      watch = [isSelected, isDisabled, typeCount]
      color = fillColor(sf, isSelected.value, isDisabled.value)
      onClick = isDisabled.value ? null
        : function() {
            close()
            if (!isSelected.value) {
              setFilter(watchFilter, squadType)
              return
            }
            if (squadType in watchFilter.value)
              clearFilter(watchFilter, squadType)
          }
      children = [
        {
          size = [flex(), SIZE_TO_CONTENT]
          flow = FLOW_HORIZONTAL
          gap = midPadding
          children = [
            squadTypeIcon(squadType, iSize, { color })
            {
              rendObj = ROBJ_TEXT
              vplace = ALIGN_CENTER
              color
              text = typeCount.value == 0 ? nameLocText : $"{nameLocText} ({typeCount.value})"
            }
          ]
        }
        mkIconCheck(isSelected.value, color)
      ]
    }.__update(styleSelector)
  })
}

let function mkSelectorShowAll(watchFilter) {
  let isEmptyFilter = Computed(@() watchFilter.value.len() == 0)
  return watchElemState(function(sf) {
    let color = textColor(sf, isEmptyFilter.value)
    return {
      color = fillColor(sf, isEmptyFilter.value)
      watch = isEmptyFilter
      onClick = function() {
        resetFilter(watchFilter)
        close()
      }
      children = [
        {
          size = [flex(), SIZE_TO_CONTENT]
          rendObj = ROBJ_TEXT
          vplace = ALIGN_CENTER
          color
          text = loc("ShowAll")
        }
        mkIconCheck(isEmptyFilter.value, color)
      ]
    }.__update(styleSelector)
  })
}

let openFilter = @(event, watchFilter, squadTypesCount, offset)
  modalPopupWnd.add([event.targetRect.r + offset[1], event.targetRect.t + offset[0]], {
    uid = WND_UID
    popupHalign = ALIGN_LEFT
    popupValign = ALIGN_TOP
    popupFlow = FLOW_VERTICAL
    popupBg = { rendObj = null }
    padding = 0
    valign = ALIGN_TOP
    children = @() {
      flow = FLOW_VERTICAL
      children = [mkSelectorShowAll(watchFilter)]
        .extend(allSquadTypes.value
          .map(@(item) mkSquadSelector(watchFilter, item, squadTypesCount)))
    }
    hotkeys = [[$"^{JB.B} | Esc | J:RS.Tilted", { action = close }]]
  })

let getFilterSquads = @(squadsList, filter) filter.len() == 0
  ? squadsList : squadsList.filter(@(s) s.squadType in filter)

let mkTextBtnFilter = @(color) {
  rendObj = ROBJ_TEXT
  color
  text = loc("Filters")
}

let squadsFilterUi = kwarg(function(watchFilter, squadTypesCount, offset = [0, 0], override = {}) {
  let squadType = Computed(@() watchFilter.value.keys()?[0])
  let filterBtn = @(sf) {
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    gap = midPadding
    padding = midPadding
    children = [
      mkTextBtnFilter(textColor(sf))
      mkIconBtnFilter(squadType, sf)
    ]
  }
  return Transp("", @(event) openFilter(event, watchFilter, squadTypesCount, offset), {
    key = "openSquadsFilter"
    margin = 0
    size = [SIZE_TO_CONTENT, smallBtnHeight]
    hotkeys = [["^J:RS.Tilted"]]
    textCtor = @(_textComp, params, handler, group, sf)
      textButtonTextCtor(filterBtn(sf), params, handler, group, sf)
  }.__update(override))
})

return {
  getCountSquadTypes
  updateSquadTypes
  squadsFilterUi
  getFilterSquads
  resetFilter
}