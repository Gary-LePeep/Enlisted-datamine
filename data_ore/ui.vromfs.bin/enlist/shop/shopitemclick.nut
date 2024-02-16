from "%enlSqGlob/ui_library.nut" import *

let buySquadWindow = require("buySquadWindow.nut")
let buyShopItem = require("buyShopItem.nut")
let activatePremiumBttn = require("activatePremiumBtn.nut")
let viewShopItemsScene = require("viewShopItemsScene.nut")
let checkLootRestriction = require("hasLootRestriction.nut")

let { curArmyData } = require("%enlist/soldiers/model/state.nut")
let { allItemTemplates } = require("%enlist/soldiers/model/all_items_templates.nut")
let { getCantBuyDataOnClick } = require("shopState.nut")
let { shopItemContentCtor, purchaseIsPossible, needGoodManage
} = require("armyShopState.nut")
let { shopItemLockedMsgBox, mkProductView } = require("shopPkg.nut")
let { mkShopMsgBoxView, mkCanUseShopItemInfo } = require("shopPackage.nut")


let function shopItemClick(shopItem) {
  let lockData = getCantBuyDataOnClick(shopItem)
  if (lockData != null)
    return shopItemLockedMsgBox(lockData)
  if (!purchaseIsPossible.value)
    return

  let { guid = "" } = curArmyData.value
  let { curShopItemPrice = null, squads = [] } = shopItem


  let countWatched = Watched(1)
  let crateContent = shopItemContentCtor(shopItem)
  let hasItemContent = crateContent == null ? false
    : (crateContent.value?.content.items ?? {}).len() > 0

  let productView = mkShopMsgBoxView(shopItem, crateContent, countWatched)
  let isBuyingWithGold = curShopItemPrice?.currencyId == "EnlistedGold"
  let squad = squads.findvalue(@(s) s.armyId == guid) ?? squads?[0]
  if (squad != null && isBuyingWithGold) {
    buySquadWindow({
      shopItem
      productView
      armyId = squad.armyId
      squadId = squad.id
    })
    return
  }

  let description = mkCanUseShopItemInfo(crateContent)
  let buyItemActionCb = function() {
    buyShopItem({
      shopItem
      activatePremiumBttn
      productView
      description
      viewBtnCb = hasItemContent ? @() viewShopItemsScene(shopItem) : null
      countWatched
      needCheckAndBuy = true
    })
    needGoodManage(true)
  }
  let itemView = mkProductView(shopItem, allItemTemplates, crateContent)
  checkLootRestriction(buyItemActionCb, { itemView, description }, crateContent)
}

return shopItemClick
