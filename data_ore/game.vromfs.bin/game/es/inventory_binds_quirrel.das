require game.es.inventory_common
require ecs.ecs_quirrel
require game.utils.hero
require game.es.inventory_drop_common


[quirrel_bind(module_name="das.inventory")]
def drop_weap_from_slot(slot_name : string)
  inventory_common::drop_weap_from_slot(get_controlled_hero(), slot_name)


[quirrel_bind(module_name="das.inventory")]
def pickup_item_to_weap_slot(eid : EntityId; slot_name : string)
  inventory_common::pickup_item_to_weap_slot(get_controlled_hero(), eid, slot_name)


[quirrel_bind(module_name="das.inventory")]
def pickup_and_install_item_on_weap(mod_eid : EntityId; weapon_slot_name, weap_mod_slot_name : string)
  inventory_common::pickup_and_install_item_on_weap(get_controlled_hero(), mod_eid, weapon_slot_name, weap_mod_slot_name)


[quirrel_bind(module_name="das.inventory")]
def pickup_item(item_eid : EntityId)
  inventory_common::pickup_item(get_controlled_hero(), item_eid)


[quirrel_bind(module_name="das.inventory")]
def is_item_useful(to_whom, item_eid : EntityId)
  return inventory_common::is_item_useful(to_whom, item_eid)


[quirrel_bind(module_name="das.inventory")]
def is_fast_pickup_item(item_eid : EntityId)
  return inventory_common::is_fast_pickup_item(get_controlled_hero(), item_eid)


[quirrel_bind(module_name="das.inventory")]
def drop_gear_from_slot(slot_name : string)
  inventory_common::drop_gear_from_slot(get_controlled_hero(), slot_name)


[quirrel_bind(module_name="das.inventory")]
def pickup_item_entity_to_gear(item_eid : EntityId; slot_name : string)
  inventory_common::pickup_item_to_gear_slot(get_controlled_hero(), item_eid, slot_name)


[quirrel_bind(module_name="das.inventory")]
def drop_item(item_eid : EntityId)
  inventory_drop_common::drop_item_from_cont(get_controlled_hero(), item_eid)
