from "%enlSqGlob/ui/ui_library.nut" import *

let { fontBody, fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let { defTxtColor, activeTxtColor, titleTxtColor, smallPadding, accentColor, mkTimerIcon,
  transpBgColor, defItemBlur } = require("%enlSqGlob/ui/designConst.nut")
let { taskMinHeight, taskSlotPadding } = require("%enlSqGlob/ui/tasksPkg.nut")
let { rewardWidthToHeight } = require("%enlist/items/itemsPresentation.nut")
let { secondsToHoursLoc } = require("%ui/helpers/time.nut")
let { txt } = require("%enlSqGlob/ui/defcomps.nut")
let tooltipBox = require("%ui/style/tooltipBox.nut")


let defCardSize = [hdpx(170), hdpx(210)]
let taskRewardSize = taskMinHeight - 2 * taskSlotPadding[0]
let timerSize = hdpxi(13)
let accentTxtStyle = { color = accentColor }.__update(fontSub)
let rewardIconWidth = hdpxi(42)

function prepareRewards(rewards, itemsMappingVal) {
  let list = []
  foreach (key, count in rewards)
    if (count.tointeger() > 0) {
      let reward = itemsMappingVal?[key.tostring()]
      let { itemCount = 1 } = reward
      if (reward != null)
        list.append({ reward, count = count * itemCount })
    }
  return list
}

// find most valuable reward that have presentation data
let getOneReward = @(rewards, itemsMappingVal) prepareRewards(rewards, itemsMappingVal)?[0]

function mkRewardIcon(reward, size = hdpx(30), override = {}) {
  let { icon = null } = reward
  if (icon == null)
    return null

  return {
    rendObj = ROBJ_IMAGE
    size = [size, size]
    image = Picture("{0}:{1}:{1}:K".subst(icon, size.tointeger()))
    keepAspect = KEEP_ASPECT_FIT
  }.__update(override)
}

function mkRewardImages(reward, sizeBg = defCardSize, override = {}, hasStageCompleted = false) {
  let { cardImage = null, cardImageParams = @(_) {}, bgImage = null, cardImageOpen = null,
    mkImage = null } = reward
  if (cardImage == null && mkImage == null)
    return null

  let curImage = hasStageCompleted && cardImageOpen ? cardImageOpen : cardImage
  return {
    size = sizeBg
    children = [
      bgImage == null ? null : {
        rendObj = ROBJ_IMAGE
        size = sizeBg
        image = Picture(bgImage)
      }
      mkImage != null
        ? mkImage?(sizeBg, curImage)
        : {
            rendObj = ROBJ_IMAGE
            image = Picture(curImage)
          }.__update(cardImageParams?(sizeBg) ?? {})
    ]
  }.__update(override)
}

function mkRewardText(reward, pxSize,  override = {}){
  let { cardText = null} = reward
  if (cardText == null)
    return null
  return {
    rendObj = ROBJ_BOX
    borderWidth = hdpx(1)
    children = {
      rendObj = ROBJ_TEXT
      fontSize = pxSize
      hplace = ALIGN_CENTER
      vplace = ALIGN_CENTER
      text = cardText
    }
  }.__update(override)
}

let mkSeasonTime = @(timeLeft, override = {}) {
  rendObj = ROBJ_WORLD_BLUR_PANEL
  fillColor = transpBgColor
  color = defItemBlur
  padding = taskSlotPadding
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  gap = smallPadding
  children = [
    mkTimerIcon(timerSize, { color = accentColor })
    {
      rendObj = ROBJ_TEXT
      text = secondsToHoursLoc(timeLeft)
    }.__update(accentTxtStyle, override)
  ]
}

function mkRewardTooltip(presentation) {
  let children = []
  if ("name" in presentation)
    children.append({
      rendObj = ROBJ_TEXT
      text = presentation.name
      color = activeTxtColor
    }.__update(fontBody))
  if ("description" in presentation)
    children.append({
      rendObj = ROBJ_TEXTAREA
      behavior = Behaviors.TextArea
      maxWidth = hdpx(500)
      text = presentation.description
      color = defTxtColor
    }.__update(fontSub))

  return children.len() == 0 ? null : tooltipBox({ flow = FLOW_VERTICAL, children })
}

function mkRewardBlock(rewardData, isFinished = false) {
  let { reward = null, count = 1 } = rewardData
  return {
    children = [
      mkRewardIcon(reward, taskRewardSize, isFinished ? { opacity = 0.5 } : {})
      count == 1 ? null
        : txt({
            text = $"x{count}"
            margin = [0, smallPadding]
            hplace = ALIGN_RIGHT
            vplace = ALIGN_BOTTOM
            color = titleTxtColor
            fontFx = FFT_GLOW
            fontFxColor = 0xCC000000
            fontFxFactor = hdpx(32)
          }).__update(fontSub)
    ]
  }
}

return {
  getOneReward
  mkRewardIcon
  mkSeasonTime
  mkRewardBlock
  prepareRewards
  mkRewardImages
  mkRewardText
  rewardWidthToHeight
  mkRewardTooltip
  defCardSize
  rewardIconWidth
}
