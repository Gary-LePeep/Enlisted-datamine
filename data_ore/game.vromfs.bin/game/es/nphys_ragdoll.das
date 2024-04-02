require app
require ecs
require AnimV20
require PhysDecl
require Dacoll
require danetlibs.navmesh_phys.main.nphys_events


[es(track=isAlive, on_appear, REQUIRE=deadEntity, after=(navmesh_move_anim, navmesh_move_offline_anim), before=anim_state_es, REQUIRE_NOT=(anim_state__deathState, human_net_phys))]
def nphys_ragdoll_death_anim(evt : Event; eid : EntityId; isAlive : bool; ragdoll__isAllowed : bool = true; var ragdoll__applyParams : bool&;
                             var animchar : AnimcharBaseComponent; var ragdoll : PhysRagdoll; var animchar__animState : Object;
                             navmesh_phys__currentWalkVelocity : float3 const?)
  if !isAlive && ragdoll__isAllowed
    animchar__animState |> clear()
    let currentVelocity = navmesh_phys__currentWalkVelocity ?? float3()
    ragdoll |> ragdoll_setOverrideVel(currentVelocity)
    ragdoll |> ragdoll_startRagdoll(int(PhysLayer EPL_CHARACTER), int(PhysLayer EPL_ALL) & (~(int(PhysLayer EPL_KINEMATIC) | int(PhysLayer EPL_CHARACTER))), animchar.nodeTree)
    let curTime = get_sync_time()
    ragdoll__applyParams = true
    sendEvent(eid, [[CmdApplyRagdollParameters cur_time=curTime]])
    animchar |> animchar_setPostController(ragdoll)