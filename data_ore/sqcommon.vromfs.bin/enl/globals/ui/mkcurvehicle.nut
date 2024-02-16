from "%enlSqGlob/ui_library.nut" import *

let {
  smallPadding, bigPadding, vehicleListCardSize, listCtors
} = require("%enlSqGlob/ui/viewConst.nut")
let { txtColor } = listCtors
let { iconByGameTemplate, getItemName } = require("%enlSqGlob/ui/itemsInfo.nut")
let { statusTier, mkNoVehicle, mkVehicleHint } = require("%enlSqGlob/ui/itemPkg.nut")
let { txt, autoscrollText } = require("%enlSqGlob/ui/defcomps.nut")
let { mkSpecialItemIcon } = require("%enlSqGlob/ui/mkSpecialItemIcon.nut")
let { getVehSkins } = require("%enlSqGlob/vehDecorUtils.nut")
let {
  squadSlotBgIdleColor, squadSlotBgHoverColor, disabledTxtColor
} = require("%enlSqGlob/ui/designConst.nut")
let { setTooltip } = require("%ui/style/cursors.nut")
let { isInBattleState } = require("%enlSqGlob/inBattleState.nut")
let { mkBattleRatingShort } = require("%enlSqGlob/ui/battleRatingPkg.nut")

let bgColor = @(sf, isAvailable) sf & S_HOVER ? squadSlotBgHoverColor
  : isAvailable ? squadSlotBgIdleColor
  : disabledTxtColor

let function mkVehicleImage(gametemplate, skinId) {
  let override = {
    width = vehicleListCardSize[0] - smallPadding * 2
    height = vehicleListCardSize[1] - smallPadding * 2
    genOverride = {}
  }
  if (skinId != null) {
    let skin = (getVehSkins(gametemplate) ?? []).findvalue(@(s) s.id == skinId)
    if ("objTexReplace" in skin)
      override.genOverride.objTexReplace <- skin.objTexReplace
  }

  return iconByGameTemplate(gametemplate, override)
}

let mkVehicleInfo = @(vehicleInfo, soldiersInSquad, sf) {
  size = flex()
  flow = FLOW_VERTICAL
  children = [
    {
      size = flex()
      flow = FLOW_HORIZONTAL
      gap = smallPadding
      children = [
        autoscrollText({
          vplace = ALIGN_BOTTOM
          text = getItemName(vehicleInfo)
          textParams = { color = txtColor(sf) }
        })
        {
          hplace = ALIGN_RIGHT
          children = statusTier(vehicleInfo)
        }
      ]
    }
    0 == (vehicleInfo?.crew ?? 0) ? null
      : txt({
          vplace = ALIGN_BOTTOM
          text = " ".join([loc("vehicleDetails/crew"), $"{soldiersInSquad}/{vehicleInfo.crew}"])
          color = txtColor(sf)
        })
  ]
}

let mkCurVehicle = @(
  vehicleInfo, soldiersList, openChooseVehicle = null, topRightChild = null,
  canSpawnOnVehicle = Watched(true)
) watchElemState(@(sf) {
    watch = [vehicleInfo, canSpawnOnVehicle, soldiersList, isInBattleState]
    size = [flex(), SIZE_TO_CONTENT]
    behavior = Behaviors.Button
    onClick = openChooseVehicle
    rendObj = ROBJ_SOLID
    color = bgColor(sf, canSpawnOnVehicle.value)
    onHover = @(on) setTooltip(!isInBattleState.value && on
      && vehicleInfo.value?.gametemplate != null
        ? mkVehicleHint(vehicleInfo.value)
        : null)
    children = (vehicleInfo.value?.gametemplate ?? "") == ""
      ? mkNoVehicle(sf)
      : [
          mkVehicleImage(vehicleInfo.value.gametemplate, vehicleInfo.value?.skin.id)
          mkSpecialItemIcon(vehicleInfo.value, hdpxi(26), { margin = 0 })
          {
            size = flex()
            flow = FLOW_HORIZONTAL
            padding = bigPadding
            halign = ALIGN_RIGHT
            children = [
              mkVehicleInfo(vehicleInfo.value, soldiersList.value.len(), sf)
              topRightChild
            ]
          }
          {
            vplace = ALIGN_BOTTOM
            hplace = ALIGN_RIGHT
            padding = bigPadding
            children = mkBattleRatingShort(vehicleInfo.value?.growthTier ?? 1)
          }
        ]
  })

return kwarg(mkCurVehicle)
