require ecs

require DagorMath
require strings

require AnimV20
require CollRes

require dm
require game.es.dm_ai_common


def private find_dm_part_id(turret : Object; key : string; damage_model : DamageModel)
  let partName = get_string(turret, key, "")
  if partName == ""
    return -1
  let partId = find_part_id_by_name(damage_model, partName)
  if partId < 0
    return -1
  return partId

[es(tag=server, on_appear, after=(init_dm_phys_parts_tracks, dm_phys_parts__wheelsPartIds, init_dm_phys_parts_tracks_by_prefix, init_dm_phys_parts_wheels_by_prefix, init_dm_phys_parts_engines, crew_receive_damage_from_dm_part_es))]
def dm_init_ai_points(evt : Event;
                      eid : EntityId;
                      transform : float3x4;
                      damage_model : DamageModel;
                      collres : CollisionResource;
                      animchar : AnimcharBaseComponent;
                      var dm_ai__points : Point3List&;
                      var dm_ai__pointsInfo : IPoint2List&;
                      var dm_ai__pointsYRange : float2&)
  dm_ai__points |> clear()
  dm_ai__pointsInfo |> clear()
  dm_ai__pointsYRange = float2()

  assume dmParts = damage_model.dmData.parts
  assume dmPartProps = damage_model.dmData.partProps
  assume dmCollData = damage_model.collisionData

  var bodyBbox = BBox3()
  var turretBbox = BBox3()

  var goals : array<int2>

  query(eid) <| $ [es] ([[shared_comp]] turret_control__turretInfo : Array)
    for turret_idx in iter_range(turret_control__turretInfo)
      let turretObj = get_ecs_object(turret_control__turretInfo, turret_idx)
      if turretObj == null
        continue
      let partId =  find_dm_part_id(*turretObj, "barrelDm", damage_model)
      if partId >= 0
        goals |> push(int2(partId, int(DMAIPoint BARREL)))

  query(eid) <| $ [es] (dm_phys_parts__tracksPartIds : IntList)
    for partId in dm_phys_parts__tracksPartIds
      if partId >= 0
        goals |> push(int2(partId, int(DMAIPoint TRACK)))

  query(eid) <| $ [es] (dm_phys_parts__wheelsPartIds : IntList)
    for partId in dm_phys_parts__wheelsPartIds
      if partId >= 0
        goals |> push(int2(partId, int(DMAIPoint WHEEL)))

  query(eid) <| $ [es] (dm_phys_parts__enginePartIds : IntList)
    for partId in dm_phys_parts__enginePartIds
      if partId >= 0
        goals |> push(int2(partId, int(DMAIPoint ENGINE)))

  query(eid) <| $ [es] (vehicle_seats_receive_damage_from_dm_part : IntList)
    for partId in vehicle_seats_receive_damage_from_dm_part
      if partId >= 0
        goals |> push(int2(partId, int(DMAIPoint CREW)))

  for partId, part, partProps in iter_range(dmParts), dmParts, dmPartProps
    if !part.enabled
      continue
    let collNodeId = part.collisionNodeId
    if collNodeId < 0
      continue
    let collNode = collres |> collres_get_node(collNodeId)
    if collNode == null
      continue

    let partName = damagePart_getName(partProps)

    let bbox = collNode.modelBBox
    let localPos = bbox.center

    var got = false
    for goal in goals
      if partId == goal.x
        if goal.y == int(DMAIPoint TRACK)
          let offs = float3(bbox.width.x * 0.3, 0.0, 0.0)
          dm_ai__points |> push(localPos + offs)
          dm_ai__pointsInfo |> push(int2(partId, goal.y))
          dm_ai__points |> push(localPos - offs)
          dm_ai__pointsInfo |> push(int2(partId, goal.y))
        dm_ai__points |> push(localPos)
        dm_ai__pointsInfo |> push(int2(partId, goal.y))
        got = true

    if !got
      var nodeTm : float3x4
      collres |> collres_get_collision_node_tm(collNodeId, transform, animchar.nodeTree, nodeTm)
      let localTmPos = inverse(transform) * nodeTm * localPos

      if starts_with(partName, "turret")
        if turretBbox.isempty
          turretBbox = BBox3(localTmPos, 0.5)
        else
          turretBbox |> bbox3_add(localTmPos)
      else
        if bodyBbox.isempty
          bodyBbox = BBox3(localTmPos, 0.5)
        else
          bodyBbox |> bbox3_add(localTmPos)

  if !turretBbox.isempty
    dm_ai__points |> push(turretBbox.center)
    dm_ai__pointsInfo |> push(int2(-1, int(DMAIPoint TURRET)))

  if !bodyBbox.isempty
    dm_ai__points |> push(bodyBbox.center)
    dm_ai__pointsInfo |> push(int2(-1, int(DMAIPoint BODY)))

  if empty(dm_ai__points)
    let DEFAULT_CENTER_POS = float3(0.0, 1.5, 0.0)
    dm_ai__points |> push(DEFAULT_CENTER_POS)
    dm_ai__pointsInfo |> push(int2(-1, int(DMAIPoint BODY)))

  if !empty(dm_ai__points)
    for pt in dm_ai__points
      dm_ai__pointsYRange.x = min(dm_ai__pointsYRange.x, pt.y)
      dm_ai__pointsYRange.y = max(dm_ai__pointsYRange.y, pt.y)
