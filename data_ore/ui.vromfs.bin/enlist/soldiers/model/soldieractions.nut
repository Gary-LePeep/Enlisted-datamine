from "%enlSqGlob/ui/ui_library.nut" import *

let {
  soldier_train, add_exp_to_soldiers, add_perk_points, add_perk, remove_perk, reset_perks,
  free_reroll_perks, buy_soldier_exp, use_soldier_levelup_orders, dismiss_reserve_soldiers
} = require("%enlist/meta/clientApi.nut")
let { markPerksUnseen, markPerksSeen } = require("%enlist/soldiers/model/soldierPerks.nut")

let mkSoldierActionCb = @(guidsList, cb = null) function(res) {
  markPerksUnseen(guidsList)
  cb?(res)
}

function soldierTrain(guid, steps, cb) {
  soldier_train(guid, steps, mkSoldierActionCb([guid], cb))
}

function addExpToSoldiers(list, cb) {
  add_exp_to_soldiers(list, mkSoldierActionCb(list.keys(), cb))
}

function addPerkPoints(guid, count, cb) {
  add_perk_points(guid, count, mkSoldierActionCb([guid], cb))
}

function buySoldierExp(guid, exp, cost, cb) {
  buy_soldier_exp(guid, exp, cost, mkSoldierActionCb([guid], cb))
}

function dismissReserveSoldiers(armyId, guidsList, cb) {
  dismiss_reserve_soldiers(armyId, guidsList, mkSoldierActionCb(guidsList, cb))
}

function useSoldierLevelupOrders(guid, barterData) {
  use_soldier_levelup_orders(guid, barterData, mkSoldierActionCb([guid]))
}

let mkPerksSeenCb = @(soldierGuid, cb = null) function(res) {
  markPerksSeen([soldierGuid])
  cb?(res)
}

function addPerk(soldierGuid, perkId, cb) {
  add_perk(soldierGuid, perkId, mkPerksSeenCb(soldierGuid, cb))
}

function removePerk(soldierGuid, perkId, sacrificeItems, cb) {
  remove_perk(soldierGuid, perkId, sacrificeItems, mkPerksSeenCb(soldierGuid, cb))
}

function resetPerks(soldierGuid, needTotalReset, sacrificeItems) {
  reset_perks(soldierGuid, needTotalReset, sacrificeItems, mkPerksSeenCb(soldierGuid))
}

function freeRerollPerks(soldierGuid, needTotalReset) {
  free_reroll_perks(soldierGuid, needTotalReset, mkPerksSeenCb(soldierGuid))
}


return {
  soldierTrain
  addExpToSoldiers
  buySoldierExp
  dismissReserveSoldiers
  useSoldierLevelupOrders
  addPerkPoints

  addPerk
  removePerk
  resetPerks
  freeRerollPerks
}
