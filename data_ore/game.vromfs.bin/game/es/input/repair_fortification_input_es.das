require ecs
require DngNet
require game.es.input.input_events
require enlisted.events_enlisted
require DagorInput
require net
require game.es.input.input_common
require HumanPhys


def init(var human_input__repairBuilding : int&)
  human_input__repairBuilding = int(get_action_handle("Human.RepairBuilding", TYPEGRP_DIGITAL))


def reset(var human_input__repairBuilding : int&)
  human_input__repairBuilding = int(BAD_ACTION_HANDLE)


[es(tag=input, on_appear)]
def human_repair_fortification_on_appear_es(evt : Event; var human_input__repairBuilding : int&)
  init(human_input__repairBuilding)


[es(tag=input)]
def human_repair_fortification_on_input_es(evt : EventDaInputInit; var human_input__repairBuilding : int&)
  if evt.init
    init(human_input__repairBuilding)
  else
    reset(human_input__repairBuilding)


[es(tag=input)]
def human_repair_fortification_start_input_es(evt : EventDaInputActionTriggered;
                                              eid : EntityId;
                                              human_use_object__selectedBuilding : EntityId;
                                              human_input__repairBuilding : int;
                                              input__enabled : bool)
  if input__enabled && int(evt.action) == human_input__repairBuilding
    query(human_use_object__selectedBuilding) <| $ [es(REQUIRE=fortification_repair__costPercent, REQUIRE_NOT=builder_preview)] ()
      send_net_event(eid, [[EventRepairFortificationStart target=human_use_object__selectedBuilding]])

[es(tag=input)]
def human_repair_fortification_stop_input_es(evt : EventDaInputActionTerminated;
                                             eid : EntityId;
                                             human_input__repairBuilding : int;
                                             input__enabled : bool)
  if input__enabled && int(evt.action) == human_input__repairBuilding
    send_net_event(eid, [[EventRepairFortificationStop]])


[es(tag=input, REQUIRE=hero, track=(human_net_phys__isHctAim, human_net_phys__isHctShoot, human_net_phys__states))]
def human_repair_fortification_interrupt_on_gamepad(evt : Event;
                                                    eid : EntityId;
                                                    human_net_phys__isHctAim : bool;
                                                    human_net_phys__isHctShoot : bool;
                                                    human_net_phys__states : int;
                                                    fortification_repair__active : bool)
  if !fortification_repair__active || !is_gamepad_input()
    return

  let isHumanJumping = ((uint(human_net_phys__states) & uint(StateFlag ST_JUMP)) != 0u)
  if human_net_phys__isHctAim || human_net_phys__isHctShoot || isHumanJumping
    send_net_event(eid, [[EventRepairFortificationStop]])
    return


[es(tag=input)]
def human_repair_fortification_reset_toggle_on_interrupting(evt : EventRepairFortificationStop; human_input__repairBuilding : int)
  reset_digital_action_sticky_toggle(uint16(human_input__repairBuilding))
