from "%enlSqGlob/ui/ui_library.nut" import *

let JB = require("%ui/control/gui_buttons.nut")
let { fontHeading2, fontBody, fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let { get_log_directory, DBGLEVEL } = require("dagor.system")
let { is_pc } = require("%dngscripts/platform.nut")
let { normal, setTooltip } = require("%ui/style/cursors.nut")
let { midPadding, commonBtnHeight, strokeStyle,
  awardIconSpacing, awardIconSize, debriefingDarkColor,
  panelBgColor
} = require("%enlSqGlob/ui/designConst.nut")
let { Bordered, PrimaryFlat } = require("%ui/components/textButton.nut")
let closeBtnBase = require("%ui/components/closeBtn.nut")
let { secondsToTimeSimpleString } = require("%ui/helpers/time.nut")
let scrollbar = require("%ui/components/scrollbar.nut")
let dtxt = require("%ui/components/text.nut").dtext
let { sound_play } = require("%dngscripts/sound_system.nut")
let { utf8ToUpper } = require("%sqstd/string.nut")
let { safeAreaBorders } = require("%enlist/options/safeAreaState.nut")
let { mkArmyIcon } = require("%enlist/soldiers/components/armyPackage.nut")
let mkAward = require("components/mkAward.nut")
let mkArmyProgress = require("components/mkArmyProgress.nut")
let mkSquadProgress = require("components/mkSquadProgress.nut")
let mkTasksProgress = require("components/mkTasksProgress.nut")
let { mkSoldierExpTooltipText } = require("%enlist/debriefing/components/mkExpTooltipText.nut")
let mkSoldierCard = require("mkDebriefingSoldierCard.nut")
let mkBattleHeroesBlock = require("mkDebriefingBattleHeroes.nut")
let mkScoresStatistics = require("%ui/hud/components/mkScoresStatistics.nut")
let { setCurSection, mainSectionId, jumpToArmyGrowth } = require("%enlist/mainMenu/sectionsState.nut")
let { gameProfile } = require("%enlist/soldiers/model/config/gameProfile.nut")
let { selectArmy, setCurSquadId } = require("%enlist/soldiers/model/state.nut")
let { collectSoldierPhoto } = require("%enlist/soldiers/model/collectSoldierData.nut")
let { setCurCampaign, curCampaignConfig } = require("%enlist/meta/curCampaign.nut")
let squadsPresentation = require("%enlSqGlob/ui/squadsPresentation.nut")
let { premiumImage } = require("%enlist/currency/premiumComp.nut")
let { round_by_value } = require("%sqstd/math.nut")
let { logerr } = require("dagor.debug")
let { saveDebriefingToLog, saveDebriefingToFile } = require("%enlist/debriefing/debriefing_dbg.nut")
let { INVALID_GROUP_ID, INVALID_SESSION_ID } = require("matching.errors")
let { get_setting_by_blk_path } = require("settings")
let {isProductionCircuit} = require("%dngscripts/appInfo.nut")
let {hasClientPermission} = require("%enlSqGlob/client_user_rights.nut")
let { BattleHeroesAward, awardPriority, isSoldierAward, isTopSquadAward
} = require("%enlSqGlob/ui/battleHeroesAwards.nut")
let { debounce } = require("%sqstd/timers.nut")
let { mkRankImage, getRankConfig } = require("%enlSqGlob/ui/rankPresentation.nut")
let { promoWidget } = require("%enlist/components/mkPromoWidget.nut")
let { showAnoProfile } = require("%enlist/profile/anoProfileState.nut")
let { INVITE_TO_FRIENDS, INVITE_TO_PSN_FRIENDS, CANCEL_INVITE, APPROVE_INVITE, REJECT_INVITE,
  REMOVE_FROM_FRIENDS, ADD_TO_BLACKLIST, REMOVE_FROM_BLACKLIST, REMOVE_FROM_BLACKLIST_XBOX,
  REMOVE_FROM_BLACKLIST_PSN, SHOW_USER_LIVE_PROFILE
} = require("%enlist/contacts/contactActions.nut")
let userActions = [
  INVITE_TO_FRIENDS, INVITE_TO_PSN_FRIENDS, CANCEL_INVITE, APPROVE_INVITE, REJECT_INVITE,
  REMOVE_FROM_FRIENDS, ADD_TO_BLACKLIST, REMOVE_FROM_BLACKLIST, REMOVE_FROM_BLACKLIST_XBOX,
  REMOVE_FROM_BLACKLIST_PSN, SHOW_USER_LIVE_PROFILE
]
let { showUserProfile } = require("%enlist/featureFlags.nut")
let { curSoldierIdx } = require("%enlist/soldiers/model/curSoldiersState.nut")
let { isUnited } = require("%enlist/meta/campaigns.nut")

const ANIM_TRIGGER = "new_items_wnd_anim"
const NEW_BLOCK_TRIGGER = "new_debr_block_appear"
const OVERLAY_TRIGGER = "content_anim"
const OVERLAY_TRIGGER_SKIP = "content_anim_skip"
const SKIP_ANIM_POSTFIX = "_skip"
const MOD_EXP_MODE = "mods"
const FILL_BLOCK_DELAY = 0.3
const AWARD_DELAY = 0.2

const MISSION_NAME_TEXT_DELAY = 1.6
const SESSION_TIME_TEXT_DELAY = 1.8
const SESSION_TIME_VALUE_DELAY = 2.0
const HEADER_TEXT_DELAY = 1.0
const HEADER_ICON_DELAY = 1.3

const DELAY = 0.1 //default delayAfter for mkAnim

let BLOCKS_GAP = hdpx(18)
let BLOCK_PADDING = hdpx(10)
let BODY_W = fsh(132)

let debriefingWidth = sw(80)
let leftBlockWidth = debriefingWidth * 0.55
let maxAwardsRows = 3
let awardsInRow = (leftBlockWidth / (awardIconSize + awardIconSpacing)).tointeger()

local hasAnim = true
local newLevelSoldier = null
local skippedAnims = {}
let canQuitByEsc = Watched(false)
let usedSkipAnim = Watched(false)
let isWaitAnim = Watched(false)

local quitByEscTimer
isWaitAnim.subscribe(function(v) {
  if (!v) {
    gui_scene.clearTimer(quitByEscTimer)
    quitByEscTimer = gui_scene.setTimeout(usedSkipAnim.value ? 2 : 0.1, @() canQuitByEsc(true))
  }
})

let windowBlocks = []
let windowBlocksVer = Watched(0)
local windowContentQueue = []
let scrollHandler = ScrollHandler()
let gainRewardContent = Watched(null)

local hasAnimFinished = false

let soldierStatsCfg = [
  { stat = "time", locId = "debriefing/battleTime", toString = secondsToTimeSimpleString, isVisible = @(_) true },
  { stat = "spawns", locId = "debriefing/awards/spawns", isVisible = @(_) true },
  { stat = "kills", locId = "debriefing/awards/kill", isVisible = @(_) true },
  { stat = "attackKills", locId = "debriefing/awards/attackKills", isVisible = @(_) true },
  { stat = "defenseKills", locId = "debriefing/awards/defenseKills", isVisible = @(_) true },
  { stat = "longRangeKills", locId = "debriefing/awards/long_range_kill" },
  { stat = "tankKills", locId = "debriefing/awards/tankKill", isVisible = @(_) true },
  { stat = "apcKills", locId = "debriefing/awards/apcKill" },
  { stats = ["planeKills", "aiPlaneKills"], locId = "debriefing/awards/planeKill", isVisible = @(_) true },
  { stat = "assists", locId = "debriefing/awards/assists", isVisible = @(_) true },
  { stat = "tankKillAssists", locId = "debriefing/awards/tankKillAssists" },
  { stat = "apcKillAssists", locId = "debriefing/awards/apcKillAssists" },
  { stats = ["planeKillAssists", "aiPlaneKillAssists"], locId = "debriefing/awards/planeKillAssists" },
  { stat = "crewKillAssists", locId = "debriefing/awards/crewKillAssists", toString = @(v) round_by_value(v, 0.01), },
  { stat = "crewTankKillAssists", locId = "debriefing/awards/crewTankKillAssists", toString = @(v) round_by_value(v, 0.01),},
  { stat = "crewApcKillAssists", locId = "debriefing/awards/crewApcKillAssists", toString = @(v) round_by_value(v, 0.01),},
  { stats = ["crewPlaneKillAssists", "crewAiPlaneKillAssists"], locId = "debriefing/awards/crewPlaneKillAssists", toString = @(v) round_by_value(v, 0.01), },
  { stat = "tankKillAssistsAsCrew", locId = "debriefing/awards/tankKillAssistsAsCrew", toString = @(v) round_by_value(v, 0.01), },
  { stat = "apcKillAssistsAsCrew", locId = "debriefing/awards/apcKillAssistsAsCrew", toString = @(v) round_by_value(v, 0.01), },
  { stats = ["planeKillAssistsAsCrew", "aiPlaneKillAssistsAsCrew"], locId = "debriefing/awards/planeKillAssistsAsCrew", toString = @(v) round_by_value(v, 0.01), },
  { stat = "builtStructures", locId = "debriefing/awards/builtStructures" },
  { stat = "builtGunKills", locId = "debriefing/awards/builtGunKills" },
  { stat = "builtGunKillAssists", locId = "debriefing/awards/builtGunKillAssists" },
  { stat = "builtGunTankKills", locId = "debriefing/awards/builtGunTankKills" },
  { stat = "builtGunTankKillAssists", locId = "debriefing/awards/builtGunTankKillAssists" },
  { stat = "builtGunApcKills", locId = "debriefing/awards/builtGunApcKills" },
  { stat = "builtGunApcKillAssists", locId = "debriefing/awards/builtGunApcKillAssists" },
  { stats = ["builtGunPlaneKills", "builtGunAiPlaneKills"], locId = "debriefing/awards/builtGunPlaneKills" },
  { stats = ["builtGunPlaneKillAssists", "builtGunAiPlaneKillAssists"], locId = "debriefing/awards/builtGunPlaneKillAssists" },
  { stat = "builtBarbwireActivations", locId = "debriefing/awards/builtBarbwireActivations" },
  { stat = "builtCapzoneFortificationActivations", locId = "debriefing/awards/builtCapzoneFortificationActivations" },
  { stat = "builtAmmoBoxRefills", locId = "debriefing/awards/builtAmmoBoxRefills" },
  { stat = "builtMedBoxRefills", locId = "debriefing/awards/builtMedBoxRefills" },
  { stat = "builtRallyPointUses", locId = "debriefing/awards/builtRallyPointUses" },
  { stat = "ownedMobileSpawnUses", locId = "debriefing/awards/ownedMobileSpawnUses" },
  { stat = "hostedOnSoldierSpawns", locId = "debriefing/awards/hostedOnSoldierSpawns" },
  { stat = "vehicleRepairs", locId = "debriefing/awards/vehicleRepairs" },
  { stat = "vehicleExtinguishes", locId = "debriefing/awards/vehicleExtinguishes" },
  { stat = "landings", locId = "debriefing/awards/landings" },
  { stat = "barrageBalloonDestructions", locId = "debriefing/awards/barrageBalloonDestructions" },
  { stat = "enemyBuiltFortificationDestructions", locId = "debriefing/awards/enemyBuiltFortificationDestructions" },
  { stat = "enemyBuiltGunDestructions", locId = "debriefing/awards/enemyBuiltGunDestructions" },
  { stat = "enemyBuiltUtilityDestructions", locId = "debriefing/awards/enemyBuiltUtilityDestructions" },
  { stat = "reviveAssists", locId = "debriefing/awards/reviveAssists" },
  { stat = "healAssists", locId = "debriefing/awards/healAssists" },
  { stat = "captures", locId = "debriefing/awards/capture", toString = @(v) round_by_value(v, 0.1), isVisible = @(_) true },
  { stat = "friendlyHits", locId = "debriefing/awards/friendlyHits" },
  { stat = "friendlyKills", locId = "debriefing/awards/friendlyKills" },
  { stat = "friendlyTankHits", locId = "debriefing/awards/friendlyTankHits" },
  { stat = "friendlyTankKills", locId = "debriefing/awards/friendlyTankKills" },
  { stat = "friendlyApcHits", locId = "debriefing/awards/friendlyApcHits" },
  { stat = "friendlyApcKills", locId = "debriefing/awards/friendlyApcKills" },
  { stat = "friendlyPlaneHits", locId = "debriefing/awards/friendlyPlaneHits" },
  { stat = "friendlyPlaneKills", locId = "debriefing/awards/friendlyPlaneKills" },
  { stat = "awardScore", locId = "debriefing/score", isVisible = @(_) true },
  { stat = "noviceBonus", locId = "debriefing/noviceExpBonus" }
].map(@(s) { toString = @(v) v.tostring(), isVisible = @(v) v != 0 }.__update(s))


windowBlocksVer.subscribe(@(_) windowBlocks.len() == 0 ? null : anim_start(NEW_BLOCK_TRIGGER))
let scrollToBlock = @(key) scrollHandler.scrollToChildren(@(desc) desc?.key == key, 3, false, true)

let mkAppearAnimations = @(delay, onVisibleCb = null) [
  { prop = AnimProp.opacity, from = 0, to = 0, duration = delay, play = true,
    easing = InOutCubic, trigger = $"{ANIM_TRIGGER}{SKIP_ANIM_POSTFIX}" }
  { prop = AnimProp.opacity, from = 0, to = 1, duration = 0.4, play = true,
    easing = InOutCubic, delay = delay, trigger = ANIM_TRIGGER, onFinish = onVisibleCb }
  { prop = AnimProp.scale, from = [2,2], to = [1,1], duration = 0.8, play = true,
    easing = InOutCubic, delay = delay, trigger = ANIM_TRIGGER}
  { prop = AnimProp.translate, from = [0, -sh(30)], to = [0,0], duration = 0.8, play = true,
    easing = OutQuart, delay = delay, trigger = ANIM_TRIGGER}
]

let blockAnimations = mkAppearAnimations(0).append(
  { prop = AnimProp.translate, from = [0, sh(30)], to = [0,0], duration = 0.3, easing = OutQuart,
    trigger = NEW_BLOCK_TRIGGER })

let mkAnim = @(children, onVisibleCb = null, animDelay = DELAY) children == null ? null : {
  size = SIZE_TO_CONTENT
  transform = {}
  animations = mkAppearAnimations(animDelay, onVisibleCb)
  children = children
}

let grayText = @(override) {
  rendObj = ROBJ_TEXT
  color = Color(184, 182, 181)
}.__merge(fontBody, override)

let headerMarginTop = hdpx(30)

function overGainRewardBlock() {
  let res = { watch = gainRewardContent }
  let content = gainRewardContent.value
  if (content == null)
    return res
  return res.__update({
    size = flex()
    children = {
      key = $"{content.key}_nest"
      rendObj = ROBJ_SOLID
      size = flex()
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      color = debriefingDarkColor
      behavior = Behaviors.Button
      children = content
      opacity = 0
      transform = {}
      animations = [
        { prop = AnimProp.opacity, from = 0, to = 1, duration = 0.2, play = true,
          trigger = OVERLAY_TRIGGER }
        { prop = AnimProp.opacity, from = 1, to = 1, duration = 1.6, play = true, delay = 0.2,
          trigger = OVERLAY_TRIGGER }
        { prop = AnimProp.opacity, from = 1, to = 0, duration = 0.2, play = true, delay = 1.8,
          trigger = OVERLAY_TRIGGER_SKIP, onFinish = @() gainRewardContent(null) }
      ]
    }
  })
}

let missionTitle = @(debriefing) debriefing?.missionName == null ? null : mkAnim({
  rendObj = ROBJ_TEXT
  text = debriefing.missionName
}.__update(fontHeading2, strokeStyle), null, MISSION_NAME_TEXT_DELAY)

let sessionTimeCounter = @(debriefing) {
  margin = [headerMarginTop, 0, 0, 0]
  flow = FLOW_VERTICAL
  hplace = ALIGN_LEFT
  halign = ALIGN_LEFT
  children = [
    mkAnim(grayText({
      text = utf8ToUpper(loc("debriefing/session_time"))
    }), null, SESSION_TIME_TEXT_DELAY)
    mkAnim(grayText({
      text = secondsToTimeSimpleString((debriefing?.result.time ?? 0).tointeger())
    }.__update(fontHeading2)), null, SESSION_TIME_VALUE_DELAY)
  ]
}

let bonusText = @(val) "+{0}%".subst((100 * val).tointeger())
let colon = loc("ui/colon")

function mkSquadsBonusTooltipText(premiumExpMul) {
  let premiumText = "".concat(loc("premium/title"), colon, "+", premiumExpMul*100, "%")
  return "\n\n".join([premiumText], true)
}

function battleExpBonus(debriefing) {
  let totalBonus = debriefing?.premiumExpMul
  if (totalBonus == null)
    return null

  return {
    margin = [headerMarginTop, 0, 0, 0]
    flow = FLOW_VERTICAL
    hplace = ALIGN_RIGHT
    halign = ALIGN_RIGHT

    behavior = Behaviors.Button
    onHover = @(on) setTooltip(
      on ? mkSquadsBonusTooltipText(totalBonus - 1) : null)
    children = [
      mkAnim(grayText({ text = utf8ToUpper(loc("battle_exp_bonus")) }))
      mkAnim(
        {
          flow = FLOW_HORIZONTAL
          children = [
            grayText({ text = bonusText(totalBonus - 1) }.__update(fontHeading2))
            premiumImage(hdpx(35))
          ]
        }
      )
    ]
  }
}

let blockHeader = @(locId) {
  size = [flex(), SIZE_TO_CONTENT]
  rendObj = ROBJ_SOLID
  color = Color(0, 0, 0, 60)
  halign = ALIGN_CENTER
  padding = hdpx(5)
  children = grayText({ text = utf8ToUpper(loc(locId)) }.__update(fontSub))
}

function continueAnimImpl(debriefing) {
  local blockIdx = -1
  local block = null
  foreach (idx, ctor in windowContentQueue) {
    block = ctor(debriefing)
    if (block != null) {
      blockIdx = idx
      break
    }
  }

  if (blockIdx < 0) {
    isWaitAnim(false)
    return
  }

  windowContentQueue = windowContentQueue.slice(blockIdx + 1)
  windowBlocks.append(block)
  windowBlocksVer(windowBlocksVer.value + 1)

  if (windowContentQueue.len() == 0)
    hasAnimFinished = true
}

let continueAnim = debounce(continueAnimImpl, 0.01)

function skipAnim(debriefing) {
  anim_skip(NEW_BLOCK_TRIGGER)
  anim_skip($"{ANIM_TRIGGER}{SKIP_ANIM_POSTFIX}")
  anim_skip(ANIM_TRIGGER)
  anim_skip(OVERLAY_TRIGGER)
  anim_skip_delay(OVERLAY_TRIGGER_SKIP)
  anim_skip("content_anim")

  skippedAnims = skippedAnims.map(@(_) true)

  let prevContent = gainRewardContent.value
  if (prevContent != null)
    gui_scene.setTimeout(0.5, function() { //only to handle bugs when reward window not delete after skip
      if (prevContent != gainRewardContent.value)
        return
      gainRewardContent(null)
      logerr($"Debriefing reward window not removed after skip: key = {prevContent?.key}")
      log("Not removed content: ", prevContent)
    })

  continueAnim(debriefing)
}

let blockStyle = {
  color = panelBgColor
}

local blockIdx = 0
function blockCtr(locId, blockContent, _debriefing, override = blockStyle) {
  if (!blockContent)
    return null

  let key = $"debr_block_{blockIdx++}"
  return {
    size = [flex(), SIZE_TO_CONTENT]
    rendObj = ROBJ_SOLID
    flow = FLOW_VERTICAL
    children = [
      locId != null ? blockHeader(locId) : null
      {
        size = [flex(), SIZE_TO_CONTENT]
        padding = locId != null ? [BLOCK_PADDING, 0, BLOCK_PADDING, 0] : 0
        halign = ALIGN_CENTER
        children = blockContent
      }
    ]

    key = key
    function onAttach() {
      scrollToBlock(key)
    }

    transform = {}
    animations = blockAnimations
  }.__update(override ?? {})
}

function isFinishGrowth(debriefing) {
  let { exp = 0, growthCfg = null } = debriefing.growthProgress
  let { expRequired = 0 } = growthCfg
  return exp + debriefing.armyExp >= expRequired
}


function armyProgressBlock(debriefing) {
  let {
    armyId, armyExp = 0, growthProgress = null, globalData = null, expMode = "",
    result = null, squads = {}, campaignId = "", armyExpDetailed = null, boosts = null
  } = debriefing

  if (expMode == MOD_EXP_MODE)
    return null

  skippedAnims.army <- false
  return {
    size = [BODY_W, SIZE_TO_CONTENT]
    padding = midPadding
    children = mkArmyProgress({
      armyId
      armyAddExp = armyExp
      growthProgress
      campaignId
      result
      squads
      armyExpDetailed
      boosts
      giftsConfig = globalData?.globalGiftsCfg ?? []
      curGifts = globalData?.globalGifts
      onFinish = function() {
        if (!(skippedAnims?.army ?? false))
          continueAnim(debriefing)
      }
    })
    transform = {}
    animations = mkAppearAnimations(FILL_BLOCK_DELAY)
  }
}

function rankBlock(debriefing) {
  let { wasPlayerRank = 0, playerRank = 0 } = debriefing
  if (playerRank == 0 || wasPlayerRank >= playerRank)
    return null

  let { locId } = getRankConfig(playerRank)
  return {
    hplace = ALIGN_CENTER
    halign = ALIGN_CENTER
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    children = [
      {
        rendObj = ROBJ_TEXT
        text = loc(locId)
      }.__update(fontHeading2)
      mkRankImage(playerRank)
    ]
    sound = { attach = "ui/debriefing/battle_result" }
  }
}

function debriefingHeader(debriefing) {
  let { result = null, armyId = null, expMode = "" } = debriefing
  let armyIcon = mkArmyIcon(armyId, hdpx(44))
  let armyProgress = armyProgressBlock(debriefing)
  return {
    size = [flex(), SIZE_TO_CONTENT]
    halign = ALIGN_CENTER
    margin = [headerMarginTop, 0, 0, 0]
    flow = FLOW_VERTICAL
    children = [
      {
        size = [sw(75), SIZE_TO_CONTENT]
        children = [
          {
            flow = FLOW_VERTICAL
            hplace = ALIGN_CENTER
            halign = ALIGN_CENTER
            children = [
              missionTitle(debriefing)
              {
                flow = FLOW_HORIZONTAL
                valign = ALIGN_CENTER
                gap = hdpx(30)
                children = [
                  mkAnim(armyIcon, null, HEADER_ICON_DELAY)
                  mkAnim({
                      size = SIZE_TO_CONTENT
                      rendObj = ROBJ_TEXT
                      text = utf8ToUpper(result?.title ?? "")
                    }.__update(fontHeading2, {fontSize = hdpx(46)}),
                    function() {
                      sound_play("ui/debriefing/{0}".subst(result?.success
                        ? "text_victory"
                        : "text_defeat"
                      ))
                      if (expMode == MOD_EXP_MODE)
                        continueAnim(debriefing)
                    },
                    HEADER_TEXT_DELAY)
                  mkAnim(armyIcon, null, HEADER_ICON_DELAY)
                ]
              }
            ]
          }
          {
            hplace = ALIGN_RIGHT
            children = promoWidget("debriefing_sections", "debriefing_sections")
          }
        ]
      }
      result?.finishedEarly ? dtxt(loc("debriefing/finished_early/desc")) : null
      blockCtr(null, armyProgress, debriefing, {
        key = "headerArmyProgress"
        size = [BODY_W, SIZE_TO_CONTENT]
        color = panelBgColor
        onAttach = @() null
        animations = []
      })
    ]
  }
}

function switchContext(debriefing) {
  let campaign = gameProfile.value?.campaignByArmyId[debriefing.armyId]
  if (campaign == null) /* FIX ME: tutorial does not need debriefing at the end */
    return
  let isCurCampaignUnited = curCampaignConfig.value?.isUnited ?? false
  if (isUnited() != isCurCampaignUnited)
    return
  setCurCampaign(campaign)
  selectArmy(debriefing.armyId)
}


function openNewLevelSoldier() {
  if (newLevelSoldier == null)
    return
  setCurSection(mainSectionId)
  setCurSquadId(newLevelSoldier.squadId)
  curSoldierIdx(newLevelSoldier.soldierIdx)
}

function skipAnimOrClose(doClose, debriefing) {
  if (isWaitAnim.value) {
    usedSkipAnim(true)
    skipAnim(debriefing)
    return
  }
  doClose()
  hasAnimFinished = false
  switchContext(debriefing)
  if (isFinishGrowth(debriefing)) {
    let { growthCfg = null } = debriefing.growthProgress
    jumpToArmyGrowth(growthCfg?.id)
  } else if (newLevelSoldier != null) {
    openNewLevelSoldier()
    newLevelSoldier = null
  }
}

let mkCloseBtn = @(doClose, debriefing) closeBtnBase({
  onClick = @() skipAnimOrClose(doClose, debriefing)
  hotkeys = null
}).__update({ margin = [midPadding, 0] })

let btnCloseStyle = { margin = 0, size = [hdpx(450), hdpx(60)] }
let mkSkipOrCloseBtn = @(doClose, debriefing) function() {
  let doStopAndClose = @() skipAnimOrClose(doClose, debriefing)

  let hotkeysStr = canQuitByEsc.value
    ? $"^{JB.B} | Space | Enter | Esc"
    : "^J:Y | Space | Enter"
  local btnClose
  if (isWaitAnim.value)
    btnClose = Bordered(loc("Skip"), doStopAndClose, btnCloseStyle.__merge({
      size = [SIZE_TO_CONTENT, commonBtnHeight]
      hotkeys = [[$"^{JB.B} | Esc | Space", {description = loc("Skip")}]]
    }))
  else if (isFinishGrowth(debriefing))
    btnClose = PrimaryFlat(loc("finishGrowth"), doStopAndClose, btnCloseStyle.__merge({
      hotkeys = [[hotkeysStr, {description = loc("finishGrowth")}]],
      size = [SIZE_TO_CONTENT, commonBtnHeight]
    }))
  else if (newLevelSoldier != null)
    btnClose = PrimaryFlat(loc("soldiers/levelUp"), doStopAndClose, btnCloseStyle.__merge({
      hotkeys = [[hotkeysStr, {description = loc("soldiers/levelUp")}]],
      size = [SIZE_TO_CONTENT, commonBtnHeight]
    }))
  else
    btnClose = Bordered(loc("Ok"), doStopAndClose, btnCloseStyle.__merge({
      hotkeys = [[hotkeysStr, {description = loc("Ok")}]],
      size = [commonBtnHeight * 10, commonBtnHeight]
    }))

  return {
    watch = [isWaitAnim, canQuitByEsc]
    size = [BODY_W, SIZE_TO_CONTENT]
    vplace = ALIGN_BOTTOM
    hplace = ALIGN_CENTER
    halign = isWaitAnim.value ? ALIGN_RIGHT : ALIGN_CENTER
    gap = hdpx(20)
    flow = FLOW_HORIZONTAL
    children = [
      btnClose
    ]
    animations = [{ prop = AnimProp.opacity, from = 0, to = 1, duration = 2.0, play = true, easing = InOutCubic }]
  }
}

let mkAnimatedAward = @(award, idx, delay, nextAnimCb = null) {
  children = mkAward.make({
    size = [awardIconSize, awardIconSize]
    award = award
    hasAnim = hasAnim
    pauseTooltip = isWaitAnim
    countDelay = delay + idx * AWARD_DELAY
  })
  transform = {}
  animations = mkAppearAnimations(delay + idx * AWARD_DELAY,
    function() {
      sound_play("ui/debriefing/battle_result")
      nextAnimCb?()
    })
}

let awardsWrapParams = {
  width = BODY_W * 0.75
  hGap = midPadding * 4
  vGap = midPadding * 2
  halign = ALIGN_CENTER
}

function mkAwardsContent(topAwards, awards, nextAnimCb, delay = 0) {
  let nextDelay = delay + topAwards.len() * AWARD_DELAY
  return {
    flow = FLOW_VERTICAL
    gap = midPadding
    children = [
      wrap(topAwards.map(@(award, idx)
        mkAnimatedAward(award, idx, delay)), awardsWrapParams)
      wrap(awards.map(@(award, idx)
        mkAnimatedAward(award, idx, nextDelay, idx == awards.len() - 1 ? nextAnimCb : null)),
          awardsWrapParams)
    ]
  }
}

function tasksBlock(debriefing) {
  let { dailyTasksProgress = [] } = debriefing
  if (dailyTasksProgress.len() == 0)
    return null

  skippedAnims.tasks <- false
  return blockCtr("debriefing/tasks_results",
    mkTasksProgress(dailyTasksProgress,
      mkAppearAnimations,
      function() {
        if (!(skippedAnims?.tasks ?? false))
          continueAnim(debriefing)
      }),
    debriefing)
}

function heroesBlock(debriefing) {
  let { heroes = [], armyExp = 0, localPlayerGroupMembers = {} } = debriefing
  if (heroes.len() == 0)
    return null

  skippedAnims.heroes <- false
  let content = mkBattleHeroesBlock(heroes, armyExp > 0, localPlayerGroupMembers).__update({
    animations = mkAppearAnimations(FILL_BLOCK_DELAY, function() {
      sound_play("ui/debriefing/battle_result")
      gui_scene.setTimeout(0.5, @() continueAnim(debriefing))
    })
  })
  return blockCtr("debriefing/heroes", content, debriefing)
}

function awardsBlock(debriefing) {
  local { awards = [], battleHeroAwards = [] } = debriefing
  awards = awards.filter(@(w) w.value > 0 && mkAward.awardsCfg?[w.id])

  let topAwards = battleHeroAwards
    .map(@(a) {id=a.award})
    .sort(@(a,b) awardPriority[b.id] <=> awardPriority[a.id])

  if (topAwards.len() == 0 && awards.len() == 0)
    return null

  skippedAnims.awards <- false

  let maxRows = topAwards.len() == 0 ? maxAwardsRows : maxAwardsRows - 1
  let awardsContent = mkAwardsContent(topAwards,
    awards.slice(0, maxRows * awardsInRow),
    function() {
      if (!(skippedAnims?.awards ?? false))
        continueAnim(debriefing)
    },
    AWARD_DELAY)

  let content = {
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    children = [
      rankBlock(debriefing)
      awardsContent
    ]
  }

  return blockCtr("debriefing/personal_results", content, debriefing)
}

function mkSoldierTooltipText(stats, result) {
  let textList = soldierStatsCfg.map(function(s) {
    local value = s?.defaultValue ?? 0
    foreach (stat in s?.stats ?? [s.stat])
      value += stats?[stat] ?? s?.defaultValue ?? 0

    return (s?.isVisible(value) ?? true)
      ? "".concat(loc(s.locId), colon, s.toString(value))
      : ""
  })
  let expText = mkSoldierExpTooltipText(stats, result)
  if (expText != null)
    textList.append(expText)
  return "\n".join(textList, true)
}

let collectSoldierAwards = @(guid, awards)
  awards.filter(@(award) isSoldierAward(award.award) && award.soldier.guid == guid).map(@(a) a.award)

let collectSquadAwards = @(squadId, awards)
  awards.filter(@(award) (isSoldierAward(award.award) || isTopSquadAward(award.award)) && award.soldier.squadId == squadId)

function checkNewLevelSoldier(soldierStat, soldierData, soldierIdx) {
  if (soldierStat == null || soldierData == null)
    return

  let { squadId, maxLevel = 1 } = soldierData
  let wasLevel = min(soldierStat?.wasExp.level ?? 0, maxLevel)
  let newLevel = min(soldierStat?.newExp.level ?? 0, maxLevel)
  if (newLevel > wasLevel)
    newLevelSoldier = {
      squadId
      soldierIdx
    }
}

function squadsAndSoldiersExpBlock(debriefing) {
  let {
    squads = {}, isBattleHero = false, battleHeroSoldier = null,
    armyId = null, result = null
  } = debriefing
  if (squads.len() == 0)
    return null

  local soldiers = debriefing?.soldiers.stats ?? {}
  if (soldiers.len() == 0)
    return null

  soldiers = soldiers.map(@(s, id) s.__merge({ soldierId = id }))
    .values()
    .sort(@(a, b) (b?.exp ?? 0) <=> (a?.exp ?? 0) || (b?.kills ?? 0) <=> (a?.kills ?? 0))

  skippedAnims.squads <- false
  local animDelay = 0
  local idx = 0
  let squadAndSoldierRow = []
  foreach (squadId, squad in squads) {
    let children = []
    let squadSoldiersAwards = collectSquadAwards(squadId, debriefing?.battleHeroAwards ?? [])
    local squadAwards = squadSoldiersAwards.map(@(a) a.award)
    if (isBattleHero)
      squadAwards = [BattleHeroesAward.PLAYER_BATTLE_HERO].extend(squadAwards)

    let squadCard = mkSquadProgress({
      squadId
      squad
      awards = squadAwards
      animDelay
      armyId
      result
      mkAppearAnimations
      onFinishCb = idx < squads.len() - 1 ? null : function() {
          if (!(skippedAnims?.squads ?? false))
            continueAnim(debriefing)
        }
    })
    children.append(squadCard.content)

    local soldierAnimDelay = 0
    foreach (soldierIdx, soldierStat in soldiers) {
      let soldierData = debriefing?.soldiers.items[soldierStat.soldierId]
      if (!soldierData)
        continue
      if (squads?[soldierData.squadId] != squad)
        continue

      if (newLevelSoldier == null)
        checkNewLevelSoldier(soldierStat, soldierData, soldierIdx)

      let soldierAwards = collectSoldierAwards(soldierData.guid, squadSoldiersAwards)
      if (battleHeroSoldier != null && battleHeroSoldier == soldierData.guid)
        soldierAwards.append(BattleHeroesAward.BATTLE_HEROES_CARD)

      let soldierCard = mkSoldierCard({
        stat = soldierStat
        awards = soldierAwards
        info = collectSoldierPhoto(soldierData, null)
        animDelay = animDelay + soldierAnimDelay
        mkAppearAnimations = mkAppearAnimations
      })
      if (!soldierCard)
        continue
      soldierAnimDelay += 0.1
      let stats = soldierStat
      children.append(soldierCard.content.__update({
          behavior = Behaviors.Button
          onHover = @(on) setTooltip(on ? mkSoldierTooltipText(stats, debriefing?.result ?? {}) : null)
        }))
    }
    animDelay += squadCard.duration
    idx++
    squadAndSoldierRow.append(children)
  }

  let content = [
    {
      flow = FLOW_VERTICAL
      size = SIZE_TO_CONTENT
      onAttach = @() gui_scene.setTimeout(0.1, function() {
        sound_play("ui/debriefing/squad_progression_appear")
      })
      children = squadAndSoldierRow.map(@(v) function(){
        return {
          children = v
          width = BODY_W * 0.95
          halign = ALIGN_CENTER
          flow = FLOW_HORIZONTAL
          margin = [hdpx(10), hdpx(10)]
          padding = [hdpx(10), hdpx(10)]
          size = SIZE_TO_CONTENT
        }
      })
    }
  ]

  return blockCtr("debriefing/squads_soldiers_progression", content, debriefing)
}

function statisticBlock(debriefing) {
  if ((debriefing?.players ?? {}).len() == 0)
    return null

  skippedAnims.statistic <- false
  gui_scene.setTimeout(0.5, function() {
    if (!(skippedAnims?.statistic ?? false))
      continueAnim(debriefing)
  })
  let {
    myTeam,
    teams,
    localPlayerEid,
    localPlayerGroupId = INVALID_GROUP_ID,
    localPlayerGroupMembers = {},
    missionType = null,
    result
  } = debriefing

  let params = {
    teams
    myTeam
    localPlayerEid
    localPlayerGroupMembers
    localPlayerGroupId
    width = BODY_W
    sessionId = debriefing?.sessionId ?? INVALID_SESSION_ID
    isInteractive = true
    showProfileCb = showUserProfile.value ? showAnoProfile : null
    missionType
    result
    mkContextMenuButton = @(_) userActions
    scorePrices = debriefing?.scorePrices ?? {}
  }

  return blockCtr(null, mkScoresStatistics(debriefing.players, params), debriefing, { color = 0 })
}

let windowContent = mkAnim({
  size = [BODY_W, flex()]
  hplace = ALIGN_CENTER

  children = scrollbar.makeVertScroll(@() {
    watch = windowBlocksVer
    size = [flex(), SIZE_TO_CONTENT]
    minHeight = ph(100)
    flow = FLOW_VERTICAL
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    gap = BLOCKS_GAP
    children = windowBlocks
  },
  {
    scrollHandler = scrollHandler
    size = flex()
    needReservePlace = false
  })
}).__merge({ size = flex() })

let mkSessionIdText = @(debriefing) (debriefing?.sessionId ?? INVALID_SESSION_ID) == INVALID_SESSION_ID ? null : {
  text = debriefing.sessionId
  vplace = ALIGN_BOTTOM
  hplace = ALIGN_LEFT
  rendObj = ROBJ_TEXT
  color = Color(120,120,120, 50)
}.__update(fontSub)

let debriefingAutosavePath = "".concat(get_log_directory() ?? "", "debriefing_enlisted.json")
let canDebugDebriefing = hasClientPermission("debug_debriefing")

function autosaveDebriefing(debriefing){
  if (!(get_setting_by_blk_path("debug/enableDebriefingDump") ?? true))
    return

  else if (is_pc && !isProductionCircuit.value)
    saveDebriefingToFile(debriefing, debriefingAutosavePath)

  else if ((!is_pc && DBGLEVEL > 0) || (is_pc && isProductionCircuit.value && canDebugDebriefing.value))
    saveDebriefingToLog(debriefing)
}

local curDebriefingSessionId = null
function initDebriefingAnim(debriefing) {
  let { sessionId = -1 } = debriefing
  if (sessionId == curDebriefingSessionId)
    return
  curDebriefingSessionId = sessionId

  skippedAnims = {}
  hasAnim = true

  windowBlocks.clear() //no need inc version here
  windowContentQueue = [
    heroesBlock
    awardsBlock
    tasksBlock
    squadsAndSoldiersExpBlock
    statisticBlock
  ]
}

function debriefingRoot(debriefing, doClose) {
  function autosaveAndClose() {
    autosaveDebriefing(debriefing)
    doClose()
  }
  let armyId = debriefing?.armyId
  let squads = debriefing?.squads ?? []
  foreach (squadId, squad in squads)
    squad.__update(squadsPresentation?[armyId][squadId] ?? {})

  initDebriefingAnim(debriefing)

  if (hasAnimFinished) {
    foreach (ctor in windowContentQueue) {
      let block = ctor(debriefing)
      if (block != null)
        windowBlocks.append(block)
    }
    windowContentQueue = []
    gui_scene.resetTimeout(0.05, @() skipAnim(debriefing))
  }

  return @() {
    key = debriefing?.sessionId
    size = [sw(100), sh(100)]
    rendObj = ROBJ_WORLD_BLUR_PANEL
    cursor = normal
    stopMouse = true
    behavior = Behaviors.ActivateActionSet
    actionSet = "StopInput"
    watch = safeAreaBorders
    stopHotkeys = true
    children = [
      {
        size = flex()
        flow = FLOW_VERTICAL
        gap = BLOCKS_GAP
        padding = safeAreaBorders.value
        children = [
          {
            size = [flex(), SIZE_TO_CONTENT]
            children = [
              debriefingHeader(debriefing)
              sessionTimeCounter(debriefing)
              battleExpBonus(debriefing)
              mkCloseBtn(autosaveAndClose, debriefing)
            ]
          }
          windowContent
          {
            size = [flex(), SIZE_TO_CONTENT]
            children = [
              mkSkipOrCloseBtn(autosaveAndClose, debriefing)
              mkSessionIdText(debriefing)
            ]
          }
        ]
      }
      overGainRewardBlock
    ]

    onAttach = @() isWaitAnim(true)
    function onDetach() { curDebriefingSessionId = null }

    transform = {pivot = [0.5, 0.25]}
    animations = [
      { prop=AnimProp.opacity, from=0, to=1 duration=0.8, play=true, easing=InOutCubic}
      { prop=AnimProp.scale, from=[2,2], to=[1,1], duration=0.5, play=true, easing=InOutCubic}
      { prop=AnimProp.opacity, from=1, to=0 duration=0.8, playFadeOut=true, easing=InOutCubic}
      { prop=AnimProp.scale, from=[1,1], to=[2,2], duration=0.5, playFadeOut=true, easing=InOutCubic}
    ]

    sound = {
      attach = "ui/menu_highlight"
      detach = "ui/menu_highlight"
    }
  }
}

return debriefingRoot
