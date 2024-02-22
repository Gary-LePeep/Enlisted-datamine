from "%enlSqGlob/ui/ui_library.nut" import *

function getPayItemsData(costData, campItems, count = 1) {
  if (costData == null || costData.len() == 0)
    return null
  let allAvailableItems = campItems.filter(@(item) (item.basetpl in costData))
  let res = {}
  foreach (payItemTpl, cost in costData) {
    if (cost == 0)
      continue
    local requiredItems = cost * count
    let inventoryItems = allAvailableItems.filter(@(item) item.basetpl == payItemTpl)
    foreach (i in inventoryItems) {
      res[i.guid] <- min(i.count, requiredItems)
      requiredItems -= i.count
      if (requiredItems <= 0)
        break
    }
    if (requiredItems > 0)
      return null
  }
  return res.len() > 0 ? res : null
}

return getPayItemsData