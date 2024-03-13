from "%enlSqGlob/ui/ui_library.nut" import *

let { fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let { sceneWithCameraAdd, sceneWithCameraRemove
} = require("%enlist/sceneWithCamera.nut")
let { midPadding, smallPadding, defInsideBgColor, defTxtColor, blurBgFillColor, activeTxtColor,
  maxContentWidth, airBgColor, opaqueBgColor
} = require("%enlSqGlob/ui/designConst.nut")
let { Bordered } = require("%ui/components/textButton.nut")
let { letters, requestLetters, takeLetterReward, isRequest, closeUsermailWindow, isUsermailWndOpened,
  selectedLetterIdx
} = require("%enlist/usermail/usermailState.nut")
let spinner = require("%ui/components/spinner.nut")
let { makeVertScroll, thinStyle } = require("%ui/components/scrollbar.nut")
let JB = require("%ui/control/gui_buttons.nut")
let serverTime = require("%enlSqGlob/userstats/serverTime.nut")
let rewardsItemMapping = require("%enlist/items/itemsMapping.nut")
let { mkSeasonTime, prepareRewards, mkRewardBlock } = require("%enlist/battlepass/rewardsPkg.nut")
let mkWindowTab = require("%enlist/components/mkWindowTab.nut")
let msgbox = require("%enlist/components/msgbox.nut")

let mailPadding = hdpx(15)
let mailmidPadding = hdpx(40)
let MAIL_WND_WIDTH = fsh(100)
let waitingSpinner = spinner()

let listBgColor = @(sf, isSelected) isSelected ? opaqueBgColor
  : sf & S_HOVER ? defInsideBgColor
  : blurBgFillColor
let listTxtColor = @(sf, isSelected) isSelected ? activeTxtColor
  : sf & S_HOVER ? Color(200,200,200)
  : defTxtColor

let noMessagesTitle = {
  rendObj = ROBJ_TEXT
  size = [flex(), SIZE_TO_CONTENT]
  halign = ALIGN_CENTER
  color = activeTxtColor
  text = loc("mail/no_messages")
}.__update(fontBody)

let expiredReward = @() msgbox.show({
  text = loc("mail/rewardExpired"),
  buttons = [{ text = loc("Ok"), isCurrent = true }]
})

function mkRewards(rewards, hasReceived = true) {
  if (rewards.len() == 0)
    return null

  return @() {
    watch = rewardsItemMapping
    size = [flex(), SIZE_TO_CONTENT]
    valign = ALIGN_CENTER
    flow = FLOW_HORIZONTAL
    gap = smallPadding
    children = prepareRewards(rewards, rewardsItemMapping.value)
      .map(@(reward) mkRewardBlock(reward, hasReceived))
  }
}

function messageRow(message, idx) {
  let { text, guid, cTime, isReceived = false, endTime = 0, rewards = [] } = message
  let hasTimeout = endTime != 0
  let timeToEnd = Computed(@() isReceived ? 0 : max(0, endTime - serverTime.value))
  let isSelected = Computed(@() selectedLetterIdx.value == idx)
  return watchElemState(function(sf) {
    if (cTime > serverTime.value)
      return null
    let cb = hasTimeout && timeToEnd.value == 0 ? expiredReward : @() takeLetterReward(guid)
    return {
      rendObj = ROBJ_SOLID
      watch = [selectedLetterIdx, timeToEnd, isSelected]
      size = [flex(), SIZE_TO_CONTENT]
      behavior = Behaviors.Button
      flow = FLOW_VERTICAL
      padding = mailPadding
      onClick = @() selectedLetterIdx(idx)
      gap = mailmidPadding
      clipChildren = true
      color = listBgColor(sf, isSelected.value)
      children = [
        {
          size = [flex(), SIZE_TO_CONTENT]
          flow = FLOW_HORIZONTAL
          children = [
            {
              rendObj = ROBJ_TEXTAREA
              behavior = Behaviors.TextArea
              size = [flex(), SIZE_TO_CONTENT]
              ellipsis = true
              textOverflowY = TOVERFLOW_LINE
              text = loc(text)
              color = listTxtColor(sf, isSelected.value)
            }.__update(fontBody)
            isReceived || timeToEnd.value == 0 ? null : mkSeasonTime(timeToEnd.value)
          ]
        }
        rewards.len() == 0 ? null : {
          size = [flex(), SIZE_TO_CONTENT]
          flow = FLOW_HORIZONTAL
          valign = ALIGN_BOTTOM
          gap = midPadding
          children = [
            mkRewards(rewards, isReceived)
            isReceived ? null : Bordered(loc("mainmenu/receive"), cb, { margin = 0 })
          ]
        }
      ]
    }
  })
}


let backBtn = Bordered(loc("BackBtn"), closeUsermailWindow, {
  margin = 0
  hotkeys = [[$"^{JB.B} | Esc", { description = loc("BackBtn") } ]]
})

let lettersBlock = @(lettrs) lettrs.len() <= 0 ? noMessagesTitle
  : makeVertScroll(
    {
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      gap = {
        rendObj = ROBJ_SOLID
        size = [flex(), hdpx(2)]
        color = airBgColor
      }
      children = lettrs.map(@(val, idx) messageRow(val, idx))
    },
    {
      size = flex()
      styling = thinStyle
    }
)

function centralBlock(){
  let children = []
  if (letters.value.len() > 0)
    children.append(lettersBlock(letters.value))
  else if (!isRequest.value)
    children.append(noMessagesTitle)
  if (isRequest.value)
    children.append(waitingSpinner)
  return {
    watch = [letters, isRequest]
    size = flex()
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    children = isRequest.value ? waitingSpinner : lettersBlock(letters.value)
  }
}

let mailTab = {
  id = "mailTab"
  locId = "mail/mailTab"
  content = centralBlock
}

let topBlock = mkWindowTab(loc(mailTab.locId), @() null, true)

let mailWindow = {
  size = [MAIL_WND_WIDTH, flex()]
  maxWidth = maxContentWidth
  hplace = ALIGN_CENTER
  padding = [fsh(5), 0]
  gap = hdpx(25)
  flow = FLOW_VERTICAL
  children = [
    topBlock
    centralBlock
    backBtn
  ]
}

function openMailWindow(){
  requestLetters()
  sceneWithCameraAdd(mailWindow, "events")
}

if (isUsermailWndOpened.value)
  openMailWindow()

isUsermailWndOpened.subscribe(@(v) v ? openMailWindow() : sceneWithCameraRemove(mailWindow))
