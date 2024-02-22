let { isProductionCircuit } = require("%dngscripts/appInfo.nut")
let { buyItemByGuid, buyItemByStoreId } = require("%enlist/shop/armyShopState.nut")

let canBuyItem = @(shopItem) (shopItem?.devStoreId ?? "") != ""
  || (shopItem?.storeId ?? "") != ""
  || (shopItem?.purchaseGuid ?? "") != ""

function buyItemAction(shopItem) {
  //In case, when pack in release and dev store is distinguishable
  if (!isProductionCircuit.value) {
    let { devStoreId = "" } = shopItem
    if (devStoreId != "") {
      buyItemByStoreId(devStoreId)
      return true
    }
  }

  let { storeId = "" } = shopItem
  if (storeId != "") {
    buyItemByStoreId(storeId)
    return true
  }

  // buy on website, no msg window ingame:
  let { purchaseGuid = "" } = shopItem
  if (purchaseGuid != "")
    if (buyItemByGuid(purchaseGuid)) {
      return true
    }

  return false
}

return {
  canBuyItem
  buyItemAction
}