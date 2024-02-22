from "%enlSqGlob/ui/ui_library.nut" import *
let { SHOP_SECTION, curArmyShopItems } = require("%enlist/shop/armyShopState.nut")
let { curSection } = require("%enlist/mainMenu/sectionsState.nut")
let { getShopItemsIds, requestCratesContent } = require("%enlist/soldiers/model/cratesContent.nut")
let { metaGen } = require("%enlist/meta/metaConfigUpdater.nut")

let shopItemsToRequest = keepref(Computed(function() {
  return curSection.value == SHOP_SECTION ? getShopItemsIds(curArmyShopItems.value) : []
}))

shopItemsToRequest.subscribe(@(items) requestCratesContent(items))
metaGen.subscribe(function(v) {
  if (v != 0) // meta is default, no need to update
    requestCratesContent(shopItemsToRequest.value)
})