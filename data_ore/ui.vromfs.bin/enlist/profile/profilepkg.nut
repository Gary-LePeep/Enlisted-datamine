from "%enlSqGlob/ui/ui_library.nut" import *

let JB = require("%ui/control/gui_buttons.nut")
let { Bordered } = require("%ui/components/textButton.nut")
let { activeBgColor, blurBgFillColor, disabledTxtColor, bigPadding, smallPadding,
  smallOffset, activeTxtColor, rowBg
} = require("%enlSqGlob/ui/viewConst.nut")
let { fontSub, fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let { armies } = require("%enlist/soldiers/model/state.nut")
let { gameProfile } = require("%enlist/soldiers/model/config/gameProfile.nut")
let { playerStatsList, killsList } = require("profileState.nut")
let { mkArmyIcon } = require("%enlist/soldiers/components/armyPackage.nut")
let { darkTxtColor, defTxtColor, hoverSlotBgColor } = require("%enlSqGlob/ui/designConst.nut")
let { getCampaignTitle } = require("%enlSqGlob/ui/itemsInfo.nut")


const COMMON_CAMPAIGN = "common"

let PROFILE_WIDTH = fsh(100)

let DEFAULT_FOOTER_PARAMS = {
  size = [ flex(), SIZE_TO_CONTENT ]
  flow = FLOW_HORIZONTAL
}

const MAIN_GAME_STAT = "main_game"

let headerHeight = hdpxi(50)
let armyIconSize = hdpxi(28)

let selectedCampaign = Watched(null)

let txtColor = @(sf, isSelected = false) isSelected
  ? Color(255,255,255)
  : sf & S_HOVER ? darkTxtColor : defTxtColor

let bgColor = @(sf, isSelected = false) isSelected
  ? Color(160,160,160)
  : sf & S_HOVER ? hoverSlotBgColor : blurBgFillColor

let borderColor = @(sf, isSelected = false) isSelected
  ? activeBgColor
  : sf & S_HOVER ? activeBgColor : disabledTxtColor

let mkFooterWithButtons = @(buttonsList, params = DEFAULT_FOOTER_PARAMS) {
  children = buttonsList
}.__merge(params)

let mkFooterWithBackButton = @(onClick, params = DEFAULT_FOOTER_PARAMS)
  mkFooterWithButtons([
    Bordered(loc("BackBtn"), onClick, {
      margin = 0
      hotkeys = [[$"^{JB.B} | Esc", { description = loc("BackBtn") } ]]
    })
  ], params)

let mkText = @(text, customStyle = {}) {
  rendObj = ROBJ_TEXT
  color = activeTxtColor
  text
}.__update(fontSub, customStyle)

let campaignSlotStyle = {
  rendObj = ROBJ_BOX
  size = [flex(), hdpx(50)]
  behavior = Behaviors.Button
  sound = {
    hover = "ui/enlist/button_highlight"
    click = "ui/enlist/button_click"
    active = "ui/enlist/button_action"
  }
  borderColor = Color(255,255,255)
}

let statValueStyle = {
  size = [flex(), SIZE_TO_CONTENT]
  halign = ALIGN_RIGHT
}

let statNameStyle = {
  size = [pw(55), SIZE_TO_CONTENT]
}

function mkCampaignInfoBtn(campaign) {
  let isSelected = Computed(@() selectedCampaign.value == campaign?.id)
  return watchElemState(function(sf) {
    let isSelectedVal = isSelected.value
    return {
      watch = isSelected
      onClick = isSelectedVal ? null : @() selectedCampaign(campaign.id)
      padding = [0, smallOffset]
      valign = ALIGN_CENTER
      fillColor = bgColor(sf, isSelectedVal)
      borderWidth = isSelectedVal ? [0, 0, hdpx(4), 0] : 0
      children = mkText(getCampaignTitle(campaign.id), fontBody.__merge({
        color = txtColor(sf, isSelectedVal)
      }))
    }.__update(campaignSlotStyle)
  })
}

function mkAllCampaignBtn() {
  let isSelected = Computed(@() selectedCampaign.value == null)
  return watchElemState(function(sf) {
    let isSelectedVal = isSelected.value
    return {
      watch = isSelected
      onClick = @() selectedCampaign(null)
      padding = [0, smallOffset]
      valign = ALIGN_CENTER
      fillColor = bgColor(sf, isSelectedVal)
      borderWidth = isSelectedVal ? [0, 0, hdpx(4), 0] : 0
      children = mkText(loc("menu/campaigns"), fontBody.__merge({
        color = txtColor(sf, isSelectedVal)
      }))
    }.__update(campaignSlotStyle)
  })
}

let mkMapsListUi = @(campListWatch) function() {
  let campCfg = gameProfile.value?.campaigns
  local campList = []
  local campCommon = null
  foreach(comp in campListWatch.value)
    if (comp != COMMON_CAMPAIGN)
      campList.append(comp)
    else
      campCommon = comp
  let campaignCfgCommon = campCfg?[campCommon]
  return {
    watch = [campListWatch, gameProfile]
    size = [pw(28), flex()]
    flow = FLOW_VERTICAL
    gap = bigPadding
    padding = [headerHeight,0,0,0]
    children = [
      mkAllCampaignBtn()
      campaignCfgCommon ? mkCampaignInfoBtn(campaignCfgCommon) : null
      campList.len() == 0 ? null
        : mkText(loc("oldCampaigns"), {margin = [bigPadding, 0, 0, 0]})
    ]
      .extend(campList.map(function(campaignId) {
        let campaignCfg = campCfg?[campaignId]
        if (campaignCfg == null)
          return null
        return mkCampaignInfoBtn(campaignCfg)
      }))
  }
}

let mkStats = @(baseStats) {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  children = baseStats.map(@(s, idx) {
    rendObj = ROBJ_SOLID
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    padding = [smallPadding, smallOffset]
    color = rowBg(0, idx)
    children = [
      mkText(loc($"debriefing/awards/{s.statId}"), statNameStyle)
    ].extend(s.statVal.map(@(v) mkText(v, statValueStyle)))
  })
}

let mkStatsHeader = @(armiesList) @() {
  watch = armies
  size = [flex(), headerHeight]
  flow = FLOW_HORIZONTAL
  padding = [0, smallOffset]
  valign = ALIGN_CENTER
  children = [ mkText(loc("debriefing/tab/statistic"), fontBody.__merge(statNameStyle))
  ]
    .extend(armiesList
      .filter(@(armyId) armyId != MAIN_GAME_STAT)
      .map(@(armyId) {
        size = [flex(), SIZE_TO_CONTENT]
        valign = ALIGN_CENTER
        halign = ALIGN_RIGHT
        children = mkArmyIcon(armyId, armyIconSize, { margin = 0} )
      }))
}

function mkPlayerStatistics(statsWatch) {
  let playerCardStats = Computed(function() {
    let campaignsCfg = gameProfile.value?.campaigns
    let selCampaign = selectedCampaign.value
    let selCampaignCfg = campaignsCfg?[selCampaign]

    let armiesList = (selCampaignCfg?.armies ?? []).map(@(a) a.id).sort()
    if (armiesList.len() == 0)
      armiesList.append(MAIN_GAME_STAT)

    let globalStats = statsWatch.value?.stats["global"] ?? {}
    let stats = armiesList.map(@(armyId) globalStats?[armyId] ?? {})
    let res = {
      campaignTitle = getCampaignTitle(selCampaign)
      armiesList
      baseStats = playerStatsList.map(@(statData) {
        statId = statData.statId
        statVal = stats.map(@(stat)
          statData.calculator(stat) + (statData?.unitSign ?? "")
        )
      })
      killsData = killsList.map(@(statId) {
        statId
        statVal = stats.map(@(stat) stat?[statId] ?? 0)
      })
    }

    return res
  })

  return function() {
    let { baseStats, killsData, armiesList } = playerCardStats.value
    return {
      watch = playerCardStats
      size = flex()
      flow = FLOW_VERTICAL
      children = [
        mkStatsHeader(armiesList)
        mkStats(baseStats)
        { size = [0, smallOffset] }
        mkStats(killsData)
      ]
    }
  }
}

return {
  mkFooterWithBackButton
  mkFooterWithButtons
  txtColor
  bgColor
  borderColor
  mkPlayerStatistics
  mkMapsListUi

  PROFILE_WIDTH
}
