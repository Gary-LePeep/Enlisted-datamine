module weapon_sounds_events shared
require ecs

[cpp_event(unicast)]
struct CmdStartActionSfx
  pos : float3
  pmid : int
