from "%enlSqGlob/ui/ui_library.nut" import *

let { fontBody, fontSub, fontawesome } = require("%enlSqGlob/ui/fontsStyle.nut")
let fa = require("%ui/components/fontawesome.map.nut")
let colors = require("%ui/style/colors.nut")
let textButtonTextCtor = require("textButtonTextCtor.nut")
let defStyle = require("textButton.style.nut")
let serverTime = require("%enlSqGlob/userstats/serverTime.nut")


function textColor(sf, style=null, isEnabled = true) {
  let styling = defStyle.__merge(style ?? {})
  if (!isEnabled) return styling.TextDisabled
  if (sf & S_ACTIVE)    return styling.TextActive
  if (sf & S_HOVER)     return styling.TextHover
  if (sf & S_KB_FOCUS)  return styling.TextFocused
  return styling.TextNormal
}

function borderColor(sf, style=null, isEnabled = true) {
  let styling = defStyle.__merge(style ?? {})
  if (!isEnabled) return styling.BdDisabled
  if (sf & S_ACTIVE)    return styling.BdActive
  if (sf & S_HOVER)     return styling.BdHover
  if (sf & S_KB_FOCUS)  return styling.BdFocused
  return styling.BdNormal
}

function fillColor(sf, style=null, isEnabled = true) {
  let styling = defStyle.__merge(style ?? {})
  if (!isEnabled) return styling.BgDisabled
  if (sf & S_ACTIVE)    return styling.BgActive
  if (sf & S_HOVER)     return styling.BgHover
  if (sf & S_KB_FOCUS)  return styling.BgFocused
  return styling.BgNormal
}

function fillColorTransp(sf, style=null, _isEnabled = true) {
  let styling = defStyle.__merge(style ?? {})
  if (sf & S_ACTIVE)    return styling.BgActive
  if (sf & S_HOVER)     return styling.BgHover
  if (sf & S_KB_FOCUS)  return styling.BgFocused
  return 0
}

let defTextCtor = @(text, _params, _handler, _group, _sf) text
let textButton = @(fill_color, border_width) function(text, handler, params = {}) {
  let { stateFlags = Watched(0), enabledDelay = 0, overrideBySf = null } = params

  let group = ElemGroup()
  let enableTs = serverTime.value + enabledDelay
  let enabByDelay = enabledDelay <= 0
    ? Watched(0)
    : Computed(@() max(0, enableTs - serverTime.value))

  function builder(sf) {
    let paramsExt = overrideBySf == null
      ? params
      : params.__merge(overrideBySf(sf, params?.isEnabled ?? true) ?? {})
    let {
      font = fontBody.font, fontSize = fontBody.fontSize, // TODO bad practice to pass values both as root & textParams fields
      textCtor = defTextCtor, isEnabled = true,
      style = defStyle, textMargin = defStyle.textMargin, key = handler,
      bgChild = null, fgChild = null
    } = paramsExt
    let sound = isEnabled ? paramsExt?.style.sound ?? paramsExt?.sound : null

    let secToEnabled = enabByDelay.value
    let isTimerEnabled = isEnabled && secToEnabled <= 0

    local btnText = (type(text)=="function") ? text() : text
    if (secToEnabled > 0)
      btnText = $"{btnText} ({secToEnabled})"

    return {
      watch = [stateFlags, enabByDelay]
      onElemState = @(v) stateFlags(v)
      margin = defStyle.btnMargin
      key
      group
      rendObj = ROBJ_BOX
      fillColor = fill_color(sf, style, isTimerEnabled)
      borderWidth = border_width
      borderRadius = hdpx(4)
      valign = ALIGN_CENTER
      clipChildren = true
      borderColor = borderColor(sf, style, isTimerEnabled)
      onDetach = @() stateFlags(0)
      children = [
        bgChild
        textCtor({
          rendObj = ROBJ_TEXT
          text = btnText
          scrollOnHover=true
          delay = 0.5
          speed = [hdpx(100),hdpx(700)]
          maxWidth = pw(100)
          ellipsis = false
          margin = textMargin
          font
          fontSize
          group
          behavior = [Behaviors.Marquee]
          color = textColor(sf, style, isTimerEnabled)
        }.__update(paramsExt?.textParams ?? {}), paramsExt, handler, group, sf)
        fgChild
      ]

      behavior = Behaviors.Button
      onClick = isTimerEnabled ? handler : null
    }.__update(paramsExt, { sound })
  }

  return @() builder(stateFlags.value)
}
let soundDefault = {
  click  = "ui/enlist/button_click"
  hover  = "ui/enlist/button_highlight"
}

let soundActive = soundDefault.__merge({  active = "ui/enlist/button_action" })

let override = {
  halign = ALIGN_CENTER
  sound = soundActive
  textCtor = textButtonTextCtor
}.__update(fontBody)

let onlinePurchaseStyle = {
  borderWidth = hdpx(1)

  style = {
    BgNormal = colors.BtnActionBgNormal
    BgActive   = colors.BtnActionBgActive
    BgFocused  = colors.BtnActionBgFocused

    BdNormal  = colors.BtnActionBdNormal
    BdActive   = colors.BtnActionBdActive
    BdFocused = colors.BtnActionBdFocused

    TextNormal  = colors.BtnActionTextNormal
    TextActive  = colors.BtnActionTextActive
    TextFocused = colors.BtnActionTextFocused
    TextHilite  = colors.BtnActionTextHilite
  }
}.__update(override)

let primaryButtonStyle = override.__merge({
  style = {
    BgNormal = 0xfa0182b5
    BgActive   = 0xfa015ea2
    BgFocused  = 0xfa0982ca

    TextNormal  = Color(180, 180, 180, 180)
    TextActive  = Color(120, 120, 120, 120)
    TextFocused = Color(160, 160, 160, 120)
    TextHilite  = Color(220, 220, 220, 160)
  }
})

let loginBtnStyle = (clone onlinePurchaseStyle)

let smallStyle = {
  textMargin = [hdpx(3), hdpx(5)]
}.__update(fontSub)

let Transp = textButton(fillColorTransp, 0)
let Bordered = textButton(fillColor, hdpx(1))
let Flat = textButton(fillColor, 0)

local defaultButton = @(text, handler, params = {}) Bordered(text, handler, override.__merge(params))

let export = class {
  _call = @(_self, text, handler, params = {}) defaultButton(text, handler, params)
  Transp = @(text, handler, params = {}) Transp(text, handler, override.__merge(params))
  Bordered = @(text, handler, params = {}) Bordered(text, handler, override.__merge(params))
  Small = @(text, handler, params = {}) Transp(text, handler, override.__merge(fontSub, {margin=hdpx(1) textMargin=[hdpx(2),hdpx(5),hdpx(2),hdpx(5)]}, params))
  SmallBordered = @(text, handler, params = {}) Bordered(text, handler, override.__merge(smallStyle, params))
  Flat = @(text, handler, params = {}) Flat(text, handler, override.__merge(params))
  SmallFlat = @(text, handler, params = {})
    Flat(text, handler, override.__merge(smallStyle, params))
  FAButton = @(iconId, callBack, params = {})
    Flat(fa[iconId], callBack, {
      size = [hdpx(40), hdpx(40)]
      halign = ALIGN_CENTER
      rendObj = ROBJ_INSCRIPTION
      borderWidth = (params?.isEnabled ?? true) ? hdpx(1):0
      margin = hdpx(1)
      sound = (params?.isEnabled ?? true) ? soundDefault : null
    }.__merge(fontawesome, params))

  Purchase = @(text, handler, params = {}) Bordered(text, handler, fontBody.__merge(onlinePurchaseStyle, params))
  PrimaryFlat = @(text, handler, params = {}) Flat(text, handler, fontBody.__merge(primaryButtonStyle, params))

  onlinePurchaseStyle = onlinePurchaseStyle
  primaryButtonStyle = primaryButtonStyle
  smallStyle = smallStyle
  override = override
  loginBtnStyle = loginBtnStyle

  soundDefault = soundDefault
  soundActive = soundActive
}()

return export
