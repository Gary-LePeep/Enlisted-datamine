from "%enlSqGlob/ui/ui_library.nut" import *

let defTransform = {}

let arrowSize = [hdpxi(27), hdpxi(13)]
let arrowPos = [0, 0]
let arrowImage = Picture("ui/skin#v_arrow.svg:{0}:{1}:K".subst(arrowSize[0], arrowSize[1]))
let makeArrow = kwarg(function(yOffs = 0, pos = arrowPos, anim=null, color=null, key=null) {
  return {
    markerFlags = MARKER_ARROW
    transform = defTransform
    pos = [0, yOffs]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = {
      rendObj = ROBJ_IMAGE
      image = arrowImage
      key = key ?? anim
      size = arrowSize
      color
      pos
      animations = anim
    }
  }
})

return {
  makeArrow
}