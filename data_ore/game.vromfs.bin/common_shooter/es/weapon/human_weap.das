require ecs
require ecs.safe
require ecs.common
require app
require common_shooter.events_common_shooter
require common_shooter.es.human_weap_common
require common_shooter.es.human.human_reload_common
require enlisted.events_enlisted
require daslib.strings_boost
require inventory
require game.events_game
require game.es.events
require math.base
require DagorRandom
require DagorSystem
require DagorMath
require DagorMathUtils
require DaWeaponProps
require DaWeapons
require Dacoll
require DngNet
require DngHuman
require DngWeapon
require DngPhys
require HumanPhys
require WeapHelpers
require Gun
require AnimV20
require GamePhys
require GridCollision



[es(tag=server, on_appear, after=gun_init_shell_prop_ids_es)]
def gun_mod_custom_props_init_es(evt : Event;
                                 eid : EntityId;
                                 gunAttachable__slotName : string;
                                 var slot_attach__slotId : int&;
                                 var custom_props : Object?)
  let animcharSlotId = animchar_getSlotId(gunAttachable__slotName)
  slot_attach__slotId = animcharSlotId
  if custom_props != null
    human_gun_mod_from_custom_props(*custom_props, eid)
  server_init_gun_ammo(eid)


[es(tag=server, on_appear)]
def server_init_gun_es(evt : Event;
                       eid : EntityId;
                       gun__owner : EntityId;
                       gun__initialSlotId : int;
                       gun__initialFlags : int)
  if gun__initialSlotId != -1
    let gunEid = eid
    var gunEids = getRW_ecs_EidList(gun__owner, "human_weap__gunEids")
    if gunEids == null // Parent was destroyed before guns creation?
      if !doesEntityExist(gun__owner)
        logwarn("Ignore gun[{gun__initialSlotId}] init since parent {gun__owner} doesn't exist anymore")
      else
        logerr("Gun's [{gun__initialSlotId}] parent {gun__owner}<{getEntityTemplateName(gun__owner)}> exist but doesn't have 'human_weap.gunEids' component?!")
      return
    server_init_gun(gun__owner, gunEid, gun__initialSlotId, *gunEids)
    if (gun__initialFlags & int(RecreateGunsFlags Attach)) != 0
      let attach = (gun__initialSlotId == get_int(gun__owner, "human_weap__currentGunSlot") ?? 0)
      sendEventImmediate(gunEid, [[CmdWeapAttach toEid=gun__owner, isAttached=attach, slotId=gun__initialSlotId]])

    if (gun__initialFlags & int(RecreateGunsFlags ParentLoaded)) != 0
      sendEvent(gunEid, [[EventOnParentLoaded eid=gun__owner, slotId=gun__initialSlotId]])
    if has(gun__owner, "hero")
      sendEvent(gun__owner, [[CmdTrackHeroWeapons]])

def recreate_gun_slot(eid : EntityId;
                      slot : int;
                      human_weap__weapTemplates : Object;
                      flags : int;
                      var human_weap__gunEids : EidList;
                      var human_weap__gunMods : Array;
                      var human_weap__weapInitialComponents : Array)
  destroyEntity(human_weap__gunEids[slot])
  var gunMods = human_weap__gunMods[slot] |> getRW_ecs_EidList()
  if gunMods != null
    for gunModEid in *gunMods
      destroyEntity(gunModEid)
    *gunMods |> clear()
  let weaponSlotName = get_human_weapon_slot_name(slot)
  let weapTempl = human_weap__weapTemplates |> get_ecs_string(weaponSlotName)
  let weapTemplStr = weapTempl != null ? *weapTempl |> string() : ""
  // Create entity synchronously on dedicated in order to be able add all it's guns in net scope on avatar creation
  // (i.e. this reduces latency for weapons creation). This also might reduce unwanted replication traffic
  var gunInitComps : Object? = null
  if slot < length(human_weap__weapInitialComponents)
    gunInitComps = human_weap__weapInitialComponents[slot] |> getRW_ecs_object()

  human_weap__gunEids[slot] = create_gun_for_entity_impl(eid, slot, weapTemplStr, gunInitComps) <| $(n : string;
                                                                                                     var ci : ComponentsInitializer)
    set(ci, "gun__initialSlotId", slot)
    set(ci, "gun__initialFlags", flags)
    if is_dedicated()
      var newEid = createInstantiatedEntitySync(n, ci)
      if newEid == INVALID_ENTITY_ID
        // createInstantiatedEntitySync may fail if the entity wasn't instantiated, it shouldn't be fatal, but should be fixed
        logerr("Template dependency '{n}' isn't instantiated in '{getEntityTemplateName(eid)}'")
        newEid = createEntitySync(n, ci)
      return newEid
    else
      return createEntity(n, ci)

def server_recreate_guns(eid : EntityId;
                         human_weap__weapTemplates : Object;
                         flags : int;
                         var human_weap__gunEids : EidList;
                         var human_weap__gunMods : Array;
                         var human_weap__weapInitialComponents : Array)
  human_weap__gunEids |> resize(int(HUWeaponSlots EWS_NUM))
  var currentGunSlot = -1
  for slotId in range(int(HUWeaponSlots EWS_NUM))
    if currentGunSlot < 0
      currentGunSlot = slotId
    recreate_gun_slot(eid, slotId, human_weap__weapTemplates, flags, human_weap__gunEids, human_weap__gunMods, human_weap__weapInitialComponents)
    if !human_weap__gunEids[slotId] && slotId == currentGunSlot
      currentGunSlot = -1

  return currentGunSlot


def setup_human_actor_weapon_slot(human_weap__gunEids : EidList;
                                  human_weap__currentGunSlot : int;
                                  var human_net_phys : HumanActor)
  if !human_weap__gunEids[int(human_net_phys.phys.producedCT.chosenWeapon)]
    if human_weap__currentGunSlot >= 0
      human_net_phys.phys.producedCT |> set_chosen_weapon(HUWeaponSlots(human_weap__currentGunSlot))
      human_net_phys.phys.currentState.weapEquipState.curSlot = HUWeaponSlots(human_weap__currentGunSlot)


[es(tag=server, on_appear)]
def human_weap_created_server_es(evt : Event;
                                 eid : EntityId;
                                 human_weap__weapTemplates : Object;
                                 var human_weap__gunEids : EidList;
                                 var human_weap__gunMods : Array;
                                 var human_weap__weapInitialComponents : Array;
                                 var human_weap__salt : IntList;
                                 var human_weap__currentGunSlot : int&;
                                 var human_net_phys : HumanActor?)
  for saltI in iter_range(human_weap__salt)
    if human_weap__salt[saltI] < 0
      human_weap__salt[saltI] = grnd()

  human_weap__currentGunSlot = server_recreate_guns(eid, human_weap__weapTemplates,
                                                    int(RecreateGunsFlags Attach) | int(RecreateGunsFlags ParentLoaded),
                                                    human_weap__gunEids, human_weap__gunMods, human_weap__weapInitialComponents)

  if human_net_phys != null
    setup_human_actor_weapon_slot(human_weap__gunEids, human_weap__currentGunSlot, *human_net_phys)

[es(tag=server)]
def human_weap_server_recreate_gun_for_slot(evt : CmdReinitWeaponInSlot;
                                            eid : EntityId;
                                            human_weap__weapTemplates : Object;
                                            var human_weap__gunEids : EidList;
                                            var human_weap__gunMods : Array;
                                            var human_weap__weapInitialComponents : Array)
  let flags = int(RecreateGunsFlags Attach) | int(RecreateGunsFlags ParentLoaded)
  recreate_gun_slot(eid, evt.slot, human_weap__weapTemplates, flags, human_weap__gunEids, human_weap__gunMods, human_weap__weapInitialComponents)


[es(tag=server, on_appear, before=gun_init_es)]
def gun_init_ammo_prop_ids(evt : Event;
                           eid : EntityId;
                           gun__ammoHolders : Array;
                           var gun__ammoHolderIds : IntList;
                           var gun__maxAmmo : int&)
  for ammoHolder in gun__ammoHolders
    let ammoHolderName = ammoHolder ?? ""
    if ammoHolderName == ""
      logerr("Unacceptable to have empty \"ammoHolder\" in template <{getEntityTemplateName(eid)}>")
    gun__ammoHolderIds |> push(int(ecs_hash(ammoHolderName)))
    if gun__maxAmmo <= 0
      let templ = getTemplateByName(ammoHolderName)
      if templ != null
        gun__maxAmmo = getTemplateComponent(*templ, "ammo_holder__ammoCount") ?? 0


[es(tag=server, on_appear, REQUIRE=gun__createLoaded)]
def load_gun_on_create(evt : Event;
                       gun__ammoHolders : Array;
                       var customProps : Object&)
  for ammoHolder in gun__ammoHolders
    let ammoHolderName = ammoHolder ?? ""
    if ammoHolderName != ""
      let templ = getTemplateByName(ammoHolderName)
      if templ != null
        customProps |> set("ammoCount", getTemplateComponent(*templ, "ammo_holder__ammoCount") ?? 0)
        return


[es(tag=netClient, on_appear)]
def human_weap_created_client_es(evt : Event;
                                 eid : EntityId;
                                 human_weap__gunEids : EidList;
                                 human_weap__currentGunSlot : int;
                                 var human_net_phys : HumanActor?)
  if human_net_phys != null
    setup_human_actor_weapon_slot(human_weap__gunEids, human_weap__currentGunSlot, *human_net_phys)
  for i in range(int(HUWeaponSlots EWS_NUM))
    if human_weap__gunEids[i] != INVALID_ENTITY_ID
      let attach = (human_weap__currentGunSlot == i)
      add_delayed_action_client_wait_for_gun_creation(eid, human_weap__gunEids[i], attach, i)


[es(tag=netClient)]
def clear_client_pending_gun_creation_waits_es(evt : EventEntityManagerBeforeClear)
  remove_delayed_actions_client_wait_for_gun_creation()


// Tracking the creation of non-physical projectiles (displayed in hand)
[es(tag=netClient, REQUIRE_NOT=phys_obj_net_phys, on_appear)]
def replace_local_projectile_es(evt : Event;
                                eid : EntityId;
                                shell__owner : EntityId;
                                var slot_attach__attachedTo aka server_slot_attach__attachedTo : EntityId&;
                                var slot_attach__slotId aka server_slot_attach__slotId : int&;
                                var gun__visible aka server_gun__visible : bool&)
  // The local and the server projectiles must have the same owner
  // The owner of a long-living projectile may be already destroyed

  // human_weap__localProjectileEid is not found means the projectile's owner was destroyed
  query(shell__owner) <| $ [es] (var human_weap__localProjectileEid : EntityId&)
    let serverProjectileEid = eid

    // localProjectileEid == ecs::INVALID_ENTITY_ID means there was no client-side projectile or it's already destroyed
    // serverProjectileEid == localProjectileEid means this ES is processing the local projectile (name "serverProjectileEid" is misleading)
    if human_weap__localProjectileEid == INVALID_ENTITY_ID || serverProjectileEid == human_weap__localProjectileEid
      return
    // If there are two projectiles (local and server's) with the same owner, the local should be destroyed

    // Copy the visibility and attachment state from the local projectile, so if it was already displayed, new projectile will be too
    // Local projectile may not have the components if it's not yet created, hence the ECS_GET_OR
    query(human_weap__localProjectileEid) <| $ [es] (slot_attach__attachedTo aka local_slot_attach__attachedTo : EntityId)
      server_slot_attach__attachedTo = local_slot_attach__attachedTo

    query(human_weap__localProjectileEid) <| $ [es] (slot_attach__slotId aka local_slot_attach__slotId : int)
      server_slot_attach__slotId = local_slot_attach__slotId

    query(human_weap__localProjectileEid) <| $ [es] (gun__visible aka local_gun__visible : bool)
      server_gun__visible = local_gun__visible

    // The local projectile should be destroyed even if its asynchronous creation process is yet in progress
    destroyEntity(human_weap__localProjectileEid)
    human_weap__localProjectileEid = INVALID_ENTITY_ID


[es(tag=netClient, on_disappear)]
def destroy_local_projectile_es(evt : Event;
                                var human_weap__localProjectileEid : EntityId&)
  // Destroying the grenade in hand, when the human_weap is destroyed
  destroyEntity(human_weap__localProjectileEid)
  human_weap__localProjectileEid = INVALID_ENTITY_ID


[es(REQUIRE=human_weap, track=isDowned)]
def change_from_greande_thrower_on_revive(evt : Event;
                                          eid : EntityId;
                                          isDowned : bool;
                                          human_weap__gunEids : EidList;
                                          var human_weap__throwMode : bool&;
                                          var human_net_phys : HumanActor)
  if !isDowned && !human_weap__throwMode
    clear_throw_mode(eid, human_weap__gunEids, human_weap__throwMode, human_net_phys.phys)


[es(REQUIRE=human_weap, REQUIRE_NOT=human_input)]
def human_weap_post_phys_es(evt : CmdPostPhysUpdate;
                            eid : EntityId;
                            transform : float3x4;
                            isInVehicle : bool;
                            human_vehicle__isHoldingGunPassenger : bool;
                            human_weap__gunEids : EidList;
                            human_weap__lockedGrenadeThrowingCounter : int = 0;
                            human_weap__jumpDeviation : float = 0.;
                            human_weap__changePosDeviationCanAim : float = 0.;
                            human_weap__changePosDeviationCanNotAim : float = 0.;
                            human_phys__afterJumpDelay : float = 0.;
                            human_phys__jumpEndTime : float;
                            human_phys__isInAirLong : bool;
                            entity_mods__shotDeviationMult : float = 1.0;
                            entity_mods__rotationShotSpreadDecrMult : float = 1.0;
                            entity_mods__aimingAfterFireMult : float = 1.0;
                            entity_mods__boltActionMult : float = 1.0;
                            entity_mods__deviationBufferSizeMult : float = 1.0;
                            grenade_rethrow__grenadeEid : EntityId const? = null;
                            entity_mods__shotDeviationAdd : float = 0.0;
                            human_weap__fastThrowExclusive : bool = true;
                            human_unarmed__active : bool = false;
                            isAlive : bool = true;
                            isDowned : bool = false;
                            human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                            var human_net_phys : HumanActor;
                            var human_weap__throwMode : bool&)
  if isAlive && !isDowned
    let tick = evt.tick
    let dt = evt.dt
    let isForReal = evt.isForReal
    let atTime = float(tick + 1) * dt
    let gunDir = human_net_phys.phys.currentState.gunDir
    let physTransform = human_net_phys.phys.currentState.location |> location_makeTM()

    let updCtx = [[GunUpdateCtx
      dt=dt,
      atTime=atTime,
      isForReal=isForReal,
      eid=eid,
      isDowned=isDowned,
      isThrowingAllowed=human_weap__lockedGrenadeThrowingCounter == 0 && (human_vehicle__isHoldingGunPassenger || !isInVehicle),
      shotDeviationMult=entity_mods__shotDeviationMult,
      rotationShotSpreadDecrMult=entity_mods__rotationShotSpreadDecrMult,
      aimingAfterFireMult=entity_mods__aimingAfterFireMult,
      boltActionMult=entity_mods__boltActionMult,
      shotDeviationAdd=entity_mods__shotDeviationAdd,
      fastThrowExclusive=human_weap__fastThrowExclusive,
      deviationBufferSizeMult=entity_mods__deviationBufferSizeMult]]

    human_weap_gun_update(human_net_phys, human_weap__gunEids, human_weap__throwMode,
                          updCtx,  transform, gunDir, gunDir, physTransform,
                          human_net_phys.phys.appliedCT, grenade_rethrow__grenadeEid,
                          human_unarmed__active, human_attached_gun__attachedGunEid,
                          human_weap__jumpDeviation, human_weap__changePosDeviationCanAim, human_weap__changePosDeviationCanNotAim,
                          human_phys__jumpEndTime, human_phys__afterJumpDelay, human_phys__isInAirLong)


def determine_current_slot(cur_time : float;
                           human_net_phys : HumanActor;
                           human_inventory__entityToUse : EntityId;
                           isDowned : bool;
                           human_sec_anim__hideWeapon : bool;
                           human_sec_anim__hideMelee : bool;
                           human_sec_anim__play : bool;
                           human_unarmed__hiddenWeapon : bool;
                           action__running : bool;
                           burning__isPuttingOut : bool;
                           human_weap__radioMode : bool = false;
                           human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID)
  var curSlot = int(determine_current_weapon_slot(cur_time, human_net_phys))
  let attachedToGun = (human_attached_gun__attachedGunEid != INVALID_ENTITY_ID)
  let isHealing = (human_inventory__entityToUse != INVALID_ENTITY_ID &&
                  has(human_inventory__entityToUse, "item__healAnimEnumValue"))
  if ((!action__running && (human_net_phys.phys.currentState |> human_phys_state_get_is_swimming))
      || attachedToGun || isHealing || burning__isPuttingOut || isDowned || human_unarmed__hiddenWeapon
      || human_net_phys.phys.currentState |> human_phys_state_attachedToLadder)
    curSlot = -1
  if human_sec_anim__play && (human_sec_anim__hideWeapon || (human_sec_anim__hideMelee && curSlot == int(HUWeaponSlots EWS_MELEE)))
    curSlot = -1
  if human_weap__radioMode
    curSlot = -1
  return curSlot


def has_any_attached_gun(human_weap__gunEids : EidList)
  for gunEid in human_weap__gunEids
    if get_bool(gunEid, "human_gun_attached") ?? false
      return true
  return false


def set_current_gun(eid : EntityId;
                    human_weap__gunEids : EidList;
                    cur_gun : int;
                    var human_weap__currentGunSlot : int&)
  if human_weap__currentGunSlot == cur_gun
    return

  human_weap__currentGunSlot = cur_gun
  for i in iter_range(human_weap__gunEids)
    let isAttached = (i == cur_gun)
    sendEvent(human_weap__gunEids[i], [[CmdWeapAttach toEid=eid, isAttached=isAttached, slotId=i]])

  sendEvent(eid, [[EventOnSelectWeap curr_gun_slot_id=human_weap__currentGunSlot]])


def send_attach_event_to_current_gun(eid : EntityId;
                                     human_weap__gunEids : EidList;
                                     human_weap__currentGunSlot : int)
  if human_weap__currentGunSlot < 0 || human_weap__currentGunSlot >= length(human_weap__gunEids)
    return
  let gunEid = human_weap__gunEids[human_weap__currentGunSlot]
  if !(get_bool(gunEid, "human_gun_attached") ?? true)
    sendEvent(gunEid, [[CmdWeapAttach toEid=eid, isAttached=true, slotId=human_weap__currentGunSlot]])


def human_weap_es_impl(var human_weap__currentGunSlot : int&;
                       cur_time : float;
                       eid : EntityId;
                       human_weap__gunEids : EidList;
                       human_net_phys : HumanActor;
                       human_inventory__entityToUse : EntityId;
                       action__running : bool;
                       isInVehicle : bool;
                       isInVehicleHidden : bool;
                       isDowned : bool;
                       human_vehicle__isHoldingGunPassenger : bool;
                       human_sec_anim__hideWeapon : bool;
                       human_sec_anim__hideMelee : bool;
                       human_sec_anim__play : bool;
                       human_unarmed__hiddenWeapon : bool;
                       burning__isPuttingOut : bool;
                       human_weap__radioMode : bool = false;
                       human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID)
  let curSlot = determine_current_slot(cur_time, human_net_phys, human_inventory__entityToUse,
    isDowned, human_sec_anim__hideWeapon, human_sec_anim__hideMelee,
    human_sec_anim__play, human_unarmed__hiddenWeapon, action__running, burning__isPuttingOut,
    human_weap__radioMode, human_attached_gun__attachedGunEid)

  let animSlot = isInVehicle && !isInVehicleHidden && !human_vehicle__isHoldingGunPassenger && !action__running ? -1 : curSlot

  if human_weap__currentGunSlot != curSlot || (animSlot < 0 && has_any_attached_gun(human_weap__gunEids))
    set_current_gun(eid, human_weap__gunEids, animSlot, human_weap__currentGunSlot)
  human_weap__currentGunSlot = curSlot

  if !isDowned
    send_attach_event_to_current_gun(eid, human_weap__gunEids, animSlot)


[es(tag=server, before=human_weap_post_phys_es)]
def human_weap_es(evt : CmdPostPhysUpdate;
                  eid : EntityId;
                  human_weap__gunEids : EidList;
                  human_net_phys : HumanActor;
                  human_inventory__entityToUse : EntityId;
                  action__running : bool = false;
                  isInVehicle : bool = false;
                  isInVehicleHidden : bool = false;
                  isDowned : bool = false;
                  human_vehicle__isHoldingGunPassenger : bool = false;
                  human_sec_anim__hideWeapon : bool = false;
                  human_sec_anim__hideMelee : bool = false;
                  human_sec_anim__play : bool = false;
                  human_unarmed__hiddenWeapon : bool = false;
                  burning__isPuttingOut : bool = false;
                  human_weap__radioMode : bool = false;
                  isAlive : bool;
                  human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                  var human_weap__currentGunSlot : int&)
  if isAlive
    human_weap_es_impl(
      human_weap__currentGunSlot, get_sync_time(), eid, human_weap__gunEids,
      human_net_phys, human_inventory__entityToUse, action__running,
      isInVehicle, isInVehicleHidden, isDowned, human_vehicle__isHoldingGunPassenger,
      human_sec_anim__hideWeapon, human_sec_anim__hideMelee,
      human_sec_anim__play, human_unarmed__hiddenWeapon, burning__isPuttingOut,
      human_weap__radioMode, human_attached_gun__attachedGunEid)


[es(tag=netClient, after=(update_phys_es, before_human_inventory_use_update), before=human_weap_update_es)]
def human_weap_client_es(info : ParallelUpdateFrameDelayed;
                         eid : EntityId;
                         human_weap__gunEids : EidList;
                         human_net_phys : HumanActor;
                         human_inventory__entityToUse : EntityId;
                         action__running : bool = false;
                         isInVehicle : bool = false;
                         isInVehicleHidden : bool = false;
                         isDowned : bool = false;
                         human_vehicle__isHoldingGunPassenger : bool = false;
                         human_sec_anim__hideWeapon : bool = false;
                         human_sec_anim__hideMelee : bool = false;
                         human_sec_anim__play : bool = false;
                         human_unarmed__hiddenWeapon : bool = false;
                         burning__isPuttingOut : bool = false;
                         human_weap__radioMode : bool = false;
                         isAlive : bool;
                         human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                         var human_weap__currentGunSlot : int&)
  if isAlive
    human_weap_es_impl(
      human_weap__currentGunSlot, info.curTime, eid, human_weap__gunEids,
      human_net_phys, human_inventory__entityToUse, action__running,
      isInVehicle, isInVehicleHidden, isDowned, human_vehicle__isHoldingGunPassenger,
      human_sec_anim__hideWeapon, human_sec_anim__hideMelee,
      human_sec_anim__play, human_unarmed__hiddenWeapon, burning__isPuttingOut,
      human_weap__radioMode, human_attached_gun__attachedGunEid)


[es(track=(isAlive, isDowned), on_event=EventEntityDied, before=destroy_nonlootable_weapons)]
def human_weap_drop_grenade_es(evt : Event;
                               eid : EntityId;
                               isAlive : bool;
                               isDowned : bool;
                               human_weap__gunEids : EidList;
                               var human_weap__throwMode : bool&;
                               var human_net_phys : HumanActor)
  if isAlive && !isDowned
    return

  if human_weap__throwMode
    query(human_weap__gunEids[int(HUWeaponSlots EWS_GRENADE)]) <| $ [es] (grenade_thrower__projectileEntity : EntityId)
      query(grenade_thrower__projectileEntity) <| $ [es] (slot_attach__attachedTo : EntityId;
                                                          shell__shell_id__shell_id : int;
                                                          var active : bool&;
                                                          var shell__explTime : float?)
        if !slot_attach__attachedTo
          return
        if !active && shell__explTime != null
          // If the soldier is downed before grenade's cookProgressTime, activate and set explosion timer anyway
          detonation_get_props(shell__shell_id__shell_id) <| $(detonationProps : DetonationProps)
            *shell__explTime = get_sync_time() + detonationProps.timer

        active = true
        query(eid) <| $ [es] (human_net_phys__velocity : float3)
          assume curState = human_net_phys.phys.currentState
          var tm = IDENT_TM
          let locTm = curState.location |> location_makeTM()
          human_net_phys.phys |> human_phys_calcGunTm(PrecomputedPresetMode FPV,
                                                      locTm,
                                                      curState.gunAngles.y,
                                                      curState.leanPosition,
                                                      curState.height,
                                                      tm)
          let curTime = get_sync_time()
          let isForReal = true
          let rndSeed = phys_time_to_seed(curTime)

          let dir = (!isAlive ? normalize(float3(0.14, -0.99, 0.0)) // Approximative down
                              : human_net_phys.phys.currentState.gunDir)

          using(dir, dir, human_net_phys__velocity, tm, tm) <| $(var gloc : GunLocation#)
            using() <| $(var gtrlNew : GunControls#)
              gtrlNew.shoot = true
              gtrlNew.wishShoot = false
              gtrlNew.boltActionMult = 1.0
              gtrlNew.timeStep = 0.01
              sendEventImmediate(
                human_weap__gunEids[int(HUWeaponSlots EWS_GRENADE)],
                [[CmdGunUpdate
                  atTime=curTime,
                  isForReal=isForReal,
                  seed=rndSeed,
                  gctrl := gtrlNew,
                  gloc := gloc]])
      clear_throw_mode(eid, human_weap__gunEids, human_weap__throwMode, human_net_phys.phys)


def detach_guns(eid : EntityId;
                human_weap__gunEids : EidList)
  for i in iter_range(human_weap__gunEids)
    sendEvent(human_weap__gunEids[i], [[CmdWeapAttach toEid=eid, isAttached=false, slotId=i]])
    sendEvent(human_weap__gunEids[i], [[CmdWeapDetach]])


def on_detach_all_guns_impl(eid : EntityId;
                            human_weap__gunEids : EidList;
                            var human_weap__currentGunSlot : int&)
  detach_guns(eid, human_weap__gunEids)
  set_current_gun(eid, human_weap__gunEids, -1, human_weap__currentGunSlot)


def on_detach_all_guns(eid : EntityId;
                       human_weap__gunEids : EidList;
                       var human_weap__currentGunSlot : int&)
  on_detach_all_guns_impl(eid, human_weap__gunEids, human_weap__currentGunSlot)

  send_net_event(eid, [[HumanDetachAllGuns]])


[es(tag=server, track=isAlive, on_event=EventEntityDied, on_disappear, before=destroy_nonlootable_weapons)]
def human_weap_dead_es(evt : Event;
                       eid : EntityId;
                       human_weap__gunEids : EidList;
                       isAlive : bool;
                       var human_weap__currentGunSlot : int&)
  if !isAlive
    if human_weap__currentGunSlot >= 0
      on_detach_all_guns(eid, human_weap__gunEids, human_weap__currentGunSlot)


[es(tag=server)]
def human_weap_req_switch_firing_mode_es(evt : HumanWeapRequestSwitchFiringMode;
                                         human_weap__gunEids : EidList)
  let slotId = int(evt.slotId)
  let modeId = int(evt.modeId)
  if slotId >= length(human_weap__gunEids)
    return

  query(human_weap__gunEids[slotId]) <| $ [es] (var gun : Gun; var gun__firingModeIndex : int&)
    if gun |> gun_checkFiringModeIndex(modeId)
      gun |> gun_setFiringModeIndex(evt.modeId)
      gun__firingModeIndex = modeId


[es(tag=netClient)]
def human_weap_human_detach_all_guns_es(evt : HumanDetachAllGuns;
                                        eid : EntityId;
                                        human_weap__gunEids : EidList;
                                        var human_weap__currentGunSlot : int&)
  on_detach_all_guns_impl(eid, human_weap__gunEids, human_weap__currentGunSlot)


[es]
def human_weap_set_current_gun_es(evt : HumanWeapSetCurrentGun;
                                  var human_net_phys : HumanActor)
  human_net_phys.phys.producedCT |> set_chosen_weapon(HUWeaponSlots(int(evt.slot)))
  human_net_phys.phys.currentState.weapEquipState.curSlot = HUWeaponSlots(int(evt.slot))

[es(on_appear, tag=gameClient, REQUIRE=hero)]
def human_weap_reset_gun_slot_es(evt : Event;
                                 human_weap__currentGunSlot : int;
                                 var human_net_phys : HumanActor)
  if human_weap__currentGunSlot >= 0
    human_net_phys.phys.producedCT |> set_chosen_weapon(HUWeaponSlots(human_weap__currentGunSlot))
    human_net_phys.phys.currentState.weapEquipState.curSlot = HUWeaponSlots(human_weap__currentGunSlot)

[es]
def human_weap_weap_throw_back_abort_es(evt : HumanWeapThrowBackAbort;
                                        var human_weap__throwMode : bool&;
                                        var human_net_phys : HumanActor)
  if human_weap__throwMode && human_net_phys.phys.appliedCT |> is_control_bit_set(HumanPhysControlType HCT_THROW_BACK)
    human_weap__throwMode = false
    human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType HCT_THROW_BACK, false)


def update_total_ammo(gun_eid : EntityId;
                      itemContainer : EidList)
  query(gun_eid) <| $ [es(REQUIRE=gun)] (gun__wishAmmoItemType : int;
                                         var gun__totalAmmo : int&)
    gun__totalAmmo = get_total_ammo_count(itemContainer, gun__wishAmmoItemType, gun_eid)


[es(tag=server, track=(human_weap__gunEids, itemContainer), on_event=EventUpdatedItemContainer)]
def human_weap_update_total_count_es(evt : Event;
                                     human_weap__gunEids : EidList;
                                     human_weap__gunMods : Array;
                                     itemContainer : EidList)
  for i in iter_range(human_weap__gunEids)
    update_total_ammo(human_weap__gunEids[i], itemContainer)
  for i in iter_range(human_weap__gunMods)
    let gunMods = get_ecs_EidList(human_weap__gunMods[i])
    if gunMods != null
      for gunModEid in *gunMods
        update_total_ammo(gunModEid, itemContainer)


[es(tag=server, track=(human_weap__gunEids, itemContainer))]
def human_weap_update_additional_ammo_count_es(evt : Event;
                                               human_weap__gunEids : EidList;
                                               itemContainer : EidList)
  for i in iter_range(human_weap__gunEids)
    let gunEid = human_weap__gunEids[i]
    query(gunEid) <| $ [es] (gun__isDualMagReady : bool;
                             var gun__additionalAmmo : int&)
      if gun__isDualMagReady
        find_ammo_for_gun(gunEid, itemContainer, INVALID_ITEM_ID, 0) <| $(ammoForGun : AmmoItemForGunResult)
          gun__additionalAmmo = ammoForGun.ammoCount


[es(tag=server, on_appear, track=(gun__isDualMagReady, gun__owner))]
def gun_update_additional_ammo_count_es(evt : Event;
                                        eid : EntityId;
                                        gun__owner : EntityId;
                                        gun__isDualMagReady : bool;
                                        var gun__additionalAmmo : int&)
  if !gun__isDualMagReady
    gun__additionalAmmo = 0
  else
    query(gun__owner) <| $ [es] (itemContainer : EidList)
      find_ammo_for_gun(eid, itemContainer, INVALID_ITEM_ID, 0) <| $(ammoForGun : AmmoItemForGunResult)
        gun__additionalAmmo = ammoForGun.ammoCount


[es(tag=server, track=gun__wishAmmoItemType)]
def human_weap_update_total_count_wish_ammo_item_type_es(evt : Event;
                                                         eid : EntityId;
                                                         gun__owner : EntityId;
                                                         gun__wishAmmoItemType : int;
                                                         var gun__totalAmmo : int&)
  query(gun__owner) <| $ [es] (itemContainer : EidList)
    gun__totalAmmo = get_total_ammo_count(itemContainer, gun__wishAmmoItemType, eid)


[es]
def human_weap_reinit_guns_es(evt : CmdReinitWeapons;
                              eid : EntityId;
                              human_weap__weapTemplates : Object;
                              var human_weap__currentGunSlot : int&;
                              var human_weap__gunEids : EidList;
                              var human_weap__gunMods : Array;
                              var human_weap__weapInitialComponents : Array)
  human_weap__currentGunSlot = server_recreate_guns(eid, human_weap__weapTemplates,
                                                    int(RecreateGunsFlags Attach),
                                                    human_weap__gunEids, human_weap__gunMods,
                                                    human_weap__weapInitialComponents)


[es(tag=server, on_appear)]
def reserve_ammo_props_init_es(evt : Event;
                               human_weap__weapInfo : Array;
                               var human_weap__reserveAmmoPropIds : IntList)
  let weapInfoSize = length(human_weap__weapInfo)
  human_weap__reserveAmmoPropIds |> resize(weapInfoSize)
  for i in range(weapInfoSize)
    let weapInfoSlot = get_ecs_object(human_weap__weapInfo[i])
    if weapInfoSlot != null
      let resvAmmoTypeName = weapInfoSlot |> get_string("reserveAmmoTemplate", "")
      human_weap__reserveAmmoPropIds[i] = resvAmmoTypeName != "" ? int(ecs_hash(resvAmmoTypeName)) : -1


[es(track=human_weap__mortarMode)]
def switch_to_mortar_mode_es(evt : Event;
                             human_weap__mortarMode : bool;
                             var human_weap__enableClampVertAimAngle : bool&)
  human_weap__enableClampVertAimAngle = !human_weap__mortarMode


[es(on_appear)]
def init_radio_slots_es(evt : Event;
                        radio__unequippedSlotName : string;
                        radio__equippedSlotName : string;
                        var radio__unequippedSlotId : int&;
                        var radio__equippedSlotId : int&)
  radio__unequippedSlotId = animchar_getSlotId(radio__unequippedSlotName)
  radio__equippedSlotId = animchar_getSlotId(radio__equippedSlotName)


[es(tag=gameClient)]
def human_weap_switch_to_first_weap_with_ammo(evt : CmdSwitchToFirstWeapWithAmmo;
                                              human_weap__gunEids : EidList;
                                              var human_net_phys : HumanActor)
  switch_to_first_weap_with_ammo(human_weap__gunEids, human_net_phys.phys)


[es(tag=(server, net), REQUIRE=human_weap__gunEids)]
def human_weap_reload_net(evt : HumanRequestUnloadAmmo;
                          eid : EntityId)
  if evt.slotId >= 0
    unload_ammo_impl(eid, evt.slotId)
