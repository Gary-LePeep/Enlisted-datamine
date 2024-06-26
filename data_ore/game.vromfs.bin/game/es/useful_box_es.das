require ecs
require DngNet
require game.es.action_common
require game.es.events
require game.events_game
require game.utils.team
require enlisted.events_enlisted

[es(tag=server, on_appear)]
def init_useful_box_refill_count_es(evt : Event; useful_box__maxUseCount : int; var useful_box__useCount : int&)
  useful_box__useCount = useful_box__maxUseCount

[es(tag=server, REQUIRE_NOT=(paid_box__ressuplyCost, paid_loot__cost))]
def useful_box_use_request_es(evt : CmdUse;
                              eid : EntityId;
                              useful_box__useCount : int;
                              useful_box__hintEnemy : string;
                              team : int;
                              useful_box__anyTeam : Tag const?)
  let requester = evt.requesterEid
  if !requester || useful_box__useCount <= 0
    return

  let ownedByTeam = team
  var isValidTeam = false
  query(requester) <| $ [es] (team : int)
    isValidTeam = useful_box__anyTeam != null || is_teams_friendly(team, ownedByTeam)

  if !isValidTeam
    sendEvent(requester, [[CmdHeroLogEvent event="enemy_crate", text=useful_box__hintEnemy]])
    return

  sendEvent(eid, [[CmdUseUsefulBox requesterEid=requester]])

[es(tag=server)]
def useful_box_use_finish_es(evt : CmdUseUsefulBox;
                             eid : EntityId;
                             var useful_box__requiredUseCount : int&;
                             var useful_box__useCount : int&;
                             var useful_box__successUse : bool&)
  if !useful_box__successUse
    return
  useful_box__useCount -= useful_box__requiredUseCount
  useful_box__requiredUseCount = 0
  useful_box__successUse = false
  send_net_event(evt.requesterEid, [[CmdUsefulBoxCompleteUse box=eid]])
  sendEvent(eid, [[EventOnUsefulBoxSuccessfulUse requester=evt.requesterEid]])

[es(tag=gameClient, track=useful_box__useCount)]
def destroy_markers_for_empty_box(evt : Event; useful_box__useCount : int; var minimap__visibleForAll : bool&)
  if useful_box__useCount <= 0
    minimap__visibleForAll = false

[es(tag=gameClient, track=useful_box__useCount)]
def apply_amimvars_for_empty_box_es(evt : Event; eid : ecs::EntityId; useful_box__useCount : int)
  if useful_box__useCount <= 0
    sendEvent(eid, [[EventApplyCustomAnimcharVars]])

[es(tag=gameClient, on_event=CmdUsefulBoxCompleteUse, REQUIRE=human)]
def useful_box_play_complete_animation_es(evt : Event; eid : EntityId)
  run_action(eid, "pickup")

[es(tag=server, track=useful_box__useCount, REQUIRE=useful_box__destroyEmpty)]
def destroy_useful_box_on_no_uses_left(evt : Event;
                                       eid : EntityId;
                                       useful_box__useCount : int)
  if useful_box__useCount <= 0
    destroyEntity(eid)
