module human_sounds_events shared
require ecs

[event(unicast)]
struct CmdClientHumanSpeech
  phrase : string

[event(unicast)]
struct CmdHumanVoiceEffect
  phrase : string
