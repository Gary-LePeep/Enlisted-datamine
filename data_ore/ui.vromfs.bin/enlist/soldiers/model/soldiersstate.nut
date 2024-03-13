from "%enlSqGlob/ui/ui_library.nut" import *

let { soldiersUpgradeAlerts } = require("unseenWeaponry.nut")
let { notChoosenPerkSoldiers } = require("soldierPerks.nut")
let {
  mkAlertIcon, PERK_ALERT_SIGN, UPGRADE_ALERT_SIGN
} = require("%enlSqGlob/ui/soldiersUiComps.nut")


const DEF_KIND = "rifle"


let mkAlertInfo = @(soldierInfo, _sf, _isSelected) {
  flow = FLOW_HORIZONTAL
  hplace = ALIGN_RIGHT
  vplace = ALIGN_TOP
  children = [
    mkAlertIcon(UPGRADE_ALERT_SIGN, Computed(@()
      soldiersUpgradeAlerts.value?[soldierInfo?.guid] ?? false
    ))
    mkAlertIcon(PERK_ALERT_SIGN, Computed(@()
      (notChoosenPerkSoldiers.value?[soldierInfo?.guid] ?? 0) > 0
    ))
  ]
}


let curSoldierKind = Watched(DEF_KIND)


return {
  mkAlertInfo
  curSoldierKind
  DEF_KIND
}
