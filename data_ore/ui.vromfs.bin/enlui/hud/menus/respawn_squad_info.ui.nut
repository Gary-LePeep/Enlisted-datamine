from "%enlSqGlob/ui/ui_library.nut" import *

let mkMainSoldiersBlock = require("%enlSqGlob/ui/mkSoldiersList.nut")
let mkCurVehicle = require("%enlSqGlob/ui/mkCurVehicle.nut")
let {
  soldiersList, curSoldierIdx, canSpawnOnVehicleBySquad, vehicleInfo, squadIndexForSpawn
} = require("%ui/hud/state/respawnState.nut")
let armyData = require("%ui/hud/state/armyData.nut")
let { mkGrenadeIcon } = require("%ui/hud/huds/player_info/grenadeIcon.nut")
let { mkMineIcon } = require("%ui/hud/huds/player_info/mineIcon.nut")
let mkMedkitIcon = require("%ui/hud/huds/player_info/medkitIcon.nut")
let mkRepairIcon = require("%ui/hud/huds/player_info/repairIcon.nut")
let { defTxtColor, darkTxtColor, smallPadding } = require("%enlSqGlob/ui/designConst.nut")
let mkFlaskIcon = require("%ui/hud/huds/player_info/flaskIcon.nut")

let sIconSize = hdpxi(15)

let canSpawnOnVehicle = Computed(@()
  canSpawnOnVehicleBySquad.value?[squadIndexForSpawn.value] ?? false)

let function addCardChild(soldier, sf, _isSelected) {
  let { grenadeType = null, mineType = null, targetHealCount = 0, targetRepairCount = 0, hasFlask = false } = soldier
  let color = sf & S_HOVER ? darkTxtColor : defTxtColor
  return {
    hplace = ALIGN_RIGHT
    vplace = ALIGN_RIGHT
    flow = FLOW_HORIZONTAL
    gap = hdpx(2)
    padding = smallPadding
    children = [
      targetHealCount > 0 ? mkMedkitIcon(sIconSize, color) : null
      targetRepairCount > 0 ? mkRepairIcon(sIconSize, color) : null
      hasFlask ? mkFlaskIcon(sIconSize, color) : null
      mkGrenadeIcon(grenadeType, sIconSize, color) ?? mkMineIcon(mineType, sIconSize, color)
    ]
  }
}

return mkMainSoldiersBlock({
  soldiersListWatch = soldiersList
  expToLevelWatch = Computed(@() armyData.value?.expToLevel)
  vehicleInfo
  hasVehicleWatch = Computed(@() vehicleInfo.value != null)
  curSoldierIdxWatch = curSoldierIdx
  curVehicleUi = mkCurVehicle({ canSpawnOnVehicle, vehicleInfo, soldiersList })
  canDeselect = false
  addCardChild
})
