import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui/ui_library.nut" import *

let {get_sync_time} = require("net")
let {fontSub} = require("%enlSqGlob/ui/fontsStyle.nut")
let {SELECTION_BORDER_COLOR} = require("%ui/hud/style.nut")
let { blurBack } = require("style.nut")
let iconWidget = require("%ui/components/icon3d.nut")

let ammoColor = Color(100,100,100,50)
let curColor = Color(180,200,230,180)
let color = Color(168,168,168,150)
let curBorderColor = SELECTION_BORDER_COLOR
let nextBorderColor = Color(200, 200, 200, 100)


function itemAppearing(duration=0.2) {
  return {prop=AnimProp.opacity, from=0, to=1, duration=duration, play=true, easing=InOutCubic}
}
let wWidth = hdpx(280)
let aHgt = calc_str_box("A", fontSub)[1]*2 //we want to be sure that weapon name and icon could be displayed without big overlapping
let wHeight = max(aHgt+hdpxi(2), hdpxi(40))


function weaponId(weapon, turretsAmmo, params={width=flex() height=wHeight}) {
  let size = [params?.width ?? flex(), params?.height ?? wHeight]
  let loadedGunInGroupEid = Computed(@() turretsAmmo.value?[weapon.groupName].firstLoadedGunInGroup)

  return function(){
    let name = weapon?.namesInGroup[loadedGunInGroupEid.value] ?? weapon.name
    return {
      watch = loadedGunInGroupEid
      size
      padding= params?.padding ?? [0,0,hdpx(2),hdpx(2)]
      margin = params?.margin
      clipChildren = true
      children = {
        behavior = Behaviors.Marquee
        size = flex()
        valign = ALIGN_BOTTOM
        children = {
          size = SIZE_TO_CONTENT
          halign = ALIGN_LEFT
          rendObj = ROBJ_TEXT
          text = loc(name)
          fontFx = FFT_BLUR
          fontFxColor = Color(0,0,0,30)
          key = name
          color = weapon?.isCurrent ? curColor : color
        }.__update(fontSub)
      }
    }
  }
}
let wAmmoDef = {width=SIZE_TO_CONTENT height=SIZE_TO_CONTENT}
function weaponAmmo(weapon, turretsAmmo, params=wAmmoDef) {
  let combinedAmmo = Computed(function() {
    let data = turretsAmmo.value
    return (data?[weapon.gunEid] ?? {}).__merge({
      groupAmmo = data?[weapon.groupName].groupAmmo
      reloadAmmo = data?[weapon.groupName].reloadAmmo
    })
  })

  //note: no sense in having size, cause we do not have scalable DTEXT yet :(
  let size = [params?.width ?? SIZE_TO_CONTENT, params?.height ?? SIZE_TO_CONTENT]
  let instant = weapon?.instant
  let showZeroAmmo = weapon?.showZeroAmmo ?? false

  return function() {
    local {
      curAmmo = 0, totalAmmo = 0, ammoByBullet = [], reloadAmmo = 0, groupAmmo = 0, firstStageAmmo = 0
    } = combinedAmmo.value
    let setAmmo = ammoByBullet?[weapon?.setId]
    totalAmmo = reloadAmmo ?? totalAmmo
    if (setAmmo != null) {
      curAmmo = weapon?.isReloadable && weapon?.isCurrent ? curAmmo : 0
      totalAmmo = weapon?.isReloadable && weapon?.isCurrent ? totalAmmo
        : ammoByBullet?[weapon?.setId] ?? totalAmmo
    }
    curAmmo = groupAmmo ?? curAmmo
    local firstStage = ""
    if (!weapon?.isCurrent)
      firstStageAmmo = 0
    else if (firstStageAmmo > 0) {
      firstStageAmmo = min(firstStageAmmo, totalAmmo)
      firstStage = $"{firstStageAmmo}+"
      totalAmmo = totalAmmo - firstStageAmmo
    }
    let ammo_string = (totalAmmo + curAmmo + firstStageAmmo <= 0 && !showZeroAmmo) ? ""
      : instant ? $"{firstStage}{(totalAmmo + curAmmo)}"
      : (weapon?.isReloadable ?? false) ? $"{curAmmo}/{firstStage}{totalAmmo}"
      : $"{firstStage}{totalAmmo}"
    return {
      watch = [combinedAmmo]
      rendObj = ROBJ_TEXT
      text = ammo_string
      color = weapon?.isCurrent ? curColor : ammoColor
      size = size
      clipChildren=true
      key = totalAmmo+curAmmo
      halign = params?.halign ?? ALIGN_RIGHT
      hplace = params?.hplace ?? ALIGN_RIGHT
      transform  = {pivot =[0.5,0.5]}
      margin = params?.margin ?? hdpx(5)
      animations = [
        { prop=AnimProp.scale, from=[1.1,1.3], to=[1,1], duration=0.2, play=true, easing=OutCubic }
      ]
    }
  }
}


let silhouetteDefColor=[200,200,200,200]
let silhouetteInactiveColor=[0,0,0,200]
let outlineDefColor=[0,0,0,0]
let outlineInactiveColor=[200,200,200,0]

let weaponWidgetAnims = [
  {prop=AnimProp.opacity, from=1, to=0, duration=0.3, playFadeOut=true}
  itemAppearing()
]

function iconCtorDefault(weapon, width, height) {
  return iconWidget(weapon, {
    width = width
    height = height
    hplace = ALIGN_CENTER
    shading = "silhouette"
    silhouette = silhouetteDefColor
    outline = outlineDefColor
    silhouetteInactive = silhouetteInactiveColor
    outlineInactive = outlineInactiveColor
  })
}

let currentBorder = { size = flex(), rendObj = ROBJ_FRAME, borderWidth = 1, color = curBorderColor }
let nextBorder = { size = flex(), rendObj = ROBJ_FRAME, borderWidth = 1, color = nextBorderColor, key = {}
  animations = [{ prop = AnimProp.opacity, from = 0.5, to = 1, duration = 1, play = true, loop = true, easing = CosineFull }] }

let mkReplenishmentProgress = @(from, to, duration, key) {
  margin = [0, 0, 0, hdpx(10)]
  rendObj = ROBJ_PROGRESS_LINEAR
  imageHalign = ALIGN_CENTER
  imageValign = ALIGN_CENTER
  vplace = ALIGN_CENTER
  hplace = ALIGN_CENTER
  fValue = 0
  size = flex()
  fgColor = Color(0,255,0)
  bgColor = Color(0,150,0)
  key
  animations = [
    { prop = AnimProp.fValue, from, to, duration, play = true }
  ]
}

function turretStowageReplenishmentTip(weapon, turretsReplenishment, width) {
  if (!weapon?.isControlled || !weapon?.isCurrent)
    return null
  let gunEid = weapon?.gunEid ?? ecs.INVALID_ENTITY_ID
  let turretReplenishmentState = Computed(@() turretsReplenishment.value?[gunEid] ?? {})

  return function() {
    let { totalTime = -1, endTime = -1 } = turretReplenishmentState.value
    let timeLeft = max(0, endTime - get_sync_time())
    let startProgress = totalTime > 0 ? max(0, 1 - timeLeft / totalTime) : 0
    let endProgress = 1
    let isReplenishing = endTime > 0
    return {
      watch = turretReplenishmentState
      valign = ALIGN_CENTER
      vplace = ALIGN_CENTER
      size = [width, hdpx(3)]
      children = isReplenishing
        ? mkReplenishmentProgress(startProgress, endProgress, timeLeft, turretReplenishmentState.value)
        : null
    }
  }
}

let iconBlockWidth = hdpxi(230)

function weaponWidget(weapon, turretsAmmo, turretsReplenishment, hint = null, width = wWidth, height = wHeight, showHint = true, iconCtor = iconCtorDefault) {
  let markAsSelected = weapon?.isEquiping || (weapon?.isCurrent && !weapon?.isHolstering)
  let borderComp = markAsSelected ? currentBorder
    : weapon?.isNext ? nextBorder
    : null

  let weaponHudIcon = iconCtor(weapon, iconBlockWidth, height - hdpx(2) * 2)

  let controlHint = showHint ? hint : null
  let hintsPadding = showHint ? wHeight + hdpx(2) : hdpx(2)
  return @() {
    size = [width,height]
    animations = weaponWidgetAnims
    flow = FLOW_HORIZONTAL
    children = [
      {
        size = [width - hintsPadding, height]
        clipChildren = true
        children = [
          blurBack,
          borderComp,
          {
            size = [width-hintsPadding,height]
            clipChildren = true
            valign = ALIGN_CENTER
            children = ((weapon?.name ?? "") != "")
              ? {
                  size = flex()
                  padding=hdpx(2)
                  children = [
                    weaponHudIcon,
                    {
                      flow = FLOW_HORIZONTAL
                      size = flex()
                      valign = ALIGN_CENTER
                      children = [
                        weaponId(weapon, turretsAmmo, { size=[flex(),height/2]})
                        {
                          flow = FLOW_VERTICAL
                          children = [
                            weaponAmmo(weapon, turretsAmmo, {width = SIZE_TO_CONTENT height=wHeight/2 hplace=ALIGN_RIGHT vplace = ALIGN_CENTER})
                            turretStowageReplenishmentTip(weapon, turretsReplenishment, (width-hintsPadding-iconBlockWidth) * 0.5)
                          ]
                        }
                      ]
                    }
                  ]
                }
              : {size=flex()}
          }
        ]
      }
      showHint ? {size = flex(0.01) minWidth=hdpx(1)} : null
      controlHint
    ]
  }
}

let vehicleWeaponWidget = kwarg(weaponWidget)

return {
  vehicleWeaponWidget
  wWidth
  wHeight
  weaponWidgetAnims
}
