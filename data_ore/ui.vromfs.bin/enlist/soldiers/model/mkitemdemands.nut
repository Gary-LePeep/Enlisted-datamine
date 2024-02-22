from "%enlSqGlob/ui/ui_library.nut" import *

let { curArmyData, curArmy } = require("state.nut")
let { getCantBuyData } = require("%enlist/shop/shopPkg.nut")
let { curGrowthState, curGrowthConfig, curGrowthProgress, curGrowthTiers
} = require("%enlist/growth/growthState.nut")
let { allItemTemplates } = require("%enlist/soldiers/model/all_items_templates.nut")
let { getShopItems, curArmyItemsPrefiltered } = require("%enlist/shop/armyShopState.nut")
let { itemToShopItem } = require("%enlist/soldiers/model/cratesContent.nut")


let growthDemand = {
  lockTxt = loc("itemDemandsHeader/classLimit")
}

let shopDemand = {
  lockTxt = loc("itemDemandsHeader/canObtainInShop_yes")
  canObtainInShop = true
}

// Caveat: This method will only work correctly for items demands check of the currently selected army
function mkItemListDemands(items) {
  if (typeof items != "array")
    items = [items]
  return Computed(function() {
    return items.map(function(item) {
      if (item?.isShopItem) {
        let shopItems = getShopItems(item?.basetpl, curArmy.value, itemToShopItem.value,
          allItemTemplates.value, curArmyItemsPrefiltered.value)
        let shopItem = shopItems?[0]
        let demands = getCantBuyData(curArmyData.value,
          shopItem?.requirements,
          curGrowthState.value,
          curGrowthConfig.value,
          curGrowthProgress.value,
          curGrowthTiers.value,
          allItemTemplates.value)
        return {
          item
          demands = !demands ? shopDemand
            : demands?.growthRequired ? growthDemand
            : demands
        }
      }

      return { item }
    })
  })
}

function mkItemDemands(item) {
  let demands = mkItemListDemands(item)
  return Computed(@() demands.value?[0].demands)
}

return {
  mkItemDemands
  mkItemListDemands
}