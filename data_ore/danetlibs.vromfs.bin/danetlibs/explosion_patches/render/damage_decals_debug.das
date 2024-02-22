options no_aot
require ecs
require math
require AnimV20
require DagorConsole
require DagorDebug3D
require DagorMath

//to be moved to daNetGameLibs
[cpp_event(broadcast)]
struct ParallelUpdateFrameDelayed
  curTime : float
  dt : float

[console_cmd(name="damage_decals.explosion_traces_debug")]
def explosion_traces_debug_cmd(enable : bool = true)
  query() <| $ [es(REQUIRE=damage_decals__explosionNumTraces)] (eid : EntityId)
    var newTemplate : string
    if enable
      newTemplate = add_sub_template_name(eid, "shrapnel_decals_debug")
    else
      newTemplate = remove_sub_template_name(eid, "shrapnel_decals_debug")
    if !empty(newTemplate)
      reCreateEntityFrom(eid, newTemplate)

[es(tag=(dev, render), before=vehicle_shrapnel_decals_process_explosion)]
def damage_decals_explosion_traces_debug(evt : ParallelUpdateFrameDelayed;
                                         var damage_decals__prevExplosionPos : float3&;
                                         var damage_decals__prevExplosionRadius : float&;
                                         damage_decals__explosionPos : Point3List;
                                         damage_decals__explosionMaxTraceLen : FloatList)
  if empty(damage_decals__explosionPos)
    return
  damage_decals__prevExplosionPos = back(damage_decals__explosionPos)
  damage_decals__prevExplosionRadius = back(damage_decals__explosionMaxTraceLen)

[es(tag=(dev, render), no_order)]
def draw_damage_decals_explosion_traces_debug(evt : UpdateStageInfoRenderDebug;
                                              eid : EntityId;
                                              damage_decals__prevExplosionPos : float3;
                                              damage_decals__prevExplosionRadius : float;
                                              damage_decals__prevExplosionTraceLen : float;
                                              damage_decals__prevExplosionTraces : Point3List)
  if length(damage_decals__prevExplosionTraces) == 0
    return
  var selectedEid = INVALID_ENTITY_ID
  query() <| $ [es(REQUIRE=daeditor__selected)] (eid aka selected_eid : EntityId)
    selectedEid = selected_eid
  if selectedEid != INVALID_ENTITY_ID && selectedEid != eid
    return
  assume explosionPos = damage_decals__prevExplosionPos
  begin_draw_cached_debug_lines(true, false, false)
  draw_cached_debug_sphere(explosionPos, damage_decals__prevExplosionRadius, E3DCOLOR(0xFFFF7F00), 16)
  for tracePoint in damage_decals__prevExplosionTraces
    let dist = length(tracePoint - explosionPos)
    let hit = dist < damage_decals__prevExplosionTraceLen - 0.01
    let color = hit ? E3DCOLOR(0xFFFFFF00) : E3DCOLOR(0xFFFF0000)
    draw_cached_debug_line(explosionPos, tracePoint, color)
    if (hit)
      draw_cached_debug_sphere(tracePoint, 0.05, color, 8)
  end_draw_cached_debug_lines()

