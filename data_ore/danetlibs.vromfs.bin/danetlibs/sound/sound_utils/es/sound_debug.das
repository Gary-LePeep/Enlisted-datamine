options no_aot
require ecs
require ecs.safe
require ecs.common
require soundSystem
require soundEvent
require DagorSystem
require DagorDebug3D
require DagorConsole
require math.color
require math.base
require strings


[es(no_order, tag=sound, on_event=EventSoundDrawDebug, REQUIRE=soundDebugDrawTemplate)]
def sound_debug_draw_template(evt : Event;
                              eid : EntityId;
                              transform : float3x4)
  add_debug_text_mark(transform[3], "{eid}={getEntityTemplateName(eid)}", -1, 0., E3DCOLOR(0xFFFFFFFF))


[es(no_order, tag=sound, on_event=EventSoundDrawDebug, REQUIRE=msg_sink)]
def sound_debug_draw_visual_labels(evt : Event)
  query_visual_labels() <| $(labels : array<VisualLabel>#)
    for it in labels
      add_debug_text_mark(it.pos, "radius={it.radius} name={it.name}", -1, 0., E3DCOLOR(0xFFFF00FF))


[es(no_order, tag=sound, on_event=EventSoundDrawDebug)]
def sound_debug_draw(evt : Event;
                     is_watched_sound : bool = false;
                     sound_tags : Object const?;
                     sound_event_group : SoundEventGroup const?;
                     human_voice_effect__activeEffects : Object const?;
                     [[shared_comp]] human_voice_effect__allOrderedEffects : StringList const?;
                     sound_control__allowSound : bool = true;
                     sound_control__inRange : bool = true;
                     sound_control__soundEnabled : bool = true;
                     transform : float3x4)

  if !sound_control__inRange
    return

  var text = ""
  if !sound_control__allowSound
    text += "sound disallowed"
  elif !sound_control__soundEnabled
    text += "sound disabled"

  if human_voice_effect__allOrderedEffects != null && human_voice_effect__activeEffects != null

    var numEffects = 0
    for id in *human_voice_effect__allOrderedEffects
      if (*human_voice_effect__activeEffects)[string(id)] ?? false
        if numEffects == 0
          text += "voice effects: [{id}"
        else
          text += ", {id}"
        ++numEffects
    if numEffects > 0
      text += "] "

    for itFx in *human_voice_effect__activeEffects
      var exist = false
      for id in *human_voice_effect__allOrderedEffects
        exist ||= itFx.key == id
      if !exist
        text += "-'{itFx.key}' is MISSING in human_voice_effect__allOrderedEffects-"

  if sound_tags != null && (is_watched_sound || length(*sound_tags) > 0)
    text += "sound tags:{*sound_tags} "

  if sound_event_group != null && (is_watched_sound || get_num_sounds(*sound_event_group) > 0)
    text += "sound group:{get_num_sounds(*sound_event_group)} "

  if !empty(text)
    let color = is_watched_sound ? E3DCOLOR(0xFF0000FF) : E3DCOLOR(0xFF000000)
    let pos = transform[3] + float3(0., 0.5, 0.)
    add_debug_text_mark(pos, text, -1, 0., color)



[console_cmd(name="sndsys.preset_enable")]
def sound_debug_console_sndsys_preset_enable(name : string; enable : bool)
  sound_banks_enable_preset(name, enable)


[console_cmd(name="sound.play")]
def sound_debug_console_sound_play(path : string; duration = 5.)
  var handle = soundEvent::play("", path, get_listener_pos())
  if handle != invalid_sound_event_handle()
    sound_debug("sound.play '{path}' is3d={is_3d(handle)}; maxRange={get_max_distance(handle)}; isOneshot={is_oneshot(handle)}")
  if is_oneshot(handle)
    abandon(handle)
  else
    abandon(handle, duration)


[console_cmd(name="sound.enum_events")]
def sound_debug_console_enum_events()
  sound_debug_enum_events()
