from "%enlSqGlob/ui_library.nut" import *

let ctor = require("%enlist/debriefing/debriefingCtor.nut")
let { dbgShow, dbgData } = require("debriefingDbgState.nut")
let { isInBattleState } = require("%enlSqGlob/inBattleState.nut")
let navState = require("%enlist/navState.nut")
let { show, data, clearData } = require("%enlist/debriefing/debriefingStateInMenu.nut")
let { update_profile } = require("%enlist/meta/clientApi.nut")


let dataToShow = Computed(@() dbgShow.value ? dbgData.value : data.value)

let needShow = keepref(Computed(@()
  !isInBattleState.value && dataToShow.value != null && (dbgShow.value || show.value)))


isInBattleState.subscribe(function(active) {
  if (!active)
    return
  clearData() //clear previous battle debriefing
  dbgShow(false)
})

let closeAction = @() dbgShow.value ? dbgShow(false) : show(false)
let function debriefingWnd() {
  let children = (!(dataToShow.value?.isFinal ?? true))
      ? null
      : ctor(dataToShow.value, closeAction)
  return {
    key = "enlist_debriefing_root"
    watch = dataToShow
    onAttach = @() children == null ? closeAction() : null
    size = flex()
    children
  }
}
let function checkAndCloseDebr(){
  if (needShow.value && !dataToShow.value?.isFinal)
    closeAction()
}
needShow.subscribe(
  function(val) {
    if (val) {
      gui_scene.resetTimeout(1, checkAndCloseDebr)
      navState.addScene(debriefingWnd)
      update_profile()
    }
    else {
      navState.removeScene(debriefingWnd)
      gui_scene.clearTimer(checkAndCloseDebr)
    }
  }
)

if (needShow.value) {
  navState.addScene(debriefingWnd)
  // this is a temporary solution until we figure out
  // why after battle isProfileChanged.value == false
  update_profile()
}

return { needShow, dataToShow }
