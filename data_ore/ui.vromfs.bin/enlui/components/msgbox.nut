from "%enlSqGlob/ui/ui_library.nut" import *

let msgbox = require("%ui/components/sys_msgbox.nut")
let JB = require("%ui/control/gui_buttons.nut")
let textButton = require("%ui/components/textButton.nut")
let fontIconButton = require("%ui/components/fontIconButton.nut")

let { fontHeading2 } = require("%enlSqGlob/ui/fontsStyle.nut")
let { isGamepad } = require("%ui/control/active_controls.nut")
let { mkTwoSidesGradientX } = require("%enlSqGlob/ui/gradients.nut")
let { smallPadding } = require("%enlSqGlob/ui/designConst.nut")


let bgColor = 0XEE1F242A
let rootColor = 0XFF1F242A

let decorImg = mkTwoSidesGradientX({
  centerColor = 0x77FFFFFF
  sideColor = 0x11FFFFFF
  isAlphaPremultiplied = false
})

let decorObj = {
  size = [flex(), smallPadding]
  rendObj = ROBJ_IMAGE
  image = decorImg
}


let eventHandlersStopper = {
  ["HUD.ChatInput"] = @(_event) EVENT_BREAK
}

let styling = {
  rootUpperDecor = decorObj
  rootLowerDecor = decorObj

  Root = {
    behavior = Behaviors.ActivateActionSet
    actionSet = "StopInput"
    rendObj = ROBJ_WORLD_BLUR_PANEL
    stopMouse = true
    stopHotkeys = true
    fillColor = rootColor
    vplace = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = [sw(100), SIZE_TO_CONTENT]
    minHeight = fsh(40)
    transform = { pivot = [0.5, 0.5] }
    animations = [
      { prop = AnimProp.opacity, from = 0, to = 1, duration = 0.25,
        play = true, easing = OutCubic }
      { prop = AnimProp.scale,  from = [1, 0], to = [1,1], duration = 0.2,
        play = true, easing = OutQuintic }
    ]
  }
  moveMouseCursor = isGamepad
  closeKeys = $"{JB.B} | Esc"
  leftKeys = "L.Shift Tab | R.Shift Tab"
  rightKeys = "Tab"
  activateKeys = "Space | Enter"
//  maskKeys = "J:D.Up | J:D.Down"
  closeTxt = loc("Close")

  BgOverlay = {
    size = [sw(100), sh(100)]
    color = bgColor
    rendObj = ROBJ_SOLID
    stopMouse = true
    zOrder = Layers.MsgBox
    sound = {
      hover  = "ui/menu_highlight"
      click  = "ui/button_click_inactive"
    }
    eventHandlers = eventHandlersStopper
    animations = [
      { prop=AnimProp.opacity, from=1, to=0, duration=0.15, playFadeout=true, easing=OutCubic }
      { prop=AnimProp.opacity, from=0, to=1, duration=0.15, play=true, easing=OutCubic }
    ]
  }

  button = function(desc, on_click) {
    let addKey = {key = desc?.key ?? desc}
    return textButton(desc?.text ?? "???", on_click, (desc?.customStyle!=null) ? desc.customStyle.__merge(addKey) : addKey)
  }

  messageText = function(params) {
    local text = params?.text
    if (text instanceof Watched)
      text = text.value

    return {
      size = [flex(), SIZE_TO_CONTENT]
      minHeight = fsh(32)
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      flow = FLOW_VERTICAL
      margin = [fsh(2), 0, 0, 0]
      children = [
        {
          size = [sw(60), SIZE_TO_CONTENT]
          rendObj = ROBJ_TEXTAREA
          behavior = Behaviors.TextArea
          halign = ALIGN_CENTER
          text
        }.__update(params?.fontStyle ?? fontHeading2)
        params?.children
      ]
    }
  }
}


let addDefOkButton = @(p) ("buttons" in p) ? p : p.__merge({
  buttons = [{ text = loc("Close"), isCancel = true,
    customStyle = { hotkeys = [[$"^{JB.B} | Esc"]] } }]
})

function msgText(p) {
  return {
    halign = ALIGN_CENTER
    padding = [fsh(2), 0]
    children = p.content
  }
}
function showMessageWithStyle(p, msgStyle) {
  msgStyle = msgStyle.__merge({messageText = msgText})
  msgbox.show(addDefOkButton(p), msgStyle)
}

function showContentOnPictureBg(p) {
  let msgStyle = clone styling
  msgStyle.Root = styling.Root.__merge({ rendObj = null })
  msgStyle.BgOverlay = styling.BgOverlay.__merge({
    size = [sw(100), sh(100)]
    rendObj = ROBJ_SOLID
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    children = {
      size = [SIZE_TO_CONTENT, sh(100)]
      rendObj = ROBJ_IMAGE
      hplace = ALIGN_CENTER
      color = null
      keepAspect = KEEP_ASPECT_FIT
      image = p?.bgImage
    }
  })
  showMessageWithStyle(p, msgStyle)
}

function showMessageWithContent(p, customStyle = null) {
  showMessageWithStyle(p, customStyle ?? styling)
}


function showWithCloseButton(params) {
  let originalMessageText = styling.messageText
  let style = styling.__merge({
    messageText = @(textParams) {
      size = [flex(), SIZE_TO_CONTENT]
      children = [
        {
          flow = FLOW_HORIZONTAL
          vplace = ALIGN_TOP
          hplace = ALIGN_RIGHT
          children = [
            params?.topPanel
            fontIconButton("close", {
              onClick = @() textParams?.handleButton(params?.onButtonCloseCb)
              size = [fsh(5),fsh(5)]
              hotkeys = [[JB.B, { description = { skip = true } }]]
            })
          ]
        }
        originalMessageText(textParams)
      ]
    }
  })
  msgbox.show(addDefOkButton(params), style)
}

let showMsgbox = @(params, style=styling) msgbox.show(addDefOkButton(params), style)

return msgbox.__merge({
  show = showMsgbox
  showMsgbox
  showMessageWithContent
  showContentOnPictureBg
  showWithCloseButton
  styling
  msgboxDefStyle = styling
})
