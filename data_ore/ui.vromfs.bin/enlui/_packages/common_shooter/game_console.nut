import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui_library.nut" import *

let {get_controlled_hero} = require("%dngscripts/common_queries.nut")
let { remove_item_from_weap_to_inventory } = require("das.human_weap")
let { drop_weap_from_slot, drop_gear_from_slot } = require("das.inventory")

console_register_command(function(weaponSlotName) {drop_weap_from_slot(weaponSlotName)},
  "inventory.drop_weap_from_slot")

console_register_command(function(equipmentSlotName) {drop_gear_from_slot(equipmentSlotName)},
  "inventory.drop_gear_from_slot")

console_register_command(function(weaponSlotName, weapModSlotName) {remove_item_from_weap_to_inventory(weaponSlotName, weapModSlotName)},
  "inventory.remove_item_from_weap")

console_register_command(function(){
  let hero = get_controlled_hero()
  let vehicle = ecs.obsolete_dbg_get_comp_val(hero, "human_anim__vehicleSelected")
  if (vehicle == ecs.INVALID_ENTITY_ID)
    return
  let camNames = ecs.obsolete_dbg_get_comp_val(vehicle, "camNames")

  if (camNames.getAll().indexof("plane_cam") == null) {
    camNames.append("plane_cam")
    ecs.obsolete_dbg_set_comp_val(vehicle, "camNames", camNames)
  }
}, "plane.enable_tps_cam")
