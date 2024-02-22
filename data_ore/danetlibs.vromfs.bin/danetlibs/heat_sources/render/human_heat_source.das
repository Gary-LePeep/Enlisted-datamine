require ecs
require ecs.common
require math
require math.base
require DagorSystem
require DagorMath
require AnimV20
require GeomNodeTree
require strings
require dm
require DngDm
require CollRes
require danetlibs.heat_sources.render.heat_source_common

[es(tag=render, on_appear, REQUIRE=attachedToParent, REQUIRE=human_gun_attached, after=human_gun_es)]
def human_gun_heat_source_init_es(evt : Event;
                                  item__weapType : string;
                                  animchar : AnimcharBaseComponent;
                                  var heat_source__humanGunEid : EntityId&;
                                  var heat_source__human_gun_offset : float3&;
                                  var heat_source__human_gun_size : float3&;
                                  var heat_source__human_gun_heating : float3&)
  if item__weapType == "melee" || item__weapType == "building_tool"
    return
  let nodeIndex = geomtree_findNodeIndex(*animchar.nodeTree, "gunFx_main")
  var heatEid = INVALID_ENTITY_ID
  if nodeIndex > 0
    var nodeWtm : float3x4
    geomtree_getNodeWtmScalar(*animchar.nodeTree, nodeIndex, nodeWtm)
    let partTemperature = float4(1, 0, 1, 0)
    let heatingTemp = getTemplateByName("weapon_heating_params_{item__weapType}")
    if heatingTemp != null
      heat_source__human_gun_offset = get_Point3(getTemplateComponent(*heatingTemp, "heat_source__human_gun_offset")) ?? heat_source__human_gun_offset
      heat_source__human_gun_size = get_Point3(getTemplateComponent(*heatingTemp, "heat_source__human_gun_size")) ?? heat_source__human_gun_size
      heat_source__human_gun_heating = get_Point3(getTemplateComponent(*heatingTemp, "heat_source__human_gun_heating")) ?? heat_source__human_gun_heating
    let rad = float3(-1.0f)
    heatEid = createEntity("heat_source_item") <| $(var init : ComponentsInitializer)
      set(init, "transform", nodeWtm)
      set(init, "heat_source__basicRad", rad)
      set(init, "heat_source__basicScale", heat_source__human_gun_size)
      set(init, "heat_source__scale", heat_source__human_gun_size)
      set(init, "heat_source__rad", rad * heat_source__human_gun_size)
      set(init, "heat_source__offset", heat_source__human_gun_offset)
      set(init, "heat_source__temperature", partTemperature)
      set(init, "heat_source__type", int(partType HUMAN_GUN))
  heat_source__humanGunEid = heatEid


[es(tag=render, on_disappear, REQUIRE=attachedToParent)]
def human_gun_heat_source_on_destroy_es(evt : Event;
                                        heat_source__humanGunEid : EntityId)
  destroyEntity(heat_source__humanGunEid)

[es(tag=render, REQUIRE=attachedToParent, after=human_gun_heat_source_init_es, before=update_heat_sources_pos_es)]
def human_gun_heat_source_update_es(info : UpdateStageInfoAct;
                                    animchar : AnimcharBaseComponent;
                                    heat_source__humanGunEid : EntityId;
                                    heat_source__human_gun_heating : float3)

  if heat_source__humanGunEid == INVALID_ENTITY_ID
    return
  var nodeWtm : float3x4
  geomtree_getNodeWtmScalar(*animchar.nodeTree, geomtree_findNodeIndex(*animchar.nodeTree, "gunFx_main"), nodeWtm)

  query(heat_source__humanGunEid) <| $ [es] (var transform : float3x4&;
                                             var heat_source__temperature : float4&)
    transform =  nodeWtm
    heat_source__temperature.y = max(0.f, heat_source__temperature.y + heat_source__human_gun_heating.z * 4.0 * info.dt)

[es(tag=render, on_appear, after=dm_parts_es)]
def human_heat_source_init_es(evt : Event;
                              transform : float3x4;
                              collres : CollisionResource;
                              animchar : AnimcharBaseComponent;
                              damage_model : DamageModel;
                              human_heat_parts : Array;
                              dm_parts__type : StringList;
                              heat_source__head_base_temp : float2;
                              heat_source__torso_base_temp : float2;
                              heat_source__hand_base_temp : float2;
                              heat_source__leg_base_temp : float2;
                              var heat_source__dmBodyPartIds : IntList&;
                              var heat_source__bodyEid : EidList&;
                              heat_source__head_size : float3;
                              heat_source__head_offset : float3;
                              heat_source__torso_size : float3;
                              heat_source__torso_offset : float3;
                              heat_source__leg_size : float3;
                              heat_source__leg_offset : float3;
                              heat_source__hand_size : float3;
                              heat_source__hand_offset : float3)
  for partName in human_heat_parts
    let partId = find_part_id_by_name(damage_model, get_string(partName, ""))
    push(heat_source__dmBodyPartIds, partId)
    let collisionNodeId = damage_model.dmData.parts[partId].collisionNodeId
    let node = collres_get_node(collres, collisionNodeId)
    if node != null
      var tm : float3x4
      collres_get_collision_node_tm(collres, collisionNodeId, transform, animchar.nodeTree, tm)
      let partModelBBox = (*node).modelBBox
      let nodeType = string(dm_parts__type[collisionNodeId])
      var partTemperature = float2(3.0f, 36.0f) //default value
      let basicRad = -partModelBBox.width
      var scale = float3(1.0f, 1.0f, 1.0f)
      var offset = float3(0.0f)
      var partType = partType HULL
      if (nodeType == "head")
        scale = heat_source__head_size
        offset = heat_source__head_offset
        partTemperature = heat_source__head_base_temp
        partType = partType HUMAN_HEAD
      elif (nodeType == "torso")
        scale = heat_source__torso_size
        offset = heat_source__torso_offset
        partTemperature = heat_source__torso_base_temp
        partType = partType HUMAN_TORSO
      elif (nodeType == "l_leg" || nodeType == "r_leg")
        scale = heat_source__leg_size
        offset = heat_source__leg_offset
        partTemperature = heat_source__leg_base_temp
        partType = partType HUMAN_LEG
      elif (nodeType == "l_hand" || nodeType == "r_hand")
        scale = heat_source__hand_size
        offset = heat_source__hand_offset
        partTemperature = heat_source__hand_base_temp
        partType = partType HUMAN_HAND
      var heatEid = INVALID_ENTITY_ID
      heatEid = createEntity("heat_source_item") <| $(var init : ComponentsInitializer)
        set(init, "transform", tm)
        set(init, "heat_source__basicRad", basicRad)
        set(init, "heat_source__rad", basicRad * scale)
        set(init, "heat_source__basicScale", scale)
        set(init, "heat_source__scale", scale)
        set(init, "heat_source__offset", offset)
        set(init, "heat_source__temperature", float4(partTemperature, partTemperature))
        set(init, "heat_source__type", int(partType))
      push(heat_source__bodyEid, heatEid)


[es(tag=render, REQUIRE=human, after=human_heat_source_init_es, before=update_heat_sources_pos_es)]
def human_heat_source_update_es(info : UpdateStageInfoAct;
                                transform : float3x4;
                                collres : CollisionResource;
                                animchar : AnimcharBaseComponent;
                                damage_model : DamageModel;
                                heat_source__dmBodyPartIds : IntList;
                                heat_source__bodyEid : EidList)
  if empty(heat_source__bodyEid) || empty(heat_source__dmBodyPartIds)
    return

  for partId, heatEid in heat_source__dmBodyPartIds, heat_source__bodyEid
    if heatEid == INVALID_ENTITY_ID
      continue
    updateHeatSourceTm(transform, collres, animchar, damage_model,
        partId, heatEid);

[es(tag=render, REQUIRE=human, before=human_heat_source_update_es)]
def human_temperature_update_es(info : UpdateStageInfoAct;
                                isAlive : bool;
                                heat_source__bodyEid : EidList;
                                heat_source__human_cooling_speed : float;
                                heat_source__head_base_temp : float2;
                                heat_source__torso_base_temp : float2;
                                heat_source__hand_base_temp : float2;
                                heat_source__leg_base_temp : float2)
  if !isAlive
    for heatEid in heat_source__bodyEid
      var basePartTemp = float2(3.0f, 36.6f) //default value for human body and temp coeff
      query(heatEid) <| $ [es] (var heat_source__temperature : float4&;
                                heat_source__type : int)
        if (heat_source__type == int(partType HUMAN_HEAD))
          basePartTemp = heat_source__head_base_temp
        elif (heat_source__type == int(partType HUMAN_TORSO))
          basePartTemp = heat_source__torso_base_temp
        elif (heat_source__type == int(partType HUMAN_HAND))
          basePartTemp = heat_source__hand_base_temp
        elif (heat_source__type == int(partType HUMAN_LEG))
          basePartTemp = heat_source__leg_base_temp
        let resultPartTemp = clamp(heat_source__temperature.y - heat_source__human_cooling_speed * info.dt, 0.0f, basePartTemp.y)
        heat_source__temperature.x = basePartTemp.x
        heat_source__temperature.y = resultPartTemp
        heat_source__temperature.z = basePartTemp.x
        heat_source__temperature.w = resultPartTemp

[es(tag=render, on_disappear)]
def human_gun_heat_source_destroy_es(evt : Event;
                                     heat_source__humanGunEid : EntityId)
  destroyEntity(heat_source__humanGunEid)

[es(tag=render, on_disappear)]
def human_heat_source_destroy_es(evt : Event;
                                 var heat_source__bodyEid : EidList)
  destroyHeatSources(heat_source__bodyEid)

[es(tag=render, track=(isInVehicle, human_vehicle__isInHatch))]
def human_heat_source_disable_inside_vehicle_es(evt : Event;
                                                heat_source__bodyEid : EidList;
                                                human_weap__gunEids : EidList;
                                                isInVehicle : bool;
                                                human_vehicle__isInHatch : bool)
  var isThermal = false
  query() <| $ [es] (thermal_vision__activePresets : EidList)
    isThermal = !empty(thermal_vision__activePresets)

  for eid in heat_source__bodyEid
    query(eid) <| $ [es] (var heat_source__inVehicle : bool&;
                          var heat_source__visibility : bool&)
      heat_source__inVehicle = isInVehicle && !human_vehicle__isInHatch
      heat_source__visibility = !heat_source__inVehicle && isThermal
      sendEventImmediate(eid, [[OnHeatSourceVisibilityChange]])
  for eid in human_weap__gunEids
    query(eid) <| $ [es] (heat_source__humanGunEid : EntityId)
      let heatEid = heat_source__humanGunEid
      query(heatEid) <| $ [es] (var heat_source__inVehicle : bool&;
                                var heat_source__visibility : bool&)
        heat_source__inVehicle = isInVehicle && !human_vehicle__isInHatch
        heat_source__visibility = !heat_source__inVehicle && isThermal
        sendEventImmediate(heatEid, [[OnHeatSourceVisibilityChange]])
[es(tag=render, track=isAlive)]
def human_heat_source_on_death_es(evt : Event;
                                  heat_source__bodyEid : EidList;
                                  isAlive : bool;
                                  bodyCleanupTime : float;
                                  heat_source__dead_human_fadeout_coeff : float)
  for eid in heat_source__bodyEid
    query(eid) <| $ [es] (var heat_source__fadeout : bool&;
                          var heat_source__fadeoutTime : float&)
      heat_source__fadeout = !isAlive
      heat_source__fadeoutTime = bodyCleanupTime * heat_source__dead_human_fadeout_coeff

[es(tag=render, on_event=(CmdNetShot, EventShot))]
def human_gun_set_temp_on_shot(evt : Event;
                               heat_source__humanGunEid : EntityId;
                               heat_source__human_gun_heating : float3)
  query(heat_source__humanGunEid) <| $ [es] (var heat_source__temperature : float4&)
    heat_source__temperature.y = min(heat_source__human_gun_heating.x / 2.0f, heat_source__temperature.y + heat_source__human_gun_heating.y / 2.0f);

