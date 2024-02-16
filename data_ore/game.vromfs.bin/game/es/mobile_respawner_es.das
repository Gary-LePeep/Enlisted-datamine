require ecs
require game.es.respawn_base_common
require DagorSystem
require enlisted.events_enlisted
require enlisted.game.es.fortifications_build_common
require game.events_game
require player
require game.es.vehicle.vehicle_events
require math.base
require game.es.vehicle.vehicle_seats_common
require game.es.battle_area_common
require game.es.awards_common
require app


[es(tag=server, REQUIRE_NOT=deadEntity)]
def mobile_respawn_update_active_state(info : ParallelUpdateFrameDelayed;
                                       transform aka mob_spawn_transform : float3x4;
                                       eid : EntityId;
                                       isAlive : bool;
                                       vehicle__isUnderwater : bool;
                                       repairable__extinguishRequired : bool;
                                       mobile_respawn__nextSpawnTimer : float;
                                       team : int;
                                       var mobile_respawn__capturePointsCheckTime : float&;
                                       mobile_respawn__occupiedSeats : int;
                                       mobile_respawn__capturePointsCheckInterval : float;
                                       mobile_respawn__minDistanceToCapturePoint : float;
                                       var active : bool&;
                                       ownedByPlayer : EntityId;
                                       lastOffender : EntityId = INVALID_ENTITY_ID;
                                       last_offender__gunPropsId : int = -1;
                                       last_offender__shellId : int = -1)
  if mobile_respawn__capturePointsCheckTime < info.curTime
    active = true
    mobile_respawn__capturePointsCheckTime = info.curTime + mobile_respawn__capturePointsCheckInterval
    let isOutsideBattleArea = is_tm_outside_battle_area(transform, team)
    if isOutsideBattleArea
      if !is_vehicle_with_crew(eid) && !!ownedByPlayer
        sendEvent(eid, [[CmdExplosionFatal offender=lastOffender, gunPropsId=last_offender__gunPropsId, shellId=last_offender__shellId]])
        return
    let distSq = square(mobile_respawn__minDistanceToCapturePoint)
    let isCloseToCapzone = find_query() <| $ [es(REQUIRE=capzone)] (transform aka capzone_transform : float3x4; active : bool)
      return active && distance_sq(capzone_transform[3], mob_spawn_transform[3]) < distSq
    active = (!isCloseToCapzone && !isOutsideBattleArea && mobile_respawn__occupiedSeats == 0 &&
      info.curTime > mobile_respawn__nextSpawnTimer && isAlive && !vehicle__isUnderwater && !repairable__extinguishRequired)

[es(REQUIRE_NOT=deadEntity)]
def mobile_respawn_check_seats(evt : EventOnSeatOwnersChanged;
                               vehicle_seats__seatEids : EidList;
                               ownedBySquad : EntityId;
                               var mobile_respawn__occupiedSeats : int&)
  mobile_respawn__occupiedSeats = 0
  for seatEid in vehicle_seats__seatEids
    query(seatEid) <| $ [es] (seat__squadEid : EntityId; seat__isOwnerAlive : bool)
      if seat__isOwnerAlive && !!seat__squadEid && seat__squadEid != ownedBySquad
        mobile_respawn__occupiedSeats += 1

[es(tag=server, on_appear, REQUIRE=mobileRespawnTag)]
def set_respawn_group_to_mobile_respawn(evt : Event; var respawnBaseGroup : int&; team : int)
  respawnBaseGroup = get_new_respawn_group(team)

[es(tag=server, on_appear)]
def attach_mobile_respawn_icon(evt : Event;
                               selectedGroup : int;
                               eid aka icon_eid : EntityId&;
                               var mobile_respawn_point_selector__mobileRespawnEid : EntityId&)
  find_query() <| $ [es] (var mobile_respawn__respawnIconEid : EntityId&; respawnBaseGroup : int; eid aka respawn_eid : EntityId)
    if selectedGroup == respawnBaseGroup
      mobile_respawn__respawnIconEid = icon_eid
      mobile_respawn_point_selector__mobileRespawnEid = respawn_eid
      return true
    return false

[es(tag=gameClient, track=repairable__extinguishRequired)]
def mobile_respawn_is_on_fire_track(evt : Event; repairable__extinguishRequired : bool; mobile_respawn__respawnIconEid : EntityId)
  query(mobile_respawn__respawnIconEid) <| $ [es] (var respawn_icon__additionalInfo : das_string&)
    respawn_icon__additionalInfo := repairable__extinguishRequired ? "respawn/is_onfire" : ""

[es(tag=gameClient, REQUIRE_NOT=deadEntity)]
def update_mobile_respawn_icon(info : ParallelUpdateFrameDelayed;
                               team aka icon_team : int;
                               var transform aka icon_transform : float3x4&;
                               var respawn_icon__active : bool&;
                               var respawn_icon__position : float3&;
                               var respawn_icon__isOccupied : bool&;
                               mobile_respawn_point_selector__mobileRespawnEid : EntityId)
  var exit = false
  query(get_local_player_eid()) <| $ [es] (respawner__enabled : bool; team aka player_team : int)
    exit = !respawner__enabled || player_team != icon_team
  if exit
    return
  query(mobile_respawn_point_selector__mobileRespawnEid) <| $ [es] (transform aka vehicle_transform : float3x4;
                                                                    mobile_respawn__reservedPlayerEid : EntityId;
                                                                    mobile_respawn__occupiedSeats : int;
                                                                    active : bool)
    icon_transform[3] = vehicle_transform[3]
    respawn_icon__position = icon_transform[3]
    if (!!mobile_respawn__reservedPlayerEid && get_local_player_eid() != mobile_respawn__reservedPlayerEid) || mobile_respawn__occupiedSeats != 0
      respawn_icon__active = false
      respawn_icon__isOccupied = true
    else
      respawn_icon__active = active
      respawn_icon__isOccupied = false

[es(tag=server, track=disconnected)]
def free_mobile_respawn_on_player_disconnect(evt : Event; disconnected : bool; eid : EntityId; var respawner__mobileRespawnEid : EntityId&)
  if !!respawner__mobileRespawnEid && disconnected
    respawner__mobileRespawnEid = INVALID_ENTITY_ID
    query(respawner__mobileRespawnEid) <| $ [es] (var mobile_respawn__reservedPlayerEid : EntityId&)
      if eid == mobile_respawn__reservedPlayerEid
        mobile_respawn__reservedPlayerEid = INVALID_ENTITY_ID

[es(tag=gameClient, track=mobile_respawn__reservedPlayerEid)]
def control_local_player_mobile_respawn_reservation(evt : Event; mobile_respawn__reservedPlayerEid : EntityId; respawnBaseGroup : int)
  if !mobile_respawn__reservedPlayerEid
    return
  let locPlayer = get_local_player_eid()
  query(locPlayer) <| $ [es] (var respawner__respawnGroupId : int&)
    if respawnBaseGroup == respawner__respawnGroupId && locPlayer != mobile_respawn__reservedPlayerEid
      respawner__respawnGroupId = -1

[es(tag=gameClient, on_appear)]
def make_seat_non_placeable_for_non_onwer_on_local(evt : Event;
                                                   seat__vehicleEid : EntityId;
                                                   seats_order__canPlaceOnlyOwner : bool;
                                                   var seats_order__canPlaceManually : bool&)
  if seats_order__canPlaceOnlyOwner
    query(seat__vehicleEid) <| $ [es] (ownedBySquad : EntityId)
      let localPlayerSquad = get_Eid(get_local_player_eid(), "respawner__squad") ?? INVALID_ENTITY_ID
      seats_order__canPlaceManually = (localPlayerSquad == ownedBySquad)
      sendEvent(seat__vehicleEid, [[EventOnSeatOwnersChanged]])

[es(tag=server, on_appear, REQUIRE=deadEntity)]
def destroy_mobile_spawn_icon_on_spawn_death(evt : Event;
                                             var active : bool&;
                                             mobile_respawn__respawnIconEid : EntityId)
  active = false
  destroyEntity(mobile_respawn__respawnIconEid)

[es(tag=gameClient, REQUIRE=hero)]
def check_is_capzones_close_to_mobile_respawn(info : ParallelUpdateFrameDelayed;
                                              human_anim__vehicleSelected : EntityId;
                                              var human_vehicle__isMobileSpawnDriverCloseToCapturePoint : bool&)
  human_vehicle__isMobileSpawnDriverCloseToCapturePoint = false
  query(human_anim__vehicleSelected) <| $ [es] (mobile_respawn__minDistanceToCapturePoint : float;
                                                transform aka vehicle_transform : float3x4)
    query() <| $ [es] (active : bool; var capzone__isNearToMobileRespawn : bool&; transform aka capzone_transform : float3x4)
      if !active
        return
      let distSq = square(mobile_respawn__minDistanceToCapturePoint)
      capzone__isNearToMobileRespawn = distance_sq(vehicle_transform[3], capzone_transform[3]) < distSq
      if capzone__isNearToMobileRespawn
        human_vehicle__isMobileSpawnDriverCloseToCapturePoint = true

[es(tag=ui)]
def mobile_spawn_icon_cooldawn_counter(info : ParallelUpdateFrameDelayed;
                                       team : int;
                                       mobile_respawn__nextSpawnTimer : float;
                                       mobile_respawn__respawnIconEid : EntityId)
  if get_int(get_local_player_eid(), "team") ?? TEAM_UNASSIGNED != team || mobile_respawn__nextSpawnTimer < info.curTime
    return
  query(mobile_respawn__respawnIconEid) <| $ [es] (var respawn_icon__playersCount : int&)
    respawn_icon__playersCount = int(mobile_respawn__nextSpawnTimer - info.curTime)


[es(tag=server, on_appear, REQUIRE=mobileRespawnTag)]
def destroy_previous_player_mobile_respawn_on_new_appear(evt : Event;
                                                         eid aka new_spawn_eid : EntityId;
                                                         ownedByPlayer aka new_spawn_ownedByPlayer : EntityId;
                                                         mobile_respawn__capturePointsCheckInterval : float;
                                                         var mobile_respawn__capturePointsCheckTime : float&)
  mobile_respawn__capturePointsCheckTime = get_sync_time() + mobile_respawn__capturePointsCheckInterval
  find_query() <| $ [es(REQUIRE=mobileRespawnTag, REQUIRE_NOT=deadEntity)] (eid aka old_spawn_eid : EntityId;
                                                                            ownedByPlayer aka old_spawn_ownedByPlayer : EntityId;
                                                                            vehicle_seats__seatEids : EidList;
                                                                            lastOffender : EntityId = INVALID_ENTITY_ID;
                                                                            last_offender__gunPropsId : int = -1;
                                                                            last_offender__shellId : int = -1)
    if old_spawn_eid != new_spawn_eid && new_spawn_ownedByPlayer == old_spawn_ownedByPlayer && !!new_spawn_ownedByPlayer
      kick_all_from_vehicle(old_spawn_eid, vehicle_seats__seatEids)
      sendEvent(old_spawn_eid, [[CmdExplosionFatal offender=lastOffender, gunPropsId=last_offender__gunPropsId, shellId=last_offender__shellId]])
      return true
    return false

[es(tag=server, on_appear)]
def create_apc_respawn_on_motorcycle_respawn(evt : Event;
                                             team : int;
                                             active : bool;
                                             groupName : string;
                                             respawnbaseType : das_string;
                                             respawnBaseGroup : int;
                                             transform : float3x4)
  if respawnbaseType == "motorcycle"
    createEntity("respawnChooser+respAPC") <| $(var init : ComponentsInitializer)
      set(init, "transform", transform)
      set(init, "team", team)
      set(init, "active", active)
      set(init, "groupName", groupName)
      set(init, "respawnBaseGroup", respawnBaseGroup)


[es(tag=server, on_appear)]
def mobile_spawn_uses_award(evt : Event;
                            squad__respawnBaseEid : EntityId;
                            squad__ownerPlayer : EntityId)
  query(squad__respawnBaseEid) <| $ [es] (ownedByPlayer : EntityId; mobile_respawn__lastDriverGuid : string)
    if squad__ownerPlayer != ownedByPlayer
      add_award(ownedByPlayer, "owned_mobile_spawn_usage")
      send_award_stat(ownedByPlayer, mobile_respawn__lastDriverGuid, "ownedMobileSpawnUses")

[es(tag=server, track=seat__ownerEid, on_appear)]
def set_seat_last_driver_guid(evt : Event;
                              seat__ownerEid : EntityId;
                              seat__vehicleEid : EntityId;
                              seats_order__canPlaceOnlyOwner : bool)
  if !seats_order__canPlaceOnlyOwner
    return
  query(seat__vehicleEid) <| $ [es] (ownedBySquad : EntityId; var mobile_respawn__lastDriverGuid : das_string&)
    query(seat__ownerEid) <| $ [es] (squad_member__squad : EntityId; guid : string)
      if squad_member__squad == ownedBySquad
        mobile_respawn__lastDriverGuid := guid
