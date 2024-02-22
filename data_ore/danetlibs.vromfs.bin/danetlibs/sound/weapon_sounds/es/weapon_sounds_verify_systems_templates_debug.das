options no_aot
require ecs
require ecs.verify_common
require ecs.verify_macro
require BallisticsProps
require soundEvent


[req_template]
struct ProjectileImpactSounds
  scene_hit_place__matId : int
  scene_hit_place__pos : float3
  projectile_sound__shellCaliberThreshold : float
  projectile_sound__ricoThreshold : float
  projectile_ballistics_props : ProjectileProps
  projectile_sound__paths : SharedObject
  projectile__exploded : bool


[req_template]
struct HumanMeleeActionSound
  human_melee_action_sound__path : string
  human_weap__gunEids : EidList
  human_weap__currentGunSlot : int
