require ecs
require soundEvent

[es(tag=sound, track=sound_control__soundEnabled)]
def loudspeaker_sound_track(evt : Event;
                            sound_control__soundEnabled : bool;
                            loudspeaker_sound__path : string;
                            var loudspeaker_sound__event : SoundEvent&;
                            transform : float3x4)
  release(loudspeaker_sound__event.handle)
  if sound_control__soundEnabled
    loudspeaker_sound__event |> play(loudspeaker_sound__path, transform[3])
