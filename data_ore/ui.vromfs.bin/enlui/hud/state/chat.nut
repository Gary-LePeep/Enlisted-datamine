import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui/ui_library.nut" import *

let { EventSqChatMessage, mkCmdChatMessage } = require("%enlSqGlob/sqevents.nut")
let { setIntervalForUpdateFunc } = require("%ui/helpers/timers.nut")
let { INVALID_USER_ID } = require("matching.errors")
let { TEAM_UNASSIGNED } = require("team")
let { blocklist } = require("%enlSqGlob/blocklist.nut")
let { canInterractCrossPlatform } = require("%enlSqGlob/platformUtils.nut")
let obsceneFilter = require("%enlSqGlob/obsceneFilter.nut")

let lines = mkWatched(persist, "lines", [])
let totalLines = mkWatched(persist, "totalLines", 0)
let logState = mkWatched(persist, "logState", [])
let outMessage = mkWatched(persist, "outMessage", "")
let sendMode = mkWatched(persist, "sendMode", "team")

function updateChat(dt) {
  foreach (rec in lines.value)
    rec.ttl -= dt
  let newLines = lines.value.filter(@(rec) rec.ttl > 0)
  if (newLines.len() != lines.value.len())
    lines(newLines)
}

setIntervalForUpdateFunc(0.45, updateChat)

function pushMsg(sender_team, name_from, user_id_from, text, send_mode, qmsg) {
  if ( user_id_from in blocklist.value
    || (qmsg == null && name_from != "" && !canInterractCrossPlatform(name_from, false)) )
    return

  totalLines.update(totalLines.value+1)
  let l = lines
  let MAX_LINES = 10
  let MAX_LOG_LINES = 1000
  let rec = {
    team = sender_team
    name = name_from
    userId = user_id_from
    text = text
    sendMode = send_mode
  }

  l.mutate(function(val) {
    val.append(rec.__merge({ttl=15.0}))
    if (val.len()>MAX_LINES) {
      val.remove(0)
    }
  })

  logState.mutate(function(val) {
    val.append(rec)
    if (val.len()>MAX_LOG_LINES) {
      val.remove(0)
    }
  })
}

function sendChatCmd(params = {mode="team", text=""}) {
  params = params.__merge({mode=params?.mode ?? "team"})
  let evt = mkCmdChatMessage(params)
  ecs.client_msg_sink(evt)
}


function sendMessage(params){
  obsceneFilter(params.text, function(filteredText) {
    params.text = filteredText
    sendChatCmd(params)
  })
}

function mkTextFromQchatMsg(data) {
  //currently KISS for team hints and usual msg. Text is used as loc id or text itself
  return (type(data?.qmsg) == "table")
      ? loc(data?.text ?? "", data.qmsg.__merge({item=loc(data.qmsg?.item ?? "", {count = data.qmsg?.count, nickname = data.qmsg?.nickname})}))
      : data?.text ?? ""
}

function onChatMessage(evt, _eid, _comp) {
  let data = evt?.data
  if (data==null)
    return

  let {
    qmsg = null,
    mode = "team",
    team = 0,
    name = "unknown",
    senderUserId = INVALID_USER_ID
  } = data

  let text = mkTextFromQchatMsg(data)
  pushMsg(team, name, senderUserId, text, mode, qmsg)
}

ecs.register_es("chat_client_es", {
    [EventSqChatMessage] = onChatMessage
  }, {comps_rq = ["msg_sink"]}
)

return {
  lines
  totalLines
  logState
  outMessage
  sendMode
  sendChatCmd

  update = updateChat
  pushMsg
  pushSystemMsg = @(msg) pushMsg(TEAM_UNASSIGNED, "", INVALID_USER_ID, msg, "system", null)
  sendMessage
}
