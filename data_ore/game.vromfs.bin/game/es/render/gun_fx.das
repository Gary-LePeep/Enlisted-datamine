require ecs
require AnimV20
require GeomNodeTree
require math
require math.base
require enlisted.events_enlisted

[es(tag=render, after=after_animchar_update_sync, before=effect_attached_es)]
def gun_fx_update(info : ParallelUpdateFrameDelayed;
                  gun_fx__ownerEid : EntityId;
                  gun_fx__nodeId : int;
                  var transform : float3x4&;
                  gun_fx__nodeMultTm : float3x4 const?;
                  gun_fx__offset : float3 const?)
  query(gun_fx__ownerEid) <| $ [es] (animchar : AnimcharBaseComponent)
    geomtree_getNodeWtmScalar(*animchar.nodeTree, gun_fx__nodeId, transform)
    if gun_fx__offset != null
      transform[3] = transform * (*gun_fx__offset)
    if gun_fx__nodeMultTm != null
      transform = transform * (*gun_fx__nodeMultTm)

[es(tag=render, no_order, REQUIRE=gun_fx__destroyIfGunDoesNotExist)]
def gun_fx_destroy_if_gun_does_not_exist(info : ParallelUpdateFrameDelayed; eid : EntityId; gun_fx__ownerEid : EntityId)
  if !doesEntityExist(gun_fx__ownerEid)
    destroyEntity(eid)
