from "%enlSqGlob/ui_library.nut" import *

let { fontSub, fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let textButton = require("%ui/components/textButton.nut")
let { soundActive } = textButton
let { blurBgColor, blurBgFillColor, selectedTxtColor,
    squadSlotHorSize, airSelectedBgColor, fadedTxtColor, opaqueBgColor,
  hoverBgColor, smallOffset, defBgColor
} = require("%enlSqGlob/ui/viewConst.nut")
let { bigPadding, smallPadding, defTxtColor, titleTxtColor, commonBtnHeight,
  attentionTxtColor, negativeTxtColor
} = require("%enlSqGlob/ui/designConst.nut")
let mkHeader = require("%enlist/components/mkHeader.nut")
let { showMsgbox, showMessageWithContent } = require("%enlist/components/msgbox.nut")
let { txt, noteTextArea } = require("%enlSqGlob/ui/defcomps.nut")
let { openUnlockSquadScene } = require("unlockSquadScene.nut")
let { safeAreaBorders } = require("%enlist/options/safeAreaState.nut")
let { sceneWithCameraAdd, sceneWithCameraRemove
} = require("%enlist/sceneWithCamera.nut")
let { isCurCampaignProgressUnlocked } = require("%enlist/meta/curCampaign.nut")
let { unlockCampaignPromo } = require("lockCampaignPkg.nut")
let { mkHorizontalSlot, mkEmptyHorizontalSlot, curDropData } = require("chooseSquadsSlots.nut")
let { isEventRoom } = require("%enlist/mpRoom/enlRoomState.nut")
let { isEventModesOpened } = require("%enlist/gameModes/eventModesState.nut")
let { unseenSquads, markSeenSquads } = require("model/unseenSquads.nut")
let { blinkUnseenIcon } = require("%ui/components/unseenSignal.nut")
let hoverHoldAction = require("%darg/helpers/hoverHoldAction.nut")
let buyShopItem = require("%enlist/shop/buyShopItem.nut")
let currenciesWidgetUi = require("%enlist/currency/currenciesWidgetUi.nut")
let { squadsArmy, selectedSquadId, chosenSquads, reserveSquads, displaySquads, slotsCount,
  applyAndClose, closeChooseSquadsWnd, changeSquadOrderByUnlockedIdx, unfocusSquad,
  squadsArmyLimits, moveIndex, changeList, curArmyLockedSquadsData, focusedSquads,
  sendSquadActionToBQ, maxSquadsInBattle, previewSquads, sellableSquads, sellSquad
} = require("%enlist/soldiers/model/chooseSquadsState.nut")
let { makeVertScroll, thinStyle } = require("%ui/components/scrollbar.nut")
let premium = require("%enlist/currency/premium.nut")
let { hasPremium } = premium
let premiumSquadsInBattle = premium.maxSquadsInBattle
let { armySlotDiscount, armySlotItem } = require("%enlist/shop/armySlotDiscount.nut")
let { premiumImage } = require("%enlist/currency/premiumComp.nut")
let { armySquadsById, armoryByArmy, soldiersBySquad } = require("model/state.nut")
let { squadsCfgById } = require("model/config/squadsConfig.nut")
let statsd = require("statsd")
let { isGamepad } = require("%ui/control/active_controls.nut")
let colorize = require("%ui/components/colorize.nut")
let { is_pc } = require("%dngscripts/platform.nut")
let premiumWnd = require("%enlist/currency/premiumWnd.nut")
let openSquadTextTutorial = require("%enlist/tutorial/squadTextTutorial.nut")
let { unseenSquadTutorials, markSeenSquadTutorial
} = require("%enlist/tutorial/unseenSquadTextTutorial.nut")
let { tutorials } = require("%enlist/tutorial/squadTextTutorialPresentation.nut")
let campaign = require("%enlist/campaigns/campaignConfig.nut")
let { needFreemiumStatus, disableBuySquadSlot } = campaign
let freemiumSquadsInBattle = campaign.maxSquadsInBattle
let { promoWidget } = require("%enlist/components/mkPromoWidget.nut")
let freemiumWnd = require("%enlist/currency/freemiumWnd.nut")
let { mkFreemiumXpImage } = require("%enlist/debriefing/components/mkXpImage.nut")
let { mkDiscountWidget, mkCurrencyImage } = require("%enlist/shop/currencyComp.nut")
let { isSquadRented, buyRentedSquad } = require("model/squadInfoState.nut")
let { sound_play } = require("%dngscripts/sound_system.nut")
let presetsBlock = require("%enlist/soldiers/squadPresetsBlock.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { squadsFilterUi, getFilterSquads,
  getCountSquadTypes, updateSquadTypes } = require("%enlist/soldiers/components/squadsFilter.nut")
let { jumpToArmyGrowth } = require("%enlist/mainMenu/sectionsState.nut")
let { isChangesBlocked, showBlockedChangesMessage } = require("%enlist/quickMatchQueue.nut")
let { getCurrencyPresentation } = require("%enlist/shop/currencyPresentation.nut")
let { massUnequipArmyReserve }= require("model/selectItemState.nut")
let { loadBRForAllSquads } = require("%enlist/soldiers/armySquadTier.nut")


let SILVER_ID = "enlisted_silver"

let filter = Watched({})
let commonBtnWidth = hdpx(250)

let playSoundItemPlace = @() sound_play("ui/inventory_item_place")
let unseenIcon = blinkUnseenIcon()

let priceIconSize = [hdpxi(30), hdpxi(30)]
let priceIconSilver = mkCurrencyImage(getCurrencyPresentation(SILVER_ID)?.icon, priceIconSize)


let sentStatsdData = persist("sentStatsdData", @() {})

let function sendData(key) {
  let keyToCheck = isGamepad.value
    ? $"squad_management_gamepad_{key}"
    : $"squad_management_{key}"

  if (keyToCheck in sentStatsdData)
    return

  sentStatsdData[keyToCheck] <- 1
  statsd.send_counter(keyToCheck, 1)
}

let curArmyUnseenSquads = Computed(@() unseenSquads.value?[squadsArmy.value])

let firstSlotToAnim = Watched(null)
let secondSlotToAnim = Watched(null)
let needMoveCursor = Watched(false)
let hoveredSquad = Watched(null)

let function moveSquad(direction) {
  let squadId = selectedSquadId.value
  if (squadId == null)
    return
  foreach (watch in [chosenSquads, reserveSquads]) {
    let list = watch.value
    let idx = list.findindex(@(s) s?.squadId == squadId)
    if (idx == null)
      continue
    let newIdx = idx + direction
    if (newIdx in list) {
      watch(moveIndex(list, idx, newIdx))
      markSeenSquads(squadsArmy.value, [squadId])
      needMoveCursor(hoveredSquad.value != null)
      firstSlotToAnim(watch == reserveSquads ? newIdx + chosenSquads.value.len() : newIdx)
      secondSlotToAnim(watch == reserveSquads ? idx + chosenSquads.value.len() : idx)
    }
    break
  }
}

let moveParams = Computed(function(prev) {
  local watch = null
  local idx = null
  let selId = isGamepad.value
    ? hoveredSquad.value ?? selectedSquadId.value
    : selectedSquadId.value
  if (selId != null)
    foreach (w in [chosenSquads, reserveSquads]) {
      idx = w.value.findindex(@(s) s?.squadId == selId)
      if (idx != null) {
        watch = w
        break
      }
    }

  let newValues = {
    canUp = watch != null && idx > 0
    canDown = watch != null && idx < watch.value.len() - 1
    canTake = watch == reserveSquads
    canRemove = watch == chosenSquads
  }

  if (prev == FRP_INITIAL)
    return newValues

  foreach (k, v in newValues)
    if (prev[k] != v)
      return newValues // was updated

  return prev // not updated, stop graph recalc
})

let buttonClose = textButton.Flat(loc("Close"), applyAndClose,
  { key = "closeSquadsManage" //used in tutorial
    margin = 0
    size = [commonBtnWidth, commonBtnHeight]
    hotkeys = [[$"^{JB.B} | Esc"]]
  })

let buttonMassUnequip = textButton.Flat(loc("removeAllEquipment/reserve"),
  @() showMsgbox({
    text = loc("removeAllEquipment/confirmSquads")
    buttons = [
      {
        text = loc("Ok")
        action = @() massUnequipArmyReserve(reserveSquads.value,
          soldiersBySquad.value, armoryByArmy.value,
          // recalculate BR for reserve squads when done
          @(_) loadBRForAllSquads(reserveSquads.value, true))
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
    margin = 0
    size = [commonBtnWidth, commonBtnHeight]
    hplace = ALIGN_RIGHT
  })

let emptySquadToBuy = @(children) {
  rendObj = ROBJ_BOX
  size = squadSlotHorSize
  fillColor = Color(0,0,0,0)
  borderColor = fadedTxtColor
  borderWidth = hdpx(1)
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = children
}

let buySquadBtn = @(sf) {
  size = [flex(), SIZE_TO_CONTENT]
  halign = ALIGN_RIGHT
  margin = [0, bigPadding]
  children = {
    color = sf & S_HOVER ? titleTxtColor : defTxtColor
    rendObj = ROBJ_IMAGE
    size = [hdpx(30), hdpx(30)]
    image = Picture("!ui/squads/plus.svg:{0}:{0}:K".subst(hdpxi(30)))
  }
}

let squadsCountHint = @() {
  watch = squadsArmyLimits
  size = [flex(1.5), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  children = [
    noteTextArea(loc("squads/maximumInBattleHint"))
      .__update({color = titleTxtColor, maxWidth = hdpx(440)}, fontSub)
    noteTextArea(loc("squads/maxSquadsToTakeHint",
      { maxSquads =  colorize(titleTxtColor, squadsArmyLimits.value.maxSquadsInBattle),
        infantry  =  colorize(titleTxtColor, squadsArmyLimits.value.maxInfantrySquads),
        bike      =  colorize(titleTxtColor, squadsArmyLimits.value.maxBikeSquads),
        vehicle   =  colorize(titleTxtColor, squadsArmyLimits.value.maxVehicleSquads),
        transport =  colorize(titleTxtColor, squadsArmyLimits.value.maxTransportSquads) }))
  ]
}

let mkText = @(text, override = {}) {
  rendObj = ROBJ_TEXT
  color = defTxtColor
  text
}.__update(fontSub, override)

let mkTextArea = @(text, override = {}) {
  size = [flex(), SIZE_TO_CONTENT]
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  color = titleTxtColor
  text
}.__update(fontSub, override)

let squadsManagementHint = mkTextArea(loc("squads/movingSquadsHint"), {
  margin = [hdpx(20), 0]
})

let faBtnParams = {
  borderWidth = 0
  borderRadius = 0
}

let function manageBlock() {
  let { canUp, canDown, canTake, canRemove } = moveParams.value
  return {
    watch = [moveParams, isChangesBlocked]
    size = [flex(), SIZE_TO_CONTENT]
    valign = ALIGN_CENTER
    flow = FLOW_HORIZONTAL
    gap = bigPadding
    children = [
      textButton.FAButton("arrow-up", function() {
          if (hoveredSquad.value != null)
            selectedSquadId(hoveredSquad.value)
          moveSquad(-1)
          sendData("arrow-up")
          sendData( "any_button")
        },
        faBtnParams.__merge({
          key = "manageSquadsBtnUp" //used in tutorial
          isEnabled = canUp && !isChangesBlocked.value
          hotkeys = [["^J:Y", {description = loc("Move Up")}]]
        })),
      textButton.FAButton("arrow-down", function() {
          if (hoveredSquad.value != null)
            selectedSquadId(hoveredSquad.value)
          moveSquad(1)
          sendData("arrow-down")
          sendData( "any_button")
        },
        faBtnParams.__merge({
          key = "manageSquadsBtnDown" //used in tutorial
          isEnabled = canDown && !isChangesBlocked.value
          hotkeys = [["^J:X", {description = loc("Move Down")}]]
        })),
      canTake ? textButton.FAButton("arrow-left", function() {
          if (hoveredSquad.value != null)
            selectedSquadId(hoveredSquad.value)
          changeList()
          sendData("arrow-left")
          sendData( "any_button")
        },
        faBtnParams.__merge({
          key = "manageSquadsBtnLeft" //used in tutorial
          isEnabled = canTake && !isChangesBlocked.value
          hotkeys = [["^J:LB", {description = loc("TakeToBattle")}]]
        }))
        : canRemove ? textButton.FAButton("arrow-right", function() {
            if (hoveredSquad.value != null)
              selectedSquadId(hoveredSquad.value)
            changeList()
            sendData("arrow-right")
            sendData( "any_button")
          },
          faBtnParams.__merge({
            key = "manageSquadsBtnRight" //used in tutorial
            isEnabled = canRemove && !isChangesBlocked.value
            hotkeys = [["^J:RB", {description = loc("MoveToReserve")}]]
          }))
        : null,
      { size = [flex(), 0] },
      textButton.Flat(loc("squads/presets"), presetsBlock.open,
        { key = "openPresetsBlock"
          margin = 0
          size = [commonBtnWidth, commonBtnHeight]
        })
    ]
  }
}

let squadUnseenMark = @(squadId) @() {
  watch = curArmyUnseenSquads
  hplace = ALIGN_RIGHT
  children = (curArmyUnseenSquads.value?[squadId] ?? false) ? unseenIcon : null
}

let mkSquadFocused = @(squadId) function() {
  let res = { watch = focusedSquads }
  if (squadId not in focusedSquads.value)
    return res

  return res.__update({
    size = flex()
    rendObj = ROBJ_FRAME
    borderWidth = hdpx(4)
    color = Color(240, 200, 100, 190)
    transform = {}
    animations = [
      { prop = AnimProp.opacity, from = 0, to = 0.5, easing = CosineFull,
        duration = 0.8, play = true, loop = true }
    ]
  })
}

let emptySlotNumberStyle = {
  fillColor = Color(0,0,0,0)
  borderColor = fadedTxtColor
  borderWidth = hdpx(1)
}

let squadNumber = @(idx, style = {}) {
  rendObj = ROBJ_BOX
  size = [hdpx(25), flex()]
  valign = ALIGN_CENTER
  halign = ALIGN_CENTER
  padding = [0, smallPadding]
  margin = [0, bigPadding,0,0]
  fillColor = defBgColor
  borderWidth = 0
  children = mkText(idx + 1)
}.__merge(style)

let premBlockBg = {
  rendObj = ROBJ_SOLID
  color = defBgColor
  padding = bigPadding
}

let mkBuySquadSlot = @(num) function() {
  let res = { watch = [armySlotItem, hasPremium, armySlotDiscount] }
  let shopItem = armySlotItem.value
  if (!shopItem || !hasPremium.value)
    return res

  return res.__update({
    children = watchElemState(@(sf) {
      flow = FLOW_HORIZONTAL
      gap = smallPadding
      behavior = Behaviors.Button
      onClick = @() buyShopItem({ shopItem })
      children = [
        squadNumber(num, emptySlotNumberStyle)
        emptySquadToBuy([
          {
            size = flex()
            valign = ALIGN_CENTER
            flow = FLOW_HORIZONTAL
            margin = [0, hdpx(20)]
            gap = hdpx(20)
            children = [
              mkText(loc("squad/openNewSlot"), {
                color = sf & S_HOVER ? titleTxtColor : fadedTxtColor
              })
              mkDiscountWidget(armySlotDiscount.value,
                { hplace = ALIGN_LEFT, vplace = ALIGN_CENTER, pos = null })
            ]
          }
          buySquadBtn(sf)
        ])
      ]
    })
  })
}

let function onDropCbForHorSlot(idxFrom, idxTo) {
  if (isChangesBlocked.value) {
    showBlockedChangesMessage()
    return
  }
  changeSquadOrderByUnlockedIdx(idxFrom, idxTo)
  sendData("drag_and_drop")
  foreach (cSquad in chosenSquads.value) {
    let { squadType = null } = cSquad
    if (squadType in unseenSquadTutorials.value) {
      openSquadTextTutorial(squadType)
      markSeenSquadTutorial(squadType)
      break
    }
  }
  playSoundItemPlace()
}

let function squadHorSlot(squad, idx, fixedSlotsCount, maxSquadsLen = 0) {
  let group = ElemGroup()
  let stateFlags = Watched(0)
  let sellCost = Computed(@() sellableSquads.value?[squad?.squadId] ?? 0)

  let function onInfoCb(squadId) {
    let armyId = squadsArmy.value
    if (isSquadRented(squad))
      buyRentedSquad({ armyId, squadId })
    else
      openUnlockSquadScene({
        armyId
        squad
        squadCfg = squadsCfgById.value?[armyId][squadId]
        unlockInfo = null
      })
    selectedSquadId(null)
  }

  let onClick = @() selectedSquadId(squad.squadId)
  let isSelected = Computed(@() selectedSquadId.value == squad.squadId)

  let function onHover(on, squadId) {
    hoveredSquad(on ? squad.squadId : null)

    hoverHoldAction("unseenSquad", squad.squadId,
      function() {
        unfocusSquad(squadId)
        markSeenSquads(squadsArmy.value, [squadId])
      }
    )
  }

  let thisSlotNeedMoveCursor = Computed(@()
    hoveredSquad.value == squad.squadId ? needMoveCursor.value : false)

  return function() {
    let sellCostVal = sellCost.value
    let onSellCb = isSquadRented(squad) || sellCostVal <= 0 ? null
      : function() {
          let sellHeader = loc("squad/sellHeader", {
            squadName = colorize(attentionTxtColor, loc(squad.titleLocId))
          })

          showMessageWithContent({
            content = {
              size = [sw(60), SIZE_TO_CONTENT]
              flow = FLOW_VERTICAL
              gap = bigPadding
              margin = [hdpxi(50),0,0,0]
              hplace = ALIGN_CENTER
              halign = ALIGN_CENTER
              children = [
                mkTextArea(sellHeader, { halign = ALIGN_CENTER }.__update(fontBody))
                mkText(loc("squad/sellAttention"), {
                  color = negativeTxtColor
                }.__update(fontBody))
                {
                  size = [flex(), SIZE_TO_CONTENT]
                  flow = FLOW_HORIZONTAL
                  gap = bigPadding
                  margin = hdpxi(50)
                  halign = ALIGN_CENTER
                  valign = ALIGN_CENTER
                  children = [
                    mkText(loc("squad/sellSilverInfo"), fontBody)
                    {
                      flow = FLOW_HORIZONTAL
                      valign = ALIGN_CENTER
                      gap = smallPadding
                      children = [
                        priceIconSilver
                        mkText(sellCostVal, fontBody)
                      ]
                    }
                  ]
                }
                mkTextArea(loc("squad/sellInfo"), {
                  size = [hdpxi(640), SIZE_TO_CONTENT]
                  color = defTxtColor
                })
              ]
            }
            buttons = [
              { text = loc("Cancel"), isCancel = true }
              {
                text = loc("squad/sellBtn")
                action = @() sellSquad(squadsArmy.value, squad.guid, sellCostVal)
                isCurrent = true
              }
            ]
          })
        }

    return {
      watch = [
        thisSlotNeedMoveCursor, firstSlotToAnim, secondSlotToAnim, chosenSquads,
        unseenSquadTutorials, sellCost
      ]
      children = mkHorizontalSlot(
        squad.__merge({
          idx
          onDropCb = onDropCbForHorSlot
          onInfoCb
          onSellCb
          onClick
          isSelected
          isLocked = maxSquadsLen > 0 && idx >= maxSquadsLen
          override = { onHover }
          group
          stateFlags
          fixedSlots = fixedSlotsCount
          needMoveCursor = thisSlotNeedMoveCursor.value
          firstSlotToAnim = firstSlotToAnim.value
          secondSlotToAnim = secondSlotToAnim.value
          addChildren = [
            mkSquadFocused(squad.squadId)
            squadUnseenMark(squad.squadId)
          ]
          needSquadTutorial = squad.squadType in tutorials
        }),
        KWARG_NON_STRICT)
    }
  }
}

let function onDropCbForEmptySlot(idxFrom, idxTo) {
  if (isChangesBlocked.value) {
    showBlockedChangesMessage()
    return
  }
  changeSquadOrderByUnlockedIdx(idxFrom, idxTo)
  sendData("drag_and_drop")
  playSoundItemPlace()
}

let emptyHorSquadSlot = @(idx, fixedSlotsCount, isReserveEmpty) mkEmptyHorizontalSlot({
  idx
  onDropCb = onDropCbForEmptySlot
  fixedSlots = fixedSlotsCount
  hasBlink = !isReserveEmpty
})

let mkSquadSlot = @(
  squad, idx, fixedSlotsCount, isReserve, isReserveEmpty = true, maxSquadsLen = 0
) {
  flow = FLOW_HORIZONTAL
  gap = smallPadding
  children = [
    !isReserve ? squadNumber(idx) : null
    squad != null
      ? squadHorSlot(squad, idx, fixedSlotsCount, maxSquadsLen)
      : emptyHorSquadSlot(idx, fixedSlotsCount, isReserveEmpty)
    ]
}

let iconSize = hdpxi(30)
let premiumIcon = premiumImage(iconSize)
let freemiumIcon = mkFreemiumXpImage(iconSize)

let mkPrimeSlotTxt = @(icon, locId) {
  flow = FLOW_HORIZONTAL
  size = [flex(), SIZE_TO_CONTENT]
  gap = bigPadding
  valign = ALIGN_CENTER
  margin = [0, hdpx(20)]
  children = [
    icon
    mkText(loc(locId), { color = fadedTxtColor })
  ]
}

let slotToBuy = @(num, icon, locId) {
  flow = FLOW_HORIZONTAL
  gap = smallPadding
  children = [
    squadNumber(num, emptySlotNumberStyle)
    emptySquadToBuy(mkPrimeSlotTxt(icon, locId))
  ]
}

let mkPrimeSlots = @(num, count, icon, locId) {
  flow = FLOW_VERTICAL
  gap = bigPadding
  children = array(count).map(@(_, idx) slotToBuy(num + idx, icon, locId))
}

let mkBuyPremBtn = @(onClick)
  watchElemState(@(sf) {
    rendObj = ROBJ_BOX
    behavior = Behaviors.Button
    onClick
    size = [hdpx(40), hdpx(40)]
    fillColor = sf & S_HOVER ? hoverBgColor : opaqueBgColor
    borderWidth = hdpx(1)
    borderRadius = hdpx(40)
    borderColor = sf & S_HOVER ? selectedTxtColor : fadedTxtColor
    pos = [squadSlotHorSize[0] - bigPadding * 2, 0]
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    sound = soundActive
    children = {
      keepAspect = KEEP_ASPECT_FIT
      rendObj = ROBJ_IMAGE
      size = [hdpx(30), hdpx(30)]
      image = Picture("!ui/squads/plus.svg:{0}:{0}:K".subst(hdpxi(30)))
      color = sf & S_HOVER ? selectedTxtColor : titleTxtColor
    }
  })

let extendSlots = function() {
  let squadNum = chosenSquads.value.len()
  let children = []
  if (previewSquads.value == null) {
    if (!isCurCampaignProgressUnlocked.value)
      children.append(unlockCampaignPromo(premBlockBg))
    else if (needFreemiumStatus.value && freemiumSquadsInBattle.value > 0)
      children.append(
        mkPrimeSlots(squadNum, freemiumSquadsInBattle.value, freemiumIcon, "squad/plusFreemiumSquadSlot"),
        mkBuyPremBtn(@(_) freemiumWnd())
      )
    else if (!hasPremium.value && premiumSquadsInBattle.value > 0)
      children.append(
        mkPrimeSlots(squadNum, premiumSquadsInBattle.value, premiumIcon, "squad/plusPremiunSquadSlot"),
        mkBuyPremBtn(premiumWnd)
      )
    else if (!disableBuySquadSlot.value)
      children.append(mkBuySquadSlot(squadNum))
  }

  return {
    watch = [isCurCampaignProgressUnlocked, hasPremium, premiumSquadsInBattle, needFreemiumStatus,
      freemiumSquadsInBattle, chosenSquads, disableBuySquadSlot, previewSquads]
    valign = ALIGN_CENTER
    children
  }
}

let scrollHandlerLeftPanel = ScrollHandler()

let mkChosenSquads = @(chosen, ctor, bottomPrime) {
  size = [SIZE_TO_CONTENT, flex()]
  flow = FLOW_VERTICAL
  clipChildren = true
  gap = bigPadding
  children = makeVertScroll({
    flow = FLOW_VERTICAL
    gap = bigPadding
    children = chosen.map(ctor)
      .append(bottomPrime)
  },
  {
    size = [SIZE_TO_CONTENT, flex()]
    styling = thinStyle
    scrollHandler = scrollHandlerLeftPanel
  })
}

let panelBg = {
  size = [SIZE_TO_CONTENT, flex()]
  padding = bigPadding
  rendObj = ROBJ_WORLD_BLUR_PANEL
  color = blurBgColor
  fillColor = blurBgFillColor
}

let function leftHeader() {
  local infantryCur = 0
  local bikeCur = 0
  local vehicleCur = 0
  local transportCur = 0
  displaySquads.value.each(function(squad) {
    if (squad == null)
      return

    let { vehicleType = "" } = squad
    if (vehicleType == "bike")
      ++bikeCur
    else if (vehicleType == "truck")
      ++transportCur
    else if (vehicleType != "")
      ++vehicleCur
    else
      ++infantryCur
  })
  let curSquads = infantryCur + bikeCur + vehicleCur
  let infantryStr = loc("squads/maxInfantry",
    { infantryCur, infantryMax =  squadsArmyLimits.value.maxInfantrySquads })
  let bikeStr = loc("squads/maxBike",
    { bikeCur, bikeMax =  squadsArmyLimits.value.maxBikeSquads })
  let transportStr = loc("squads/maxTransport",
    { transportCur, transportMax = squadsArmyLimits.value.maxTransportSquads })
  let vehicleStr = loc("squads/maxVehicle",
    { vehicleCur, vehicleMax = squadsArmyLimits.value.maxVehicleSquads })
  return {
    watch = [squadsArmyLimits, displaySquads]
    size = [flex(), SIZE_TO_CONTENT]
    children = [
    txt(loc("squads/maxSquads", { curSquads, maxSquads = maxSquadsInBattle.value }))
    {
      rendObj = ROBJ_TEXT
      color = defTxtColor
      hplace = ALIGN_RIGHT
      text = " | ".join([infantryStr, bikeStr, transportStr, vehicleStr])
    }
  ]
}}

let function leftPanel() {
  let noReserve = reserveSquads.value.len() == 0
  return panelBg.__merge({
    watch = [displaySquads, reserveSquads, maxSquadsInBattle]
    children = {
      size = [SIZE_TO_CONTENT, flex()]
      flow = FLOW_VERTICAL
      gap = bigPadding
      children = [
        leftHeader
        mkChosenSquads(displaySquads.value,
          @(squad, idx) mkSquadSlot(
            squad, idx, displaySquads.value.len(), false, noReserve, maxSquadsInBattle.value
          ), extendSlots)
        is_pc ? squadsManagementHint : null
        manageBlock
        {
          flow = FLOW_HORIZONTAL
          gap = bigPadding
          size = [flex(), SIZE_TO_CONTENT]
          padding = [hdpx(10), 0]
          children = [
            squadsCountHint
            buttonClose
          ]
        }
      ]
    }
  })
}


let labelText = @(sf, needHighlight) mkText(loc("squad/dropToReserve"), {
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  color = (sf & S_ACTIVE) && needHighlight ? selectedTxtColor : defTxtColor
})


let onDropCbForReserveContainer = function(data) {
  if (isChangesBlocked.value) {
    showBlockedChangesMessage()
    return
  }
  if (data.squadIdx > chosenSquads.value.len() - 1)
    return

  let { guid, squadId } = chosenSquads.value[data.squadIdx]
  sendSquadActionToBQ("move_to_reserve", guid, squadId)
  sendData("drag_and_drop")
  reserveSquads.mutate(@(v) v.insert(0, chosenSquads.value[data.squadIdx]))
  chosenSquads.mutate(@(v) v[data.squadIdx] = null)
  playSoundItemPlace()
}

let function dropToReserveContainer() {
  let function dropContainer(sf) {
    let highligtToDrop = curDropData.value?.squadIdx != null
      && curDropData.value.squadIdx <= chosenSquads.value.len() - 1
    return {
      watch = [curDropData, chosenSquads]
      key = "dropToReserveSquad" //used in tutorial
      rendObj = ROBJ_BOX
      fillColor = (sf & S_ACTIVE) && highligtToDrop ? airSelectedBgColor : defBgColor
      size = squadSlotHorSize
      borderWidth = highligtToDrop ? hdpx(1) : 0
      transform = {}
      behavior = Behaviors.DragAndDrop
      onDrop = onDropCbForReserveContainer
      children = labelText(sf, highligtToDrop)
    }
  }
  return watchElemState(dropContainer)
}


let scrollHandlerRightPanel = ScrollHandler()


let growthSquadMsgbox = function(growthData) {
  let okBtn = { text = loc("Ok"), isCancel = true }
  showMsgbox({
    text = "\n\n".join([loc("growth/requiredHeader"), growthData?.lockFull ?? ""])
    buttons = Computed(@() isEventRoom.value || isEventModesOpened.value
      ? [okBtn]
      : [okBtn, {
          text = loc("GoToGrowth")
          action = function() {
            jumpToArmyGrowth(growthData.growthId)
            closeChooseSquadsWnd()
          }
          isCurrent = true
        }])
  })
}

let getIdxSlot = @(guid) reserveSquads.value.findindex(@(v) v.guid == guid) ?? 0

let function mkHeadRightPanel() {
  let squadTypesCount = Computed(@()
    updateSquadTypes(getCountSquadTypes(reserveSquads.value), curArmyLockedSquadsData.value, 0))
  return {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    children = [
      txt(loc("squads/reserveSquads", "Reserve squads"))
      {
        size = [flex(), SIZE_TO_CONTENT]
        halign = ALIGN_RIGHT
        children = squadsFilterUi({
          watchFilter = filter,
          squadTypesCount,
          offset = [-hdpxi(8), hdpxi(20)]
        })
      }
    ]
  }
}

let function rightPanel() {
  let sCount = slotsCount.value
  let children = []
  let reserveChildren = getFilterSquads(reserveSquads.value, filter.value)
    .map(@(squad) mkSquadSlot(squad, getIdxSlot(squad.guid) + sCount, sCount, true))
  loadBRForAllSquads(reserveSquads.value)

  if (reserveSquads.value.len() >= 0)
    children
      .append(chosenSquads.value.findvalue(@(squad) squad != null)
        ? dropToReserveContainer()
        : null)
      .extend(reserveChildren)
  let lockedChildren = getFilterSquads(curArmyLockedSquadsData.value, filter.value)
    .map(function(val) {
      let { growthData } = val
      let { lockTxt = "" } = growthData
      let unlockObj = lockTxt != "" ? txt({ text = lockTxt, margin = bigPadding }) : null

      return mkHorizontalSlot(val.__merge({
        guid = ""
        isLocked = true
        idx = -1
        onClick = @() growthSquadMsgbox(growthData)
        unlockObj
      }), KWARG_NON_STRICT)
    })

  if (lockedChildren.len() > 0) {
    children
      .append(txt(loc("squads/lockedSquads", "Locked squads")))
      .extend(lockedChildren)
  }

  return panelBg.__merge({
    watch = [slotsCount, reserveSquads, filter, curArmyLockedSquadsData, chosenSquads]
    size = [SIZE_TO_CONTENT, flex()]
    flow = FLOW_VERTICAL
    halign = ALIGN_CENTER
    children = [
      mkHeadRightPanel()
      {
        size = [SIZE_TO_CONTENT, flex()]
        margin = [bigPadding, 0, smallOffset, 0]
        xmbNode = XmbContainer({
          canFocus = false
          scrollSpeed = 5.0
          isViewport = true
        })
        children = makeVertScroll({
          flow = FLOW_VERTICAL
          gap = bigPadding
          children = children
        },
        {
          size = [SIZE_TO_CONTENT, flex()]
          styling = thinStyle
          scrollHandler = scrollHandlerRightPanel
        })
      }
      {
        size = [flex(), SIZE_TO_CONTENT]
        children = [
          promoWidget("squads_manage")
          buttonMassUnequip
        ]
      }
    ]
  })
}

let allSquadsList = {
  size = flex()
  flow = FLOW_HORIZONTAL
  gap = bigPadding
  children = [
    leftPanel
    rightPanel
  ]
}

let neededSquad = Computed(@() hoveredSquad.value ?? selectedSquadId.value)

let needSquadInfoHotkeys = Computed(@() neededSquad.value != null)

let function squadInfoHotkeyHelper() {
  return {
    watch = needSquadInfoHotkeys
    hotkeys = needSquadInfoHotkeys.value
    ? [["^J:Start", {description = loc("squads/squadInfo"),
        action = function() {
          let armyId = squadsArmy.value
          openUnlockSquadScene({
            armyId
            squad = armySquadsById.value?[armyId][neededSquad.value]
            squadCfg = squadsCfgById.value?[armyId][neededSquad.value]
            unlockInfo = null
          })
      }}]]
    : null
  }
}

let function chooseSquadsScene() {
  return  {
    watch = [squadsArmy, safeAreaBorders]
    size = [sw(100), sh(100)]
    flow = FLOW_VERTICAL
    padding = safeAreaBorders.value
    onDetach = @() markSeenSquads(squadsArmy.value, (curArmyUnseenSquads.value ?? {}).keys())

    children = [
      squadInfoHotkeyHelper
      mkHeader({
        armyId = squadsArmy.value
        textLocId = "squads/manageTitle"
        addToRight = currenciesWidgetUi
      })
      {
        size = flex()
        children = allSquadsList
      }
    ]}
}

let isOpened = keepref(Computed(@() squadsArmy.value != null))
let open = @() sceneWithCameraAdd(chooseSquadsScene, "soldiers")
if (isOpened.value)
  open()

isOpened.subscribe(function(v) {
  if (v == true)
    open()
  else
    sceneWithCameraRemove(chooseSquadsScene)
})

console_register_command(function() {
  massUnequipArmyReserve(reserveSquads.value, soldiersBySquad.value, armoryByArmy.value)
}, "test.undressSquads")
