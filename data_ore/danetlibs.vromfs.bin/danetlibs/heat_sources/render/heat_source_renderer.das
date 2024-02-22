require ecs
require ecs.common
require math
require math.base
require DagorSystem
require DagorMath
require strings
require danetlibs.heat_sources.render.heat_source_common

[es(tag=render, before=update_heat_sources_es)]
def update_heat_sources_pos_es(info : ParallelUpdateFrameDelayed;
                               heat_source__basicScale : float3;
                               heat_source__resultOffset : float3;
                               heat_source__prevCurrVelocityMixCoeff : float;
                               heat_source__movementBiasCoeff : float;
                               heat_source__inflateCoef : float;
                               heat_source__velocityThresholdSq : float;
                               heat_source__shouldInflate : bool;
                               var transform : float3x4&;
                               var heat_source__prevPos : float3&;
                               var heat_source__prevVel : float3&;
                               var heat_source__scale : float3&)
  var velocityVector = clamp(((transform[3] - heat_source__prevPos) * safeinv(info.dt)), float3(-100.0f), float3(100.0f));
  let velocityMix = heat_source__prevCurrVelocityMixCoeff
  velocityVector = velocityMix * velocityVector + (1.0 - velocityMix) * heat_source__prevVel;
  if heat_source__shouldInflate && length_sq(velocityVector) > heat_source__velocityThresholdSq
    heat_source__scale.x = heat_source__basicScale.x
    heat_source__scale.y = heat_source__basicScale.y * heat_source__inflateCoef
    heat_source__scale.z = heat_source__basicScale.z * heat_source__inflateCoef
  else
    heat_source__scale = heat_source__basicScale
  heat_source__prevVel = velocityVector
  heat_source__prevPos = transform[3]
  transform[3] += (velocityVector * heat_source__movementBiasCoeff)
  transform[3] += rotate(transform, heat_source__resultOffset)

[es(tag=render, on_appear, track=heat_source__scale)]
def track_heat_sources_size_coeff_es(evt : Event;
                                     heat_source__scale : float3;
                                     heat_source__basicRad : float3;
                                     var heat_source__rad : float3&)
  heat_source__rad = heat_source__basicRad * heat_source__scale

[es(tag=render, on_appear, track=(heat_source__offset, heat_source__radMult))]
def track_heat_sources_offset_rad_mult_es(evt : Event;
                                          heat_source__offset : float3;
                                          heat_source__radMult : float;
                                          heat_source__rad : float3;
                                          heat_source__dirRadOffset : float3;
                                          var heat_source__resultOffset : float3&)
  heat_source__resultOffset = heat_source__offset + heat_source__dirRadOffset * heat_source__rad * heat_source__radMult
