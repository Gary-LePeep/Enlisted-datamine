require ecs
require game.es.events
require game.es.input.input_events
require DagorInput
require DngHuman


def init(var human_input__reload : int&;
         var human_input__quickReload : int&)
  human_input__reload = int(get_action_handle("Human.Reload", TYPEGRP_DIGITAL))
  human_input__quickReload = int(get_action_handle("Human.QuickReload", TYPEGRP_DIGITAL))


def reset(var human_input__reload : int&;
          var human_input__quickReload : int&)
  human_input__reload = int(BAD_ACTION_HANDLE)
  human_input__quickReload = int(BAD_ACTION_HANDLE)


[es(tag=input, on_appear)]
def human_reload_input_on_appear(evt : Event;
                                 var human_input__reload : int&;
                                 var human_input__quickReload : int&)
  init(human_input__reload, human_input__quickReload)


[es(tag=input)]
def human_reload_input_on_init(evt : EventDaInputInit;
                               var human_input__reload : int&;
                               var human_input__quickReload : int&)
  if evt.init
    init(human_input__reload, human_input__quickReload)
  else
    reset(human_input__reload, human_input__quickReload)


[es(tag=input)]
def human_reload_input_on_action_triggered(evt : EventDaInputActionTriggered;
                                           input__enabled : bool;
                                           human_input__reload : int;
                                           human_input__quickReload : int;
                                           var human_net_phys : HumanActor&)
  if !input__enabled
    return
  assume ct = human_net_phys.phys.producedCT

  if int(evt.action) == human_input__reload
    human_control_state_set_control_bit(ct, HumanPhysControlType HCT_RELOAD, true)
    setQuickReloadState(ct, false)
  elif int(evt.action) == human_input__quickReload
    human_control_state_set_control_bit(ct, HumanPhysControlType HCT_RELOAD, true)
    setQuickReloadState(ct, true)


[es(tag=input)]
def human_reload_input_on_action_terminated(evt : EventDaInputActionTerminated;
                                            input__enabled : bool;
                                            human_input__reload : int;
                                            human_input__quickReload : int;
                                            var human_input__isNeedHctReloadReset : bool&)
  if !input__enabled
    return
  if int(evt.action) == human_input__reload || int(evt.action) == human_input__quickReload
    human_input__isNeedHctReloadReset = true


[es(tag=input, after=human_weap_post_phys_es)]
def human_reload_input_reset_reload_flag_on_update(evt : CmdPostPhysUpdate;
                                                   var human_net_phys : HumanActor&;
                                                   var human_input__isNeedHctReloadReset : bool&)
  if human_input__isNeedHctReloadReset
    human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType HCT_RELOAD, false)
    human_net_phys.phys.producedCT |> setQuickReloadState(false)
    human_input__isNeedHctReloadReset = false
