from "%enlSqGlob/ui/ui_library.nut" import *

let { sourceProfileData, profileStructure } = require("sourceServProfile.nut")
let rand = require("%sqstd/rand.nut")()
let { updateAllConfigs } = require("%enlist/meta/configs.nut")
let { serverTimeUpdate } = require("%enlSqGlob/userstats/serverTimeUpdate.nut")
let { get_time_msec } = require("dagor.time")
let { doRequest } = require("%enlist/profileServer/profileServer.nut")
let { logerr } = require("dagor.debug")
let logApi = require("%enlSqGlob/library_logs.nut").with_prefix("[ClientApi] ")

const MAX_REQUESTS_HISTORY = 20
const LONG_TIME = 100 // threshold for long requests and calls logging

let requestData = persist("requestData", @() { id = rand.rint(), callbacks = {}})
let debugDelay = mkWatched(persist, "debugDelay", 0)
let lastRequests = mkWatched(persist, "lastRequests", [])

let diffTime = @(time) get_time_msec() - time

function handleMessages(msg, idStr) {
  let result = clone msg?.result
  let cb = requestData.callbacks?.$rawdelete(idStr)
  local reqTime = 0
  local method

  lastRequests.mutate(function(v) {
    local data = v.findvalue(@(d) d.id == idStr)
    if (data == null) {
      data = { id = idStr, request = "unknown" }
      if (v.len() >= MAX_REQUESTS_HISTORY)
        v.remove(0)
      v.append(data)
    }
    data.resultKeys <- result?.keys()  //store only keys, because of data can be really big
    reqTime = data?.reqTime ?? 0
    method = data.request?.method ?? idStr
    let diff = diffTime(reqTime)
    if (diff > LONG_TIME)
      logApi($"TOO LONG request '{method}' takes {diff} ms")
  })

  if (!result) {
    let errorStr = msg?.error.message ?? "unknown error"
    console_print(errorStr)
    if (cb)
      cb({ error = errorStr })
    return
  }

  let { timeMs = 0 } = result
  if (reqTime > 0 && timeMs > 0)
    serverTimeUpdate(timeMs, reqTime)

  if (result?.configs != null) {
    let curTime = get_time_msec()
    updateAllConfigs(result)
    result.$rawdelete("configs")
    logApi($"Config update takes {diffTime(curTime)} ms")
  }

  if (result?.full ?? false) {
    let curTime = get_time_msec()
    result.$rawdelete("full")
    if ("removed" in result) {
      logerr($"Not empty removed field on full profile update on '{method}'")
      result.$rawdelete("removed")
    }

    foreach (key, _ in result)
      if (key not in profileStructure)
        logApi($"Try to full update not existed profile field '{key}' on '{method}'")

    sourceProfileData.mutate(function(profile) {
      foreach (profileId, _ in profileStructure)
        profile[profileId] <- (result?[profileId] ?? {})
    })

    logApi($"Full profile update on '{method}' takes {diffTime(curTime)} ms")
  }
  else if (typeof result == "table") {
    let found = result.findindex(@(tbl) type(tbl) == "table")
    if (found != null) {
      let curTime = get_time_msec()
      local count = 0
      local removed = 0

      sourceProfileData.mutate(function(profile) {
        foreach (profileId, _ in profileStructure) {
          if (profileId not in result && profileId not in result?.removed)
            continue

          let needAddData = profileId in result
            && type(result[profileId]) == "table"
            && result[profileId].len() > 0
          let needRemoveData = profileId in result?.removed

          if (needAddData || needRemoveData) {
            let curVal = profile[profileId]
            if (needAddData) {
              ++count
              curVal.__update(result[profileId])
            }

            if (needRemoveData) {
              ++removed
              foreach (fieldId in result.removed[profileId])
                if (fieldId in curVal)
                  curVal.$rawdelete(fieldId)
            }
            profile[profileId] = clone curVal
          }
        }
      })
      logApi($"Profile updated:{count} deleted:{removed} tables of '{method}' takes {diffTime(curTime)} ms")
    }
  }

  if (cb) {
    let curTime = get_time_msec()
    cb(result)
    let diff = diffTime(curTime)
    if (diff > 0)
      logApi($"Handler call on '{method}' takes {diff} ms")
  }
}

let cleanKeys = ["method", "params", "token"]

function requestImpl(data, cb = null) {
  let idStr = (++requestData.id).tostring()
  if (cb)
    requestData.callbacks[idStr] <- cb

  lastRequests.mutate(function(v) {
    if (v.len() >= MAX_REQUESTS_HISTORY)
      v.remove(0)
    v.append({ id = idStr, request = data, reqTime = get_time_msec() })
  })

  let { method, params = null, token = null } = data
  let args = clone data
  cleanKeys.each(@(key) args?.$rawdelete(key))
  doRequest(method, params, args, idStr, handleMessages, token)
}

local request = requestImpl
function updateDebugDelay() {
  request = (debugDelay.value <= 0) ? requestImpl
    : @(data, cb = null) gui_scene.setTimeout(debugDelay.value, @() requestImpl(data, cb))
}
updateDebugDelay()
debugDelay.subscribe(@(_) updateDebugDelay())

console_register_command(@(delay) debugDelay(delay), "pserver.delay_requests")
console_register_command(function() {
  logApi("lastRequests: ")
  debugTableData(lastRequests.value, { recursionLevel = 7 })
}, "pserver.debug_last_requests")

return {
  lastRequests

  update_profile  = @(cb = null, token = null) request({
    method = "get"
    token
  }, cb)

  get_all_configs = @(cb = null, token = null) request({
    method = "get_all_configs"
    token
  }, cb)

  check_purchases = @() request({
    method = "check_purchases"
  })

  get_userlogs = @(timestamp = 0, cb = null, token = null) request({
    method = "get_userlogs"
    token
    params = { timestamp }
  }, cb)

  equip_item = @(target, item, slot, index, cb = null) request({
    method = "equip_item"
    params = { target, item, slot, index = index ?? -1 }
  }, cb)

  equip_by_list = @(target, equipList, cb = null) request({
    method = "equip_by_list"
    params = { target, equipList }
  }, cb)

  mass_equip = @(equipListBySoldier, cb) request({
    method = "mass_equip"
    params = { equipListBySoldier }
  }, cb)

  swap_soldiers_equipment = @(soldierAGuid, soldierBGuid) request({
    method = "swap_soldiers_equipment"
    params = { soldierAGuid, soldierBGuid }
  })

  set_vehicle_to_squad = @(vehicle, squad, cb) request({
    method = "set_vehicle_to_squad"
    params = { vehicle, squad }
  }, cb)

  set_squad_order = @(armyId, orderedGuids) request({
    method = "set_squad_order"
    params = { armyId, orderedGuids }
  })

  sell_squad = @(armyId, squadGuid, silverCost) request({
    method = "sell_squad"
    params = { armyId, squadGuid, silverCost }
  })

  rent_squad = @(armyId, squadId, rentTime, price) request({
    method = "rent_squad"
    params = { armyId, squadId, rentTime, price }
  })

  // UNUSED
  set_soldier_order = @(squad, orderedGuids)  request({
    method = "set_soldier_order"
    params = { squad, orderedGuids }
  })

  // UNUSED
  set_reserve_order = @(armyId, orderedGuids, cb = null) request({
    method = "set_reserve_order"
    params = { armyId, orderedGuids }
  }, cb)

  manage_squad_soldiers = @(armyId, squadGuid, squadSoldiers, reserveSoldiers, cb = null) request({
    method = "manage_squad_soldiers"
    params = { armyId, squadGuid, squadSoldiers, reserveSoldiers }
  }, cb)

  // UNUSED
  dismiss_reserve_soldier = @(armyId, soldierGuid, cb = null) request({
    method = "dismiss_reserve_soldier"
    params = { armyId, soldierGuid }
  }, cb)

  dismiss_reserve_soldiers = @(armyId, guidsList, cb) request({
    method = "dismiss_reserve_soldiers"
    params = { armyId, guidsList }
  }, cb)

  swap_items = @(soldier1, slot1, index1, soldier2, slot2, index2, cb = null) request({
    method = "swap_items"
    params = { soldier1, slot1, index1 = index1 ?? -1, soldier2, slot2, index2 = index2 ?? -1 }
  }, cb)

  drop_items = @(crateId) request({
    method = "drop_items"
    params = { crateId }
  })

  get_current_crates = @(crates, cb) request({
    method = "get_current_crates"
    params = { crates }
  }, cb)

  add_squad = @(squadId) request({
    method = "add_squad"
    params = { squadId }
  })

  remove_squad = @(squadId) request({
    method = "remove_squad"
    params = { squadId }
  })

  add_all_squads = @() request({
    method = "add_all_squads"
  })

  add_soldier = @(armyId, sClass, tier) request({
    method = "add_soldier"
    params = { armyId, sClass, tier }
  })

  add_items = @(armyId, itemTmpl, count) request({
    method = "add_items"
    params = { armyId, itemTmpl, count }
  })

  remove_item = @(itemGuid, count = 1) request({
    method = "remove_item"
    params = { itemGuid, count }
  })

  add_items_by_type = @(armyId, itemTypes, count) request({
    method = "add_items_by_type"
    params = { armyId, itemTypes, count }
  })

  add_army_exp = @(armyId, exp, cb) request({
    method = "add_army_exp"
    params = { armyId, exp }
  }, cb)

  buy_army_exp = @(armyId, exp, cost, cb = null) request({
    method = "buy_army_exp"
    params = { armyId, exp, cost }
  }, cb)

  buy_squad_exp = @(armyId, squadId, exp, cost, cb = null) request({
    method = "buy_squad_exp"
    params = { armyId, squadId, exp, cost }
  }, cb)

  use_soldier_levelup_orders = @(guid, barterData, cb = null) request({
    method = "use_soldier_levelup_orders"
    params = { guid, barterData }
  }, cb)

  buy_soldier_exp = @(guid, exp, cost, cb) request({
    method = "buy_soldier_exp"
    params = { guid, exp, cost }
  }, cb)

  unlock_squad = @(armyId, squadId, cb) request({
    method = "unlock_squad"
    params = { armyId, squadId }
  }, cb)

  get_army_level_reward = @(armyId, unlockGuid) request({
    method = "get_army_level_reward"
    params = { armyId, unlockGuid }
  })

  make_squad_researches = @(armyId, squadId, cb = null) request({
    method = "make_squad_researches"
    params = { armyId, squadId }
  }, cb)

  barter_shop_items = @(armyId, shopItemGuid, payItems, count, cb = null) request({
    method = "barter_shop_items"
    params = { armyId, shopItemGuid, payItems, count }
  }, cb)

  barter_shop_items_multiple = @(armyId, itemData, payData, cb) request({
    method = "barter_shop_items_multiple"
    params = { armyId, itemData, payData }
  }, cb)

  buy_shop_items = @(armyId, shopItemGuid, currencyId, price, count, cb = null) request({
    method = "buy_shop_items"
    params = { armyId, shopItemGuid, currencyId, price, count }
  }, cb)

  buy_shop_items_list = @(armyId, itemData, payData, cb) request({
    method = "buy_shop_items_list"
    params = { armyId, itemData, payData }
  }, cb)

  update_offers = @(cb = null) request({
    method = "update_offers"
  }, cb)

  reset_offers = @(cb = null) request({
    method = "reset_offers"
  }, cb)

  buy_shop_offer = @(armyId, shopItemGuid, currencyId, price, offerGuid = "", cb = null) request({
    method = "buy_shop_offer"
    params = { armyId, shopItemGuid, currencyId, offerGuid, price }
  }, cb)

  get_shop_item = @(shopId, cb = null) request({
    method = "get_shop_item"
    params = { shopId }
  }, cb)

  reset_profile = @(isUnited, cb) request({
    method = "reset_profile"
    params = { isUnited }
  }, cb)

  soldiers_regenerate_view = @() request({
    method = "soldiers_regenerate_view"
  })

  reset_mutations_timestamp = @() request({
    method = "reset_mutations_timestamp"
  })

  apply_profile_mutation = @(key) request({
    method = "apply_profile_mutation"
    params = { key }
  })

  soldier_train = @(guid, steps, cb = null) request({
    method = "soldier_train"
    params = { guid, steps }
  }, cb)

  use_soldier_train_order = @(guid, ticket, steps, cb = null) request({
    method = "use_soldier_train_order"
    params = { guid, ticket, steps }
  }, cb)

  add_exp_to_soldiers = @(list, cb) request({
    method = "add_exp_to_soldiers"
    params = { list }
  }, cb)

  add_perk_points = @(guid, count, cb = null) request({
    method = "add_perk_points"
    params = { guid, count }
  }, cb)

  add_perk = @(soldierGuid, perkId, cb) request({
    method = "add_perk"
    params = { soldierGuid, perkId }
  }, cb)

  remove_perk = @(soldierGuid, perkId, sacrificeItems, cb) request({
    method = "remove_perk"
    params = { soldierGuid, perkId, sacrificeItems }
  }, cb)

  reset_perks = @(soldierGuid, needTotalReset, sacrificeItems, cb) request({
    method = "reset_perks"
    params = { soldierGuid, needTotalReset, sacrificeItems }
  }, cb)

  free_reroll_perks = @(soldierGuid, needTotalReset, cb) request({
    method = "free_reroll_perks"
    params = { soldierGuid, needTotalReset }
  }, cb)

  add_army_squad_exp_by_id = @(armyId, exp, squadId) request({
    method = "add_army_squad_exp_by_id"
    params = { armyId, exp, squadId }
  })

  do_research = @(armyId, researchId, cb = null) request({
    method = "research"
    params = { armyId, researchId }
  }, cb)

  change_research = @(armyId, researchFrom, researchTo, payItems, cb = null) request({
    method = "change_research"
    params = { armyId, researchFrom, researchTo, payItems }
  }, cb)

  buy_change_research = @(armyId, researchFrom, researchTo, cost, cb = null) request({
    method = "buy_change_research"
    params = { armyId, researchFrom, researchTo, cost }
  }, cb)

  upgrade_items_count = @(itemData, sacrificeItems, cb = null) request({
    method = "upgrade_items_count"
    params = { itemData, sacrificeItems }
  }, cb)

  dispose_items_count = @(itemData, cb = null) request({
    method = "dispose_items_count"
    params = { itemData }
  }, cb)

  gen_perks_points_statistics = @(tier, count, genId, cb) request({
    method = "gen_perks_points_statistics"
    params = { tier, count, genId }
  }, cb)

  get_bots_data = @(armyId, campaignId, cb) request({
    method = "get_bots_data"
    params = { armyId, campaignId }
    timeout_factor = 4.0
  }, cb)

  get_profile_data_jwt = @(armies, campaignId, cb) request({
    method = "get_profile_data_jwt_v2"
    params = { armies, campaignId }
    timeout_factor = 4.0
  }, cb)

  gen_default_profile = @(target, armies, isUnited, cb) request({
    method = "gen_default_profile"
    params = { target, armies, isUnited }
    timeout_factor = 4.0
  }, cb)

  gen_tutorial_profiles = @(cb) request({
    method = "gen_tutorial_profiles"
  }, cb)

  // UNUSED
  get_info_for_matching_jwt = @(cb) request({
    method = "get_info_for_matching_jwt"
  }, cb)

  mark_seen_objects = @(objectsGuids = [], cb = null) request({
    method = "mark_seen_objects"
    params = { objectsGuids }
  }, cb)

  reward_single_player_mission = @(missionId, armyId, squads, soldiers) request({
    method = "reward_single_player_mission"
    params = { missionId, armyId, squads, soldiers }
  })

  premium_add = @(duration) request({
    method = "premium_add"
    params = { duration }
  })

  premium_remove = @(duration) request({
    method = "premium_remove"
    params = { duration }
  })

  use_callname_change_order = @(guid, callname, ticket, cb = null) request({
    method = "use_callname_change_order"
    params = { guid, callname, ticket }
  }, cb)

  buy_callname_change = @(guid, callname, cost, cb = null) request({
      method = "buy_callname_change"
      params = { guid, callname, cost }
  }, cb)

  appearance_change = @(guid, cb = null) request({
    method = "appearance_change"
    params = { guid }
  }, cb)

  use_appearance_change_order = @(guid, ticket, cb = null) request({
    method = "use_appearance_change_order"
    params = { guid, ticket }
  }, cb)

  buy_appearance_change = @(guid, cost, cb = null) request({
      method = "buy_appearance_change"
      params = { guid, cost }
  }, cb)

  inventory_add_item = @(itemdef, quantity = 1) request({
    method = "inventory_add_item"
    params = { itemdef, quantity }
  })

  gen_testdrive_squad_profile_jwt = @(armyId, squadId, shopItemGuid, cb) request({
    method = "gen_testdrive_squad_profile_jwt"
    params = { armyId, squadId, shopItemGuid }
  }, cb)

  choose_decorator = @(cType, guid) request({
    method = "choose_decorator"
    params = { cType, guid }
  })

  buy_decorator = @(guid, cost, cb = null) request({
    method = "buy_decorator"
    params = { guid, cost }
  }, cb)

  add_decorator = @(guid, lifeTime = 0) request({
    method = "add_decorator"
    params = { guid, lifeTime }
  })

  add_all_decorators = @() request({
    method = "add_all_decorators"
  })

  remove_type_decorator = @(cType) request({
    method = "remove_type_decorator"
    params = { cType }
  })

  add_veh_decorators = @(cType, id) request({
    method = "add_veh_decorators"
    params = { cType, id }
  })

  apply_decorator = @(guid, vehGuid, cType, details, slot, cb = null) request({
    method = "apply_decorator"
    params = { guid, vehGuid, cType, details, slot }
  }, cb)

  buy_veh_decorator = @(cType, id, cost, cb = null) request({
    method = "buy_veh_decorator"
    params = { cType, id, cost }
  }, cb)

  buy_apply_veh_decorators = @(decorators, vehGuid, cost, cb = null) request({
    method = "buy_apply_veh_decorators"
    params = { decorators, vehGuid, cost }
  }, cb)

  mark_decorators_as_seen = @(guids) request({
    method = "mark_decorators_as_seen"
    params = { guids }
  })

  mark_veh_decorators_as_seen = @(guids) request({
    method = "mark_veh_decorators_as_seen"
    params = { guids }
  })

  add_medal = @(id) request({
    method = "add_medal"
    params = { id }
  })

  mark_medals_as_seen = @(guids) request({
    method = "mark_medals_as_seen"
    params = { guids }
  })

  mark_wallposters_as_seen = @(guids) request({
    method = "mark_wallposters_as_seen"
    params = { guids }
  })

  debug_apply_booster_in_battle = @(battleBoosters) request({
    method = "debug_apply_booster_in_battle"
    params = { battleBoosters }
  })

  decrease_purchases_count = @(goodsGuid, count) request({
    method = "decrease_purchases_count"
    params = { goodsGuid, count }
  })

  add_wallposter = @(tpl) request({
    method = "add_wallposter"
    params = { tpl }
  })

  update_meta_config = @(data, cb = null) request({
    method = "update_meta_config"
    params = { data }
  }, cb)

  change_outfit = @(guid, free, premium, campaignId, cb = null) request({
    method = "change_outfit"
    params = { guid, free, premium, campaignId }
  }, cb)

  change_outfit_squad = @(equipListBySoldier, campaignId) request({
    method = "change_outfit_squad"
    params = { equipListBySoldier, campaignId }
  })

  add_outfit = @(armyId, outfitTmpl, count) request({
    method = "add_outfit"
    params = { armyId, outfitTmpl, count }
  })

  buy_outfit = @(armyId, items, cost, cb = null) request({
    method = "buy_outfit"
    params = { armyId, items, cost }
  }, cb)

  apply_freemium = @(campaignId) request({
    method = "apply_freemium"
    params = { campaignId }
  })

  apply_freemium_soldier = @(guid, level = 0) request({
    method = "apply_freemium_soldier"
    params = { guid, level }
  })

  use_outfit_orders = @(armyId, items, orders, cb = null) request({
    method = "use_outfit_orders"
    params = { armyId, items, orders }
  }, cb)

  usermail_check = @(ts, cb) request({
    method = "usermail_check"
    params = { ts }
  }, cb)

  usermail_list = @(ts, limit, cb) request({
    method = "usermail_list"
    params = { ts, limit }
  }, cb)

  usermail_take_reward = @(guid, cb) request({
    method = "usermail_take_reward"
    params = { guid }
  }, cb)

  usermail_reset_reward = @(cb) request({
    method = "usermail_reset_reward"
    params = {}
  }, cb)

  rate_mission = @(missionId, rate) request({
    method = "rate_mission"
    params = { missionId, rate }
  })

  growth_select = @(armyId, growthId) request({
    method = "growth_select"
    params = { armyId, growthId }
  })

  growth_use_army_exp = @(armyId, growthId, exp, cb) request({
    method = "growth_use_army_exp"
    params = { armyId, growthId, exp }
  }, cb)

  growth_select_forced = @(armyId, growthId) request({
    method = "growth_select_forced"
    params = { armyId, growthId }
  })

  growth_purchase = @(armyId, growthId, payItems) request({
    method = "growth_purchase"
    params = { armyId, growthId, payItems }
  })

  growth_reward_take_forced = @(armyId, growthId) request({
    method = "growth_reward_take_forced"
    params = { armyId, growthId }
  })

  growth_state_set = @(armyId, growthId, exp, status) request({
    method = "growth_state_set"
    params = { armyId, growthId, exp, status }
  })

  growth_buy_exp = @(armyId, growthId, exp, cost, cb = null) request({
    method = "growth_buy_exp"
    params = { armyId, growthId, exp, cost }
  }, cb)

  set_item_count = @(itemTpl, count, armyId) request({
    method = "set_item_count"
    params = { itemTpl, count, armyId }
  })

  growth_tier_set = @(armyId, index, progress, status) request({
    method = "growth_tier_set"
    params = { armyId, index, progress, status }
  })

  growth_reset = @() request({
    method = "growth_reset"
  })

  set_squad_outfit_preset = @(squadGuid, campaignId) request({
    method = "set_squad_outfit_preset"
    params = { squadGuid, campaignId }
  })

  force_squad_outfit_preset = @(squadGuid, presetId) request({
    method = "force_squad_outfit_preset"
    params = { squadGuid, presetId }
  })

  set_soldier_outfit_preset = @(soldierGuid, campaignId) request({
    method = "set_soldier_outfit_preset"
    params = { soldierGuid, campaignId }
  })

  growth_army_unlock = @(armyId) request({
    method = "growth_army_unlock"
    params = { armyId }
  })
}