from "%enlSqGlob/ui/ui_library.nut" import *

let style = require("%ui/hud/style.nut")

let { abs } = require("%sqstd/math.nut")
let { fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let { smallPadding } = require("%enlSqGlob/ui/designConst.nut")


let mkText = @(txt, override = {}) {
  rendObj = ROBJ_TEXT
  text = txt
}.__update(override)


let mkScoreAnimations = @(trigger) [
  { prop = AnimProp.scale, from = [1, 1], to = [1.3, 1.3],
    duration = 0.5, easing = Blink, trigger }
  { prop = AnimProp.opacity, from = 1, to = 0.7,
    duration = 0.5, easing = Blink, trigger }
]

let mkScoreDeltaAnim = @(onFinishScoreAnim) [
  { prop = AnimProp.translate, from = [-90, 0], to = [-90, 0],
    duration = 0.7, play = true }
  { prop = AnimProp.scale, from = [1, 1], to = [1.8, 1.8],
    duration = 0.5, play = true, easing = Blink }
  { prop = AnimProp.opacity, from = 0.3, to = 1,
    duration = 0.2, play = true }
  { prop = AnimProp.translate, from = [-90, 0], to = [-30, 0], delay = 0.7,
    duration = 0.2, play = true, onFinish = onFinishScoreAnim }
]


let mkScoreIcon = @(iconPath, color, iconSize) {
  rendObj = ROBJ_IMAGE
  image = Picture("{0}:{1}:{1}:K".subst(iconPath, iconSize))
  color
  size = [iconSize, iconSize]
}


let mkScoreDeltaAnimUi = @(
  iconPath, isMyTeamAttacking, attackerScore, scoreAnimStack,
  scoreAnimData, onFinishScoreAnim
)
  function() {
    scoreAnimData.animIdx++
    let addColor = isMyTeamAttacking.value ? style.TEAM0_COLOR_FG : style.TEAM1_COLOR_FG
    let removeColor = isMyTeamAttacking.value ? style.TEAM1_COLOR_FG : style.TEAM0_COLOR_FG
    let nextScoreValue = scoreAnimStack.value?[0] ?? attackerScore.value
    let scoreDelta = scoreAnimData.lastValue == null ? 0 : nextScoreValue - scoreAnimData.lastValue
    let color = scoreDelta < 0 ? removeColor : addColor
    let signObj = scoreDelta > 0 ? mkText("+", { color }.__update(fontBody))
      : scoreDelta < 0 ? mkText("-", { color }.__update(fontBody))
      : null
    if (scoreAnimData.lastValue == null)
      onFinishScoreAnim()
    return {
      watch = [isMyTeamAttacking, attackerScore, scoreAnimStack]
      size = [SIZE_TO_CONTENT, flex()]
      valign = ALIGN_CENTER
      children = {
        key = $"play_score_anim_{scoreAnimData.animIdx}"
        flow = FLOW_HORIZONTAL
        gap = hdpxi(2)
        valign = ALIGN_CENTER
        children = scoreDelta == 0 ? null : [
          signObj
          mkScoreIcon(iconPath, color, hdpxi(18))
          mkText($"{abs(scoreDelta)}", { color })
        ]
        transform = { pivot = [0.5, 0.5] }
        animations = mkScoreDeltaAnim(onFinishScoreAnim)
      }
    }
  }


return function(id, iconPath, isMyTeamAttacking, attackerScore) {
  let scoreAnimData = {
    lastValue = null
    animIdx = 0
  }
  let scoreAnimStack = Watched([])

  function onFinishScoreAnim() {
    scoreAnimData.lastValue = scoreAnimStack.value?[0] ?? attackerScore.value
    if (scoreAnimStack.value.len() > 0)
      scoreAnimStack.mutate(@(v) v.remove(0))
  }

  attackerScore.subscribe(function(val) {
    if (scoreAnimStack.value.len() <= 1)
      scoreAnimStack.mutate(@(v) v.append(val))
    else
      scoreAnimStack.mutate(@(v) v[v.len() - 1] = val)
  })

  return function() {
    let color = isMyTeamAttacking.value ? style.TEAM0_COLOR_FG : style.TEAM1_COLOR_FG
    return {
      watch = isMyTeamAttacking
      valign = ALIGN_CENTER
      children = [
        mkScoreDeltaAnimUi(iconPath, isMyTeamAttacking, attackerScore, scoreAnimStack,
          scoreAnimData, onFinishScoreAnim)
        function() {
          let scoreVal = scoreAnimStack.value.len() == 0
            ? attackerScore.value
            : scoreAnimData.lastValue ?? attackerScore.value
          return {
            watch = [attackerScore, scoreAnimStack]
            flow = FLOW_HORIZONTAL
            valign = ALIGN_CENTER
            gap = smallPadding
            children = [
              mkScoreIcon(iconPath, color, hdpxi(24))
              mkText(scoreVal, { color }.__update(fontBody))
            ]
            transform = { pivot = [0.2, 0.5] }
            animations = mkScoreAnimations(id)
          }
        }
      ]
    }
  }
}
