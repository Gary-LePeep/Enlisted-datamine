require ecs
require app

[es(REQUIRE=clouds_hole_tag, on_event=EventLevelLoaded)]
def clouds_hole_init(evt : Event;
                     var transform : float3x4&)
  // calculate a position that is close to battle area
  // because if hole target is (0, 0, 0), it can be far enough for battle area to not be covered by hole
  var sum : float3
  var count = 0

  query() <| $ [es(REQUIRE=respawnObject)] (transform : float3x4)
    sum += transform[3]
    count++

  if count > 0
    transform[3] = (1.0f / float(count)) * sum
