import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui/ui_library.nut" import *

let { mkCmdChatMessage } = require("%enlSqGlob/sqevents.nut")

function sendChatMsg(params) { //should be some enum
  let evt = mkCmdChatMessage(params)
  ecs.client_msg_sink(evt)
}

function sendQuickChatSoundMsg(text, qmsg = null, sound = null) {
  sendChatMsg({mode = "qteam", text = text, qmsg = qmsg, sound = sound})
}

function sendQuickChatItemMsg(text, item_name=null) {
  sendChatMsg({mode="qteam", text = text, qmsg={item=item_name}})
}

function sendItemHint(item_name, item_eid, item_count, item_owner_nickname) {
  sendChatMsg({mode="qteam", text= "squad/item_hint", qmsg={item=item_name, count = item_count, nickname = item_owner_nickname}, eid = item_eid/*, showOnMap = true*/})
}

return {
  sendQuickChatSoundMsg
  sendQuickChatMsg = sendQuickChatItemMsg
  sendQuickChatItemMsg = sendQuickChatItemMsg
  sendItemHint = sendItemHint
}