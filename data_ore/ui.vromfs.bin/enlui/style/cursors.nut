from "%enlSqGlob/ui/ui_library.nut" import *

let {isGamepad} = require("%ui/control/active_controls.nut")
let {safeAreaVerPadding, safeAreaHorPadding} = require("%enlSqGlob/ui/safeArea.nut")
let tooltipBox = require("tooltipBox.nut")
let { is_sony, is_xbox } = require("%dngscripts/platform.nut")

let tooltipComp = {value = null, elemPos = null}
let tooltipGen = Watched(0)

const MAX_GEN_INT = 1000
function setTooltip(val, elemPos = null){
  tooltipComp.value = val
  tooltipComp.elemPos = elemPos
  tooltipGen(tooltipGen.value > MAX_GEN_INT ? 0 : tooltipGen.value + 1)
}

let getTooltip = @() tooltipComp.value
let cursors = {getTooltip, setTooltip, tooltip = {}}
let { cursorOverStickScroll, cursorOverClickable } = gui_scene
let showGamepad = Computed(@() isGamepad.value || is_xbox || is_sony)

let colorBack = Color(0,0,0,120)

let safeAreaBorders = Computed(@() [safeAreaVerPadding.value+fsh(1), safeAreaHorPadding.value+fsh(1)])

function getTooltipPositioning(vplace, tooltipChildren) {
  if (vplace == ALIGN_BOTTOM)
    return [0, 0]

  if (!showGamepad.value)
    return [hdpxi(12), hdpxi(28)]

  let elemPos = tooltipComp.elemPos?.targetRect
  if (!elemPos)
    return [hdpxi(28), hdpxi(40)]

  let rootSizeHeight = elemPos.b - elemPos.t
  local posY = (((rootSizeHeight * 0.5) + hdpx(20)) + 0.5).tointeger()

  let tooltipPrecalcRect = calc_comp_size(tooltipChildren)
  let critPosY = elemPos.b + tooltipPrecalcRect[1]
  if (critPosY >= (sh(100) - safeAreaBorders.value[0])) {
    let curPos = get_mouse_cursor_pos()
    posY = elemPos.t - curPos.y - tooltipPrecalcRect[1] + hdpxi(20)
  }

  return [hdpxi(28), posY]
}

let mkTooltipCmp = @(align) function() {
  let children = type(getTooltip()) == "string"
    ? tooltipBox({
        rendObj = ROBJ_TEXTAREA
        behavior = Behaviors.TextArea
        maxWidth = hdpxi(500)
        text = getTooltip()
        color = Color(180, 180, 180, 120)
      })
    : getTooltip()

  if (children == null)
    return { watch = [tooltipGen] }

  let pos = getTooltipPositioning(align, children)
  return {
    key = "tooltip"
    pos
    watch = [tooltipGen, showGamepad, safeAreaBorders]
    behavior = Behaviors.BoundToArea
    transform = {}
    safeAreaMargin = safeAreaBorders.value
    vplace = align
    children
  }
}

cursors.tooltip.cmp <- mkTooltipCmp(ALIGN_TOP)
cursors.tooltip.cmpTop <- mkTooltipCmp(ALIGN_BOTTOM)

//EXAMPLE: CUSTOM TOOLTIP (MAY BE FUNCTION OR TABLE)
/*    function onHover(on) {
        cursors.tooltip.state(
          on && descLoc != ""
          ? {
              rendObj = ROBJ_TEXT
              text = descLoc
              fontFx = FFT_GLOW
              fontFxColor = Color(0, 0, 0, 120)
              fontFxFactor = 50
              transform = {}
              safeAreaMargin = [fsh(2), fsh(2)]
            }
          : null
        )
      }
 */

let getEvenIntegerHdpx = @(px) hdpxi(0.5 * px) * 2

let scroll_size = getEvenIntegerHdpx(20)

let round_cursor = [
  [VECTOR_WIDTH, hdpx(1.4)],
  [VECTOR_FILL_COLOR, Color(70, 80, 90, 90)],
  [VECTOR_COLOR, Color(100, 100, 100, 50)],
  [VECTOR_ELLIPSE, 50, 50, 50, 50],
  [VECTOR_WIDTH, hdpx(1.5)],
  [VECTOR_FILL_COLOR, 0],
  [VECTOR_COLOR, Color(0, 0, 0, 60)],
  [VECTOR_ELLIPSE, 50, 50, 43, 43],
  [VECTOR_WIDTH, hdpx(1.5)],
  [VECTOR_COLOR, Color(100, 100, 100, 50)],
  [VECTOR_ELLIPSE, 50, 50, 46, 46],
]

let joyScrollCursorImage = {
  key = "scroll-cursor"
  rendObj = ROBJ_IMAGE
  size = [scroll_size, scroll_size]
  image = Picture($"!ui/uiskin/cursor_scroll.svg:{scroll_size}:{scroll_size}:K")
  keepAspect = KEEP_ASPECT_FIT
  pos = [hdpxi(20), hdpxi(30)]
  opacity = 1

  transform = {}

  animations = [
    { prop=AnimProp.opacity,  from=0.0,    to=1.0,     duration=0.3,  play=true, easing=OutCubic }
    { prop=AnimProp.opacity,  from=1.0,    to=0.0,     duration=0.1,  playFadeOut=true, easing=OutCubic }
    { prop=AnimProp.scale,    from=[0, 0], to=[1, 1],  duration=0.15, play=true, easing=OutCubic }
    { prop=AnimProp.scale,    from=[1, 1], to=[0, 0],  duration=0.1,  playFadeOut=true, easing=OutCubic }
  ]
}

let cursorSzNormal     = getEvenIntegerHdpx(32)
let cursorSzResizeDiag = getEvenIntegerHdpx(18)

let normalCursorPic = Picture("!ui/skin#cursor.svg:{0}:{0}:K".subst(cursorSzNormal))

let draggableCursorPic = Picture("!ui/skin#hand.svg:{0}:{0}:K".subst(cursorSzNormal))

let targetCursorPic = Picture("!ui/skin#sniper_rifle.svg:{0}:{0}:K".subst(cursorSzNormal))
let cursorImageComp = {
  rendObj = ROBJ_IMAGE
  image = normalCursorPic
  size = [cursorSzNormal, cursorSzNormal]
}

function mkPcCursor(children){
  children = children ?? []
  if (type(children) != "array")
    children = [children]
  children = clone children
  children.append(cursorImageComp)
  return {
    size = [0, 0]
    children = children
    watch = [showGamepad, cursorOverStickScroll]
  }
}

let gamepadCursorSize = [hdpxi(40), hdpxi(40)]

let gamepadOnClickAnimationComp = {
  animations = [
    {prop=AnimProp.scale, from=[0.5, 0.5], to=[1, 1],  duration=0.5, play=true, loop=true }
  ]
  commands = round_cursor
  rendObj = ROBJ_VECTOR_CANVAS
  size = gamepadCursorSize
  halign = ALIGN_CENTER
  transform = {pivot=[0.5,0.5]}
  opacity = 0.5
}

let gamepadComp = {
  rendObj = ROBJ_VECTOR_CANVAS
  size = gamepadCursorSize
  commands = round_cursor
}

function mkGamepadCursor(children){
  children = clone children
  children.append(gamepadComp)
  if (cursorOverClickable.value)
    children.append(gamepadOnClickAnimationComp)
  return {
    hotspot = [hdpxi(20), hdpxi(20)]
    watch = [showGamepad, cursorOverStickScroll, cursorOverClickable]
    size = gamepadCursorSize
    children = children
    halign = ALIGN_CENTER
    transform = {
      pivot = [0.5, 0.5]
    }
  }
}

function mkCursorWithTooltip(children){
  if (type(children) != "array")
    children = [children]
  if (cursorOverStickScroll.value && showGamepad.value)
    children.append(joyScrollCursorImage)
  return showGamepad.value ? mkGamepadCursor(children)
                           : mkPcCursor(children)
}

cursors.normal <- Cursor(@() mkCursorWithTooltip(cursors.tooltip.cmp))

cursors.normalTooltipTop <- Cursor(@() mkCursorWithTooltip(cursors.tooltip.cmpTop))


cursors.target <- Cursor(function() {
  let children = [cursors.tooltip.cmp]
  return {
    rendObj = ROBJ_IMAGE
    size = [cursorSzNormal, cursorSzNormal]
    hotspot = [cursorSzNormal/2, cursorSzNormal/2]
    image = targetCursorPic
    children = children
    watch = [showGamepad, cursorOverStickScroll]
    transform = {
      pivot = [0, 0]
    }
  }
})

cursors.draggable <- Cursor(function() {
  let children = [cursors.tooltip.cmp]
  if (cursorOverStickScroll.value && showGamepad.value)
    children.append(joyScrollCursorImage)
  return showGamepad.value
    ? mkGamepadCursor(children)
    : {
        rendObj = ROBJ_IMAGE
        size = [cursorSzNormal, cursorSzNormal]
        hotspot = [0, 0]
        image = draggableCursorPic
        children = children
        watch = [showGamepad, cursorOverStickScroll]
        transform = {
        pivot = [0, 0]
      }
  }
})

let helpSign = {
  rendObj = ROBJ_INSCRIPTION
  text = "?"
  fontSize = hdpx(25)
  vplace = ALIGN_CENTER
  fontFx = FFT_GLOW
  fontFxFactor = 48
  fontFxColor = colorBack
  color = Color(150,150,150,100)
}

let helpSignPc = helpSign.__merge({pos = [hdpxi(25), hdpxi(10)]})

cursors.help <- Cursor(function(){
  let children = [
    cursorOverStickScroll.value && showGamepad.value
      ? joyScrollCursorImage : null,
    showGamepad.value ? helpSign
                      : helpSignPc,
    cursors.tooltip.cmp
  ]
  return showGamepad.value ? mkGamepadCursor(children)
                           : mkPcCursor(children)
})

function mkResizeC(commands, angle=0){
  return {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [cursorSzResizeDiag, cursorSzResizeDiag]
    commands = [
      [VECTOR_WIDTH, hdpx(1)],
      [VECTOR_FILL_COLOR, Color(255,255,255)],
      [VECTOR_COLOR, Color(20, 40, 70, 250)],
      [VECTOR_POLY].extend(commands.map(@(v) v.tofloat()*100/7.0))
    ]
    hotspot = [cursorSzResizeDiag / 2, cursorSzResizeDiag / 2]
    transform = {rotate=angle}
  }
}
let horArrow = [0,3, 2,0, 2,2, 5,2, 5,0, 7,3, 5,6, 5,4, 2,4, 2,6]
cursors.sizeH <- Cursor(mkResizeC(horArrow))
cursors.sizeV <- Cursor(mkResizeC(horArrow, 90))
cursors.sizeDiagLtRb <- Cursor(mkResizeC(horArrow, 45))
cursors.sizeDiagRtLb <- Cursor(mkResizeC(horArrow, 135))

cursors.moveResizeCursors <- {
  [MR_LT] = cursors.sizeDiagLtRb,
  [MR_RB] = cursors.sizeDiagLtRb,
  [MR_LB] = cursors.sizeDiagRtLb,
  [MR_RT] = cursors.sizeDiagRtLb,
  [MR_T]  = cursors.sizeV,
  [MR_B]  = cursors.sizeV,
  [MR_L]  = cursors.sizeH,
  [MR_R]  = cursors.sizeH,
}

cursors.normalCursorPic <- normalCursorPic

function applyTooltip(comp, tooltipCtor) {
  // do not attract dirpad to tooltip components by default
  local { behavior = [], onHover = null, skipDirPadNav = true, eventPassThrough = true } = comp
  behavior = typeof behavior != "array" ? [behavior] : behavior
  if (!behavior.contains(Behaviors.Button))
    behavior.append(Behaviors.Button)
  let onHoverNew = function(on) {
    setTooltip(on ? tooltipCtor() : null)
    onHover?(on)
  }
  return (comp ?? {}).__merge({
    behavior
    skipDirPadNav
    eventPassThrough
    onHover = onHoverNew
    inputPassive = true
  })
}
cursors.withTooltip <- function(comp, tooltipCtor) {
  if (comp == null)
    return null
  return typeof comp == "table"
    ? applyTooltip(comp, tooltipCtor)
    : @() applyTooltip(comp?(), tooltipCtor)
}

return cursors
