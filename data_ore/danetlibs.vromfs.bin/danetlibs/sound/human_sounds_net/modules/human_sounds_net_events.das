module human_sounds_net_events shared
require ecs


[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdNetHumanSpeech
  phraseIdx : int
  time : float

[cpp_event(unicast)] // server
struct CmdRequestHumanSpeech
  phrase : string


[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdNetHumanVoiceEffect
  phrase : string
  time : float

[cpp_event(unicast)] // server
struct CmdRequestHumanVoiceEffect
  phrase : string
