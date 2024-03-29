require ecs
require app
require net
require strings
require DngNet
require CurrentCircuit
require rapidjson
require game.events_game
require enlisted.events_enlisted
require matching // INVALID_USER_ID

[es(tag=recordingReplay, on_appear, REQUIRE=human)]
def set_first_respawn_time_es(evt : Event)
  query() <| $ [es] (var replay__firstHumanSpawnTime : float&;
                     var replay__isFirstHumanSpawned : bool&)
    if !replay__isFirstHumanSpawned
      replay__isFirstHumanSpawned = true
      replay__firstHumanSpawnTime = get_sync_time()

[es(tag=recordingReplay)]
def replay_save_keyframe_es(evt : EventKeyFrameSaved; var replay__keyFrameTimes : IntList&)
  push(replay__keyFrameTimes, evt.time)

[es(tag=recordingReplay, on_event=EventLevelLoaded)]
def replay_recording_create_meta(evt : Event)
  createEntity("replay_meta_record") <| $(var init)
    init |> set("replay__startAt", get_sync_time())
    init |> set("mission__startTime", int64(get_clock()))

[es(tag=recordingReplay, on_event=EventTeamRoundResult)]
def replay_is_game_finished_es(evt : Event; var replay__isFinished : bool&)
  replay__isFinished = true

[es(tag=recordingReplay)]
def replay_write_meta_es(var evt : EventOnWriteReplayMetaInfo&)
  assume obj = evt.replayMeta
  SetObject(obj) <| $(var item : JsonValue)
    query() <| $ [es] (mission_name : string; mission_type : string; mission_outfit : string)
      item |> AddMember("mission_name", mission_name, obj)
      item |> AddMember("mission_type", mission_type, obj)
      item |> AddMember("mission_outfit", mission_outfit, obj)

    query() <| $ [es] (mission__startTime : int64;
                       replay__firstHumanSpawnTime : float;
                       replay__isFinished : bool;
                       replay__startAt : float;
                       replay__keyFrameTimes : IntList)
      item |> AddMember("start_timestamp", mission__startTime, obj)
      item |> AddMember("first_human_spawn_time", replay__firstHumanSpawnTime, obj)
      item |> AddMember("total_play_time", get_sync_time(), obj)
      item |> AddMember("replay__startAt", replay__startAt, obj)
      item |> AddMember("replay__isFinished", replay__isFinished, obj)
      using(JsonType kArrayType) <| $(var keyFrames : JsonValue)
        for time in replay__keyFrameTimes
          keyFrames |> PushBack(time, obj)
        item |> AddMember("keyFrames", keyFrames, obj)
    item |> AddMember("end_timestamp", int64(get_clock()), obj)
    item |> AddMember("session_id", get_session_id(), obj)

    item |> AddMember("circuit", get_circuit_name(), obj)
    item |> AddMember("game", get_game_name(), obj)
    item |> AddMember("exe_version", get_exe_version_str(), obj)
    item |> AddMember("protocol_version", int(NET_PROTO_VERSION), obj)
    item |> AddMember("dasevent_net_version", get_dasevent_net_version(), obj)

    get_matching_invite_data() |> FindMember("mode_info", JsonType kObjectType) <| $(mode_info)
      let digestGroup = mode_info |> json_get_or("digestGroup", "")
      if digestGroup != ""
        item |> AddMember("digestGroup", digestGroup, obj)

      let modId = mode_info |> json_get_or("modId", "")
      if modId != ""
        item |> AddMember("digestGroup", "mods-lobby", obj)
        item |> AddMember("modId", modId, obj)
        item |> AddMember("modVersion", json_get_or(mode_info, "modVersion", 1), obj)

      let modName = mode_info |> json_get_or("modName", "")
      if modName != ""
        item |> AddMember("mission_name", modName, obj)

      let difficulty = mode_info |> json_get_or("difficulty", "standard") // default(empty) is standard difficulty
      item |> AddMember("difficulty", difficulty, obj)

      let mode = mode_info |> json_get_or("mode", "SQUADS") // default(empty) is SQUADS mode
      item |> AddMember("mode", mode, obj)

    using(JsonType kArrayType) <| $(var players : JsonValue)
      query() <| $ [es(REQUIRE=player)] (team : int; name : string; userid : uint64; playerIsBot : Tag const?)
        using(JsonType kObjectType) <| $(var player : JsonValue)
          player |> AddMember("team", team, obj)
          // replace white spaces for hide bot player names from output
          player |> AddMember("name", replace(name, " ", ""), obj)
          if playerIsBot == null && userid != INVALID_USER_ID // do not send bot userid to meta
            player |> AddMember("userid", int64(userid), obj) // convert to signed for backend
          players |> PushBack(player, obj)
      item |> AddMember("players", players, obj)

  obj |> json_stringify_pretty() <| $(data)
    print("replay meta: {data}")
