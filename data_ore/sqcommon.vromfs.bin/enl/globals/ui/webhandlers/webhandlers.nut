let {exit_game} = require("app")
let {subscribe} = require("%enlSqGlob/ui/notifications/matchingNotifications.nut")
let { showMsgbox, removeMsgboxByUid } = require("%ui/components/msgbox.nut")
let { eventbus_send, eventbus_subscribe, eventbus_send_foreign } = require("eventbus")

let handlers = {
  function show_message_box(_ev, params) {
    let { message = null, logout_on_close = false } = params
    if (message == null)
      return
    showMsgbox({
      uid = message
      text = message
      onClose = logout_on_close ? exit_game
        : @() eventbus_send_foreign("webHandlers.removeMsg", { message })
    })
  }
  replay_start = @(_ev, params) eventbus_send("replay.download", params)
  hangar_install = @(_ev, params) eventbus_send("hangar.install", params)
}

subscribe("web-service", @(ev) handlers?[ev?.func](ev, ev?.params ?? {}))
eventbus_subscribe("webHandlers.removeMsg", @(msg) removeMsgboxByUid(msg.message))
