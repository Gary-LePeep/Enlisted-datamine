import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui/ui_library.nut" import *

let { getZoneWatch, visibleCurrentCapZonesEids, capZones } = require("%ui/hud/state/capZones.nut")
let { TEAM1_COLOR_FG, DEFAULT_TEXT_COLOR } = require("%ui/hud/style.nut")
let {safeAreaHorPadding, safeAreaVerPadding} = require("%enlSqGlob/ui/safeArea.nut")
let { isReplay } = require("%ui/hud/state/replay_state.nut")
let { showSquadSpawn, respawnSelectedEid } = require("%ui/hud/state/respawnState.nut")

let { watchedHeroEid, watchedTeam } = require("%ui/hud/state/watched_hero.nut")

let { capzoneWidget } = require("%ui/hud/components/capzone.nut")
let { canShowGameHudInReplay } = require("%ui/hud/replay/replayState.nut")
let capzoneSettings = {canHighlight=false}

let visibleZoneEids = Computed(function(prev) {
  let capzones = capZones.value
  let watchedhero = watchedHeroEid.value
  let n = visibleCurrentCapZonesEids.value.filter(@(_, eid)
      capzones?[eid].heroInsideEid != watchedhero
      || watchedhero == ecs.INVALID_ENTITY_ID
      || watchedhero == null
    )
  if (!isEqual(n, prev))
    return n
  return prev
})

let isZonesInReplayHidden = Computed(@() isReplay.value && !canShowGameHudInReplay.value)

let distanceText = memoize(function(eid, fromEid = ecs.INVALID_ENTITY_ID) {
  return freeze({
    rendObj = ROBJ_TEXT
    color = DEFAULT_TEXT_COLOR
    hplace = ALIGN_CENTER
    halign = ALIGN_CENTER
    pos = [0, fsh(3.5)]
    size = [fsh(5), SIZE_TO_CONTENT]

    behavior = Behaviors.DistToEntity
    targetEid = eid
    fromEid
    minDistance = 3.0
  })
})

let pointerColor = Color(200,200,200)
let iconSz =[hdpxi(32), hdpxi(24)]

let defIcon = {
  rendObj = ROBJ_IMAGE
  size = iconSz
  image = Picture("!ui/skin#waypoint.svg:{0}:{1}".subst(iconSz[0], iconSz[1]))
}
let mkZoneIcon = memoize(@(eid, title, icon, isDefendZone) (!isDefendZone && (title ?? "") == "" && (icon ?? "") == "")
    ? defIcon.__merge({ key = eid })
    : null,
  1
)

let mkPointer = @(capturingAndDefend) freeze({
  rendObj = ROBJ_IMAGE
  image = Picture("!ui/skin#target_pointer.avif")
  size = [fsh(4), fsh(4.8)]
  pos = [fsh(0.05), -fsh(0.34)]
  color = pointerColor
  key = capturingAndDefend
  animations = capturingAndDefend ? [
      { prop=AnimProp.color, from=pointerColor, to=TEAM1_COLOR_FG, duration=0.6, play=true, loop=true, easing=CosineFull}
    ] : null
})

let pointerCapturingAndDefend = mkPointer(true)
let pointer = mkPointer(false)
let animations = [
  { prop=AnimProp.opacity, from=0, to=1, duration=0.5, play=true, easing=InOutCubic}
  { prop=AnimProp.opacity, from=1, to=0, duration=0.3, playFadeOut=true, easing=InOutCubic}
]

// let capzoneIconForMobileRespawn = function(nearToMobileRespawn) {
//   let color = nearToMobileRespawn ? Color(160,160,160,150) : Color(86,131,212,250)
//   let flagIcon = {
//     rendObj = ROBJ_IMAGE
//     image = Picture($"!ui/skin#spawn_point.svg:{hdpxi(26)}:{hdpxi(26)}:K")
//     size = [hdpxi(26),hdpxi(26)]
//     hplace = ALIGN_CENTER
//     vplace = ALIGN_CENTER
//     color
//   }
//   let circle = {
//     rendObj = ROBJ_IMAGE
//     image = Picture($"ui/skin#circle_progress.avif:{hdpxi(40)}:{hdpxi(40)}:K")
//     hplace = ALIGN_CENTER
//     vplace = ALIGN_CENTER
//     size = [hdpxi(40),hdpxi(40)]
//     color
//   }
//   return { children = [circle, flagIcon] }
// }

let behavior = [Behaviors.DistToPriority, Behaviors.OverlayTransparency]
let size = [0,0]
let childSize = [fsh(4.8), fsh(4.8 + 2.0)]

let mkZonePointer = function(eid) {
  let capzone = capzoneWidget(eid, capzoneSettings)
  let zoneWatch = getZoneWatch(eid)
  let {title=null, icon=null, iconOffsetY=0.0} = zoneWatch.value
  let watch = [watchedTeam, zoneWatch, showSquadSpawn, respawnSelectedEid]
  let childData = {
    eid
    priorityOffset = 10000
    opacityCenterRelativeDist = 0.05
    opacityCenterMinMult = 0.5
  }
  let data = {
    zoneEid = eid
    yOffs = iconOffsetY
  }
  let capturingKey = {}
  let nkey = {}
  return function() {
    let zone = zoneWatch.value
    if (zone == null)
      return { watch }
    let heroTeam = watchedTeam.value
    let {isCapturing, curTeamCapturingZone, attackTeam } = zone
    let isDefendZone = (attackTeam >= 0 && attackTeam != heroTeam)
    let zoneIcon = mkZoneIcon(eid, title, icon, isDefendZone)
    let showCapturing = isCapturing
      && (attackTeam == heroTeam || (curTeamCapturingZone != heroTeam && attackTeam!=heroTeam))
    let distance = showSquadSpawn.value ?
      (respawnSelectedEid.value != ecs.INVALID_ENTITY_ID ? distanceText(eid, respawnSelectedEid.value) : null) : distanceText(eid)
    return {
      watch = [zoneWatch, showSquadSpawn, respawnSelectedEid]
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      size
      key = showCapturing ? capturingKey : nkey
      data
      transform = {}
      children = {
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        data  = childData
        size = childSize
        pos = [0, -fsh(1)]
        behavior
        children = [
          {
            size = [fsh(4.8), fsh(4.8)]
            halign = ALIGN_CENTER
            transform = {}
            children = showCapturing && isDefendZone ? pointerCapturingAndDefend : pointer
          }
          capzone
          zoneIcon
          distance
        ]
      }

      animations
    }
  }
}

let zonePointersWatch = [visibleZoneEids, safeAreaHorPadding, isZonesInReplayHidden,
  isZonesInReplayHidden]
let memoizedMap = mkMemoizedMapSet(mkZonePointer)

function zonePointers() {

  let children = isZonesInReplayHidden.value ? null : memoizedMap(visibleZoneEids.value).values()

  return {
    watch = zonePointersWatch
    size = [sw(100)-safeAreaHorPadding.value*2 - fsh(6), sh(100) - safeAreaVerPadding.value*2-fsh(8)]
    behavior = Behaviors.ZonePointers
    halign = ALIGN_CENTER
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    valign = ALIGN_CENTER
    children
  }
}

return zonePointers
