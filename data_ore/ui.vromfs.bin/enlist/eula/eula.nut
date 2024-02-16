from "%enlSqGlob/ui_library.nut" import *

let { fontHeading2, fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let eulaLog = require("%enlSqGlob/library_logs.nut").with_prefix("[EULA]")
let colors = require("%ui/style/colors.nut")
let platform = require("%dngscripts/platform.nut")
let msgbox = require("%ui/components/msgbox.nut")
let {makeVertScroll, thinStyle} = require("%ui/components/scrollbar.nut")
let {safeAreaSize} = require("%enlist/options/safeAreaState.nut")
let {read_text_from_file, file_exists} = require("dagor.fs")
let { loadJson } = require("%sqstd/json.nut")
let { gameLanguage } = require("%enlSqGlob/clientState.nut")
let JB = require("%ui/control/gui_buttons.nut")
let {hotkeysBarHeight} = require("%ui/hotkeysPanel.nut")
let {processHypenationsCN = @(v) v, processHypenationsJP = @(v) v} = require("dagor.localize")
let { nestWatched } = require("%dngscripts/globalState.nut")

const NO_VERSION = -1

let json_load = @(file) loadJson(file, { logger = eulaLog, load_text_file = read_text_from_file})

let function loadConfig(fileName) {
  let config = file_exists(fileName) ? json_load(fileName) : null
  local curLang = gameLanguage.tolower()
  if (!(curLang in config))
    curLang = "english"
  return {
    version = config?[curLang]?.version ?? NO_VERSION
    filePath = config?[curLang]?.file
  }
}

let eula = loadConfig("content/enlisted/eula/eula.json")

eulaLog("language:", gameLanguage)
eulaLog("eula config:", eula)

let postProcessEulaText = platform.is_sony
  ? function() {
    let ps4 = require("ps4")
    return function(text) {
      local eulaTxt = text
      let lang = gameLanguage.tolower()
      if (lang.contains("chinese"))
        eulaTxt = processHypenationsCN(eulaTxt)
      else if (lang.contains("japanese"))
        eulaTxt = processHypenationsJP(eulaTxt)
      let regionKey = ps4.get_region() == ps4.SCE_REGION_SCEA ? "scea" : "scee"
      let regionText = loc($"sony/{regionKey}")
      return $"{eulaTxt}{regionText}"
    }
  }()
  : function(text) {
    local eulaTxt = text
    if (gameLanguage.tolower().contains("chinese"))
      eulaTxt = processHypenationsCN(eulaTxt)
    else if (gameLanguage.tolower().contains("japanese"))
      eulaTxt = processHypenationsJP(eulaTxt)
    return eulaTxt
  }

let customStyleA = {hotkeys=[[$"^J:X | Enter | Space", {description={skip=true}}]]}
let customStyleB = {hotkeys=[[$"^Esc | {JB.B}", {description={skip=true}}]]}
let customStyleOK = {hotkeys=[[$"^Esc | {0} | Enter | Space | {JB.B} | {JB.A} | J:X", {description={skip=true}}]]}
let customStyleNoChoice = {hotkeys=[[$"^Esc | {0} | Enter | Space | J:X", {description={skip=true}}]]}

const FORCE_EULA = "FORCE_EULA"

let forcedMsgBoxStyle = (clone msgbox.msgboxDefStyle)
forcedMsgBoxStyle.rawdelete("closeKeys")

let function show(version, filePath, decisionCb=null, isUpdated=false) {
  if (version == NO_VERSION || filePath == null) {
    // accept if there is no EULA
    if (decisionCb)
      decisionCb?(true)
    return
  }
  local eulaTxt = read_text_from_file(filePath)
  eulaTxt = postProcessEulaText("\x09".join(eulaTxt.split("\xE2\x80\x8B")))
  let isForced = FORCE_EULA==isUpdated
  //!!FIX ME: better to count max height by msgBox self, and do not reserve place for buttons here
  let eulaSize = Computed(@() [safeAreaSize.value[0] - (platform.is_mobile ? fsh(10) : 0), safeAreaSize.value[1] - fsh(15) - hotkeysBarHeight.value])

  let eulaUiContent = @() {
    watch = [eulaSize]
    size = eulaSize.value
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    children = [
      {rendObj = ROBJ_TEXT text = loc(isUpdated && !isForced ? "LegalsUpdated" : "Legals") hplace = ALIGN_CENTER}.__update(fontHeading2)
      makeVertScroll({
        size = [eulaSize.value[0], SIZE_TO_CONTENT]
        halign = ALIGN_LEFT
        children = {
          size = [eulaSize.value[0] - hdpx(20), SIZE_TO_CONTENT]
          rendObj = ROBJ_TEXTAREA
          behavior = Behaviors.TextArea
          color = colors.BtnTextNormal
          text = eulaTxt
        }.__update(sh(100) <= 720 ? fontHeading2 : fontBody)
      }, {
        size = flex()
        styling = thinStyle
        needReservePlace = false
        maxHeight = eulaSize.value[1]
        wheelStep = 30
      })
    ]
  }

  let eulaUi = {
    uid = "eula"
    content = eulaUiContent
  }

  if (isUpdated || decisionCb==null) {
    eulaUi.buttons <- [
      {
        text = isForced ? loc("eula/accept") : loc("Ok")
        isCurrent = true
        action = @() decisionCb?(true)
        customStyle = isForced ? customStyleNoChoice : customStyleOK
      }
    ]
  }
  else {
    eulaUi.buttons <- [
      {
        text = loc("eula/accept")
        isCurrent = true
        action = @() decisionCb(true)
        customStyle = customStyleA
      },
      {
        text = loc("eula/reject")
        isCancel = true
        action = @() decisionCb(false)
        customStyle = customStyleB
      }
    ]
  }
  msgbox.showMessageWithContent(eulaUi, isForced ? forcedMsgBoxStyle : null)
}

let showEula = @(cb, isUpdated=false) show(eula.version, eula.filePath, cb, isUpdated)

console_register_command(@() showEula(@(a) log_for_user($"Result: {a}"), true), "eula.showUpdated")
console_register_command(@() showEula(@(a) log_for_user($"Result: {a}"), false), "eula.showNewUser")
console_register_command(@() showEula(null), "eula.showManualOpen")

let acceptedEulaVersionBeforeLogin = nestWatched("acceptedEulaBeforeLogin", null)

return {
  showEula = showEula
  eulaVersion = eula.version
  acceptedEulaVersionBeforeLogin
  FORCE_EULA
}
