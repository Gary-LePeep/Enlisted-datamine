require ecs
require ecs.common
require app
require game.es.events
require common_shooter.events_common_shooter
require common_shooter.es.human_weap_common
require enlisted.events_enlisted
require inventory
require DngNet
require DagorSystem
require DngHuman
require DngWeapon
require HumanPhys
require WeapHelpers
require Gun
require DagorSystem

def set_wish_ammo_item_type(gun_eid : ecs::EntityId; item_id : int)
  var changed = false
  query(gun_eid) <| $ [es(REQUIRE=gun)] (var gun__wishAmmoItemType : int&)
    changed = gun__wishAmmoItemType != item_id
    gun__wishAmmoItemType = item_id
  return changed


def set_ammo_type(slot_id : int;
                  item_id : int;
                  human_weap__gunEids : EidList;
                  owner_eid : EntityId)
  if slot_id < 0 || slot_id >= length(human_weap__gunEids)
    return

  if set_wish_ammo_item_type(human_weap__gunEids[slot_id], item_id)
    request_unload_ammo(owner_eid, slot_id)
    sendEvent(owner_eid, [[CmdRequestReload atTime=get_sync_time(), gunEid=human_weap__gunEids[slot_id], isQuick = false]])

// Why update: because we need check state human_net_phys.phys.currentState.weapEquipState.curState
// and change grenade when first animation is end(when grenade disappear)
[es(tag=server, REQUIRE=grenade_thrower, no_order)]
def update_switch_grenade_es(evt : UpdateStageInfoAct;
                             gun__owner : EntityId;
                             var grenade_thrower__wishProjectileId : int&)
  if grenade_thrower__wishProjectileId == 0
    return

  query(gun__owner) <| $ [es] (var human_net_phys : HumanActor; human_weap__gunEids : EidList)
    if human_net_phys.phys.currentState.weapEquipState.curState == HUWeaponEquipState EES_EQUIPING
      set_ammo_type(int(HUWeaponSlots EWS_GRENADE), grenade_thrower__wishProjectileId, human_weap__gunEids, gun__owner)
      take_grenade_in_hand(gun__owner, human_weap__gunEids, human_net_phys.phys)
      grenade_thrower__wishProjectileId = 0

def try_take_grenade_in_hand(eid aka owner_eid : ecs::EntityId;
                             slot_id : int;
                             wish_item_id : int;
                             human_weap__fastThrowExclusive : bool;
                             human_weap__throwMode : bool;
                             human_weap__gunEids : EidList;
                             var human_net_phys : HumanActor;
                             is_grenade_slot_current : bool)
  let isGrenade = (slot_id == int(HUWeaponSlots EWS_GRENADE))
  if !isGrenade || human_weap__fastThrowExclusive || human_weap__throwMode
    return false

  let gunEid = human_weap__gunEids[slot_id]
  let wishAmmoItemType = get_int(gunEid, "gun__wishAmmoItemType") ?? INVALID_ITEM_ID
  let retakeGrenade = !is_grenade_slot_current || (wishAmmoItemType != wish_item_id)

  if is_grenade_slot_current && retakeGrenade
    query(gunEid) <| $ [es(REQUIRE=grenade_thrower)] (var grenade_thrower__wishProjectileId : int?)
      if grenade_thrower__wishProjectileId != null
        *grenade_thrower__wishProjectileId = wish_item_id
      human_net_phys.phys.currentState.weapEquipState.progress = 0f
      human_net_phys.phys.currentState.weapEquipState.curState = HUWeaponEquipState EES_HOLSTERING
    return false

  if retakeGrenade
    set_wish_ammo_item_type(gunEid, wish_item_id)
    if !take_grenade_in_hand(eid, human_weap__gunEids, human_net_phys.phys)
      return false

  return true


[es(before=human_weap_post_phys_es)]
def human_weap_throw_on_equip(evt : CmdPostPhysUpdate;
                              var human_weap__throwOnEquip : bool&;
                              var human_net_phys : HumanActor)
  assume cs = human_net_phys.phys.currentState
  let equiped = cs.weapEquipState.curState == HUWeaponEquipState EES_EQUIPED
  let isGrenade = cs.weapEquipState.effectiveCurSlot == HUWeaponSlots EWS_GRENADE
  if isGrenade && equiped && human_weap__throwOnEquip
    assume ct = is_true_net_server() ? human_net_phys.phys.appliedCT : human_net_phys.phys.producedCT
    ct |> human_control_state_set_control_bit(HumanPhysControlType HCT_SHOOT, true)
    human_weap__throwOnEquip = false


[es]
def human_weap_grenade_quick_throw(evt : RequestQuickThrowGrenade;
                                   eid aka owner_eid : EntityId;
                                   human_weap__gunEids : EidList;
                                   human_weap__fastThrowExclusive : bool;
                                   human_weap__throwMode : bool;
                                   var human_weap__quickThrowLastWeaponSlot : int&;
                                   var human_weap__throwOnEquip : bool&;
                                   var human_net_phys : HumanActor)
  let grenadeAmmoId = evt.grenade_ammo_id

  assume phys = human_net_phys.phys
  assume weapEquipState = phys.currentState.weapEquipState
  let effectiveCurSlot = weapEquipState.effectiveCurSlot
  let isGrenadeSlotCurrent = (effectiveCurSlot == HUWeaponSlots EWS_GRENADE)
  let slotId = int(HUWeaponSlots EWS_GRENADE)

  if !try_take_grenade_in_hand(eid, slotId, grenadeAmmoId,
                               human_weap__fastThrowExclusive,
                               human_weap__throwMode,
                               human_weap__gunEids,
                               human_net_phys,
                               isGrenadeSlotCurrent)
    set_ammo_type(slotId, grenadeAmmoId, human_weap__gunEids, owner_eid)

  // queue grenade throw when it's equipped and ready to throw
  human_weap__throwOnEquip = true
  // save current weapon slow to switch to it back after grenade throw
  human_weap__quickThrowLastWeaponSlot = int(effectiveCurSlot)


[es]
def human_weap_wish_ammo_es(evt : CmdSetWishAmmoItemType;
                            eid aka owner_eid : ecs::EntityId;
                            human_weap__gunEids : ecs::EidList;
                            human_weap__fastThrowExclusive : bool;
                            human_weap__throwMode : bool;
                            var human_net_phys : HumanActor)
  let slotId = evt.slot_id
  let itemId = evt.item_id

  assume phys = human_net_phys.phys
  assume weapEquipState = phys.currentState.weapEquipState
  let effectiveCurSlot = weapEquipState.effectiveCurSlot
  let isGrenadeSlotCurrent = (effectiveCurSlot == HUWeaponSlots EWS_GRENADE)

  if !is_server()
    send_net_event(eid, [[HumanRequestSetWishAmmoItemType slot_id=slotId, item_id=itemId, is_grenade_slot_current=isGrenadeSlotCurrent]])
    return // Do nothing, it's all should be server driven

  if !try_take_grenade_in_hand(eid, slotId, itemId,
                               human_weap__fastThrowExclusive,
                               human_weap__throwMode,
                               human_weap__gunEids,
                               human_net_phys,
                               isGrenadeSlotCurrent)
    set_ammo_type(slotId, itemId, human_weap__gunEids, owner_eid)

[es]
def human_weap_toggle_wish_ammo_es(evt : CmdToggleWishAmmoItemType;
                                   eid : ecs::EntityId;
                                   itemContainer : ecs::EidList;
                                   human_weap__gunEids : ecs::EidList;
                                   human_net_phys : HumanActor)
  let slotId = evt.slot_id
  if slotId < 0 || (slotId >= length(human_weap__gunEids)) || (human_weap__gunEids[slotId] == INVALID_ENTITY_ID)
    return

  let gunEid = human_weap__gunEids[slotId]
  query(gunEid) <| $ [es(REQUIRE=gun)] (gun__ammoHolderIds : IntList&;
                                        gun__shell_prop_ids : GunShellPropIds&;
                                        gun__wishAmmoItemType : int = INVALID_ITEM_ID)
    gather_ammo_for_gun(gun__ammoHolderIds, gun__shell_prop_ids, itemContainer) <| $(ammoItems)
      let ammoItemsCount = length(ammoItems)
      let isGrenadeSlotCurrent = human_net_phys.phys.currentState.weapEquipState.effectiveCurSlot == HUWeaponSlots EWS_GRENADE
      var curSlot = ammoItems |> find_index(gun__wishAmmoItemType)
      if curSlot < 0
        curSlot = 0 // for case when we don't found wish ammo item in ammoItems
      let wishSlot = isGrenadeSlotCurrent ? curSlot + 1 : curSlot
      let wishItemId = (ammoItemsCount == 0) ? INVALID_ITEM_ID : ammoItems[(wishSlot) % ammoItemsCount]
      sendEvent(eid, [[CmdSetWishAmmoItemType slot_id=slotId, item_id=wishItemId]])


[es]
def human_weap_req_wish_ammo_es(evt : HumanRequestSetWishAmmoItemType;
                                eid aka owner_eid : ecs::EntityId;
                                human_weap__gunEids : ecs::EidList;
                                human_weap__fastThrowExclusive : bool;
                                human_weap__throwMode : bool;
                                var human_net_phys : HumanActor)
  let slotId = evt.slot_id
  let itemId = evt.item_id
  if !try_take_grenade_in_hand(eid, slotId, itemId,
                               human_weap__fastThrowExclusive,
                               human_weap__throwMode,
                               human_weap__gunEids,
                               human_net_phys,
                               evt.is_grenade_slot_current)
    set_ammo_type(slotId, itemId, human_weap__gunEids, owner_eid)


def review_weap_gun_wish_ammo_item_type(itemContainer : ecs::EidList;
                                        human_weap__gunEids : ecs::EidList)
  for gunEid in human_weap__gunEids
    if gunEid == INVALID_ENTITY_ID
      continue

    query(gunEid) <| $ [es(REQUIRE=gun)] (gun__ammoHolderIds : IntList&;
                                          gun__shell_prop_ids : GunShellPropIds&;
                                          gun__wishAmmoItemType : int = INVALID_ITEM_ID)
      gather_ammo_for_gun(gun__ammoHolderIds, gun__shell_prop_ids, itemContainer) <| $(ammoItems)
        let ammoItemsCount = length(ammoItems)
        let slotIdx = ammoItems |> find_index(gun__wishAmmoItemType)
        if slotIdx == -1
          var wishAmmoId = -1
          var hasWishedAmmo = false
          for ammoHolderId in gun__ammoHolderIds
            for itemEid in itemContainer
              query(itemEid) <| $ [es] (ammo_holder__id : int; item__id : int)
                if ammo_holder__id == ammoHolderId
                  wishAmmoId = item__id
                  hasWishedAmmo = true
              if hasWishedAmmo
                break
            if hasWishedAmmo
              break

          if !hasWishedAmmo
            wishAmmoId = ammoItemsCount == 0 ? INVALID_ITEM_ID : ammoItems[0]

          set_wish_ammo_item_type(gunEid, wishAmmoId)


[es(tag=server, after=gun_init_es, track=(itemContainer, human_weap__gunEids))]
def human_weap_gun_wish_ammo_item_type_es(evt : Event;
                                          itemContainer : ecs::EidList;
                                          human_weap__gunEids : ecs::EidList)
  review_weap_gun_wish_ammo_item_type(itemContainer, human_weap__gunEids)


[es(tag=server)]
def human_drop_grenade_es(evt : EventOnLootDrop;
                          eid : ecs::EntityId;
                          human_weap__gunEids : ecs::EidList;
                          var human_net_phys : HumanActor)
  assume phys = human_net_phys.phys
  assume weapEquipState = phys.currentState.weapEquipState
  let effectiveCurSlot = weapEquipState.effectiveCurSlot

  if effectiveCurSlot != HUWeaponSlots EWS_GRENADE
    return

  if !take_grenade_in_hand(eid, human_weap__gunEids, phys)
    switch_to_first_weap_with_ammo(human_weap__gunEids, phys)
