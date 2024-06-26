module events_common_shooter shared
require ecs
require dm
require DngDm
require Gun
require DaWeapons
require DaWeaponProps
require DngNet
require BitStream
require RendInst

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdNextBulletIdRequest
  triggerGroup : int

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdRequestStabilizer
  enabled : bool

[event(unicast)]
struct EventOnSelectNextBulletId
  gunEid : EntityId
  nextBulletId : int

[event(unicast)]
struct EvtEntityKilledToPart
  offender : EntityId
  collNodeId : int
  damageType : int

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventHeadShotKill {}

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdDeleteMapUserPoint {}

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdCreateMapUserPoint
  pos : float3
  dir : float3
  norm : float3
  item_name : string
  markOwnerEid : EntityId

[event(unicast)]
struct CmdCreateMapPoint
  x : float
  z : float

[cpp_event(broadcast, with_scheme, cpp_gen=false)]
struct EventOnEntityHit
  victim : EntityId
  offender : EntityId
  hitResult : int
  damageType : int
  shellId : int
  gunPropsId : int
  actionPropsId : int
  collNodeId : int
  deltaHp : float
  blockingDeltaHp : float
  stoppingPower : float
  hitPos : float3
  hitDir : float3
  hitNorm : float3
  dmgMult : float
  armorMult : float
  armorPenetration : float
  shatterCount : int

[cpp_event(unicast)]
struct EventOnGunCreated
  gunEid : ecs::EntityId

[cpp_event(unicast)]
struct CmdOnHeroHit
  damageType : int
  hitDir : float3
  collNodeId : int

[cpp_event(unicast)]
struct EventProjectileHitScene
  pos : float3
  shouldStop : bool
  ricochetAngle : float
  smokeTracerStop : bool
  rendinstCellIdx : int
  rendinstIdx : int
  rendinstPool : int
  rendinstOffs : uint
  rendinstLayer : int
  matId : int
  norm : float3
  allowDetonation : bool
  sceneIntersectionsExceeded : bool
  collType : int
  vel : float3
  riexHandle : riex_handle_t

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventEntityDowned
  offender : EntityId

[event(unicast)]
struct EventPlayerKilledEntity
  victimEid : EntityId
  killerEid : EntityId
  deathDesc_gunPropsId : int16
  deathDesc_collNodeId : int16
  deathDesc_damageTypeId : uint16
  victimPlayerEid : EntityId
  killerPlayerEid : EntityId

[cpp_event(unicast)]
struct EventOnPartDamaged
  partId : int
  damageTypeId : int
  damageEffectsMask : int
  damage : float
  hpFixed : uint16
  prevHpFixed : uint16
  state : int
  hitData : HitData

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdRestoreEntityHp
  restoreHp : float

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdRestoreStamina
  restoreStamina : float

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdPutOutFireStart {}

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdPutOutFireStop {}

[event(unicast)]
struct CmdMedkitUse {}

[event(unicast)]
struct CmdMedkitUseCancel {}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct EventMortarCanceled {}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct EventMortarTargetSelected
  targetPos : float3

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdStartMortarStrikeAtPos
  pos : float3

[cpp_event(unicast)]
struct EventOnParentLoaded
  eid : ecs::EntityId
  slotId : int

[cpp_event(unicast)]
struct CmdWeapAttach
  toEid : EntityId
  isAttached : bool
  slotId : int

[event(unicast)]
struct CmdWeapDetach {}

[event(unicast)]
struct CmdDetachAttachedGun {}

[cpp_event(unicast)]
struct CmdWeapPhysUpdate
  owner : ecs::EntityId
  atTime : float
  dt : float
  isForReal : bool
  slotId : int
  gctrl : GunControls
  gloc : GunLocation

[cpp_event(unicast)]
struct EventOnInstallWeapMod
  slotTag : string
  gunSlotId : int
  withSfx : bool

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct HumanWeapThrowBackAbort {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct HumanDetachAllGuns {}

[cpp_event(unicast)]
struct HumanWeapSetCurrentGun
  slot : uint8

[event(unicast)]
struct CmdReinitWeapons {}

[event(unicast)]
struct CmdReinitWeaponInSlot
  slot : int

[event(broadcast)]
struct EventOnGunBlocksShoot
  reason : string

[event(broadcast)]
struct EventOnWindChange{}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct HumanRequestModActivate
  slotId : int
  activate : bool

[cpp_event(unicast)]
struct EventOnShellExploded
  explPos : float3
  shellId : int16
  damageId : int16
  ballisticsId : int16
  gunPropsId : int
  owner : EntityId

[cpp_event(unicast)]
struct EventShellExplodedServer
  pos : float3

[cpp_event(unicast)]
struct CmdShellExplode
  position : float3
  prevPos : float3
  vel : float3

[cpp_event(unicast)]
struct CmdShellExplosionFx {}

[event(unicast)]
struct EventHumanStartedReload {}

[event(unicast)]
struct CmdUnloadAmmo
  unloadManually : bool

[event(unicast)]
struct CmdRequestReload
  atTime : float
  gunEid : ecs::EntityId
  isQuick : bool

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct HumanRequestUnloadAmmo
  slotId : int

[event(unicast)]
struct CmdInterruptReloadImmediately {}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdInventoryPickupGunMod
  item : EntityId

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdNextSpecialGun {}

[event(unicast)]
struct CmdWeapModActivate
  slotId : int
  activate : bool

[cpp_event(unicast)]
struct CmdSetWishAmmoItemType
  slot_id : int
  item_id : int

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestQuickThrowGrenade
  grenade_ammo_id : int

[event(unicast)]
struct CmdToggleWishAmmoItemType
  slot_id : int

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct HumanRequestSetWishAmmoItemType
  slot_id : int
  item_id : int
  is_grenade_slot_current : bool

[event(unicast)]
struct EventOnGrenadeThrow
  gun_props_id : int

[cpp_event(unicast)]
struct EventShot
  launchDesc : LaunchDesc

[cpp_event(unicast)]
struct CmdNetShot
  shellId : int16
  damageId : int16
  ballisticsId : int16
  gunPropsId : int16
  atTime : float
  initialLifeTime : float
  tm : float3x4
  vel : float3
  firingMode : uint
  bombBayHeight : float

[cpp_event(unicast)]
struct CmdLaunchShell
  launchDesc : LaunchDesc
  gunEid : EntityId

[cpp_event(unicast)]
struct CmdLaunchProjectile
  launchDesc : LaunchDesc
  gunEid : EntityId

[cpp_event(broadcast)]
struct EventProjectileFlight
  prevPos : float3
  normalizedDir : float3
  dist : float
  isLocalOwner : bool


[cpp_event(unicast)]
struct CmdGunUpdate
  atTime : float
  isForReal : bool
  seed : int
  gctrl : GunControls
  gloc : GunLocation

[event(unicast)]
struct CmdTurretsUpdate
  tick : int
  dt : float

[cpp_event(unicast)]
struct TurretControlsMsg
  bs : BitStream // TODO: Rework, remove BitStream field

[event(unicast)]
struct EventOnTurretShooting
  isStart : bool
  turretNo : int

[cpp_event(unicast)]
struct CmdSyncTurretShootAngles
  turretEid : EntityId
  shootAngles : float2

[cpp_event(unicast)]
struct TurretShotShellMsg
  turretNo : int
  shellId : int16
  damageId : int16
  ballisticsId : int16
  gunPropsId : int16
  atTime : float
  initialLifeTime : float
  tm : float3x4
  vel : float3
  firingMode : uint
  bombBayHeight : float

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestBipodPlacing
  enabled : bool
  isCrawl : bool
  anchorPos : float3
  anchorDir : float3
  anchorHeight : float
  anchorOffset : float3
  anchorNormal : float3
  anchorYawLimit : float2
  recoilMult : float

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct HumanWeapRequestSwitchFiringMode
  slotId : uint8
  modeId : uint8

[event(unicast)]
struct CmdAutoequipGunMod
  slotId : int

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct HumanPickupWeapRequest
  itemEid : EntityId
  slotId : int

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct HumanDropWeapRequest
  slotId : int

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct HumanSwapWeapRequest
  fromSlotId : int
  toSlotId : int

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct HumanInstallItemOnWeapRequest
  itemEid : EntityId
  slotId : int
  slotName : string

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct HumanPickupAndInstallItemOnWeapRequest
  itemEid : EntityId
  slotId : int
  slotName : string

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct HumanRemoveItemFromWeapRequest
  slotId : int
  slotName : string
  toGround : bool

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct HumanSwapWeaponModsRequest
  fromSlotId : int
  fromWeapModSlot : string
  toSlotId : int
  toWeapModSlot : string

[event(unicast)]
struct CmdInventoryDropGun
  slotId : int

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct HumanAttachToGunResponse
  gun_eid : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct HumanDetachFromGunResponse {}

[event(unicast)]
struct HumanAttachToGunComplete
  gun_eid : EntityId

[event(unicast)]
struct HumanDetachFromGunComplete {}

[event(unicast)]
struct CmdResolveTurrets {}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct HumanRequestParachuteOpen {}

[event(unicast)]
struct CmdHumanEndFreefall {}

[cpp_event(unicast)]
struct CmdTrackHeroWeapons {}

[event(unicast)]
struct CmdInitPolyCapzoneAreas {}

// TODO: probably remove this after foolmoon event
[event(broadcast, routing=ROUTING_SERVER_TO_CLIENT, net_liable=ignore)]
struct CmdShellExplodeFx
  position : float3
  effectTemplate : string

[cpp_event(unicast)]
struct EventShotDry {}

[cpp_event(unicast)]
struct CmdGuidanceLockSwitch
  on : bool

[cpp_event(unicast)]
struct EventOnPlayerLooted
  itemType : string
  region : string

[cpp_event(unicast)]
struct CmdSwapEquipSlots
  item : EntityId
  fromSlotName : string
  toSlotName : string
