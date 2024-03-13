from "%enlSqGlob/ui/ui_library.nut" import *

let {fontBody, fontSub, fontawesome} = require("%enlSqGlob/ui/fontsStyle.nut")
let fa = require("%ui/components/fontawesome.map.nut")
let faComp = require("%ui/components/faComp.nut")
let { smallPadding, midPadding, startBtnWidth, attentionTxtColor, titleTxtColor,
  activeTxtColor, soldierLvlColor
} = require("%enlSqGlob/ui/designConst.nut")
let { safeAreaSize, safeAreaBorders } = require("%enlist/options/safeAreaState.nut")
let { PrimaryFlat } = require("%ui/components/textButton.nut")
let { makeHorizScroll } = require("%ui/components/scrollbar.nut")
let { sceneWithCameraAdd, sceneWithCameraRemove } = require("%enlist/sceneWithCamera.nut")
let { curSelectedItem } = require("%enlist/showState.nut")
let {
  basicProgress, combinedUnlocks, nextUnlock,
  progressCounters, currentProgress, hasReward, receiveAllRewards, buyNextStage,
  nextUnlockPrice, buyUnlockInProgress, receiveRewardInProgress, seasonIndex
} = require("bpState.nut")
let { BP_INTERVAL_STARS } = require("%enlSqGlob/bpConst.nut")
let { premiumStage0Unlock } = require("%enlist/unlocks/taskRewardsState.nut")
let { hasEliteBattlePass, canBuyBattlePass } = require("eliteBattlePass.nut")
let { prepareRewards } = require("rewardsPkg.nut")
let { currencyBtn } = require("%enlist/currency/currenciesComp.nut")
let { purchaseMsgBox } = require("%enlist/currency/purchaseMsgBox.nut")
let {
  bpHeader, bpTitle, sizeCard, mkCard, btnSize, btnBuyPremiumPass, gapCards, lockScreen,
  mkBpIconBlock
} = require("bpPkg.nut")
let spinner = require("%ui/components/spinner.nut")
let eliteBattlePassWnd = require("eliteBattlePassWnd.nut")
let closeBtnBase = require("%ui/components/closeBtn.nut")
let { curArmy } = require("%enlist/soldiers/model/state.nut")
let {
  progressBarHeight, completedProgressLine, acquiredProgressLine,
  progressContainerCtor, gradientProgressLine, inactiveProgressCtor
} = require("%enlist/components/mkProgressBar.nut")
let { glareAnimation } = require("%enlSqGlob/ui/glareAnimation.nut")
let itemsMapping = require("%enlist/items/itemsMapping.nut")
let { commonArmy } = require("%enlist/meta/profile.nut")
let { allItemTemplates } = require("%enlist/soldiers/model/all_items_templates.nut")
let { isOpened, curItem, RewardState, unlockToShow, combinedRewards, curItemUpdate } = require("bpWindowState.nut")
let { scenesListGeneration, getTopScene } = require("%enlist/navState.nut")
let { serviceNotificationsList } = require("%enlSqGlob/serviceNotificationsList.nut")
let { mkDailyTasksUi } = require("%enlist/unlocks/taskWidgetUi.nut")
let weeklyTasksUi = require("%enlist/unlocks/weeklyTasksBtn.nut")
let mkServiceNotification = require("%enlSqGlob/ui/notifications/mkServiceNotification.nut")
let { canTakeDailyTaskReward } = require("%enlist/unlocks/taskListState.nut")

let waitingSpinner = spinner(hdpx(35))
let progressWidth = hdpxi(174)
let sizeBlocks    = fsh(40)
let sizeStar      = hdpx(15)
let hugePadding   = midPadding * 4
let cardProgressBar = progressContainerCtor(
  $"ui/uiskin/battlepass/progress_bar_mask.svg",
  $"ui/uiskin/battlepass/progress_bar_border.svg",
  [progressWidth, progressBarHeight]
)
let progressBarImage = @(isReceived, isPremium) !isReceived && isPremium
  ? "!ui/uiskin/progress_bar_gray.svg"
  : "!ui/uiskin/progress_bar_gradient.svg"

let tblScrollHandler = ScrollHandler()

let showingItem = Computed(function() {
  if (curItem.value == null)
    return null

  let reward = clone curItem.value.reward
  let season = seasonIndex.value
  let weapId = reward?.specialRewards[season][curArmy.value]
  if (weapId != null) {
    let { gametemplate = reward.gametemplate } = allItemTemplates.value?[curArmy.value][weapId]
    reward.isSpecial <- true
    reward.gametemplate <- gametemplate
    return reward
  }

  if (reward?.itemTemplate && !reward?.gametemplate) {
    let { gametemplate = null } = allItemTemplates.value?["common_army"][reward.itemTemplate]
    if (gametemplate)
      reward.gametemplate <- gametemplate
  }

  if ((curItem.value?.stage0idx ?? -1 ) >= 0) {
    reward.isPremium <- true
    return reward
  }

  foreach (item in unlockToShow.value) {
    if (item.stage == curItem.value?.stageIdx) {
      reward.isPremium <- item?.isPremium ?? false
      return reward
    }
  }

  return reward
})

showingItem.subscribe(function(item) {
  if (isOpened.value)
    curSelectedItem(item)
})

let progressTxt = @(text = "") {
  hplace = ALIGN_RIGHT
  vplace = ALIGN_CENTER
  padding = [0, hdpx(20), 0, 0]
  rendObj = ROBJ_TEXT
  text
}.__update(fontBody)

function scrollToCurrent() {
  let cardIdx = (curItem.value?.stageIdx ?? "0").tointeger()
    + (premiumStage0Unlock.value?.stages[0].rewards.len() ?? 0)
  tblScrollHandler.scrollToX((sizeCard[0] + gapCards) * (cardIdx + 0.5) - gapCards
    - safeAreaSize.value[0] / 2)
}

nextUnlock.subscribe( function(_) {
  curItemUpdate()
  scrollToCurrent()
})

let cardsList = function() {
  let { isFinished = false } = premiumStage0Unlock.value
  let { rewards  = {} } = premiumStage0Unlock.value?.stages[0]

  let templates = allItemTemplates.value?[commonArmy.value] ?? {}

  let children = [
    {
      size = [SIZE_TO_CONTENT, flex()]
      flow = FLOW_VERTICAL
      gap = midPadding * 2
      valign = ALIGN_BOTTOM
      children = [
        {
          flow = FLOW_HORIZONTAL
          gap = gapCards
          children = prepareRewards(rewards, itemsMapping.value)
            .map(@(r, idx) mkCard(r.reward, r.count, templates,
              @() curItem({ reward = r.reward, stage0idx = idx }),
              Computed(@() curItem.value?.stage0idx == idx),
              isFinished, true,
              null))
        }
        {
          size = [flex(), progressBarHeight]
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          children = {
            rendObj = ROBJ_TEXT
            color = activeTxtColor
            text = loc("bp/eliteBPRewards")
          }
        }
      ]
    }
  ].extend(combinedRewards.value.map(function(r) {
    let { reward, count, stageIdx, isReceived, isPremium, progressState, progressVal } = r
    return mkCard(reward, count, templates, @() curItem({ reward, stageIdx }),
      Computed(@() curItem.value?.stageIdx == stageIdx), isReceived, isPremium,
      cardProgressBar(
        progressState == RewardState.COMPLETED ? completedProgressLine(1)
          : progressState == RewardState.ACQUIRED ? acquiredProgressLine(1, glareAnimation(0.5))
          : progressState == RewardState.IN_PROGRESS ? gradientProgressLine(
              progressVal, progressBarImage(isReceived, isPremium)
            )
          : inactiveProgressCtor(),
        progressTxt(r.stageIdx + 1))
    )
  }))

  return {
    watch = [
      combinedRewards, premiumStage0Unlock, itemsMapping, allItemTemplates, commonArmy
    ]
    flow = FLOW_HORIZONTAL
    gap = gapCards
    children
  }
}

let bpUnlocksList = @() {
  size = [flex(), SIZE_TO_CONTENT]
  halign = ALIGN_CENTER
  valign = ALIGN_BOTTOM
  watch = safeAreaSize
  xmbNode = XmbContainer({
    canFocus = false
    scrollSpeed = 5.0
    isViewport = true
  })

  children = makeHorizScroll({
    flow = FLOW_VERTICAL
    padding = [hugePadding, 0, hugePadding, 0]
    gap = gapCards
    children = cardsList
    onAttach = scrollToCurrent
  }, {
    size = SIZE_TO_CONTENT
    maxWidth = safeAreaSize.value[0]
    scrollHandler = tblScrollHandler
    rootBase = {
      key = "battlepassUnlocksRoot"
      behavior = Behaviors.Pannable
      wheelStep = 0.82
    }
  })
}

let progressStyles = {
  fa = { color = attentionTxtColor, font = fontawesome.font, fontSize = sizeStar }
}

let mkTextProgress = @(locName) @() {
  watch = progressCounters
  rendObj = ROBJ_TEXTAREA
  size = [flex(), SIZE_TO_CONTENT]
  halign = ALIGN_CENTER
  behavior = Behaviors.TextArea
  text = loc(locName, progressCounters.value)
  color = activeTxtColor
}.__update(fontBody)

let bpInfoStage = @() {
  watch = [hasEliteBattlePass, progressCounters]
  flow = FLOW_VERTICAL
  valign = ALIGN_CENTER
  size = [flex(), SIZE_TO_CONTENT]
  children = hasEliteBattlePass.value ? null
    : [
        progressCounters.value.allowedFreeRewarded > 0 ? mkTextProgress("bp/freeRewards") : null
        progressCounters.value.allowedPremRewarded > 0 ? mkTextProgress("bp/premiumRewards") : null
      ]
}

let starFilled = faComp("star", { fontSize = sizeStar, color = attentionTxtColor })
let starEmpty = faComp("star-o", { fontSize = sizeStar, color = attentionTxtColor })

function bpInfoProgress () {
  let { current, required, interval } = currentProgress.value
  let starFactor = (interval / BP_INTERVAL_STARS).tointeger()
  let filledStars = current >= required || hasReward.value || starFactor == 0
    ? BP_INTERVAL_STARS
    : min(BP_INTERVAL_STARS - 1, ((current + interval - required) / starFactor).tointeger())

  return {
    valign = ALIGN_CENTER
    watch = [currentProgress, hasReward, basicProgress, combinedUnlocks, progressCounters]
    flow = FLOW_HORIZONTAL
    gap = midPadding
    margin = [0,0,0,midPadding]
    children = [
      {
        rendObj = ROBJ_TEXT
        text = loc("nextReward")
        color = hasReward.value ? soldierLvlColor: activeTxtColor
      }.__update(fontBody)
      {
        flow = FLOW_HORIZONTAL
        gap = smallPadding
        children = array(filledStars).map(@(_) starFilled)
          .extend(array(BP_INTERVAL_STARS - filledStars).map(@(_) starEmpty))
      }
    ]
  }
}

let bpInfoDetails = @() {
  watch = [hasEliteBattlePass, canTakeDailyTaskReward]
  rendObj = ROBJ_TEXTAREA
  size = [flex(), SIZE_TO_CONTENT]
  margin = [0, midPadding]
  text = !canTakeDailyTaskReward.value ? loc("unlocks/dailyTasksLimit")
    : hasEliteBattlePass.value ? loc("bp/progressWithPremium", fa)
    : loc("bp/howToProgress", fa)
  behavior = Behaviors.TextArea
  color = activeTxtColor
  tagsTable = progressStyles
  transform = {}
  animations = [
    { prop = AnimProp.translate, from = [-sizeBlocks, 0], to = [0, 0], duration = 0.2,
      easing = InOutCubic, play = true }
    { prop = AnimProp.opacity, from = 0, to = 1, duration = 0.5,
      easing = InOutCubic, play = true}
  ]
}.__update(fontSub)

let bpInfoPremPass = function() {
  let res = { watch = hasEliteBattlePass }
  if (!hasEliteBattlePass.value)
    return res

  return res.__update({
    rendObj = ROBJ_TEXT
    text = loc("bp/battlePassBought")
    color = attentionTxtColor
  }, fontBody)
}

function btnReceiveAllRewards() {
  let res = {watch = hasReward}
  if (!hasReward.value)
    return res
  return res.__update({
    watch = [hasReward, receiveRewardInProgress, progressCounters]
    halign = ALIGN_CENTER
    size = btnSize
    children = receiveRewardInProgress.value ? waitingSpinner
      : PrimaryFlat(loc("bp/getAllReward"), receiveAllRewards, {
          hotkeys = [["^J:X | Enter | Space", { skip = true }]]
          size = btnSize
          margin = 0
        })
  })
}

let mkBtnBuySkipStage = @(price) currencyBtn({
  btnText = loc("bp/buy")
  currencyId = price.currency
  price = price.price
  cb = @() purchaseMsgBox({
    price = price.price
    currencyId = price.currency
    description = loc("bp/buyNextStageConfirm")
    purchase = buyNextStage
    alwaysShowCancel = true
    srcComponent = "buy_battlepass_level"
  })
  style = ({
    margin = 0
    hotkeys = [["^J:Y", { description = { skip = true }}]]
    size = btnSize
    minWidth = btnSize[0]
  })
})

let mkBuySkipStageBlock = @(price) {
  flow = FLOW_VERTICAL
  size = [btnSize[0], SIZE_TO_CONTENT]
  halign = ALIGN_CENTER
  padding = [midPadding, 0, 0, 0]
  gap = midPadding
  children = [
    {
      rendObj = ROBJ_TEXT
      text = loc("bp/buyNextStage")
      color = titleTxtColor
    }.__update(fontBody)
    mkBtnBuySkipStage(price)
  ]
}

function buttonsBlock() {
  let res = { watch = [ hasEliteBattlePass, canBuyBattlePass, nextUnlockPrice,
    buyUnlockInProgress, hasReward] }

  let price = nextUnlockPrice.value
  return res.__update({
    transform = {}
    animations = [
      { prop = AnimProp.translate, from = [sizeBlocks, 0], to = [0, 0], duration = 0.2,
        easing = InOutCubic, play = true }
      { prop = AnimProp.opacity, from = 0, to = 1, duration = 0.5,
        easing = InOutCubic, play = true }
    ]
    flow = FLOW_VERTICAL
    halign = ALIGN_CENTER
    margin = [midPadding, 0, 0, 0]
    gap = midPadding
    children = [
      hasEliteBattlePass.value || !canBuyBattlePass.value ? null
        : btnBuyPremiumPass(loc("bp/buy"), eliteBattlePassWnd )
      buyUnlockInProgress.value ? waitingSpinner
        : price && !hasReward.value ? mkBuySkipStageBlock(price)
        : null
      btnReceiveAllRewards
    ]
  })
}

let bpTasksBlock = @() {
  watch = serviceNotificationsList
  size = [startBtnWidth, SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  gap = midPadding
  margin = [0,0,0,midPadding]
  children = serviceNotificationsList.value.len() > 0
    ? mkServiceNotification(serviceNotificationsList.value, { hplace = ALIGN_RIGHT })
    : [
        mkDailyTasksUi()
        weeklyTasksUi
      ]
}

let bpRightBlock = mkBpIconBlock([
  bpInfoPremPass
  buttonsBlock
  bpInfoStage
])

let closeButton = closeBtnBase({ onClick = @() isOpened(false) })

let bpLeftBlock = {
  size = [SIZE_TO_CONTENT, flex()]
  hplace = ALIGN_LEFT
  flow = FLOW_VERTICAL
  gap = midPadding
  children = [
    {
      margin = [midPadding,0,midPadding,0]
      children = bpTitle(hasEliteBattlePass.value, hdpx(100))
    }
    {
      flow = FLOW_VERTICAL
      size = [SIZE_TO_CONTENT, flex()]
      valign = ALIGN_CENTER
      gap = midPadding
      children = [
        bpInfoProgress
        bpTasksBlock
        bpInfoDetails
      ]
    }
  ]
}

let bpWindow = @(){
  size = flex()
  watch = [safeAreaBorders, hasEliteBattlePass, showingItem]
  padding = [
    safeAreaBorders.value[0] + hdpx(30),
    safeAreaBorders.value[1] + hdpx(25),
    safeAreaBorders.value[0] + hdpx(60),
    safeAreaBorders.value[1] + hdpx(25)
  ]
  children = [
    {
      size = flex()
      flow = FLOW_VERTICAL
      children = [
        {
          flow = FLOW_VERTICAL
          behavior = Behaviors.MenuCameraControl
          size = flex()
          children = [
            bpHeader(showingItem.value, closeButton)
            {
              size = flex()
              children = [
                bpLeftBlock
                bpRightBlock
              ]
            }
          ]
        }
        bpUnlocksList
      ]
    }
    lockScreen(showingItem.value)
  ]
}

scenesListGeneration.subscribe(function(_v){
  if( getTopScene() == bpWindow )
    curItemUpdate()
})

function open() {
  sceneWithCameraAdd(bpWindow, "battle_pass")
  curItemUpdate()
}

function close() {
  sceneWithCameraRemove(bpWindow)
  curSelectedItem(null)
  curItem(null)
}

if (isOpened.value)
  open()

isOpened.subscribe(@ (v) v ? open() : close())