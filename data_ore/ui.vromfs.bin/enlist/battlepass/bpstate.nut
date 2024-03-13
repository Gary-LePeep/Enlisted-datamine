from "%enlSqGlob/ui/ui_library.nut" import *

let { debounce } = require("%sqstd/timers.nut")
let {
  timeLeft, basicUnlockId, basicUnlock, basicProgress, premiumUnlockId, premiumUnlock,
  premiumProgress, hasBattlePass, unlockPrices, purchaseInProgress, doReceiveRewards, doBuyUnlock,
  nextBasicStage, nextPremiumStage, seasonIndex
} = require("%enlist/unlocks/taskRewardsState.nut")
let { hasEliteBattlePass, premRewardsAllowed } = require("eliteBattlePass.nut")
let { receiveUnlockRewardsAllUp, unlockRewardsInProgress } = require("%enlSqGlob/userstats/userstat.nut")

const BP_PREMIUM_STAT = "battle_pass_stage"

let combinedUnlocks = Computed(function() {
  let basicRewards = basicUnlock.value?.stages ?? []
  let premRewards = premiumUnlock.value?.stages ?? []
  local premIdx = 0
  local premProgress = 0
  let res = []
  foreach (basicStage, basic in basicRewards) {
    foreach (stat in basic?.updStats ?? []){
      premProgress += stat?.name == BP_PREMIUM_STAT ? (stat?.value ?? 0).tointeger() : 0
    }
    res.append(basic.__merge({
      stage = basicStage
    }))
    for (local premStage = premIdx; premStage < premRewards.len(); ++premStage) {
      let premium = premRewards[premStage]
      if (premium.progress > premProgress)
        break
      res.append(premium.__merge({
        stage = premStage
        isPremium = true
      }))
      ++premIdx
    }
  }
  return res
    .map(function(r) {
      let rewards = r?.rewards ?? {}
      if ("currencyRewards" in r) {
        rewards.__update(r.currencyRewards)
        r.$rawdelete("currencyRewards")
      }
      if (rewards.len() > 0)
        r.rewards <- rewards.map(@(val) val.tointeger())
      return r
    })
    .filter(@(r) r?.rewards != null)
})

let combinedUnlocksGrid = Computed(function() {
  local lastIdx = 0
  local lastProgress = 0
  local stepProgress = 0
  let res = array(combinedUnlocks.value.len())
  foreach (idx, unlock in combinedUnlocks.value)
    if (!(unlock?.isPremium ?? false)) {
      let { progress } = unlock
      if (idx == lastIdx) {
        res[idx] = progress
      } else {
        stepProgress = (progress - lastProgress).tofloat() / (idx - lastIdx)
        for (local i = lastIdx; i <= idx; ++i)
          res[i] = (lastProgress + (i - lastIdx) * stepProgress + 0.5).tointeger()
      }
      lastIdx = idx
      lastProgress = progress
    }
  for (; lastIdx < res.len(); ++lastIdx) {
    res[lastIdx] = lastProgress.tointeger()
    lastProgress += stepProgress
  }
  return res
})

function calcUnlockRatio(unlocksGrid, progress, minProgress = 0.0) {
  let length = unlocksGrid.len()
  if (length < 1)
    return 0.0

  let index = unlocksGrid.findindex(@(p) p >= progress)
  if (index == null)
    return 1.0

  let prev = unlocksGrid?[index - 1].tofloat() ?? minProgress
  let curr = unlocksGrid[index].tofloat()
  return min((index + (progress - prev).tofloat() / (curr - prev)) / length, 1.0)
}

let clampStage = @(stage, total, full) stage < full ? stage
  : full > total ? total + (stage - total) % (full - total)
  : full - 1

function clampProgress(grid, total, progress) {
  if (grid.len() == 0 || total == 0)
    return progress

  let lastProgress = grid.top()
  if (progress < lastProgress)
    return progress

  let firstProgress = grid[total - 1]
  return firstProgress < lastProgress
    ? firstProgress + (progress - firstProgress) % (lastProgress - firstProgress)
    : lastProgress
}

function getCountAllowedAllUnlocks(fullUnlocks, hasEliteBP, startIdx, endIdx) {
  let unlocks = fullUnlocks.slice(startIdx, endIdx)
  return hasEliteBP
    ? unlocks.len()
    : unlocks.reduce(@(s, item) s + (item?.isPremium ? 0 : 1), 0)
}

function getCountAllowedUnlocks(fullUnlocks, startIdx, endIdx, isPremRewarded = false) {
  local count = 0
  for(local i = startIdx; i < endIdx; i++)
    if (isPremRewarded == !!fullUnlocks[i]?.isPremium)
      count++
  return count
}

let progressCounters = Computed(function() {
  let fullUnlocks = combinedUnlocks.value
  let full = fullUnlocks.len()
  let { startStageLoop = 0, periodic = false } = basicUnlock.value
  let loopIndex = startStageLoop - 1
  let loop = max(1, full - loopIndex)
  let total = periodic ? loopIndex : full
  let { current, lastRewardedStage } = basicProgress.value
  let rewarded = max(lastRewardedStage, premiumProgress.value.lastRewardedStage)
  let stageCurrentInLoop = (rewarded - total) % loop + total
  let interval = (combinedUnlocksGrid.value?[1] ?? 1) - (combinedUnlocksGrid.value?[0] ?? 1)
  let stageCurrent = combinedUnlocksGrid.value.findindex(@(p) p > current) ?? stageCurrentInLoop
  let stageRewardedInLoop = stageCurrent + (current / (interval ? interval : 3) - rewarded)
  let isLoop = rewarded > full
  let countLoop = (rewarded - total) / loop
  let allowedReward = getCountAllowedAllUnlocks(
    fullUnlocks,
    hasEliteBattlePass.value,
    isLoop ? stageCurrent : rewarded,
    stageRewardedInLoop)
  let allowedRewarded = getCountAllowedAllUnlocks(fullUnlocks, hasEliteBattlePass.value, 0, rewarded)
  local allowedFreeRewarded = getCountAllowedUnlocks(fullUnlocks, 0, isLoop ? stageCurrent : rewarded)
  local allowedPremRewarded = getCountAllowedUnlocks(fullUnlocks, 0, stageCurrent, true)
  if (isLoop) {
    allowedFreeRewarded += loop / 2 * countLoop
    allowedPremRewarded += loop / 2 * countLoop
  }
  return {
    rewarded = isLoop ? stageRewardedInLoop : rewarded
    current = stageCurrent
    total
    full
    loop
    reward = allowedReward
    allowedRewarded
    allowedFreeRewarded
    allowedPremRewarded
    isCompleted = stageCurrent >= total
  }
})

let currentProgress = Computed(function() {
  let { total, full } = progressCounters.value
  local { current, required, stage } = basicProgress.value
  stage = clampStage(stage, total, full)
  let interval = (combinedUnlocksGrid.value?[stage] ?? 0)
    - (combinedUnlocksGrid.value?[stage - 1] ?? 0)
  return {
    current = clampStage(current, required - interval, required)
    required
    interval
  }
})

let currentUnlockRatio = Computed(function() {
  let { rewarded, total, full, loop, isCompleted } = progressCounters.value
  if (full == 0 || combinedUnlocksGrid.value.len() == 0)
    return {
      received = 0.0
      earned = 0.0
    }

  local { current } = basicProgress.value
  if (!isCompleted) {
    let earned = calcUnlockRatio(combinedUnlocksGrid.value.slice(0, total), current)
    let received = rewarded.tofloat() / total
    return {
      received
      earned = earned - received
    }
  }

  let received = clampStage(rewarded, total, full).tofloat() / full
  let first = combinedUnlocksGrid.value?[total - 1] ?? 0
  let diff = combinedUnlocksGrid.value.top() - first
  let progress = first + (rewarded - total) * diff / loop

  if (current > progress)
    return {
      received
      earned = 1.0 - received
    }

  current = clampProgress(combinedUnlocksGrid.value, total, current)
  return {
    received
    earned = calcUnlockRatio(combinedUnlocksGrid.value, current) - received
  }
})

function isWorthlessReward(stage) {
  let { rewards = {}, currencyRewards = {} } = stage
  return rewards.len() == 0 && currencyRewards.len() == 0
}

let hasReward = Computed(@() basicProgress.value.hasReward
  || (hasEliteBattlePass.value && premiumProgress.value.hasReward))

let findStageIdx = @(stages, stageIdx, isPremium)
  stages.findindex(@(s) s.stage >= stageIdx && (s?.isPremium ?? false) == isPremium) //empty stages are filtered, so take first not empty stage

let nextRewardInfo = Computed(function() {
  let stages = combinedUnlocks.value
  local unlockId = null
  local stageIdx = null
  local isReadyToReceive = true
  let { total, full } = progressCounters.value
  if (basicProgress.value.hasReward && (!premiumProgress.value.hasReward || !premRewardsAllowed.value)) {
    unlockId = basicUnlockId.value
    stageIdx = findStageIdx(stages, clampStage(basicProgress.value.lastRewardedStage, total, full), false)
  } else if (premiumProgress.value.hasReward && hasEliteBattlePass.value) {
    unlockId = premiumUnlockId.value
    stageIdx = findStageIdx(stages, clampStage(premiumProgress.value.lastRewardedStage, total, full), true)
    isReadyToReceive = premRewardsAllowed.value
  }
  return { unlockId, stageIdx, isReadyToReceive }
})

let nextRewardStage = Computed(@() nextRewardInfo.value.stageIdx)
let nextStage = Computed(function() {
  let { rewarded, total, full } = progressCounters.value
  let res = clampStage(rewarded, total, full)
  return max(res, nextRewardStage.value ?? res) //no need to go before next reward while loop
})

let nextUnlock = Computed(@() combinedUnlocks.value?[nextStage.value])

let nextUnlockPrice = Computed(@() (basicProgress.value.hasReward
  || basicProgress.value.isFinished
  || !hasEliteBattlePass.value)
    ? null
    : unlockPrices.value?[basicUnlockId.value])

let receiveRewardInProgress = Computed(@() basicUnlockId.value in unlockRewardsInProgress.value
  || premiumUnlockId.value in unlockRewardsInProgress.value)

let buyUnlockInProgress = Computed(@() basicUnlockId.value in purchaseInProgress.value)

function receiveAllRewards() {
  let unlocksToRewards = []
  if (basicProgress.value.hasReward)
    unlocksToRewards.append({ name = basicUnlockId.value })
  if (hasEliteBattlePass.value)
    unlocksToRewards.append({ name = premiumUnlockId.value })

  if (unlocksToRewards.len() > 0)
    receiveUnlockRewardsAllUp(unlocksToRewards)
}

function buyNextStage() {
  if (nextUnlockPrice.value)
    doBuyUnlock(basicUnlockId.value)
}

let curWorthlessRewardId = keepref(Computed(@() !hasReward.value || receiveRewardInProgress.value ? null
  : isWorthlessReward(nextPremiumStage.value) && hasEliteBattlePass.value ? premiumUnlockId.value
  : isWorthlessReward(nextBasicStage.value) ? basicUnlockId.value
  : null))

let tryReceiveReward = debounce(@(id) doReceiveRewards(id), 0.01)
curWorthlessRewardId.subscribe(tryReceiveReward)

return {
  timeLeft
  basicProgress
  premiumProgress
  combinedUnlocks
  currentUnlockRatio
  progressCounters
  currentProgress
  nextStage
  nextRewardStage
  nextUnlock
  hasReward
  hasBattlePass
  nextUnlockPrice
  receiveRewardInProgress
  buyUnlockInProgress
  receiveAllRewards
  buyNextStage
  seasonIndex
}
