module swarm_events shared
require ecs

[cpp_event(unicast)]
struct EventSomeSwarmBoidBorn
  count : int

[cpp_event(unicast)]
struct EventSomeSwarmBoidDied
  pos : float3
