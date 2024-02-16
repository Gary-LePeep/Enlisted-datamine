options no_aot
require ecs
require app
require DngHuman
require DngWeapon
require HumanPhys
require DagorConsole
require game.es.net_console_macro
require common_shooter.es.human_weap_common
require common_shooter.events_common_shooter


[net_console_cmd(name="player.request_weapon_reload")]
def request_hero_weapon_reload_cmd(weapon_slot_name : string = "primary"; [[net_hero]] hero_eid : EntityId)
  let slotId = get_weapon_slot_index_from_name(weapon_slot_name)
  if slotId < 0
    console_print("Can't find weapon slot with name: {weapon_slot_name}")
    return
  query(hero_eid) <| $ [es] (human_weap__gunEids : EidList)
    sendEvent(hero_eid, [[CmdRequestReload atTime=get_sync_time(), gunEid=human_weap__gunEids[slotId]]])


[net_console_cmd(name="player.request_unload_weapon")]
def request_hero_weapon_unload_cmd(weapon_slot_name : string = "primary"; [[net_hero]] hero_eid : EntityId)
  if !unload_weapon_ammo_to_inventory(hero_eid, weapon_slot_name)
    console_print("Can't find weapon slot with name: {weapon_slot_name}")


[net_console_cmd(name="player.choose_weapon")]
def hero_choose_weapon_cmd(weapon_slot_name : string = "primary"; [[net_hero]] hero_eid : EntityId)
  if !choose_weapon(hero_eid, weapon_slot_name)
    console_print("Can't find weapon slot with name: {weapon_slot_name}")
