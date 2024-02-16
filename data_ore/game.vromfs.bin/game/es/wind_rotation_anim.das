require ecs
require math.base
require RendInst
require RendInstPhys
require common_shooter.events_common_shooter

[es(on_appear, on_event=EventOnWindChange, before=set_rotation_es, after=rotate_ri_by_wind_direction)]
def set_rotation_by_wind_es(evt : Event;
                            wind_rotated_ri__rotationSpeed : float;
                            var ang_speed_roll : float&)
  if wind_rotated_ri__rotationSpeed == 0.
    return
  query() <| $ [es] (wind__strength : float)
    ang_speed_roll = wind_rotated_ri__rotationSpeed * wind__strength

[es(on_appear, on_event=EventOnWindChange, before=(set_rotation_es, set_rotation_by_wind_es), REQUIRE=windOrientedRi)]
def rotate_ri_by_wind_direction(evt : Event;
                                ri_extra : RiExtraComponent;
                                var initialTransform : float3x4&;
                                var transform : float3x4&)
  query() <| $ [es] (wind__dir : float)
    var s, c : float
    sincos(deg_to_rad(wind__dir), s, c)
    transform[0] = normalize(float3(c, 0., s))
    transform[1] = float3(0., 1., 0.)
    transform[2] = normalize(cross(transform[0], transform[1]))
    initialTransform = transform
    if riex_isRiGenExtraValid(ri_extra.handle)
      move_ri_extra_tm(ri_extra.handle, transform)

[es(track=(wind__dir, wind__strength), REQUIRE=(wind__dir, wind__strength))]
def send_event_on_wind_change(evt : Event)
  broadcastEvent([[EventOnWindChange]])
