from "%enlSqGlob/ui/ui_library.nut" import *
let { squadSlotBgIdleColor }  = require("%enlSqGlob/ui/designConst.nut")

let darkColor = Color(49, 56, 65)
let lightColor = Color(250, 250, 250)
let treeBgColor = squadSlotBgIdleColor
let pointsBgColor = Color(64, 73, 85)
let inactiveColor = mul_color(lightColor, 0.4)

enum NodeState {
  TIER_LOCKED = 0
  INACTIVE = 1
  UNLOCKED = 2
  FULL = 3
}

enum NodeElements {
  OUTER = 0
  INNER = 1
  ICON  = 2
  POINTS_BG = 3
  POINTS_BORDER = 4
  POINTS_TEXT = 5
}

let colors = {
  [NodeState.TIER_LOCKED] = @(_, isHover) {
    [NodeElements.OUTER] = isHover ? lightColor : treeBgColor,
    [NodeElements.INNER] = isHover ? lightColor : darkColor,
    [NodeElements.ICON] = isHover ? darkColor : treeBgColor,
    [NodeElements.POINTS_BG] = isHover ? lightColor : pointsBgColor,
    [NodeElements.POINTS_BORDER] = darkColor,
    [NodeElements.POINTS_TEXT] = isHover ? darkColor : lightColor
  },

  [NodeState.INACTIVE] = @(_, isHover) {
    [NodeElements.OUTER] = isHover ? lightColor : inactiveColor,
    [NodeElements.INNER] = isHover ? lightColor : darkColor,
    [NodeElements.ICON] = isHover ? darkColor : inactiveColor,
    [NodeElements.POINTS_BG] = isHover ? lightColor : pointsBgColor,
    [NodeElements.POINTS_BORDER] = darkColor,
    [NodeElements.POINTS_TEXT] = isHover ? darkColor : lightColor
  },

  [NodeState.UNLOCKED] = @(iconColor, isHover) {
    [NodeElements.OUTER] = lightColor,
    [NodeElements.INNER] = isHover ? iconColor : darkColor,
    [NodeElements.ICON] = isHover ? darkColor : iconColor,
    [NodeElements.POINTS_BG] = isHover ? iconColor : pointsBgColor,
    [NodeElements.POINTS_BORDER] = darkColor,
    [NodeElements.POINTS_TEXT] = isHover ? darkColor : lightColor
  },

  [NodeState.FULL] = @(iconColor, isHover) {
    [NodeElements.OUTER] = iconColor,
    [NodeElements.INNER] = isHover ? iconColor : darkColor,
    [NodeElements.ICON] = isHover ? darkColor : iconColor,
    [NodeElements.POINTS_BG] = isHover ? iconColor : pointsBgColor,
    [NodeElements.POINTS_BORDER] = isHover ? darkColor : iconColor,
    [NodeElements.POINTS_TEXT] = isHover ? darkColor : iconColor
  }
}

// locked state is intentionally checked last
// for some legacy premium perk schemes may include 5th level perks for the 4th level soldiers
let getColorTbl = @(isTierAvailable, hasUnlocked, hasAvailable)
  hasUnlocked == hasAvailable ? colors[ NodeState.FULL ]
    : hasUnlocked > 0 ? colors[ NodeState.UNLOCKED ]
    : !isTierAvailable ? colors[ NodeState.TIER_LOCKED ]
    : colors[ NodeState.INACTIVE ]

return {
  darkColor
  lightColor
  treeBgColor
  getColorTbl
  NodeElements
}
