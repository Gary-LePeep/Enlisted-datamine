require ecs
require game.events_game


[es(on_appear, track=game_effect__attachedTo)]
def game_effect_attached_es(evt : Event; eid, game_effect__attachedTo : EntityId; var game_effect__lastAttachedTo : EntityId&)
  if game_effect__attachedTo != INVALID_ENTITY_ID
    game_effect__lastAttachedTo = game_effect__attachedTo
    sendEventImmediate(eid, [[GameEffectStateChanged attachedTo=game_effect__attachedTo, activated=true]])


[es(track=game_effect__attachedTo)]
def game_effect_detached_es(evt : Event; eid, game_effect__attachedTo : EntityId; var game_effect__lastAttachedTo : EntityId&)
  if !game_effect__attachedTo && game_effect__lastAttachedTo != INVALID_ENTITY_ID
    sendEventImmediate(eid, [[GameEffectStateChanged attachedTo=game_effect__lastAttachedTo, activated=false]])
    game_effect__lastAttachedTo = INVALID_ENTITY_ID


[es(on_disappear)]
def game_effect_destroyed_es(evt : Event; eid, game_effect__attachedTo : EntityId)
  sendEventImmediate(eid, [[GameEffectStateChanged attachedTo=game_effect__attachedTo, activated=false]])


[es(on_event=EventEntityRecreated)]
def game_effect_recreated_es(evt : Event; eid, game_effect__attachedTo : EntityId; var game_effect__lastAttachedTo : EntityId&)
  if game_effect__attachedTo != INVALID_ENTITY_ID
    sendEventImmediate(eid, [[GameEffectStateChanged attachedTo=game_effect__attachedTo, activated=true]])
  if game_effect__attachedTo != game_effect__lastAttachedTo && game_effect__lastAttachedTo != INVALID_ENTITY_ID
    sendEventImmediate(eid, [[GameEffectStateChanged attachedTo=game_effect__lastAttachedTo, activated=false]])
    game_effect__lastAttachedTo = game_effect__attachedTo
