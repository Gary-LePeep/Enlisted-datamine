from "%enlSqGlob/ui/ui_library.nut" import *

let { fontBody, fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let { defTxtColor, titleTxtColor, smallPadding, inventoryItemDetailsWidth, midPadding, totalBlack,
  defItemBlur, transpDarkPanelBgColor, largePadding
} = require("%enlSqGlob/ui/designConst.nut")
let { statusTier, statusHintText, statusIconCtor } = require("%enlSqGlob/ui/itemPkg.nut")
let { getItemName, getItemTypeName } = require("%enlSqGlob/ui/itemsInfo.nut")
let { itemTypeIcon } = require("itemTypesData.nut")
let mkItemLevelData = require("%enlist/soldiers/model/mkItemLevelData.nut")
let { mkItemDescription, mkVehicleDetails, mkItemDetails, mkUpgrades, BASE_COLOR
} = require("itemDetailsPkg.nut")
let { configs } = require("%enlist/meta/configs.nut")
let { mkSpecialItemIcon } = require("%enlSqGlob/ui/mkSpecialItemIcon.nut")
let { campPresentation, needFreemiumStatus } = require("%enlist/campaigns/campaignConfig.nut")
let { inventoryItems } = require("%enlist/soldiers/model/selectItemState.nut")
let { makeVertScroll } = require("%ui/components/scrollbar.nut")
let { mkBattleRating } = require("%enlSqGlob/ui/battleRatingPkg.nut")
let { detailsModeCheckbox, isDetailsFull } = require("%enlist/items/detailsMode.nut")

let animations = [
  { prop = AnimProp.opacity, from = 0, to = 1, duration = 0.3, easing = OutCubic,
    play = true, trigger = "itemDetailsAnim"}
  { prop = AnimProp.translate, from =[0, hdpx(100)], to = [0, 0], duration = 0.15, easing = OutQuad,
    play = true, trigger = "itemDetailsAnim"}
]

let inStockInfo = @(item) function() {
  let count = inventoryItems.value?[item.basetpl].count ?? 0
  return count < 1 ? { watch = inventoryItems } : {
    watch = inventoryItems
    hplace = ALIGN_RIGHT
    children = {
      rendObj = ROBJ_TEXT
      maxWidth = inventoryItemDetailsWidth
      halign = ALIGN_RIGHT
      text = loc("itemCurrentCount", { count })
      color = BASE_COLOR
    }.__update(fontSub)
  }
}

let lockedInfo = @(demands) {
  size = [inventoryItemDetailsWidth, SIZE_TO_CONTENT]
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  hplace = ALIGN_RIGHT
  children = [
    statusHintText(demands)
    statusIconCtor(demands)
  ]
}

let mkInfoRow = @(text, value) {
  rendObj = ROBJ_TEXT
  maxWidth = inventoryItemDetailsWidth
  halign = ALIGN_RIGHT
  text = $"{text}: {value}"
  color = defTxtColor
}.__update(fontSub)

let mkSlotIncreaseInfo = @(item) function() {
  let res = { watch = configs }
  let incInfo = {}
  foreach (slotType, tplsList in configs.value?.equip_slot_increase ?? {})
    if (item.basetpl in tplsList)
      incInfo[slotType] <- tplsList[item.basetpl]
  if (incInfo.len() == 0)
    return res
  return res.__update({
    flow = FLOW_VERTICAL
    halign = ALIGN_RIGHT
    children = incInfo
      .map(@(count, slotType) mkInfoRow(loc($"itemDetails/slotsIncrease/{slotType}"), count))
      .values()
  })
}

let mkAmmoIncreaseInfo = @(item) function() {
  let res = { watch = configs }
  let value = configs.value?.equip_ammo_increase[item.basetpl] ?? 0
  if (value == 0)
    return res
  let perc = (100.0 * value + 0.5).tointeger()
  return mkInfoRow(loc("itemDetails/ammoIncrease"), $"+{perc}%")
}

let itemTitle = @(item, maxWidth) {
  maxWidth
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  hplace = ALIGN_RIGHT
  text = getItemName(item)
  color = titleTxtColor
}.__update(fontBody)

let detailsStatusTier = @(item) @() {
  watch = [needFreemiumStatus, campPresentation]
  children = statusTier(
    item,
    mkItemLevelData(item),
    needFreemiumStatus.value,
    campPresentation.value?.color,
    @(v) v
  )
}

local lastTpl = null

let mkRow = @(children) {
  flow = FLOW_HORIZONTAL
  gap = smallPadding
  valign = ALIGN_CENTER
  children = children
}

function mkTypeIcon(itemtype, itemsubtype) {
  if (itemtype == null)
    return null

  let children = itemTypeIcon(itemtype, itemsubtype)
  return children == null ? null
    : {
        size = [hdpx(30), hdpx(30)]
        margin = smallPadding
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        vplace = ALIGN_BOTTOM
        rendObj = ROBJ_VECTOR_CANVAS
        commands = [[ VECTOR_ELLIPSE, 50, 50, 50, 50 ]]
        fillColor = totalBlack
        color = totalBlack
        children
      }
}

function mkItemHeader(item, isFull) {
  let isVehicle = item?.itemtype == "vehicle"
  let specialIcon = mkSpecialItemIcon(item, hdpxi(27))
  let titleWidth = inventoryItemDetailsWidth * (isFull ? 1 : 0.92) - ((specialIcon != null)
    ? hdpx(57) : hdpx(27))
  local typeLoc = getItemTypeName(item)
  typeLoc = typeLoc == "" ? null
    : {
      rendObj = ROBJ_TEXT
      text = typeLoc
      color = BASE_COLOR
    }.__update(fontSub)
  let itemType = isVehicle ? item?.itemsubtype : item?.itemtype
  let { growthTier = 0 } = item
  return {
    flow = FLOW_VERTICAL
    size = [flex(), SIZE_TO_CONTENT]
    children = [
      {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        gap = { size = flex() }
        valign = ALIGN_CENTER
        children = [
          mkRow([
            specialIcon
            mkTypeIcon(itemType, null)
          ])
          {
            flow = FLOW_VERTICAL
            halign = ALIGN_RIGHT
            gap = smallPadding
            children = [
              typeLoc
              detailsStatusTier(item)
            ]
          }
        ]
      }
      itemTitle(item, titleWidth)
      mkBattleRating(growthTier, { size = [flex(), SIZE_TO_CONTENT ]})
      inStockInfo(item)
    ]
  }
}


function setlastTpl(item) {
  let tpl = item?.basetpl
  if (lastTpl != tpl)
    lastTpl = tpl
  if (!tpl)
    return null

  anim_start("itemDetailsAnim")
  return tpl
}

let panelStyle = {
  rendObj = ROBJ_WORLD_BLUR_PANEL
  fillColor = transpDarkPanelBgColor
  flow = FLOW_VERTICAL
  halign = ALIGN_RIGHT
  gap = largePadding
  transform = {}
  animations = animations
}

let contentStyle = {
  color = defItemBlur
  flow = FLOW_VERTICAL
  halign = ALIGN_RIGHT
  gap = midPadding
  padding = midPadding
  size = [inventoryItemDetailsWidth, SIZE_TO_CONTENT]
  valign = ALIGN_BOTTOM
}

function mkViewDetailsContent(item, isFull) {
  let isVehicle = item?.itemtype == "vehicle"
  return isVehicle
    ? [
        mkItemHeader(item, isFull)
        isFull ? mkItemDescription(item) : null
        mkVehicleDetails(item)
        mkUpgrades(item, isFull)
      ]
    : [
        mkItemHeader(item, isFull)
        isFull ? mkItemDescription(item) : null
        mkSlotIncreaseInfo(item)
        mkAmmoIncreaseInfo(item)
        mkItemDetails(item, isFull)
        mkUpgrades(item, isFull)
      ]
}

let briefChildrenComp = @(item) {
  children = {
    vplace = ALIGN_BOTTOM
    children = mkViewDetailsContent(item, false)
  }.__update(contentStyle)
}

let fullChildrenCompWithScroll = @(item, maxHeight)
  makeVertScroll({
    vplace = ALIGN_TOP
    children = mkViewDetailsContent(item, true)
  }.__update(contentStyle), {
    size = SIZE_TO_CONTENT
    maxHeight
  })

let mkViewItemWatchDetails = @(viewItemWatch, maxHeight = SIZE_TO_CONTENT) function() {
  let res = { watch = viewItemWatch }
  let item = viewItemWatch.value
  let tpl = setlastTpl(item)
  if (!tpl)
    return res

  return res.__update({
    key = tpl
    children = fullChildrenCompWithScroll(item, maxHeight)
  }.__update(panelStyle))
}

function mkViewDetailsBrief(item) {
  let tpl = setlastTpl(item)
  if (!tpl)
    return null
  return {
    key = tpl
    children = briefChildrenComp(item)
  }.__update(panelStyle)
}

function mkViewDetailsFull(item, maxHeight = SIZE_TO_CONTENT) {
  let tpl = setlastTpl(item)
  if (!tpl)
    return null
  return {
    key = tpl
    children = fullChildrenCompWithScroll(item, maxHeight)
  }.__update(panelStyle)
}

function mkViewDetailsSwitchable(item, maxHeight = SIZE_TO_CONTENT) {
  let tpl = setlastTpl(item)
  if (!tpl)
    return null
  return {
    key = tpl
    children = [
      @() isDetailsFull.value
        ? {
            watch = isDetailsFull
            children = fullChildrenCompWithScroll(item, maxHeight)
          }
        : {
            watch = isDetailsFull
            children = briefChildrenComp(item)
          }
      {
        padding = [0, midPadding]
        children = detailsModeCheckbox
      }
    ]
  }.__update(panelStyle)
}

return {
  mkViewDetailsSwitchable
  mkViewDetailsFull
  mkViewDetailsBrief
  mkViewItemWatchDetails
  lockedInfo
  detailsStatusTier
  mkTypeIcon
}
