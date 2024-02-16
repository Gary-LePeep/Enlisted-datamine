options no_aot
require ecs
require ecs.verify_common
require ecs.verify_macro
require soundEvent

[req_template]
struct TeamNarrator
  team_narrator__event : SoundEvent
  team_narrator__queue : ecs::Array
  team_narrator__history : ecs::Object
