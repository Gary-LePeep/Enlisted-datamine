from "%enlSqGlob/ui/ui_library.nut" import *
let { TextDefault } = require("%ui/style/colors.nut")
let { safeAreaVerPadding } = require("%enlSqGlob/ui/safeArea.nut")
let { mkColoredGradientY, mkColoredGradientX } = require("%enlSqGlob/ui/gradients.nut")

let isWide = sw(100).tofloat() / sh(100) > 1.7
let unitSize = hdpxi(45)
let midPadding = hdpxi(8)

let selectedTxtColor = 0xFF000000
let weaponTxtColor = 0xFFAAAAAA
let titleTxtColor = 0xFFFAFAFA
let disabledTxtColor = 0xFF646464
let activeBgColor = 0xFFB4B4B4
let defBgColor = 0x78000000
let hoverBgColor = 0xFFCDCDDC
let panelBgColor  = 0xFF313C45
let fadedTxtColor = 0x96828282

let footerContentHeight = hdpx(36) + safeAreaVerPadding.value


let levelNestGradient    = mkColoredGradientX({colorLeft=0x00FFFFFF, colorRight=0x22FFFFFF, width=6, isAlphaPremultiplied=false})
let hoverLevelNestGradient = mkColoredGradientX({colorLeft=0x00000000, colorRight=0x33555555, width=6, isAlphaPremultiplied=false})


let lineGradient = mkColoredGradientX({colorLeft=0x5AFFFFFF, colorRight=0x00FFFFFF, width=12, isAlphaPremultiplied=false})
let highlightLineHgt = hdpx(4)
let mkHighlightLine = @(isTop = true) freeze({
  rendObj = ROBJ_IMAGE
  size = [flex(), highlightLineHgt]
  image = lineGradient
  vplace = isTop ? ALIGN_TOP : ALIGN_BOTTOM
})

let highlightLineTop = mkHighlightLine()
let highlightLineBottom = mkHighlightLine(false)

let lineVertGradient = mkColoredGradientY({colorTop=0x5AFFFFFF, colorBottom=0x00FFFFFF, height=12, isAlphaPremultiplied=false})

let mkHighlightVertLine = @(isLeft = true) freeze({
  rendObj = ROBJ_IMAGE
  size = [highlightLineHgt, flex()]
  image = lineVertGradient
  hplace = isLeft ? ALIGN_LEFT : ALIGN_RIGHT
})
let highlightVertLineLeft = mkHighlightVertLine()
let highlightVertLineRight = mkHighlightVertLine(false)

let mkAnimationList = @(delay, toLeft = true, trigger = null) [
  { prop = AnimProp.opacity, from = 0, to = 0, duration = delay, trigger,
    play = (trigger == null) }
  { prop = AnimProp.opacity, from = 0, to = 1, delay, duration = 0.2, trigger,
    play = (trigger == null) }
  toLeft
    ? { prop = AnimProp.translate, from = [sw(20),0], to = [0,0], delay, trigger,
        duration = 0.2, easing = OutQuart, play = (trigger == null) }
    : { prop = AnimProp.translate, from = [-sw(20),0], to = [0,0], delay, trigger,
        duration = 0.2, easing = OutQuart, play = (trigger == null) }
  { prop = AnimProp.opacity, from = 1, to = 0, duration = 0.2, playFadeOut = true }
]

const DEF_APPEARANCE_TIME = 0.4
let appearanceAnim = @(delay, toLeft = true, trigger = null) {
  transform = {}
  animations = mkAnimationList(delay, toLeft)
    .extend(trigger != null ? mkAnimationList(delay, toLeft, trigger) : [])
}

let defTxtColor = 0xFFB3BDC1

let mkTimerIcon = @(size = hdpxi(22), override = {}) {
  rendObj = ROBJ_IMAGE
  size = [size, size]
  image = Picture("ui/skin#battlepass/boost_time.svg:{0}:{0}:K".subst(size))
  color =  defTxtColor
}.__update(override)

let emptyGap = freeze({
  size = [fsh(1), fsh(1)]
})

let horGap = freeze({
  size = [fsh(3), flex()], halign = ALIGN_CENTER, valign = ALIGN_CENTER
  children = { rendObj = ROBJ_SOLID, size = [hdpx(1),flex()], color = TextDefault, margin = [hdpx(4),0], opacity = 0.5 }
})

let listCtors = {
  nameColor = @(flags, _selected = false)
    flags & S_HOVER ? selectedTxtColor : titleTxtColor

  weaponColor = @(flags, _selected = false)
    flags & S_HOVER ? selectedTxtColor : weaponTxtColor

  txtColor = @(flags, selected = false)
    (flags & S_HOVER) || (flags & S_ACTIVE) || selected ? selectedTxtColor : defTxtColor

  txtDisabledColor = @(flags, _selected = false)
    flags & S_HOVER ? selectedTxtColor : disabledTxtColor

  bgColor = @(flags, selected = false, idx = 0) selected ? activeBgColor
    : flags & S_HOVER ? hoverBgColor
    : (idx%2==0) ? defBgColor
    : mul_color(defBgColor, 0.65)
}

let rowBg = @(sf, idx, isSelected = false) isSelected ? 0x19464646
  : sf & S_HOVER ? 0x190A0A0A
  : (idx % 2) ? 0x19353535
  : 0x19191919

return {
  isWide

  //Gradients
  highlightLineTop
  highlightLineBottom
  highlightLineHgt
  highlightVertLineLeft
  highlightVertLineRight

  // Gaps
  horGap
  emptyGap
  midPadding
  largePadding = hdpxi(16)
  sidePadding = hdpxi(32)
  bigPadding = hdpxi(12)
  smallPadding = hdpxi(4)
  miniPadding = hdpxi(2)
  contentGap = hdpxi(68)
  bigGap = hdpx(10)
  gap = hdpx(5)

  //Size
  unitSize
  footerContentHeight
  maxContentWidth = min(hdpx(1920), sw(100))
  commonBtnHeight = hdpx(48)
  smallBtnHeight = hdpx(30)
  commonBorderRadius = hdpx(2)
  startBtnWidth = fsh(34.6)
  navHeight = hdpx(74)
  bigOffset = hdpx(48)
  smallOffset = hdpx(24)
  contentOffset = hdpx(20)
  tinyOffset = hdpx(12)
  mainContentOffset = hdpx(96)
  selectionLineHeight = hdpx(4)
  selectionLineOffset = hdpx(6)
  fastAccessIconHeight = hdpx(32)
  hotkeysBarHeight = hdpx(22)
  navigationBtnHeight = hdpx(62)
  inventoryItemDetailsWidth = hdpx(378)
  soldierWndWidth = hdpxi(450)
  modeCardSize = [fsh(27.5), fsh(43)]
  modeNameBlockHeight = hdpx(82)
  mainContentHeaderHeight = hdpx(55)
  awardIconSize = (unitSize * 2).tointeger()
  awardIconSpacing = 2 * midPadding
  armyIconSize = hdpx(50)
  vehicleListCardSize = [unitSize * 5, unitSize * 3]
  slotBaseSize = [(7 * unitSize).tointeger(), (1.5 * unitSize).tointeger()]
  multySquadPanelSize = [(unitSize * 3.2).tointeger(), (unitSize * 2.2).tointeger()]
  squadSlotHorSize = [hdpxi(660), hdpxi(72)]

  //BgColor
  defBgColor
  panelBgColor
  hoverBgColor
  activeBgColor
  defItemBlur = 0xFFA0A2A3
  defSlotBgColor = 0x99303841
  hoverSlotBgColor = 0xFFA0A2A3
  reseveSlotBgColor = 0xFF424C37
  defLockedSlotBgColor = 0xFF402729
  hoverLockedSlotBgColor = 0xFF624A4D
  enableItemIdleBgColor  = 0x99596756
  idleBgColor = 0xFF464646
  transpPanelBgColor = 0xAA313C45
  hoverPanelBgColor = 0xFF59676E
  darkPanelBgColor = 0xFF13181F
  transpDarkPanelBgColor = 0x5513181F
  transpBgColor = 0x88111111
  fullTransparentBgColor = 0x00000000
  disabledBgColor = 0xFF292E33
  accentColor = 0xFFFAFAFA
  brightAccentColor = 0xFFFCB11D
  discountBgColor = 0xFFF8BD41
  modsBgColor = 0xFF13181F
  totalBlack = 0xFF000000
  accentColorOld = 0xFFE68200
  blurBgFillColor = 0x19191919
  darkBgColor = 0xB4000000
  selectedPanelBgColor = mul_color(panelBgColor, 1.5)

  //BdColor
  defInsideBgColor = panelBgColor
  defBdColor = 0xFFB3BDC1
  disabledBdColor = 0xFF4B575D
  hoverBdColor  = 0xFF132438
  blurBgColor = 0xFF969696
  airSelectedBgColor = 0x96969696
  airHoverBgColor = 0xC8CDDCDD
  airBgColor = 0x78000000
  defPanelBgColorVer_1 = 0xC8323232
  opaqueBgColor = 0xFF141414
  blockedBgColor = 0xFF640A0A
  insideBorderColor = 0x05F03232
  bgPremiumColor = 0xFF0B0B13

  // TxtColor
  disabledTxtColor
  selectedTxtColor
  defTxtColor
  titleTxtColor
  fadedTxtColor
  noteTxtColor = fadedTxtColor
  activeTxtColor = 0xFFDCDCDC
  weakTxtColor  = 0xFFA4A4A4
  hoverTxtColor = 0xFFD4D4D4
  hoverSlotTxtColor = 0xFF404040
  darkTxtColor = 0xFF313841
  attentionTxtColor = 0xFFFFBE30
  negativeTxtColor = 0xFFEE5656
  positiveTxtColor = 0xFF8FEE56
  completedTxtColor = 0xFF2968E9
  deadTxtColor = 0xAA101010
  msgHighlightedTxtColor = 0xFFD2AA14
  blockedTxtColor = 0xFFC80F0A
  hoverTitleTxtColor = 0xFFDCDCE6
  activeTitleTxtColor = 0xFFB4B4C8
  textBgBlurColor = 0xFFFFFFFF
  accentTitleTxtColor = 0xFFFBBD40

  // soldier and squad slot color
  levelNestGradient
  hoverLevelNestGradient
  haveLevelColor = 0xFFF8BD41
  gainLevelColor = 0xFFFFCE68
  lockLevelColor = 0xFFAAAAAA
  soldierLvlColor = 0x96B4B400
  soldierLockedLvlColor = 0xFFB3BDC1
  lockedSquadBgColor = 0xFF636162
  squadElemsBgColor = 0x963C3C3C
  squadElemsBgHoverColor = 0x96AFAFAF
  squadSlotBgIdleColor = 0x99303841
  squadSlotBgHoverColor = 0xFFA0A2A3
  squadSlotBgActiveColor = 0xFF4A5A68
  squadSlotBgAlertColor = 0x77330000
  squadSlotBgMultiSelColor = 0x99606060

  unseenColor = 0xFF00FF6C
  bonusColor = 0xFF78FA78
  warningColor = 0xFFE66464
  hasPremiumColor = 0xFFD2D264
  basePremiumColor = 0xFF707070
  taskProgressColor = 0xFFFBBD40
  taskDefColor = 0xFF7D7D7D
  debriefingDarkColor = 0xB4000000
  spawnNotReadyColor = 0xFFB44646

  listCtors
  rowBg

  strokeStyle = {
    fontFx = FFT_GLOW
    fontFxColor = 0xCC000000
    fontFxFactor = min(16, hdpx(16))
  }
  shadowStyle = {
    fontFx = FFT_GLOW
    fontFxColor = 0xFF000000
    fontFxFactor = min(hdpx(16), 16)
    fontFxOffsX = hdpx(1)
    fontFxOffsY = hdpx(1)
  }

  //Animations
  rightAppearanceAnim = @(delay = DEF_APPEARANCE_TIME, trigger = null)
    appearanceAnim(delay, false, trigger)
  leftAppearanceAnim = @(delay = DEF_APPEARANCE_TIME, trigger = null)
    appearanceAnim(delay, true, trigger)
  DEF_APPEARANCE_TIME

  mkTimerIcon
}
