from "%enlSqGlob/ui/ui_library.nut" import *

let tooltipBox = require("%ui/style/tooltipBox.nut")
let { MEDAL_SIZE } = require("medalsPresentation.nut")


let mkImage = @(path, override = {}) {
  rendObj = ROBJ_IMAGE
  size = flex()
  image = Picture(path)
}.__update(override)

function mkStackImage(imgData, override = {}) {
  let { img, params = {} } = imgData
  return mkImage(img, params.__update(override))
}

let mkMedalCard = @(bgImage, stackImages, mSize = hdpx(MEDAL_SIZE)) {
  size = [mSize, mSize]
  children = (bgImage == null ? [] : [mkImage(bgImage)]) // -unwanted-modification
    .extend(stackImages.map(@(imgData) mkStackImage(imgData)))
}

function mkDisabledMedalCard(bgImage, stackImages, mSize = hdpx(MEDAL_SIZE)) {
  let imgStyle = {
    picSaturate = 0
    tint = Color(40, 40, 40, 120)
  }
  return {
    size = [mSize, mSize]
    children = (bgImage == null ? [] : [mkImage(bgImage, imgStyle)]) // -unwanted-modification
      .extend(stackImages.map(@(imgData) mkStackImage(imgData, imgStyle)))
  }
}

function mkMedalTooltip(medal) {
  let { name = null } = medal
  let tooltipText = name == null ? "" : loc(name)
  return tooltipText == "" ? null
    : tooltipBox({
        rendObj = ROBJ_TEXTAREA
        behavior = Behaviors.TextArea
        maxWidth = hdpx(500)
        color = Color(180, 180, 180, 120)
        text = tooltipText
      })
}

return {
  mkMedalCard
  mkDisabledMedalCard
  mkMedalTooltip
}
