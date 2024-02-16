module team_narrator_common shared
require ecs
require ecs.safe
require app
require soundEvent


def private need_cooldown(cooldown : float; phrase : string; is_ally, has_path : bool; team_narrator__history : Object)
  if cooldown > 0.
    let key = is_ally || !has_path ? phrase : "{phrase}_enemy"
    let lastTime = get_float(team_narrator__history[key]) ?? -1.
    return lastTime >= 0. && get_sync_time() < lastTime + cooldown
  return false


def private add_to_history(phrase : string; is_ally, has_path : bool; var team_narrator__history : Object&)
  let key = is_ally || !has_path ? phrase : "{phrase}_enemy"
  team_narrator__history |> set(key, get_sync_time())


def start_narrator_impl(phrase : string;
                        is_ally : bool;
                        team__narrator : Object;
                        var team_narrator__history : Object&;
                        var team_narrator__event : SoundEvent&)
  let obj = team__narrator[phrase] ?as Object
  if obj != null
    let hasPath = has(*obj, "path")
    let path = hasPath ? (*obj).path ?? "" : get_string(*obj, is_ally ? "ally" : "enemy", "")
    if !empty(path)
      add_to_history(phrase, is_ally, hasPath, team_narrator__history)
      release(team_narrator__event.handle)
      team_narrator__event |> play(path)


def start_narrator(phrase : string;
                   is_ally : bool;
                   replace : bool;
                   team_id : int;
                   var team_narrator__event : SoundEvent&;
                   var team_narrator__queue : Array&;
                   var team_narrator__history : Object&)

  find_query() <| $ [es] (team__id : int; team__narrator : Object)
    if team__id != team_id
      return false
    let obj = team__narrator[phrase] ?as Object
    if obj == null
      return true
    if need_cooldown((*obj).cooldown ?? 0., phrase, is_ally, has(*obj, "path"), team_narrator__history)
      return true

    if replace
      release(team_narrator__event.handle)
      team_narrator__queue |> clear()

    if length(team_narrator__queue) == 0 && team_narrator__event.handle == invalid_sound_event_handle()
      start_narrator_impl(phrase, is_ally, team__narrator, team_narrator__history, team_narrator__event)
    else
      using() <| $(var item : Object)
        item |> set("phrase", phrase)
        item |> set("isAlly", is_ally)
        item |> set("teamId", team_id)
        team_narrator__queue |> push(item)

    return true
