from "%enlSqGlob/ui_library.nut" import *
let { fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let { bigPadding, midPadding, titleTxtColor, defTxtColor, commonBorderRadius,
  hoverSlotBgColor, darkTxtColor
} = require("%enlSqGlob/ui/designConst.nut")
let { utf8ToUpper } = require("%sqstd/string.nut")
let { blinkUnseen } = require("%ui/components/unseenComponents.nut")
let { soundActive } = require("%ui/components/textButton.nut")


let markerTarget = MoveToAreaTarget()

let function requestMoveToElem(elem) {
  let x = elem.getScreenPosX()
  let y = elem.getScreenPosY()
  let w = elem.getWidth()
  let h = elem.getHeight()
  markerTarget.set(x, y, x + w, y + h)
}


let tabTxtStyle = @(sf, isSelected) {
  color = sf & S_HOVER ? darkTxtColor
    : (sf & S_ACTIVE) || isSelected ? titleTxtColor
    : defTxtColor
  fontFx = sf & S_HOVER ? null : FFT_GLOW
  fontFxFactor = min(24, hdpx(24))
  fontFxColor = 0xDD000000
}.__update(fontBody)


let tabBottomPadding = midPadding * 2


let function mkTab(section, action, curSection) {
  let {
    id, locId, isUnseenWatch = Watched(false), addChild = null, mkChild = null
  } = section
  let isSelected = @(curSec) curSec == id
  let stateFlags = Watched(0)
  let function textTabComp() {
    let isSel = isSelected(curSection.value)
    return {
      watch = [curSection, stateFlags]
      rendObj = ROBJ_TEXT
      text = utf8ToUpper(loc(locId))
      size = [SIZE_TO_CONTENT, flex()]
      padding = [0, midPadding, tabBottomPadding, midPadding]
      valign = ALIGN_BOTTOM
      key = id
      behavior = [Behaviors.RecalcHandler]
      function onRecalcLayout(initial, elem) {
        if (initial || isSel) {
          requestMoveToElem(elem)
        }
      }
    }.__update(tabTxtStyle(stateFlags.value, isSel))
  }
  let boxTabComp = @() {
    watch = stateFlags
    size = flex()
    margin = [bigPadding, 0, 0, 0]
    rendObj = ROBJ_SOLID
    color = stateFlags.value & S_HOVER ? hoverSlotBgColor : 0
  }

  let childTabComp = @() {
    size = [flex(), SIZE_TO_CONTENT]
    watch = stateFlags
    children = mkChild?(stateFlags.value) ?? addChild
  }
  return function(){
    return {
      watch = isUnseenWatch
      size = [SIZE_TO_CONTENT, flex()]
      halign = ALIGN_CENTER
      behavior = Behaviors.Button
      sound = soundActive
      minWidth = fsh(8.5)
      onClick = action
      onElemState = @(s) stateFlags(s)
      skipDirPadNav = true
      children = [
        boxTabComp
        textTabComp
        isUnseenWatch.value ? blinkUnseen : null
        childTabComp
      ]
    }
  }
}

let backgroundMarker = freeze({
  behavior = Behaviors.MoveToArea
  subPixel = true
  target = markerTarget
  viscosity = 0.1
  valign = ALIGN_BOTTOM
  children = {
    rendObj = ROBJ_BOX
    size = [flex(), hdpxi(4)]
    borderWidth = 0
    borderRadius = commonBorderRadius
    fillColor = Color(255,255,255)
  }
})



return {
  mkTab
  backgroundMarker
  requestMoveToElem
}
