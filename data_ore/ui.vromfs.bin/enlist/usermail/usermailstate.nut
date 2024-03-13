from "%enlSqGlob/ui/ui_library.nut" import *

let { usermail_check, usermail_list, usermail_take_reward, usermail_reset_reward
} = require("%enlist/meta/clientApi.nut")
let serverTime = require("%enlSqGlob/userstats/serverTime.nut")
let { isInBattleState } = require("%enlSqGlob/inBattleState.nut")
let { eventbus_subscribe, eventbus_send } = require("eventbus")
let { sound_play } = require("%dngscripts/sound_system.nut")
let { subscribe } = require("%enlSqGlob/ui/notifications/matchingNotifications.nut")
let userInfo = require("%enlSqGlob/userInfo.nut")

const MAX_AMOUNT = 20
let MAX_LIFETIME = 30 * 24 * 60 * 60
const soundNewMail = "ui/enlist/notification"

let letters = mkWatched(persist, "letters", [])
let lastTime = mkWatched(persist, "lastTime", 0)

let isRequest = Watched(false)
let isUsermailWndOpened = mkWatched(persist, "isUsermailWndOpened", false)
let selectedLetterIdx = mkWatched(persist, "selectedLetterIdx", -1)
let unseenLettersCount = mkWatched(persist, "unseenLettersCount", 0)

serverTime.subscribe(function(ts) {
  if (ts <= 0)
    return
  serverTime.unsubscribe(callee())
  lastTime(ts - MAX_LIFETIME)
})

function markUnseenLetters(count) {
  if (isRequest.value)
    return
  unseenLettersCount(count)
  if (!isInBattleState.value)
    sound_play(soundNewMail)
}

let function onCheckMail(result) {
  isRequest(false)
  let { newMailCount = 0 } = result
  if (newMailCount > 0)
    markUnseenLetters(newMailCount)
}

let function checkNewMail() {
  if (isRequest.value)
    return
  isRequest(true)
  usermail_check(lastTime.value, onCheckMail)
}

let isDataReady = keepref(Computed(@() userInfo.value != null && lastTime.value > 0))
isDataReady.subscribe(function(value) {
  if (value)
    checkNewMail()
})

eventbus_subscribe("matching.notify_new_mail", @(...) checkNewMail())
subscribe("profile", @(event) event?.func == "newmail" ? checkNewMail() : null)

function closeUsermailWindow() {
  isUsermailWndOpened(false)
  unseenLettersCount(0)
  selectedLetterIdx(-1)
}

function onLettersUpdate(result) {
  isRequest(false)
  let { usermail = [] } = result
  if (usermail.len() == 0)
    return

  letters.mutate(function(list) {
    foreach (letter in usermail) {
      let idx = list.findindex(@(prev) prev.guid == letter.guid)
      if (idx == null)
        list.append(letter)
      else
        list[idx] = letter
    }
    list.sort(@(a, b) b.cTime <=> a.cTime)
  })
}

function requestLetters(forceUpdate = false) {
  if (isRequest.value)
    return

  isRequest(true)
  let ts = lastTime.value
  lastTime(serverTime.value)
  usermail_list(forceUpdate ? 0 : ts, MAX_AMOUNT, onLettersUpdate)
}

function takeLetterReward(guid) {
  if (isRequest.value)
    return

  isRequest(true)
  usermail_take_reward(guid, onLettersUpdate)
}


console_register_command(@() requestLetters(true), "usermail.request")
console_register_command(takeLetterReward, "usermail.getReward")
console_register_command(@() usermail_reset_reward(onLettersUpdate), "usermail.resetReward")
console_register_command(
  function(reward) {
    let letter = {
      guid = serverTime.value
      text = $"New mail received, mail in mailbox № {letters.value.len() + 1}"
      cTime = serverTime.value
    }
    if (reward != null && reward.tointeger() > 0)
      letter.__update({
        reward
        endTime = serverTime.value + 1000
      })
    letters.mutate(@(v) v.insert(0, letter))
    eventbus_send("matching.notify_new_mail", null)
  },
  "usermail.newMail"
)

return {
  letters
  requestLetters
  takeLetterReward
  isRequest
  isUsermailWndOpened
  selectedLetterIdx
  closeUsermailWindow
  unseenLettersCount
}
