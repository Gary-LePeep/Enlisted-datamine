from "%enlSqGlob/ui_library.nut" import *

let { fontBody, fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let { transpPanelBgColor, panelBgColor, defItemBlur, bigPadding, largePadding, startBtnWidth,
  defTxtColor, titleTxtColor, smallPadding, miniPadding
} = require("%enlSqGlob/ui/designConst.nut")
let { secondsToStringLoc } = require("%ui/helpers/time.nut")
let { mkArmyIcon } = require("%enlist/soldiers/components/armyPackage.nut")
let { allArmiesTiers, maxMatesArmiesTiers } = require("%enlist/soldiers/armySquadTier.nut")
let spinner = require("%ui/components/spinner.nut")
let cursors = require("%ui/style/cursors.nut")
let { randTeamAvailable, randTeamCheckbox, matchRandomTeam, crossplayHint,
  alwaysRandTeamSign, isCurQueueReqRandomSide
} = require("%enlist/quickMatch.nut")
let { timeInQueue, isInQueue } = require("%enlist/state/queueState.nut")
let { noteTextArea, txt } = require("%enlSqGlob/ui/defcomps.nut")
let { allArmiesInfo } = require("%enlist/soldiers/model/config/gameProfile.nut")
let { curArmiesList, curArmy } = require("%enlist/soldiers/model/state.nut")
let { eventsArmiesList, eventCurArmyIdx } = require("%enlist/gameModes/eventModesState.nut")
let { doubleSideHighlightLine, doubleSideHighlightLineBottom, doubleSideBg
} = require("%enlSqGlob/ui/defComponents.nut")
let { mkDailyTasksUi, eventTasksUi } = require("%enlist/unlocks/taskWidgetUi.nut")
let { eventsKeysSorted } = require("%enlist/offers/offersState.nut")
let { mkBattleRating } = require("%enlSqGlob/ui/battleRatingPkg.nut")
let { squadLeaderState } = require("%enlist/squad/squadState.nut")
let { isInSquad } = require("%enlist/squad/squadManager.nut")
let { remap_others } = require("%enlSqGlob/remap_nick.nut")

const TIME_BEFORE_SHOW_QUEUE = 1

let titleHeight = fsh(5.1)
let spinnerHeight = fsh(6)
let waitingSpinner = spinner(spinnerHeight)
let armyIconWidth = hdpx(120)
let armiesGap = hdpx(20)

let infoContainer = {
  transform = {}
  animations = [
    { prop=AnimProp.translate,  from=[0, sh(5)], to=[0,0], duration=0.5, play=true, easing=OutBack }
    { prop=AnimProp.opacity, from=0.0, to=1.0, duration=0.25, play=true, easing=OutCubic }
    { prop=AnimProp.translate, from=[0,0], to=[0, sh(30)], duration=0.7, playFadeOut=true, easing=OutCubic }
    { prop=AnimProp.opacity, from=1.0, to=0.0, duration=0.6, playFadeOut=true, easing=OutCubic }
  ]
}

let function queueTitle() {
  return {
    size = [flex(), titleHeight]
    flow = FLOW_VERTICAL
    watch = timeInQueue
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    vplace = ALIGN_TOP
    children = [
      doubleSideHighlightLine
      doubleSideBg(
        noteTextArea({
          text = loc("queue/searching", {
            wait_time = secondsToStringLoc(timeInQueue.value  / 1000)
          })
          halign = ALIGN_CENTER
          color = titleTxtColor
        }).__update(fontBody)
      )
      doubleSideHighlightLineBottom
    ]
  }
}

let mkPlayers = @(players) {
  flow = FLOW_VERTICAL
  gap = miniPadding
  halign = ALIGN_CENTER
  children = players.map(@(name) txt(remap_others(name)))
}

let function queueArmiesBlock() {
  let squadLeaderInfo = squadLeaderState.value
  local armyList = curArmiesList.value
  local armyId = curArmy.value
  local isRandomTeam = matchRandomTeam.value
  if (isInSquad.value && squadLeaderInfo != null) {
    armyId = squadLeaderInfo.curArmy
    isRandomTeam = squadLeaderInfo.isTeamRandom
  }
  if (eventsArmiesList.value.len() > 0) {
    armyList = eventsArmiesList.value
    armyId = eventsArmiesList.value[eventCurArmyIdx.value]
  }
  if (!isRandomTeam)
    armyList = armyList.filter(@(army) army == armyId)
  return {
    watch = [curArmiesList, curArmy, eventsArmiesList, eventCurArmyIdx, allArmiesInfo,
      matchRandomTeam, squadLeaderState, isInSquad]
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = bigPadding
    children = [
      {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        gap =  armiesGap
        halign = ALIGN_CENTER
        valign = ALIGN_TOP
        children = armyList.map(function(army) {
          let armyTier = Computed(@() maxMatesArmiesTiers.value?[army].tier
            ?? allArmiesTiers.value?.armies[army] ?? 1)
          let armyPlayers = Computed(@() maxMatesArmiesTiers.value?[army].players ?? [])
          return @() {
            watch = [armyTier, armyPlayers]
            flow = FLOW_VERTICAL
            halign = ALIGN_CENTER
            gap = smallPadding
            children = [
              {
                rendObj = ROBJ_BOX
                fillColor = Color(10,10,10,10)
                size = [armyIconWidth, SIZE_TO_CONTENT]
                halign = ALIGN_CENTER
                valign = ALIGN_CENTER
                children = mkArmyIcon(allArmiesInfo.value?[army].id)
              }
              mkBattleRating(armyTier.value)
              isInSquad.value && armyPlayers.value.len() > 0 ? mkPlayers(armyPlayers.value) : null
            ]
          }
        })
      }
      {
        rendObj = ROBJ_TEXTAREA
        size = [flex(), SIZE_TO_CONTENT]
        behavior = Behaviors.TextArea
        maxWidth = hdpx(650)
        color = defTxtColor
        hplace = ALIGN_CENTER
        halign = ALIGN_CENTER
        text = loc("battleRating/desc")
      }.__update(fontSub)
      waitingSpinner
    ]
  }
}

let function mkQueueContent() {
  let needQueueInfo = Computed(@() timeInQueue.value / 1000 > TIME_BEFORE_SHOW_QUEUE)
  return @() {
    watch = needQueueInfo
    size = [flex(), SIZE_TO_CONTENT]
    minHeight = hdpx(260)
    padding = [0, bigPadding]
    children = needQueueInfo.value ? queueArmiesBlock : null
  }
}

let randomTeamHint = noteTextArea({
  text = loc("queue/join_any_team_hint")
  halign = ALIGN_CENTER
  color = titleTxtColor
}).__update(fontSub)

let function mkRandomTeamContent() {
  let res = { watch = [randTeamAvailable, isCurQueueReqRandomSide, matchRandomTeam] }
  if (!randTeamAvailable.value)
    return res

  return res.__update({
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    halign = ALIGN_CENTER
    children = [
      matchRandomTeam.value ? null : randomTeamHint
      isCurQueueReqRandomSide.value ? alwaysRandTeamSign : randTeamCheckbox
    ]
  })
}

let eventTasksBlock = @(event) {
  size = [startBtnWidth, SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  gap = bigPadding
  children = [
    {
      rendObj = ROBJ_TEXT
      text = loc("eventTasks")
      color = defTxtColor
    }.__update(fontBody)
    {
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      children = eventTasksUi(event, 2)
    }
  ]
}

let dailyTasksBlock = {
  flow = FLOW_VERTICAL
  gap = largePadding
  children = [
    {
      rendObj = ROBJ_TEXT
      text = loc("dailyTasks")
      color = defTxtColor
    }.__update(fontBody)
    mkDailyTasksUi(true)
  ]
}

let tasksBlock = @(events) {
  rendObj = ROBJ_WORLD_BLUR
  fillColor = panelBgColor
  color = defItemBlur
  padding = bigPadding
  halign = ALIGN_CENTER
  flow = FLOW_HORIZONTAL
  gap = hdpx(30)
  children = [
    dailyTasksBlock
    events.len() > 0 ? eventTasksBlock(events[0]) : null
  ]
}

local dxSum = 0.0
local dySum = 0.0
local canBeUpdated = false

let wndContent = @(events) {
  flow = FLOW_VERTICAL
  gap = largePadding
  valign = ALIGN_TOP
  halign = ALIGN_CENTER
  minWidth = fsh(55)
  padding = [0,0, largePadding, 0]
  children = [
    queueTitle
    crossplayHint
    mkQueueContent()
    mkRandomTeamContent
    tasksBlock(events)
  ]
}.__merge(infoContainer)

let wndPosition = { pos = [0, 0] }
let function updatePosition(size) {
  wndPosition.pos <- [sw(50) - size[0] / 2, sh(80) - size[1]]
}
let position = Watched(wndPosition)

return function queueWaitingInfo() {
  if (!isInQueue.value)
    return { watch = isInQueue }

  let events = eventsKeysSorted.value
  let wndSize = calc_comp_size(wndContent(events))
  updatePosition(wndSize)
  return {
    watch = [isInQueue, eventsKeysSorted]
    children = function() {
      let { pos } = position.value
      return {
        watch = position
        fillColor = transpPanelBgColor
        borderRadius = hdpx(2)
        rendObj = ROBJ_WORLD_BLUR_PANEL
        moveResizeCursors = null
        behavior = [Behaviors.MoveResize, Behaviors.RtPropUpdate]
        update = function() {
          canBeUpdated = true
        }
        cursor = cursors.normal
        stopHover = true
        valign = ALIGN_CENTER
        key = 1
        pos
        onMoveResize = function(dx, dy, _dw, _dh) {
          dxSum += dx
          dySum += dy
          if (!canBeUpdated)
            return null
          canBeUpdated = false
          let newPos = { pos =  [
            clamp(pos[0] + dxSum, 0, sw(100) - wndSize[0]),
            clamp(pos[1] + dySum, 0, sh(100) - wndSize[1])
          ]}
          position(newPos)
          dxSum = 0
          dySum = 0
          return newPos
        }
        children = wndContent(events)
      }
    }
  }
}