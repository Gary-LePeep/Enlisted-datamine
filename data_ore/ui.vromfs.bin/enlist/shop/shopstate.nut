from "%enlSqGlob/ui/ui_library.nut" import *

let serverTime = require("%enlSqGlob/userstats/serverTime.nut")
let squadsParams = require("%enlist/soldiers/model/squadsParams.nut")
let { getCantBuyData } = require("shopPkg.nut")
let { allItemTemplates } = require("%enlist/soldiers/model/all_items_templates.nut")
let { curArmyData, curChoosenSquads } = require("%enlist/soldiers/model/state.nut")
let { shopItems } = require("shopItems.nut")
let { curCampSoldiers } = require("%enlist/meta/profile.nut")
let { curUnseenAvailShopGuids, notOpenedShopItems, curArmyItemsPrefiltered } = require("armyShopState.nut")
let {
  curGrowthState, curGrowthConfig, curGrowthProgress, curGrowthTiers
} = require("%enlist/growth/growthState.nut")
let { classSlotLocksByArmy } = require("%enlist/researches/researchesSummary.nut")
let {
  getObjectsByLinkSorted, getLinkedArmyName, getItemIndex
} = require("%enlSqGlob/ui/metalink.nut")

let curSwitchTime = Watched(0)

function updateSwitchTime(...) {
  let currentTs = serverTime.value
  let nextTime = shopItems.value.reduce(function(firstTs, item) {
    let { showIntervalTs = null } = item
    if ((showIntervalTs?.len() ?? 0) == 0)
      return firstTs

    let [from, to = 0] = showIntervalTs
    return (currentTs < from && (from < firstTs || firstTs == 0)) ? from
      : (currentTs < to && (to < firstTs || firstTs == 0)) ? to
      : firstTs
  }, 0) - currentTs
  if (nextTime > 0)
    gui_scene.resetTimeout(nextTime, updateSwitchTime)
  curSwitchTime(currentTs)
}

function onServerTime(t) {
  if (t <= 0)
    return
  serverTime.unsubscribe(callee())
  updateSwitchTime()
}


function onShopAttach(){
  serverTime.subscribe(onServerTime)
  shopItems.subscribe(updateSwitchTime)
}

function onShopDetach(){
  serverTime.unsubscribe(onServerTime)
  shopItems.unsubscribe(updateSwitchTime)
}


let curGroupIdx = Watched(0)
let curFeaturedIdx = Watched(0)
let chapterIdx = Watched(-1)
let curSelectionShop = Watched(null)

function canBarterItem(item, armyItemCount) {
  foreach (payItemTpl, cost in item.curItemCost)
    if ((armyItemCount?[payItemTpl] ?? 0) < cost)
      return false
  return true
}

let isTemporaryVisible = @(itemId, shopItem, itemCount, itemsByTime)
  ((shopItem?.isVisibleIfCanBarter ?? false) && canBarterItem(shopItem, itemCount))
    || itemId in itemsByTime

function mkShopState() {
  let shownByTimestamp = Computed(function() {
    let res = {}
    let ts = curSwitchTime.value
    foreach (id, item in shopItems.value) {
      let { showIntervalTs = null } = item
      if ((showIntervalTs?.len() ?? 0) == 0)
        continue

      let [from, to = 0] = showIntervalTs
      if (from <= ts && (ts < to || to == 0))
        res[id] <- true
    }
    return res
  })

  let mainOrders = {
    enlisted_silver = true
    weapon_order = true
    soldier_order = true
    weapon_order_silver = true
    soldier_order_silver = true
    weapon_order_gold = true
    soldier_order_gold = true
    vehicle_with_skin_order_gold = true
  }

  function hasPriceContainsGold(shopItem) {
    let { price = 0, currencyId = "" } = shopItem?.shopItemPrice
    return currencyId == "EnlistedGold" && price > 0
  }

  function hasPriceContainsOrders(shopItem) {
    let { itemCost = {} } = shopItem
    return itemCost.len() > 0
  }

  function hasPriceContainsSpecOrders(shopItem) {
    foreach (orderId, price in shopItem?.itemCost ?? {})
      if (orderId not in mainOrders && price > 0)
        return true
    return false
  }

  function isExternalPurchase(shopItem) {
    let { shop_price = 0, shop_price_curr = "", storeId = "", devStoreId = "" } = shopItem
    return (shop_price_curr != "" && shop_price > 0) //PC type
      || storeId != "" || devStoreId != ""//Consoles type
  }

  function premFilterFunc(shopItem) {
    if (hasPriceContainsSpecOrders(shopItem))
      return true

    if (hasPriceContainsOrders(shopItem))
      return false

    return ((hasPriceContainsGold(shopItem) || isExternalPurchase(shopItem))
      && shopItem?.offerGroup != "enlisted_silver")
  }

  let bpGroupsChapters = {
    weapon_battlepass_group = 0
    soldier_battlepass_group = 1
    vehicle_battlepass_group = 2
  }

  let itemsGroupsChapters = {
    wpack_silver_pistol_group = 0
    wpack_silver_rifle_group = 1
    wpack_silver_submachine_gun_group = 2
    wpack_silver_special_group = 3
    item_group = 4
  }


  let sortItemsFunc = @(a, b) (a?.viewOrder ?? 1000) <=> (b?.viewOrder ?? 1000)
    || (a?.requirements.armyLevel ?? 0) <=> (b?.requirements.armyLevel ?? 0)

  let sortFeaturedFunc = @(a, b)
    (a?.featuredWeight ?? 0) <=> (b?.featuredWeight ?? 0)
      || (a?.requirements.armyLevel ?? 0) <=> (b?.requirements.armyLevel ?? 0)

  function getChapterItems(armyItems, chapterScheme) {
    let chapters = chapterScheme.map(@(weigth) { container = null, goods = [], weigth })
    foreach (sItem in armyItems) {
      let { offerContainer = "", offerGroup = "" } = sItem
      if (offerContainer in chapters)
        chapters[offerContainer].container = sItem
      if (offerGroup in chapters)
        chapters[offerGroup].goods.append(sItem)
    }
    chapters.each(@(chapter) chapter.goods.sort(sortItemsFunc))
    return chapters.values().sort(@(a, b) a.weigth <=> b.weigth)
  }

  let armyGroups = [
    {
      id = "premium"
      reqFeatured = true
      autoseenDelay = true
      filterFunc = premFilterFunc
    }
    {
      id = "battlepass"
      mkChapters = @(armyShopItems) getChapterItems(armyShopItems, bpGroupsChapters)
    }
    {
      id = "weapon"
      locId = "soldierWeaponry"
      mkChapters = @(armyShopItems) getChapterItems(armyShopItems, itemsGroupsChapters)
    }
    {
      id = "soldier"
      locId = "menu/soldier"
      filterFunc = @(shopItem)
        shopItem?.offerGroup == "soldier_silver_group"
    }
    {
      id = "silver"
      filterFunc = @(shopItem) shopItem?.offerGroup == "enlisted_silver"
    }
  ]


  let curItemsByGroup = Computed(function() {
    let prefilteredItems = curArmyItemsPrefiltered.value
    let res = {}
    foreach (group in armyGroups) {
      let { filterFunc = null, mkChapters = null } = group
      if (mkChapters != null) {
        let groupRes = []
        foreach (chapter in mkChapters(prefilteredItems))
          foreach (sItem in chapter.goods)
            groupRes.append(sItem)
        res[group.id] <- groupRes
      }
      else if (filterFunc != null)
        res[group.id] <- prefilteredItems
          .reduce(function(r, val) {
            if (filterFunc(val))
              r.append(val)
            return r
          }, [])
          .sort(sortItemsFunc)
    }
    return res
  })


  let curShopItemsByGroup = Computed(function() {
    let items = curItemsByGroup.value
    let armyItems = curArmyItemsPrefiltered.value
    return armyGroups.map(function(group) {
      let { mkChapters = null } = group
      return {
        id = group.id
        locId = group?.locId
        autoseenDelay = group?.autoseenDelay ?? false
        goods = (items?[group.id] ?? []).filter(@(item) (item?.featuredWeight ?? 0) == 0)
        chapters = mkChapters?(armyItems)
      }
    })
  })


  let maxDiscountByGroup = Computed(@() curItemsByGroup.value
    .map(@(group) group.reduce(@(r, v) max(r, v?.hideDiscount ? 0 : v?.discountInPercent ?? 0), 0)))

  let specialOfferByGroup = Computed(@() curItemsByGroup.value
    .map(@(group) group
      .findvalue(@(v) (v?.discountInPercent ?? 0) > 0 && v?.showSpecialOfferText) != null))

  let curFeaturedByGroup = Computed(@() curItemsByGroup.value
    .map(@(group) group
      .filter(@(item) (item?.featuredWeight ?? 0) > 0)
      .sort(sortFeaturedFunc)
    ))


  let curShopDataByGroup = Computed(function() {
    let curUnseen = curUnseenAvailShopGuids.value
    let curUnopened = {}
    foreach (guid in notOpenedShopItems.value)
      curUnopened[guid] <- true

    let maxDiscounts = maxDiscountByGroup.value
    let specialOffer = specialOfferByGroup.value
    let res = {}
    foreach (id, group in curItemsByGroup.value)
      res[id] <- {
        hasUnseen = group.findvalue(@(v) v.guid in curUnseen) != null
        unopened = group.filter(@(v) v.guid in curUnopened).map(@(v) v.guid)
        discount = maxDiscounts?[id] ?? 0
        showSpecialOffer = specialOffer?[id] ?? false
      }

    return res
  })

  function switchGroup() {
    let grCount = curShopItemsByGroup.value.len()
    curGroupIdx((curGroupIdx.value + 1) % grCount)
    chapterIdx(-1)
  }

  function autoSwitchNavigation() {
    let groups = curShopItemsByGroup.value
    let { group = null, chapter = null } = curSelectionShop.value
    local groupIndex, chapterIndex

    curSelectionShop(null)

    if (chapter)
      foreach (k,v in groups) {
        chapterIndex = v.chapters?.findindex(@(g) g.container?.offerContainer == chapter)
        if (chapterIndex != null) {
          groupIndex = k
          break
        }
      }

    if (group) {
      groupIndex = groups.findindex(@(g) g.id == group)
    }

    if (groupIndex != null)
      curGroupIdx(groupIndex)
    if (chapterIndex != null)
      chapterIdx(chapterIndex)
    // TODO: need add function open item shop
  }

  return {
    curShopItemsByGroup
    curShopDataByGroup
    curFeaturedByGroup
    switchGroup
    autoSwitchNavigation
    shownByTimestamp
  }
}


let getCantBuyDataOnClick = @(shopItem)
  getCantBuyData(curArmyData.value,
    shopItem?.requirements,
    curGrowthState.value,
    curGrowthConfig.value,
    curGrowthProgress.value,
    curGrowthTiers.value,
    allItemTemplates.value)


function getGoodManageObject(manageData) {
  if (manageData == null)
    return null
  let { soldier = null, weapon = null } = manageData

  if (soldier != null) {
    let allSquadsParams = squadsParams.value
    let { sClass } = soldier
    foreach (squad in curChoosenSquads.value) {
      let armyId = getLinkedArmyName(squad)
      let suitableClasses = allSquadsParams?[armyId][squad.squadId].maxClasses ?? {}
      if ((suitableClasses?[sClass] ?? 0) > 0)
        return { squadId = squad.squadId }
    }
  }

  else if (weapon != null) {
    let { itemtype } = weapon
    foreach (squad in curChoosenSquads.value) {
      let armyId = getLinkedArmyName(squad)
      foreach(squadSoldier in getObjectsByLinkSorted(curCampSoldiers.value, squad.guid, "squad")) {
        let { sClass, equipScheme } = squadSoldier
        foreach(slotName, slotData in equipScheme)
          if ((slotData?.itemTypes ?? []).contains(itemtype)) {
            let locked = (classSlotLocksByArmy.value?[armyId][sClass] ?? []).contains(slotName)
            if (!locked)
              return {
                squadId = squad.squadId
                soldierIdx = getItemIndex(squadSoldier)
                manageSlotType = slotName
              }
          }
      }
    }
  }

  return null
}


return {
  mkShopState
  onShopAttach
  onShopDetach
  curGroupIdx
  curFeaturedIdx
  chapterIdx
  curSwitchTime
  setAutoGroup = @(group) curSelectionShop({group})
  setAutoChapter = @(chapter) curSelectionShop({chapter})

  canBarterItem
  isTemporaryVisible
  getCantBuyDataOnClick
  getGoodManageObject
}
