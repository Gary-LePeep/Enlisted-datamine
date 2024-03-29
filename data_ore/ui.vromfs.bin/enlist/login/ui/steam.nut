from "%enlSqGlob/ui/ui_library.nut" import *

let { fontHeading2, fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let background = require("background.nut")
let textButton = require("%ui/components/textButton.nut")
let progressText = require("%enlist/components/progressText.nut")
let regInfo = require("reginfo.nut")
let supportLink = require("supportLink.nut")

let { startLogin, currentStage, resetCurrentStage } = require("%enlist/login/login_chain.nut")
let { linkSteamAccount, isSteamFirstOpen, isSteamConnectionLost
} = require("%enlSqGlob/ui/login_state.nut")

let fontIconButton = require("%ui/components/fontIconButton.nut")
let { safeAreaBorders } = require("%enlist/options/safeAreaState.nut")
let {exitGameMsgBox} = require("%enlist/mainMsgBoxes.nut")

function createSteamAccount() {
  let onlyKnown = isSteamConnectionLost.value
  isSteamConnectionLost(false)
  if (!linkSteamAccount.value) { //when linkSteamAccount, opens other ui, but we can still receive button onClick from the previous
    if (currentStage.value != null)
      resetCurrentStage()

    startLogin({onlyKnown})
  }
}

function onOpen() {
  if (!isSteamFirstOpen.value)
    return
  isSteamFirstOpen(false)
  startLogin({onlyKnown = true})
}

let steamLoginBtn = textButton(loc("steam/loginWithoutGaijinNet"), createSteamAccount, fontSub)

function createLoginForm() {
  return [
    {
      vplace = ALIGN_BOTTOM
      halign = ALIGN_CENTER
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      gap = hdpx(10)
      children = [
        steamLoginBtn
      ]
    }
    regInfo
  ]
}

let centralContainer = @(children = null, watch = null, size = null) {
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  size = size
  watch = watch
  children = children
}

function loginRoot() {
  onOpen()
  let size = [fsh(40), fsh(40)]
  let watch = [currentStage]

  if (currentStage.value)
    return centralContainer(
      progressText(loc("loggingInProcessSteam")), watch, size)

  return centralContainer(createLoginForm(), watch, size)
}

let headerHeight = calc_comp_size({size=SIZE_TO_CONTENT children={margin = [fsh(1), 0] size=[0, fontH(100)] rendObj=ROBJ_TEXT}.__update(fontHeading2)})[1]*0.75

return {
 size = flex()
 children = [
  background
  loginRoot
  supportLink
  {
      size = [headerHeight, headerHeight]
      hplace = ALIGN_RIGHT
      margin = safeAreaBorders.value[1]
      children = fontIconButton("power-off", { onClick = exitGameMsgBox })
    }
 ]
}

