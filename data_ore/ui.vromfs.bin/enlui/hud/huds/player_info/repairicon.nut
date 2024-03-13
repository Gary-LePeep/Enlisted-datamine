from "%enlSqGlob/ui/ui_library.nut" import *

let repairIcon = memoize(@(size)
  Picture("ui/skin#item_repair_kit.svg:{0}:{0}:K".subst(size)))

let mkRepairIcon = memoize(@(size, color) {
  size = [size, size]
  rendObj = ROBJ_IMAGE
  color
  image = repairIcon(size)
})

return mkRepairIcon