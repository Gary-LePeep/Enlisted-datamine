module weaponry_hit_fx_forward_events shared
require ecs
require RendInst
require DngWeapon

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

[cpp_event(unicast)]
struct CmdShellExplosionFx {}

[cpp_event(unicast)]
struct EventOnShellExploded
  explPos : float3
  shellId : int16
  damageId : int16
  ballisticsId : int16
  gunPropsId : int
  owner : EntityId
