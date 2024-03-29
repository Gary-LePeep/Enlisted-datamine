let { weaponToAnimState, weaponToSittingAnimState } = require("menu_poses_for_weapons.nut")
let { rnd } = require("dagor.random")
let { split_by_chars } = require("string")
let { kwarg } = require("%sqstd/functools.nut")

function getWeapTemplate(template){
  assert(type(template)=="string")
  return split_by_chars(template, "+")?[0] ?? template
}

let SLOTS_ORDER = ["primary", "secondary", "tertiary"]
let firstAvailableWeapon = @(tmpls, slot_order)
  tmpls?[slot_order.findvalue(@(key) (tmpls?[key] ?? "") != "")] ?? ""

function getAnimationBlacklist(itemTemplates) {
  let animationBlacklist = {}
  foreach (itemTemplate in itemTemplates) {
    let itemAnimationBlacklist = itemTemplate.getCompValNullable("animationBlacklistForMenu")
    if (itemAnimationBlacklist == null)
      continue
    foreach (anim in itemAnimationBlacklist) {
      animationBlacklist[anim] <- true
    }
  }
  return animationBlacklist
}

function getIdleAnimState(weapTemplates, itemTemplates = null, overridedIdleAnims = null, overridedSlotsOrder = null, seed = null, isSiting = false) {
  seed = seed ?? rnd()
  if (seed < 0)
    seed = -seed

  local idle = overridedIdleAnims?.defaultPoses ?? weaponToAnimState.defaultPoses
  let weaponTemplate = getWeapTemplate(firstAvailableWeapon(weapTemplates, overridedSlotsOrder ?? SLOTS_ORDER))
  if (!isSiting)
    if (weaponTemplate == "")
      idle = overridedIdleAnims?.unarmedPoses.getAll()
        ?? weaponToAnimState?.unarmedPoses
        ?? idle
    else
      idle = overridedIdleAnims?[weaponTemplate].getAll()
        ?? weaponToAnimState?[weaponTemplate]
        ?? idle
  else
    if (weaponTemplate == "")
      idle = overridedIdleAnims?.unarmedPoses.getAll()
        ?? weaponToSittingAnimState?.unarmedPoses
        ?? weaponToSittingAnimState?.defaultPoses
        ?? idle
    else
      idle = overridedIdleAnims?.sittingPoses.getAll()
        ?? weaponToSittingAnimState?[weaponTemplate]
        ?? weaponToSittingAnimState?.defaultPoses
        ?? idle

  if (itemTemplates != null) {
    idle = clone idle
    let animationBlacklist = getAnimationBlacklist(itemTemplates)
    for (local i = idle.len() - 1; i >= 0; --i)
      if (idle[i] in animationBlacklist)
        idle.remove(i)
  }

  return idle.len() > 0 ? idle[seed % idle.len()] : weaponToAnimState.defaultPoses.top()
}

return {
  getWeapTemplate
  getIdleAnimState = kwarg(getIdleAnimState)
}
