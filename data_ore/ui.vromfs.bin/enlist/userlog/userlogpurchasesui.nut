from "%enlSqGlob/ui/ui_library.nut" import *

let { purchaseUserLogs, UserLogType } = require("userLogState.nut")
let { mkUserLogHeader, mkRowText, rowStyle, userLogStyle, userLogRowStyle
} = require("userLogPkg.nut")
let { shopItems } = require("%enlist/shop/shopItems.nut")
let { allItemTemplates } = require("%enlist/soldiers/model/all_items_templates.nut")
let { utf8ToUpper } = require("%sqstd/string.nut")
let { detailsStatusTier } = require("%enlist/soldiers/components/itemDetailsComp.nut")
let { getItemName } = require("%enlSqGlob/ui/itemsInfo.nut")
let { getClassCfg } = require("%enlSqGlob/ui/soldierClasses.nut")
let { accentColor, smallPadding, defTxtColor, hoverSlotBgColor, panelBgColor, selectedPanelBgColor,
  accentTitleTxtColor
} = require("%enlSqGlob/ui/designConst.nut")

let selectedIdx = Watched(0)


function mkReceivedItem(row, allTpl) {
  let { armyId, baseTpl, count } = row
  let template = allTpl?[armyId][baseTpl]
  if (template == null)
    return null

  return {
    children = [
      mkRowText(loc("listWithDot", { text = getItemName(template) }), defTxtColor)
      detailsStatusTier(template)
      count <= 1 ? null : mkRowText(loc("common/amountShort", { count }), accentTitleTxtColor)
    ]
  }.__update(rowStyle)
}

function mkReceivedSoldier(row, _allTpl = null) {
  let { name, surname, sClass } = row
  let { locId } = getClassCfg(sClass)
  return {
    children = [
      mkRowText(loc("listWithDot", { text = $"{loc(name)} {loc(surname)}" }), defTxtColor)
      mkRowText(loc(locId), accentTitleTxtColor)
    ]
  }.__update(rowStyle)
}

function mkReceivedPremium(row, _allTpl = null) {
  let { count } = row
  return {
    children = [
      mkRowText(loc("listWithDot", { text = loc("premium/title") }), defTxtColor)
      mkRowText("{0} {1}".subst(count, loc("premiumDays", { days = count })),
        accentTitleTxtColor)
    ]
  }.__update(rowStyle, { gap = smallPadding })
}

function mkReceivedWallposter(row, _allTpl = null) {
  let { wallposterId, armyId } = row
  return {
    children = [
      mkRowText(loc("listWithDot", { text = loc("userLogRow/wallposter") }), defTxtColor)
      mkRowText("{0} ({1})".subst(loc($"wp/{wallposterId}/name"), loc(armyId)),
        accentTitleTxtColor)
    ]
  }.__update(rowStyle, { gap = smallPadding })
}

let purchaseRowView = {
  [UserLogType.PURCH_ITEM] = mkReceivedItem,
  [UserLogType.PURCH_SOLDIER] = mkReceivedSoldier,
  [UserLogType.PURCH_PREMDAYS] = mkReceivedPremium,
  [UserLogType.PURCH_WALLPOSTER] = mkReceivedWallposter,
  [UserLogType.PURCH_BONUS] = null
}

let mkPurchaseLogRows = @(uLogRows, allTpl) {
  children = uLogRows.map(@(row) purchaseRowView?[row?.logType](row, allTpl))
}.__update(userLogRowStyle)

function mkPurchaseLog(uLog, shopItem, allTpl, isSelected, sf) {
  let { nameLocId = "Undefined" } = shopItem
  let shortItemTitle = utf8ToUpper(loc(nameLocId).split("\r\n")?[0] ?? "")
  return {
    children = [
      mkUserLogHeader(isSelected, uLog.logTime,
        loc("userLog/purchase", {
          name = shortItemTitle
        }), sf)
      isSelected && uLog?.rows ? mkPurchaseLogRows(uLog.rows, allTpl) : null
    ]
  }.__update(userLogStyle)
}
function mkLog(uLog, idx, sItems, allTpl) {
  let shopItem = sItems?[uLog.shopItemId]
  if (shopItem == null)
    return null

  let isSelected = Computed(@() idx == selectedIdx.value)
  return watchElemState(@(sf) {
    rendObj = ROBJ_BOX
    watch = isSelected
    size = [flex(), SIZE_TO_CONTENT]
    behavior = Behaviors.Button
    onClick = @() selectedIdx(idx)
    xmbNode = XmbNode()
    borderColor = accentColor
    fillColor = sf & S_HOVER ? hoverSlotBgColor
      : isSelected.value ? selectedPanelBgColor
      : panelBgColor
    borderWidth = isSelected.value ? [0, 0, hdpx(2), 0] : 0
    children = mkPurchaseLog(uLog, shopItem, allTpl, isSelected.value, sf)
  })
}

return function() {
  let sItems = shopItems.value
  let allTpl = allItemTemplates.value
  return {
    watch = [purchaseUserLogs, shopItems, allItemTemplates]
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = hdpx(2)
    //gap = bigPadding
    xmbNode = XmbContainer({
      canFocus = false
      wrap = false
      scrollSpeed = 10.0
      isViewport = true
    })
    children = purchaseUserLogs.value.map(@(uLog, idx) mkLog(uLog, idx, sItems, allTpl))
  }
}
