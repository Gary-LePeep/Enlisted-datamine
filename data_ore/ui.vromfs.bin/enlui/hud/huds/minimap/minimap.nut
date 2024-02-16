from "%enlSqGlob/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
from "minimap" import MinimapState

let mmContext = require("minimap_ctx.nut")
let {controlHudHint} = require("%ui/components/controlHudHint.nut")
let {mmChildrenCtors} = require("%ui/hud/minimap_ctors.nut")

let minimapDefaultVisibleRadius = Watched(150)

ecs.register_es("set_minimap_default_visible_radius_es", {
    function onInit(_eid, comp) {
      minimapDefaultVisibleRadius.update(comp["level__minimapDefaultVisibleRadius"])
    }
  },
  {
    comps_rq = ["level"]
    comps_ro = [["level__minimapDefaultVisibleRadius", ecs.TYPE_INT]]
  })

let mapSize = [fsh(17), fsh(17)]
let mapContentMargin = fsh(0.5)//needed because of compass arrows that are out of size

let MMSHAPES = {
  SQUARE = {
    rendType = "square"
    rotate = 90
    minimapObjsTransform = {rotate=-90}
    blurBackMask = null
    clipChildren = true
    viewDependentRotation = false
  },
  CIRCLE = {
    blurBackMask = Picture("ui/uiskin/white_circle.svg:{0}:{0}:K".subst(mapSize[0].tointeger()))
    rendType = "circle"
    rotate = 0
    minimapObjsTransform = {rotate=0}
    viewDependentRotation=true
    clipChildren = false
  }
}

let curMinimapShape = MMSHAPES.SQUARE
let minimapState = MinimapState({
  ctx = mmContext
  visibleRadius = minimapDefaultVisibleRadius.value
  shape = curMinimapShape.rendType
})
minimapDefaultVisibleRadius.subscribe(@(r) minimapState.setVisibleRadius(r))
let mapTransform = { rotate = curMinimapShape.rotate }

let blurredWorld = {
  rendObj = ROBJ_MASK
  image = curMinimapShape.blurBackMask
  size = mapSize
  children = {
    rendObj = ROBJ_WORLD_BLUR
    size = flex()
  }
}


let visCone = {
  size = flex()
  minimapState = minimapState
  rendObj = ROBJ_MINIMAP_VIS_CONE
  behavior = Behaviors.Minimap
}

let mapHotKey = {
  children = controlHudHint("HUD.BigMap")
  hplace = ALIGN_LEFT
  vplace = ALIGN_BOTTOM
  margin = [hdpx(3),hdpx(3)]
  opacity = 0.7
}

let baseMap = {
  size = mapSize
  transform = mapTransform
  minimapState = minimapState
  rendObj = ROBJ_MINIMAP
  behavior = Behaviors.Minimap
  margin = mapContentMargin

  children = visCone
}

let commonLayerParams = {
  state = minimapState
  size = mapSize
  isCompassMinimap = curMinimapShape.viewDependentRotation
  transform = curMinimapShape.minimapObjsTransform
  showHero = false
}

let function mkMinimapLayer(ctorWatch, params) {
  return @() {
    watch = ctorWatch.watch
    size = flex()
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    clipChildren = params?.clipChildren ?? curMinimapShape.clipChildren
    minimapState = minimapState
    transform = mapTransform
    behavior = Behaviors.Minimap
    children = ctorWatch.ctor(params)
  }
}

let function makeMinimap() {
  return {
    size = mapSize
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    clipChildren = curMinimapShape.clipChildren

    children = [
      blurredWorld,
      baseMap,
    ]
      .extend(mmChildrenCtors.map(@(c) mkMinimapLayer(c, commonLayerParams)))
      .append(
        mapHotKey
      )
  }
}

return makeMinimap
