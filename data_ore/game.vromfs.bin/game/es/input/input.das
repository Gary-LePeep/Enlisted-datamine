require ecs
require DagorInput
require enlisted.events_enlisted


[es(tag=input)]
def input_on_reset_digital_action_sticky_toggle(evt : CmdResetDigitalActionStickyToggle)
  reset_digital_action_sticky_toggle(evt.action)
