from "%enlSqGlob/ui/ui_library.nut" import *

let buySquadWindow = require("buySquadWindow.nut")
let buyShopItem = require("buyShopItem.nut")
let activatePremiumBttn = require("activatePremiumBtn.nut")
let viewShopItemsScene = require("viewShopItemsScene.nut")
let { allItemTemplates } = require("%enlist/soldiers/model/all_items_templates.nut")
let { shopItemContentCtor, curArmyShopFolder, purchaseIsPossible, setCurArmyShopPath
} = require("armyShopState.nut")
let { mkShopMsgBoxView, mkCanUseShopItemInfo } = require("shopPackage.nut")
let { shopItemLockedMsgBox, mkProductView } = require("shopPkg.nut")
let checkLootRestriction = require("hasLootRestriction.nut")
let { getCantBuyDataOnClick } = require("shopState.nut")
let { curArmyData } = require("%enlist/soldiers/model/state.nut")


function shopItemAction(shopItem, isNotSuitable = false) {
  let { guid = "" } = curArmyData.value
  let { squads = [] } = shopItem
  let squad = squads.findvalue(@(s) s.armyId == guid) ?? squads?[0]
  let isBuyingWithGold = shopItem?.curShopItemPrice.currencyId == "EnlistedGold"
  let countWatched = Watched(1)
  let crateContent = shopItemContentCtor(shopItem)
  let hasItemContent = crateContent == null ? false
    : (crateContent.value?.content.items ?? {}).len() > 0

  let lockData = getCantBuyDataOnClick(shopItem)

  if ((shopItem?.offerContainer ?? "") != "")
    setCurArmyShopPath((clone curArmyShopFolder.value.path).append(shopItem))
  else if (lockData != null)
    shopItemLockedMsgBox(lockData)
  else if (purchaseIsPossible.value) {
    let description = mkCanUseShopItemInfo(crateContent)
    let productView = mkShopMsgBoxView(shopItem, crateContent, countWatched)
    if (squad != null && isBuyingWithGold)
      buySquadWindow({
        shopItem
        productView
        armyId = squad.armyId
        squadId = squad.id
      })
    else {
      let buyItemAction = @() buyShopItem({
        shopItem
        activatePremiumBttn
        productView
        description
        viewBtnCb = hasItemContent ? @() viewShopItemsScene(shopItem) : null
        countWatched
        isNotSuitable
      })
      checkLootRestriction(buyItemAction,
        {
          itemView = mkProductView(shopItem, allItemTemplates, crateContent)
          description
        },
        crateContent)
    }
  }
}

return shopItemAction
