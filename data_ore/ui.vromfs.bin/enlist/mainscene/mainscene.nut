from "%enlSqGlob/ui/ui_library.nut" import *

let { fontBody, fontSub, fontawesome } = require("%enlSqGlob/ui/fontsStyle.nut")
let { bigPadding, startBtnWidth, contentOffset, commonBtnHeight,
  defItemBlur, darkTxtColor, transpPanelBgColor, hoverSlotBgColor, titleTxtColor, defTxtColor,
  accentColor, smallPadding, mainContentHeaderHeight, sidePadding, midPadding, attentionTxtColor
} = require("%enlSqGlob/ui/designConst.nut")
let startBtn = require("%enlist/startButton.nut")
let { changeGameModeBtn, selectedGameMode } = require("%enlist/mainScene/changeGameModeButton.nut")
let { randTeamAvailable, randTeamCheckbox, queuesCampaignsData
} = require("%enlist/quickMatch.nut")
let { mkDailyTasksUiReward, mkDailyTasksUi } = require("%enlist/unlocks/taskWidgetUi.nut")
let mkOffersPanel = require("%enlist/offers/offersPanel.nut")
let { isMainMenuVisible } = require("%enlist/mainMenu/sectionsState.nut")
let { serviceNotificationsList } = require("%enlSqGlob/serviceNotificationsList.nut")
let mkServiceNotification = require("%enlSqGlob/ui/notifications/mkServiceNotification.nut")
let { mkSquadsList } = require("%enlist/soldiers/squads_list.ui.nut")
let systemWarningsBlock = require("%enlist/mainScene/systemWarnings.nut")
let { mkSquadInfo } = require("%enlist/soldiers/squad_info.ui.nut")
let { mkSoldierInfo, mkCustomButtons } = require("%enlist/soldiers/mkSoldierInfo.nut")
let { curSoldierInfo } = require("%enlist/soldiers/model/curSoldiersState.nut")
let gotoResearchUpgradeMsgBox = require("%enlist/soldiers/researchUpgradeMsgBox.nut")
let { promoWidget } = require("%enlist/components/mkPromoWidget.nut")
let { mkPresetEquipBlock } = require("%enlist/preset/presetEquipUi.nut")
let { notifierHint } = require("%enlist/tutorial/notifierTutorial.nut")
let { hasBaseEvent, openCustomGameMode } = require("%enlist/gameModes/eventModesState.nut")
let { utf8ToUpper } = require("%sqstd/string.nut")
let { goodManageData } = require("%enlist/shop/armyShopState.nut")
let { withTooltip } = require("%ui/style/cursors.nut")
let tooltipCtor = require("%ui/style/tooltipCtor.nut")
let { mkArmyIcon } = require("%enlist/soldiers/components/armyPackage.nut")
let fa = require("%ui/components/fontawesome.map.nut")
let { getArmyName } = require("%enlist/campaigns/armiesConfig.nut")
let { getCampaignTitle } = require("%enlSqGlob/ui/itemsInfo.nut")
let { FAButton } = require("%ui/components/txtButton.nut")
let { isMissionsRatingOpened } = require("%enlist/gameModes/missionsRatingState.nut")
let { hasMissionLikes } = require("%enlist/featureFlags.nut")


let isOfferExpandLocked = Watched(false)

function mkMainSceneContent() {
  function mkSoldiersUi(){
    let squad_info = mkSquadInfo()
    let squads_list = mkSquadsList()

    let mainContent = {
      size = flex()
      flow = FLOW_HORIZONTAL
      gap = bigPadding
      children = [
        squads_list
        squad_info
        mkSoldierInfo({
          soldierInfoWatch = curSoldierInfo,
          onResearchClickCb = gotoResearchUpgradeMsgBox
          buttons = mkCustomButtons(curSoldierInfo)
        })
        mkPresetEquipBlock()
      ]
    }

    return mainContent
  }

  let customMatchesBtn = @(){
    watch = hasBaseEvent
    size = [flex(), SIZE_TO_CONTENT]
    children = hasBaseEvent.value ? null : watchElemState(@(sf) {
      rendObj = ROBJ_WORLD_BLUR
      size = [flex(), commonBtnHeight]
      color = defItemBlur
      fillColor = sf & S_ACTIVE ? accentColor
        : sf & S_HOVER ? hoverSlotBgColor
        : transpPanelBgColor
      behavior = Behaviors.Button
      onClick = openCustomGameMode
      sound = {
        hover = "ui/enlist/button_highlight"
        click = "ui/enlist/button_click"
        active = "ui/enlist/button_action"
      }
      valign = ALIGN_CENTER
      halign = ALIGN_CENTER
      children = {
        rendObj = ROBJ_TEXT
        text = utf8ToUpper(loc("custom_matches"))
        color = sf & S_ACTIVE ? titleTxtColor
          : sf & S_HOVER ? darkTxtColor
          : defTxtColor
      }.__update(fontBody)
    })
  }

  let quickMatchButtonWidth = startBtnWidth

  let armyGameModeBlock = @() {
    watch = [selectedGameMode, randTeamAvailable]
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = smallPadding
    halign = ALIGN_RIGHT
    children = [
      selectedGameMode.value?.isLocal || !randTeamAvailable.value ? null : randTeamCheckbox
      @() {
        watch = hasMissionLikes
        children = [
          changeGameModeBtn
          !hasMissionLikes.value ? null
            : FAButton("cog", @() isMissionsRatingOpened(true), { pos = [-hdpx(55), 0] })
        ]
      }
    ]
  }

  let startPlay = {
    halign = ALIGN_RIGHT
    children = @() {
      watch = [selectedGameMode, randTeamAvailable]
      size = [quickMatchButtonWidth, SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      halign = ALIGN_RIGHT
      gap = smallPadding
      children = [
        armyGameModeBlock
        startBtn
      ]
    }
  }

  let bpBlockUi = @() {
    watch = isOfferExpandLocked
    behavior = Behaviors.Button
    onHover = @(on) isOfferExpandLocked(on)
    skipDirPadNav = true
    children = {
      flow = FLOW_VERTICAL
      gap = smallPadding
      children = [
        mkDailyTasksUiReward(@(on) isOfferExpandLocked(on))
        !isOfferExpandLocked.value ? null
          : {
              clipChildren = true
              children = {
                key = isOfferExpandLocked.value
                children = mkDailyTasksUi(false, @(on) isOfferExpandLocked(on))
                transform = {}
                animations = [{ prop = AnimProp.translate, from = [0, -hdpxi(180)],
                  to = [0, 0], duration = 0.3, easing = OutQuintic, play = true }]
              }
            }
      ]
    }
  }

  let mkMapsListItem = @(army, maps) {
    flow = FLOW_VERTICAL
    children = [
      {
        flow = FLOW_HORIZONTAL
        gap = midPadding
        valign = ALIGN_CENTER
        children = [
          mkArmyIcon(army, hdpxi(18), { margin = 0 })
          {
            rendObj = ROBJ_TEXT
            color = attentionTxtColor
            text = getArmyName(army)
          }.__update(fontSub)
        ]
      }
      {
        rendObj = ROBJ_TEXTAREA
        behavior = [Behaviors.TextArea]
        color = defTxtColor
        text = "\n".join(maps.map(@(v) getCampaignTitle(v)))
      }.__update(fontSub)
    ]
  }

  let possibleMaps = {
    behavior = Behaviors.Button
    skipDirPadNav = false
    vplace = ALIGN_BOTTOM
    valign = ALIGN_CENTER
    children = {
      rendObj = ROBJ_TEXTAREA
      behavior = Behaviors.TextArea
      color = defTxtColor
      halign = ALIGN_RIGHT
      text = loc("start/possible_maps", { questionIcon = $"<fa>{fa["question-circle"]}</fa>" })
      tagsTable = {
        fa = fontawesome
      }
    }.__update(fontSub)
  }

  function possibleMapsTooltip() {
    let children = []
    queuesCampaignsData.value.mapsList.each(@(maps, army)
      children.append(mkMapsListItem(army, maps)))

    return {
      watch = queuesCampaignsData
      flow = FLOW_VERTICAL
      gap = bigPadding
      children
    }
  }

  let possibleMapsWidget = @() {
    watch = queuesCampaignsData
    size = [SIZE_TO_CONTENT, flex()]
    vplace = ALIGN_BOTTOM
    children = queuesCampaignsData.value.mapsList.len() == 0 ? null
      : withTooltip(possibleMaps, @() tooltipCtor(possibleMapsTooltip))
  }

  let rightContent = {
    size = [SIZE_TO_CONTENT, flex()]
    hplace = ALIGN_RIGHT
    flow = FLOW_HORIZONTAL
    gap = midPadding
    children = [
      possibleMapsWidget
      {
        size = [startBtnWidth, flex()]
        flow = FLOW_VERTICAL
        gap = { size = flex() }
        children = [
          @() {
            watch = [serviceNotificationsList, hasBaseEvent]
            size = [flex(), SIZE_TO_CONTENT]
            flow = FLOW_VERTICAL
            gap = smallPadding
            children = serviceNotificationsList.value.len() > 0
              ? mkServiceNotification(serviceNotificationsList.value, { hplace = ALIGN_RIGHT })
              : [
                  bpBlockUi
                  mkOffersPanel(isOfferExpandLocked)
                  hasBaseEvent.value ? customMatchesBtn : null
                ]
          }
          startPlay
        ]
      }
    ]
  }

  let headerContent = {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    margin = [contentOffset, 0, 0, 0]
    minHeight = mainContentHeaderHeight
    children = [
      promoWidget("soldier_equip", "soldier_inventory", {margin = [0, sidePadding, 0, 0]})
      notifierHint
    ]
  }

  return {
    size = flex()
    onAttach = @() isMainMenuVisible(true)
    function onDetach() {
      goodManageData(null)
      isMainMenuVisible(false)
    }
    children = {
      size = flex()
      flow = FLOW_VERTICAL
      children = [
        headerContent
        {
          size = flex()
          children = [
            rightContent
            mkSoldiersUi
            systemWarningsBlock
          ]
        }
      ]
    }
  }
}
return {mkMainSceneContent}