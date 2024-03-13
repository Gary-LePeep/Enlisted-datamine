require ecs
require app
require player

module ai_poly_areas_common shared

enum EnlPolyArea : uint8
  // enlisted specific areas
  POLYAREA_WATER = 6


enum EnlPolyFlags : uint16
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
