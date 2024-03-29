require ecs
require DngHuman
require HumanPhys
require Gun
require enlisted.events_enlisted

[es(before=after_net_phys_sync, after=human_weap_phys_es)]
def enlisted_human_weap_phys_es(info : ParallelUpdateFrameDelayed;
                                human_phys__jumpEndTime : float;
                                human_phys__isInAirLong : bool;
                                human_weap__canAimInJump : bool = false;
                                human_phys__afterJumpDelay : float = -1.;
                                human_phys__aimPoseHeightVelThreshold : float;
                                human_phys__aimPoseHeightThreshold : float;
                                action__running : bool;
                                var human_net_phys : HumanActor&)
  assume ct = human_net_phys.phys.currentState
  let isChangingCrawlTransition = ct.height < human_phys__aimPoseHeightThreshold && abs(ct.heightCurVel) > human_phys__aimPoseHeightVelThreshold
  let isJumpState = (!human_weap__canAimInJump &&
    (human_phys__isInAirLong
    || (uint(ct.states) & uint(StateFlag ST_JUMP)) != 0u
    || ct.jumpStartTime > 0.
    || info.curTime - human_phys__jumpEndTime < human_phys__afterJumpDelay))
  human_phys_state_set_can_aim(ct, human_phys_state_can_aim(ct) && !isJumpState && !isChangingCrawlTransition && !action__running)
  human_phys_state_set_can_zoom(ct, human_phys_state_can_zoom(ct) && !isJumpState && !isChangingCrawlTransition && !action__running)

[es(on_event=CmdPostPhysUpdate)]
def enlisted_human_weap_phys_reduce_to_walk_when_shoot(evt : Event;
                                                       human_weap__currentGunEid : EntityId;
                                                       var human_net_phys : HumanActor&)
  var reduceToWalk = false
  query(human_weap__currentGunEid) <| $ [es(REQUIRE=gun__reduceToWalkWhenShot)] (gun : Gun)
    reduceToWalk = gun.curState.atTime < gun.curState.nextShotAtTime
  human_phys_state_set_reduceToWalk(human_net_phys.phys.currentState, reduceToWalk)
