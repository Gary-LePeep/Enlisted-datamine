from "%enlSqGlob/ui/ui_library.nut" import *

let { itemUpgrades, itemDisposes, getModifyConfig } = require("config/itemsModifyConfig.nut")
let { ceil } = require("%sqstd/math.nut")
let { getLinkedArmyName, isObjLinkedToAnyOfObjects } = require("%enlSqGlob/ui/metalink.nut")
let { upgradeLocksByArmy, upgradeCostMultByArmy, disposeCountMultByArmy
} = require("%enlist/researches/researchesSummary.nut")
let { armyItemCountByTpl } = require("state.nut")
let { allItemTemplates, findItemTemplate } = require("all_items_templates.nut")
let { hasShopSection } = require("%enlist/mainMenu/disabledSections.nut")
let { trimUpgradeSuffix } = require("%enlSqGlob/ui/itemsInfo.nut")
let { curUpgradeDiscount } = require("%enlist/campaigns/campaignConfig.nut")
let { curCampSoldiers, curCampItems } = require("%enlist/meta/profile.nut")

let disposableTypes = {
  sideweapon = true
  launcher = true
  flaregun = true
  antitank_rifle = true
  mortar = true
  flamethrower = true
  scope = true
  bayonet = true
  melee = true
  axe = true
  sword = true
  medkits = true
  repair_kit = true
  shovel = true
  binoculars_usable = true
  flask_usable = true
  molotov = true
  grenade = true
  tnt_block_exploder = true
  explosion_pack = true
  smoke_grenade = true
  impact_grenade = true
  incendiary_grenade = true
  antitank_mine = true
  antipersonnel_mine = true
  lunge_mine = true
  small_backpack = true
  backpack = true
}

let canUpgrade = @(item)
   (item?.guid ?? "") != "" && (item?.upgradeitem ?? "") != ""

let mkItemUpgradeData = function(item) {
  if (!canUpgrade(item))
    return Computed(@() { isUpgradable = false })

  let { basetpl = "", tier = 0, upgradeitem = "" } = item
  let itemBaseTpl = trimUpgradeSuffix(basetpl)
  let armyId = getLinkedArmyName(item)
  return Computed(function() {

    let res = {
      isUpgradable = false
      isResearchRequired = false
      armyId
      hasEnoughOrders = false
      upgradeMult = null
      itemBaseTpl
      upgradeitem
      guids = []
      priceOptions = []
    }

    if (!hasShopSection.value)
      return res

    let itemType = findItemTemplate(allItemTemplates, armyId, itemBaseTpl).itemtype
    let upgrades = getModifyConfig(itemUpgrades.value, tier, itemType)
    if (upgrades == null)
      return res

    let lockedUpgrades = upgradeLocksByArmy.value?[armyId] ?? []
    if (lockedUpgrades.indexof(upgradeitem) != null)
      return res.__update({ isUpgradable = true, isResearchRequired = true })

    local upgradeMult = upgradeCostMultByArmy.value?[armyId][itemBaseTpl] ?? 1.0
    upgradeMult *= 1.0 - curUpgradeDiscount.value
    local canBuy = false
    local maxBuyCount = 0

    foreach (orderTpl, price in upgrades) {
      local orderReq = price.count
      if (!price?.isFixedPrice)
        orderReq = ceil(orderReq * upgradeMult).tointeger()
      let ordersInStock = armyItemCountByTpl.value?[orderTpl] ?? 0
      let hasEnoughOrders = orderReq > 0 && ordersInStock >= orderReq
      canBuy = canBuy || hasEnoughOrders
      let canBuyCount = orderReq > 0 ? ordersInStock / orderReq : 0

      res.priceOptions.append({ orderTpl, orderReq, ordersInStock, hasEnoughOrders, canBuyCount })
      if (maxBuyCount < canBuyCount)
        maxBuyCount = canBuyCount
    }

    let allGuids = item?.guids ?? [item?.guid]

    if (res.priceOptions.len() > 0)
      res.__update({
        hasEnoughOrders = canBuy
        isUpgradable = true
        guids = allGuids.slice(0, maxBuyCount)
        itemBaseTpl, upgradeMult
      })
    return res
  })
}

let canDispose = @(item) (item?.guid ?? "") != ""
  && !(item?.isFixed ?? false)
  && (item?.sign ?? 0) == 0
  && ((item?.upgradesId ?? "") != "" || (disposableTypes?[item?.itemtype] ?? false))

let mkItemDisposeData = function(item) {
  if (!canDispose(item))
    return Computed(@() { isDisposable = false })

  let { basetpl = "", tier = 0 } = item
  let itemBaseTpl = trimUpgradeSuffix(basetpl)
  let armyId = getLinkedArmyName(item)
  return Computed(function() {
    let res = {
      isDisposable = false
      isDestructible = false
      isRecyclable = false
      armyId
      orderCount = 0
      orderTpl = ""
      disposeMult = null
      itemBaseTpl
      guids = null
    }
    if (!hasShopSection.value)
      return res

    let itemType = findItemTemplate(allItemTemplates, armyId, itemBaseTpl).itemtype
    local disposes = getModifyConfig(itemDisposes.value, tier, itemType)
    if (disposes == null)
      return res

    disposes = disposes.values()[0] // TODO suggest multiple selection instead of first price

    let { isDestructible = false, count = 0, batchSize = 1, isFixedPrice = false } = disposes
    if (!isDestructible && itemBaseTpl == basetpl)
      return res

    local disposeMult = 1.0
    if (!isFixedPrice) {
      disposeMult += (disposeCountMultByArmy.value?[armyId][itemBaseTpl] ?? 0.0)
      disposeMult *= 1.0 - curUpgradeDiscount.value
    }
    let orderCount = count * disposeMult
    let orderTpl = disposes.itemTpl
    let guids = isObjLinkedToAnyOfObjects(item, curCampItems.value ?? {}) ? null
      : isObjLinkedToAnyOfObjects(item, curCampSoldiers.value ?? {}) ? null
      : item?.guids ?? [item?.guid]
    return res.__update({
      isDisposable = true
      isRecyclable = orderCount <= 0
      guids
      isDestructible, itemBaseTpl, disposeMult, orderTpl, orderCount, batchSize
    })
  })
}

return {
  mkItemUpgradeData
  mkItemDisposeData
}