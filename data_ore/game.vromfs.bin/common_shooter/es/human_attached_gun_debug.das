options no_aot
require app
require ecs
require ecs.ecs_template
require game.utils.hero
require DagorConsole
require DagorDebug3D
require math
require math.base
require DagorMath
require AnimV20
require GeomNodeTree
require common_shooter.es.human_attached_gun_common


[ecs_template]
struct stgun_debug
  stgun_debug_tag : Tag

[console_cmd(name="stgun.debug")]
def stgun_debug()
  let hero = get_controlled_hero()
  if has(hero, "stgun_debug_tag")
    removeSubTemplate(hero, "stgun_debug")
  else
    addSubTemplate(hero, "stgun_debug")


[es(tag=(dev, render), REQUIRE=(hero, stgun_debug_tag), after=human_attached_gun_controls_update_es)]
def stgun_debug_es(info : UpdateStageInfoRenderDebug;
                   human_attached_gun__attachedGunEid : EntityId)
  query(human_attached_gun__attachedGunEid) <| $ [es] (transform : float3x4;
                                                       mounted_gun__aiRotOffset : float3 = MOUNTED_GUN_DEFAULT_ROT_OFFSET;
                                                       mounted_gun__aiLimitsMod : float2 = MOUNTED_GUN_DEFAULT_LIMITS_MOD;
                                                       mounted_gun__aiFireRange : float2 = MOUNTED_GUN_DEFAULT_FIRE_RANGE;
                                                       mounted_gun__horz_limits : float2;
                                                       mounted_gun__vert_limits : float2;
                                                       animchar : AnimcharBaseComponent)
    begin_draw_cached_debug_lines(true, true, false)

    let c1 = E3DCOLOR(0xFFFF00FF)
    let c2 = E3DCOLOR(0xFFFFFFFF)

    // brow_m1919a4     offset=(0.0, 0.37, 0.1),  limits=(0.95, 0.95)
    // dshk             offset=(0.0, 1.5, 0.2),   limits=(0.95, 1.0)
    // maxim            offset=(0.0, 0.5, 0.1),   limits=(0.97, 0.95)
    // mg_42            offset=(0.0, 0.3, 0.4),   limits=(0.97, 0.95)
    // mg_131           offset=(0.0, 0.5, 0.45),  limits=(0.95, 0.9)
    // type_92_hmg      offset=(0.0, 0.4, 0.0),   limits=(0.97, 0.95)
    // mg_34            offset=(0.0, 0.08, 0.25), limits=(0.97, 0.95)
    // ampulomet        offset=(0.0, 0.3, 0.0),   limits=(0.97, 0.95)
    // turret_105skc32  offset=(0.0, 0.25, 0.45), limits(0.25, 0.95)
    // brow_m2          offset=(0.0, 0.35, 0.05), limits(0.97, 0.95)
    // type_93_hmg      offset=(0.0, 1.2, 0.2),   limits(0.95, 0.95)
    //
    // == average ==    offset=(0.0, 0.3, 0.3),   limits(0.95, 0.95)

    let gunFw = -transform[2]
    let gunRt = -transform[0]
    let gunUp = transform[1]
    let gunPos = transform[3] + gunUp * mounted_gun__aiRotOffset.y + mounted_gun__aiRotOffset.x * gunRt + gunFw * mounted_gun__aiRotOffset.z

    let angleL = deg_to_rad(mounted_gun__horz_limits.x * mounted_gun__aiLimitsMod.x)
    let angleR = deg_to_rad(mounted_gun__horz_limits.y * mounted_gun__aiLimitsMod.x)
    let angleD = deg_to_rad(mounted_gun__vert_limits.x * mounted_gun__aiLimitsMod.y)
    let angleU = deg_to_rad(mounted_gun__vert_limits.y * mounted_gun__aiLimitsMod.y)

    let gunRange = mounted_gun__aiFireRange.x
    let gunPtLM = gunPos + (gunFw * cos(angleL) + gunRt * sin(angleL)) * gunRange
    let gunPtRM = gunPos + (gunFw * cos(angleR) + gunRt * sin(angleR)) * gunRange
    let gunPtMU = gunPos + (gunFw * cos(angleU) + gunUp * sin(angleU)) * gunRange
    let gunPtMD = gunPos + (gunFw * cos(angleD) + gunUp * sin(angleD)) * gunRange

    draw_cached_debug_sphere(gunPos, 0.1, c2, 8)
    draw_cached_debug_sphere(gunPtLM, 0.1, c2, 8)
    draw_cached_debug_sphere(gunPtRM, 0.1, c2, 8)
    draw_cached_debug_sphere(gunPtMU, 0.1, c2, 8)
    draw_cached_debug_sphere(gunPtMD, 0.1, c2, 8)

    var ptA = float3()
    let divs = 10
    for i in 0..divs
      let k = -1.0 + float(i) * 2.0 / float(divs)
      if get_attached_gun_ai_aim_point(ptA, human_attached_gun__attachedGunEid, -k, -1.0, 0.0)
        draw_cached_debug_sphere(ptA, 0.1, c1, 32)
      if get_attached_gun_ai_aim_point(ptA, human_attached_gun__attachedGunEid, k, 1.0, 0.0)
        draw_cached_debug_sphere(ptA, 0.1, c1, 32)
      if get_attached_gun_ai_aim_point(ptA, human_attached_gun__attachedGunEid, -1.0, k, 0.0)
        draw_cached_debug_sphere(ptA, 0.1, c1, 32)
      if get_attached_gun_ai_aim_point(ptA, human_attached_gun__attachedGunEid, 1.0, -k, 0.0)
        draw_cached_debug_sphere(ptA, 0.1, c1, 32)
      if get_attached_gun_ai_aim_point(ptA, human_attached_gun__attachedGunEid, -k, -1.0, 1.0)
        draw_cached_debug_sphere(ptA, 1.1, c1, 32)
      if get_attached_gun_ai_aim_point(ptA, human_attached_gun__attachedGunEid, k, 1.0, 1.0)
        draw_cached_debug_sphere(ptA, 1.1, c1, 32)
      if get_attached_gun_ai_aim_point(ptA, human_attached_gun__attachedGunEid, -1.0, k, 1.0)
        draw_cached_debug_sphere(ptA, 1.1, c1, 32)
      if get_attached_gun_ai_aim_point(ptA, human_attached_gun__attachedGunEid, 1.0, -k, 1.0)
        draw_cached_debug_sphere(ptA, 1.1, c1, 32)

    let nodeId = geomtree_findNodeIndex(*animchar.nodeTree, "gunFx_main")
    if nodeId >= 0
      var nodeTm = transform
      geomtree_getNodeWtmScalar(*animchar.nodeTree, nodeId, nodeTm)
      draw_cached_debug_sphere(nodeTm[3], 0.2, c1, 24)
      let pt1 = nodeTm[3]
      let pt2 = nodeTm[3] + nodeTm[1] * 5.1
      var cc = c2
      if is_pos_in_attached_gun_ai_aim_range(pt2, human_attached_gun__attachedGunEid)
        cc = c1
      draw_cached_debug_line(pt1, pt2, cc)
      draw_cached_debug_sphere(pt2, 0.2, cc, 12)

    end_draw_cached_debug_lines()
