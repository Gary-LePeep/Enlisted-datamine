from "%enlSqGlob/ui_library.nut" import *

let { fontSub, fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let faComp = require("%ui/components/faComp.nut")
let {
  msgHighlightedTxtColor, smallPadding, hoverTxtColor, vehicleListCardSize, listCtors
} = require("%enlSqGlob/ui/viewConst.nut")
let { txtColor } = listCtors
let { defTxtColor } = require("%enlSqGlob/ui/designConst.nut")
let {
  statusIconChosen, statusIconDisabled, statusIconLocked
} =  require("%enlSqGlob/ui/style/statusIcon.nut")
let { soldierClasses } = require("%enlSqGlob/ui/soldierClasses.nut")
let { mkItemTier } = require("%enlSqGlob/ui/itemTier.nut")
let { getItemName, getItemDesc } = require("%enlSqGlob/ui/itemsInfo.nut")
let tooltipCtor = require("%ui/style/tooltipCtor.nut")
let { mkBattleRating } = require("%enlSqGlob/ui/battleRatingPkg.nut")

let iconSize = hdpx(15)
let badgeSize = hdpx(40)

let mkStatusIcon = @(icon, color) faComp(icon, {
  margin = smallPadding
  fontSize = iconSize
  color
})

let iconChosen = mkStatusIcon("check", statusIconChosen)
let iconBlocked = mkStatusIcon("ban", statusIconDisabled)

let mkBackBlock = @(children) {
  rendObj = ROBJ_BOX
  size = array(2, hdpx(19))
  borderWidth = 0
  borderRadius = hdpx(5)
  fillColor = statusIconLocked
  clipChildren = true
  margin = smallPadding
  valign = ALIGN_CENTER
  children = children
}

let iconLocked = faComp("lock", {
  size = array(2, hdpx(19))
  fontSize = iconSize
  color = statusIconLocked
})

let mkIconWarning = @(size) faComp("warning", {
  vplace = ALIGN_CENTER
  hplace = ALIGN_CENTER
  fontSize = size
  color = statusIconLocked
  animations = [{ prop = AnimProp.opacity, from = 0.5, to = 1, duration = 1.0, play = true, loop = true, easing = CosineFull }]
})

let mkLevelBlock = @(level) mkBackBlock({
  rendObj = ROBJ_TEXT
  size = [flex(), SIZE_TO_CONTENT]
  halign = ALIGN_CENTER
  text = level
  color = hoverTxtColor
}.__update(fontSub))

let statusIconCtor = @(demands) demands?.classLimit != null ? iconBlocked
  : demands == null ? null
  : demands?.canObtainInShop ? null
  : iconLocked

let mkHintText = @(text, params = fontSub) {
  rendObj = ROBJ_TEXTAREA
  size = [flex(), SIZE_TO_CONTENT]
  behavior = Behaviors.TextArea
  text = text
  color = msgHighlightedTxtColor
}.__update(params)

let mkStatusHint = @(demands) demands == null ? null
  : demands?.classLimit != null ? mkHintText(loc("itemClassResearch", {
      soldierClass = loc(soldierClasses?[demands.classLimit].locId ?? "unknown")
    }))
  : demands?.levelLimit != null ? mkHintText(loc("itemObtainAtLevel", {
      level = demands.levelLimit
    }))
  : mkHintText(loc(demands?.canObtainInShop ? "itemObtainInShop" : "itemOutOfStock"))

let function mkVehicleHint(vehicle) {
  let desc = getItemDesc(vehicle)
  let { growthTier = 0 } = vehicle
  return tooltipCtor({
    flow = FLOW_VERTICAL
    minWidth = hdpx(350)
    maxWidth = hdpx(500)
    gap = smallPadding
    children = [
      {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        children = [
          mkHintText(getItemName(vehicle), { color = defTxtColor }.__update(fontBody))
          mkItemTier(vehicle)
        ]
      }
      desc == "" ? null : mkHintText(desc, { color = defTxtColor })
      mkBattleRating(growthTier)
    ]
  })
}

let statusBadgeWarning = mkIconWarning(badgeSize)

let mkNoVehicle = @(sf, color = null) {
  size = [flex(), vehicleListCardSize[1] - smallPadding * 2]
  children = [
    {
      rendObj = ROBJ_TEXT
      hplace = ALIGN_CENTER
      text = loc("menu/vehicle/none")
      color = color ?? txtColor(sf)
    }.__update(fontSub)
    statusBadgeWarning
  ]
}

return {
  statusIconLocked = iconLocked
  statusIconChosen = iconChosen
  statusIconBlocked = iconBlocked
  statusIconCtor = statusIconCtor
  statusIconWarning = mkIconWarning(iconSize)
  statusBadgeWarning
  statusLevel = mkLevelBlock
  statusTier = mkItemTier
  hintText = mkHintText
  statusHintText = mkStatusHint
  mkVehicleHint
  mkNoVehicle
}