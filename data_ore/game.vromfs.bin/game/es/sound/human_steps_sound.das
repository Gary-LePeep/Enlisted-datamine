require ecs
require ecs.safe
require soundHash
require soundSystem
require soundEvent
require sound_utils.modules.sound_player_common
require sound_utils_net.modules.sound_utils_net_events
require common_sounds.modules.common_sounds_events
require human_sounds.modules.human_steps_sound_common
require DngHuman
require game.utils.hero
require game.utils.team


def get_volume(is_watched_sound : bool; team : int; friend_volume : float)
  return (!is_watched_sound && is_teams_friendly(team, (get_int(get_controlled_hero(), "team") ?? TEAM_UNASSIGNED))) ? friend_volume : 1.


[es(tag=sound, REQUIRE=humanSound, REQUIRE_NOT=deadEntity)]
def human_steps_sound_irq(evt : CmdSoundStepIrq;
                          var human_steps_sound__irqObjIdx : int&)
  human_steps_sound__irqObjIdx = evt.objIdx


[es(tag=sound, after=(sound_landmesh_queries_update, start_async_phys_sim_es, sound_begin_update_es), before=sound_end_update_es)] // after start_async_phys_sim_es to start phys sim job earlier
def human_steps_sound_update(info : ParallelUpdateFrameDelayed)

  let listenerPos = get_listener_pos()

  query() <| $ [es(REQUIRE_NOT=deadEntity)] (eid : EntityId;
                                             transform : float3x4;
                                             team : int;
                                             is_watched_sound : bool;
                                             [[shared_comp]] human_steps_sound__path : Object;
                                             [[shared_comp]] human_steps_sound__irqs : Array;
                                             var human_steps_sound__irqObjIdx : int&;
                                             [[shared_comp]] human_steps_sound__runVoiceFx : Object;
                                             [[shared_comp]] human_steps_sound__walkVoiceFx : Object;
                                             sound_tags : Object;
                                             var sound_event_group : SoundEventGroup&;
                                             human_steps_sound__traceStepOffsetLen : float2;
                                             human_steps_sound__friendVolume : float;
                                             sound_landmesh_queries__biomePhysMatId : int;
                                             sound_landmesh_queries__biomeOverridesWater : bool;
                                             sound_landmesh_queries__puddleDepth : float;
                                             var human_steps_sound__smid : float&;
                                             var human_steps_sound__waterDepth : float&;
                                             var human_steps_sound__isOddStep : bool&;
                                             human_steps_sound__farawayThresholdSq : float;
                                             human_net_phys__states : int = int(StateFlag ST_ON_GROUND);
                                             human_net_phys__isClimbing : bool = false;
                                             var human_net_phys : HumanActor;

                                             animchar__animSpeed : float;
                                             animchar__updatable : bool;
                                             animchar__visible : bool;
                                             var human_steps_sound_generator__lastStepAt : float&;
                                             var human_steps_sound_generator__cooldown : float&;
                                             human_steps_sound_generator__walkRunSprint_stand_intervals : float3;
                                             human_steps_sound_generator__walkRunSprint_crouch_intervals : float3;
                                             human_steps_sound_generator__enableForVisible : bool;
                                             human_steps_sound_generator__enableForInvisible : bool)

    let irqObjIdx = human_steps_sound_generator(human_steps_sound__irqObjIdx,
                                                info.curTime,
                                                info.dt,
                                                listenerPos,
                                                transform[3],
                                                is_watched_sound,
                                                human_steps_sound__farawayThresholdSq,
                                                read_state(StateFlag ST_ON_GROUND, human_net_phys__states),
                                                human_net_phys__isClimbing,
                                                human_net_phys,
                                                animchar__animSpeed,
                                                animchar__updatable,
                                                animchar__visible,
                                                human_steps_sound_generator__lastStepAt,
                                                human_steps_sound_generator__cooldown,
                                                human_steps_sound_generator__walkRunSprint_stand_intervals,
                                                human_steps_sound_generator__walkRunSprint_crouch_intervals,
                                                human_steps_sound_generator__enableForVisible,
                                                human_steps_sound_generator__enableForInvisible,
                                                human_steps_sound__irqs)
    human_steps_sound__irqObjIdx = INVALID_IRQ_OBJ_IDX

    if irqObjIdx != INVALID_IRQ_OBJ_IDX
      let desc = human_steps_sound__irqs?[irqObjIdx] ?as Object
      if desc != null
        play_footstep(*desc,
                      human_steps_sound__path,
                      sound_tags,
                      get_volume(is_watched_sound, team, human_steps_sound__friendVolume),
                      eid,
                      transform[3],
                      human_steps_sound__isOddStep,
                      is_watched_sound,
                      human_steps_sound__traceStepOffsetLen,
                      sound_landmesh_queries__biomePhysMatId,
                      sound_landmesh_queries__biomeOverridesWater,
                      sound_landmesh_queries__puddleDepth,
                      human_steps_sound__smid,
                      human_steps_sound__waterDepth,
                      human_net_phys)
        human_steps_sound__isOddStep = !human_steps_sound__isOddStep

      let isRun = read_state(StateFlag ST_SPRINT, human_net_phys__states) && !read_state(StateFlag ST_WALK, human_net_phys__states)
      sound_player_common::play_path(isRun ? human_steps_sound__runVoiceFx : human_steps_sound__walkVoiceFx, sound_tags, is_watched_sound, transform[3], sound_hash(""), sound_event_group)


    query(eid) <| $ [es] ([[shared_comp]] sound_paths : Object;
                          [[shared_comp]] human_steps_sound__descs : Object;
                          [[shared_comp]] human_steps_sound__jumpFx : Object;
                          human_steps_sound__fallSpeedCollThreshold : float;
                          var sound_landmesh_queries_vars__speedSq : float&;
                          var sound_landmesh_queries_vars__isOnGround : bool&;
                          var human_steps_sound__physStates : int&;
                          var human_steps_sound__lastTimeOnGround : float&)

      sound_landmesh_queries_vars__speedSq = length_sq(human_net_phys.phys.currentState.velocity.xz)
      sound_landmesh_queries_vars__isOnGround = read_state(StateFlag ST_ON_GROUND, human_net_phys__states)

      let name = human_steps_sound_update_states(info.curTime,
                                                 listenerPos,
                                                 transform[3],
                                                 is_watched_sound,
                                                 human_steps_sound__farawayThresholdSq,
                                                 human_net_phys__states,
                                                 human_steps_sound__physStates,
                                                 human_steps_sound__lastTimeOnGround)

      if name == "jump"
        play_path(human_steps_sound__jumpFx, sound_tags, is_watched_sound, transform[3])
      elif name == "land"
        if !human_net_phys__isClimbing && info.curTime > human_steps_sound__lastTimeOnGround + 1.
          let speed = -min(human_net_phys.phys.currentState.velocity.y, human_net_phys.phys.previousState.velocity.y)
          if speed >= human_steps_sound__fallSpeedCollThreshold
            play_path("collision_fall", sound_paths, sound_tags, is_watched_sound, transform[3])
            return

      if !empty(name)
        let desc = sound_player_common::get_desc(human_steps_sound__descs, name)
        if desc != null
          play_footstep(*desc,
                        human_steps_sound__path,
                        sound_tags,
                        get_volume(is_watched_sound, team, human_steps_sound__friendVolume),
                        eid,
                        transform[3],
                        false,
                        is_watched_sound,
                        human_steps_sound__traceStepOffsetLen,
                        sound_landmesh_queries__biomePhysMatId,
                        sound_landmesh_queries__biomeOverridesWater,
                        sound_landmesh_queries__puddleDepth,
                        human_steps_sound__smid,
                        human_steps_sound__waterDepth,
                        human_net_phys)



[es(tag=sound, on_appear)]
def human_steps_sound_on_appear(evt : Event;
                                human_steps_sound__tag : string;
                                var sound_tags : Object&)
  raise_sound_tag(human_steps_sound__tag, sound_tags)
