require ecs
require app
require math.base
require game.events_game
require strings
require DngHumanAnim
require DngHuman
require DngActor
require DngNet
require PhysVars
require PhysDecl
require HumanPhys
require HumanAnim
require DagorMath
require DagorSystem
require Dacoll
require GeomNodeTree
require AnimV20
require enlisted.events_enlisted

[es(tag=gameClient, after=human_anim_ragdoll_es, before=ragdoll_start_es, on_event=ParallelUpdateFrameDelayed)]
def clean_extra_projectile_impulse(evt : Event;
                                   projectile_impulse : ProjectileImpulse;
                                   ragdoll__applyParams : bool;
                                   var projectile_impulse__impulseSaveDeltaTime : float&;
                                   projectile_impulse__maxCount = 5)
  if !ragdoll__applyParams
    return
  let curTime = get_sync_time()
  projectile_impulse_get_data(projectile_impulse) <| $(pairs)
    let impulsesCount = length(pairs)
    if impulsesCount > projectile_impulse__maxCount
      let impulseTime = pairs[impulsesCount - projectile_impulse__maxCount].time
      if impulseTime > curTime - projectile_impulse__impulseSaveDeltaTime
        projectile_impulse__impulseSaveDeltaTime = impulseTime - curTime

[es(on_appear)]
def init_ragdolls_wake_up_node_ind(evt : Event;
                                   eid : EntityId;
                                   animchar : AnimcharBaseComponent;
                                   var ragdoll__wakeUpNodeId : int&;
                                   ragdoll__wakeUpNode : string)
  let wakeUpNodeInd = geomtree_findNodeIndex(*animchar.nodeTree, ragdoll__wakeUpNode)
  if wakeUpNodeInd < 0
    logerr("Node {ragdoll__wakeUpNode} was not found in node tree of [{eid}] {getEntityTemplateName(eid)}. Use default ragdoll__wakeUpNodeId = {ragdoll__wakeUpNodeId}")
  else
    ragdoll__wakeUpNodeId = wakeUpNodeInd

[es(tag=render)]
def wake_up_ragdoll_on_ri_destroy(evt : EventRendinstDestroyedClient;
                                  animchar : AnimcharBaseComponent;
                                  var ragdoll : PhysRagdoll;
                                  ragdoll__wakeUpNodeId : int&;
                                  var animchar__updatable : bool&)
  let rootPos = geomtree_getNodeWpos(*animchar.nodeTree, ragdoll__wakeUpNodeId)
  if !animchar__updatable && (evt.riGlobBBox & rootPos)
    animchar__updatable = true
    if ! ragdoll |> ragdoll_wakeUp()
      ragdoll |> ragdoll_startRagdoll(int(PhysLayer EPL_CHARACTER),
                                      int(PhysLayer EPL_ALL & (~(PhysLayer EPL_KINEMATIC | PhysLayer EPL_CHARACTER))),
                                      animchar.nodeTree)

def start_ragdoll(var ragdoll : PhysRagdoll;
                  var ragdoll__applyParams : bool&;
                  var animchar : AnimcharBaseComponent;
                  unitTm : float3x4;
                  pos : float3;
                  eid : EntityId;
                  curTime : float)
  animchar |> animchar_resetPostController()

  let boxScale = float3(0.5f)
  let box = BBox3(unitTm[3] - boxScale, unitTm[3] + boxScale)
  update_ri_cache_in_volume_to_phys_world(box)
  // Go through wtm/tms setuping proper collision
  // There was a hand-made extrapolation of current position by velocity, position and dt before.
  // Yes, fixing the jump in position creates more visually pleasing animations.
  // But it shouldn't be done, as also anything, that may move the animchar in a physically incorrect position.
  // Meaning it may become pushed inside the wall or under the ground. Hence why we override the transform position to
  // the last server-authoritated position.
  animchar |> animchar_set_tm(pos, unitTm[0], unitTm[1])
  // Recalc tm so ragdoll will have proper coordinates and anything, like visual entity offset will not interfere
  animchar |> animchar_recalc_wtm()
  ragdoll__applyParams = true
  sendEvent(eid, [[CmdApplyRagdollParameters cur_time=curTime]])
  animchar |> animchar_setPostController(ragdoll)

def stop_ragdoll(var ragdoll : PhysRagdoll;
                 var animchar : AnimcharBaseComponent)
  ragdoll |> ragdoll_endRagdoll()
  animchar |> animchar_resetPostController()

[es(tag=render, before=ragdoll_start_es)]
def human_anim_ragdoll_start_es(info : ParallelUpdateFrameDelayed;
                                var animchar : AnimcharBaseComponent;
                                var ragdoll : PhysRagdoll;
                                ragdoll__applyParams : bool;
                                human_net_phys__locationPos : DPoint3;
                                human_net_phys__velocity : float3;
                                human_anim__dynamicRagdollClipoutTimeout : float = 0.4;
                                human_anim__dynamicRagdollClipoutOffset : float3 = float3(0., 0.5, 0.))
  if !ragdoll__applyParams
    return
  let pos = float3(human_net_phys__locationPos)
  let vel = human_net_phys__velocity
  if (human_anim__dynamicRagdollClipoutTimeout > 0.0f)
    let toPos = pos + human_anim__dynamicRagdollClipoutOffset
    ragdoll |> ragdoll_setDynamicClipout(toPos, human_anim__dynamicRagdollClipoutTimeout)
  ragdoll |> ragdoll_setOverrideVel(vel)
  ragdoll |> ragdoll_startRagdoll(int(PhysLayer EPL_CHARACTER),
                                  int(PhysLayer EPL_ALL & (~(PhysLayer EPL_KINEMATIC | PhysLayer EPL_CHARACTER))),
                                  animchar.nodeTree)


[es(tag=render, before=human_anim_ragdoll_start_es)]
def human_anim_ragdoll_es(info : ParallelUpdateFrameDelayed)
  var ragdollStarts = -1
  query() <| $ [es(REQUIRE=deadEntity)] (animchar__updatable : bool;
                                         human_net_phys__locationPos : DPoint3;
                                         transform : float3x4;
                                         eid : EntityId;
                                         ragdoll__isAllowed : bool = true;
                                         ragdoll__maxEntitiesInUpdate : int = 2;
                                         var ragdoll__applyParams : bool&;
                                         var human_anim__ragdollEnabled : bool&;
                                         var ragdoll : PhysRagdoll;
                                         var animchar : AnimcharBaseComponent)
    if !animchar__updatable
      return

    let shouldDoRagdoll = ragdoll__isAllowed
    if shouldDoRagdoll != human_anim__ragdollEnabled
      if shouldDoRagdoll
        if ragdollStarts < 0 && ragdoll__maxEntitiesInUpdate > 0
          ragdollStarts = ragdoll__maxEntitiesInUpdate

        if ragdollStarts == 0
          return

        human_anim__ragdollEnabled = true
        let curTime = info.curTime
        // human_net_phys__locationPos stores the last correct snapshot's position of the human phys
        start_ragdoll(ragdoll, ragdoll__applyParams, animchar, transform, float3(human_net_phys__locationPos), eid, curTime)
        ragdollStarts--
      else
        human_anim__ragdollEnabled = false
        stop_ragdoll(ragdoll, animchar)


[es(tag=render, REQUIRE=deadEntity, on_event=(EventComponentsDisappear))]
def stop_ragdoll_es(event : Event;
                    var animchar : AnimcharBaseComponent;
                    var human_anim__ragdollEnabled : bool&;
                    var ragdoll : PhysRagdoll)
  if human_anim__ragdollEnabled
    human_anim__ragdollEnabled = false
    stop_ragdoll(ragdoll, animchar)


[es(tag=render, on_appear, REQUIRE=deadEntity)]
def disable_far_ragdolls_on_death_es(evt : Event; transform : float3x4; var ragdoll__isAllowed : bool&)
  ragdoll__isAllowed &&= distance_sq(transform[3], get_hidden_pos()) > 1.0