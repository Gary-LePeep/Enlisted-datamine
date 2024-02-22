from "%enlSqGlob/ui/ui_library.nut" import *

let { dgs_get_settings } = require("dagor.system")
let { file } = require("io")
let { switch_to_menu_scene } = require("app")
let { fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let { addModalWindow, removeModalWindow } = require("%ui/components/modalWindows.nut")
let { WindowTransparent } = require("%ui/style/colors.nut")
let { Bordered } = require("%ui/components/textButton.nut")
let { defInsideBgColor, commonBtnHeight, titleTxtColor } = require("%enlSqGlob/ui/viewConst.nut")
let { noteTextArea } = require("%enlSqGlob/ui/defcomps.nut")
let { httpRequest, HTTP_SUCCESS } = require("dagor.http")
let { eventbus_subscribe, eventbus_subscribe_onehit } = require("eventbus")
let spinner = require("%ui/components/spinner.nut")
let logHG = require("%enlSqGlob/library_logs.nut").with_prefix("[CustomHangar] ")

const EVENT_RECEIVE_HANGAR_MOD = "EVENT_RECEIVE_HANGAR_MOD"
const WND_UID = "hangarDownloadUi"

let defaultSize = [hdpx(432), hdpx(324)]
let waitingSpinner = spinner()
let errorTextState = Watched("")
let isDownloadInProgress = Watched(false)

let defTxtStyle = { color = titleTxtColor }.__update(fontBody)

let btnStyle = {
  margin = 0
  size = [SIZE_TO_CONTENT, commonBtnHeight]
  hplace = ALIGN_CENTER
  vplace = ALIGN_BOTTOM
}

let title = noteTextArea({
  size = [flex(), SIZE_TO_CONTENT]
  text = loc("hangar/Downloading")
  halign = ALIGN_CENTER
}).__update(defTxtStyle)

let content = @(message) {
  size = [flex(), SIZE_TO_CONTENT]
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  halign = ALIGN_CENTER
  margin = [hdpx(30), 0]
  vplace = ALIGN_CENTER
  text = message
}.__update(defTxtStyle)

let infoContainer = @() {
  watch = errorTextState
  size = defaultSize
  gap = hdpx(20)
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  flow = FLOW_VERTICAL
  padding = hdpx(20)
  fillColor = WindowTransparent
  borderRadius = hdpx(2)
  rendObj = ROBJ_WORLD_BLUR_PANEL
  transform = {}
  animations = [
    { prop=AnimProp.translate,  from=[0, sh(5)], to=[0,0], duration=0.5, play=true, easing=OutBack }
    { prop=AnimProp.opacity, from=0.0, to=1.0, duration=0.25, play=true, easing=OutCubic }
    { prop=AnimProp.translate, from=[0,0], to=[0, sh(30)], duration=0.7, playFadeOut=true, easing=OutCubic }
    { prop=AnimProp.opacity, from=1.0, to=0.0, duration=0.6, playFadeOut=true, easing=OutCubic }
  ]
  children = errorTextState.value == ""
    ? [
        title
        {
          size = flex()
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          flow = FLOW_VERTICAL
          children = waitingSpinner
        }
      ]
    : [
        title
        content(loc(errorTextState.value))
        {
          size = flex()
          flow = FLOW_HORIZONTAL
          halign = ALIGN_CENTER
          gap = hdpx(5)
          children = Bordered(loc("replay/Close"), @() removeModalWindow(WND_UID), btnStyle)
        }
      ]
}

let openDownloadModal = @() addModalWindow({
  key = WND_UID
  rendObj = ROBJ_WORLD_BLUR_PANEL
  fillColor = defInsideBgColor
  size = flex()
  valign = ALIGN_CENTER
  halign = ALIGN_CENTER
  stopMouse = true
  children = infoContainer
  onClick = @() null
})

eventbus_subscribe("hangar.install", function(params) {
  logHG($"Install request, download in progress = {isDownloadInProgress.value} params:", params)
  if (isDownloadInProgress.value)
    return

  let { url = null } = params
  if (url == null)
    return

  isDownloadInProgress(true)
  eventbus_subscribe_onehit(EVENT_RECEIVE_HANGAR_MOD, function(response) {
    logHG("received headers:", response?.headers)
    isDownloadInProgress(false)

    let { status, http_code } = response
    if (status != HTTP_SUCCESS || http_code == null || http_code >= 300 || http_code < 200) {
      logHG("request status =", status, http_code)
      errorTextState("mods/failedDownload")
      return
    }

    try {
      let body = response?.body
      let customHangarFile = dgs_get_settings()?.menu?.scene ?? ""
      let resultFile = file(customHangarFile, "wb+")
      resultFile.writeblob(body)
      resultFile.close()
      removeModalWindow(WND_UID)
      switch_to_menu_scene()
    }
    catch(e) {
      errorTextState("mods/failedToSave")
      logHG(e)
    }
  })

  openDownloadModal()
  httpRequest({
    method = "GET"
    url
    respEventId = EVENT_RECEIVE_HANGAR_MOD
  })
})
