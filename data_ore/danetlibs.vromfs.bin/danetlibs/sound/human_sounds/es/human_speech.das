require ecs
require ecs.safe
require app
require soundSystem
require soundEvent
require player
require human_sounds.modules.human_sounds_events
require human_sounds_net.modules.human_sounds_net_events
require sound_utils_net.modules.sound_desc_common
require sound_utils.modules.sound_player_common
require strings


let SPEECH_WATCHED_VOLUME = 1.5
let SPEECH_TEAM_VOLUME = 1.5
let SPEECH_MAX_NET_DELAY = 4.
let SPEECH_DEF_MAX_DISTANCE = 50.
let SPEECH_IGNORE_MAX_DISTANCE_VALUE = -1.


def get_enemy_voice(voice_id : int; voices : StringList)
  if length(voices) == 0 || voice_id < 0
    return ""
  return string(voices[voice_id % int(length(voices))])


def is_player_team(team : int)
  return team != TEAM_UNASSIGNED && (get_int(get_local_player_eid(), "team") ?? TEAM_UNASSIGNED) == team

def is_hardcore_mode()
  return find_query() <| $ [es(REQUIRE=noBotsMode)] () { return true; }

def start_speech(phrase_idx : int;
                 human_speech__canSpeak : bool;
                 human_speech__playerVoice : string;
                 human_speech__enemyVoices : StringList;
                 human_speech__locale : string;
                 human_speech__voiceIdx : int;
                 [[shared_comp]] human_speech__speeches : Array;
                 is_watched_sound : bool;
                 var human_speech__event : SoundEvent&;
                 transform : float3x4;
                 team : int = TEAM_UNASSIGNED)
  if !human_speech__canSpeak || uint(phrase_idx) >= uint(human_speech__speeches.size)
    return
  let desc = human_speech__speeches[phrase_idx] as Object
  if desc == null
    return

  let isWatchedSound = is_watched_sound || (desc?.treatAsWatched ?? false)

  let hardcoreModeMaxDist = desc?.hardcoreModeMaxDist ?? SPEECH_IGNORE_MAX_DISTANCE_VALUE
  if hardcoreModeMaxDist != SPEECH_IGNORE_MAX_DISTANCE_VALUE
    if is_hardcore_mode() && !should_play(transform[3], hardcoreModeMaxDist)
      return
  elif !isWatchedSound && !should_play(transform[3], desc?.maxDist ?? SPEECH_DEF_MAX_DISTANCE)
    return

  if !(desc?.replace ?? false) && is_playing(human_speech__event.handle)
    return

  release(human_speech__event.handle)
  let path = isWatchedSound ? human_speech__playerVoice : get_enemy_voice(human_speech__voiceIdx, human_speech__enemyVoices)
  if empty(human_speech__locale)
    human_speech__event.handle = sound_player_common::play_desc_path(*desc, path, transform[3], false)
  else
    human_speech__event.handle = sound_player_common::play_desc_path(*desc, "{path}/{human_speech__locale}", transform[3], false)

  if isWatchedSound
    set_volume(human_speech__event.handle, SPEECH_WATCHED_VOLUME)
  elif is_player_team(team)
    set_volume(human_speech__event.handle, SPEECH_TEAM_VOLUME)


[es(tag=sound)]
def human_speech_cmd(evt : CmdNetHumanSpeech;
                     human_speech__canSpeak : bool;
                     human_speech__playerVoice : string;
                     human_speech__enemyVoices : StringList;
                     human_speech__locale : string;
                     human_speech__voiceIdx : int;
                     [[shared_comp]] human_speech__speeches : Array;
                     is_watched_sound : bool;
                     var human_speech__event : SoundEvent&;
                     transform : float3x4;
                     team : int = TEAM_UNASSIGNED)
  if get_sync_time() < evt.time + SPEECH_MAX_NET_DELAY
    start_speech(evt.phraseIdx,
                 human_speech__canSpeak,
                 human_speech__playerVoice,
                 human_speech__enemyVoices,
                 human_speech__locale,
                 human_speech__voiceIdx,
                 human_speech__speeches,
                 is_watched_sound,
                 human_speech__event,
                 transform,
                 team)


[es(tag=sound)]
def human_speech_cmd_hero_speech(evt : CmdClientHumanSpeech;
                                 human_speech__canSpeak : bool;
                                 human_speech__playerVoice : string;
                                 human_speech__enemyVoices : StringList;
                                 human_speech__locale : string;
                                 human_speech__voiceIdx : int;
                                 [[shared_comp]] human_speech__speeches : Array;
                                 is_watched_sound : bool;
                                 var human_speech__event : SoundEvent&;
                                 transform : float3x4;
                                 team : int = TEAM_UNASSIGNED)
  let phraseIdx = find_desc_idx(evt.phrase, human_speech__speeches)
  if phraseIdx >= 0
    start_speech(phraseIdx,
                 human_speech__canSpeak,
                 human_speech__playerVoice,
                 human_speech__enemyVoices,
                 human_speech__locale,
                 human_speech__voiceIdx,
                 human_speech__speeches,
                 is_watched_sound,
                 human_speech__event,
                 transform,
                 team)
  else
    sound_debug("There is no human speech desc for phrase '{evt.phrase}'")


[es(tag=sound, on_appear, track=human_voice_effect__isActive, REQUIRE_NOT=humanSpeechDisable)]
def human_speech_can_speak(evt : Event;
                           human_voice_effect__isActive : bool = false;
                           var human_speech__canSpeak : bool&;
                           var human_speech__event : SoundEvent&)
  human_speech__canSpeak = !human_voice_effect__isActive
  if !human_speech__canSpeak
    release(human_speech__event.handle)


[es(tag=sound, on_appear)]
def human_speech_on_appear(evt : Event;
                           human_speech__enemyVoices : StringList;
                           var human_speech__voiceIdx : int&;
                           squad_member__memberIdx : int;
                           var sound_tags : Object&)
  human_speech__voiceIdx = max(0, squad_member__memberIdx) % max(1, length(human_speech__enemyVoices))
  if (human_speech__voiceIdx % 3) == 1
    raise_sound_tag("voice0", sound_tags)
  elif (human_speech__voiceIdx % 3) == 2
    raise_sound_tag("voice1", sound_tags)


[es(tag=sound, on_disappear, REQUIRE=human_speech__canSpeak)]
def human_speech_disappear(evt : Event;
                           var human_speech__event : SoundEvent&)
  release(human_speech__event.handle)


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=sound_begin_update_es, before=sound_end_update_es)]
def human_speech_update(evt : Event;
                        transform : float3x4;
                        var human_speech__event : SoundEvent&;
                        var human_speech__isSpeaking : bool&)
  human_speech__isSpeaking = human_speech__event.handle != invalid_sound_event_handle()
  if human_speech__isSpeaking
    if is_playing(human_speech__event.handle)
      set_pos(human_speech__event.handle, transform[3])
      return
    release(human_speech__event.handle)
    human_speech__isSpeaking = false
