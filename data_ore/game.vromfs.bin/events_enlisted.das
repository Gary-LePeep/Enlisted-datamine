module events_enlisted shared
require ecs
require DngWalkerai
require common_shooter.events_common_shooter
require enlisted.game.es.medic_common
require game.es.squad_order_common
require game.es.binocular_common
require DngWeapon
require DaWeaponProps
require DaWeapons
require CollisionTraces
require DngDm

[cpp_event(broadcast)]
struct ParallelUpdateFrameDelayed
  curTime : float
  dt : float

[cpp_event(unicast)]
struct EventOnApplyTornWound
  animchar_eid : EntityId
  bone_break_params_id : uint

[cpp_event(unicast)]
struct QueryPhysActorsNotCollidable
  shouldCollide : bool
  otherEid : EntityId

[event(broadcast)]
struct EventRequestedAircraftShootAllBombs
  aircraftEid : EntityId

[cpp_event(unicast)]
struct CmdInitSkeletonAttach {}

[event(broadcast)]
struct EventOnChangeSpawnTeams {}

[event(unicast)]
struct CmdFinishPlacePlaceableItem
  tm : float3x4
  newTemplate : string
  itemEid : EntityId
  vehicleEid : EntityId
  vehicleNodeId : int

[event(unicast)]
struct faceGenInfoUpdated {}

[event(unicast)]
struct faceGenSaveInfo
  initialSave : bool

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct RequestSquadOrder
  orderType : SquadOrder
  orderPosition : float3
  orderUseEntity : ecs::EntityId

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct RequestSquadMateOrder
  orderType : SquadMateOrder
  orderPosition : float3
  orderUseEntity : ecs::EntityId

[event(unicast)]
struct CmdMortarAttackOrder
  orderPosition : float3
  orderTargetPos : float3
  orderNumShots : int

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct RequestSquadFormation
  spread : SquadFormationSpread

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct RequestSquadBehaviour
  behaviour : int

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct EventDigRequest
  pos : float3

[event(unicast)]
struct RqContextCommand{}

[event(unicast)]
struct RqCancelContextCommand
  include_personal_orders : bool

[cpp_event(unicast)]
struct CmdSelectBuildingType
  data : ecs::Object // index : int

[event(unicast)]
struct EventTryBuildFortification {}

[event(unicast)]
struct EventRecreateBuildPreview {}

[event(unicast)]
struct EventRecreateBuildIcons {}

[event(unicast)]
struct EventApplyCustomAnimcharVars {}

[cpp_event(unicast)]
struct EventItemAttached
  attach_to : EntityId

[cpp_event(unicast)]
struct EventItemDetached
  detach_from : EntityId

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdBuildFortification
  builderGunEid : ecs::EntityId
  tm : float3x4
  boxMin : float3
  boxMax : float3

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdStartPlacePlaceableItem
  itemEid : EntityId
  tm : float3x4
  vehicleEid : EntityId
  vehicleNodeId : int

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct EventSetBuildingTarget
  target : EntityId

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct EventDismantleBuilding
  target : EntityId

[event(unicast)]
struct EventOnDestroyBuilding {}

[event(broadcast)]
struct EventUpdateBuildingColors
  selectedObject : EntityId
  builderPos : float3
  isEngineer : bool
  engineerTeam : int

[event(unicast)]
struct EventEngineerBuildingBroken
  offender : EntityId

[event(unicast)]
struct CmdWallposterPreview
  enable : bool
  wallPosterId : int

[event(unicast)]
struct CmdWallposterPlace {}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct WallposterRequestPlace
  wallPosterId : int
  wallPostersCurCount : int
  tm : float3x4
  bmin : float3
  bmax : float3

[event(unicast)]
struct OnScoringKillBySquadMember
  victim : EntityId
  offender : EntityId

[event(unicast)]
struct OnScoringVehicleKillBySquadMember
  victim : EntityId
  offender : EntityId

[event(unicast)]
struct EventOnPlayerWipedOutInfantrySquad {}

[event(broadcast)]
struct EventTeamWon
  team : int

[event(broadcast)]
struct EventTeamLost
  team : int

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventMechStepInfo
  limbIdx : int
  pos : float3
  detach : bool
  isNextStep : bool

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventMechStepRelativeInfo
  limbIdx : int
  pos : float3

[event(broadcast)]
struct EventStepShakeCamera
  position : float3
  max_distance : float
  wish_shake : float

[event(unicast)]
struct EventMechStepSound
  pos : float3

[event(broadcast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventTeamLowScore
  teamId : int

[event(broadcast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventTeamLoseHalfScore
  teamId : int

[event(unicast)]
struct EventPlayerSquadFinishedCapturing {}

[event(unicast)]
struct EventOnBarbwireDamageAward {}

[event(unicast)]
struct EventAddPlayerStat
  stat : string

[event(unicast)]
struct EventAddPlayerAwardWithStat
  stat : string

[event(unicast)]
struct EventOnCapzoneFortificationAward {}

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdHumanHoorayRequest {}

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdBlinkMarker {}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestForgiveFriendlyFire
  player : EntityId

[event(unicast)]
struct OnFriendlyFire
  offender : EntityId
  gunPropsId : int

[event(unicast)]
struct OnTeamKill
  offender : EntityId
  gunPropsId : int

[event(broadcast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventKillReport
  victim : EntityId
  victimTeam : int
  victimPlayer : EntityId
  victimName : string
  victimRank : int
  isVictimVehicle : bool
  scoreId : string
  killer : EntityId
  killerTeam : int
  killerPlayer : EntityId
  killerName : string
  killerRank : int
  isKillerVehicle : bool
  isHeadshot : bool
  damageType : int
  gunName : string

[event(unicast)]
struct CmdSwitchSquad {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdResupplyVehicle {}

[event(unicast)]
struct CmdResupplyPassengers {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdResupplyPassengersFinished
  vehicle : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdResetupVehicle
  setupOnWater : bool
  tm : float3x4
  speed : float

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestNextRespawnEntity
  memberEid : EntityId

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdRequestRespawn
  squadId : int
  memberId : int
  spawnGroup : int
  isParatroopers : bool
  withoutVehicle : bool

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdCancelRequestRespawn
  squadId : int
  memberId : int
  spawnGroup : int
  isParatroopers : bool
  withoutVehicle : bool

[event(unicast)]
struct RqPersonalContextCommand{}

[event(unicast)]
struct RqCancelPersonalContextCommand{}

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct RequestPersonalSquadMateOrder
  orderType : int
  orderPosition : float3
  orderUseEntity : ecs::EntityId

[event(unicast)]
struct EventAwardZoneCapturers {}

[event(unicast)]
struct EventAwardZoneCapturersProgressTick
  amount : float
  team : int

[event(unicast)]
struct EventForceCapture
  team : int

[event(unicast)]
struct EventBombSiteExplosion {}

[event(unicast)]
struct EventBombSitePlanting
  bombSiteOperator : EntityId

[event(unicast)]
struct EventBombSitePlanted
  bombSiteOperator : EntityId

[event(unicast)]
struct EventBombSiteDefusing
  bombSiteOperator : EntityId

[event(unicast)]
struct EventBombSiteDefused
  bombSiteOperator : EntityId

[event(unicast)]
struct EventPlayerSquadHelpedToDestroyPoint {}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdVoteToKick
  voteYes : bool
  accused : EntityId

[event(unicast)]
struct CmdOpenSupplyMenu
  boxEid : EntityId

[event(unicast)]
struct CmdCloseSupplyMenu
  needApplyPreset : bool

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestApplySupplyScheme
  boxEid : EntityId
  index : int

[event(broadcast)]
struct CmdShowAllWeaponsUi {}

[event(unicast)]
struct CmdOpenArtilleryMap {}

[event(unicast)]
struct CmdCloseArtilleryMap {}

[event(unicast)]
struct CmdShowArtilleryCooldownHint {}

[event(unicast)]
struct RequestOpenArtilleryMap {}

[event(unicast)]
struct RequestCloseArtilleryMap {}

[event(unicast)]
struct EventArtilleryMapPosSelected
  pos : float3
  typeIndex : int
  posEnd : float3

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct RequestArtilleryStrikeAtPos
  owner : EntityId
  pos : float3
  typeIndex : int
  posEnd : float3

[event(unicast)]
struct CmdStartArtilleryStrikeAtPos
  owner : EntityId
  pos : float3
  typeIndex : int
  posEnd : float3

[event(unicast)]
struct CmdStartDelayedArtilleryStrikeAtPos
  owner : EntityId
  pos : float3
  typeIndex : int
  posEnd : float3
  delayTime : float

[event(unicast)]
struct CmdStartArtilleryOverOrder
  targetPos : float3
  typeIndex : int
  posEnd : float3

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct RequestStopArtilleryOverOrder {}

[event(unicast)]
struct CmdSpawnSquad
  team : int
  possessed : ecs::EntityId
  squadId : int
  memberId : int
  respawnGroupId : int
  existedVehicleEid : EntityId
  withoutVehicle : bool

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdCreateParatroopersSpawn
  point : float2

[event(unicast)]
struct CmdParatroopersPointDeleted{}

[event(unicast)]
struct CmdPickParatroopersPoint
  coordX : float
  coordY : float

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdTurnParatroopersCamera
  paratroopersCameraOn : bool

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdParatroopersSpawnConfirm
  spawnPos : float3

[event(broadcast)]
struct EventFirstPlayerConnected
  time : float

[event(broadcast)]
struct EventFirstPlayerSpawned
  time : float

[event(unicast)]
struct EventPlayerProfileChanged {}

[event(unicast)]
struct RequestCheckTeamSpawnDefeat {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventCapZoneEnter
  visitor : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventCapZoneLeave
  visitor : EntityId

[event(broadcast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventZoneCaptured
  zone : EntityId
  team : int

[event(broadcast)]
struct EventSectorCaptured
  zone : EntityId
  team : int

[event(broadcast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventZoneIsAboutToBeCaptured
  zone : EntityId
  team : int

[event(unicast)]
struct EventEntityAboutToDeactivate {}

[event(broadcast)]
struct EventZoneDeactivated
  zone : EntityId
  team : int

[event(broadcast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventZoneDecaptured
  zone : EntityId
  team : int

[event(broadcast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdDig
  diggerEid : EntityId
  pos : float3
  radius : float
  depth : float
  matId : int

[event(broadcast)]
struct CmdApplyDigAction
  pos : float3
  radius : float
  matId : int

[event(broadcast)]
struct CmdTerraBrush
  pos : float3
  radius : float
  alt : float
  clearMode : bool
  eraseGrass : bool

[event(broadcast)]
struct CmdTerraUpdateRender
  hmapBoxMin : float3
  hmapBoxMax : float3
  egrasBase : int
  egrasNum  : int

[event(broadcast)]
struct CmdTerraBrushUndo {}

[event(broadcast)]
struct CmdTerraBrushRedo {}

[event(broadcast)]
struct CmdRIToolAddSelected
  tm : float3x4
  name : string
  bsph : float4
  action : string
  kind : int

[event(broadcast)]
struct CmdRIToolClearSelected {}

[event(broadcast)]
struct CmdRIToolRemoveRendInst
  tm : float3x4
  name : string
  eid : EntityId

[event(broadcast)]
struct CmdRIToolUnbakeRendInst
  tm : float3x4
  name : string
  eid : EntityId

[event(broadcast)]
struct CmdRIToolEnbakeRendInst
  tm : float3x4
  name : string
  eid : EntityId

[event(broadcast)]
struct CmdRIToolRebakeRendInst
  tm : float3x4
  name : string
  eid : EntityId

[event(broadcast)]
struct CmdRIToolCreateRendInst
  tpl : string
  tm : float3x4
  name : string
  eid : EntityId
  undo : bool

[event(broadcast)]
struct CmdRIToolRestoreRendInst {}

[event(unicast)]
struct EventEditorEntityMoved {}

[event(broadcast)]
struct EventBombCraterPartTerraformed
  partPos : float3
  partRadius : float
  shouldDig : bool

[event(broadcast)]
struct EventBombCraterTerraformed
  pos : float3
  outerRadius : float
  availablePartsMask : uint64
  availableDigPartsMask : uint64
  partsGridWidth : int
  mainPhysmatId : int

[event(broadcast)]
struct CmdUpdateBombCraterRiPoolFlags {}

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdNextBuildingType {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventOnDig
  canTerraformCheckResult : int

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdStopInteractBomb
  operatorEid : EntityId

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdRequestAmmoBoxMarker {}

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdRequestRallyPointMarker {}

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct RequestSquadChangeLeader
  eid : EntityId

[event(unicast)]
struct CmdSwitchSquadLeader
  eid : EntityId

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct EventRepairFortificationStart
  target : EntityId

[event(unicast)]
struct EventRepairFortificationFinish {}

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct EventRepairFortificationStop {}

[event(unicast)]
struct EventAdditiveBuildingRepaired {}

[event(unicast)]
struct InitCapzoneRadius {}

[event(unicast)]
struct CmdExplodeTntBlocks {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventActivateRadioMode
  isActive : bool

[cpp_event(unicast)]
struct CmdTutorialHint
  data : ecs::Object

[event(unicast)]
struct EventUpdatedItemContainer {}

[event(unicast)]
struct NextReplayTarget
  delta : int

[event(unicast)]
struct SetReplayTarget {}

[event(broadcast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdSpawnCharredArea
  pos : float3
  normal : float3

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct VoteKickResult
  kicked : bool

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdFlaskUse {}

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct CmdFlaskUseCancel {}

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct HumanUseItemRequest
  item : EntityId
  target : EntityId

[event(unicast)]
struct EventBeforeEntityRecreatedOnDeath {}

[event(unicast)]
struct RequestSwitchBinocular
  choosePrevGunSlot : BinocularChooseWeapSlotMode

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdSwitchBinocular
  choosePrevGunSlot : BinocularChooseWeapSlotMode

[event(unicast)]
struct CmdSwitchBinocularCockpit
  enabled : bool

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdToggleHatch {}

[cpp_event(broadcast)]
struct EventSquadMembersStats
  data : Object

[event(broadcast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventGunGameNewLeader
  oldLeaderPlayerEid : EntityId
  newLeaderPlayerEid : EntityId

[event(broadcast, routing=ROUTING_SERVER_TO_CLIENT)]
struct EventGunGameLevelReached
  playerEid : EntityId
  level : int

[event(broadcast)]
struct SaveVehicleDecor {}

[event(unicast)]
struct SetVehicleDecor
  relativeTm : float3x4
  slotId : int
  nodeName : string
  templateName : string

[event(broadcast)]
struct CmdSetCameraFov
  fov : float

[event(broadcast)]
struct CmdSetCameraDofEnabled
  enabled : bool

[cpp_event(broadcast, with_scheme, cpp_gen=false)]
struct OnShellHitEntityFx
  shellId : int
  pos : float3
  dir : float3
  pmid : int
  norm : float3
  bloodSplash : HitBloodType
  nodeCollId : int
  withSound : bool
  victimEid : EntityId
  directHit : bool
  stopped : bool
  projectileEid : EntityId

[cpp_event(broadcast)]
struct ProjectileOnHitEntityWithHp
  result : ProjectileHitResult
  projectile_eid : EntityId
  victim : EntityId
  isect : IntersectedEntityData
  launch_desc : LaunchDesc
  vel : float3
  dir : float3
  waterLen : float
  curTime : float
  offender : EntityId
  prev_projectile_dist : float
  piercing_shift : float
  allow_detonation : bool
  gun_eid : EntityId
  sceneHitRicochetStability : float
  trace_ray_mat_id : int
  check_if_should_apply_damage : bool

[event(unicast)]
struct EventProjectileIntersectEntityWithHp
  victim : EntityId
  offender : EntityId
  pos : float3
  collNodeId : int

[event(broadcast)]
struct CmdSetCinematicModeEnabled
  enabled : bool

[event(broadcast)]
struct CmdSetMotionBlurScale
  scale : float

[event(broadcast)]
struct CmdSetBloomThreshold
  threshold : float

[event(broadcast)]
struct CmdSetChromaticAberrationOffset
  offset : float

[event(broadcast)]
struct CmdSetFilmGrain
  strength : float

[event(broadcast)]
struct CmdSetVignetteStrength
  strength : float

[event(broadcast)]
struct CmdSetDofIsFilmic
  isFilmic : bool

[event(broadcast)]
struct CmdSetDofFocusDistance
  focusDistance : float

[event(broadcast)]
struct CmdSetDofFocalLength
  focalLength : float

[event(broadcast)]
struct CmdSetDofFStop
  fStop : float

[event(broadcast)]
struct CmdSetDofBokehCorners
  bokehCorners : float

[event(broadcast)]
struct CmdSetDofBokehSize
  bokehSize : float

[event(broadcast)]
struct CmdChangeTimeOfDay
  timeOfDay : float

[event(broadcast)]
struct CmdWeather
  preset : string

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdPushObject
  target : EntityId

[event(unicast)]
struct ReplayPossessEntity
  prevEid : EntityId

[event(broadcast)]
struct ReplayToggleFreeCamera {}

[event(broadcast)]
struct CmdSetRain
  enabled : bool

[event(broadcast)]
struct CmdSetSnow
  enabled : bool

[event(broadcast)]
struct CmdSetLightning
  enabled : bool

[event(broadcast)]
struct CmdSetFreeTpsCameraSpeed
  speed : float

[event(broadcast)]
struct CmdSetLenseFlareIntensity
  intensity : float

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdHeroLogExEvent
  event : string
  key : string
  data : ecs::Object const?

[event(broadcast)]
struct CmdSetCinemaRecording
  enabled : bool

[event(broadcast)]
struct CmdSetCinematicPostFxBloom
  enabled : bool

[event(broadcast)]
struct CmdSetCinematicSetSuperPixels
  super_pixels : int

[event(broadcast)]
struct CmdSetCinematicCustomSettings
  enabled : bool

[event(unicast)]
struct EventEntityRedeployed {}

[event(unicast)]
struct EventInventorySpecialItemAdded
  itemEid : EntityId

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdGetBattleResult {}

[event(unicast)]
struct CmdGetDebriefingResult {}

[event(unicast)]
struct CmdDestoyProjectileEntity {}

[event(unicast)]
struct CmdDetonateShellServer
  gun_props_id : int
  pos : float3
  offender : EntityId
  prev_pos : float3
  vel : float3
  ignore_entity : EntityId
  normal : float3
  alternative_offender : EntityId

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct RequestNextGunAmmoHolderType {}

// This events use for only visual sync cockpit slit,
// cause the slit feature is client only and if we want
// show current slit in replay mode, need somehow sync it between client and server
[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct ClientSetVisualCockpitSlit
  nextSlit : int
  prevSlit : int

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct ServerSetVisualCockpitSlit
  nextSlit : int
  prevSlit : int

[event(unicast, routing=ROUTING_CLIENT_CONTROLLED_ENTITY_TO_SERVER)]
struct CmdLimitVehicleByGroup
  isLimited : bool

[event(unicast)]
struct CmdClearHiddenNode
  nodeName : string

[event(unicast)]
struct CmdSetHideNode
  nodeName : string

[event(broadcast)]
struct CmdSetCameraLerpFactor
  lerpFactor : float

[event(broadcast)]
struct CmdSetCameraStopLerpFactor
  stopLerpFactor : float

[event(broadcast)]
struct EventApplyDevMode {}

[event(unicast)]
struct CmdUpdatePlaneEngineDamageFx
  engineIndex : int

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdSwitchToFirstWeapWithAmmo {}

[event(broadcast)]
struct EventControlsMenuToggle
  isShown : bool

[event(unicast)]
struct CmdUpdateCameraByVehicleType {}

[event(unicast)]
struct CmdStartNextReloadState {}

[event(broadcast)]
struct CmdReplayRewind
  time : int

[event(broadcast)]
struct CmdReplayRewindSaveState
  state : ecs::Object const?

[event(broadcast)]
struct CmdReplayRewindLoadState
  state : ecs::Object const?

[event(broadcast)]
struct CmdEditorInvalidateAI {}

[event(broadcast)]            // require only for use parallel for in different attaches queue's
struct SlotAttachUpdateEvent  // May be removed when "parallel for" will implemented in das ecs query
  dt : float

[event(unicast)]
struct PrefabSaveEvent {}

[event(broadcast)]
struct PrefabSpawnEvent
  name : string

[event(broadcast)]
struct PrefabCreateFromSelectedEvent
  name : string
  save : bool

[event(broadcast)]
struct PrefabShatterSelectedEvent {}

[event(unicast)]
struct AddSelectedToPrefabEvent {}

[event(unicast)]
struct EventOnWeapSlotItemPickup
  itemEid : EntityId
  slotId : int

[event(unicast)]
struct PrefabSelectParentEvent {}

[event(unicast)]
struct PrefabSelectObjectsEvent {}

[cpp_event(unicast)]
struct EditorToDeleteEntitiesEvent
  linkedEntitiesToDelete : ecs::EidList

[cpp_event(unicast)]
struct EditorClonedEntity {}

[event(unicast)]
struct EventPolyAreaMadeCompact {}

[event(broadcast)]
struct CmdDebugRulerAddOrRemovePoint
  pos : float3
  findClosestPoint : bool

[event(broadcast)]
struct CmdDebugRulerClearPoints {}

[event(unicast)]
struct OnCameraTrackFinishCycle {}

[event(broadcast)]
struct CmdResetDigitalActionStickyToggle
  action : uint16