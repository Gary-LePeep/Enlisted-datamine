from "%enlSqGlob/ui/ui_library.nut" import *

let { fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let faComp = require("%ui/components/faComp.nut")
let fontIconButton = require("%ui/components/fontIconButton.nut")
let mkCountdownTimer = require("%enlSqGlob/ui/mkCountdownTimer.nut")
let {
  mkCardText, squadBgColor, mkSquadIcon, mkSquadTypeIcon, mkSquadPremIcon,
  txtColor
} = require("%enlSqGlob/ui/squadsUiComps.nut")
let {
  midPadding, smallPadding, squadSlotHorSize,
  listCtors, defTxtColor, selectedTxtColor, activeBgColor
} = require("%enlSqGlob/ui/designConst.nut")
let { nameColor, txtDisabledColor } = listCtors
let { getItemName } = require("%enlSqGlob/ui/itemsInfo.nut")
let {
  selectedSquadId, reserveSquads, chosenSquads, getCantTakeReason
} = require("model/chooseSquadsState.nut")
let { isGamepad } = require("%ui/control/active_controls.nut")
let openSquadTextTutorial = require("%enlist/tutorial/squadTextTutorial.nut")
let { sound_play } = require("%dngscripts/sound_system.nut")
let { mkBattleRating } = require("%enlSqGlob/ui/battleRatingPkg.nut")
let { getSquadBR } = require("%enlist/soldiers/armySquadTier.nut")


let squadIconSize = [hdpxi(60), hdpxi(60)]
let squadTypeIconSize = hdpxi(20)
let dragIconWidth = hdpxi(25)

let curDropData = Watched(null)
let curDropTgtIdx = Watched(-1)
curDropData.subscribe(@(_) curDropTgtIdx(-1))

let highlightSlots = Computed(function() {
  let allSlots = chosenSquads.value
  let total = allSlots.len()
  local reserveIdx = curDropData.value?.squadIdx
  if (reserveIdx != null)
    reserveIdx -= total
  else {
    let selSquadId = selectedSquadId.value
    reserveIdx = reserveSquads.value.findindex(@(s) s.squadId == selSquadId)
  }

  let squad = reserveSquads.value?[reserveIdx]
  return squad == null ? []
    : allSlots.map(@(_, idx) getCantTakeReason(squad, allSlots, idx) == null)
})

let getMoveDirSameList = @(idx, dropIdx, targetIdx)
  dropIdx < idx && targetIdx >= idx ? -1
    : dropIdx > idx && targetIdx <= idx ? 1
    : 0

let mkMoveDirComputed = @(idx, fixedSlots) Computed(function() {
  let dropIdx = curDropData.value?.squadIdx ?? -1
  let targetIdx = curDropTgtIdx.value
  if (targetIdx < 0 || dropIdx < 0)
    return 0
  if (idx < fixedSlots)
    return dropIdx < fixedSlots && targetIdx < fixedSlots
      ? getMoveDirSameList(idx, dropIdx, targetIdx)
      : 0
  return dropIdx >= fixedSlots && targetIdx >= fixedSlots
    ? getMoveDirSameList(idx, dropIdx, targetIdx)
    : dropIdx < fixedSlots && targetIdx >= fixedSlots && targetIdx <= idx
      ? 1
      : 0
})

function squadDragAnim(moveDir, idx, stateFlags, content, chContent, needMoveCursor = false) {
  function onAttach(elem) {
    if (isGamepad.value && needMoveCursor)
      move_mouse_cursor(elem, false)
  }

  function onElemState(sf) {
    stateFlags(sf)
    if (!curDropData.value || curDropData.value.squadIdx == idx)
      return
    if (sf & S_ACTIVE)
      curDropTgtIdx(idx)
    else if (curDropTgtIdx.value == idx)
      curDropTgtIdx(-1)
  }

  return content.__merge({
    behavior = Behaviors.DragAndDrop
    onAttach
    xmbNode = XmbNode()
    canDrop = @(data) data?.dragid == "squad"
    dropData = "dropData" in content ? content.dropData : { squadIdx = idx, dragid = "squad" }
    onDragMode = function(on, data){
      if (on)
        sound_play("ui/inventory_item_take")
      curDropData(on ? data : null)
    }
    onElemState
    transform = {}
    children = curDropData.value ? chContent.__merge({
      transform = {}
      transitions = [{ prop = AnimProp.translate, duration = 0.3, easing = OutQuad }]
      behavior = Behaviors.RtPropUpdate
      rtAlwaysUpdate = true
      update = @() {
        transform = { translate = [0, moveDir.value * (squadSlotHorSize[1] + midPadding)] }
      }
    }) : chContent
  })
}

let highlightBorder = {
  size = flex()
  rendObj = ROBJ_FRAME
  borderWidth = hdpx(1)
  color = activeBgColor
}

let getIconColor = @(sf, isHovered, isSelected) sf & S_ACTIVE ? selectedTxtColor
  : sf & S_HOVER ? Color(70,70,70)
  : isHovered || isSelected ? selectedTxtColor
  : defTxtColor

let mkInfoBtn = @(onInfoCb, squadId, override, stateFlags, isHovered, isSelected)
  fontIconButton("info", {
    stateFlags
    onClick = @() onInfoCb(squadId)
    margin = 0
    iconParams = { size = [dragIconWidth, dragIconWidth], halign = ALIGN_CENTER }
    fontSize = dragIconWidth
    iconColor = @(sf) getIconColor(sf, isHovered, isSelected)
  }.__update(override))

let mkSellBtn = @(onSellCb, override, stateFlags, isHovered, isSelected)
  fontIconButton("trash", {
    stateFlags
    onClick = onSellCb
    margin = 0
    iconParams = { size = [dragIconWidth, dragIconWidth], halign = ALIGN_CENTER }
    fontSize = dragIconWidth
    iconColor = @(sf) getIconColor(sf, isHovered, isSelected)
  }.__update(override))


let dragIcon = @(sf) {
  rendObj = ROBJ_IMAGE
  size = [dragIconWidth, dragIconWidth]
  margin = [0, midPadding, 0, 0]
  keepAspect = KEEP_ASPECT_FIT
  image = Picture("!ui/squads/drag_squads.svg:{0}:{0}:K".subst(dragIconWidth))
  color = txtColor(sf)
}

let tutorialIcon = @(squadType, isHovered, isSelected) watchElemState(@(sf) {
  rendObj = ROBJ_IMAGE
  behavior = Behaviors.Button
  keepAspect = KEEP_ASPECT_FIT
  onClick = @() openSquadTextTutorial(squadType)
  size = [dragIconWidth, dragIconWidth]
  image = Picture("!ui/squads/tutorial_squad.svg:{0}:{0}:K".subst(dragIconWidth))
  color = getIconColor(sf, isHovered, isSelected)
})


let mkHorizontalSlot = kwarg(function (guid, squadId, idx, onClick, manageLocId,
  isSelected = Watched(false), onInfoCb = null, onDropCb = null, group = null, addChildren = null,
  icon = "", squadType = "", level = 0, vehicle = null, squadSize = null, battleExpBonus = 0,
  isOwn = true, fixedSlots = -1, override = {}, premIcon = null, isLocked = false, unlockObj = null,
  needMoveCursor = false, firstSlotToAnim = null, secondSlotToAnim = null, stateFlags = null,
  needSquadTutorial = false, expireTime = 0, size = null, onSellCb = null
) {
  let stateFlagsUnfiltered = stateFlags ?? Watched(0)
  stateFlags = Computed(@() stateFlagsUnfiltered.value & ~S_TOP_HOVER)

  function onDrop(data) {
    onDropCb?(data?.squadIdx, idx)
  }

  let isDropTarget = Computed(@() idx < fixedSlots
    && curDropTgtIdx.value == idx
    && (curDropData.value?.squadIdx ?? -1) >= fixedSlots)

  let needHighlight = Computed(@() highlightSlots.value?[idx] ?? false)

  let key = $"slot{guid}{idx}" //used for animations and tutorial

  let animations = [
    { prop=AnimProp.translate, from=[0, squadSlotHorSize[1]], to=[0, 0], duration=0.2, trigger = $"squadMoveTop{idx}",  easing=OutCubic }
    { prop=AnimProp.translate, from=[0, -squadSlotHorSize[1]], to=[0, 0], duration=0.2, trigger = $"squadMoveBottom{idx}", easing=OutCubic }
  ]

  function onAttach() {
    if (firstSlotToAnim != null || secondSlotToAnim != null) {
      anim_start($"squadMoveTop{min(firstSlotToAnim, secondSlotToAnim)}")
      anim_start($"squadMoveBottom{max(firstSlotToAnim, secondSlotToAnim)}")
    }
  }

  let squadIcon = mkSquadIcon(icon, { size = squadIconSize, margin = midPadding })
  let squadPremIcon = mkSquadPremIcon(premIcon, { margin = [hdpx(2), 0] })
  let watch = [isSelected, stateFlags, isDropTarget, needHighlight, isGamepad]
  let infoBtnStateFlags = Watched(0)
  let sellBtnStateFlags = Watched(0)

  let opacity = isOwn ? 1.0 : 0.5

  local bonusText = ""
  if (battleExpBonus > 0) {
    let expBonus = (100 * battleExpBonus).tointeger()
    bonusText = $"{loc("XP")}{loc("ui/colon")}+{expBonus}%"
  }
  else
    bonusText = loc("levelInfo", { level = level + 1 })

  let mainText = $"{bonusText}, {loc("squad/contain")}{squadSize ?? size}"
  let vehicleText = vehicle ? $"{loc("menu/vehicle")} {getItemName(vehicle)}" : ""
  let manageText = loc(manageLocId)
  let moveDir = onDropCb != null ? mkMoveDirComputed(idx, fixedSlots) : null

  return function() {
    let sf = stateFlags.value
    let selected = isSelected.value || isDropTarget.value
    let timerObj = expireTime == 0 ? null
      : mkCountdownTimer({
          timestamp = expireTime
          prefixLocId = "rented"
          expiredLocId = "rentExpired"
          color = txtColor(sf, selected)
          prefixColor = txtColor(sf, selected)
        })

    let bgColor = squadBgColor(sf, selected, isLocked)
    let chContent = {
      key
      size = flex()
      opacity
      transform = {}
      onAttach
      animations
      children = [
        {
          rendObj = ROBJ_SOLID
          flow = FLOW_HORIZONTAL
          size = flex()
          valign = ALIGN_CENTER
          gap = midPadding
          color = bgColor
          children = [
            {
              children = [
                squadIcon
                squadPremIcon
              ]
            }
            {
              size = flex()
              flow = FLOW_VERTICAL
              valign = ALIGN_CENTER
              gap = smallPadding
              clipChildren = true
              children = [
                {
                  size = [flex(), SIZE_TO_CONTENT]
                  behavior = Behaviors.Marquee
                  scrollOnHover = true
                  children = mkCardText(manageText, sf)
                }
                {
                  flow = FLOW_HORIZONTAL
                  valign = ALIGN_BOTTOM
                  children = [
                    mkSquadTypeIcon(squadType, sf, selected, squadTypeIconSize)
                    {
                      flow = FLOW_HORIZONTAL
                      valign = ALIGN_CENTER
                      gap = midPadding
                      children = [
                        {
                          flow = FLOW_HORIZONTAL
                          valign = ALIGN_CENTER
                          children = [
                            mkCardText(mainText, sf)
                            faComp("user-o", {
                              fontSize = hdpx(12)
                              color = txtColor(sf & S_HOVER, selected)
                            })
                          ]
                        }
                        isLocked ? null
                          : mkBattleRating(getSquadBR(squadId), { color = txtColor(sf) })
                        vehicle == null
                          ? null
                          : mkCardText(vehicleText, sf)
                      ]
                    }
                  ]
                }
              ]
            }
            timerObj
            unlockObj
            onSellCb != null
              ? mkSellBtn(onSellCb, override, sellBtnStateFlags, sf & S_HOVER, selected)
              : null
            needSquadTutorial ? tutorialIcon(squadType, sf & S_HOVER, selected) : null
            onInfoCb != null && !isGamepad.value
              ? mkInfoBtn(onInfoCb, squadId,
                          override, infoBtnStateFlags,
                          sf & S_HOVER, selected)
              : null
            !isLocked ? dragIcon(sf) : null
          ]
        }
        needHighlight.value ? highlightBorder : null
      ]
    }

    if (addChildren)
      chContent.children.extend(addChildren)

    return onDropCb != null
      ? squadDragAnim(moveDir, idx, stateFlagsUnfiltered,
          {
            watch
            group
            size = squadSlotHorSize
            key = $"{guid}{idx}"
            onDrop
            onClick
          }.__update(override),
          chContent, needMoveCursor)
      : {
          watch
          group
          size = squadSlotHorSize
          onClick
          behavior = Behaviors.Button
          xmbNode = XmbNode()
          onElemState = @(s) stateFlagsUnfiltered(s)
          transform = {}
          children = chContent
        }
  }
})


let horSlotText = @(hasBlink, isDropTarget, text, style = {}) {
  rendObj = ROBJ_TEXT
  key = $"hasBlink{hasBlink}"
  text
  color = hasBlink
    ? nameColor(0, isDropTarget)
    : txtDisabledColor(0, isDropTarget)
  animations = hasBlink
    ? [{
        prop = AnimProp.opacity, from = 0.4, to = 0.6,
        duration = 1, play = true, loop = true, easing = Blink
      }]
    : null
}.__merge(fontSub, style)

let angleLeft = faComp("angle-left", { hplace = ALIGN_RIGHT, padding = [0, hdpx(15)], fontSize = hdpx(30)})

let mkEmptyHorizontalSlot = kwarg(
  function(idx, onDropCb, fixedSlots = -1, group = null, hasBlink = false) {
    let stateFlags = Watched(0)
    let isDropTarget = Computed(@() idx < fixedSlots
      && curDropTgtIdx.value == idx
      && (curDropData.value?.squadIdx ?? -1) >= fixedSlots)
    let needHighlight = Computed(@() highlightSlots.value?[idx] ?? false)
    let onDrop = @(data) onDropCb(data?.squadIdx, idx)
    let moveDir = mkMoveDirComputed(idx, fixedSlots)

    return function() {
      let chContent = {
        rendObj = ROBJ_SOLID
        key = $"empty_slot{idx}" //used in animations and tutorial
        size = flex()
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        transform = {}
        color = squadBgColor(0, isDropTarget.value)
        children = [
          horSlotText(hasBlink, isDropTarget.value, loc("squads/squadFreeSlot"),{
            padding = [0, hdpx(20)],
            hplace = ALIGN_LEFT
          })
          horSlotText(hasBlink, isDropTarget.value, loc("squads/dragFromReserve"),{
            padding = [0, hdpx(40)],
            hplace = ALIGN_RIGHT
          })
          horSlotText(hasBlink, isDropTarget.value, null, angleLeft)
          needHighlight.value ? highlightBorder : null
        ]
      }
      return squadDragAnim(moveDir, idx, stateFlags,
        {
          watch = [stateFlags, isDropTarget, needHighlight]
          size = squadSlotHorSize
          key = $"empty_{idx}"
          onDrop
          dropData = null
          fixedSlots
          group
        },
        chContent)
    }
  })

return {
  mkHorizontalSlot
  mkEmptyHorizontalSlot
  curDropData
}
