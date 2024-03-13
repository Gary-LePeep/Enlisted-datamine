from "%enlSqGlob/ui/ui_library.nut" import *

let { fontHeading2 } = require("%enlSqGlob/ui/fontsStyle.nut")
let {
  strokeStyle, bigGap, armyIconSize, hoverTitleTxtColor, activeTitleTxtColor
} = require("%enlSqGlob/ui/designConst.nut")
let armiesPresentation = require("%enlSqGlob/ui/armiesPresentation.nut")

let mkIcon = @(sIcon, size, override) sIcon == null ? null : {
  rendObj = ROBJ_IMAGE
  size = [size, size]
  image = Picture("!ui/skin#{0}:{1}:{1}:K".subst(sIcon, size.tointeger()))
  keepAspect = KEEP_ASPECT_FIT
  imageHalign = ALIGN_CENTER
  imageValign = ALIGN_CENTER
  margin = bigGap
}.__update(override)

let mkArmyIcon = @(armyId, size = armyIconSize, override = {})
  mkIcon(armiesPresentation?[armyId].smallColorIcon ?? armyId, size, override)

let mkArmySimpleIcon = @(armyId, size = armyIconSize, override = {})
  mkIcon(armiesPresentation?[armyId].smallIcon ?? armyId, size, override)

let getArmyColor = @(selected, sf)
  selected || (sf & S_HOVER) ? hoverTitleTxtColor : activeTitleTxtColor

let mkArmyName = @(armyId, isSelected = false, sf = 0) {
  rendObj = ROBJ_TEXT
  text = loc(armyId)
  color = getArmyColor(isSelected, sf)
  vplace = ALIGN_CENTER
}.__update(fontHeading2, strokeStyle)

return {
  mkArmySimpleIcon
  mkArmyIcon
  mkArmyName
}
