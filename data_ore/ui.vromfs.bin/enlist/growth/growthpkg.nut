from "%enlSqGlob/ui/ui_library.nut" import *

let { fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let {
  titleTxtColor, smallPadding, bigPadding, defTxtColor, defSlotBgColor, midPadding
} = require("%enlSqGlob/ui/designConst.nut")
let { kindIcon } = require("%enlSqGlob/ui/soldiersUiComps.nut")
let { newSquadBlock, starterPerkBlock, primePerkBlock
} = require("%enlist/soldiers/mkSquadPromo.nut")
let { mkViewDetailsBrief } = require("%enlist/soldiers/components/itemDetailsComp.nut")
let { mkShopItem } = require("%enlist/soldiers/model/items_list_lib.nut")
let { getClassCfg } = require("%enlSqGlob/ui/soldierClasses.nut")
let { getItemName, iconByGameTemplate } = require("%enlSqGlob/ui/itemsInfo.nut")
let { itemTypeIcon } = require("%enlist/soldiers/components/itemTypesData.nut")
let { Bordered } = require("%ui/components/txtButton.nut")
let { openUnlockSquadScene } = require("%enlist/soldiers/unlockSquadScene.nut")
let viewItemsScene = require("%enlist/shop/viewItemsScene.nut")
let { GrowthStatus } = require("growthState.nut")
let { mkTierStars } = require("%enlSqGlob/ui/itemTier.nut")


let detailsDescStyle = freeze({ color = defTxtColor }.__update(fontSub))
let headerTitleStyle = freeze({ color = titleTxtColor }.__update(fontSub))

let bigIconSize = hdpxi(32)
let itemImgStyle = { width = hdpxi(300), height = hdpxi(150) }
let relationIconSize = [hdpxi(24), hdpxi(24)]
let squadIconSize = [hdpxi(30), hdpxi(18)]
let elemBarSize = [hdpxi(218), hdpxi(80)]

let templateSize = {
  width = elemBarSize[0] - midPadding * 2
  height = elemBarSize[1] - midPadding * 2
}


let mkText = @(text, style = {}) {
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  size = [flex(), SIZE_TO_CONTENT]
  color = titleTxtColor
  text
}.__update(fontSub, style)


function mkSquadDescBlock(squad, armyId) {
  let { newClass, newPerk = null, isPrimeSquad = false } = squad
  let { descLocId, shortLocId } = getClassCfg(newClass)
  return {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    vplace = ALIGN_CENTER
    gap = bigPadding
    children = [
      newSquadBlock(armyId, newClass)
      starterPerkBlock(armyId, newPerk)
      isPrimeSquad
        ? primePerkBlock(loc(descLocId))
        : mkText(loc(shortLocId))
    ]
  }
}


function mkSquadDetails(data, classesCfg, squadsById, cb = @() null) {
  let { squad, armyId } = data
  let {
    nameLocId, titleLocId, image, id, newClass = null,
    itemType = null, itemSubType = null
  } = squad
  let squadCfg = squadsById?[armyId][id]
  return {
    size = flex()
    flow = FLOW_VERTICAL
    gap = bigPadding
    children = [
      {
        size = [flex(), hdpxi(270)]
        valign = ALIGN_BOTTOM
        children = [
          {
            size = flex()
            rendObj = ROBJ_IMAGE
            image = Picture(image)
            keepAspect = KEEP_ASPECT_FILL
            imageValign = ALIGN_TOP
          }
          {
            size = [flex(), SIZE_TO_CONTENT]
            flow = FLOW_HORIZONTAL
            gap = smallPadding
            padding = smallPadding
            valign = ALIGN_CENTER
            children = [
              newClass == null
                ? itemTypeIcon(itemType, itemSubType, {
                    size = [hdpxi(bigIconSize), hdpxi(bigIconSize)]
                  })
                : kindIcon(classesCfg?[newClass].kind ?? newClass,
                    hdpxi(bigIconSize), null, defTxtColor)
              {
                size = [flex(), SIZE_TO_CONTENT]
                flow = FLOW_VERTICAL
                children = [
                  mkText(loc(titleLocId), headerTitleStyle)
                  mkText(loc(nameLocId), detailsDescStyle)
                ]
              }
            ]
          }
        ]
      }
      mkSquadDescBlock(squad, armyId)
      Bordered(loc("btn/view"), function() {
        openUnlockSquadScene({
          armyId, squad, squadCfg, unlockInfo = { hasTestDrive = true }
        }, KWARG_NON_STRICT)
        cb()
      })
    ]
  }
}

function mkItemDetails(data, cb = @() null) {
  let { item, itemTemplate, armyId } = data
  let itemDetails = mkShopItem(itemTemplate, item, armyId)
  return {
    size = flex()
    flow = FLOW_VERTICAL
    gap = bigPadding
    children = [
      {
        size = [flex(), SIZE_TO_CONTENT]
        rendObj = ROBJ_SOLID
        color = defSlotBgColor
        children = iconByGameTemplate(item.gametemplate, itemImgStyle)
      }
      mkViewDetailsBrief(itemDetails)
      Bordered(loc("btn/view"), function() {
        viewItemsScene(itemDetails)
        cb()
      })
    ]
  }
}


function mkGrowthRewardsText(reward, templates, squads) {
  let { itemTemplate = null, squadId = null } = reward
  if (itemTemplate == null && squadId == null)
    return []

  let item = templates?[itemTemplate]
  let squad = squads?[squadId]
  let res = []
  if (item != null)
    res.append(getItemName(item))
  if (squad != null)
    res.append(loc(squad.titleLocId))

  return res
}



let relationsIcon = @(status, color) {
  rendObj = ROBJ_IMAGE
  size = relationIconSize
  hplace = ALIGN_RIGHT
  keepAspect = KEEP_ASPECT_FIT
  margin = smallPadding
  image = Picture("!ui/squads/angle_icon.svg:{0}:{1}:K"
    .subst(relationIconSize[0], relationIconSize[1]))
  color
  opacity = status == GrowthStatus.UNAVAILABLE ? 0.7 : 1
}


let squadIcon = @(color) {
  rendObj = ROBJ_IMAGE
  size = squadIconSize
  hplace = ALIGN_RIGHT
  vplace = ALIGN_BOTTOM
  keepAspect = KEEP_ASPECT_FIT
  margin = [0, 0, smallPadding, 0]
  image = Picture("!ui/squads/squad_icon.svg:{0}:{1}:K".subst(squadIconSize[0], squadIconSize[1]))
  color
}


function mkGrowthInfo(item, squad, status, elemsColor, curRelations) {
  let { tier = 0, gametemplate = "" } = item
  let imgStyle = status != GrowthStatus.UNAVAILABLE ? {} : { picSaturate = 0, opacity = 0.7 }
  let itemIcon = iconByGameTemplate(gametemplate, imgStyle.__update(templateSize))
  return {
    size = flex()
    padding = smallPadding
    children = [
      itemIcon
      mkTierStars(tier, { fontSize = hdpxi(12) }
        .__update({
          color = elemsColor
          hplace = ALIGN_CENTER
          margin = curRelations == null ? 0 : [0,relationIconSize[0],0,0]
        }))
      squad == null ? null : squadIcon(elemsColor)
    ]
  }
}


let mkGrowthSlotElems = @(elemsColor, status, item, squad, curRelations = null) {
  size = flex()
  children = [
    curRelations == null ? null : relationsIcon(status, elemsColor)
    mkGrowthInfo(item, squad, status, elemsColor, curRelations)
  ]
}


let tierColor = 0xFF292F38
let tierProgressColor = 0xFFFBB01C

let mkTierObject = @(progress, leftObj = null, rightObj = null) {
  size = flex()
  flow = FLOW_HORIZONTAL
  children = [
    {
      size = flex()
      rendObj = ROBJ_SOLID
      color = tierColor
      children = [
        {
          size = [pw(min(progress * 100, 100)), flex()]
          rendObj = ROBJ_SOLID
          color = tierProgressColor
        }
        {
          size = flex()
          padding = [0, midPadding]
          valign = ALIGN_CENTER
          children = [
            leftObj
            rightObj
          ]
        }
      ]
    }
    {
      size = [ph(50), flex()]
      rendObj = ROBJ_IMAGE
      image = Picture($"!ui/uiskin/progress_bar_tail.svg:{30}:{60}:K")
      color = progress < 1 ? tierColor : tierProgressColor
    }
  ]
}


return {
  mkSquadDetails
  mkItemDetails
  mkGrowthRewardsText
  mkGrowthSlotElems
  mkTierObject
  elemBarSize
}
