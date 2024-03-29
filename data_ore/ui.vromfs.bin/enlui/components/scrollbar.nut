from "%enlSqGlob/ui/ui_library.nut" import *

let baseScrollbar = require("%ui/components/base_scrollbar.nut")
let { Interactive, Active, HoverItemBg, FullTransparent, ScrollBgColor
} = require("%ui/style/colors.nut")
let { mkColoredGradientY } = require("%enlSqGlob/ui/gradients.nut")

let styling = freeze({
  Knob = {
    rendObj = ROBJ_SOLID
    colorCalc = @(sf) sf & S_ACTIVE ? Active
      : sf & S_HOVER ? HoverItemBg
      : Interactive
    sound = { active = "ui/enlist/combobox_action" }
  }

  Bar = function(has_scroll) {
    if (has_scroll) {
      return {
        rendObj = ROBJ_SOLID
        color = Color(40, 40, 40, 160)
        _width = fsh(1)
        _height = fsh(1)
        sound = { hover  = "ui/enlist/combobox_highlight" }
        skipDirPadNav = true
      }
    } else {
      return {
        rendObj = null
        _width = sh(0)
        _height = sh(0)
        skipDirPadNav = true
      }
    }
  }

  ContentRoot = {
    size = flex()
    skipDirPadNav = true
  }
})

let thinStyle = freeze({
  Knob = {
    rendObj = ROBJ_SOLID
    colorCalc = @(_sf) Color(0, 0, 0, 0)
    hoverChild = @(sf){
      size = [hdpx(2), flex()]
      rendObj = ROBJ_SOLID
      hplace = ALIGN_RIGHT
      color = sf & S_ACTIVE  ? Color(255, 255, 255)
              : sf & S_HOVER ? Color(110, 120, 140, 80)
              : Color(110, 120, 140, 160)
    }
  }
  Bar = function(has_scroll) {
    if (!has_scroll)
      return {
        _width = 0
        _height = 0
        skipDirPadNav = true
      }
    return {
      rendObj = ROBJ_SOLID
      color = Color(0, 0, 0, 60)
      _width = hdpx(4)
      _height = fsh(1)
      skipDirPadNav = true
    }
  }

  ContentRoot = {
    size = flex()
    skipDirPadNav = true
  }
})


function scrollbar(scroll_handler) {
  return baseScrollbar.scroll(scroll_handler, {styling=styling})
}


function makeHorizScroll(content, options={}) {
  if (!("styling" in options))
    options.styling <- styling
  return baseScrollbar.makeHorizScroll(content, options)
}

function makeVertScroll(content, options={}) {
  if (!("styling" in options))
    options.styling <- styling
  return baseScrollbar.makeVertScroll(content, options)
}

let topGradient = mkColoredGradientY({ colorTop = ScrollBgColor, colorBottom = FullTransparent})
let bottomGradient = mkColoredGradientY({ colorTop = FullTransparent, colorBottom = ScrollBgColor })

function makeGradientVertScroll(content, options = {}) {
  let hasBottomScroll = Watched(false)
  let hasTopScroll = Watched(true)
  let scrollHandler = ScrollHandler()

  function updateScroll(elem) {
    hasTopScroll(elem.getScrollOffsY() > 0)
    let overflow = elem.getContentHeight() - elem.getHeight()
    hasBottomScroll(overflow > elem.getScrollOffsY())
  }

  scrollHandler.subscribe(function(_) {
    let { elem = null } = scrollHandler
    if (elem == null)
      return
    updateScroll(elem)
  })

  let { gradientSize, size = [SIZE_TO_CONTENT, flex()] } = options
  let topScroll = freeze({
    rendObj = ROBJ_IMAGE
    size = [flex(), gradientSize]
    image = topGradient
  })

  let bottomScroll = freeze({
    rendObj = ROBJ_IMAGE
    size = [flex(), gradientSize]
    image = bottomGradient
  })

  let opt = options.__merge({ scrollHandler })

  return @() {
    size
    children = [
      makeVertScroll(content, opt)
      @() {
        watch = hasTopScroll
        size = [flex(), gradientSize]
        children = hasTopScroll.value ? topScroll : null
        vplace = ALIGN_TOP
      }
      @() {
        watch = hasBottomScroll
        size = [flex(), gradientSize]
        children = hasBottomScroll.value ? bottomScroll : null
        vplace = ALIGN_BOTTOM
      }
    ]
  }
}


return {
  scrollbar
  makeHorizScroll
  makeVertScroll
  styling
  thinStyle
  makeGradientVertScroll
}
