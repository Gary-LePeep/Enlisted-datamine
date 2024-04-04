require ecs
require DagorSystem
require DagorRandom
require game.es.events
require inventory
require game.utils.team
require game.events_game
require game.es.inventory_common
require danetlibs.native_dasevents.main.native_events
require enlisted.events_enlisted
require DngNet

[es(tag=server, on_appear)]
def init_randomize_weight_for_loot(evt : Event;
                                   eid : EntityId;
                                   paid_loot__weapTemplates : StringList;
                                   paid_loot__weapRandomizeWeight : FloatList;
                                   var paid_loot__weapChanceRange : FloatList&)
  if length(paid_loot__weapTemplates) != length(paid_loot__weapRandomizeWeight)
    logerr("incorrect radnomize weap weight set in {eid} {getEntityTemplateName(eid)}")
    return
  resize(paid_loot__weapChanceRange, length(paid_loot__weapTemplates))
  var summWeight = 0.
  for weight in paid_loot__weapRandomizeWeight
    summWeight += weight
  if summWeight == 0.
    return
  for weight, chance in paid_loot__weapRandomizeWeight, paid_loot__weapChanceRange
    chance = weight / summWeight

[es(tag=server)]
def useful_box_paid_request_es(evt : CmdUse;
                               eid : EntityId;
                               useful_box__useCount : int;
                               useful_box__hintEnemy : string;
                               team : int;
                               paid_box__ressuplyCost : int;
                               useful_box__anyTeam : Tag const?)
  let requester = evt.requesterEid
  if !requester || useful_box__useCount <= 0
    return

  let ownedByTeam = team
  var isValidTeam = false
  query(requester) <| $ [es] (team : int;
                              paid_loot__points : int)
    isValidTeam = useful_box__anyTeam != null || is_teams_friendly(team, ownedByTeam)
    if !isValidTeam
      sendEvent(requester, [[CmdHeroLogEvent event="enemy_crate", text=useful_box__hintEnemy]])
      return
    if paid_loot__points >= paid_box__ressuplyCost
      sendEvent(eid, [[CmdUseUsefulBox requesterEid=requester]])
    else
      sendEvent(requester, [[CmdHeroLogEvent event="paid_loot", text="paid_loot/no_score"]])

[es(tag=server)]
def useful_box_paid_es(evt : EventOnUsefulBoxSuccessfulUse;
                       eid : EntityId;
                       paid_box__ressuplyCost : int)
  query(evt.requester) <| $ [es] (var paid_loot__points : int&)
    if paid_loot__points >= paid_box__ressuplyCost
      paid_loot__points -= paid_box__ressuplyCost
    else
      logwarn("Soldier use box without shop points. Smthg wrong. {eid} {getEntityTemplateName(eid)}")


[es(tag=gameClient, REQUIRE=watchedByPlr, track=human_weap__currentGunEid, on_appear)]
def useful_box_update_ui_cost_es(evt : Event;
                                 human_weap__currentGunEid : EntityId)
  query() <| $ [es(REQUIRE=paid_loot__checkCurrentWeap)] (var useful_box__uiPrice : int&;
                                                          paid_loot__ressuplyDefCost = 5)
    useful_box__uiPrice = get_int(human_weap__currentGunEid, "paid_loot__ressuplyCost") ?? paid_loot__ressuplyDefCost

[es(tag=server, on_appear, REQUIRE=paid_loot__ressuplyCost)]
def turn_off_initial_ammo_for_dropped_weapon(evt : Event;
                                             item__alreadyLooted : bool;
                                             var gun__isInitialAmmoHoldersSpawned : bool&)
  gun__isInitialAmmoHoldersSpawned = item__alreadyLooted

[es(tag=server, REQUIRE=paid_loot_item)]
def pickup_cost_item_es(evt : CmdPickupSpecialItem;
                        eid aka shop_eid : EntityId;
                        paid_loot__cost : int;
                        paid_loot__ressuplyCost : int = 0;
                        paid_loot__weapTemplates : StringList const?;
                        paid_loot__weapChanceRange : FloatList const?;
                        gun__initialAmmoHoldersCount : IntList const?)
  let randomWeapBox = paid_loot__weapTemplates != null && paid_loot__weapChanceRange != null
  let callback <- @ <| (eid aka item_eid : EntityId)
    var equipToSlots = false
    sendEvent(evt.pickuperEid, [[CmdHeroLogEvent event="paid_loot", text="", sound="events/z/ui/buy_weapon"]])
    if randomWeapBox
      let itemName = get_string(item_eid, "item__name", "")
      if itemName != ""
        using() <| $(var data : Object)
          set(data, "item", itemName)
          send_net_event(evt.pickuperEid, [[CmdHeroLogExEvent event="paid_loot", key="paid_loot/random_box", data=ecs_addr(data)]])
    query(item_eid) <| $ [es] (item__equipToSlots : Array)
      if length(item__equipToSlots) != 0
        equipToSlots = true
        if equip_item_entity(evt.pickuperEid, item_eid, item__equipToSlots)
          remove_item_from_entity_container(item_eid)
    if equipToSlots
      return

    let res = query(item_eid) <| $ [es] (item__id : int)
      if item__id != INVALID_ITEM_ID
        pickup_one_item_impl(evt.pickuperEid, item_eid)
    if !res
      logwarn("Unable to pickup item {item_eid}, exist={doesEntityExist(item_eid)}")

  query(evt.pickuperEid) <| $ [es] (var paid_loot__points : int&)
    if paid_loot__cost <= paid_loot__points
      if randomWeapBox
        var curChanceRange = 0.
        let curWinNum = rnd_float(0.0, 1.0)
        for weapTempl, chance in *paid_loot__weapTemplates, *paid_loot__weapChanceRange
          curChanceRange += chance
          if curWinNum < curChanceRange
            paid_loot__points -= paid_loot__cost
            createEntity(string(weapTempl), callback) <| $ [unused_argument(init)] (var init) {}
            return
      else
        if !can_pickup_item_by_volume(shop_eid, evt.pickuperEid)
          return
        var lootTemplate = remove_sub_template_name(getEntityTemplateName(shop_eid), "paid_loot_item")
        lootTemplate = add_sub_template_name(lootTemplate, "paid_loot_ressuply")
        paid_loot__points -= paid_loot__cost
        createEntity(lootTemplate, callback) <| $(var init)
          if gun__initialAmmoHoldersCount != null
            set(init, "gun__initialAmmoHoldersCount", *gun__initialAmmoHoldersCount)
            set(init, "paid_loot__ressuplyCost", paid_loot__ressuplyCost)
    else
      sendEvent(evt.pickuperEid, [[CmdHeroLogEvent event="paid_loot", text="paid_loot/no_score"]])
