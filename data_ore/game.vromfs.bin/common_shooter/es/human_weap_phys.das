require ecs
require ecs.common
require EnlistedHuman
require HumanPhys
require player
require game.es.events
require enlisted.events_enlisted

def reset_human_aim_zoom(var human_net_phys : HumanActor; var camera__magnification : float&)
  human_net_phys.phys.currentState.aimPosition = 0.f
  human_net_phys.phys.currentState.zoomPosition = 0.f
  human_net_phys.phys.previousState.aimPosition = 0.f
  human_net_phys.phys.previousState.zoomPosition = 0.f
  camera__magnification = 1.f

[es(before=after_net_phys_sync, after=before_net_phys_sync)]
def human_weap_phys_es(
                       info : ParallelUpdateFrameDelayed;
                       human_weap__reloadAtTime : float;
                       human_weap__weapModActivateStartTime : float;
                       human_weap__blockAiming : bool;
                       boltActionProgress : float;
                       isGunManualLoadMode : bool;
                       var human_net_phys : HumanActor;
                       human_weap__staminaCanAim : bool = true;
                       human_weap__currentGunEid : EntityId = INVALID_ENTITY_ID;
                       human_attached_gun__isAttached = false;
                       isDowned = false;
                       action__running = false)

  assume ct = human_net_phys.phys.currentState
  let reloading = (info.curTime <= human_weap__reloadAtTime) || (human_weap__weapModActivateStartTime > 0.0f)
  let standState = ct.standState
  let isCrawling = ct.moveState != HUMoveState EMS_STAND && ct.isCrawl
  let isShootingStandState = standState == HUStandState ESS_STAND || standState == HUStandState ESS_CROUCH || standState == HUStandState ESS_CRAWL
  let isBoltActionInProgress = isGunManualLoadMode ? boltActionProgress > 0.f && boltActionProgress < 1.f : false

  let canAimReloading = has(human_weap__currentGunEid, "gun__canAimReloading")
  let canZoomReloading = has(human_weap__currentGunEid, "gun__canZoomReloading")
  let canZoomInBoltAction = has(human_weap__currentGunEid, "gun__canZoomInBoltAction")

  human_phys_state_set_can_aim(ct,
    (!reloading || human_attached_gun__isAttached || canAimReloading) &&
    (ct.weapEquipState.curState == HUWeaponEquipState EES_EQUIPED) &&
    !isBoltActionInProgress &&
    human_weap__staminaCanAim &&
    !isDowned && !human_weap__blockAiming && !isCrawling && isShootingStandState)

  human_phys_state_set_can_zoom(ct,
    (!reloading || human_attached_gun__isAttached || canZoomReloading) &&
    !isDowned && !human_weap__blockAiming &&
    (!isBoltActionInProgress || canZoomInBoltAction)
    && !action__running && isShootingStandState)

[es(track=human_anim__vehicleSelected, REQUIRE=human_anim__vehicleSelected)]
def human_weap_zoom_reset_es(evt : Event; var human_net_phys : HumanActor; var camera__magnification : float&)
  reset_human_aim_zoom(human_net_phys, camera__magnification)

[es(on_event=EventEntityDowned)]
def downed_human_reset_zoom_es(evt : Event; var human_net_phys : HumanActor; var camera__magnification : float&)
  reset_human_aim_zoom(human_net_phys, camera__magnification)

[es(on_appear, REQUIRE=attachedToParent, tag=gameClient)]
def init_human_weapon_len_es(evt : Event;
                             eid : EntityId;
                             gun__owner : EntityId;
                             gun__standOffset : float3 = float3(0.f, 0.f, 0.f);
                             gun__crouchOffset : float3 = float3(0.f, 0.f, 0.f);
                             gun__length : float = 0f)
  query(gun__owner) <| $ [es] (human_weap__gunEids : EidList; var human_net_phys : HumanActor&)
    var slotId = -1
    for i in iter_range(human_weap__gunEids)
      if human_weap__gunEids[i] == eid
        slotId = i
        break

    if slotId < 0
      return

    human_net_phys.phys |> human_phys_setWeaponOffs(gun__standOffset, gun__crouchOffset, slotId)
    human_net_phys.phys |> human_phys_setWeaponLen(gun__length, slotId)

