require ecs
require player
require ecs.common
require DngWalkerai
require enlisted.events_enlisted

def private write_member_data(var states : Object&; member_eid : EntityId)
  query(member_eid) <| $ [es] (squad_member__memberIdx : int;
                               isAlive : bool;
                               isDowned : bool;
                               hitpoints__hp : float;
                               hitpoints__maxHp : float;
                               walker_agent__currentAiAction : int = int(AiAction AI_ACTION_UNKNOWN);
                               beh_tree__enabled : bool = false;
                               guid : string;
                               name : string;
                               surname : string;
                               callname : string;
                               human_weap__weapTemplates : Object;
                               squad_member__kills : int;
                               hasFlask : bool = false;
                               total_kits__targetHeal : int = 0;
                               total_kits__targetRepair : int = 0;
                               total_kits__targetRevive : int = 0;
                               soldier__sKind : string;
                               soldier__displayedKind : string;
                               soldier__sClassRare : int;
                               squad_member__canBeLeader : bool = false;
                               squad_member__isPersonalOrder : bool = false;
                               squad_member_ui__grenadeTypes : StringList;
                               squad_member_ui__mineTypes : StringList)
    let eidKey = "{member_eid}"
    var state = getRW_ecs_object(states, eidKey)
    if state == null
      push_to_object(states, eidKey) <| $(var init : Object)
        init |> set("eid", member_eid)
      state = getRW_ecs_object(states, eidKey)
    *state |> set("eid", member_eid)
    *state |> set("guid", guid)
    *state |> set("name", name)
    *state |> set("surname", surname)
    *state |> set("callname", callname)
    *state |> set("isAlive", isAlive)
    *state |> set("isDowned", isDowned)
    *state |> set("hp", int(hitpoints__hp)) // round up to int to avoid frequent update in ui
    *state |> set("maxHp", int(hitpoints__maxHp))
    *state |> set("weapTemplates", human_weap__weapTemplates)
    *state |> set("memberIdx", squad_member__memberIdx)
    *state |> set("currentAiAction", walker_agent__currentAiAction)
    *state |> set("hasAI", beh_tree__enabled)
    *state |> set("kills", squad_member__kills)
    *state |> set("targetHealCount", total_kits__targetHeal)
    *state |> set("targetRepairCount", total_kits__targetRepair)
    *state |> set("hasFlask", hasFlask)
    *state |> set("targetReviveCount", total_kits__targetRevive)
    *state |> set("sKind", soldier__sKind)
    *state |> set("displayedKind", soldier__displayedKind)
    *state |> set("sClassRare", soldier__sClassRare)
    *state |> set("canBeLeader", squad_member__canBeLeader)
    *state |> set("isPersonalOrder", squad_member__isPersonalOrder)
    *state |> set("grenadeTypes", squad_member_ui__grenadeTypes)
    *state |> set("mineTypes", squad_member_ui__mineTypes)


[es(tag=ui, after=start_async_phys_sim_es)] // after start_async_phys_sim_es to start phys sim job earlier
def squad_members_ui_update_state(info : ParallelUpdateFrameDelayed)
  query(get_local_player_eid()) <| $ [es] (squad_members_ui__watchedSquadEid : EntityId;
                                           squad_members_ui__updateInterval : float;
                                           var squad_members_ui__nextUpdateAtTime : float&;
                                           var squad_members_ui__watchedSquadState : Object&)
    if squad_members_ui__nextUpdateAtTime > info.curTime
      return
    squad_members_ui__nextUpdateAtTime = info.curTime + squad_members_ui__updateInterval
    query(squad_members_ui__watchedSquadEid) <| $ [es] (squad__allMembers : EidList)
      for memberEid in squad__allMembers
        squad_members_ui__watchedSquadState |> write_member_data(memberEid)

[es(tag=ui, REQUIRE=watchedByPlr, before=squad_members_ui_update_state, on_appear)]
def squad_members_ui_track_watched_squad(evt : Event; squad_member__squad : EntityId)
  query(get_local_player_eid()) <| $ [es] (var squad_members_ui__watchedSquadEid : EntityId&; var squad_members_ui__watchedSquadState : Object&)
    if squad_members_ui__watchedSquadEid != squad_member__squad
      squad_members_ui__watchedSquadEid = squad_member__squad
      squad_members_ui__watchedSquadState |> clear()

[es(tag=ui, on_appear, track=squad__isAlive)]
def squad_members_ui_track_controlled_squad(evt : Event; eid : EntityId; squad__isAlive : bool; squad__ownerPlayer : EntityId)
  let localPlayerEid = get_local_player_eid()
  if squad__ownerPlayer == localPlayerEid
    query(localPlayerEid) <| $ [es] (var squad_members_ui__controlledSquadEid : EntityId&)
      if squad__isAlive
        squad_members_ui__controlledSquadEid = eid
      else
        squad_members_ui__controlledSquadEid = INVALID_ENTITY_ID
