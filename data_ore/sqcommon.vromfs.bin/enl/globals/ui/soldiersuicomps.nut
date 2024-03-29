from "%enlSqGlob/ui/ui_library.nut" import *

let { fontBody, fontawesome } = require("%enlSqGlob/ui/fontsStyle.nut")
let tooltipCtor = require("%ui/style/tooltipCtor.nut")
let fa = require("%ui/components/fontawesome.map.nut")
let {
  gap, bigGap, defTxtColor, soldierLockedLvlColor, msgHighlightedTxtColor
} = require("%enlSqGlob/ui/designConst.nut")
let colorize = require("%ui/components/colorize.nut")
let soldiersPresentation = require("%enlSqGlob/ui/soldiersPresentation.nut")
let { getClassCfg, getKindCfg } = require("%enlSqGlob/ui/soldierClasses.nut")
let { blinkingIcon } = require("%enlSqGlob/ui/blinkingIcon.nut")
let { txt, note } = require("%enlSqGlob/ui/defcomps.nut")

const PERK_ALERT_SIGN = "caret-square-o-up"
const ITEM_ALERT_SIGN = "dropbox"
const UPGRADE_ALERT_SIGN = "angle-double-up"

let iconSize = hdpxi(26)

let formatIconName = memoize(function(icon, width, height = null) {
  if (icon.endswith(".svg")) {
    log("getting svg icon for soldiers")
    return $"{icon}:{width.tointeger()}:{(height ?? width).tointeger()}:P"
  }
  return $"{icon}?Ac"
})

let mkAlertIcon = @(icon, unseenWatch = Watched(true), hasBlink = false)
  function() {
    let res = { watch = unseenWatch }
    return !unseenWatch.value ? res
      : res.__update(blinkingIcon(icon), hasBlink ? {} : { animations = null })
  }

let mkLevelIcon = @(fontSize = hdpx(10), color = msgHighlightedTxtColor, fName = "star") {
  rendObj = ROBJ_INSCRIPTION
  validateStaticText = false
  text = fa[fName]
  font = fontawesome.font
  fontSize
  color
}

let mkIconBar = @(level, color, fontSize, fName = "star-o", hasBlink = false) level > 0
  ? mkLevelIcon(fontSize, color, fName).__update({
      key = $"l{level}fnm{fName}b{hasBlink}"
      text = "".join(array(level, fa[fName]))
      color
      animations = hasBlink
        ? [ { prop = AnimProp.opacity, from = 0.5, to = 1, duration = 0.7, play = true, loop = true, easing = Blink} ]
        : null
    })
  : null

let mkHiddenAnim = @(p = {})
  { prop = AnimProp.opacity, from = 0, to = 0, duration = 0.1, play = true }.__update(p)

let mkAnimatedLevelIcon = function(guid, color, fontSize) {
    let trigger = $"{guid}lvl_anim"
    return {
      children = [
        mkLevelIcon(fontSize, color, "star-o")
        mkLevelIcon(fontSize, color, "star").__update({
          transform = {}
          animations = [
            mkHiddenAnim({ duration = 0.9, play = false, trigger })
            { prop = AnimProp.opacity, from = 0, to = 1, duration = 0.4,
              easing = InOutCubic, delay = 0.8, trigger }
            { prop = AnimProp.scale, from = [3,3], to = [1,1], duration = 0.8,
              easing = InOutCubic, delay = 0.8, trigger }
          ]
        })
      ]
    }
  }

function levelBlock(params) {
  let { level = 1, maxLevel = 1, fontSize = hdpx(12) } = params
  return {
    size = SIZE_TO_CONTENT
    flow = FLOW_HORIZONTAL
    children = [
      mkIconBar(level, msgHighlightedTxtColor, fontSize, "star")
      mkIconBar(max(maxLevel - level, 0), soldierLockedLvlColor, fontSize)
    ]
    animations = [ mkHiddenAnim() ]
  }
}

let mkUnknownClassIcon = @(iSize) {
  rendObj = ROBJ_TEXT
  size = [iSize.tointeger(), SIZE_TO_CONTENT]
  halign = ALIGN_CENTER
  text = "?"
  color = defTxtColor
}.__update(fontBody)

let getKindIcon = memoize(@(img, sz) Picture("ui/skin#{0}:{1}:{1}:K".subst(img, sz.tointeger())))
let getClassIcon = memoize(@(img, sz) Picture("{0}:{1}:{1}:K".subst(img, sz.tointeger())))

function kindIcon(sKind, iSize, sClassRare = null, forceColor = null) {
  if (sKind == null)
    return mkUnknownClassIcon(iSize)

  let { icon = "", iconsByRare = null, colorsByRare = null } = getKindCfg(sKind)
  let sKindImg = iconsByRare?[sClassRare] ?? icon
  if (sKindImg == "")
    return mkUnknownClassIcon(iSize)
  let sClassColor = forceColor ?? colorsByRare?[sClassRare] ?? defTxtColor
  return {
    rendObj = ROBJ_IMAGE
    size = [iSize, iSize]
    color = sClassColor
    image = getKindIcon(sKindImg, iSize)
  }
}

function classIcon(armyId, sClass, iSize, override = {}) {
  let { getIcon } = getClassCfg(sClass)
  let icon = getIcon(armyId) ?? ""
  if (icon == "")
    return null

  return {
    rendObj = ROBJ_IMAGE
    size = [iSize, iSize]
    keepAspect = KEEP_ASPECT_FIT
    image = getClassIcon(icon, iSize)
  }.__update(override)
}

let kindName = @(sKind) note({
  text = loc(getKindCfg(sKind).locId)
  vplace = ALIGN_CENTER
  color = defTxtColor
})

let className = @(sClass, count = 0) note({
  text = count <= 1 ? loc(getClassCfg(sClass).locId)
    : $"{loc(getClassCfg(sClass).locId)} {loc("common/amountShort", { count })}"
  vplace = ALIGN_CENTER
  color = defTxtColor
})

let classNameColored = @(sClass, sKind, sClassRare) txt({
  text = loc(getClassCfg(sClass).locId)
  vplace = ALIGN_CENTER
  color = getKindCfg(sKind)?.colorsByRare[sClassRare] ?? defTxtColor
})

function calcExperienceData(soldier, expToLevel) {
  let { level = 1, maxLevel = 1, exp = 0 } = soldier
  let expToNextLevel = level < maxLevel ? (expToLevel?[level] ?? 0) : 0
  return { level, maxLevel, exp, expToNextLevel }
}

let classTooltip = function(armyId, sClass, sKind, tierMapsHint = null) {
  let classCfg = getClassCfg(sClass)
  return tooltipCtor({
    flow = FLOW_VERTICAL
    size = [hdpx(500), SIZE_TO_CONTENT]
    gap = bigGap
    children = [
      {
        flow = FLOW_HORIZONTAL
        valign = ALIGN_CENTER
        gap = gap
        children = [
          kindIcon(sKind, iconSize)
          classIcon(armyId, sClass, iconSize)
          txt(loc(classCfg.locId))
        ]
      }
      {
        rendObj = ROBJ_TEXTAREA
        size = [flex(), SIZE_TO_CONTENT]
        text = loc(classCfg.longLocId)
        color = defTxtColor
        behavior = Behaviors.TextArea
      }
      tierMapsHint
    ]
  })
}

let experienceTooltip = kwarg(@(level, maxLevel, exp, expToNextLevel)
  loc(level < maxLevel ? "hint/soldierLevel" : "hint/soldierMaxLevel", {
    level = colorize(msgHighlightedTxtColor, level)
    maxLevel
    exp = colorize(msgHighlightedTxtColor, exp)
    expToNextLevel
  })
)

function mkSoldierMedalIcon(soldierInfo, size) {
  let { isHero = false, armyId = null, country = null } = soldierInfo
  let heroIcon = soldiersPresentation?[country] ?? soldiersPresentation?[armyId] // FIXME backward compatibility
  if (heroIcon == null || !isHero)
    return null

  return {
    rendObj = ROBJ_IMAGE
    size = [size, size]
    image = Picture(formatIconName(heroIcon, size))
    keepAspect = KEEP_ASPECT_FIT
  }
}

return {
  mkAlertIcon
  levelBlock
  kindIcon
  kindName
  classIcon
  className
  classNameColored
  calcExperienceData
  classTooltip
  experienceTooltip
  mkLevelIcon
  mkSoldierMedalIcon
  mkIconBar
  mkAnimatedLevelIcon
  mkHiddenAnim

  PERK_ALERT_SIGN
  ITEM_ALERT_SIGN
  UPGRADE_ALERT_SIGN
}
