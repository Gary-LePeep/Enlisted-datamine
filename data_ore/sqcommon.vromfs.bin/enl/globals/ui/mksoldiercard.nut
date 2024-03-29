from "%enlSqGlob/ui/ui_library.nut" import *

let { fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let { statusIconWarning } = require("%enlSqGlob/ui/itemPkg.nut")
let { autoscrollText } = require("%enlSqGlob/ui/defcomps.nut")
let { withTooltip } = require("%ui/style/cursors.nut")
let { kindIcon, classIcon, levelBlock, classTooltip,
  calcExperienceData, experienceTooltip, mkSoldierMedalIcon
} = require("%enlSqGlob/ui/soldiersUiComps.nut")
let { getItemName, getObjectName } = require("%enlSqGlob/ui/itemsInfo.nut")
let { mkSoldierPhoto } = require("%enlSqGlob/ui/soldierPhoto.nut")
let { getClassCfg } = require("%enlSqGlob/ui/soldierClasses.nut")
let {
  panelBgColor, squadSlotBgIdleColor, squadSlotBgHoverColor,
  squadSlotBgActiveColor, squadSlotBgAlertColor, squadSlotBgMultiSelColor,
  gap, midPadding, slotBaseSize, disabledTxtColor, blockedTxtColor,
  deadTxtColor, defTxtColor, listCtors, selectedTxtColor
} = require("%enlSqGlob/ui/designConst.nut")


let DISABLED_ITEM = { tint = Color(40, 40, 40, 120), picSaturate = 0.0 }
let borderThickness = hdpxi(3)
let iconDead = Picture("ui/skin#lb_deaths.avif")
let panelBgBlockedColor = Color(40,10,10,180)

let listSquadColor = @(flags, selected, massSelected, hasAlertStyle, isBlocked)
  isBlocked ? panelBgBlockedColor
    : flags & S_HOVER ? squadSlotBgHoverColor
    : selected ? squadSlotBgActiveColor
    : massSelected ? squadSlotBgMultiSelColor
    : hasAlertStyle ? squadSlotBgAlertColor
    : squadSlotBgIdleColor


let iconSize = hdpxi(26)
let deadIconSize = hdpxi(48)
let deadIcon = {
  rendObj = ROBJ_IMAGE
  size = [deadIconSize, deadIconSize]
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  image = iconDead
  opacity = 0.3
}

let mkPhotoSize = @(h) [h * 2 / 3, h]

function mkClassBlock(soldier, isClassRestricted, isPremium, displayedKind) {
  let { sKind = null, sClass = null, sClassRare = null, armyId = null } = soldier
  let color = isClassRestricted ? blockedTxtColor : defTxtColor

  return {
    size = [hdpxi(36), flex()]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    rendObj = ROBJ_SOLID
    color = panelBgColor
    children = withTooltip({
      flow = FLOW_VERTICAL
      gap
      children = [
        kindIcon(displayedKind ?? sKind, iconSize, sClassRare).__update({ color, vplace = ALIGN_CENTER })
        isPremium ? null : classIcon(armyId, sClass, iconSize)
      ]
    }, @() classTooltip(armyId, sClass, sKind))
  }
}


let mkDropSoldierInfoBlock = @(soldierInfo, squadInfo, nameColor, textColor, group) { //!!FIX ME: Why it here?
  size = flex()
  flow = FLOW_VERTICAL
  valign = ALIGN_CENTER
  children = [
    {
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_HORIZONTAL
      children = {
        size = [flex(), SIZE_TO_CONTENT]
        rendObj = ROBJ_TEXTAREA
        behavior = Behaviors.TextArea
        text = loc(squadInfo.titleLocId)
        color = textColor
      }.__update(fontSub)
    }
    autoscrollText({
      text = getObjectName(soldierInfo)
      color = nameColor
      group = group
    })
  ]
}

function mkWeaponRow(soldierInfo, weaponColor, group, override = {}) {
  let { primaryWeapon = null, weapons = [] } = soldierInfo
  let template = primaryWeapon
    ?? weapons.findvalue(@(v, idx) idx < 3 && (v?.templateName ?? "") != "")?.templateName
  let weaponLocId = template != null
    ? getItemName(template)
    : "delivery/withoutWeapon"
  return autoscrollText({
    text = loc(weaponLocId)
    color = weaponColor
    vplace = ALIGN_BOTTOM
    group = group
  }.__update(override))
}

let mkWeaponRowWithWarning = @(soldierInfo, weaponColor, group, override = {}) {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_HORIZONTAL
  gap = hdpx(2)
  children = [
    statusIconWarning
    mkWeaponRow(soldierInfo, weaponColor, group, override)
  ]
}

function soldierName(soldierInfo, nameColor, group) {
  let { guid = "", callname = "" } = soldierInfo
  return guid == "" ? null : {
    size = [flex(), SIZE_TO_CONTENT]
    valign = ALIGN_CENTER
    flow = FLOW_HORIZONTAL
    gap = gap
    children = [
      mkSoldierMedalIcon(soldierInfo, hdpx(16))
      autoscrollText({
        group = group
        text = callname != "" ? callname : getObjectName(soldierInfo)
        color = nameColor
      })
    ]
  }
}

let mkSoldierInfoBlock = function(soldierInfo, nameColor, weaponRow, group,
  _isFreemiumMode, _thresholdColor, expToLevel) {
  let { maxLevel = 1, level = 1 } = soldierInfo
  return {
    size = flex()
    flow = FLOW_VERTICAL
    valign = ALIGN_CENTER
    children = [
      soldierName(soldierInfo, nameColor, group)
      weaponRow
      withTooltip(@()
        levelBlock({
          level
          maxLevel
          fontSize = hdpx(14)
        }).__update({ margin = [gap, 0] }),
        @() experienceTooltip(calcExperienceData(soldierInfo, expToLevel)))
    ]
  }
}

function soldierCard(soldierInfo, group = null, sf = 0, isSelected = false,
  isFaded = false, isDead = false, size = slotBaseSize, isClassRestricted = false,
  hasAlertStyle = false, hasWeaponWarning = false, addChild = null, squadInfo = null,
  isDisarmed = false, isFreemiumMode = false, thresholdColor = 0, expToLevel = [],
  displayedKind = null, isGroupSelected = false
) {
  let {
    guid, photo = null, sClass = null, armyId = null, canSpawn = true
  } = soldierInfo

  let isBlocked = isDead || !canSpawn
  let isPremium = getClassCfg(sClass)?.isPremium ?? false
  let photoStyle = isFaded || isBlocked ? DISABLED_ITEM : {}
  let noWeaponTxt = loc("delivery/withoutWeapon")

  let textColor = isGroupSelected ?  @(...) selectedTxtColor
    : isBlocked ? @(...) deadTxtColor
    : isFaded ? listCtors.txtDisabledColor
    : listCtors.weaponColor

  let nameColor = isGroupSelected ?  @(...) selectedTxtColor
    : isBlocked ? @(...) deadTxtColor
    : isFaded ? listCtors.weaponColor
    : listCtors.nameColor

  let noWeaponTxtColor = isDisarmed && isGroupSelected ? selectedTxtColor : disabledTxtColor
  let weaponRow = isDisarmed ? mkWeaponRow(soldierInfo, noWeaponTxtColor,
        group, { text = noWeaponTxt })
    : (hasWeaponWarning ? mkWeaponRowWithWarning : mkWeaponRow)(soldierInfo,
        textColor(sf), group)

  return {
    key = guid
    size
    children = [
      {
        size = flex()
        flow = FLOW_HORIZONTAL
        clipChildren = true
        children = [
          {
            size = flex()
            flow = FLOW_HORIZONTAL
            gap = midPadding
            rendObj = ROBJ_SOLID
            color = listSquadColor(sf, isSelected, isGroupSelected, hasAlertStyle, isBlocked)
            children = [
              isDead ? deadIcon : mkSoldierPhoto(photo, mkPhotoSize(size[1]), null, photoStyle)
              {
                size = flex()
                children = [
                  squadInfo == null
                    ? mkSoldierInfoBlock(
                        soldierInfo,
                        nameColor(sf),
                        weaponRow,
                        group,
                        isFreemiumMode,
                        thresholdColor,
                        expToLevel
                      )
                    : mkDropSoldierInfoBlock(
                        soldierInfo,
                        squadInfo,
                        nameColor(sf),
                        textColor(sf),
                        group
                      )
                  addChild == null ? null : {
                    flow = FLOW_HORIZONTAL
                    vplace = ALIGN_BOTTOM
                    hplace = ALIGN_RIGHT
                    margin = hdpx(2)
                    children = addChild(soldierInfo, sf, isSelected)
                  }
                ]
              }
            ]
          }
          mkClassBlock(soldierInfo, isClassRestricted, isPremium, displayedKind)
        ]
      }
      isPremium ? classIcon(armyId, sClass, iconSize) : null
      {
        size = flex()
        borderWidth = isSelected ? [0,0,borderThickness,0] : 0
        rendObj = ROBJ_BOX
        fillColor = 0
      }
    ]
  }
}

return kwarg(soldierCard)
