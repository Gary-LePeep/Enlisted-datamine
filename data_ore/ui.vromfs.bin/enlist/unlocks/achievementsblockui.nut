from "%enlSqGlob/ui/ui_library.nut" import *

let { achievementsByTypes, receiveTaskRewards } = require("taskListState.nut")
let { getUnlockProgress, unlockProgress } = require("%enlSqGlob/userstats/unlocksState.nut")
let { unlockRewardsInProgress } = require("%enlSqGlob/userstats/userstat.nut")
let { smallPadding, midPadding, defBgColor, smallOffset, hoverSlotBgColor
} = require("%enlSqGlob/ui/designConst.nut")
let { mkAchievementTitle, mkTaskEmblem, taskHeader, taskDescription, taskDescPadding,
  statusBlock, taskMinHeight, taskSlotPadding, mkGetTaskRewardBtn
} = require("%enlSqGlob/ui/tasksPkg.nut")
let itemsMapping = require("%enlist/items/itemsMapping.nut")
let { mkTaskRewards } = require("mkUnlockSlots.nut")
let scrollbar = require("%ui/components/scrollbar.nut")
let { seenUnlocks, markUnlocksOpened } = require("%enlist/unlocks/unseenUnlocksState.nut")

let mkTaskContent = @(task, sf)
  function() {
    let progress = getUnlockProgress(task, unlockProgress.value)
    return {
      watch = unlockProgress
      size = [flex(), SIZE_TO_CONTENT]
      valign = ALIGN_CENTER
      children = {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        gap = hdpx(10)
        valign = ALIGN_CENTER
        children = [
          mkTaskEmblem(task, progress)
          {
            size = [flex(), SIZE_TO_CONTENT]
            flow = FLOW_VERTICAL
            gap = taskDescPadding
            children = [
              taskHeader(task, progress, true, sf)
              taskDescription(task.localization.description, sf)
            ]
          }
        ]
      }
    }
  }

let finishedOpacity = 0.5
let finishedHoveredOpacity = 0.75
let finishedBgColor = mul_color(defBgColor, 1.0 / finishedOpacity)
let mkAchievementSlot = @(task) {
  size = [flex(), SIZE_TO_CONTENT]
  children = [
    watchElemState(@(sf) {
      size = [flex(), SIZE_TO_CONTENT]
      watch = itemsMapping
      minHeight = taskMinHeight
      rendObj = ROBJ_SOLID
      xmbNode = XmbNode()
      behavior = Behaviors.Button
      color = sf & S_HOVER ? hoverSlotBgColor
        : task.isFinished ? finishedBgColor
        : defBgColor
      opacity = !task.isFinished ? 1.0
        : sf & S_HOVER ? finishedHoveredOpacity
        : finishedOpacity
      flow = FLOW_HORIZONTAL
      padding = taskSlotPadding
      gap = smallPadding
      valign = ALIGN_CENTER
      children = [
        mkTaskContent(task, sf)
        task.hasReward
          ? mkGetTaskRewardBtn(task, receiveTaskRewards, unlockRewardsInProgress)
          : null
        mkTaskRewards(task, itemsMapping.value, true)
      ]
    })
    statusBlock(task)
  ]
}

let WINDOW_CONTENT_SIZE = [fsh(100), flex()]
let achievementsBlockUI = {
  key = "achievementsBlock"
  size = WINDOW_CONTENT_SIZE
  vplace = ALIGN_CENTER
  hplace = ALIGN_CENTER
  padding = [fsh(2),0,0,0]
  onDetach = @() markUnlocksOpened((seenUnlocks.value?.unopenedAchievements ?? {}).keys())
  children = scrollbar.makeVertScroll(function() {
    let achieveByTypes = achievementsByTypes.value
    let { achievements = [], challenges = [] } = achieveByTypes
    return {
      rendObj = ROBJ_WORLD_BLUR_PANEL
      watch = achievementsByTypes
      size = [flex(), SIZE_TO_CONTENT]
      minHeight = ph(100)
      xmbNode = XmbContainer({
        canFocus = false
        scrollSpeed = 5
        isViewport = true
        wrap = false
      })
      flow = FLOW_VERTICAL
      gap = smallPadding
      margin = [0,0,0,smallOffset]
      halign = ALIGN_CENTER
      children = [mkAchievementTitle(achievements, "achievementsTitle")]
        .extend(achievements.map(@(achievement) mkAchievementSlot(achievement)))
        .append({ size = [0, midPadding] })
        .append(mkAchievementTitle(challenges, "challengesTitle"))
        .extend(challenges.map(@(challenge) mkAchievementSlot(challenge)))
    }
  },
  {
    needReservePlace = false
  })
}

return achievementsBlockUI