from "%enlSqGlob/ui/ui_library.nut" import *

let buySquadWindow = require("buySquadWindow.nut")
let buyShopItem = require("buyShopItem.nut")
let activatePremiumBttn = require("activatePremiumBtn.nut")
let viewShopItemsScene = require("viewShopItemsScene.nut")
let checkLootRestriction = require("hasLootRestriction.nut")
let shopItemCompositeWindow = require("shopItemCompositeWindow.nut")

let { curArmyData } = require("%enlist/soldiers/model/state.nut")
let { allItemTemplates } = require("%enlist/soldiers/model/all_items_templates.nut")
let { getCantBuyDataOnClick } = require("shopState.nut")
let { shopItemContentCtor, purchaseIsPossible, needGoodManage
} = require("armyShopState.nut")
let { shopItemLockedMsgBox, mkProductView } = require("shopPkg.nut")
let { mkShopMsgBoxView, mkCanUseShopItemInfo } = require("shopPackage.nut")
let { shopItemsBase } = require("shopItems.nut")
let { deep_clone } = require("%sqstd/underscore.nut")
let { purchasesCount } = require("%enlist/meta/servProfile.nut")


function addIncludesShopItems(shopItem) {
  if ((shopItem?.includes ?? []).len() == 0)
    return shopItem

  let res = deep_clone(shopItem)
  let allShopItems = shopItemsBase.value
  let purchases = purchasesCount.value
  local { squads = [], decorators = [], premiumDays = 0, announcements = [] } = res
  foreach (guid in (res?.includes ?? [])) {
    let includesShopItem = allShopItems?[guid]
    if ((purchases?[guid].amount ?? 0) > 0)
      continue

    foreach (squadData in (includesShopItem?.squads ?? []))
      squads.append(squadData)
    foreach (decoratorData in (includesShopItem?.decorators ?? []))
      decorators.append(decoratorData)

    premiumDays += (includesShopItem?.premiumDays ?? 0)
    foreach (announcement in (includesShopItem?.announcements ?? [])) {
      let idx = announcements.findindex(@(a) a.announcementId == announcement.announcementId)
      if (idx == null)
        announcements.append(announcement)
      else
        announcements[idx].count += announcement.count
    }
  }

  res.squads <- squads
  res.decorators <- decorators
  res.announcements <- announcements
  res.premiumDays <- premiumDays
  return res
}


function isShopItemComposite(shopItem) {
  let { squads = [], decorators = [] } = shopItem
  return squads.len() > 1 || (squads.len() > 0 && decorators.len() > 0)
}


function shopItemClick(shopItem) {
  let lockData = getCantBuyDataOnClick(shopItem)
  if (lockData != null)
    return shopItemLockedMsgBox(lockData)
  if (!purchaseIsPossible.value)
    return

  let { guid = "" } = curArmyData.value
  let { curShopItemPrice = null, squads = [] } = shopItem

  let sItemFinal = addIncludesShopItems(shopItem)
  if (isShopItemComposite(sItemFinal)) {
    shopItemCompositeWindow({
      shopItem = sItemFinal
    })
    return
  }

  let countWatched = Watched(1)
  let crateContent = shopItemContentCtor(shopItem)
  let hasItemContent = crateContent == null ? false
    : (crateContent.value?.content.items ?? {}).len() > 0

  let productView = mkShopMsgBoxView(shopItem, crateContent, countWatched)
  let isBuyingWithGold = curShopItemPrice?.currencyId == "EnlistedGold"
  let squad = squads.findvalue(@(s) s.armyId == guid) ?? squads?[0]
  if (squad != null && isBuyingWithGold) {
    buySquadWindow({
      shopItem = shopItem
      productView
      armyId = squad.armyId
      squadId = squad.id
    })
    return
  }

  let description = mkCanUseShopItemInfo(crateContent)
  let buyItemActionCb = function() {
    buyShopItem({
      shopItem = shopItem
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

return {
  shopItemClick
  isShopItemComposite
}
