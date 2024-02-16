require ecs
require DagorMath
require math.base
require math.ang
require vehicle
require sound_utils_net.modules.sound_utils_net_events


// not using velocity from vehicle_net_phys because of unresolveable replication problems relatively to net optimizations
[es(tag=sound, after=(vehicle_phys_es, sound_control_update))]
def vehicle_sound_update_speed(info : ParallelUpdateFrameDelayed;
                               sound_control__shouldPlay : bool;
                               var vehicle_sound_update_speed__prevTransform : float3x4&;
                               var vehicle_sound_vars__speed : float&;
                               var vehicle_sound_vars__speedSummary : float4&;
                               var vehicle_sound_vars__linearVelocity : float3&;
                               transform : float3x4)
  if sound_control__shouldPlay
    if vehicle_sound_vars__speedSummary.x < 0.
      vehicle_sound_update_speed__prevTransform = transform
      vehicle_sound_vars__speedSummary = float4(0., 0., 0., 0.)
    vehicle_sound_vars__linearVelocity = (transform[3] - vehicle_sound_update_speed__prevTransform[3]) * safeinv(info.dt)
    vehicle_sound_update_speed__prevTransform = transform
    vehicle_sound_vars__speedSummary = float4(length(vehicle_sound_vars__linearVelocity), vehicle_sound_vars__speedSummary.x, vehicle_sound_vars__speedSummary.y, vehicle_sound_vars__speedSummary.z)
    vehicle_sound_vars__speed = (vehicle_sound_vars__speedSummary.x + vehicle_sound_vars__speedSummary.y + vehicle_sound_vars__speedSummary.z + vehicle_sound_vars__speedSummary.w) * 0.25
  else
    vehicle_sound_vars__linearVelocity = float3(0., 0., 0.)
    vehicle_sound_vars__speedSummary.x = -1.
    vehicle_sound_vars__speed = 0.
