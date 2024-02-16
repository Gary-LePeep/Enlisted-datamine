from "%enlSqGlob/ui_library.nut" import *

let { fontHeading2, fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let { blurBgFillColor, disabledTxtColor, lockedSquadBgColor, accentTitleTxtColor
} = require("%enlSqGlob/ui/viewConst.nut")
let { brightAccentColor, bigPadding, titleTxtColor, maxContentWidth, defTxtColor, commonBtnHeight,
  navHeight, startBtnWidth, midPadding
} = require("%enlSqGlob/ui/designConst.nut")
let hoverHoldAction = require("%darg/helpers/hoverHoldAction.nut")
let { blinkUnseenIcon } = require("%ui/components/unseenSignal.nut")
let { utf8ToUpper } = require("%sqstd/string.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { sceneWithCameraAdd, sceneWithCameraRemove } = require("%enlist/sceneWithCamera.nut")
let { BtnActionBgDisabled }  = require("%ui/style/colors.nut")
let {
  eventGameModes, isEventModesOpened, isCustomRoomsMode, hasCustomRooms, selEvent, selectEvent,
  selLbMode, eventCustomSquads, eventsSquadList, eventsArmiesList, eventCurArmyIdx, allEventsToShow,
  inactiveEventsToShow, customRoomsModeSaved, eventCustomProfile, curTab,
  eventStartTime
} = require("eventModesState.nut")
let serverTime = require("%enlSqGlob/userstats/serverTime.nut")
let { secondsToHoursLoc } = require("%ui/helpers/time.nut")
let mkActiveBoostersMark = require("%enlist/mainMenu/mkActiveBoostersMark.nut")
let { unseenEvents, markSeenEvent, markAllSeenEvents } = require("unseenEvents.nut")
let textButton = require("%ui/components/textButton.nut")
let { soundDefault } = textButton
let { Bordered } = require("%ui/components/txtButton.nut")
let { mkMenuScene, menuContentAnimation } = require("%enlist/mainMenu/mkMenuScene.nut")
let { leaveQueue, isInQueue } = require("%enlist/quickMatchQueue.nut")
let {
  joinQueue, randTeamAvailable, randTeamCheckbox, alwaysRandTeamSign
} = require("%enlist/quickMatch.nut")
let { showCurNotReadySquadsMsg } = require("%enlist/soldiers/model/notReadySquadsState.nut")
let { isInSquad, isSquadLeader, myExtSquadData, unsuitableCrossplayConditionMembers,
  getUnsuitableVersionConditionMembers
} = require("%enlist/squad/squadManager.nut")
let { showSquadMembersCrossPlayRestrictionMsgBox, showSquadVersionRestrictionMsgBox,
  showNegativeBalanceRestrictionMsgBox } = require("%enlist/restrictionWarnings.nut")
let { hasValidBalance } = require("%enlist/currency/currencies.nut")
let { mkSquadsList } = require("%enlist/soldiers/squads_list.ui.nut")
let { selectedGameMode } = require("%enlist/mainScene/changeGameModeButton.nut")
let { curArmyData } = require("%enlist/soldiers/model/state.nut")
let { gameProfile } = require("%enlist/soldiers/model/config/gameProfile.nut")
let shortLbUi = require("%enlist/leaderboard/shortLb.ui.nut")
let {
  lbCurrentTable, openLbWnd, curLbIdx, lbPlayersCount, curLbSelfRow
} = require("%enlist/leaderboard/lbState.nut")
let {
  verticalGap, localPadding, localGap, armieChooseBlockWidth, eventBlockWidth
} = require("eventModeStyle.nut")
let eventModeDescription = require("eventModeDescription.nut")
let { room, roomIsLobby, lobbyStatus, LobbyStatus } = require("%enlist/state/roomState.nut")
let lobbyWnd = require("%enlist/mpRoom/eventLobbyWnd.nut")
let progressText = require("%enlist/components/progressText.nut")
let { showMsgbox } = require("%enlist/components/msgbox.nut")
let { eventRoomsList, modsRoomsList} = require("eventRoomsList.nut")
let { curEventRoomInfo } = require("eventRoomInfo.nut")
let { joinSelEventRoom } = require("joinEventRoom.nut")
let { selRoom } = require("eventRoomsListState.nut")
let { isEditEventRoomOpened } = require("createEventRoomState.nut")
let mkWindowTab = require("%enlist/components/mkWindowTab.nut")
let { toggleEventFiltersPopup, isRoomFilterOpened } = require("eventRoomsListFiltersPopup.nut")
let { footer, mkPanel } = require("eventModesPkg.nut")
let profileInfoBlock = require("%enlist/mainMenu/profileInfoBlock.nut")
let { isGamepad } = require("%ui/control/active_controls.nut")
let { mkHotkey } = require("%ui/components/uiHotkeysHint.nut")
let colorize = require("%ui/components/colorize.nut")
let { ceil } = require("%sqstd/math.nut")
let customMissionOfferBlock = require("sandbox/customMissionOfferBlock.nut")
let { FEATURED_MODS_TAB_ID, featuredModsRoomsList, isFeaturedAvailable
} = require("sandbox/customMissionOfferState.nut")
let { serverClusterBtnAbbrev } = require("%enlist/gameModes/gameModesWnd/serverClusterUi.nut")
let { mkArmyBtn, armySelectText } = require("%enlist/soldiers/army_select.ui.nut")

const CONTAINERS_ANIM_DURATION = 0.3
const EVENTS_TAB_ID = "events"
const CUSTOM_MATCHES_TAB_ID = "custom_matches"


let tabHoverAnim    = [{ prop = AnimProp.translate, duration = 0.2}]
let tabStateCommon = { translate = [hdpx(380), 0] }
let tabStateHovered = { translate = [0, 0] }
let buttonTabBgNormal = 0xfa015ea2
let buttonTabBgActive = 0xfa0182b5
let activeBoostersMarkPosition = { hplace = ALIGN_RIGHT, pos = [hdpx(20), bigPadding] }
let unseenIcon = blinkUnseenIcon().__update({pos = [-hdpx(26), 0]})

let isCustomRoomsUi = Computed(@() isCustomRoomsMode.value || curTab.value == FEATURED_MODS_TAB_ID )
let windowTabs = Computed(function() {
  let tabs = []
  if (eventGameModes.value.len() > 0)
    tabs.append(EVENTS_TAB_ID)
  if (hasCustomRooms.value)
    tabs.append(CUSTOM_MATCHES_TAB_ID)
  if ((hasCustomRooms.value && featuredModsRoomsList.value.len() > 0)
    || curTab.value == FEATURED_MODS_TAB_ID
  )
    tabs.append(FEATURED_MODS_TAB_ID)
  return tabs
})


windowTabs.subscribe(function(v) {
  if (v.len() > 0 && v.findvalue(@(t) t == curTab.value) == null)
    curTab(v[0])
})


curTab.subscribe(@(v) customRoomsModeSaved(v == CUSTOM_MATCHES_TAB_ID))


let function txtColor(sf, isInactive = false) {
  return sf & S_ACTIVE ? titleTxtColor
    : sf & S_HOVER ? titleTxtColor
    : isInactive ? disabledTxtColor : defTxtColor
}

let filterBtnCommonStyle = freeze({
  margin = 0
  hotkeys = [["^J:LT"]]
})

let filterBtnOpenedStyle = freeze(filterBtnCommonStyle.__merge({
  BgNormal = 0xFF40404040
}))

let defQuickMatchBtnParams = {
  size = [pw(100), hdpx(80)]
  halign = ALIGN_CENTER
  margin = 0
  borderWidth = hdpx(0)
  textParams = { rendObj=ROBJ_TEXT }.__update(fontHeading2)
}

let function changeWindowTab(delta) {
  let wndTabs = windowTabs.value
  let curTabIdx = wndTabs?.indexof(curTab.value) ?? 0
  if ((curTabIdx + delta) < wndTabs.len() && (curTabIdx + delta) >= 0)
    curTab(wndTabs[curTabIdx + delta])
}


let function wndTabsBlock() {
  let children = windowTabs.value.map(@(val)
    mkWindowTab(loc(val), @() curTab(val), curTab.value == val))

  if (isGamepad.value && windowTabs.value.len() > 1)
    children
      .insert(0, mkHotkey("^J:LB", @() changeWindowTab(-1)))
      .append(mkHotkey("^J:RB", @() changeWindowTab(1)))

  return {
    watch = [isGamepad, curTab, windowTabs]
    flow = FLOW_HORIZONTAL
    size = [flex(), commonBtnHeight]
    gap = localPadding
    valign = ALIGN_CENTER
    children
  }
}

let function mkEventBtn(eventGm) {
  let isSelected = Computed(@() selEvent.value == eventGm)
  let isUnseen = Computed(@() unseenEvents.value.contains(eventGm.id))
  let isInactive = !eventGm.isEnabled && eventGm.showWhenInactive
  let isEnded = Computed(@() isInactive && (eventGm?.leaderboardTableIdx ?? 0) < curLbIdx.value)

  return watchElemState(@(sf) {
    size = [flex(), SIZE_TO_CONTENT]
    watch = [isSelected, isUnseen, gameProfile, isEnded, eventCustomProfile]
    behavior = Behaviors.Button
    onAttach = @() isSelected.value ? markSeenEvent(eventGm.id) : null
    onClick = @() selectEvent(eventGm.id)
    onHover = hoverHoldAction("unseenEvent", eventGm.id, @(c) markSeenEvent(c))
    sound = soundDefault
    children = [
      isSelected.value || (sf & S_HOVER)
        ? {
            rendObj = ROBJ_SOLID
            size = isSelected.value ? [hdpx(6), flex()] : [hdpx(6), ph(50)]
            color = txtColor(sf)
            pos = [-hdpx(16), 0]
          }
        : isUnseen.value ? unseenIcon : null
        {
          rendObj = ROBJ_TEXTAREA
          size = [flex(), SIZE_TO_CONTENT]
          behavior = Behaviors.TextArea
          text = eventGm.title == "" ? eventGm.locId : eventGm.title
          color = txtColor(sf, isInactive)
        }.__update(fontBody)
    ]
  })
}

let function eventsList() {
  return {
    watch = allEventsToShow
    size = [eventBlockWidth, SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = localPadding
    children = allEventsToShow.value.map(mkEventBtn)
  }
}

let backBtn = Bordered(loc("BACK"), @() isEventModesOpened(false), {
  hotkeys = [[$"^{JB.B} | Esc"]]
  size = [flex(), SIZE_TO_CONTENT]
})

let events = @() {
  watch = selEvent
  onDetach = @() markAllSeenEvents()
  size = flex()
  flow = FLOW_HORIZONTAL
  gap = bigPadding
  children = [
    eventsList
    selEvent.value != null ? eventModeDescription : {
      rendObj = ROBJ_TEXT
      size = [flex(), SIZE_TO_CONTENT]
      halign = ALIGN_CENTER
      color = brightAccentColor
      text = loc("events/noEvents")
    }.__update(fontBody)
  ]
}

let mkRandTeamBlock = @(ctor) {
  halign = ALIGN_RIGHT
  size = [flex(), hdpx(26)]
  children = ctor
}

let mkRightBlockHeader = @(sf, label) {
  size = [flex(), commonBtnHeight]
  clipChildren = true
  valign = ALIGN_CENTER
  children = [
    {
      size = flex()
      children = [
        {
          rendObj = ROBJ_WORLD_BLUR_PANEL
          size = flex()
          fillColor = blurBgFillColor
        }
        {
          rendObj = ROBJ_SOLID
          size = [startBtnWidth, commonBtnHeight]
          color = sf & S_ACTIVE ? buttonTabBgActive : buttonTabBgNormal
          transitions = tabHoverAnim
          transform = sf != 0 ? tabStateHovered : tabStateCommon
        }
      ]
    }
    {
      rendObj = ROBJ_TEXT
      padding = [0, bigPadding]
      color = txtColor(sf)
      text = label
    }.__update(fontHeading2)
  ]
}

let function curLbPlacementBlock() {
  let res = { watch = [lbPlayersCount, curLbSelfRow] }
  let { idx = -1 } = curLbSelfRow.value
  if (idx < 0)
    return res

  local text = ""
  if (lbPlayersCount.value > 0) {
    let topPercentPlacement = ceil(100.0 * (idx + 1) / lbPlayersCount.value)
    if (topPercentPlacement <= 99)
      text = loc("lbPercentPlacemet", {
        percentPlacement = colorize(accentTitleTxtColor, $"{topPercentPlacement}%") })
  }
  return res.__update({
    rendObj = ROBJ_TEXTAREA
    size = [flex(), SIZE_TO_CONTENT]
    behavior = Behaviors.TextArea
    text
  }.__update(fontBody))
}


let leaderboard = watchElemState(@(sf) {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  gap = localGap
  behavior = Behaviors.Button
  sound = soundDefault
  onClick = openLbWnd
  children = [
    mkRightBlockHeader(sf, loc("Leaderboard"))
    mkPanel({
      size = [flex(), SIZE_TO_CONTENT]
      children = shortLbUi
    })
    curLbPlacementBlock
  ]
})

let upcomingEventMsgbox = function() {
  let seconds = max(0, (eventStartTime.value?[selEvent.value?.queueId] ?? 0) - serverTime.value)
  showMsgbox({
    text = loc("events/comingInLong", { time = secondsToHoursLoc(seconds) })
  })
}

let endedEventMsgbox = @() showMsgbox({
  text = loc("events/endedEvent")
})

let leaveQueueButton = textButton(loc("Leave queue"), @() leaveQueue(),
  defQuickMatchBtnParams
    .__merge({ hotkeys = [[$"^{JB.B} | Esc", { description = { skip = true }}]]}))

let mkBattleButton = @(text, onClick) textButton(text, onClick,
  defQuickMatchBtnParams
    .__merge({
      style = { BgNormal = brightAccentColor }
      hotkeys = [["^J:Y", { description = { skip = true }}]]
    }))

let mkDisabledBattleButton = @(text, onClick) textButton(text, onClick,
  defQuickMatchBtnParams.__merge({
    fillColor = lockedSquadBgColor
    textParams = { color = titleTxtColor }
  }))


let upcomingEventBtn = mkDisabledBattleButton(loc("inactiveEvent"), upcomingEventMsgbox)
let endedEventBtn = mkDisabledBattleButton(loc("endedEvent"), endedEventMsgbox)

let function joinEventQueue() {
  if (isSquadLeader.value && unsuitableCrossplayConditionMembers.value.len() > 0) {
    showSquadMembersCrossPlayRestrictionMsgBox(unsuitableCrossplayConditionMembers.value)
    return
  }

  let unsuitableByVersion = getUnsuitableVersionConditionMembers(selectedGameMode.value)
  if (unsuitableByVersion.len() > 0) {
    showSquadVersionRestrictionMsgBox(unsuitableByVersion.values())
    return
  }

  if (!hasValidBalance.value) {
    showNegativeBalanceRestrictionMsgBox()
    return
  }

  if (eventsArmiesList.value.len() > 0 && isEventModesOpened.value) {
    let specialParams = clone selEvent.value
    specialParams.eventCurArmy <- eventCurArmyIdx.value
    showCurNotReadySquadsMsg(@() joinQueue(specialParams))
    return
  }
  showCurNotReadySquadsMsg(@() joinQueue(selEvent.value))
}
let joinEventButton = {
  size = [startBtnWidth, SIZE_TO_CONTENT]
  children = mkBattleButton(loc("START"), joinEventQueue)
}

let setNotReadyBtn = textButton(loc("Set not ready"),
  @() myExtSquadData.ready(false),
  defQuickMatchBtnParams.__merge({
    style = { BgNormal = BtnActionBgDisabled }
    hotkeys = [[$"^{JB.B}", { description = { skip = true } }]] }))

let pressWhenReadyBtn = textButton(loc("Press when ready"),
  @() showCurNotReadySquadsMsg(@() myExtSquadData.ready(true)),
  defQuickMatchBtnParams.__merge({
    style = { BgNormal = brightAccentColor },
    hotkeys = [["^J:Y", { description = { skip = true } }]] }))

let toEventBattleButton = function() {
  let isEnabled = selEvent.value.queues.findvalue(@(q) q.enabled) != null
  return {
    watch = [isInQueue, selEvent, isInSquad, isSquadLeader, curLbIdx,
      curArmyData, myExtSquadData.ready, selLbMode, inactiveEventsToShow]
    size = [startBtnWidth, SIZE_TO_CONTENT]
    children = [
      selEvent.value == null
          ? null
        : ((selEvent.value?.showWhenInactive ?? false) && !isEnabled &&
            (selEvent.value?.leaderboardTableIdx ?? 0) < curLbIdx.value)
          ? endedEventBtn
        : ((selEvent.value?.showWhenInactive ?? false) && !isEnabled)
          ? upcomingEventBtn
        : isInSquad.value && !isSquadLeader.value && myExtSquadData.ready.value
          ? setNotReadyBtn
        : isInSquad.value && !isSquadLeader.value && !myExtSquadData.ready.value
          ? pressWhenReadyBtn
        : isInQueue.value
          ? leaveQueueButton
        : joinEventButton
      selLbMode.value == "for_fun_events" || (selEvent.value?.dontShowBoosters ?? false)
        ? null
        : mkActiveBoostersMark(activeBoostersMarkPosition)
    ]
  }
}

let actionIfValidBalance = function(action) {
  if (hasValidBalance.value)
    action()
  else
    showNegativeBalanceRestrictionMsgBox()
}

let createRoomBtn = Bordered(utf8ToUpper(loc("createRoom")),
  @() actionIfValidBalance(@() isEditEventRoomOpened(true)), {
    hotkeys = [ ["^J:X", { description = { skip = true } }] ]
  }
)

let activeCustomRoomButton = mkBattleButton(loc("Join"), @() actionIfValidBalance(joinSelEventRoom))
let inactiveCustomRoomButton = mkDisabledBattleButton(loc("noRoomSelected"), @() showMsgbox({ text = loc("noRoomSelected") }))
let noSlotsToJoinRoom = mkDisabledBattleButton(loc("noSlotsInRoom"), @() null)

let joinCustomRoomButton = @() {
  watch = selRoom
  size = [startBtnWidth, SIZE_TO_CONTENT]
  children = [
    selRoom.value == null ? inactiveCustomRoomButton
      : (selRoom.value?.membersCnt ?? 0) >= (selRoom.value?.maxPlayers ?? 0) ? noSlotsToJoinRoom
      : activeCustomRoomButton
    mkActiveBoostersMark(activeBoostersMarkPosition)
  ]
}

let function clusterAndRandTeamButtons() {
  let { alwaysRandomSide = false } = selEvent.value
  return {
    watch = [selEvent, randTeamAvailable]
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    hplace = ALIGN_RIGHT
    vplace = ALIGN_BOTTOM
    gap = bigPadding
    children = [
      alwaysRandomSide ? mkRandTeamBlock(alwaysRandTeamSign)
        : randTeamAvailable.value ? mkRandTeamBlock(randTeamCheckbox)
        : null
      serverClusterBtnAbbrev
    ]
  }
}

let topBar = {
  size = flex()
  maxWidth = maxContentWidth
  children = [
    function () {
      let res = { watch = isCustomRoomsUi }
      if (isCustomRoomsUi.value)
        return res
      return res.__update({
        flow = FLOW_VERTICAL
        hplace = ALIGN_CENTER
        padding = [midPadding, 0,0,0]
        children = [
          armySelectText
          @() {
            watch = eventsArmiesList
            flow = FLOW_HORIZONTAL
            children = eventsArmiesList.value.map(@(army) mkArmyBtn(army))
          }
        ]
      })
    }
    {
      size = [flex(), navHeight]
      children = profileInfoBlock
    }
  ]
}


let function leftBlock() {
  let squads_list = mkSquadsList()
  return {
    watch = [eventsArmiesList, eventCustomSquads, eventCurArmyIdx]
    size = [armieChooseBlockWidth, flex()]
    margin = [0, localPadding, 0, 0]
    flow = FLOW_VERTICAL
    gap = bigPadding
    transform = {}
    animations = [
      { prop = AnimProp.translate, from = [-sw(20), 0], to = [0, 0],
        duration = CONTAINERS_ANIM_DURATION, easing = InOutCubic, play = true }
    ]
    children = [
      eventCustomSquads.value == null ? squads_list : eventsSquadList(eventCustomSquads)
      backBtn
    ]
  }
}

let buttonsBlock = @() {
  watch = isRoomFilterOpened
  flow = FLOW_HORIZONTAL
  vplace = ALIGN_BOTTOM
  gap = localGap
  children = [
    backBtn
    Bordered(
      utf8ToUpper(loc("showFilters")),
      toggleEventFiltersPopup,
      isRoomFilterOpened.value ? filterBtnOpenedStyle : filterBtnCommonStyle
    )
    createRoomBtn
  ]
}
let roomsListBlock = @() {
  watch = curTab
  size = flex()
  flow = FLOW_VERTICAL
  gap = localGap
  children = [
    curTab.value == FEATURED_MODS_TAB_ID ? modsRoomsList : eventRoomsList
    buttonsBlock
  ]
}
let centralBlock = @() {
  watch = isCustomRoomsUi
  size = flex()
  flow = FLOW_VERTICAL
  padding = [0, localPadding, 0, 0]
  transform = {}
  animations = [{ prop = AnimProp.translate, from = [0, sh(70)], to = [0, 0],
    duration = CONTAINERS_ANIM_DURATION, easing = InOutCubic, play = true }]
  gap = localGap
  children = [
    wndTabsBlock
    isCustomRoomsUi.value ? roomsListBlock : events
  ]
}

let customMatchesRightBlock = {
  size = flex()
  flow = FLOW_VERTICAL
  gap = bigPadding
  children = [
    {
      size = flex()
      flow = FLOW_VERTICAL
      gap = bigPadding
      children = [
        isFeaturedAvailable ? customMissionOfferBlock : null
        mkPanel({ size = flex(), children = curEventRoomInfo })
      ]
    }
  ]
}

let rightBlock = @() {
  watch = [selEvent, lbCurrentTable, eventCustomProfile, isCustomRoomsUi]
  size = [startBtnWidth, flex()]
  flow = FLOW_VERTICAL
  gap = verticalGap
  transform = {}
  animations = [
    { prop = AnimProp.translate, from = [sw(30), 0], to = [0, 0],
      duration = CONTAINERS_ANIM_DURATION, easing = InOutCubic, play = true }
  ]
  children = [
    {
      size = flex()
      flow = FLOW_VERTICAL
      gap = bigPadding
      children = isCustomRoomsUi.value ? customMatchesRightBlock
        : selEvent.value != null && lbCurrentTable.value != null
          ? (selEvent.value?.isLeaderboardVisible ?? true) ? leaderboard : null
          : null
    }
    {
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      gap = bigPadding
      children = [
        isCustomRoomsUi.value ? null : clusterAndRandTeamButtons
        isCustomRoomsUi.value ? joinCustomRoomButton
          : selEvent.value != null ? toEventBattleButton
          : null
      ]
    }
  ]
}

let function eventsContent() {
  return {
    watch = isCustomRoomsUi
    size = flex()
    flow = FLOW_HORIZONTAL
    maxWidth = maxContentWidth
    hplace = ALIGN_CENTER
    gap = bigPadding
    hotkeys = [[$"^{JB.B} | Esc",
      { action = @() isEventModesOpened(false), description = loc("Close") }]]
    transform = {}
    animations = menuContentAnimation
    padding = [bigPadding, 0,0,0]
    children = [
      isCustomRoomsUi.value ? null : leftBlock
      centralBlock
      rightBlock
    ]
  }
}

let eventsWindow = mkMenuScene(topBar, eventsContent, footer)

let eventsWndHub = @() {
  watch = [room, roomIsLobby]
  size = flex()
  children = room.value == null ? eventsWindow
    : roomIsLobby.value ? lobbyWnd
    : progressText(loc("lobbyStatus/gameIsRunning"))
}

let open = function() {
  if (eventGameModes.value.len() <= 0 || customRoomsModeSaved.value)
    curTab(CUSTOM_MATCHES_TAB_ID)
  else
    curTab(windowTabs.value?[0])
  sceneWithCameraAdd(eventsWndHub, "events")
}

if (isEventModesOpened.value)
  open()

isEventModesOpened.subscribe(@(v) v ? open() : sceneWithCameraRemove(eventsWndHub))

lobbyStatus.subscribe(function(status) {
  if (status == LobbyStatus.SceneLoadFailure) {
    showMsgbox({
        text = loc($"lobbyStatus/{status}")
      })
  }
})
