
module explosion_patches_events shared
require ecs
require RendInst

[event(unicast)]
struct CmdRendinstBulletHole
  riHandle : riex_handle_t
  pos : float3
  dir : float3
  norm : float3
  pmid : int