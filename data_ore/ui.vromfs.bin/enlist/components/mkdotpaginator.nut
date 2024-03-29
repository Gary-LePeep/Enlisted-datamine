from "%enlSqGlob/ui/ui_library.nut" import *

let faComp = require("%ui/components/faComp.nut")
let { smallPadding, titleTxtColor, defTxtColor, activeTxtColor, activeBgColor
} = require("%enlSqGlob/ui/designConst.nut")


let defDotSize = hdpx(12)

let mkProgressLine = @(trigger, page, duration) {
  key = $"page_{page}"
  rendObj = ROBJ_SOLID
  size = [flex(), hdpx(2)]
  opacity = 0
  color = activeBgColor
  transform = { pivot = [0,0] }
  animations = [
    { prop = AnimProp.opacity, from = 0.4, to = 0.4,
      duration = duration, play = true, trigger }
    { prop = AnimProp.scale, from = [0, 1], to = [1, 1],
      duration = duration, play = true, trigger }
  ]
}

let mkDotPaginator = kwarg(function(
  id, pageWatch, dotSize = defDotSize, switchTime = Watched(0)
) {
  local pages = 1
  let gotoNextPage = @() pageWatch((pageWatch.value + 1) % pages)
  function startSwitchTimer(_ = null) {
    anim_skip(id)
    gui_scene.clearTimer(gotoNextPage)
    if (pages > 1 && switchTime.value > 0) {
      anim_start(id)
      gui_scene.setTimeout(switchTime.value, gotoNextPage)
    }
  }

  return function(curPages) {
    pages = curPages
    if (pages <= 1) {
      gui_scene.clearTimer(gotoNextPage)
      foreach (v in [pageWatch, switchTime])
        v.unsubscribe(startSwitchTimer)

      return null
    }

    foreach (v in [pageWatch, switchTime])
      v.subscribe(startSwitchTimer)
    startSwitchTimer()

    return @() {
      watch = pageWatch
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      halign = ALIGN_CENTER
      children = [
        {
          flow = FLOW_HORIZONTAL
          children = array(pages).map(function(_, idx) {
            let isSelected = pageWatch.value == idx
            return watchElemState(@(sf) {
              behavior = Behaviors.Button
              onClick = @() pageWatch(idx)
              onHover = function(on) {
                if (on) {
                  anim_skip(id)
                  gui_scene.clearTimer(gotoNextPage)
                }
                else
                  startSwitchTimer()
              }
              children = faComp(isSelected ? "circle" : "circle-o", {
                padding = smallPadding
                fontSize = dotSize
                color = isSelected ? titleTxtColor
                  : sf & S_HOVER ? activeTxtColor
                  : defTxtColor
              })
            })
          })
        }
        mkProgressLine(id, pageWatch.value, switchTime.value)
      ]
    }
  }
})

return mkDotPaginator
