from "%enlSqGlob/ui/ui_library.nut" import *

let { ceil } = require("%sqstd/math.nut")
let { fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let hoverHoldAction = require("%darg/helpers/hoverHoldAction.nut")
let { blinkUnseenIcon } = require("%ui/components/unseenSignal.nut")
let { curArmy, armoryByArmy } = require("%enlist/soldiers/model/state.nut")
let { curSoldierIdx } = require("%enlist/soldiers/model/curSoldiersState.nut")
let { bigPadding, blurBgColor, blurBgFillColor, smallPadding,
  activeBgColor, defBgColor, slotBaseSize, scrollbarParams, listCtors,
  msgHighlightedTxtColor, fadedTxtColor
} = require("%enlSqGlob/ui/viewConst.nut")
let { nameColor, txtDisabledColor } = listCtors
let { hoverTxtColor } = require("%enlSqGlob/ui/designConst.nut")
let { READY, TOO_MUCH_CLASS, NOT_FIT_CUR_SQUAD, NOT_READY_BY_EQUIP
} = require("%enlSqGlob/readyStatus.nut")
let { note, noteTextArea } = require("%enlSqGlob/ui/defcomps.nut")
let { FAButton, Flat, Bordered } = require("%ui/components/textButton.nut")
let defBtnStyle = require("%ui/components/textButton.style.nut")
let { safeAreaBorders } = require("%enlist/options/safeAreaState.nut")
let checkbox = require("%ui/components/checkbox.nut")
let msgbox = require("%enlist/components/msgbox.nut")
let { squadSoldiers, reserveSoldiers, selectedSoldierGuid, selectedSoldier, soldiersStatuses,
  applySoldierManage, changeSoldierOrderByIdx, maxSoldiersInBattle, soldiersSquadParams,
  moveCurSoldier, soldierToReserveByIdx, curSoldierToReserve, curSoldierToSquad, getCanTakeSlots,
  soldiersSquad, curSquadSoldierIdx, closeChooseSoldiersWnd
  isPurchaseWndOpend, updateSoldiersListAndSort
} = require("model/chooseSoldiersState.nut")
let { sceneWithCameraAdd, sceneWithCameraRemove } = require("%enlist/sceneWithCamera.nut")
let { curArmyReserve, curArmyReserveCapacity } = require("model/reserve.nut")
let { gameProfile } = require("model/config/gameProfile.nut")
let { hasPremium } = require("%enlist/currency/premium.nut")
let closeBtnBase = require("%ui/components/closeBtn.nut")
let { makeVertScroll } = require("%ui/components/scrollbar.nut")
let { mkSoldierInfo, mkCustomButtons } = require("%enlist/soldiers/mkSoldierInfo.nut")
let squadHeader = require("components/squadHeader.nut")
let mkSoldierCard = require("%enlSqGlob/ui/mkSoldierCard.nut")
let mkValueWithBonus = require("%enlist/components/valueWithBonus.nut")
let mkHeader = require("%enlist/components/mkHeader.nut")
let { unseenSoldiers, markSoldierSeen } = require("model/unseenSoldiers.nut")
let gotoResearchUpgradeMsgBox = require("researchUpgradeMsgBox.nut")
let { curCanUnequipSoldiersList, massUnequipReserve } = require("model/selectItemState.nut")
let { debounce } = require("%sqstd/timers.nut")
let { needFreemiumStatus, curUpgradeDiscount } = require("%enlist/campaigns/campaignConfig.nut")
let { perkLevelsGrid } = require("%enlist/meta/perks/perksExp.nut")
let soldiersPurchaseWnd = require("%enlist/shop/soldiersPurchaseWnd.nut")
let { unseenSoldierShopItems } = require("%enlist/shop/soldiersPurchaseState.nut")
let { smallUnseenNoBlink } = require("%ui/components/unseenComps.nut")
let { bigDismissBtn, retireReturnCost, mkDismissWarning, mkApplyChangesWarning
} = require("%enlist/soldiers/soldierDismissBtn.nut")
let { isGamepad } = require("%ui/control/active_controls.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { mkPresetEquipBlock } = require("%enlist/preset/presetEquipUi.nut")
let { deselectSoldier } = require("model/squadInfoState.nut")
let { retireReturn } = require("model/config/soldierRetireConfig.nut")
let { getLinkedSquadGuid } = require("%enlSqGlob/ui/metalink.nut")


const NO_SOLDIER_SLOT_IDX = -1
const SOLDIERS_ON_PAGE = 12
let SELL_BTN_STYLE = {
  margin = 0
  size = [flex(), SIZE_TO_CONTENT]
  style = {
    BgDisabled = null
    BdDisabled = fadedTxtColor
    TextDisabled = fadedTxtColor
  }
}

let SELECT_ACTIVE_BTN_STYLE = {
  margin = 0
  size = [flex(), SIZE_TO_CONTENT]
  style = {
    BgNormal = defBtnStyle.BgActive
    BdNormal = defBtnStyle.BgNormal
    TextNormal = defBtnStyle.TextActive
  }
}

let massSelectStyle = {
  rendObj = ROBJ_FRAME
  borderWidth = hdpxi(2)
  padding = hdpxi(2)
  color = hoverTxtColor
}

let massSelectReadyStyle = {
  rendObj = ROBJ_FRAME
  borderWidth = hdpxi(1)
  padding = hdpxi(1)
  color = fadedTxtColor
}

let unseenIcon = blinkUnseenIcon(0.7, msgHighlightedTxtColor, "th-large")
let smallUnseenIcon = blinkUnseenIcon(0.7)

let slotWithPadding = [slotBaseSize[0], slotBaseSize[1] + bigPadding]
let boxSize = 2 * bigPadding + hdpxi(20)
let slotWithCheckbox = [slotWithPadding[0] + boxSize, slotWithPadding[1]]
let selectionSlotGamepad = [slotWithPadding[0] + smallPadding, slotWithPadding[1] + smallPadding]

let buttonMassUnequip = Flat(loc("removeAllEquipment/reserve"),
  @() msgbox.show({
    text = loc("removeAllEquipment/confirm")
    buttons = [
      {
        text = loc("Ok")
        action = @() massUnequipReserve(reserveSoldiers.value, armoryByArmy.value)
          customStyle = { hotkeys = [[$"^{JB.A} | Enter"]] }
      }
      {
        text = loc("Cancel")
        isCancel = true
        isCurrent = true
        customStyle = { hotkeys = [[$"^{JB.B} | Esc"]] }
      }
    ]
  }),
  {
    hplace = ALIGN_RIGHT
    vplace = ALIGN_BOTTOM
  })

function chooseSoldiersScene() {
  let reserveAvailableSize = Computed(@() reserveSoldiers.value.findindex(@(s)
      (soldiersStatuses.value?[s.guid] ?? NOT_FIT_CUR_SQUAD) & NOT_FIT_CUR_SQUAD)
    ?? reserveSoldiers.value.len())

  let curDropData = Watched(null)
  let curDropTgtIdx = Watched(NO_SOLDIER_SLOT_IDX)
  let curDropTgtIdxDebounced = Watched(NO_SOLDIER_SLOT_IDX)
  curDropData.subscribe(@(_) curDropTgtIdx(NO_SOLDIER_SLOT_IDX))
  curDropTgtIdx.subscribe(debounce(@(_) curDropTgtIdxDebounced(curDropTgtIdx.value), 0.01))

  let moveParams = Computed(function() {
    local watch = null
    local idx = null
    let guid = selectedSoldierGuid.value
    if (guid != null)
      foreach (w in [squadSoldiers, reserveSoldiers]) {
        idx = w.value.findindex(@(s) s?.guid == guid)
        if (idx != null) {
          watch = w
          break
        }
      }

    let listSize = watch == squadSoldiers ? watch.value.len()
      : watch == reserveSoldiers ? reserveAvailableSize.value
      : 0
    let isAvailable = watch != null && idx < listSize
    return {
      canUp = isAvailable && idx > 0
      canDown = isAvailable && idx < listSize - 1
      canRemove = watch == squadSoldiers
      canTake = watch == reserveSoldiers
      takeAvailable = isAvailable && soldiersStatuses.value?[guid] == READY
        && squadSoldiers.value.findindex(@(s) s == null) != null
    }
  })

  let soldierToTake = Computed(function() {
    let dropIdx = curDropData.value?.soldierIdx
    if (dropIdx != null)
      return reserveSoldiers.value?[dropIdx - maxSoldiersInBattle.value]
    let selGuid = selectedSoldierGuid.value
    return selGuid == null ? null : reserveSoldiers.value.findvalue(@(s) s?.guid == selGuid)
  })

  let slotsHighlight = Computed(function() {
    let soldier = soldierToTake.value
    return soldier == null ? [] : getCanTakeSlots(soldier, squadSoldiers.value)
  })

  let commonLimit = Computed(@() curArmyReserveCapacity.value
    - (hasPremium.value ? (gameProfile.value?.premiumBonuses.soldiersReserve ?? 0) : 0))
  let premiumLimit = Computed(@() hasPremium.value ? curArmyReserveCapacity.value : null)
  function reserveCountBlock() {
    let res = { watch = [reserveSoldiers] }
    let reserveCount = reserveSoldiers.value.len()
    if (reserveCount <= 0)
      return res

    return res.__update({
      valign = ALIGN_CENTER
      flow = FLOW_HORIZONTAL
      gap = smallPadding
      children = [
        note(loc("squad/reserveAmount", { count = reserveCount }))
        mkValueWithBonus(commonLimit, premiumLimit)
      ]
    })
  }

  let buttonOk = Flat(loc("Close"), @() applySoldierManage(closeChooseSoldiersWnd),
    { margin = 0, hplace = ALIGN_RIGHT, hotkeys = [[$"^{JB.B} | Esc"]] })

  let getMoveDirSameList = @(idx, dropIdx, targetIdx)
    dropIdx < idx && targetIdx >= idx ? -1
      : dropIdx > idx && targetIdx <= idx ? 1
      : 0

  let mkMoveDirComputed = @(idx, fixedSlotsWatch) Computed(function() {
    let dropIdx = curDropData.value?.soldierIdx ?? -1
    let targetIdx = curDropTgtIdxDebounced.value
    if (targetIdx < 0 || dropIdx < 0 || dropIdx == idx)
      return 0
    let fixedSlots = fixedSlotsWatch.value
    if (idx < fixedSlots)
      return dropIdx < fixedSlots && targetIdx < fixedSlots ? getMoveDirSameList(idx, dropIdx, targetIdx) : 0
    return dropIdx >= fixedSlots && targetIdx >= fixedSlots ? getMoveDirSameList(idx, dropIdx, targetIdx)
      : dropIdx < fixedSlots && targetIdx >= fixedSlots && targetIdx <= idx ? 1
      : 0
  })

  let soldierDragAnim = @(moveDir, idx, stateFlags, content, chContent)
    content.__merge({
      behavior = Behaviors.DragAndDrop
      canDrop = @(data) data?.dragid == "soldier"
      dropData = "dropData" in content ? content.dropData : { soldierIdx = idx, dragid = "soldier" }
      onDragMode = @(on, data) curDropData(on ? data : null)
      onElemState = function(sf) {
        stateFlags(sf)
        if (!curDropData.value || curDropData.value.soldierIdx == idx)
          return
        if (sf & S_ACTIVE)
          curDropTgtIdx(idx)
        else if (curDropTgtIdx.value == idx)
          curDropTgtIdx(NO_SOLDIER_SLOT_IDX)
      }
      transform = {}
      children = curDropData.value ? chContent.__merge({
        transform = {}
        transitions = [{ prop = AnimProp.translate, duration = 0.3, easing = OutQuad }]
        behavior = Behaviors.RtPropUpdate
        rtAlwaysUpdate = true
        update = @() {
          transform = { translate = [0, moveDir.value * slotWithPadding[1]] }
        }
      }) : chContent
    })

  let highlightBorder = {
    size = flex()
    rendObj = ROBJ_FRAME
    borderWidth = hdpx(1)
    borderColor = 0xFFFFFFFF
  }

  function mkEmptySlot(idx, tgtHighlight, hasBlink) {
    let group = ElemGroup()
    let onDrop = @(data) changeSoldierOrderByIdx(data?.soldierIdx, idx)
    let isDropTarget = Computed(@() curDropTgtIdx.value == idx
      && (curDropData.value?.soldierIdx ?? -1) >= maxSoldiersInBattle.value)
    let needHighlight = Computed(@() tgtHighlight.value?[idx] ?? false)
    let stateFlags = Watched(0)
    let moveDir = mkMoveDirComputed(idx, maxSoldiersInBattle)

    return function() {
      let content = {
        watch = [stateFlags, isDropTarget, needHighlight]
        group = group
        size = slotWithPadding
        key = $"emptySlot_{idx}"
        onDrop = onDrop
        dropData = null
        onClick = @() selectedSoldierGuid(null)
      }

      let chContent = {
        size = flex()
        padding = [0, 0, bigPadding, 0]
        children = {
          key = $"empty_slot_{idx}{hasBlink}"
          size = flex()
          rendObj = ROBJ_SOLID
          color = isDropTarget.value ? activeBgColor : defBgColor
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          children = [
            {
              rendObj = ROBJ_TEXT
              text = loc("squad/soldierFreeSlot")
              color = hasBlink
                ? nameColor(0, isDropTarget.value)
                : txtDisabledColor(0, isDropTarget.value)
              animations = hasBlink
                ? [{
                    prop = AnimProp.opacity, from = 0.4, to = 1, duration = 1,
                    play = true, loop = true, easing = Blink
                  }]
                : null
            }.__update(fontSub)
            needHighlight.value ? highlightBorder : null
          ]
        }
      }

      return soldierDragAnim(moveDir, idx, stateFlags, content, chContent)
    }
  }

  let unseenMark = @(soldierGuid) @() {
    watch = unseenSoldiers
    children = (unseenSoldiers.value?[soldierGuid] ?? false) ? smallUnseenIcon : null
  }

  let isMarkingForSale = Watched(false)
  let soldierCheckedState = {}
  let selectedSoldiersNum = Watched(0)
  let hoveredSoldierGuid = Watched(null)

  function selectHoveredSoldierForSale() {
    let guid = hoveredSoldierGuid.value
    if (guid == null)
      return
    if (guid not in soldierCheckedState)
      soldierCheckedState[guid] <- Watched(false)
    let watch = soldierCheckedState[guid]
    watch(!watch.value)
    if (!watch.value)
      selectedSoldiersNum(selectedSoldiersNum.value - 1)
    else
      selectedSoldiersNum(selectedSoldiersNum.value + 1)
  }

  function mkSoldierSlot(soldier, idx, tgtHighlight, addObjects, hasGroupSelection = false) {
    let isSelectedWatch = Computed(@() selectedSoldierGuid.value == soldier.guid)
    let isDropTarget = Computed(@() idx < maxSoldiersInBattle.value && curDropTgtIdx.value == idx
      && (curDropData.value?.soldierIdx ?? -1) >= maxSoldiersInBattle.value)
    let needHighlight = Computed(@() tgtHighlight.value?[idx] ?? false)
    let moveDir = mkMoveDirComputed(idx, maxSoldiersInBattle)

    let soldierStatus = Computed(@() soldiersStatuses.value?[soldier.guid] ?? READY)
    let onDrop = @(data) changeSoldierOrderByIdx(data?.soldierIdx, idx)
    let stateFlags = Watched(0)
    let group = ElemGroup()

    let hasSelectionUI = Computed(@() hasGroupSelection && isMarkingForSale.value)
    let hasCheckbox = Computed(@() hasSelectionUI.value && !isGamepad.value)

    return function mkSoldierSlotImpl() {
      let sf = stateFlags.value
      let status = soldierStatus.value
      let isSelected = isSelectedWatch.value
      let watch = [stateFlags, soldierStatus, isSelectedWatch, isDropTarget, needHighlight,
        isMarkingForSale, isGamepad]
      if (hasSelectionUI.value)
        watch.append(soldierCheckedState[soldier.guid])
      let isGroupSelected = hasSelectionUI.value && (soldierCheckedState?[soldier.guid].value ?? false)
      let borderStyle = !hasSelectionUI.value ? {}
        : isGroupSelected ? massSelectStyle
        : massSelectReadyStyle

      let content = {
        watch
        xmbNode = XmbNode()
        group = group
        size = !hasSelectionUI.value ? slotWithPadding
          : hasCheckbox.value ? slotWithCheckbox
          : selectionSlotGamepad
        key = $"slot{soldier?.guid}{idx}"
        onDrop = onDrop
        sound = {
          hover = "ui/enlist/button_highlight"
          click = "ui/enlist/button_click"
          active = "ui/enlist/button_action"
        }
        onClick = @() selectedSoldierGuid(soldier.guid == selectedSoldierGuid.value ? null : soldier.guid)
        onHover = function(on) {
          if (hasSelectionUI.value && isGamepad.value) {
            if (on)
              hoveredSoldierGuid(soldier.guid)
            else
              hoveredSoldierGuid(null)
          }
          hoverHoldAction("markSeenSoldier",
            { armyId = curArmy.value, guid = soldier?.guid },
            @(v) markSoldierSeen(v.armyId, v.guid))(on)
        }
      }

      let chContent = {
        padding = [0, bigPadding, 0, 0]
        flow = FLOW_HORIZONTAL
        valign = ALIGN_TOP
        children = [
          @() {
            watch = [needFreemiumStatus, perkLevelsGrid]
            children = [
              mkSoldierCard({
                soldierInfo = soldier
                expToLevel = perkLevelsGrid.value?.expToLevel
                size = slotBaseSize
                group = group
                sf = sf
                isGroupSelected
                isSelected = isSelected || isDropTarget.value
                isFaded = status != READY
                isClassRestricted = status & TOO_MUCH_CLASS
                hasAlertStyle = status & NOT_FIT_CUR_SQUAD
                hasWeaponWarning = !!(status & NOT_READY_BY_EQUIP)
                isFreemiumMode = needFreemiumStatus.value
                addChild = @(...) addObjects
              })
              needHighlight.value ? highlightBorder : null
            ]
          }.__update(borderStyle)
          hasCheckbox.value && !soldier.isHero
            ? checkbox(soldierCheckedState[soldier.guid], { text = null, margin = null },
                {
                  override = { gap = null, margin = bigPadding }
                  setValue = function(val) {
                    soldierCheckedState[soldier.guid](val)
                    if (!val)
                      selectedSoldiersNum(selectedSoldiersNum.value - 1)
                    else
                      selectedSoldiersNum(selectedSoldiersNum.value + 1)
                  }
                })
            : null
        ]
      }

      return hasSelectionUI.value || (status & NOT_FIT_CUR_SQUAD)
        ? content.__update({
            behavior = Behaviors.Button
            onElemState = @(s) stateFlags(s)
            transform = {}
            children = chContent
          })
        : soldierDragAnim(moveDir, idx, stateFlags, content, chContent)
    }
  }

  let mkSoldiersList = kwarg(@(soldiers, hasUnseen = false, idxOffset = Watched(0),
    tgtHighlight = Watched([]), slotsBlinkWatch = Watched(false), isInReserve = false,
    hasGroupSelection = false
  ) function() {
    let size = !(hasGroupSelection && isMarkingForSale.value) ? slotBaseSize
      : isGamepad.value ? selectionSlotGamepad
      : slotWithCheckbox
    return {
      watch = [soldiers, idxOffset, tgtHighlight, slotsBlinkWatch,
        curCanUnequipSoldiersList, isMarkingForSale, isGamepad]
      size = [size[0], SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      behavior = Behaviors.Button
      onClick = @() selectedSoldierGuid(null)
      children = soldiers.value.map(function(s, idx) {
        let addObjects = hasUnseen ? [unseenMark(s.guid)] : []
        if (isInReserve && s.guid in curCanUnequipSoldiersList.value)
          addObjects.append(unseenIcon)
        return s == null
          ? mkEmptySlot(idx + idxOffset.value, tgtHighlight, slotsBlinkWatch.value)
          : mkSoldierSlot(s, idx + idxOffset.value, tgtHighlight, addObjects, hasGroupSelection)
      })
    }
  })

  let labelUnableToAdd = @(listWatch) function() {
    let res = { watch = listWatch }
    if (listWatch.value.len() == 0)
      return res
    return res.__update({
      children = note(loc("squad/unableAddSoldier"))
    })
  }

  let bg = {
    rendObj = ROBJ_WORLD_BLUR_PANEL
    color = blurBgColor
    fillColor = blurBgFillColor
    padding = bigPadding
    flow = FLOW_VERTICAL
  }

  let faBtnParams = {
    borderWidth = 0
    borderRadius = 0
  }
  let faBtnVisualDisabled = faBtnParams.__merge({
    style = {
      BgNormal = Color(20, 20, 20, 170)
      BdNormal = Color(20, 20, 20, 20)
      TextNormal = Color(0, 0, 0, 100)
    }
  })

  function manageBlock() {
    let { canUp, canDown, canTake, canRemove, takeAvailable } = moveParams.value
    let hasMoveButtons = !isPurchaseWndOpend.value && !isMarkingForSale.value
    let needShowUpButton = canUp && hasMoveButtons
    let needShowDownButton = canDown && hasMoveButtons
    let canSelect = isMarkingForSale.value && (hoveredSoldierGuid.value != null)

    let buttons = isMarkingForSale.value
    ? [
        FAButton("check-square", selectHoveredSoldierForSale, faBtnParams.__merge({
          key = $"selectForSale_{canSelect}"
          hotkeys = [["^J:X", { description = loc("soldiers/mark") }]]
        }))
      ]
    : [
        FAButton("arrow-up", @() moveCurSoldier(-1), faBtnParams.__merge({
          key = $"moveUp_{canUp}"
          isEnabled = needShowUpButton
          hotkeys = needShowUpButton ? [["^J:Y", { description = loc("Move Up") }]]
            : null
        })),
        FAButton("arrow-down", @() moveCurSoldier(1), faBtnParams.__merge({
          key = $"moveDown_{canDown}"
          isEnabled = needShowDownButton
          hotkeys = needShowDownButton ? [["^J:X", { description = loc("Move Down") }]]
            : null
        })),
        canTake
          ? FAButton("arrow-left", curSoldierToSquad,
              (takeAvailable ? faBtnParams : faBtnVisualDisabled).__merge({
                key = $"moveToSquad_{takeAvailable}"
                hotkeys = [["^J:LB", { description = loc("TakeToBattle") }]]
              }))
          : FAButton("arrow-right", curSoldierToReserve, faBtnParams.__merge({
              key = $"moveToReserve_{canRemove}"
              isEnabled = canRemove
              hotkeys = canRemove ? [["^J:RB", { description = loc("MoveToReserve") }]] : null
            }))
      ]

    return {
      watch = [moveParams, isPurchaseWndOpend, isMarkingForSale, hoveredSoldierGuid]
      size = [flex(), SIZE_TO_CONTENT]
      valign = ALIGN_CENTER
      halign = ALIGN_RIGHT
      flow = FLOW_HORIZONTAL
      gap = bigPadding
      children = buttons.append({ size = flex() }, buttonOk)
    }
  }

  let soldiersManageHint = @() {
    watch = isGamepad
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = bigPadding
    children = isGamepad.value ? null : [
      noteTextArea(loc("soldier/manageHeader"))
      noteTextArea(loc("soldier/maxSoldiers"))
    ]
  }


  let hasEmptySlotsBlink = Computed(function() {
    return reserveSoldiers.value.slice(0, reserveAvailableSize.value)
      .findindex(@(s) unseenSoldiers.value?[s.guid] ?? false) != null
  })

  let squadList = bg.__merge({
    size = [slotWithPadding[0] + 2 * bigPadding, flex()]
    gap = bigPadding
    children = [
      squadHeader({
        curSquad = soldiersSquad
        curSquadParams = soldiersSquadParams
        soldiersList = Computed(@() squadSoldiers.value.filter(@(s) s != null))
        soldiersStatuses = soldiersStatuses
        vehicleCapacity = Watched(0)
      })
      note(loc("menu/soldier"))
      mkSoldiersList({
        soldiers = squadSoldiers
        hasUnseen = false
        idxOffset = Watched(0)
        tgtHighlight = slotsHighlight
        slotsBlinkWatch = hasEmptySlotsBlink
      })
      { size = flex() }
      soldiersManageHint
      manageBlock
    ]
  })

  let sellSelected = function() {
    let guids = {}
    soldierCheckedState.each(function(state, guid) {
      if (state.value)
        guids[guid] <- true
    })

    if (guids.len() == 0) {
      return
    }

    local totalCost = 0
    // iterate all reserve soldiers once and fetch relevant data
    foreach (soldier in reserveSoldiers.value) {
      if (soldier.guid not in guids)
        continue
      let { guid, sClass, tier, heroTpl, isHero } = soldier
      if (soldier.isHero) {
        // we have to filter heroes out
        //because gamepad selection interface does not exclude them
        guids.$rawdelete(soldier.guid)
        continue
      }

      if (getLinkedSquadGuid(soldier) != null) {
        mkApplyChangesWarning()
        return
      }

      let cost = retireReturnCost(reserveSoldiers.value, retireReturn.value,
        curArmyReserveCapacity.value, curArmyReserve.value,
        guid, sClass, tier, heroTpl, isHero)
      if (cost == null)
        return
      totalCost += cost
    }

    let retireCountMult = 1.0 - curUpgradeDiscount.value
    totalCost = ceil(totalCost * retireCountMult).tointeger()

    // mkDismissWarning makes the call to profile server
    // and takes the callback to that call as an argument
    mkDismissWarning(curArmy.value, guids.keys(), totalCost, function() {
      soldierCheckedState.each(function(state, guid) {
        if (state.value)
          soldierCheckedState.$rawdelete(guid)
      })
    })
  }

  let mkMarkBtn = @(isActive) Flat(loc("btn/selectSoldiers"),
    @() isMarkingForSale(!isMarkingForSale.value),
    { hotkeys = [["^J:Y"]] }
      .__update(isActive ? SELECT_ACTIVE_BTN_STYLE : SELL_BTN_STYLE))

  let mkSellBtn = @(isEnabled) (isEnabled ? Flat : Bordered)(loc("btn/massSellSoldiers"),
    sellSelected,
    { isEnabled }.__update(SELL_BTN_STYLE))

  let mkSoldiersBlock = @(withText = true) @() {
    size = [flex(), SIZE_TO_CONTENT]
    watch = unseenSoldierShopItems
    flow = FLOW_VERTICAL
    hplace = ALIGN_CENTER
    halign = ALIGN_CENTER
    gap = bigPadding
    children = [
      withText ? noteTextArea({
        text = loc("squad/getMoreSoldiers")
      }).__update(fontSub, {halign = ALIGN_CENTER}) : null
      Flat(loc("soldiers/purchaseSoldier"), @() isPurchaseWndOpend(true),
        {
          size = [flex(), SIZE_TO_CONTENT]
          margin = 0
          hotkeys = [["^J:Start"]]
        }.__update(unseenSoldierShopItems.value.len() > 0 ? {
          fgChild = smallUnseenNoBlink.__update({
            hplace = ALIGN_RIGHT
            vplace = ALIGN_TOP
          })
        } : {})
      )
    ]
  }
  local wasPurchOpened = false
  isPurchaseWndOpend.subscribe(function(v){
    if (!v && wasPurchOpened) {
      updateSoldiersListAndSort()
      wasPurchOpened = true
    }
    else
      wasPurchOpened = true
  })

  let availList = Computed(@() reserveSoldiers.value.slice(0, reserveAvailableSize.value))
  let blockedList = Computed(@() reserveSoldiers.value.slice(reserveAvailableSize.value))
  function reserveList() {
    if (reserveSoldiers.value.len() == 0)
      return bg.__merge({
        watch = reserveSoldiers
        size = [slotWithPadding[0] + 2 * bigPadding, flex()]
        valign = ALIGN_CENTER
        halign = ALIGN_CENTER
        behavior = Behaviors.Button // only to attract cursor on dirpad navigation
        children = mkSoldiersBlock()
      })

    let bigList = reserveSoldiers.value.len() >= SOLDIERS_ON_PAGE

    foreach (soldier in reserveSoldiers.value) {
      if (isMarkingForSale.value && soldier.guid not in soldierCheckedState)
        soldierCheckedState[soldier.guid] <- Watched(false)
    }

    return bg.__merge({
      watch = [ reserveSoldiers, curArmyReserveCapacity, isMarkingForSale ]
      size = [SIZE_TO_CONTENT, flex()]
      gap = bigPadding
      children = [
        reserveCountBlock
        makeVertScroll({
          xmbNode = XmbContainer({
            canFocus = false
            scrollSpeed = 5.0
          })
          flow = FLOW_VERTICAL
          children = [
            mkSoldiersList({
              soldiers = availList
              hasUnseen = true
              idxOffset = maxSoldiersInBattle
              isInReserve = true
              hasGroupSelection = true
            })
            labelUnableToAdd(blockedList)
            mkSoldiersList({
              soldiers = blockedList
              hasUnseen = false
              idxOffset = Computed(@() maxSoldiersInBattle.value + reserveAvailableSize.value)
              isInReserve = true
              hasGroupSelection = true
            })
          ]
        }, scrollbarParams)
        reserveSoldiers.value.len() >= curArmyReserveCapacity.value
        ? null : mkSoldiersBlock(!bigList)
        @() {
          watch = [isMarkingForSale, selectedSoldiersNum]
          flow = FLOW_HORIZONTAL
          gap = bigPadding
          size = [flex(), SIZE_TO_CONTENT]
          children = [
            mkMarkBtn(isMarkingForSale.value)
            mkSellBtn(isMarkingForSale.value && selectedSoldiersNum.value > 0)
          ]
        }
      ]
    })
  }


  let soldiersContent = {
    size = flex()
    flow = FLOW_HORIZONTAL
    gap = bigPadding
    children = [
      squadList
      {
        size = flex()
        flow = FLOW_HORIZONTAL
        gap = bigPadding
        behavior = Behaviors.DragAndDrop
        onDrop = @(data) soldierToReserveByIdx(data?.soldierIdx)
        canDrop = @(data) data?.soldierIdx != null && data.soldierIdx < maxSoldiersInBattle.value
        skipDirPadNav = true
        children = [
          reserveList
          mkSoldierInfo({
            soldierInfoWatch = selectedSoldier
            mkDismissBtn = bigDismissBtn
            onResearchClickCb = gotoResearchUpgradeMsgBox
            buttons = mkCustomButtons(selectedSoldier)
          })
          mkPresetEquipBlock()
        ]
      }
      buttonMassUnequip
    ]
  }


  return {
    size = [sw(100), sh(100)]
    behavior = Behaviors.MenuCameraControl
    children = [
      @() {
        watch = [curArmy, safeAreaBorders]
        size = flex()
        flow = FLOW_VERTICAL
        padding = safeAreaBorders.value
        children = [
          mkHeader({
            armyId = curArmy.value
            textLocId = "soldier/manageTitle"
            closeButton = closeBtnBase({
              onClick = @() applySoldierManage(closeChooseSoldiersWnd)
            })
          })
          {
            size = flex()
            flow = FLOW_VERTICAL
            children = soldiersContent
          }
        ]
      }
      @(){
        watch = isPurchaseWndOpend
        size = flex()
        children = isPurchaseWndOpend.value
          ? soldiersPurchaseWnd(@() isPurchaseWndOpend(false))
          : null
       }
    ]
  }
}

let isOpened = keepref(Computed(@() soldiersSquad.value != null))

let open = function() {
  curSquadSoldierIdx(curSoldierIdx.value)
  deselectSoldier()
  sceneWithCameraAdd(chooseSoldiersScene, "soldiers_quarters")
}

if (isOpened.value)
  open()

isOpened.subscribe(function(v) {
  if (v == true)
    open()
  else
    sceneWithCameraRemove(chooseSoldiersScene)
})
