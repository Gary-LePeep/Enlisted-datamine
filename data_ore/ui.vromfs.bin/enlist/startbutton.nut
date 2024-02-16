from "%enlSqGlob/ui_library.nut" import *

let { fontHeading2, fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let { titleTxtColor, accentColor, defTxtColor, startBtnWidth, leftAppearanceAnim, weakTxtColor,
  midPadding
} = require("%enlSqGlob/ui/designConst.nut")
let { isInBattleState } = require("%enlSqGlob/inBattleState.nut")
let { leaveQueue, isInQueue } = require("%enlist/quickMatchQueue.nut")
let { joinQueue, queuesCampaignsData } = require("quickMatch.nut")
let { leaveRoom, room } = require("%enlist/state/roomState.nut")
let { showCreateRoom } = require("mpRoom/showCreateRoom.nut")
let { MsgMarkedText }  = require("%ui/style/colors.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { curUnfinishedBattleTutorial } = require("%enlist/tutorial/battleTutorial.nut")
let gameLauncher = require("%enlist/gameLauncher.nut")
let { currentGameMode } = require("%enlist/gameModes/gameModeState.nut")
let { isInSquad, isSquadLeader, allMembersState, squadSelfMember,
  myExtSquadData, unsuitableCrossplayConditionMembers, getUnsuitableVersionConditionMembers
} = require("%enlist/squad/squadManager.nut")
let { showCurNotReadySquadsMsg } = require("soldiers/model/notReadySquadsState.nut")
let { curCampaign } = require("%enlist/meta/curCampaign.nut")
let { gameProfile } = require("%enlist/soldiers/model/config/gameProfile.nut")
let { showMsgbox, showMessageWithContent } = require("%enlist/components/msgbox.nut")
let checkbox = require("%ui/components/checkbox.nut")
let colorize = require("%ui/components/colorize.nut")
let { contacts } = require("%enlist/contacts/contact.nut")
let { remap_nick } = require("%enlSqGlob/remap_nick.nut")
let mkActiveBoostersMark = require("%enlist/mainMenu/mkActiveBoostersMark.nut")
let { showSquadMembersCrossPlayRestrictionMsgBox, showSquadVersionRestrictionMsgBox
} = require("%enlist/restrictionWarnings.nut")
let { Flat } = require("%ui/components/txtButton.nut")
let mkGlare = require("%enlist/components/mkGlareAnim.nut")
let { realCurrencies } = require("%enlist/shop/armyShopState.nut")
let { setCurSection } = require("%enlist/mainMenu/sectionsState.nut")
let { setDontShowToday, getDontShowToday, mkDontShowTodayComp
} = require("%enlist/options/dontShowAgain.nut")
let { updateBROnMatchStart } = require("%enlist/soldiers/armySquadTier.nut")
let { getCampaignTitle } = require("%enlSqGlob/ui/itemsInfo.nut")
let { getRomanNumeral } = require("%sqstd/math.nut")
let { mkHotkey } = require("%ui/components/uiHotkeysHint.nut")

const DONT_SHOW_TODAY_ID = "silver_full"

let defStartTxtStyle = {
  defTextColor = titleTxtColor
  hoverTextColor = accentColor
  activeTextColor = titleTxtColor
}

let leaveMatchTxtStyle = {
  defTextColor = defTxtColor
  hoverTextColor = titleTxtColor
  activeTextColor = defTxtColor
  txtParams = {
    rendObj = ROBJ_TEXTAREA
    behavior = Behaviors.TextArea
    size = [pw(70), SIZE_TO_CONTENT]
    halign = ALIGN_CENTER
  }.__update(fontHeading2, { lineSpacing = hdpx(-4) })
}


let defBtnBg = Picture("ui/uiskin/startBtn/start_btn_regular.avif")
let hoverBtnBg = Picture("ui/uiskin/startBtn/start_btn_hover.avif")
let activeBtnBg = Picture("ui/uiskin/startBtn/start_btn_active.avif")
let defPressedBtnBg = Picture("ui/uiskin/startBtn/start_btn_pressed_regular.avif")
let hoverPressedBtnBg = Picture("ui/uiskin/startBtn/start_btn_pressed_hover.avif")
let activePressedBtnBg = Picture("ui/uiskin/startBtn/start_btn_pressed_active.avif")


let defStartBgStyle = {
  defBg = defBtnBg
  hoverBg = hoverBtnBg
  activeBg = activeBtnBg
}

let leaveMatchBgStyle = {
  defBg = defPressedBtnBg
  hoverBg = hoverPressedBtnBg
  activeBg = activePressedBtnBg
}


let blinkAnimation = [{prop = AnimProp.color, from = 0x00F27272 , to = 0x44AA7272, duration = 3,
  loop = true, play = true, easing = CosineFull }]

let brValue = function() {
  let { brMin, brMax } = queuesCampaignsData.value
  let res = { watch = queuesCampaignsData }
  if (brMin == null)
    return res
  return res.__update({
    rendObj = ROBJ_TEXT
    color = weakTxtColor
    text = brMin == brMax
      ? loc("start/br", { br = getRomanNumeral(brMin) })
      : loc("start/brRange", { brMin = getRomanNumeral(brMin),
          brMax = getRomanNumeral(brMax) })
  }, fontSub)
}

let btnHeight = hdpxi(94)
let function btnCtor(text, action, params = {}) {
  let { defTextColor, hoverTextColor, activeTextColor, txtParams = fontHeading2 } = params.txtStyle
  let { bgStyle, hotkeys = null } = params
  let txtCtor = @(_txt, txtCtorParams, _handler, _group, sf) {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    children = [
      {
        size = [0, SIZE_TO_CONTENT]
        padding = midPadding
        vplace = ALIGN_CENTER
        children = mkHotkey((sf & S_HOVER) || (sf & S_ACTIVE) ? $"^{JB.A}" : hotkeys, action)
      }
      {
        flow = FLOW_VERTICAL
        size = [flex(), SIZE_TO_CONTENT]
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        children = [
          leaveMatchTxtStyle.txtParams.__merge({
            rendObj = ROBJ_TEXTAREA
            text
            size = [flex(), SIZE_TO_CONTENT]
          }, txtCtorParams)
          brValue
        ]
      }
    ]
  }
  return Flat(txtCtor, action, {
    btnWidth = startBtnWidth
    btnHeight
    style = {
      defTxtColor = defTextColor
      hoverTxtColor = hoverTextColor
      activeTxtColor = activeTextColor
    }
    txtParams
    bgComp = function(sf, _isEnabled = true) {
      let { defBg, hoverBg, activeBg } = bgStyle
      let isActive = sf & S_ACTIVE
      return {
        key = $"{isActive}"
        size = flex()
        rendObj = ROBJ_IMAGE
        image = sf & S_ACTIVE ? activeBg
          : sf & S_HOVER ? hoverBg
          : defBg
        animations = [
          { prop = AnimProp.opacity, from = 0.0, to = 1.0, duration = 0.3, play = true }
          { prop = AnimProp.opacity, from = 1.0, to = 0.0, duration = 0.3, playFadeOut = true }
        ]
      }
    }
  })
}

let function quickMatchFn() {
  if (room.value)
    leaveRoom()
  showCreateRoom.update(false)
  if (currentGameMode.value.queues.len() > 0)
    joinQueue(currentGameMode.value)
}

let function onLeaveQueuePressed() {
  myExtSquadData.ready(false)
  leaveQueue()
}

let leaveQuickMatchButton = btnCtor(loc("Leave queue"), onLeaveQueuePressed,
  {
    bgStyle = leaveMatchBgStyle
    txtStyle = leaveMatchTxtStyle
    hotkeys = $"^{JB.B} | Esc"
  })


let function checkPlayAvailability() {
  if (isSquadLeader.value && unsuitableCrossplayConditionMembers.value.len() != 0) {
    showSquadMembersCrossPlayRestrictionMsgBox(unsuitableCrossplayConditionMembers.value)
    return
  }

  let unsuitableByVersion = getUnsuitableVersionConditionMembers(currentGameMode.value)
  if (unsuitableByVersion.len() != 0) {
    showSquadVersionRestrictionMsgBox(unsuitableByVersion.values())
    return
  }

  let campaign = curCampaign.value
  let lockedUserIds = allMembersState.value
    .filter(@(m) !(m?.unlockedCampaigns ?? []).contains(campaign))
    .keys()
  if (lockedUserIds.len() > 0) {
    showMsgbox({
      text = loc("msg/cantGoBattle/membersCampaignLocked", {
        campaign = colorize(MsgMarkedText, getCampaignTitle(campaign))
        membersList = colorize(MsgMarkedText,
          ", ".join(lockedUserIds.map(@(userId)
            remap_nick(contacts.value[userId.tostring()]?.realnick))))
      })
    })
    return
  }

  if (!getDontShowToday(DONT_SHOW_TODAY_ID)) {
    let curSilver = realCurrencies.value?["enlisted_silver"] ?? 0
    let { silverCurrencyLimit = 0 } = gameProfile.value
    if (silverCurrencyLimit - curSilver < silverCurrencyLimit * 0.1) {
      let dontShowMeToday = mkDontShowTodayComp(DONT_SHOW_TODAY_ID)
      let text = curSilver >= silverCurrencyLimit
        ? loc("msg/silverFull")
        : loc("msg/silverAlmostFull")
      let dontShowCheckbox = checkbox(dontShowMeToday, loc("dontShowMeAgainToday"), {
        setValue = @(v) setDontShowToday(DONT_SHOW_TODAY_ID, v)
        override = {
          vplace = ALIGN_BOTTOM
        }
        hotkeys = [["^J:RS.Tilted"]]
      })
      let silverLimitContent = {
        uid = "silverLimitMsgbox"
        content = {
          minHeight = fsh(32)
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          children = [
            {
              rendObj = ROBJ_TEXTAREA
              maxWidth = sw(60)
              behavior = Behaviors.TextArea
              halign = ALIGN_CENTER
              text
            }.__update(fontHeading2)
            dontShowCheckbox
          ]
        }
        buttons = [
          {
            text = loc("btnGoShop")
            action = @() setCurSection("SHOP")
            customStyle = { hotkeys = [["^J:X"]] }
          }
          {
            text = loc("btnStartAnyway")
            action = @() showCurNotReadySquadsMsg(quickMatchFn)
            customStyle = { hotkeys = [["^J:Y"]] }
          }
        ]
      }
      showMessageWithContent(silverLimitContent)
      return
    }
  }

  showCurNotReadySquadsMsg(quickMatchFn)
}


let function startQuickMatchFunc() {
  updateBROnMatchStart()
  myExtSquadData.ready(true)
  checkPlayAvailability()
}


let function mkJoinQuickMatchButton() {
  return btnCtor(loc("START"), startQuickMatchFunc,
    {
      bgStyle = defStartBgStyle
      txtStyle = defStartTxtStyle
      hotkeys = "^J:Y"
      animations = blinkAnimation
    })
}


let quickMatchButton = @() {
  watch = isInQueue
  children = isInQueue.value
    ? leaveQuickMatchButton
    : mkJoinQuickMatchButton()
}


let quickMatchBtn = btnCtor(loc("START"), startQuickMatchFunc,
  {
    bgStyle = defStartBgStyle
    txtStyle = defStartTxtStyle
    hotkeys = "^J:Y"
    animations = blinkAnimation
  })


let pressWhenReadyBtn = btnCtor(loc("Press when ready"),
  @() showCurNotReadySquadsMsg(function() {
    updateBROnMatchStart()
    myExtSquadData.ready(true)
  }),
  {
    bgStyle = defStartBgStyle
    txtStyle = leaveMatchTxtStyle.__merge({ defTextColor = titleTxtColor })
    hotkeys = "^J:Y"
    animations = blinkAnimation
  })

let setNotReadyBtn = btnCtor(loc("Set not ready"), @() myExtSquadData.ready(false),
  {
    bgStyle = leaveMatchBgStyle
    txtStyle = leaveMatchTxtStyle
    hotkeys = $"^{JB.B}"
  })

isInBattleState.subscribe(function(inBattle) {
  if (!inBattle) {
    myExtSquadData.ready(false)
  }
})

let function squadMatchButton(){
  local btn = isInQueue.value ? leaveQuickMatchButton : quickMatchBtn
  if (!isSquadLeader.value && squadSelfMember.value != null)
    btn = myExtSquadData.ready.value ? setNotReadyBtn : pressWhenReadyBtn
  return {
    watch = [isInQueue, isSquadLeader, squadSelfMember, myExtSquadData.ready]
    children = btn
  }
}


let startTutorial = @() gameLauncher.startGame({
  game = "enlisted", scene = curUnfinishedBattleTutorial.value
})

let startTutorialBtn = btnCtor(loc("TUTORIAL"), startTutorial,
  {
    bgStyle = defStartBgStyle
    txtStyle = defStartTxtStyle
    hotkeys = "^J:Y"
    animations = blinkAnimation
  })

let startLocalGameMode = @() gameLauncher.startGame({
  game = "enlisted", scene = currentGameMode.value?.queues[0].scenes[0]
})

let localGameBtn = btnCtor(loc("START"), startLocalGameMode,
  {
    bgStyle = defStartBgStyle
    txtStyle = defStartTxtStyle
    hotkeys = "^J:Y"
    animations = blinkAnimation
  })

let startBtn = @() {
  watch = [curUnfinishedBattleTutorial, isInSquad, currentGameMode]
  children = [
    isInSquad.value ? squadMatchButton
      : curUnfinishedBattleTutorial.value != null ? startTutorialBtn
      : currentGameMode.value?.isLocal ? localGameBtn
      : quickMatchButton
    mkGlare({
      nestWidth = startBtnWidth
      glareWidth = hdpx(124)
      glareDuration = 0.7
      glareOpacity = 0.5
      glareDelay = 5
    })
    isInSquad.value || (!curUnfinishedBattleTutorial.value && !currentGameMode.value?.isLocal)
      ? mkActiveBoostersMark({ hplace = ALIGN_RIGHT, vplace = ALIGN_CENTER, pos = [hdpxi(20), 0] })
      : null
  ]
}.__update(leftAppearanceAnim(0.1))

return startBtn
