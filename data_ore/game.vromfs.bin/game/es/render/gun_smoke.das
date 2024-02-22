require ecs
require AnimV20
require GeomNodeTree
require DagorSystem
require math.base
require enlisted.events_enlisted
require DagorMath
require DngCamera
require dm
require DngDm
require CollRes


def is_gun_too_far_from_camera(gun_pos : vec4f; threshold_dist_sq : float)
  let camTm = get_TMatrix(get_cur_cam_entity(), "transform")
  if camTm == null
    return true
  let camPos = (*camTm)[3]
  return distance_sq(gun_pos.xyz, camPos) > threshold_dist_sq

def smoke_fx_on_shot(eid : EntityId;
                     animchar : AnimcharBaseComponent;
                     gun_smoke_fx__nodeIds : IntList;
                     gun_smoke_fx__incAmountPerShot : float;
                     gun_smoke_fx__template : StringList;
                     gun_smoke_fx__scale : FloatList;
                     gun_smoke_fx__visibleAmountThreshold : FloatList;
                     var gun_smoke_fx__amount : float&;
                     var gun_smoke_fx__fxEids : EidList&;
                     gun_smoke_fx__fxOffsets : Point3List const? = null)
  gun_smoke_fx__amount = min(1.0, gun_smoke_fx__amount + gun_smoke_fx__incAmountPerShot)

  for counter, nodeId, fxTemplate, scale, fxEid, threshold in iter_range(gun_smoke_fx__nodeIds), gun_smoke_fx__nodeIds, gun_smoke_fx__template, gun_smoke_fx__scale, gun_smoke_fx__fxEids, gun_smoke_fx__visibleAmountThreshold
    if fxEid != INVALID_ENTITY_ID || gun_smoke_fx__amount < threshold || nodeId < 0
      continue

    var tm : float3x4
    geomtree_getNodeWtmScalar(*animchar.nodeTree, nodeId, tm)
    for i in 0..3
      tm[i] *= scale
    peek(fxTemplate) <| $(fxTemplateStr)
      fxEid = createEntity(fxTemplateStr) <| $(var init : ComponentsInitializer)
        init |> set("transform", tm)
        init |> set("gun_fx__ownerEid", eid)
        init |> set("gun_fx__nodeId", nodeId)
        if gun_smoke_fx__fxOffsets != null
          let offset = (*gun_smoke_fx__fxOffsets)[counter]
          init |> set("gun_fx__offset", offset)

def smoke_update(dt : float;
                 animchar_render__root_pos : vec4f;
                 gun_smoke_fx__halfLife : float;
                 gun_smoke_fx__thresholdDistSq : float;
                 gun_smoke_fx__opacityMult : FloatList;
                 gun_smoke_fx__visibleAmountThreshold : FloatList;
                 var gun_smoke_fx__fxEids : EidList;
                 var gun_smoke_fx__amount : float&;
                 animchar__visible : bool = true)
  let visible = animchar__visible && !is_gun_too_far_from_camera(animchar_render__root_pos, gun_smoke_fx__thresholdDistSq)
  for fxEid, opacityMult, threshold in gun_smoke_fx__fxEids, gun_smoke_fx__opacityMult, gun_smoke_fx__visibleAmountThreshold
    if fxEid != INVALID_ENTITY_ID
      if !visible || gun_smoke_fx__amount < threshold
        destroyEntity(fxEid)
        fxEid = INVALID_ENTITY_ID
      else
        query(fxEid) <| $ [es] (var effect__colorMult : E3DCOLOR&)
          let opacity = uint(255.0 * min(1.0, opacityMult * gun_smoke_fx__amount))
          effect__colorMult = E3DCOLOR(uint4(opacity, opacity, opacity, 255u))

  if visible
    gun_smoke_fx__amount *= pow(0.5, safediv(dt, gun_smoke_fx__halfLife))
  else
    gun_smoke_fx__amount = 0.0

[es(tag=render, on_appear)]
def gun_smoke_fx_init(evt : Event;
                      eid : EntityId;
                      animchar : AnimcharBaseComponent;
                      [[shared_comp]] gun_smoke_fx__nodes : StringList;
                      [[shared_comp]] gun_smoke_fx__template : StringList;
                      [[shared_comp]] gun_smoke_fx__scale : FloatList;
                      [[shared_comp]] gun_smoke_fx__opacityMult : FloatList;
                      [[shared_comp]] gun_smoke_fx__visibleAmountThreshold : FloatList;
                      var gun_smoke_fx__nodeIds : IntList&;
                      var gun_smoke_fx__fxEids : EidList&)
  let numFx = length(gun_smoke_fx__nodes)
  gun_smoke_fx__nodeIds |> resize(numFx)
  gun_smoke_fx__fxEids |> resize(numFx)

  if length(gun_smoke_fx__template) != numFx || length(gun_smoke_fx__scale) != numFx || length(gun_smoke_fx__opacityMult) != numFx || length(gun_smoke_fx__visibleAmountThreshold) != numFx
    logerr("[{eid}] {getEntityTemplateName(eid)}: gun_smoke_fx has wrong number of elements in lists")

  for id, node in gun_smoke_fx__nodeIds, gun_smoke_fx__nodes
    id = geomtree_findNodeIndex(*animchar.nodeTree, string(node))
    if id < 0
      logerr("[{eid}] {getEntityTemplateName(eid)}: gun_smoke_fx node {node} not found")

[es(tag=render, on_appear, REQUIRE=resolvedTurret, REQUIRE_NOT=gun__isLauncher, after=technic_heat_source_init_es)]
def tankgun_smoke_fx_init(evt : Event;
                          eid : EntityId;
                          turret__owner : EntityId;
                          turret_dm_part__barrelDm : int;
                          gun_smoke_fx__offsetMultRadius : float;
                          [[shared_comp]] gun_smoke_fx__template : StringList;
                          [[shared_comp]] gun_smoke_fx__scale : FloatList;
                          [[shared_comp]] gun_smoke_fx__opacityMult : FloatList;
                          [[shared_comp]] gun_smoke_fx__visibleAmountThreshold : FloatList;
                          var gun_smoke_fx__nodeIds : IntList&;
                          var gun_smoke_fx__fxEids : EidList&;
                          var gun_smoke_fx__fxOffsets : Point3List&)
  if (turret_dm_part__barrelDm < 0)
    logwarn("[{eid}] {getEntityTemplateName(eid)}: barrelDmId is -1, tankgun_smoke_fx_init could not determine the node to put tankgun_smoke effect in..")
    logwarn("please check that a proper barrelDm name is set for this turret template")
    return
  query(turret__owner) <| $ [es] (animchar : AnimcharBaseComponent;
                                  collres : CollisionResource;
                                  damage_model : DamageModel)
    let numFx = length(gun_smoke_fx__template)
    gun_smoke_fx__nodeIds |> resize(numFx)
    gun_smoke_fx__fxEids |> resize(numFx)
    gun_smoke_fx__fxOffsets |> resize(numFx)

    if length(gun_smoke_fx__scale) != numFx || length(gun_smoke_fx__opacityMult) != numFx || length(gun_smoke_fx__visibleAmountThreshold) != numFx
      logerr("[{eid}] {getEntityTemplateName(eid)}: gun_smoke_fx has wrong number of elements in lists")

    for id, offset in gun_smoke_fx__nodeIds, gun_smoke_fx__fxOffsets
      let collisionNodeId = damage_model.dmData.parts[turret_dm_part__barrelDm].collisionNodeId
      let node = collres_get_node(collres, collisionNodeId)
      id = -1
      if node != null
        id = uint((*node).geomNodeId) < uint(animchar.nodeTree.nodeCount) ? int((*node).geomNodeId) : -1
        let center = (*node).modelBBox.center
        offset = (float3(center.x, center.z, 0.0f) + float3(gun_smoke_fx__offsetMultRadius * node.boundingSphere.r, 0.0, 0.0))
      if id < 0
        logerr("[{eid}] {getEntityTemplateName(eid)}: gun_smoke_fx not found node related to {turret_dm_part__barrelDm} dmId part")

[es(tag=render, on_event=(CmdNetShot, EventShot))]
def gun_smoke_fx_on_shot(evt : Event;
                         eid : EntityId;
                         animchar_render__root_pos : vec4f;
                         animchar : AnimcharBaseComponent;
                         gun_smoke_fx__nodeIds : IntList;
                         gun_smoke_fx__incAmountPerShot : float;
                         gun_smoke_fx__thresholdDistSq : float;
                         [[shared_comp]] gun_smoke_fx__template : StringList;
                         [[shared_comp]] gun_smoke_fx__scale : FloatList;
                         [[shared_comp]] gun_smoke_fx__visibleAmountThreshold : FloatList;
                         var gun_smoke_fx__amount : float&;
                         var gun_smoke_fx__fxEids : EidList&;
                         animchar__visible : bool = true)
  if !animchar__visible || is_gun_too_far_from_camera(animchar_render__root_pos, gun_smoke_fx__thresholdDistSq)
    return
  smoke_fx_on_shot(eid, animchar,
                    gun_smoke_fx__nodeIds, gun_smoke_fx__incAmountPerShot, gun_smoke_fx__template,
                    gun_smoke_fx__scale, gun_smoke_fx__visibleAmountThreshold,
                    gun_smoke_fx__amount, gun_smoke_fx__fxEids)

[es(tag=render, on_event=(CmdNetShot, EventShot))]
def tankgun_smoke_fx_on_shot(evt : Event;
                             turret__owner : EntityId;
                             gun_smoke_fx__nodeIds : IntList;
                             gun_smoke_fx__incAmountPerShot : float;
                             gun_smoke_fx__thresholdDistSq : float;
                             [[shared_comp]] gun_smoke_fx__template : StringList;
                             [[shared_comp]] gun_smoke_fx__scale : FloatList;
                             [[shared_comp]] gun_smoke_fx__visibleAmountThreshold : FloatList;
                             gun_smoke_fx__fxOffsets : Point3List const?;
                             var gun_smoke_fx__amount : float&;
                             var gun_smoke_fx__fxEids : EidList&)
  query(turret__owner) <| $ [es] (animchar : AnimcharBaseComponent;
                                  animchar_render__root_pos : vec4f;
                                  animchar__visible : bool = true)
    if !animchar__visible || is_gun_too_far_from_camera(animchar_render__root_pos, gun_smoke_fx__thresholdDistSq)
      return
    smoke_fx_on_shot(turret__owner, animchar,
                    gun_smoke_fx__nodeIds, gun_smoke_fx__incAmountPerShot, gun_smoke_fx__template,
                    gun_smoke_fx__scale, gun_smoke_fx__visibleAmountThreshold,
                    gun_smoke_fx__amount, gun_smoke_fx__fxEids, gun_smoke_fx__fxOffsets)

[es(tag=render, after=after_animchar_update_sync, before=effect_attached_es)]
def gun_smoke_update(info : ParallelUpdateFrameDelayed;
                     animchar_render__root_pos : vec4f;
                     gun_smoke_fx__halfLife : float;
                     gun_smoke_fx__thresholdDistSq : float;
                     [[shared_comp]] gun_smoke_fx__opacityMult : FloatList;
                     [[shared_comp]] gun_smoke_fx__visibleAmountThreshold : FloatList;
                     var gun_smoke_fx__fxEids : EidList;
                     var gun_smoke_fx__amount : float&;
                     animchar__visible : bool = true)
  smoke_update(info.dt, animchar_render__root_pos,
               gun_smoke_fx__halfLife, gun_smoke_fx__thresholdDistSq,
               gun_smoke_fx__opacityMult, gun_smoke_fx__visibleAmountThreshold,
               gun_smoke_fx__fxEids, gun_smoke_fx__amount, animchar__visible)

[es(tag=render, after=after_animchar_update_sync, before=effect_attached_es)]
def tankgun_smoke_update(info : ParallelUpdateFrameDelayed;
                         turret__owner : EntityId;
                         gun_smoke_fx__halfLife : float;
                         gun_smoke_fx__thresholdDistSq : float;
                         [[shared_comp]] gun_smoke_fx__opacityMult : FloatList;
                         [[shared_comp]] gun_smoke_fx__visibleAmountThreshold : FloatList;
                         var gun_smoke_fx__fxEids : EidList;
                         var gun_smoke_fx__amount : float&)
  query(turret__owner) <| $ [es] (animchar_render__root_pos : vec4f;
                                  animchar__visible : bool = true)
    smoke_update(info.dt, animchar_render__root_pos,
               gun_smoke_fx__halfLife, gun_smoke_fx__thresholdDistSq,
               gun_smoke_fx__opacityMult, gun_smoke_fx__visibleAmountThreshold,
               gun_smoke_fx__fxEids, gun_smoke_fx__amount, animchar__visible)