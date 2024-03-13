import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui/ui_library.nut" import *

let { forcedMinimalHud } = require("%ui/hud/state/hudGameModes.nut")
let { fontHeading2, fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let playerGrenades = require("player_info/grenades.ui.nut")
let {medicMedpacks} = require("player_info/medic_medpacks.ui.nut")
let { barWidth } = require("player_info/style.nut")
let vehicleBlock = require("player_info/vehicle_weapons.nut")
let {firingModeCmp} = require("player_info/player_cur_weapon.ui.nut")
let {showVehicleWeapons} = require("%ui/hud/state/vehicle_turret_state.nut")
let vitalPlayerInfo = require("player_info/vital_player_info.ui.nut")
let showPlayerHuds = require("%ui/hud/state/showPlayerHuds.nut")
let {weaponItems} = require("player_info/player_weapon_switch.nut")
let mkAmmoInfo = require("player_info/player_ammo.ui.nut")
let { controlledHeroEid } = require("%ui/hud/state/controlled_hero.nut")
let { watchedHeroEid } = require("%ui/hud/state/watched_hero.nut")
let {minimalistHud} = require("%ui/hud/state/hudOptionsState.nut")
let { currentGunEid, showAllWeaponsTrigger } = require("%ui/hud/state/hero_weapons.nut")
let mkMedkitIcon = require("player_info/medkitIcon.nut")
let mkRepairIcon = require("player_info/repairIcon.nut")
let {selfHealMedkits} = require("%ui/hud/state/total_medkits.nut")
let {repairKits} = require("%ui/hud/state/total_repairkits.nut")
let { defTxtColor } = require("%enlSqGlob/ui/designConst.nut")
let { mobileRespawnOccupiedSeats } = require("%ui/hud/huds/player_info/mobile_respawn_widget.nut")

let hasMedkit = Computed(@() selfHealMedkits.value > 0)
let hasRepair = Computed(@() repairKits.value > 0)
let medkitIco = mkMedkitIcon(hdpxi(25), defTxtColor)
let repairIco = mkRepairIcon(hdpxi(25), defTxtColor)
let playerMedkits = @() {
  watch = hasMedkit
  children = hasMedkit.value ? medkitIco : null
}
let playerRepairkit = @() {
  watch = hasRepair
  children = hasRepair.value ? repairIco : null
}

let mainStyles = {
  curAmmo = {fontFxColor=Color(0,0,0,50) fontFx=FFT_GLOW}.__update(fontHeading2)
  sep = {fontFxColor=Color(0,0,0,50) fontFx=FFT_GLOW}.__update(fontHeading2)
  totalAmmo = {fontFxColor=Color(0,0,0,50) fontFx=FFT_GLOW}.__update(fontHeading2)
  useBlur = false
}

let secondaryStyles = {
  curAmmo = {fontFxColor=Color(0,0,0,50) fontFx=FFT_GLOW}.__update(fontSub)
  sep = {fontFxColor=Color(0,0,0,50) fontFx=FFT_GLOW}.__update(fontSub)
  totalAmmo = {fontFxColor=Color(0,0,0,50) fontFx=FFT_GLOW}.__update(fontSub)
  useBlur = false
}

let gap = freeze({size = [0, hdpx(5)]})

let equipmentIcons = freeze({
  flow = FLOW_HORIZONTAL
  gap = hdpx(8)
  valign = ALIGN_CENTER
  children = [playerRepairkit, playerMedkits, playerGrenades]
})

let showShortBlock = Watched(true)
let hideShortBlock = @() showShortBlock(false)
function activateShowShortBlock(...){
  showShortBlock(true)
  if (!forcedMinimalHud.value)
    return
  gui_scene.clearTimer(hideShortBlock)
  gui_scene.setTimeout(4, hideShortBlock)
}
forcedMinimalHud.subscribe(activateShowShortBlock)
minimalistHud.subscribe(activateShowShortBlock)

let showShortHandlers = [ "Human.Weapon1","Human.Weapon2","Human.Weapon3",
    "Human.Weapon4","Human.Throw","Human.SpecialItemSlot","Human.GrenadeNext","Human.GrenadePrev","Inventory.UseMedkit",
    "Human.WeaponNext","Human.WeaponPrev","Human.Melee", "Human.WeaponNextMain", "Human.GrenadeNext", "Human.FiringMode",
    "Human.WeapModToggle", "Human.Reload"
  ].map(@(v) [v,activateShowShortBlock]).totable()

let handlersCm = {eventHandlers = showShortHandlers}

let shortPlayerBlock = @() {
  flow = FLOW_VERTICAL
  size = SIZE_TO_CONTENT
  halign = ALIGN_RIGHT
  watch = showShortBlock
  children = showShortBlock.value ? [
    medicMedpacks
    gap
    mkAmmoInfo(mainStyles, secondaryStyles)
    gap
    firingModeCmp
    gap
    gap
    equipmentIcons
    handlersCm
  ] : handlersCm
}

let showAllWeapons = Watched(false)
let hideAllWeapons = @(...) showAllWeapons(false)
function activateShowAllWeapons(...){
  if (controlledHeroEid.value != watchedHeroEid.value || controlledHeroEid.value == ecs.INVALID_ENTITY_ID)
    return
  showAllWeapons(true)
  activateShowShortBlock()
  gui_scene.resetTimeout(4, hideAllWeapons)
}
activateShowAllWeapons()
showAllWeaponsTrigger.subscribe(activateShowAllWeapons)
controlledHeroEid.subscribe(activateShowAllWeapons)
currentGunEid.subscribe(function(eid) {
  if (eid != ecs.INVALID_ENTITY_ID)
    activateShowAllWeapons()
})

let playerDynamic = @(){
  watch = [showAllWeapons, forcedMinimalHud, showShortBlock]
  flow = FLOW_VERTICAL
  halign = ALIGN_RIGHT
  gap = fsh(2)
  children = [
    showAllWeapons.value ? weaponItems : null,
    shortPlayerBlock
  ]
}

function playerBlock() {
  return {
    flow = FLOW_VERTICAL
    halign = ALIGN_RIGHT
    size = [barWidth, SIZE_TO_CONTENT]
    gap = fsh(0.5)
    watch = [showPlayerHuds, showVehicleWeapons, forcedMinimalHud, mobileRespawnOccupiedSeats]
    children = showPlayerHuds.value ? [
      !showVehicleWeapons.value ? playerDynamic : null,
      (showVehicleWeapons.value || mobileRespawnOccupiedSeats.value != null) ? vehicleBlock : null,
      vitalPlayerInfo
    ] : null
  }
}

return playerBlock