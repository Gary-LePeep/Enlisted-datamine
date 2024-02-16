require ecs
require math.base
require DagorMath
require game.es.artillery_aircraft_common


[es(tag=server, on_appear)]
def scripted_plane_spawner_on_appear(evt : Event;
                                     scripted_plane_spawner__firstSpawnDelay : float;
                                     var scripted_plane_spawner__timeToSpawn : float&)
  scripted_plane_spawner__timeToSpawn = scripted_plane_spawner__firstSpawnDelay


[es(tag=server, no_order)]
def scripted_plane_spawner_update(info : UpdateStageInfoAct;
                                  team : int;
                                  scripted_plane_spawner__flyFrom : float3;
                                  scripted_plane_spawner__flyTo : float3;
                                  scripted_plane_spawner__spawnPeriod : float;
                                  scripted_plane_spawner__planeSpeed : float;
                                  scripted_plane_spawner__planeTemplate : string;
                                  var scripted_plane_spawner__timeToSpawn : float&)
  if scripted_plane_spawner__timeToSpawn > 0.0
    scripted_plane_spawner__timeToSpawn -= info.dt
    return

  scripted_plane_spawner__timeToSpawn = scripted_plane_spawner__spawnPeriod

  createEntity(scripted_plane_spawner__planeTemplate) <| $(var init : ComponentsInitializer)
    var tm = IDENT_TM
    tm[0] = normalize(scripted_plane_spawner__flyTo - scripted_plane_spawner__flyFrom)
    tm[2] = cross(tm[0], float3(0, 1, 0))
    tm[1] = cross(tm[2], tm[0])
    tm[3] = scripted_plane_spawner__flyFrom

    set(init, "transform", tm)
    set(init, "team", team)
    set(init, "startVelDir", tm[0])
    set(init, "startRelativeSpeed", 1.0)
    set(init, "ai_aircraft__state", int(AIAircraftState FLY_TO_END))
    set(init, "ai_aircraft__wishSpeed", scripted_plane_spawner__planeSpeed)
    set(init, "ai_aircraft__flyPos", scripted_plane_spawner__flyTo)
    set(init, "ai_aircraft__endPos", scripted_plane_spawner__flyTo)


[es(tag=server, no_order)]
def scripted_plane_destroy(info : UpdateStageInfoAct;
                           eid : EntityId;
                           transform : float3x4;
                           ai_aircraft__endPos : float3;
                           scripted_plane__nearEndPosRadiusSq : float)
  if distance_sq(transform[3], ai_aircraft__endPos) < scripted_plane__nearEndPosRadiusSq
    destroyEntity(eid)
