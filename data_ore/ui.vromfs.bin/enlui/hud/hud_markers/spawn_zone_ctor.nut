from "%enlSqGlob/ui/ui_library.nut" import *

let { fontTitle, fontHeading1 } = require("%enlSqGlob/ui/fontsStyle.nut")
let { respawnsInBot, canUseRespawnbaseByType, needSpawnMenu, selectedRespawnGroupId, isFirstSpawn, respRequested, paratroopersPointSelectorOn } = require("%ui/hud/state/respawnState.nut")
let { localPlayerTeam } = require("%ui/hud/state/local_player.nut")
let { isReplay } = require("%ui/hud/state/replay_state.nut")
let {
  spawnZonesState,
  spawnZonesGetWatched,
} = require("%ui/hud/state/spawn_zones_markers.nut")
let { delete_paratroopers_icon } = require("%ui/hud/menus/troopers_point_chooser.nut")

let spawnIconColor = Color(86,131,212,250)
let inactiveSpawnIconColor = Color(160,160,160,150)
let playerSpawnActiveColor = Color(57, 99, 255)

let mkIconSquareSize = @(size) array(2, size)

//Temporarily same icons as spawn points icons for soldiers
let spawnIconSize = mkIconSquareSize(hdpxi(98))
let selectedSpawnIconSize = mkIconSquareSize(hdpxi(130))
let customSpawnSize = mkIconSquareSize(hdpxi(64))
let selectedCustomSpawnSize = mkIconSquareSize(hdpxi(98))
let playerSpawnSize = mkIconSquareSize(hdpxi(64))
let selectedPlayerSpawnSize = mkIconSquareSize(hdpxi(86))
let counterSpawnSize =mkIconSquareSize(hdpxi(32))
let counterMobileSpawnSize = mkIconSquareSize(hdpxi(46))
let mobileSpawnIconSize = [hdpxi(115), hdpxi(50)]
let selectedMobileSpawnIconSize = [hdpxi(135), hdpxi(60)]


let spawn_point = Picture($"!ui/skin#spawn_point.svg:{spawnIconSize[0]}:{spawnIconSize[1]}:K")
let selected_spawn_point = Picture($"!ui/skin#spawn_point_active.svg:{selectedSpawnIconSize[0]}:{selectedSpawnIconSize[1]}:K")

let mobile_spawn_point_selected = Picture($"!ui/skin#enlisted_mapcar_icon.svg:{selectedMobileSpawnIconSize[0]}:{selectedMobileSpawnIconSize[1]}:K")
let mobile_spawn_point = Picture($"!ui/skin#enlisted_mapcar_icon_unselect.svg:{mobileSpawnIconSize[0]}:{mobileSpawnIconSize[1]}:K")

let teammate_spawn_point = Picture($"!ui/skin#spawn_soldier_point.svg:{playerSpawnSize[0]}:{playerSpawnSize[1]}:K")
let selected_teammate_spawn_point = Picture($"!ui/skin#spawn_soldier_point_active.svg:{selectedPlayerSpawnSize[0]}:{selectedPlayerSpawnSize[1]}:K")

let custom_spawn_point = Picture($"!ui/skin#custom_spawn_point.svg:{customSpawnSize[0]}:{customSpawnSize[1]}:K")
let selected_custom_spawn_point = Picture($"!ui/skin#custom_spawn_point_active.svg:{selectedCustomSpawnSize[0]}:{selectedCustomSpawnSize[1]}:K")

let counter_spawn_icon = Picture($"!ui/skin#counter_spawn_icon.svg:{counterSpawnSize[0]}:{counterSpawnSize[1]}:K")
let counter_mobile_spawn_icon = Picture($"!ui/skin#battlepass/boost_time.svg:{counterMobileSpawnSize[0]}:{counterMobileSpawnSize[1]}:K")
let paratroopers_spawn_point = Picture($"!ui/skin#paratrooper_spawn_point.svg:{spawnIconSize[0]}:{spawnIconSize[1]}:K")

let mkSpawnPointInfo = @() {
  icon = @(isSelected) isSelected ? selected_spawn_point : spawn_point
  size = @(isSelected) isSelected ? selectedSpawnIconSize : spawnIconSize
  color = @(isActive) isActive ? spawnIconColor : inactiveSpawnIconColor
}

let customSpawnPointInfo = {
  icon = @(isSelected) isSelected ? selected_custom_spawn_point : custom_spawn_point
  size = @(isSelected) isSelected ? selectedCustomSpawnSize : customSpawnSize
  color = @(isActive) isActive ? spawnIconColor : inactiveSpawnIconColor
}

let playerSpawnPointInfo = {
  icon = @(isSelected) isSelected ? selected_teammate_spawn_point : teammate_spawn_point
  size = @(isSelected) isSelected ? selectedPlayerSpawnSize : playerSpawnSize
  color = @(isActive) isActive ? playerSpawnActiveColor : inactiveSpawnIconColor
}

let mobileSpawnPointInfo = {
  icon = @(isSelected) isSelected ? mobile_spawn_point_selected : mobile_spawn_point
  size = @(isSelected) isSelected ? selectedMobileSpawnIconSize : mobileSpawnIconSize
  color = @(isActive) isActive ? playerSpawnActiveColor : inactiveSpawnIconColor
}

let paratroopersSpawnPointInfo = {
  icon = @(_isSelected) paratroopers_spawn_point
  size = @(isSelected) isSelected ? selectedSpawnIconSize : spawnIconSize
  color = @(isActive) isActive ? playerSpawnActiveColor : inactiveSpawnIconColor
  offset = -0.25
}

let counterSpawnIconInfo = {
  image = counter_spawn_icon
  size = counterSpawnSize
  pos = [-counterSpawnSize[0], counterSpawnSize[1]*0.1]
}

let counterMobileSpawnIconInfo = {
  image = counter_mobile_spawn_icon
  size = counterMobileSpawnSize
  pos = [-counterMobileSpawnSize[0], counterMobileSpawnSize[1]*0.1]
}

let spawnPointsTypesInfo = {
  vehicle = mkSpawnPointInfo()
  human = mkSpawnPointInfo()
}

function paratroopers_icon_click(event){
  if (event.button == 1)
    delete_paratroopers_icon()
}



let defTransform = {}
let defPos = [0, -fsh(1)]

function mkQueueCounter(spawnIconInfo, isSelected, isActive, playersCount, isMobileSpawn) {
  let res = playersCount > 0 ? {
    pos = [0, -spawnIconInfo.size(isSelected)[1]*0.7]
    flow = FLOW_HORIZONTAL
    children = [
      {
        rendObj = ROBJ_TEXT
        color = Color(255, 255, 255)
        halign = ALIGN_LEFT
        valign = ALIGN_CENTER
        text = playersCount
        transform = defTransform
        size = SIZE_TO_CONTENT
      }.__update(fontHeading1),
      {
        rendObj = ROBJ_IMAGE
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        color = isActive ? spawnIconColor : inactiveSpawnIconColor
      }.__update(isMobileSpawn ? counterMobileSpawnIconInfo : counterSpawnIconInfo)
    ]
  }: null

  return res
}

let mkRespawnPoint = @(eid, isSelected, spawnIconInfo, selectedGroup, isActive, playersCount, additiveAngle, iconType, isMobileSpawn) {
  additiveAngle
  targetEid = eid
  transform = defTransform
  behavior = Behaviors.RotateRelativeToDir
  children = @() {
    watch = isReplay
    rendObj = ROBJ_IMAGE
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = spawnIconInfo.size(isSelected)
    color = spawnIconInfo.color(isActive)
    image = spawnIconInfo.icon(isSelected)
    pos = [0, spawnIconInfo.size(isSelected)[1]*(spawnIconInfo?.offset ?? -0.1)]
    behavior = isReplay.value ? null : Behaviors.Button
    onClick = @(event) iconType == "paratroopers" ? paratroopers_icon_click(event) : selectedRespawnGroupId.mutate(@(v) v[iconType] <- selectedGroup)
    onDoubleClick = @() respRequested(true)
    children = mkQueueCounter(spawnIconInfo, isSelected, isActive, playersCount, isMobileSpawn)
  }
}

let mkTextPlayerGroupmate = @(num, isSelected) {
  rendObj = ROBJ_TEXT
  color = Color(255, 255, 255)
  text = num
  transform = defTransform
  pos = defPos
  size = SIZE_TO_CONTENT
}.__update(isSelected ? fontTitle : fontHeading1)

let isAllZonesHidden = Computed(@() (isFirstSpawn.value && !paratroopersPointSelectorOn.value) || respawnsInBot.value || !needSpawnMenu.value)

let mk_respawn_point = memoize(function(eid) {
  let data = {
    eid
    minDistance = 0.7
    maxDistance = 15000
    distScaleFactor = 0.5
    clampToBorder = true
  }
  let markerState = spawnZonesGetWatched(eid)
  let watch = [selectedRespawnGroupId, canUseRespawnbaseByType, isAllZonesHidden, localPlayerTeam,
    markerState, isReplay]

  return function() {
    let {selectedGroup, iconType, iconIndex, forTeam, isCustom, isPlayerSpawn, isMobileSpawn, isActive, playersCount, additiveAngle} = markerState.value
    local spawnIconInfo = spawnPointsTypesInfo?[iconType] ?? spawnPointsTypesInfo.human
    if (isPlayerSpawn)
      spawnIconInfo = playerSpawnPointInfo
    else if (isMobileSpawn)
      spawnIconInfo = mobileSpawnPointInfo
    else if (isCustom)
      spawnIconInfo = customSpawnPointInfo

    if (iconType == "paratroopers")
      spawnIconInfo = paratroopersSpawnPointInfo

    let isHidden = isReplay.value
      || isAllZonesHidden.value
      || forTeam != localPlayerTeam.value
      || iconType != canUseRespawnbaseByType.value
    let isSelected = (selectedRespawnGroupId.value?[iconType] ?? -1) == selectedGroup
    return {
      data
      targetEid = eid
      halign = ALIGN_CENTER
      valign = ALIGN_BOTTOM
      key = eid
      transform = defTransform
      behavior = Behaviors.Projection
      watch
      sortOrder = eid
      children = isHidden ? null : [
            mkRespawnPoint(eid, isSelected, spawnIconInfo, selectedGroup, isActive,
              playersCount, additiveAngle, iconType, isMobileSpawn
            )
            iconIndex > 0 ? mkTextPlayerGroupmate(iconIndex, isSelected) : null
          ]
    }
  }
})

return {
  spawn_zone_ctor = { watch = spawnZonesState,
    ctor = @() spawnZonesState.value.keys().map(mk_respawn_point) },
}
