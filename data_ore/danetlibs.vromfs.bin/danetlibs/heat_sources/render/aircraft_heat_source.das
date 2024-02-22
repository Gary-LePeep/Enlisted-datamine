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
require Plane
require DngPlane
require danetlibs.heat_sources.render.heat_source_common

[es(tag=render, REQUIRE=airplane, after=technic_heat_source_init_es, before=update_heat_sources_pos_es)]
def aircraft_heat_source_update_es(info : UpdateStageInfoAct;
                                   transform : float3x4;
                                   collres : CollisionResource;
                                   animchar : AnimcharBaseComponent;
                                   damage_model : DamageModel;
                                   heat_source__dmEnginePartIds : IntList;
                                   heat_source__hullEid : EntityId;
                                   heat_source__enginesEids : EidList)
  //hull
  query(heat_source__hullEid) <| $ [es] (var transform aka hull_heat_source_transform : float3x4&)
    hull_heat_source_transform = transform

  //engine
  for partId, heatEid in heat_source__dmEnginePartIds, heat_source__enginesEids
    updateHeatSourceTm(transform, collres, animchar, damage_model,
      partId, heatEid);

[es(tag=render, before=aircraft_heat_source_update_es)]
def aircraft_temperature_update_es(info : UpdateStageInfoAct;
                                   isExploded : bool;
                                   fatal_explosion_fire__endTime : float;
                                   heat_source__hullEid : EntityId;
                                   heat_source__enginesEids : EidList;
                                   heat_source__engine_temp_mult : float;
                                   heat_source__engine_temp_max : float;
                                   heat_source__engine_heating_spd : float2;
                                   heat_source__hull_base_temp : float;
                                   heat_source__hull_cooling_speed : float;
                                   heat_source__on_fire_technic_temp_mult : float;
                                   var plane_net_phys : PlaneActor&)
  //hull
  if isExploded
    query(heat_source__hullEid) <| $ [es] (var heat_source__temperature : float4&)
      if info.curTime >= fatal_explosion_fire__endTime && fatal_explosion_fire__endTime > 0.f
        let resultHullTemp = clamp(heat_source__temperature.y - heat_source__hull_cooling_speed * info.dt, 0.0f, heat_source__on_fire_technic_temp_mult * heat_source__hull_base_temp)
        heat_source__temperature = float4(1.0f, resultHullTemp, 1.0f, resultHullTemp)
    return ;
  //engines
  assume propulsion = plane_net_phys.phys.EI
  if propulsion != null
    let numEngines = (*propulsion).numEngines
    for eid, i in heat_source__enginesEids, range(numEngines)
      (*propulsion) |> propulsion_getEngine(i) <| $(engine)
        var mult = engine_hasFuel(engine, plane_net_phys.phys) || int(engine.stage) > int(EStage E_STAGE_NOMINAL) || int(engine.damageLevel) >= MAX_ENGINE_DAMAGE_LEVEL ? 1.0f : 0.0f
        let heatingSpd = (engine.controlThrottle < 0.95) ? heat_source__engine_heating_spd.y : heat_source__engine_heating_spd.x
        mult *= engine.readyness
        query(eid) <| $ [es] (var heat_source__temperature : float4&)
          heat_source__temperature.w = clamp(heat_source__temperature.w + heatingSpd * info.dt, 0.f, heat_source__engine_temp_max) * mult
          heat_source__temperature.y = heat_source__engine_temp_mult * (heat_source__engine_temp_max) * safediv(heat_source__temperature.w, heat_source__engine_temp_max) * mult