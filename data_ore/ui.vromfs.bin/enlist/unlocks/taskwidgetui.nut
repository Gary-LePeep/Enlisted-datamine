from "%enlSqGlob/ui/ui_library.nut" import *

let { fontSub, fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let msgbox = require("%enlist/components/msgbox.nut")
let { utf8ToUpper } = require("%sqstd/string.nut")
let { smallPadding, bigPadding, defTxtColor, disabledTxtColor, hoverTxtColor, startBtnWidth,
  largePadding
} = require("%enlSqGlob/ui/designConst.nut")
let { dailyTasksByDifficulty, receiveTaskRewards, getTotalRerolls, getLeftRerolls,
  isRerollInProgress, canTakeDailyTaskReward, doRerollUnlock, rewardDailyTask
} = require("taskListState.nut")
let { taskDescription, taskDescPadding, mkTaskLabel, taskLabelSize, taskHeader
} = require("%enlSqGlob/ui/tasksPkg.nut")
let { mkUnlockSlot, mkUnlockSlotReward, mkHideTrigger } = require("mkUnlockSlots.nut")
let { userstatStats, unlockRewardsInProgress } = require("%enlSqGlob/userstats/userstat.nut")
let eliteBattlePassWnd = require("%enlist/battlepass/eliteBattlePassWnd.nut")
let { specialEvents, showNotActiveTaskMsgbox } = require("eventsTaskState.nut")
let buyUnlockMsg = require("buyUnlockMsg.nut")
let { isUnlockAvailable, getUnlockProgress, unlockProgress
} = require("%enlSqGlob/userstats/unlocksState.nut")
let { PrimaryFlat, Purchase } = require("%ui/components/textButton.nut")
let { unlockPrices, purchaseInProgress, hasBattlePass } = require("taskRewardsState.nut")
let spinner = require("%ui/components/spinner.nut")
let { sound_play } = require("%dngscripts/sound_system.nut")
let JB = require("%ui/control/gui_buttons.nut")
let mkBpWidgetOpen = require("%enlist/battlepass/battlePassButton.nut")
let { rewardWeeklyTask, rewardEventTask } = require("%enlist/unlocks/weeklyUnlocksState.nut")
let offersPromoWndOpen = require("%enlist/offers/offersPromoWindow.nut")

let defTxtStyle = { color = defTxtColor }.__update(fontSub)
let disabledTxtStyle = { color = disabledTxtColor }.__update(fontSub)
let hoveredTxtStyle = { color = hoverTxtColor }.__update(fontSub)
let headerTxtStyle = { color = defTxtColor }.__update(fontBody)
let disabledHeaderTxtStyle = { color = disabledTxtColor }.__update(fontBody)
let hoveredHeaderTxtStyle = { color = hoverTxtColor }.__update(fontBody)
let smallGap = hdpx(4)
let waitingSpinner = spinner()


let mkRerollText = @(leftRerolls, totalRerolls) {
  size = [sw(30), SIZE_TO_CONTENT]
  halign = ALIGN_CENTER
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  text = "\n".concat(
    loc("unlocks/reroll/youCanReroll"),
    loc("unlocks/reroll/info", {
      left = leftRerolls
      total = totalRerolls
    }))
}.__update(defTxtStyle)


function askForRerollConfirm(unlockDesc) {
  msgbox.show({
    text = loc("unlocks/reroll/askForConfirm")
    buttons = [
      { text = loc("Ok"), action = @() doRerollUnlock(unlockDesc),
        customStyle = { hotkeys = [["^J:X"]] } }
      { text = loc("Cancel"), isCurrent = true, isCancel = true,
        customStyle = { hotkeys = [[$"^{JB.B}"]] } }
    ]
  })
}


function openTaskMsgbox(unlockDesc, leftRerolls = 0, totalRerolls = 0) {
  let progress = getUnlockProgress(unlockDesc, unlockProgress.value)
  let buttons = []
  if (leftRerolls > 0)
    buttons.append({
      text = loc("btn/rerollUnlock")
      action = @() askForRerollConfirm(unlockDesc)
      isCurrent = true
      customStyle = { hotkeys = [["^J:X"]] }
    })
  buttons.append({ text = loc("Close"), isCancel = true, customStyle = {hotkeys = [[$"^{JB.B}"]]} })

  msgbox.showMessageWithContent({
    content = {
      flow = FLOW_VERTICAL
      size = [sh(100), SIZE_TO_CONTENT]
      halign = ALIGN_CENTER
      margin = [0,0,fsh(5),0]
      gap = fsh(5)
      children = [
        taskHeader(unlockDesc, progress, true, 0, {
          halign = ALIGN_CENTER
        }.__update(headerTxtStyle))
        taskDescription(unlockDesc.localization.description, 0, { halign = ALIGN_CENTER})
        leftRerolls > 0 ? mkRerollText(leftRerolls, totalRerolls) : null
      ]
    }
    buttons
  })
}


local curTimeout = null
function mkDailyTasksBlock(tasksList, stats, canTakeReward, isCompletedHidden, onHover) {
  return {
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      halign = ALIGN_RIGHT
      gap = smallGap
      children = tasksList.value.map(@(tasks, taskStype) {
          size = [flex(), SIZE_TO_CONTENT]
          flow = FLOW_VERTICAL
          gap = smallGap
          children = tasks.reduce(function(acc, task) {
            let leftRerolls = getLeftRerolls(task, stats)
            let totalRerolls = getTotalRerolls(task, stats)
            let onClick = !task.hasReward
              ? @() openTaskMsgbox(task, leftRerolls, totalRerolls)
              : canTakeReward
                ? function() {
                    if (curTimeout != null)
                      return
                    anim_start(mkHideTrigger(task))
                    sound_play("ui/reward_receive")
                    curTimeout = gui_scene.setTimeout(0.5, function() {
                      curTimeout = null
                      receiveTaskRewards(task)
                    })
                  }
                : @() msgbox.show({
                    text = loc("unlocks/dailyTasksLimitOnReward")
                    buttons = [
                      {
                        text = loc("bp/buyBattlePass")
                        action = eliteBattlePassWnd
                      }
                      {
                        text = loc("Cancel"), isCancel = true,
                        customStyle = { hotkeys = [[$"^{JB.B} | Esc"]] }
                      }
                    ]
                  })
            if (!isCompletedHidden || !task.isCompleted)
              acc.append(mkUnlockSlot({
                task
                onClick
                onHover
                hasWaitIcon = isRerollInProgress
                rerolls = leftRerolls
                rightObject = taskStype == "hardTasks"
                  ? mkTaskLabel("main_task_lable")
                  : { size = [taskLabelSize[0], flex()] }
                canTakeReward
              }))
            return acc
          }, [])
        }
      ).values()
    }
  }

let hasDailyTasks = Computed(function() {
  let { easyTasks = [], hardTasks = [] } = dailyTasksByDifficulty.value
  return easyTasks.len() > 0 || hardTasks.len() > 0
})

let mkDailyTasksUi = @(isCompletedHidden = false, onHover = null) function() {
  let res = {
    watch = [hasDailyTasks, canTakeDailyTaskReward, userstatStats]
  }

  if (!hasDailyTasks.value)
    return res

  let canTakeReward = canTakeDailyTaskReward.value
  let stats = userstatStats.value?.stats
  return res.__update({
    flow = FLOW_VERTICAL
    gap = largePadding
    children = [
      {
        size = [startBtnWidth, SIZE_TO_CONTENT]
        flow = FLOW_VERTICAL
        gap = bigPadding
        children = mkDailyTasksBlock(dailyTasksByDifficulty, stats, canTakeReward,
          isCompletedHidden, onHover)
      }
    ]
  })
}

let rewardTask = Computed(@() rewardDailyTask.value ?? rewardWeeklyTask.value ?? rewardEventTask.value)

let mkDailyTasksUiReward = @(onHover = null) function() {
  let res = {
    watch = [rewardTask, hasBattlePass]
  }

  if (!hasBattlePass.value && !rewardTask.value)
    return res

  let { event_unlock = false, event_group = "" } = rewardTask.value?.meta
  let forcedCb = !event_unlock ? null : @() offersPromoWndOpen(event_group)

  return res.__update({
    size = [startBtnWidth, SIZE_TO_CONTENT]
    children = rewardTask.value
      ? mkUnlockSlotReward(rewardTask.value, forcedCb)
      : mkBpWidgetOpen(onHover)
  })
}


let btnHeight = hdpxi(46)
let btnMinWidth = hdpxi(200)

function mkBtnBuyTask(task) {
  let hasBlockedByRequirement = Computed(function() {
    let pRequirement = task?.purchaseRequirement ?? ""
    return pRequirement == "" ? false
      : !(unlockProgress.value?[pRequirement].isCompleted ?? false)
  })
  return @() {
    watch = [purchaseInProgress, hasBlockedByRequirement]
    size = [SIZE_TO_CONTENT, btnHeight]
    valign = ALIGN_CENTER
    halign = ALIGN_RIGHT
    children = hasBlockedByRequirement.value ? null
      : purchaseInProgress.value?[task.name] ? waitingSpinner
      : Purchase(loc("bp/Purchase"),
          @() buyUnlockMsg(task),
          {
            key = "buyBtnTask"
            size = [SIZE_TO_CONTENT, btnHeight]
            minWidth = btnMinWidth
            margin = 0
            hotkeys = [["^J:Y", { description = { skip = true }}]]
          })
  }
}


let mkBtnReceiveReward = @(task) @() {
  watch = unlockRewardsInProgress
  size = [SIZE_TO_CONTENT, btnHeight]
  valign = ALIGN_CENTER
  halign = ALIGN_RIGHT
  children = unlockRewardsInProgress.value?[task.name] ? waitingSpinner
    : PrimaryFlat(loc("bp/getNextReward"),
        @() receiveTaskRewards(task),
        {
          key = "btnReceiveReward"
          size = [SIZE_TO_CONTENT, btnHeight]
          minWidth = btnMinWidth
          margin = 0
          hotkeys = [["^J:X", { description = { skip = true }}]]
        })
}


local lastActiveIdx = 0

const MAIN_EVENT_TASK_PLACE = 1
function mkEventTask(task, taskPrice, idx, isActive, isMainActive) {
  let { isCompleted, hasReward, isFinished, step, totalSteps, meta = null } = task
  let { currency = "", price = 0 } = taskPrice
  let isMain = meta?.taskListPlace == MAIN_EVENT_TASK_PLACE
  let onClick = isActive ? null : showNotActiveTaskMsgbox
  let isPurchasable = isMainActive && !isCompleted && price > 0 && currency != ""
  lastActiveIdx = isActive ? idx + 1 : lastActiveIdx
  return {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    gap = bigPadding
    children = [
      mkUnlockSlot({
        task
        isAllRewardsVisible = true
        onClick
        hasDescription = !isFinished && isActive
        bottomBtn = !isActive ? null
          : hasReward ? mkBtnReceiveReward(task)
          : isPurchasable ? mkBtnBuyTask(task)
          : null
        customDescription = !isMain && idx >= lastActiveIdx
            ? taskDescription(loc("unlocks/blockedByPrevious"), 0, {
                margin = taskDescPadding
              })
          : isFinished
            ? taskDescription(utf8ToUpper(loc("finishedTaskText")), 0, {
                margin = taskDescPadding
              })
          : null
        rightObject = mkTaskLabel(isMain ? "main_task_lable" : null)
      })
      totalSteps <= 1 ? null : {
        flow = FLOW_VERTICAL
        size = [hdpx(12), flex()]
        halign = ALIGN_CENTER
        gap = bigPadding
        children = [
          {
            rendObj = ROBJ_TEXT
            text = step
          }.__update(isActive ? hoveredHeaderTxtStyle : disabledHeaderTxtStyle)
          step >= totalSteps ? null
            : {
                rendObj = ROBJ_SOLID
                size = [smallPadding, flex()]
              }.__update(isActive ? hoveredTxtStyle : disabledTxtStyle)
        ]
      }
    ]
  }
}


let eventTasksUi = @(eventId, tasksCount = -1) function() {
  let res = { watch = [specialEvents, unlockPrices, unlockProgress] }
  let eUnlocks = specialEvents.value?[eventId].unlocks
  if (eUnlocks == null)
    return res
  local activeTasksCount = 0
  let uProgress = unlockProgress.value
  let isMainActive = eUnlocks?[0].activity.active ?? true
  let children = []
  foreach (idx, task in eUnlocks) {
    let isActive = isUnlockAvailable(uProgress, task)
    if (isActive)
      activeTasksCount++
    if (tasksCount > 0 && activeTasksCount > tasksCount)
      break
    children.append(mkEventTask(task, unlockPrices.value?[task.name], idx, isActive, isMainActive))
  }
  return res.__update({
    size = [flex(), SIZE_TO_CONTENT]
    minHeight = ph(100)
    flow = FLOW_VERTICAL
    gap = bigPadding
    valign = ALIGN_CENTER
    children
  })
}


return {
  hasDailyTasks
  mkDailyTasksUiReward
  mkDailyTasksUi
  eventTasksUi
}
