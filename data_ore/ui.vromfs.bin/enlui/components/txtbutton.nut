from "%enlSqGlob/ui/ui_library.nut" import *

let { fontawesome, fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let { disabledTxtColor, defTxtColor, titleTxtColor, commonBtnHeight, smallBtnHeight, defBdColor,
  commonBorderRadius, midPadding, hoverTxtColor, hoverPanelBgColor, accentColor, darkTxtColor,
  darkPanelBgColor, brightAccentColor, hoverSlotBgColor
} = require("%enlSqGlob/ui/designConst.nut")
let fa = require("%ui/components/fontawesome.map.nut")
let getGamepadHotkeys = require("%ui/components/getGamepadHotkeys.nut")
let {mkImageCompByDargKey} = require("%ui/components/gamepadImgByKey.nut")
let { isGamepad } = require("%ui/control/active_controls.nut")
let JB = require("%ui/control/gui_buttons.nut")
let tooltipCtor = require("%ui/style/tooltipCtor.nut")
let { setTooltip } = require("%ui/style/cursors.nut")
let { soundActive } = require("%ui/components/textButton.nut")

let defTxtStyle = {
  defTxtColor
  hoverTxtColor = darkTxtColor
  activeTxtColor = defTxtColor
  disabledTxtColor
}

function textColor(sf, style = {}, isEnabled = true) {
  let txtColor = defTxtStyle.__merge(style)
  if (!isEnabled) return txtColor.disabledTxtColor
  if (sf & S_ACTIVE) return txtColor.activeTxtColor
  if (sf & S_HOVER)     return txtColor.hoverTxtColor
  if (sf & S_KB_FOCUS)  return txtColor.hoverTxtColor
  return txtColor.defTxtColor
}


let pressedBtnStyle = {
  defTxtColor = titleTxtColor
  hoverTxtColor = hoverTxtColor
  defBgColor = darkPanelBgColor
  hoverBgColor = hoverPanelBgColor
}


let accentBtnStyle = {
  defTxtColor = darkTxtColor
  hoverTxtColor = darkTxtColor
  activeTxtColor = darkTxtColor
  defBgColor = brightAccentColor
  hoverBgColor = accentColor
  activeBgColor = 0xFFB4B4B4
}


let defBorderStyle = {
  disabledBdColor = disabledTxtColor
  defBdColor
  hoverBdColor = titleTxtColor
  activeBdColor = titleTxtColor
  borderWidth = hdpx(1)
  borderRadius = commonBorderRadius
}

function borderColor(sf, style = {}, isEnabled = true) {
  let bdColor = defBorderStyle.__merge(style)
  if (!isEnabled)       return bdColor.disabledBdColor
  if (sf & S_ACTIVE)    return bdColor.activeBdColor
  if (sf & S_HOVER)     return bdColor.hoverBdColor
  if (sf & S_KB_FOCUS)  return bdColor.hoverBdColor
  return bdColor.defBdColor
}


let defBgStyle = {
  defBgColor = null
  hoverBgColor = hoverSlotBgColor
  activeBgColor = darkPanelBgColor
  disabledBgColor = null
}


function fillColor(sf, style = {}, isEnabled = true) {
  let bgColor = defBgStyle.__merge(style)
  if (!isEnabled)       return bgColor.disabledBgColor
  if (sf & S_ACTIVE)    return bgColor.activeBgColor
  if (sf & S_HOVER)     return bgColor.hoverBgColor
  if (sf & S_KB_FOCUS)  return bgColor.hoverBgColor
  return bgColor.defBgColor
}


let defHotkeyParams = {
  hplace = ALIGN_LEFT
  margin = midPadding
}


let defButtonBg = @(sf, style, isEnabled) {
  size = flex()
  rendObj = style?.rendObj ?? ROBJ_BOX
  fillColor = fillColor(sf, style, isEnabled)
  borderWidth = style?.borderWidth ?? defBorderStyle.borderWidth
  borderRadius = style?.borderRadius ?? defBorderStyle.borderRadius
  borderColor = borderColor(sf, style, isEnabled)
}

let defTextCtor = function(text, params, _handler, group, sf) {
  let { isEnabled = true, txtParams = fontBody, style = {} } = params
  return {
    rendObj = ROBJ_TEXT
    text
    group
    color = textColor(sf, style, isEnabled)
    margin = txtParams?.margin ?? [hdpx(10), hdpx(20)]
  }.__update(txtParams)
}

function textButton(text, handler, params={}) {
  let group = ElemGroup()
  let { stateFlags = Watched(0) } = params
  let {
    txtParams = fontBody, isEnabled = true, style = {}, bgComp = null, fgChild = null,
    btnHeight = commonBtnHeight, btnWidth = null, sound = {}, hint = null, onHoverFunc = null
  } = params
  let minWidth = btnWidth ?? SIZE_TO_CONTENT
  let usingCustomCtor = type(text) == "function"

  function builder(sf) {
    local gamepadHotkey = usingCustomCtor ? "" : getGamepadHotkeys(params?.hotkeys)
    local gamepadBtn = null
    if (gamepadHotkey != "") {
      if ((sf & S_HOVER) || (sf & S_ACTIVE)) {
        gamepadHotkey = JB.A
      }
      gamepadBtn = mkImageCompByDargKey(gamepadHotkey
        defHotkeyParams.__merge({ height = txtParams.fontSize}, params?.hotkeyParams ?? {}))
    }
    let bgChild = bgComp?(sf, isEnabled) ?? defButtonBg(sf, style, isEnabled)

    let btnContent = text == null ? null
      : usingCustomCtor ? text(null, params, handler, group, sf)
      : defTextCtor(text, params, handler, group, sf)

    return {
      watch = [stateFlags, isGamepad]
      size = [btnWidth ?? SIZE_TO_CONTENT, btnHeight]
      key = handler
      group
      minWidth
      onElemState = @(v) stateFlags(v)
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      behavior = Behaviors.Button
      onDetach = @() stateFlags(0)
      onHover = function(on) {
        onHoverFunc?(on)
        if (hint != null)
          setTooltip(!on ? null : tooltipCtor(hint))
      }
      onClick = isEnabled ? handler : null
      sound = soundActive.__update(sound)

      children = [
        bgChild
        {
          flow = FLOW_HORIZONTAL
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          size = [btnWidth ?? SIZE_TO_CONTENT, btnHeight]
          clipChildren = true
          children = [
            isGamepad.value ? gamepadBtn : null
            btnContent
          ]
        }
        fgChild
      ]
    }.__merge(params)
  }

  return @() builder(stateFlags.value)
}


let export = class {
  Bordered = @(text, handler, params = {}) textButton(text, handler, params)
  Flat = @(text, handler, params = {}) textButton(text, handler, {
    style = { borderWidth = 0 }
  }.__merge(params))
  SmallBordered = @(text, handler, params = {}) textButton(text, handler, {
    btnHeight = smallBtnHeight
    txtParams = fontBody
  }.__merge(params))
  PressedBordered = @(text, handler, params = {}) textButton(text, handler, {
    style = pressedBtnStyle
  }.__merge(params))
  FAButton = @(iconId, handler, params = {}) function() {
    let icon = isGamepad.value && params?.hotkeys != null ? null : fa[iconId]
    return {
      watch = isGamepad
      children = textButton(icon, handler, {
          btnWidth = commonBtnHeight
          txtParams = fontawesome
        }.__merge(params))
    }
  }
  FAFlatButton = @(iconId, handler, params = {}) function() {
    let icon = isGamepad.value && params?.hotkeys != null ? null : fa[iconId]
    return {
      watch = isGamepad
      children = textButton(icon, handler, {
          btnWidth = commonBtnHeight
          txtParams = fontawesome
          style = { borderWidth = 0 rendObj = ROBJ_WORLD_BLUR_PANEL }
        }.__merge(params))
    }
  }
  Accented = @(text, handler, params = {}) textButton(text, handler, {
    style = { borderWidth = 0 }.__merge(accentBtnStyle)
  }.__merge(params))
}()

return export
