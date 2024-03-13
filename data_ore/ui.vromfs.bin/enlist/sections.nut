from "%enlSqGlob/ui/ui_library.nut" import *

let { fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let { buildShopUi } = require("shop/mkShopUi.nut")
let { buildResearchesUi } = require("researches/mkResearchesUi.nut")
let { mkMainSceneContent } = require("%enlist/mainScene/mainScene.nut")
let growthUi = require("%enlist/growth/growthUi.nut")
let armyProgressScene = require("%enlist/soldiers/armyProgressScene.nut")
let { setSectionsSorted, curSection, mainSectionId } = require("%enlist/mainMenu/sectionsState.nut")
let { disabledSectionsData } = require("%enlist/mainMenu/disabledSections.nut")
let { seenResearches, markSeen, curUnseenResearches } = require("researches/unseenResearches.nut")
let { isCurCampaignProgressUnlocked } = require("%enlist/meta/curCampaign.nut")
let { curUnseenAvailShopGuids, isShopVisible, hasShopSection, curArmyShopItems, notOpenedShopItems
} = require("shop/armyShopState.nut")
let { nextTutorialUnlock, showGetUnlockTutorial
} = require("%enlist/tutorial/notReceivedUnlockTutorial.nut")
let { hasCampaignSection } = require("soldiers/model/armyUnlocksState.nut")
let { hasLevelDiscount, curLevelDiscount
} = require("%enlist/campaigns/armiesConfig.nut")
let { curArmy, curArmyData } = require("%enlist/soldiers/model/state.nut")
let { mkAlertIcon, PERK_ALERT_SIGN, ITEM_ALERT_SIGN
} = require("%enlSqGlob/ui/soldiersUiComps.nut")
let { notChoosenPerkArmies } = require("%enlist/soldiers/model/soldierPerks.nut")
let { unseenArmiesVehicle } = require("%enlist/vehicles/unseenVehicles.nut")
let { openUrl } = require("%ui/components/openUrl.nut")
let { getStoreUrl, getEventUrl} = require("%ui/networkedUrls.nut")
let { isEventUnseen, markEventSeen } = require("gameModes/eventUnseenSignState.nut")
let { markShopItemOpened } = require("%enlist/shop/unseenShopItems.nut")
let { seenArmyProgress, markOpened } = require("%enlist/soldiers/model/unseenArmyProgress.nut")
let { mkDiscountBar } = require("%enlist/shop/shopPackage.nut")
let { chapterIdx } = require("%enlist/shop/shopState.nut")
let { titleTxtColor, darkTxtColor, brightAccentColor } = require("%enlSqGlob/ui/designConst.nut")
let { unblinkUnseen } = require("%ui/components/unseenComponents.nut")
let { curGrowthState, curGrowthConfig, GrowthStatus } = require("%enlist/growth/growthState.nut")


let alertSign = {
  pos = [hdpx(10), -hdpx(2)]
  children = unblinkUnseen
}


function researchesAlertUi() {
  let { hasUnseen = false } = curUnseenResearches.value
  return {
    watch = curUnseenResearches
    size = [flex(), SIZE_TO_CONTENT]
    pos = [0, hdpx(5)]
    margin = hdpx(11)
    halign = ALIGN_RIGHT
    children = hasUnseen ? alertSign : null
  }
}

let hasUnseenShopItems = Computed(@() curUnseenAvailShopGuids.value.len() > 0)

let maxCurArmyDiscount = Computed(function() {
  let lvl = curArmyData.value?.level ?? 0
  return curArmyShopItems.value.reduce(@(res, val)
    (val?.requirements.armyLevel ?? 0) > lvl
      ? res
      : max(res, (val?.hideDiscount ? 0 : val?.discountInPercent ?? 0)), 0)
})

let maxGrowthDiscount = Computed(function() {
  let discountByShopGuid = {}
  foreach (shopItem in curArmyShopItems.value) {
    let { guid, discountInPercent = 0 } = shopItem
    if (discountInPercent > 0)
      discountByShopGuid[guid] <- discountInPercent
  }

  let growthStates = curGrowthState.value
  local res = 0
  foreach (growthItem in curGrowthConfig.value) {
    let { id, expRequired = 0 } = growthItem
    let { status = GrowthStatus.UNAVAILABLE } = growthStates?[id]

    if (status == GrowthStatus.REWARDED
        || (status != GrowthStatus.PURCHASABLE && expRequired > 0))
      continue

    let shopItemGuid = growthItem?.shopItemsGuids[0]
    if (shopItemGuid != null)
      res = max(res, discountByShopGuid?[shopItemGuid] ?? 0)
  }
  return res
})

let hasPurchGrowth = Computed(function() {
  let configs = curGrowthConfig.value
  return curGrowthState.value.findvalue(@(st)
    st.status == GrowthStatus.PURCHASABLE && st.guid in configs) != null
})

let haveSpecialOfferArmy = Computed(function() {
  return curArmyShopItems.value.findvalue(@(val)
    val?.hideDiscount && (val?.discountInPercent ?? 0) > 0 && val?.showSpecialOfferText
  ) != null
})

let hasShopAlert = Computed(@() hasShopSection.value
  && isCurCampaignProgressUnlocked.value
  && isShopVisible.value
  && (maxCurArmyDiscount.value > 0 || hasUnseenShopItems.value))

let isShopOpen = Computed(@() curSection.value == "SHOP")
let watchShopAlert = freeze([isShopOpen, hasShopAlert, maxCurArmyDiscount, haveSpecialOfferArmy])

let styleAlertUi = {
  size = [flex(), SIZE_TO_CONTENT]
  margin = hdpx(11)
  halign = ALIGN_RIGHT
}

let mkGrowthAlertUi = @(sf) function() {
  let percents = maxGrowthDiscount.value
  return {
    watch = [hasPurchGrowth, maxGrowthDiscount]
    children = percents > 0
      ? mkDiscountBar({
          rendObj = ROBJ_TEXT
          text = $"-{percents}%"
          color = sf & S_HOVER ? titleTxtColor : darkTxtColor
        }.__update(fontSub), true, sf & S_HOVER ? darkTxtColor : brightAccentColor)
      : hasPurchGrowth.value ? alertSign
      : null
  }.__merge(styleAlertUi)
}

let mkShopAlertUi = @(sf) function() {
  if (!hasShopAlert.value)
    return { watch = watchShopAlert }

  let percents = maxCurArmyDiscount.value
  return {
    watch = watchShopAlert
    children = percents > 0
        ? mkDiscountBar({
            rendObj = ROBJ_TEXT
            text = $"-{percents}%"
            color = sf & S_HOVER ? titleTxtColor : darkTxtColor
          }.__update(fontSub), true, sf & S_HOVER ? darkTxtColor : brightAccentColor)
      : alertSign
  }.__merge(styleAlertUi)
}

let mkEventAlertUi = @(_sf) function() {
  if (!isEventUnseen.value)
    return { watch = isEventUnseen }
  return {
    watch = isEventUnseen
    children = isEventUnseen.value ? alertSign : null
  }.__merge(styleAlertUi)
}

let mkUnseenAlert = mkAlertIcon(ITEM_ALERT_SIGN, Computed(@()
  (unseenArmiesVehicle.value?[curArmy.value].len() ?? 0) > 0
))

let mkPerksAlert = mkAlertIcon(PERK_ALERT_SIGN, Computed(@()
  (notChoosenPerkArmies.value?[curArmy.value] ?? 0) > 0))


let hasUnseenArmyProgress = Computed(@() hasCampaignSection.value
  && isCurCampaignProgressUnlocked.value
  && curArmyData.value?.guid in seenArmyProgress.value?.unseen
)
let hasUnopenedArmyProgress = Computed(@() hasCampaignSection.value
  && isCurCampaignProgressUnlocked.value
  && curArmyData.value?.guid in seenArmyProgress.value?.unopened
)


const CAMPAIGN_PROGRESS = "CAMPAIGN"
let campaignWatched = [
  curSection, hasLevelDiscount, curLevelDiscount, hasUnseenArmyProgress, hasUnopenedArmyProgress
]

let notifierSize = [hdpxi(29), hdpxi(17)]

let campaignNotifier = {
  size = notifierSize
  hplace = ALIGN_RIGHT
  rendObj = ROBJ_IMAGE
  image = Picture("ui/skin#info/progress_notifier.svg:{0}:{1}:K"
    .subst(notifierSize[0], notifierSize[1]))
}
let blinkCampaignNotifier = {
  animations = [{ prop = AnimProp.opacity, from = 0.5, to = 1, duration = 1,
    play = true, loop = true, easing = Blink }]
}.__update(campaignNotifier)

let sections = [
  {
    locId = "menu/battles"
    getContent = mkMainSceneContent
    id = mainSectionId
    camera = "soldiers"
    addChild = {
      pos = [0, hdpx(16)]
      flow = FLOW_HORIZONTAL
      hplace = ALIGN_RIGHT
      valign = ALIGN_CENTER
      children = [
        mkUnseenAlert
        mkPerksAlert
      ]
    }
  }

  {
    locId = "menu/progress"
    descId = "menu/campaignRewardsDesc"
    getContent = @() armyProgressScene
    id = CAMPAIGN_PROGRESS
    camera = "researches"
    mkChild = @(sf) function() {
      let notifier = curSection.value != CAMPAIGN_PROGRESS && hasUnopenedArmyProgress.value
        ? blinkCampaignNotifier
        : campaignNotifier
      return {
        watch = campaignWatched
        size = [flex(), SIZE_TO_CONTENT]
        margin = hdpx(11)
        halign = ALIGN_RIGHT
        children = hasLevelDiscount.value
          ? mkDiscountBar({
              rendObj = ROBJ_TEXT
              text = $"-{curLevelDiscount.value}%"
              color = sf & S_HOVER ? titleTxtColor : darkTxtColor
            }.__update(fontSub), true, sf & S_HOVER ? darkTxtColor : brightAccentColor)
          : hasUnseenArmyProgress.value ? notifier.__merge({
              color = sf & S_HOVER ? darkTxtColor : brightAccentColor
            })
          : null
      }
    }
    onExitCb = function() {
      let armyId = curArmyData.value?.guid ?? ""
      let { unseen = {}, unopened = {} } = seenArmyProgress.value
      if (armyId in unopened)
        markOpened(armyId, unopened[armyId])

      if (armyId not in unseen)
        return true

      let unlock = nextTutorialUnlock.value
      if (unlock != null) {
        showGetUnlockTutorial(unlock)
        return false
      }

      return true
    }
  }

  {
    locId = "menu/researches"
    descId = "menu/researchesDesc"
    getContent = buildResearchesUi
    id = "RESEARCHES"
    camera = "researches"
    addChild = researchesAlertUi
    onExitCb = function() {
      let armyId = curArmyData.value?.guid
      let unopened = seenResearches.value?.unopened[armyId] ?? {}
      if (unopened.len() > 0)
        markSeen(armyId, unopened.keys(), true)
      return true
    }
  }

  {
    locId = "menu/shop"
    getContent = buildShopUi
    id = "SHOP"
    camera = "researches"
    mkChild = mkShopAlertUi
    onBackCb = function() {
      if (chapterIdx.value >= 0) {
        chapterIdx(-1)
        return false
      }
      return true
    }
    onExitCb = function() {
      markShopItemOpened(curArmyData.value?.guid, notOpenedShopItems.value)
      return true
    }
    animations = null
  }

  {
    locId = "menu/growth"
    getContent = growthUi
    id = "GROWTH"
    camera = "battle_pass"
    mkChild = mkGrowthAlertUi
  }
]

if (getStoreUrl() != null)
  sections.append({
    locId = "menu/store"
    id = "STORE"
    selectable = false
    onClickCb = @() openUrl(getStoreUrl())
  })

if (getEventUrl() != null)
  sections.append({
    locId = "menu/event"
    id = "EVENT"
    selectable = false
    onClickCb = function(){
      openUrl(getEventUrl())
      markEventSeen()
    }
    mkChild = mkEventAlertUi
  })

function updateSections(disabled) {
  let sectionsToShow = sections.filter(@(section) section.id not in disabled)
  setSectionsSorted(sectionsToShow)
}

disabledSectionsData.subscribe(updateSections)
updateSections(disabledSectionsData.value)
