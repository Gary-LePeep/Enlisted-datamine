from "%enlSqGlob/ui/ui_library.nut" import *

let armyEffects = require("armyEffects.nut")
let { get_current_crates } = require("%enlist/meta/clientApi.nut")
let { configs } = require("%enlist/meta/configs.nut")
let { templateLevel } = require("%enlSqGlob/ui/itemsInfo.nut")


let requestedCratesContent = Watched({})
let requested = {}

function requestCratesContent(crates) {
  let curCrates = requestedCratesContent.value
  let toRequest = crates.filter(@(c) c not in curCrates && c not in requested)
  if (toRequest.len() == 0)
    return
  toRequest.each(@(c) requested[c] <- true)
  get_current_crates(toRequest, function(res) {
    toRequest.each(function(c) {
      if (c in requested)
        requested.$rawdelete(c)
    })
    if ("content" in res)
      requestedCratesContent.mutate(function(cc) {
        cc.__update(res.content)
      })
  })
}

armyEffects.subscribe(function(_effects) {
  let curCrates = requestedCratesContent.value
  if (curCrates.len() > 0) {
    requestedCratesContent({})
    // automatic request of all cached crates is not needed after every effects update
    //requestCratesContent(curCrates.keys())
  }
})


function removeCrateContent(crates) {
  requestedCratesContent.mutate(function(cc) {
    foreach (crateId in crates) {
      if (crateId in cc)
        cc.$rawdelete(crateId)
    }
  })
}


function getShopItemsIds(items) {
  let res = {}
  foreach (item in items) {
    if (item?.crates != null)
      item.crates.each(@(crateId) res[crateId] <- true)
  }
  return res.keys()
}

let itemToShopItem = Computed(@() configs.value?.item_to_shop_item ?? {})


function getShopListForItem(tpl, armyId, itemsToShopItems, allItemTemplates){
  let res = itemsToShopItems?[armyId][tpl] ?? []
  if (res.len() > 0)
    return res

  for (local i=1; i<4; i++){
    let upgraded = templateLevel(tpl, i)
    if (upgraded not in allItemTemplates?[armyId])
      return []
    let upShopItems = itemsToShopItems?[armyId][upgraded]
    if (upShopItems != null){
      return upShopItems
    }
  }

  return []
}

return {
  getShopListForItem
  removeCrateContent
  requestCratesContent
  requestedCratesContent
  getShopItemsIds
  itemToShopItem
}
