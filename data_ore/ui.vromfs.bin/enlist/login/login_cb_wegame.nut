from "%enlSqGlob/ui/ui_library.nut" import *

let auth = require("auth")
let JB = require("%ui/control/gui_buttons.nut")
let { fontBody, fontHeading2} = require("%enlSqGlob/ui/fontsStyle.nut")
let defLoginCb = require("%enlist/login/login_cb.nut")
let { startLogin } = require("%enlist/login/login_chain.nut")
let { addModalWindow, removeModalWindow } = require("%ui/components/modalWindows.nut")
let { commonBtnHeight, midPadding, maxContentWidth } = require("%enlSqGlob/ui/designConst.nut")
let { Bordered } = require("%ui/components/textButton.nut")
let textInput = require("%ui/components/textInput.nut")
let spinner = require("%ui/components/spinner.nut")
let fontIconButton = require("%ui/components/fontIconButton.nut")
let { exitGameMsgBox } = require("%enlist/mainMsgBoxes.nut")
let { safeAreaBorders } = require("%enlist/options/safeAreaState.nut")

const LOGIN_WND_UID = "login_back_window"
let newNick = Watched("")
local nickToShowIfInvalid = ""
const WE_GAME_ID = "auth_wegame"
let isLoginInProgress = Watched(false)
let additionalTxt = Watched("")
let wndHeaderTxt = Watched("")
let waitingSpinner = spinner()

function loginWithNick(){
  isLoginInProgress(true)
  nickToShowIfInvalid = newNick.value
  startLogin({ nick = newNick.value })
  removeModalWindow(LOGIN_WND_UID)
}

let inputOptions = {
  size = [flex(), commonBtnHeight]
  textmargin = hdpx(7)
  colors = { backGroundColor = Color(0, 0, 0, 255) }
  valignText = ALIGN_CENTER
  margin = 0
  onReturn = loginWithNick
}.__update(fontBody)

let wndHeader = {
  flow = FLOW_VERTICAL
  gap = midPadding
  halign = ALIGN_CENTER
  vplace = ALIGN_TOP
  children = [
    @(){
      watch = wndHeaderTxt
      rendObj = ROBJ_TEXT
      text = wndHeaderTxt.value
    }.__update(fontHeading2)
    @(){
      watch = additionalTxt
      rendObj = ROBJ_TEXTAREA
      size = [sw(100), SIZE_TO_CONTENT]
      halign = ALIGN_CENTER
      maxWidth = maxContentWidth - hdpx(100)
      behavior = Behaviors.TextArea
      text = additionalTxt.value
    }.__update(fontBody)
  ]
}

let inputBlock = @(){
  watch = [newNick, isLoginInProgress]
  rendObj = ROBJ_SOLID
  padding = hdpx(20)
  size = [flex(), sh(50)]
  vplace = ALIGN_CENTER
  color = Color(0,0,0, 210)
  gap = hdpx(20)
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = isLoginInProgress.value ? waitingSpinner : [
    wndHeader
    {
      size = [hdpx(500), SIZE_TO_CONTENT]
      children = textInput(newNick, inputOptions)
    }
    Bordered(loc("Ok"), loginWithNick, {
      vplace = ALIGN_BOTTOM
      isEnabled = newNick.value != ""
    })
  ]
}

let wndContent = @(){
  watch = safeAreaBorders
  size = flex()
  children = [
    fontIconButton("power-off", {
      onClick = exitGameMsgBox
      hplace = ALIGN_RIGHT
      margin = safeAreaBorders.value[1]
      hotkeys = [[$"^{JB.B} | Esc"]]
    })
    inputBlock
  ]
}

let mkNickInputWnd = {
  key = LOGIN_WND_UID
  onClick = @() null
  size = flex()
  rendObj = ROBJ_IMAGE
  image = Picture("ui/stalingrad_login_screen_blured.avif")
  keepAspect = KEEP_ASPECT_FILL
  children = wndContent
}

function onInterrupt(state) {
  isLoginInProgress(false)
  additionalTxt(state?.stageResult?[WE_GAME_ID]?.message ?? "")
  if (state?.status == auth.YU2_NOT_FOUND){
    wndHeaderTxt(loc("wegame/pasteNick"))
    addModalWindow(mkNickInputWnd)
    state.params.needShowError <- @(...) false
  }
  else if (state?.status == auth.YU2_UPDATE){
    addModalWindow(mkNickInputWnd)
    wndHeaderTxt(loc("wegame/invalidNick", {nick = nickToShowIfInvalid}))
    state.params.needShowError <- @(...) false
  }

  defLoginCb.onInterrupt(state)
}

return {
  onSuccess = @(state) defLoginCb.onSuccess(state)
  onInterrupt
}
