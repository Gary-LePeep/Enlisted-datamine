from "%enlSqGlob/ui/ui_library.nut" import *

let { configs } = require("%enlist/meta/configs.nut")
let { rewardsPresentation, mkReward } = require("itemsPresentation.nut")
let userInfo = require("%enlSqGlob/userInfo.nut")

let itemMapping = Computed(function() {
  let { addItemMapping = null } = configs.value
  let res = clone rewardsPresentation
  if (addItemMapping == null)
    return res

  let { nameorig = "" } = userInfo.value
  foreach (key, reward in addItemMapping)
    res[key] <- reward.__merge(res?[key] ?? {}, mkReward(reward, nameorig) ?? {})
  return res
})

return itemMapping
