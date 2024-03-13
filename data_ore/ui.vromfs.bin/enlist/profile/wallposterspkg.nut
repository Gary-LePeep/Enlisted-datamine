from "%enlSqGlob/ui/ui_library.nut" import *

let exclamation = require("%enlist/components/exclamation.nut")
let { doesLocTextExist } = require("dagor.localize")
let { fontSub, fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let { bgColor, txtColor } = require("profilePkg.nut")
let { midPadding, smallPadding, smallOffset, defTxtColor, darkTxtColor, disabledTxtColor
} = require("%enlSqGlob/ui/designConst.nut")
let { smallUnseenNoBlink } = require("%ui/components/unseenComps.nut")
let { staticSeasonBPIcon } = require("%enlist/battlepass/battlePassPkg.nut")

let wpSize = hdpxi(190)
let wpHeaderWidth = hdpxi(150)
let iconSize = hdpxi(60)

let weakTxtColor = @(sf) sf & S_HOVER ? darkTxtColor : disabledTxtColor

let mkText = @(text, style) {
  rendObj = ROBJ_TEXT
  color = defTxtColor
  text
}.__update(style)

let mkTextArea = @(text, style, sf=0) {
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  size = [flex(), SIZE_TO_CONTENT]
  color = txtColor(sf)
  text
}.__update(style)

let mkTitleColumn = @(text, sf) {
  size = [wpHeaderWidth, SIZE_TO_CONTENT]
  halign = ALIGN_RIGHT
  children = mkText(text, { color = weakTxtColor(sf) }.__update(fontSub))
}

let mkWpRow = @(locId, rowTitleText, txtStyle, isEmptyHidden = false, sf = 0)
  doesLocTextExist(locId) || !isEmptyHidden
    ? {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        gap = midPadding
        valign = ALIGN_CENTER
        children = [
          mkTitleColumn(rowTitleText, sf)
          mkTextArea(loc(locId), txtStyle, sf)
        ]
      }
    : null

function mkWpBottomRow(wallposter, sf) {
  let { armyLocId, bpSeason = null, icon = null } = wallposter
  return {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    gap = midPadding
    children = [
      {
        size = [wpHeaderWidth, SIZE_TO_CONTENT]
        halign = ALIGN_RIGHT
        children = icon != null
          ? {
              rendObj = ROBJ_IMAGE
              size = [iconSize, iconSize]
              image = Picture($"{icon}:{iconSize.tointeger()}:{iconSize.tointeger()}:K?Ac")
            }
          : (bpSeason ?? 0) == 0 ? null : staticSeasonBPIcon(bpSeason, iconSize)
      }
      {
        rendObj = ROBJ_FRAME
        size = [pw(50), SIZE_TO_CONTENT]
        flow = FLOW_VERTICAL
        color = disabledTxtColor
        borderWidth = [hdpx(1), 0, 0, 0]
        children = mkText(loc(armyLocId), { color = weakTxtColor(sf) }.__update(fontBody))
      }
    ]
  }
}

let mkWallposterImg = @(img, hasReceived, isHovered, wpImgSize) {
  rendObj = ROBJ_IMAGE
  size = [wpImgSize, wpImgSize]
  picSaturate = hasReceived ? 1.2
    : isHovered ? 0.5
    : 0.1
  opacity = hasReceived || isHovered ? 1 : 0.7
  image = Picture(img)
}

function mkWallposter(wallposter, sf = 0, isUnseen = false) {
  let { hasReceived, isHidden, img, nameLocId, descLocId, hintLocId } = wallposter
  let isHovered = sf & S_HOVER
  return {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    gap = smallPadding
    valign = ALIGN_CENTER
    vplace = ALIGN_CENTER
    children = [
      mkWallposterImg(img, hasReceived, isHovered, wpSize)
      {
        rendObj = ROBJ_SOLID
        size = flex()
        padding = midPadding
        color = bgColor(sf)
        children = [
          {
            size = [flex(), SIZE_TO_CONTENT]
            flow = FLOW_VERTICAL
            gap = midPadding
            children = [
              mkWpRow(nameLocId, loc("wp/name"), fontBody, false, sf)
              { size = [flex(), smallOffset] }
              mkWpRow(descLocId, loc("wp/desc"), fontSub, true, sf)
              mkWpRow(hintLocId, loc("wp/toToGet"), fontSub, true, sf)
              mkWpBottomRow(wallposter, sf)
            ]
          }
          isHidden ? exclamation().__update({ hplace = ALIGN_RIGHT }) : null
          isUnseen ? smallUnseenNoBlink : null
        ]
      }
    ]
  }
}

function makeBigWpImage(wallposter, onClick) {
  let { img, nameLocId } = wallposter
  return {
    size = flex()
    flow = FLOW_VERTICAL
    gap = midPadding
    padding = midPadding
    halign = ALIGN_CENTER
    behavior = Behaviors.Button
    onClick
    children = [
      mkTextArea(loc(nameLocId), {
        size = [pw(80), SIZE_TO_CONTENT]
        halign = ALIGN_CENTER
      }.__update(fontBody))
      {
        rendObj = ROBJ_IMAGE
        size = flex()
        image = Picture(img)
        keepAspect = KEEP_ASPECT_FIT
      }
    ]
  }
}

return {
  mkWallposter
  mkWallposterImg
  makeBigWpImage
}
