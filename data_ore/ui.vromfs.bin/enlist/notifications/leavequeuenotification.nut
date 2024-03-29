from "%enlSqGlob/ui/ui_library.nut" import *

let msgbox = require("%enlist/components/msgbox.nut")
let {leaveQueue, isInQueue} = require("%enlist/quickMatchQueue.nut")
let JB = require("%ui/control/gui_buttons.nut")

const MSG_UID = "leave_queue_msgbox"

function leaveQueueNotification(watch, setValue = null, askLeave = @() true) {
  setValue = setValue ?? @(v) watch(v)
  local last = watch.value

  function showLeaveMsgBox() {
    if (msgbox.isMsgboxInList(MSG_UID))
      return
    msgbox.show({
      uid = MSG_UID
      text = loc("msg/cancel_queue_question"),
      buttons = [
        { text = loc("Ok"),
          action = @() leaveQueue()
          isCurrent = true
        }
        { text = loc("Cancel")
          action = @() setValue(last)
          isCancel = true
          customStyle = { hotkeys = [[$"^{JB.B} | Esc"]] }
        }
      ]
    })
  }

  isInQueue.subscribe(function(val) {
    if (val)
      return
    msgbox.removeMsgboxByUid(MSG_UID)
    last = watch.value
  })

  watch.subscribe(function(val) {
    if (val == last)
      return
    if (!isInQueue.value) {
      last = val
      return
    }
    if (askLeave())
      showLeaveMsgBox()
  })
}

return kwarg(leaveQueueNotification)
