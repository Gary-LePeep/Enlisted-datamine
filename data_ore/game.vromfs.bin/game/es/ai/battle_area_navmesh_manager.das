require ecs
require app
require math.base
require enlisted.events_enlisted
require daslib/algorithm
require DagorMath
require DagorSystem
require pathfinder
require enlisted.game.es.ai_poly_areas_common
require %daslib.sort_boost


[es(tag=server, on_appear, track=active, REQUIRE=(battle_area, active, humanTriggerable))]
def battle_area_navmesh_manager_add_area_es(evt : Event;
                                            eid : EntityId)
  find_query() <| $ [es] (battle_area_navmesh_manager__delay : float;
                          var battle_area_navmesh_manager__nextUpdate : float&;
                          var battle_area_navmesh_manager__areaEids : EidList&)
    battle_area_navmesh_manager__nextUpdate = get_sync_time() + battle_area_navmesh_manager__delay
    push(battle_area_navmesh_manager__areaEids, eid)
    return true


def get_boxes_for_battle_areas(var eids : array<EntityId>&; var boxes : array<bbox3f>&)
  query() <| $ [es(REQUIRE=(battle_area, humanTriggerable))] (eid : EntityId; battleAreaPoints : Point2List)
    if empty(battleAreaPoints)
      return
    var box : bbox3f
    let initPoint3d = float3(battleAreaPoints[0].x, 0.0, battleAreaPoints[0].y)
    bbox3f_init(box, initPoint3d)
    for i in range(1, length(battleAreaPoints))
      let point3d = float3(battleAreaPoints[i].x, 0.0, battleAreaPoints[i].y)
      bbox3f_add_pt(box, point3d)
    push(eids, eid)
    push(boxes, box)
  query() <| $ [es(REQUIRE=(battle_area, box_zone, humanTriggerable))] (eid : EntityId; transform : float3x4)
    let bb3 = transform * IDENT_BBOX
    var box : bbox3f
    let bmin = float3(bb3.boxMin.x, 0.0, bb3.boxMin.z)
    let bmax = float3(bb3.boxMax.x, 0.0, bb3.boxMax.z)
    bbox3f_init(box, bmin)
    bbox3f_add_pt(box, bmax)
    push(eids, eid)
    push(boxes, box)


[es(tag=server)]
def battle_area_navmesh_manager_es(info : ParallelUpdateFrameDelayed;
                                   battle_area_navmesh_manager__nextUpdate : float;
                                   var battle_area_navmesh_manager__areaEids : EidList&)
  if empty(battle_area_navmesh_manager__areaEids) || info.curTime < battle_area_navmesh_manager__nextUpdate
    return

  var allAreaEids : array<EntityId>
  var allBoxes : array<bbox3f>
  get_boxes_for_battle_areas(allAreaEids, allBoxes)

  var activeAreaEidsToCheck : array<EntityId>

  for areaEid in battle_area_navmesh_manager__areaEids
    query(areaEid) <| $ [es(REQUIRE=battle_area)] (active : bool;
                                                   battle_area__team aka this_battle_area__team : int;
                                                   transform : float3x4;
                                                   battleAreaPoints : Point2List const?;
                                                   box_zone : Tag const?)
      if active
        push(activeAreaEidsToCheck, areaEid)
        return

      if battleAreaPoints != null
        change_navpolys_flags_in_poly(NM_EXT_1, *battleAreaPoints, uint16(0), team_to_tank_navmesh_poly_flags(battle_area__team), uint16(PolyFlag POLYFLAG_GROUND), uint16(0), pathfinder::POLYAREA_OBSTACLE)
      elif box_zone != null
        change_navpolys_flags_in_box(NM_EXT_1, transform, uint16(0), team_to_tank_navmesh_poly_flags(battle_area__team), uint16(PolyFlag POLYFLAG_GROUND), uint16(0), pathfinder::POLYAREA_OBSTACLE)
      else
        logerr("battle_area_navmesh_manager_es: found a battle area {areaEid} that does not have box_zone and battleAreaPoints")
        return

      let idx = find_index(allAreaEids, areaEid)
      if idx < 0 // this can't be true, but let's have it here just in case
        return
      let bb3 = BBox3(allBoxes[idx].bmin.xyz, allBoxes[idx].bmax.xyz)

      for otherAreaEid, otherBox in allAreaEids, allBoxes
        if otherAreaEid == areaEid
          continue
        query(otherAreaEid) <| $ [es] (battle_area__team aka other_battle_area__team : int; active aka other_active : bool)
          if !other_active || (this_battle_area__team != -1 && other_battle_area__team != -1 && this_battle_area__team != other_battle_area__team)
            return
          let otherBb3 = BBox3(otherBox.bmin.xyz, otherBox.bmax.xyz)
          if bb3 & otherBb3
            push(activeAreaEidsToCheck, otherAreaEid)

  qsort(activeAreaEidsToCheck) <| $(a, b) { return uint(a) < uint(b); }
  activeAreaEidsToCheck <- unique(activeAreaEidsToCheck)

  for areaEid in activeAreaEidsToCheck
    query(areaEid) <| $ [es(REQUIRE=battle_area)] (battle_area__team : int;
                                                   transform : float3x4;
                                                   battleAreaPoints : Point2List const?;
                                                   box_zone : Tag const?)
      if battleAreaPoints != null
        change_navpolys_flags_in_poly(NM_EXT_1, *battleAreaPoints, team_to_tank_navmesh_poly_flags(battle_area__team), uint16(0), uint16(PolyFlag POLYFLAG_GROUND), uint16(0), pathfinder::POLYAREA_OBSTACLE)
      elif box_zone != null
        change_navpolys_flags_in_box(NM_EXT_1, transform, team_to_tank_navmesh_poly_flags(battle_area__team), uint16(0), uint16(PolyFlag POLYFLAG_GROUND), uint16(0), pathfinder::POLYAREA_OBSTACLE)
      else
        logerr("battle_area_navmesh_manager_es: found a battle area {areaEid} that does not have box_zone and battleAreaPoints")
        return

  clear(battle_area_navmesh_manager__areaEids)
  broadcastEvent([[OnTankNavmeshFlagsGlobalUpdate]])
