require ecs
require game.es.game_effect_macro
require common_shooter.es.grenade_thrower_common
require enlisted.events_enlisted


[es_game_effect(bool_flag=grenade_rethrow__isLocked, tag=grenade_rethrow__lockGrenadeRethrowing)]
def grenade_rethrow_lock_rethrowing_by_affect() { pass; }


[es(tag=gameClient, REQUIRE=hero)]
def grenade_rethrow_find_grenade_on_update(info : ParallelUpdateFrameDelayed;
                                           eid : EntityId;
                                           grenade_rethrow__isLocked : bool = false;
                                           var grenade_rethrow__grenadeEid : EntityId&)
  if grenade_rethrow__isLocked
    grenade_rethrow__grenadeEid = INVALID_ENTITY_ID
    return

  grenade_rethrow__grenadeEid = find_rethrowable_grenade(eid)
