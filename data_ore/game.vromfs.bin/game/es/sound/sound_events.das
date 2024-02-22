module sound_events shared
require ecs

[cpp_event(unicast)]
struct CmdSoundMeleeIrq
  irq : string
