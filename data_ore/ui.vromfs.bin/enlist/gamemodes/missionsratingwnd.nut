from "%enlSqGlob/ui/ui_library.nut" import *
from "createEventRoomState.nut" import *

let getMissionInfo = require("getMissionInfo.nut")
let faComp = require("%ui/components/faComp.nut")
let JB = require("%ui/control/gui_buttons.nut")

let { Bordered } = require("%ui/components/textButton.nut")
let { fontSub, fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let { addModalWindow, removeModalWindow } = require("%ui/components/modalWindows.nut")
let { makeVertScroll, thinStyle } = require("%ui/components/scrollbar.nut")
let { MissionType, typeToLocId, missionTypes } = require("%enlSqGlob/ui/missionsPresentation.nut")
let {
  isMissionsRatingOpened, callRate, missionRatesData, RatesStatus, getMissionRate, missionRatesCfg
} = require("missionsRatingState.nut")
let {
  bigPadding, midPadding, smallPadding, transpBgColor, defItemBlur, activeTxtColor,
  defTxtColor, darkTxtColor, attentionTxtColor, panelBgColor, modsBgColor,
  squadSlotBgIdleColor, squadSlotBgHoverColor, squadSlotBgActiveColor,
  negativeTxtColor, positiveTxtColor
} = require("%enlSqGlob/ui/designConst.nut")


let WND_UID = "MISSIONS_RATING_WNG"


let columns = 4
let contentWidth = sw(60)
let blockWidth = ((contentWidth - (columns - 1) * bigPadding) / columns).tointeger()

let missionBlockSize = [blockWidth, (blockWidth * 0.75).tointeger()]
let missionTypeBlockWidth = sw(20)


let selectedFront = Watched(0)
let selectedMissionType = Watched(MissionType.INVASION)


let mkTextArea = @(text, override = {}) {
  rendObj = ROBJ_TEXTAREA
  size = [flex(), SIZE_TO_CONTENT]
  behavior = Behaviors.TextArea
  color = activeTxtColor
  text = text
}.__update(fontSub, override)

let mkText = @(text, override = {}) {
  rendObj = ROBJ_TEXT
  color = attentionTxtColor
  text
}.__update(fontSub, override)


let function mkLikeBtn(onClick, btnType, isSelected) {
  let faName = btnType == RatesStatus.LIKE ? "thumbs-up"
    : btnType == RatesStatus.DISLIKE ? "thumbs-down"
    : "ban"
  let selectedColor = btnType == RatesStatus.LIKE ? positiveTxtColor : negativeTxtColor
  return watchElemState(function(sf) {
    let color = isSelected ? selectedColor
      : sf & S_HOVER ? activeTxtColor
      : defTxtColor
    return {
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      behavior = Behaviors.Button
      onClick
      children = [
        {
          size = [hdpx(32), hdpx(32)]
          rendObj = ROBJ_VECTOR_CANVAS
          commands = [
            [ VECTOR_WIDTH, hdpx(2) ],
            [ VECTOR_COLOR, color ],
            [ VECTOR_ELLIPSE, 50, 50, 50, 50 ]
          ]
          fillColor = modsBgColor
        }
        faComp(faName, { fontSize = hdpxi(18), color })
      ]
    }
  })
}


let mkRateCb = @(id, rateIdx, rate, likeCount) function() {
  let { rates = {}, limits = {} } = likeCount.value
  if (rate.value != rateIdx && (rates?[rateIdx] ?? 0) >= (limits?[rateIdx] ?? 0))
    return

  callRate(id, rate.value == rateIdx ? RatesStatus.UNDEFINED : rateIdx)
}

let function mkMission(mission, likeCount, valToString, typeToString) {
  let { id, image } = mission
  let resampledImage = $"{image}:{missionBlockSize[0]}:{missionBlockSize[1]}:K"
  let missionRate = Computed(@() getMissionRate(missionRatesData.value, id))
  let onLikeCb = mkRateCb(id, RatesStatus.LIKE, missionRate, likeCount)
  let onDislikeCb = mkRateCb(id, RatesStatus.DISLIKE, missionRate, likeCount)

  return watchElemState(function(sf) {
    let rate = missionRate.value
    let buttons = {
        flow = FLOW_HORIZONTAL
        gap = midPadding
        padding = midPadding
        children = sf & S_HOVER
            ? [
                mkLikeBtn(onLikeCb, RatesStatus.LIKE, rate == RatesStatus.LIKE)
                mkLikeBtn(onDislikeCb, RatesStatus.DISLIKE, rate == RatesStatus.DISLIKE)
              ]
          : rate != RatesStatus.UNDEFINED ? mkLikeBtn(null, rate, true)
          : null
      }

    return {
      watch = missionRate
      size = missionBlockSize
      behavior = Behaviors.Button
      children = [
        {
          rendObj = ROBJ_IMAGE
          size = missionBlockSize
          image = Picture(resampledImage)
          keepAspect = KEEP_ASPECT_FILL
        }
        {
          size = [flex(), SIZE_TO_CONTENT]
          flow = FLOW_VERTICAL
          padding = midPadding
          vplace = ALIGN_BOTTOM
          rendObj = ROBJ_SOLID
          color = panelBgColor
          children = [
            mkTextArea(valToString(id))
            mkText(typeToString(id))
            mkText(id)
          ]
        }
        buttons
      ]
    }
  })
}


let function mkFront(cfg, idx) {
  let isSelected = Computed(@() selectedFront.value == idx)
  return watchElemState(@(sf) {
    watch = isSelected
    size = [missionTypeBlockWidth, SIZE_TO_CONTENT]
    padding = midPadding
    rendObj = ROBJ_SOLID
    color = isSelected.value ? squadSlotBgActiveColor
      : sf & S_HOVER ? squadSlotBgHoverColor
      : squadSlotBgIdleColor
    behavior = Behaviors.Button
    onClick = @() selectedFront(idx)
    children = mkText(loc(cfg.locId), {
      color = isSelected.value ? activeTxtColor
        : sf & S_HOVER ? darkTxtColor
        : defTxtColor
    }.__update(fontBody))
  })
}

let function mkMissionType(missionType) {
  let isSelected = Computed(@() selectedMissionType.value == missionType)
  return watchElemState(@(sf) {
    watch = isSelected
    size = [missionTypeBlockWidth, SIZE_TO_CONTENT]
    padding = midPadding
    rendObj = ROBJ_SOLID
    color = isSelected.value ? squadSlotBgActiveColor
      : sf & S_HOVER ? squadSlotBgHoverColor
      : squadSlotBgIdleColor
    behavior = Behaviors.Button
    onClick = @() selectedMissionType(missionType)
    children = mkText(loc(typeToLocId[missionType]), {
      color = isSelected.value ? activeTxtColor
        : sf & S_HOVER ? darkTxtColor
        : defTxtColor
    }.__update(fontBody))
  })
}


let mkLimitsBlockUi = @(likeCount) @() {
  watch = likeCount
  flow = FLOW_HORIZONTAL
  gap = bigPadding
  children = [RatesStatus.LIKE, RatesStatus.DISLIKE]
    .map(function(rate) {
      let curValue = likeCount.value?.rates[rate] ?? 0
      let maxValue = likeCount.value?.limits[rate] ?? 0
      return {
        flow = FLOW_HORIZONTAL
        gap = smallPadding
        valign = ALIGN_CENTER
        children = [
          mkLikeBtn(null, rate, true)
          mkText($"{curValue}/{maxValue}", {
            color = curValue < maxValue ? defTxtColor : negativeTxtColor
          })
        ]
      }
    })
}


let mkFilterBlockUi = @(likeCount) {
  flow = FLOW_VERTICAL
  gap = hdpx(70)
  children = [
    {
      flow = FLOW_VERTICAL
      gap = hdpx(40)
      children = [
        mkLimitsBlockUi(likeCount)
        {
          flow = FLOW_VERTICAL
          gap = midPadding
          children = missionRatesCfg.map(mkFront)
        }
      ]
    }
    {
      flow = FLOW_VERTICAL
      gap = midPadding
      children = missionTypes.map(mkMissionType)
    }
    Bordered(loc("BackBtn"), @() isMissionsRatingOpened(false), {
      margin = 0
      hotkeys = [[$"^{JB.B} | Esc", { description = { skip = true }}]]
    })
  ]
}


let wrapParams = {
  width = contentWidth
  hGap = bigPadding
  vGap = bigPadding
}

let scrollParams = {
  size = [SIZE_TO_CONTENT, sh(70)]
  styling = thinStyle
  rootBase = {
    key = "battlepassUnlocksRoot"
    behavior = Behaviors.Pannable
    wheelStep = 1
  }
}

let function open() {
  let { cfg, valToString = @(v) v, typeToString = @(v) v } = optMissions
  let missions = Computed(function() {
    let { campaigns = [] } = missionRatesCfg[selectedFront.value]
    return cfg.value.values
      .filter(@(blk) campaigns.contains(getMissionInfo(blk).campaign))
      .map(function(blk) {
        let missionData = getMissionInfo(blk)
        let missionType = missionData.type
        let { id, image, campaign } = missionData
        return { id, image, campaign, missionType }
      })
  })

  let missionsByType = Computed(function() {
    let selectedType = selectedMissionType.value
    return missions.value.filter(@(mission) mission.missionType == selectedType)
  })

  let likeCount = Computed(function() {
    let missionsById = {}
    foreach (mission in missions.value)
      missionsById[mission.id] <- true

    let rates = {}
    foreach (id, rate in missionRatesData.value)
      if (id in missionsById)
        rates[rate] <- (rates?[rate] ?? 0) + 1

    let { limits = {} } = missionRatesCfg[selectedFront.value]

    return { rates, limits }
  })

  return addModalWindow({
    key = WND_UID
    size = flex()
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    rendObj = ROBJ_WORLD_BLUR_PANEL
    fillColor = transpBgColor
    color = defItemBlur
    children = {
      flow = FLOW_HORIZONTAL
      gap = bigPadding
      children = [
        mkFilterBlockUi(likeCount)
        @() {
          watch = [missionsByType, likeCount]
          children = makeVertScroll({
            children = wrap(missionsByType.value.map(@(mission)
              mkMission(mission, likeCount, valToString, typeToString)), wrapParams)
          }, scrollParams)
        }
      ]
    }
    onClick = @() null
  })
}


if (isMissionsRatingOpened.value)
  open()

isMissionsRatingOpened.subscribe(@(v) v ? open() : removeModalWindow(WND_UID))
