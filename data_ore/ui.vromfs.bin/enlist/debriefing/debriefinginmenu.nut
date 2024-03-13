from "%enlSqGlob/ui/ui_library.nut" import *

let ctor = require("%enlist/debriefing/debriefingCtor.nut")
let { dbgShow, dbgData } = require("debriefingDbgState.nut")
let { isInBattleState } = require("%enlSqGlob/inBattleState.nut")
let navState = require("%enlist/navState.nut")
let { show, data, clearData } = require("%enlist/debriefing/debriefingStateInMenu.nut")
let { openSteamReviewWnd } = require("%enlist/steam/steamRateWnd.nut")
let { isSteamRateWindowAvailable } = require("%enlist/steam/steamRateState.nut")
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

let closeAction = function() {
  if (dbgShow.value)
    dbgShow(false)
  else
    show(false)

  let battleResult = dataToShow.value?.result
  if (battleResult?.success && !battleResult.deserter && isSteamRateWindowAvailable.value)
    openSteamReviewWnd()
}
function debriefingWnd() {
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
function checkAndCloseDebr(){
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
