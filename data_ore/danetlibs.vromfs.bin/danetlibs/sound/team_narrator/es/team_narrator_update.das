require ecs
require ecs.safe
require soundEvent
require team_narrator.modules.team_narrator_common


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=sound_begin_update_es, before=sound_end_update_es)]
def team_narrator_update(evt : Event;
                         var team_narrator__event : SoundEvent&;
                         var team_narrator__queue : Array&;
                         var team_narrator__history : Object&)

  if team_narrator__event.handle != invalid_sound_event_handle() && !is_playing(team_narrator__event.handle)
    release(team_narrator__event.handle)

    if length(team_narrator__queue) > 0
      let obj = team_narrator__queue[0] as Object
      if obj != null
        let phrase = (*obj).phrase ?? ""
        let teamId = (*obj).teamId ?? -1
        let isAlly = (*obj).isAlly ?? false
        find_query() <| $ [es] (team__id : int; team__narrator : Object)
          if teamId == team__id
            start_narrator_impl(phrase, isAlly, team__narrator, team_narrator__history, team_narrator__event)
            return true
          return false
      erase(team_narrator__queue, 0)
