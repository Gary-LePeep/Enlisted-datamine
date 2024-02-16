module sound_utils shared

require ecs
require ecs.safe
require app
require game.utils.net_utils
require game.utils.team
require DngNet
require soundHash
require soundSystem
require sound_utils_net.modules.sound_utils_net_events


def private get_desc(name : string; descs : Object; should_exist : bool) : Object const?
  let desc = descs[name] ?as Object
  if should_exist && desc == null
    sound_debug("net_sound: sound '{name}' not found in net_sound.descs {descs}")
  return desc


def private is_valid(desc : Object const?)
  return desc != null && (has(*desc, "path") || has(*desc, "hero") || has(*desc, "enemy"))


def play_net_sound_pos(target : EntityId; name : string; pos : float3; filter_possessd : bool = false; should_exist : bool = true)
  query(target) <| $ [es] ([[shared_comp]] net_sound__descs : Object)
    let desc = get_desc(name, net_sound__descs, should_exist)
    if is_valid(desc)
      let maxRange : float = (*desc)["range"] ?? 0.f
      send_net_event(target, [[CmdPlayNetSoundPos hash=sound_hash(name), pos=pos, time=get_sync_time()]],
        enum_connections_range_team(pos, maxRange, TEAM_UNASSIGNED, filter_possessd, target))


def play_net_sound_pos_to_team(target : EntityId; name : string; pos : float3; filter_possessd : bool = false; should_exist : bool = true)
  query(target) <| $ [es] ([[shared_comp]] net_sound__descs : Object; team = TEAM_UNASSIGNED)
    let desc = get_desc(name, net_sound__descs, should_exist)
    if is_valid(desc)
      let maxRange : float = (*desc)["range"] ?? 0.f
      if team != TEAM_UNASSIGNED
        send_net_event(target, [[CmdPlayNetSoundPos hash=sound_hash(name), pos=pos, time=get_sync_time()]],
          enum_connections_range_team(pos, maxRange, team, filter_possessd, target))
      else
        send_net_event(target, [[CmdPlayNetSoundPos hash=sound_hash(name), pos=pos, time=get_sync_time()]],
          target_entity_conn(target))


def play_net_sound_pos_to_target(target : EntityId; name : string; pos : float3; should_exist : bool = true)
  query(target) <| $ [es] ([[shared_comp]] net_sound__descs : Object)
    let desc = get_desc(name, net_sound__descs, should_exist)
    if is_valid(desc)
      let maxRange : float = *desc |> get_float("range") ?? 20.
      if maxRange > 0.
        send_net_event(target, [[CmdPlayNetSoundPos hash=sound_hash(name), pos=pos, time=get_sync_time()]],
          enum_connections_range_team(pos, maxRange, TEAM_UNASSIGNED, false/*filter_possessd*/, target))
      send_net_event(target, [[CmdPlayNetSoundPos hash=sound_hash(name), pos=pos, time=get_sync_time()]],
        target_entity_conn(target))


def play_net_sound(target : EntityId; name : string; param : float = 0.; filter_possessd : bool = false; should_exist : bool = true)
  query(target) <| $ [es] ([[shared_comp]] net_sound__descs : Object; transform : float3x4)
    let desc = get_desc(name, net_sound__descs, should_exist)
    if is_valid(desc)
      let maxRange : float = (*desc)["range"] ?? 0.f
      send_net_event(target, [[CmdPlayNetSound hash=sound_hash(name), param=param, time=get_sync_time()]],
        enum_connections_range_team(transform[3], maxRange, TEAM_UNASSIGNED, filter_possessd, target))


def play_net_sound_to_target(target : EntityId; name : string; should_exist : bool = true)
  query(target) <| $ [es] ([[shared_comp]] net_sound__descs : Object)
    let desc = get_desc(name, net_sound__descs, should_exist)
    if is_valid(desc)
      let maxRange : float = *desc |> get_float("range") ?? 20.
      if maxRange > 0.
        send_net_event(target, [[CmdPlayNetSound hash=sound_hash(name), param=0., time=get_sync_time()]],
          target_entity_pos_range(target, maxRange))
      else
        send_net_event(target, [[CmdPlayNetSound hash=sound_hash(name), param=0., time=get_sync_time()]],
          target_entity_conn(target))


def play_scene_net_sound(name : string; pos : float3; should_exist : bool = true)
  query() <| $ [es(REQUIRE=sceneNetSounds)] (eid : EntityId; [[shared_comp]] net_sound__descs : Object)
    let desc = get_desc(name, net_sound__descs, should_exist)
    if is_valid(desc)
      let maxRange : float = *desc |> get_float("range") ?? 100.
      send_net_event(eid, [[CmdPlayNetSoundPos hash=sound_hash(name), pos=pos, time=get_sync_time()]],
        enum_connections_range_team(pos, maxRange, TEAM_UNASSIGNED/*team_id*/, false/*filter_possessd*/, INVALID_ENTITY_ID/*except_possessed*/))


def play_net_sound_from_any_source_to_target(target : EntityId; name : string)
  var numSounds = 0
  query() <| $ [es(REQUIRE=anySourceNetSounds)] ([[shared_comp]] net_sound__descs : Object)
    if is_valid(get_desc(name, net_sound__descs, false))
      ++numSounds
      if numSounds == 1
        send_net_event(target, [[CmdPlayNetSoundFromAnySource hash=sound_hash(name), time=get_sync_time()]],
          target_entity_conn(target))
  if numSounds > 1
    sound_debug("net_sound: more than one sound with name '{name}' found")
  elif numSounds == 0
    sound_debug("net_sound: sound with name '{name}' not found")
