require ecs
require app
require player
require math.base
require pathfinder

module ai_poly_areas_common shared

enum EnlPolyArea : uint8
  // enlisted specific areas
  POLYAREA_WATER = 6

[event(broadcast)]
struct OnTankNavmeshFlagsGlobalUpdate {}

[event(broadcast)]
struct OnTankNavmeshFlagsLocalUpdate
  pos : float3
  extents : float

enum EnlPolyFlags : uint16
  POLYFLAG_TANK_OBSTACLE = 0x0080
  POLYFLAG_TANK_PASSABLE_TEAM_1 = 0x0100
  POLYFLAG_TANK_PASSABLE_TEAM_2 = 0x0200
  POLYFLAG_TANK_PASSABLE_TEAM_ALL = 0x0300


def team_to_tank_navmesh_poly_flags(team : int)
  if team == 1
    return uint16(EnlPolyFlags POLYFLAG_TANK_PASSABLE_TEAM_1)
  elif team == 2
    return uint16(EnlPolyFlags POLYFLAG_TANK_PASSABLE_TEAM_2)
  elif team == TEAM_UNASSIGNED
    return uint16(EnlPolyFlags POLYFLAG_TANK_PASSABLE_TEAM_ALL)
  return uint16(0)

def update_navmesh_poly_flags_on_still_obstacle(is_still : bool; pos : float3; extents : float)
  var tm = IDENT_TM
  tm[3] = pos
  tm[0][0] = extents
  tm[1][1] = extents
  tm[2][2] = extents
  static_if typeinfo(builtin_function_exists @@ < (arg0 : int; arg1 : float3x4; arg2 : uint16; arg3 : uint16; arg4 : uint16; arg5 : uint16; arg6 : int; arg7 : bool) : void > pathfinder::change_navpolys_flags_in_box)
    change_navpolys_flags_in_box(NM_EXT_1, tm,
                                 is_still ? uint16(EnlPolyFlags POLYFLAG_TANK_OBSTACLE) : uint16(0),
                                 is_still ? uint16(0) : uint16(EnlPolyFlags POLYFLAG_TANK_OBSTACLE),
                                 uint16(0), uint16(0), -1, false)
  else
    change_navpolys_flags_in_box(NM_EXT_1, tm,
                                 is_still ? uint16(EnlPolyFlags POLYFLAG_TANK_OBSTACLE) : uint16(0),
                                 is_still ? uint16(0) : uint16(EnlPolyFlags POLYFLAG_TANK_OBSTACLE),
                                 uint16(0), uint16(0))
