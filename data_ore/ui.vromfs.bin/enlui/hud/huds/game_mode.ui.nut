import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui/ui_library.nut" import *

let { fontHeading2, fontBody, fontawesome } = require("%enlSqGlob/ui/fontsStyle.nut")
let fa = require("%ui/components/fontawesome.map.nut")
let style = require("%ui/hud/style.nut")
let mkPointsUi = require("%ui/components/mkAnimatedPointsUi.nut")
let { TEAM_UNASSIGNED } = require("team")
let { abs } = require("%sqstd/math.nut")
let {
  capZones, curCapZone, trainZoneEid, nextTrainCapzoneEid, trainCapzoneProgress, visibleZoneGroups, whichTeamAttack, isTwoChainsCapzones
} = require("%ui/hud/state/capZones.nut")
let { capzoneWidget, capzoneGap } = require("%ui/hud/components/capzone.nut")
let {
  myScore, enemyScore, myScoreBleed, myScoreBleedFast, enemyScoreBleed,
  enemyScoreBleedFast, failTimerShowTime, anyTeamFailTimer, myTeamFailTimer, enemyTeamFailTimer
} = require("%ui/hud/state/team_scores.nut")
let { localPlayerTeam, localPlayerEid } = require("%ui/hud/state/local_player.nut")
let {
  isZombieMode, zombieModeCurWave, zombieModeHeroPoints, zombiesNextWaveTime
} = require("%ui/hud/state/zombie_mode.nut")
let { secondsToStringLoc } = require("%ui/helpers/time.nut")
let { isGunGameMode, GunGameModeUI } = require("gun_game.game_mode.ui.nut")
let random = require("dagor.random")
let { scoreNestGradientR, scoreNestGradientL } = require("%enlSqGlob/ui/designConst.nut")
let scoringPlayers = require("%ui/hud/state/scoring_players.nut")


const GAP_RATIO = 0.4 // magic number calculated as gap/icon = (1 / 1.5) / (1 + 1 / 1.5)

let SCORE_ANIM_TRIGGER = "SCORE_ANIM_TRIGGER"
let teamScoreBlink = @(trigger) [{ prop = AnimProp.opacity, from = 0.8, to = 1.0, trigger = trigger, easing = InCubic, duration = 0.5}]
let myTeamScoreBlinkAnim = teamScoreBlink("myTeamScoreChanged")
let enemyTeamScoreBlinkAnim = teamScoreBlink("enemyTeamScoreChanged")

myScore.subscribe(@(_v) anim_start("myTeamScoreChanged"))
enemyScore.subscribe(@(_v) anim_start("enemyTeamScoreChanged"))


let mkText = @(txt, override = {}) {
  rendObj = ROBJ_TEXT
  text = txt
}.__update(override)

let hasScoreBar = Computed(@() isTwoChainsCapzones.value || whichTeamAttack.value != -1
  || ((myScore.value ?? 0) != 0 && (enemyScore.value ?? 0) != 0))

let mkScoreTeam = @(params) function() {
  let score = params.score.value
  return {
    color = Color(200,100,10)
    size = [flex(), fsh(0.5)]
    watch = params.score
    children = score != null
      ? {
          rendObj = ROBJ_PROGRESS_LINEAR
          size = flex()
          fgColor = params.fgColor
          bgColor = params.bgColor
          fValue = params.fValueMul * score
        }
      : null
    animations = params.anim
  }
}

let scoreTeam1 = mkScoreTeam({
  fgColor = style.TEAM0_COLOR_FG
  bgColor = style.TEAM0_COLOR_BG
  fValueMul = -1
  score = myScore
  anim = myTeamScoreBlinkAnim
})

let scoreTeam2 = mkScoreTeam({
  fgColor = style.TEAM1_COLOR_FG
  bgColor = style.TEAM1_COLOR_BG
  fValueMul = 1
  score = enemyScore
  anim = enemyTeamScoreBlinkAnim
})


let mkScoreBleed = @(params) @() {
  watch = [params.bleed, params.bleedFast]
  size = [SIZE_TO_CONTENT, hdpx(18)]
  valign = ALIGN_CENTER
  children = params.bleed.value
    ? {
        rendObj = ROBJ_INSCRIPTION
        fontSize = params.bleedFast.value ? hdpx(9) : hdpx(16)
        color = params.dirColor
        font = fontawesome.font
        text = params.bleedFast.value ? params.dirFast : params.dirSlow
        validateStaticText = false
      }
    : null
}

let scoreBleedTeam1 = mkScoreBleed({
  bleed = myScoreBleed
  bleedFast = myScoreBleedFast
  dirColor = style.TEAM0_COLOR_FG
  dirSlow = fa["long-arrow-right"]
  dirFast = $"{fa["forward"]}{fa["forward"]}"
})

let scoreBleedTeam2 = mkScoreBleed({
  bleed = enemyScoreBleed
  bleedFast = enemyScoreBleedFast
  dirColor = style.TEAM1_COLOR_FG
  dirSlow = fa["long-arrow-left"]
  dirFast = $"{fa["backward"]}{fa["backward"]}"
})

let team1 = {
  flow = FLOW_VERTICAL
  halign = ALIGN_LEFT
  size = [flex(), fsh(0.5)]
  children = [
    scoreTeam1
    scoreBleedTeam1
  ]
}

let team2 = {
  flow = FLOW_VERTICAL
  halign = ALIGN_RIGHT
  size = [flex(), fsh(0.5)]
  children = [
    scoreTeam2
    scoreBleedTeam2
  ]
}

let teamScores = {
  size = [sw(25), SIZE_TO_CONTENT]
  hplace = ALIGN_CENTER
  valign = ALIGN_CENTER
  flow = FLOW_HORIZONTAL
  children = [
    team1
    team2
  ]
}

function capZonesBlock() {
  let groups = visibleZoneGroups.value
  let total = groups.reduce(@(res, g) res + g.len(), 0)
    + max(groups.len() - 1, 0) * GAP_RATIO
  let children = []
  local offset = 0.0
  foreach (idx, zList in groups) {
    if (idx != 0) {
      children.append(capzoneGap)
      offset += GAP_RATIO
    }
    foreach (zoneEid in zList) {
      children.append(
        capzoneWidget(zoneEid,
          {
            showDistance = false
            idx = offset
            total
          })
      )
      offset += 1.0
    }
  }

  return {
    watch = visibleZoneGroups
    size = SIZE_TO_CONTENT
    flow = FLOW_HORIZONTAL
    halign = ALIGN_CENTER
    children
  }
}

let isMyTeamAttacking = Computed(@() localPlayerTeam.value == whichTeamAttack.value)
let trainCapzone = Computed(@() capZones.value?[trainZoneEid.value])

let escortPointsBlockLength = sw(20)
let escortPointSize = [hdpxi(8), hdpxi(8)]
let escortLineHeight = fsh(0.8*0.85)
let trainMarkerSize = [hdpxi(74), hdpxi(24)]
let INACTIVATED_TRAIN_COLOR = Color(90, 90, 90)
let PATH_COLOR_BG = Color(50, 50, 50, 150)

let mkTrainIcon = @(image, color) {
  size = trainMarkerSize
  color
  rendObj = ROBJ_IMAGE
  image
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
}

let mkTrainMarkerMovement = @(color) mkTrainIcon(
  Picture("!ui/skin#train/train_move.svg:{0}:{1}:K".subst(trainMarkerSize[0], trainMarkerSize[1])),
  color
)
let trainCursor = mkTrainIcon(
  Picture("!ui/skin#train/train_cursor.svg:{0}:{1}:K".subst(trainMarkerSize[0], trainMarkerSize[1])),
  INACTIVATED_TRAIN_COLOR
)
let mkTrainMarker = @(color) mkTrainIcon(
  Picture("!ui/skin#train/train_marker.svg:{0}:{1}:K".subst(trainMarkerSize[0], trainMarkerSize[1])),
  color
)
let trainMarkerConflict = mkTrainMarker(style.TEAM0_COLOR_FG).__merge({
  animations = [{ prop=AnimProp.opacity, from=0.1, to=1.0, duration=1.0, play=true, loop=true, easing=CosineFull}]
})

let mkEscortProgress = @(offset, lineLength) function(){
  let progressOffset = offset + lineLength * trainCapzoneProgress.value
  let curTeamCapturingTrain = trainCapzone.value?.curTeamCapturingZone ?? TEAM_UNASSIGNED
  let isTrainMoving = curTeamCapturingTrain != TEAM_UNASSIGNED && curTeamCapturingTrain == (trainCapzone.value?.trainOffenseTeam ?? TEAM_UNASSIGNED)
  let color = curTeamCapturingTrain == TEAM_UNASSIGNED
    ? INACTIVATED_TRAIN_COLOR
    : curTeamCapturingTrain == localPlayerTeam.value ? style.TEAM0_COLOR_FG : style.TEAM1_COLOR_FG
  let conflictMarker = curTeamCapturingTrain < TEAM_UNASSIGNED
    ? trainMarkerConflict.__merge({ key = curTeamCapturingTrain })
    : null
  return {
    watch = [trainCapzoneProgress, trainCapzone, localPlayerTeam]
    children = [
      mkTrainMarker(color),
      conflictMarker,
      isTrainMoving ? mkTrainMarkerMovement(color) : null,
      trainCursor
    ]
    valign = ALIGN_BOTTOM
    transform = {
      translate = [progressOffset - trainMarkerSize[0]*0.5, 0.0]
    }
  }
}

function mkEscortZoneLine(offset, lineLength, color, progress) {
  let size = [lineLength - escortPointSize[0], escortLineHeight]
  return @() {
    watch = progress.watch
    size
    rendObj = ROBJ_MASK
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    image = Picture("ui/skin#train/segment_way.svg:{0}:{1}:K".subst(size[0].tointeger(),size[1].tointeger()))
    children = {
      size = [lineLength,escortLineHeight]
      rendObj = ROBJ_PROGRESS_LINEAR
      fgColor = color
      bgColor = PATH_COLOR_BG
      fValue = progress.watch?.value ?? progress.value
    }
    transform = {translate=[offset + escortPointSize[0] * 0.5,0]}
  }
}

let pathPointImage = Picture("ui/skin#train/train_point.svg:{0}:{1}:K".subst(escortPointSize[0], escortPointSize[1]))
let pathPointStartImage = Picture("ui/skin#train/train_start.svg:{0}:{1}:K".subst(escortPointSize[0], escortPointSize[1]))

let mkEscortZonePoint = @(offset, image, color) {
  size = escortPointSize
  color
  rendObj = ROBJ_IMAGE
  image
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  transform = {translate=[offset - escortPointSize[0] * 0.5, 0]}
}

let mkEscortZoneWidget = @(offset, lineLength, lineColor, pointColor, progress) {
  children = [mkEscortZoneLine(offset-lineLength, lineLength, lineColor, progress), mkEscortZonePoint(offset, pathPointImage, pointColor)]
  valign = ALIGN_CENTER
}

let mkEscortStartPoint = @(color) mkEscortZonePoint(0, pathPointStartImage, color).__merge({valign=ALIGN_CENTER})

let trainPathCapzones = Computed(function() {
  let res = []
  foreach (_idx, zList in visibleZoneGroups.value)
    foreach (zoneEid in zList)
      if (capZones.value?[zoneEid].trainTriggerable)
        res.append(zoneEid)
  return res
})

function escortBlock() {
  let colorStart = isMyTeamAttacking.value ? style.TEAM0_COLOR_FG : style.TEAM1_COLOR_FG
  let colorEnd = isMyTeamAttacking.value ? style.TEAM1_COLOR_FG : style.TEAM0_COLOR_FG
  let escortPoints = [mkEscortStartPoint(colorStart)]
  let pointCount = trainPathCapzones.value.len()
  local index = 1
  let lineLength = pointCount > 0 ? escortPointsBlockLength / pointCount : escortPointsBlockLength
  local progressOffset = 0

  local isPastCapture = trainPathCapzones.value == ecs.INVALID_ENTITY_ID
  foreach (zoneEid in trainPathCapzones.value) {
    let offset = index * lineLength
    if (zoneEid == nextTrainCapzoneEid.value) {
      progressOffset = offset - lineLength
      isPastCapture = true
    }
    let lineColor = isPastCapture && (zoneEid != nextTrainCapzoneEid.value) ? PATH_COLOR_BG : colorStart
    let pointColor = isPastCapture ? colorEnd : colorStart
    let progress = {
      watch = (zoneEid == nextTrainCapzoneEid.value) ? trainCapzoneProgress : null
      value = isPastCapture ? 0.0 : 1.0
    }
    escortPoints.append(mkEscortZoneWidget(offset, lineLength, lineColor, pointColor, progress))
    ++index
  }

  let escortProgress = mkEscortProgress(progressOffset, lineLength)
  let points = {
    size = [flex(), SIZE_TO_CONTENT]
    children = escortPoints
  }
  return {
    watch = [trainPathCapzones, nextTrainCapzoneEid, isMyTeamAttacking, trainCapzone, localPlayerTeam]
    flow = FLOW_VERTICAL
    gap = hdpx(1)
    children = [escortProgress, points]
    size = [escortPointsBlockLength, SIZE_TO_CONTENT]
    halign = ALIGN_LEFT
  }
}

let capZoneOnTrainBlock = @() {
  watch = [trainZoneEid, curCapZone]
  children = curCapZone.value?.eid == trainZoneEid.value
    ? capzoneWidget(trainZoneEid.value, { showDistance = false, total = 1 })
    : null
}

let makeFailTimer = @(endTimeWatch) function(){
  let timeIsRunningOut = endTimeWatch.value < 10
  let shouldShow = endTimeWatch.value > 0 && endTimeWatch.value <= failTimerShowTime
  return {
    watch = endTimeWatch
    margin = [hdpx(4), 0]
    children = shouldShow
      ? {
          rendObj = ROBJ_TEXT
          color = timeIsRunningOut ? Color(155, 0, 0, 95) : Color(155, 155, 155, 95)
          text = secondsToStringLoc(endTimeWatch.value)
        }.__update(timeIsRunningOut ? fontHeading2 : fontBody)
      : null
  }
}

let failTimerBlock = makeFailTimer(anyTeamFailTimer)
let myTeamFailTimerBlock = makeFailTimer(myTeamFailTimer)
let enemyTeamFailTimerBlock = makeFailTimer(enemyTeamFailTimer)

let attackerScoreWatch = Computed(function() {
  let score = isMyTeamAttacking.value ? myScore.value : enemyScore.value
  return score == null ? null : (1000.0 * score + 0.5).tointeger()
})


local scoreAnimLastValue = null
local scoreAnimIdx = 0
let scoreAnimStack = Watched([])

function onFinishScoreAnim() {
  if (scoreAnimStack.value.len() == 0)
    return

  scoreAnimLastValue = scoreAnimStack.value[0]
  scoreAnimStack.mutate(@(v) v.remove(0))
}

attackerScoreWatch.subscribe(function(val) {
  scoreAnimStack.mutate(@(v) v.append(val))
})

let mkSquadSizeIcon = @(color, iconSize) {
  rendObj = ROBJ_IMAGE
  image = Picture("ui/skin#initial_squad_size.svg:{0}:{0}:K".subst(iconSize))
  color
  size = [iconSize, iconSize]
}

let scoreDeltaAnim = [
  { prop = AnimProp.translate, from = [-90, 0], to = [-90, 0],
    duration = 0.7, play = true }
  { prop = AnimProp.scale, from = [1, 1], to = [1.8, 1.8],
    duration = 0.5, play = true, easing = Blink }
  { prop = AnimProp.opacity, from = 0.3, to = 1,
    duration = 0.2, play = true }
  { prop = AnimProp.translate, from = [-90, 0], to = [-30, 0], delay = 0.7,
    duration = 0.2, play = true, onFinish = onFinishScoreAnim }
]

function scoreDeltaAnimUi() {
  scoreAnimIdx++
  let addColor = isMyTeamAttacking.value ? style.TEAM0_COLOR_FG : style.TEAM1_COLOR_FG
  let removeColor = isMyTeamAttacking.value ? style.TEAM1_COLOR_FG : style.TEAM0_COLOR_FG
  let nextScoreValue = scoreAnimStack.value?[0] ?? attackerScoreWatch.value
  let scoreDelta = scoreAnimLastValue == null ? 0 : nextScoreValue - scoreAnimLastValue
  let color = scoreDelta < 0 ? removeColor : addColor
  let signObj = scoreDelta > 0 ? mkText("+", { color }.__update(fontBody))
    : scoreDelta < 0 ? mkText("-", { color }.__update(fontBody))
    : null

  return {
    watch = [scoreAnimStack, attackerScoreWatch, isMyTeamAttacking]
    size = [SIZE_TO_CONTENT, flex()]
    valign = ALIGN_CENTER
    children = {
      key = $"play_score_anim_{scoreAnimIdx}"
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      children = scoreDelta == 0 ? null : [
        signObj
        mkSquadSizeIcon(color, hdpxi(18))
        mkText($"{abs(scoreDelta)}", { color })
      ]
      transform = { pivot = [0.5, 0.5] }
      animations = scoreDeltaAnim
    }
  }
}


function attackingTeamPoints() {
  let color = isMyTeamAttacking.value ? style.TEAM0_COLOR_FG : style.TEAM1_COLOR_FG
  let scoreVal = scoreAnimStack.value.len() == 0
    ? attackerScoreWatch.value
    : scoreAnimLastValue ?? attackerScoreWatch.value

  return {
    watch = [isMyTeamAttacking, attackerScoreWatch, scoreAnimStack]
    children = [
      scoreDeltaAnimUi
      {
        flow = FLOW_HORIZONTAL
        valign = ALIGN_CENTER
        children = [
          mkSquadSizeIcon(color, hdpxi(32))
          mkText(scoreVal, { color }.__update(fontBody))
        ]
        transform = { pivot = [0.2, 0.5] }
        animations = [
          {
            prop = AnimProp.scale, from = [1, 1], to = [1.3, 1.3],
            duration = 0.5, easing = Blink, trigger = SCORE_ANIM_TRIGGER
          }
          {
            prop = AnimProp.opacity, from = 1, to = 0.7,
            duration = 0.5, easing = Blink, trigger = SCORE_ANIM_TRIGGER
          }
        ]
      }
    ]
  }
}

let modeDomination = @() {
  watch = hasScoreBar
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  gap = fsh(1)
  children = [
    hasScoreBar.value ? teamScores : null
    {
      flow = FLOW_HORIZONTAL
      children=[
        {size = [0,0] children = myTeamFailTimerBlock, halign = ALIGN_RIGHT},
        capZonesBlock,
        {size = [0,0] children = enemyTeamFailTimerBlock, halign = ALIGN_LEFT}
      ]
    }
  ]
}


let zombieWaveColor = 0xFFFF5577

function modeZombieWaveUi() {
  let hasTimer = zombiesNextWaveTime.value > 0
  return {
    watch = [ zombieModeCurWave, zombiesNextWaveTime ]
    size = [hdpx(180), SIZE_TO_CONTENT]
    valign = ALIGN_CENTER
    padding = [fsh(1.1), fsh(2)]
    margin = fsh(1.5)
    rendObj = ROBJ_IMAGE
    image = scoreNestGradientL
    color = 0xFF000000
    children = mkText(loc("zombieMod/curWave", {
      count = zombieModeCurWave.value + (hasTimer ? 0 : 1)
    }), { color = zombieWaveColor }.__merge(fontBody))
  }
}


function modeZombieWaveTimerUi() {
  let timerVal = zombiesNextWaveTime.value
  let hasTimer = timerVal > 0
  return {
    watch = [zombiesNextWaveTime, scoringPlayers, localPlayerEid]
    size = [SIZE_TO_CONTENT, hdpx(60)]
    hplace = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = hasTimer
      ? mkText(loc("zombieMod/nextWaveTime", {
          count = secondsToStringLoc(zombiesNextWaveTime.value)
        }), fontBody)
      : null
  }
}

function mkModeZombie() {
  let killCounter = Computed(@()
    scoringPlayers.value?[localPlayerEid.value].scoring_player__zombieKills ?? 0)
  return {
    size = [sw(100), SIZE_TO_CONTENT]
    padding = [0, fsh(2)]
    children = [
      modeZombieWaveUi
      modeZombieWaveTimerUi
      {
        size = [hdpx(180), SIZE_TO_CONTENT]
        flow = FLOW_VERTICAL
        hplace = ALIGN_RIGHT
        halign = ALIGN_RIGHT
        valign = ALIGN_CENTER
        padding = [fsh(1), fsh(2)]
        margin = fsh(1.5)
        rendObj = ROBJ_IMAGE
        image = scoreNestGradientR
        color = 0xFF000000
        children = [
          mkPointsUi("zombieModScore", "ui/skin#score.svg", Watched(true),
            zombieModeHeroPoints)
          mkPointsUi("killCounter", "ui/skin#statistics_kills_icon.svg",
            Watched(true), killCounter)
        ]
      }
    ]
  }
}


let modeInvasion = {
  flow = FLOW_HORIZONTAL
  valign = ALIGN_TOP
  gap = fsh(1)
  children = [
    {size = [0,0] children = attackingTeamPoints, halign = ALIGN_RIGHT}
    {
      flow = FLOW_VERTICAL
      halign = ALIGN_RIGHT
      gap = fsh(1)
      children = [capZonesBlock, failTimerBlock]
    }
  ]
}

let modeEscort = {
  valign = ALIGN_BOTTOM
  children = [
    {
      flow = FLOW_HORIZONTAL
      valign = ALIGN_BOTTOM
      children = [
        {size = [0,SIZE_TO_CONTENT], children = attackingTeamPoints, halign = ALIGN_RIGHT, padding = [0, fsh(3)]}
        {
          padding = [0,0,hdpx(16) - escortPointSize[1]/2,0] // TODO: align score with line properly
          flow = FLOW_VERTICAL
          halign = ALIGN_CENTER
          children = [escortBlock]
        }
        {size = [0,SIZE_TO_CONTENT], children = failTimerBlock, halign = ALIGN_LEFT, padding = [0, fsh(3)]}
      ]
    },
    {
      hplace = ALIGN_CENTER
      children = [capZoneOnTrainBlock]
    }
  ]
}


let isDominationMode = Computed(@() whichTeamAttack.value < 0)
let isEscortMode = Computed(@() capZones.value.findindex(@(zone) zone?.trainZone) != null)

console_register_command(function(steps) {
  let curVal = attackerScoreWatch.value
  for (local i = 0; i < steps; i++)
    scoreAnimStack.mutate(@(v) v.append(curVal - random.rnd_int(10, 50)))
}, "meta.addScoresAnim")

let gameModeBlock = @() {
  watch = [isDominationMode, isGunGameMode, isZombieMode]
  hplace = ALIGN_CENTER
  children = isGunGameMode.value ? GunGameModeUI
           : isZombieMode.value ? mkModeZombie()
           : isEscortMode.value ? modeEscort
           : isDominationMode.value ? modeDomination
           : modeInvasion
}

return gameModeBlock