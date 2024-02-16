const USSR    = "ussr"
const GERMANY = "ger"
const USA     = "usa"
const JAPAN   = "jap"

let renameCommonArmies = {
  moscow_allies     = USSR
  moscow_axis       = GERMANY
  berlin_allies     = USSR
  berlin_axis       = GERMANY
  normandy_allies   = USA
  normandy_axis     = GERMANY
  tunisia_allies    = USA
  tunisia_axis      = GERMANY
  stalingrad_allies = USSR
  stalingrad_axis   = GERMANY
  pacific_allies    = USA
  pacific_axis      = JAPAN
}

let campaignsByArmies = renameCommonArmies.reduce(function(res, newArmy, oldArmy) {
  let campaign = oldArmy.slice(0, oldArmy.indexof("_"))
  if (res?[newArmy] == null)
    res[newArmy] <- [campaign]
  else if (!res[newArmy].contains(campaign))
    res[newArmy].append(campaign)
  return res
}, {})

return {
  renameCommonArmies
  campaignsByArmies
}
