module kill_awards_common shared public

require ecs
require DngDm
require math.base

def private has_long_range_award_for_type(weapon_type : string)
  return {{
    "assault_rifle";
    "machine_gun";
    "pistol";
    "rifle";
    "semiauto";
    "shotgun";
    "submachine_gun";
  }} |> key_exists(weapon_type)

def should_apply_long_range_kill_award(damage_type, weapon_type, killer, victim_pos)
  var res = false
  if damage_type == int(DamageType DM_PROJECTILE) && has_long_range_award_for_type(weapon_type)
    query(killer) <| $ [es] (transform : float3x4; awards__longRangeDist : float = 100.)
      res = length_sq(transform[3] - victim_pos) > square(awards__longRangeDist)
  return res
