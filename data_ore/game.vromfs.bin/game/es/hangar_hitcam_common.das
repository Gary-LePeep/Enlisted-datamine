module hangar_hitcam_common shared
require ecs.enum_macro

[export_enum]
enum HitcamResult : int
  EMPTY
  RICOCHET
  NOT_PENETRATE
  INEFFECTIVE
  POSSIBLE_EFFECTIVE
  EFFECTIVE
