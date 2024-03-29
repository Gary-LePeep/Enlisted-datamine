from "%enlSqGlob/ui/ui_library.nut" import *

let { fontBody, fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let faComp = require("%ui/components/faComp.nut")
let msgbox = require("%ui/components/msgbox.nut")
let textButtonTextCtor = require("%ui/components/textButtonTextCtor.nut")
let { mkShopItemPrice } = require("mkShopItemPrice.nut")
let spinner = require("%ui/components/spinner.nut")
let { itemTypeIcon } = require("%enlist/soldiers/components/itemTypesData.nut")
let { getClassCfg, getKindCfg, soldierKindsList } = require("%enlSqGlob/ui/soldierClasses.nut")
let { txt } = require("%enlSqGlob/ui/defcomps.nut")
let { trimUpgradeSuffix, getItemName } = require("%enlSqGlob/ui/itemsInfo.nut")
let { scrollToCampaignLvl, curArmySquadsUnlocks
} = require("%enlist/soldiers/model/armyUnlocksState.nut")
let { jumpToArmyProgress, jumpToArmyGrowth, jumpToArmyGrowthTier
} = require("%enlist/mainMenu/sectionsState.nut")
let getEquipClasses = require("%enlist/soldiers/model/equipClassSchemes.nut")
let { defBgColor, midPadding, smallPadding, defTxtColor, warningColor, idleBgColor,
  soldierLvlColor, disabledTxtColor, mkTimerIcon
} = require("%enlSqGlob/ui/designConst.nut")
let { kindIcon } = require("%enlSqGlob/ui/soldiersUiComps.nut")
let { TextHover, TextNormal, textMargin
} = require("%ui/components/textButton.style.nut")
let { mkSquadIcon } = require("%enlSqGlob/ui/squadsUiComps.nut")
let { armySquadsById, lockedArmySquadsById } = require("%enlist/soldiers/model/state.nut")
let allowedVehicles = require("%enlist/vehicles/allowedVehicles.nut")
let { mkDiscountWidget } = require("%enlist/shop/currencyComp.nut")
let serverTime = require("%enlSqGlob/userstats/serverTime.nut")
let { secondsToHoursLoc } = require("%ui/helpers/time.nut")
let { mkCounter } = require("%enlist/shop/mkCounter.nut")
let { shopItemContentCtor } = require("%enlist/shop/armyShopState.nut")
let { curArmyReserve, curArmyReserveCapacity } = require("%enlist/soldiers/model/reserve.nut")
let { mkIconBar } = require("%enlSqGlob/ui/itemTier.nut")
let { allItemTemplates } = require("%enlist/soldiers/model/all_items_templates.nut")
let { mkRightHeaderFlag, primeFlagStyle } = require("%enlSqGlob/ui/mkHeaderFlag.nut")
let { mkBpIcon } = require("%enlSqGlob/ui/mkSpecialItemIcon.nut")
let { getTierInterval } = require("shopPackage.nut")
let { getRomanNumeral } = require("%sqstd/math.nut")
let { GrowthStatus } = require("%enlist/growth/growthState.nut")


let PRICE_HEIGHT = hdpx(48)

const DISCOUNT_WARN_TIME = 600

let cardPreviewSize = [fsh(45), fsh(30)]
let cardSquadPreviewSize = [fsh(60), fsh(30)]
let timerSize = fontSub.fontSize

let mkPurchaseSpinner = @(shopItem, purchasingItem) @() {
  watch = purchasingItem
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  children = purchasingItem.value == shopItem ? spinner(hdpx(40), 0.7) : null
}

let mkShopItemImg = @(img, override = {}) (img ?? "").len()  == 0 ? null
  : {
      rendObj = ROBJ_IMAGE
      size = flex()
      keepAspect = KEEP_ASPECT_FILL
      image = Picture(img)
    }.__update(override)

let mkShopItemVideo = @(uri) {
  size = flex()
  keepAspect = KEEP_ASPECT_FILL
  rendObj = ROBJ_MOVIE
  movie = uri
  behavior = Behaviors.Movie
}

let shopBottomLine = {
  rendObj = ROBJ_SOLID
  size = [flex(), PRICE_HEIGHT]
  color = Color(40,40,40,255)
  valign = ALIGN_CENTER
}

let lockIcon = faComp("lock", { fontSize = hdpx(20), color = defTxtColor })

let mkLevelLockLine = @(level) shopBottomLine.__merge({
  padding = [0, fsh(2)]
  children = [
    lockIcon
    {
      rendObj = ROBJ_TEXT
      hplace = ALIGN_RIGHT
      color = defTxtColor
      text = loc("levelInfo", { level })
    }.__update(fontSub)
  ]
})

function mkShopItemPriceLine(shopItem, personalOffer = null, isNarrow = false) {
  let children = mkShopItemPrice(shopItem, personalOffer, isNarrow)
  return !children ? null : shopBottomLine.__merge({ children })
}

let itemHighlight = @(trigger){
  size = flex()
  rendObj = ROBJ_BOX
  borderWidth = hdpx(8)
  borderColor = 0xFFFFFF
  opacity = 0
  transform = {}
  animations = [
    { prop = AnimProp.opacity, from = 0, to = 1, duration = 1, trigger, easing = Blink }
    { prop = AnimProp.opacity, from = 0, to = 1, duration = 1, delay = 1, trigger, easing = Blink }
    { prop = AnimProp.opacity, from = 0, to = 1, duration = 1, delay = 2, trigger, easing = Blink }
  ]
}

let infoBtnSize = hdpxi(30)
let hoveredInfoBtnSize = hdpxi(33)

let mkInfoBtn = @(onClick) watchElemState(function(sf) {
  let size = sf & S_HOVER ? hoveredInfoBtnSize : infoBtnSize
  return {
    hplace = ALIGN_LEFT
    margin = fsh(1)
    behavior = Behaviors.Button
    onClick
    children = {
      rendObj = ROBJ_IMAGE
      size = array(2, size)
      image = Picture($"ui/skin#info/info_icon.svg:{size}:{size}:K")
    }
  }
})

let mkViewCrateBtn = @(crateContentWatch, onCrateViewCb)
  crateContentWatch == null || onCrateViewCb == null ? null
    : @() {
        watch = crateContentWatch
        hplace = ALIGN_LEFT
        children = (crateContentWatch.value?.content.items ?? {}).len() == 0 ? null
          : mkInfoBtn(onCrateViewCb)
      }

function extractItems(crateContent) {
  let { items = {} } = crateContent?.value.content
  let res = {}
  foreach (tmpl, _ in items)
    res[trimUpgradeSuffix(tmpl)] <- true
  return res.keys()
}

function extractClasses(crateContent) {
  let { soldierClasses = [] } = crateContent?.value.content
  let res = {}
  foreach (sClass in soldierClasses)
    res[getClassCfg(sClass).kind] <- true
  return res.keys()
}

let mkForVehicleSquad = @(squad, unlockLevel) {
  size = [hdpx(300), SIZE_TO_CONTENT]
  flow = FLOW_HORIZONTAL
  hplace = ALIGN_CENTER
  gap = midPadding
  valign = ALIGN_CENTER
  children = [
    mkSquadIcon(squad?.icon, { size = [hdpx(80), hdpx(80)], margin = smallPadding })
    {
      size = [flex(), SIZE_TO_CONTENT]
      valign = ALIGN_CENTER
      halign = ALIGN_LEFT
      flow = FLOW_VERTICAL
      gap = midPadding
      children = [
        {
          rendObj = ROBJ_TEXTAREA
          size = [flex(), SIZE_TO_CONTENT]
          behavior = Behaviors.TextArea
          color = defTxtColor
          text = loc(squad?.manageLocId ?? "")
        }.__update(fontBody)
        unlockLevel == 0 ? null : {
          flow = FLOW_HORIZONTAL
          gap = midPadding
          valign = ALIGN_BOTTOM
          children = [
            faComp("lock", { fontSize = fontSub.fontSize, color = warningColor })
            txt({
              text = loc("level/short", { level = unlockLevel })
              color = warningColor
            }.__update(fontSub))
          ]
        }
      ]
    }
  ]
}

let mkSquadUsageKind = function(squadId, armyId) {
  local squad = armySquadsById.value?[armyId][squadId]
  local unlockLevel = 0
  if (!squad){
    squad = lockedArmySquadsById.value?[armyId][squadId]
    unlockLevel = (curArmySquadsUnlocks.value ?? {})
      .findvalue(@(s) s.unlockId == squadId)?.level ?? 0
  }

  return !squad ? null : {
    rendObj = ROBJ_SOLID
    size = [flex(), SIZE_TO_CONTENT]
    padding = midPadding
    color = defBgColor
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    children = mkForVehicleSquad(squad, unlockLevel)
  }
}


function mkClassCanUse(itemtype, armyId, itemtmpl) {
  if (itemtype == "vehicle"){
    let vehicleSquadIds = (allowedVehicles.value?[armyId] ?? {})
      .filter(@(squad) squad?[itemtmpl]).keys()
    let squadsCount = vehicleSquadIds.len()
    return squadsCount == 0 ? null : {
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      halign = ALIGN_CENTER
      gap = smallPadding
      children = [
        {
          rendObj = ROBJ_TEXTAREA
          behavior = Behaviors.TextArea
          halign = ALIGN_CENTER
          size = [flex(), SIZE_TO_CONTENT]
          text = loc("shop/squadsCanUse", { squadsCount })
        }.__update(fontBody)
      ].extend(vehicleSquadIds.map(@(squadId) mkSquadUsageKind(squadId, armyId)))
    }
  }

  let kindsList = getEquipClasses(armyId, itemtmpl, itemtype)
    .reduce(function(tbl, sClass) {
      let { kind, isPremium = false, isEvent = false } = getClassCfg(sClass)
      if (!isPremium && !isEvent)
        tbl[kind] <- true
      return tbl
    }, {})
    .keys()
  let count = kindsList.len()
  if (count == 0)
    return null
  let tShopCanUse = count == soldierKindsList.len()
    ? loc("shop/allCanUse")
    : loc("shop/someCanUse",
      {classes = ", ".join(kindsList.map(@(sKind) loc(getKindCfg(sKind).locId)))})
  return {
    rendObj = ROBJ_TEXTAREA
    behavior = Behaviors.TextArea
    size = [flex(), SIZE_TO_CONTENT]
    text = tShopCanUse
  }
}

let mkClassCanUseCenter = @(crateContent) function() {
  let res = { watch = [allItemTemplates, crateContent] }
  let itemsList = extractItems(crateContent) ?? []
  if (itemsList.len() != 1)
    return res

  let { armyId = null } = crateContent.value
  let templates = allItemTemplates.value?[armyId]
  let itemtmpl = itemsList[0]
  let { itemtype = null } = templates?[itemtmpl]
  return res.__update(mkClassCanUse(itemtype, armyId, itemtmpl) ?? {}, {halign = ALIGN_CENTER})
}

let mkShopItemInfoTier = @(minTier, maxTier, override = {})
  maxTier <= 0 || maxTier <= minTier ? null
    : {
        rendObj = ROBJ_TEXTAREA
        size = [flex(), SIZE_TO_CONTENT]
        behavior = Behaviors.TextArea
        text = loc("shop/upgradeLevel", { maxUpgrade = maxTier, minUpgrade = minTier })
      }.__update(fontSub, override)

let mkShopItemInfoBlock = @(crateContent) function() {
  let res = { watch = [allItemTemplates, crateContent] }
  let itemsList = extractItems(crateContent) ?? []
  if (itemsList.len() != 1)
    return res

  let { armyId = null } = crateContent.value
  let templates = allItemTemplates.value?[armyId]
  let itemtmpl = itemsList[0]
  let { itemtype = null } = templates?[itemtmpl]
  let { minTier, maxTier } = getTierInterval(crateContent?.value.content.items, templates)
  return res.__update({
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    hplace = ALIGN_CENTER
    padding = [smallPadding, 0]
    children = [
      mkShopItemInfoTier(minTier, maxTier)
      mkClassCanUse(itemtype, armyId, itemtmpl)
    ]
  })
}

let mkTitle = @(text, minAmount, maxAmount, isBundle) {
  flow = FLOW_HORIZONTAL
  size = [flex(), SIZE_TO_CONTENT]
  valign = ALIGN_CENTER
  gap = smallPadding
  children = [
    {
      rendObj = ROBJ_TEXTAREA
      size = [flex(), SIZE_TO_CONTENT]
      behavior = Behaviors.TextArea
      text
    }.__update(fontBody)
    minAmount <= 1 || isBundle ? null : {
      rendObj = ROBJ_TEXT
      text = minAmount == maxAmount ? $"×{minAmount}" : $"×{minAmount}-{maxAmount}" // TODO use localization for multipliers
    }.__update(fontBody)
  ]
}

let mkSubtitle = @(text) text == "" ? null : {
  rendObj = ROBJ_TEXTAREA
  size = [flex(), SIZE_TO_CONTENT]
  behavior = Behaviors.TextArea
  text
}.__update(fontSub)

function getMaxCount(shopItem) {
  let { limit = 0, premiumDays = 0, squads = [] } = shopItem
  let isSoldier = (shopItemContentCtor(shopItem)?.value.content.soldierClasses.len() ?? 0) > 0
  return limit > 0 ||  premiumDays > 0 || squads.len() > 0 ? 1
    : isSoldier ? min(99, max(curArmyReserveCapacity.value - curArmyReserve.value.len(), 0))
    : 99
}

// fast temporary solution
function mkSeasonBpIcon(shopItem){
  let { offerGroup = null } = shopItem
  return  offerGroup != "weapon_battlepass_group" ? null
    : mkBpIcon()
}

function mkShopItemTitle(
  shopItem, crateContent, itemTemplates, showDiscount, countWatched = null
) {
  let { armyId = null, content = {} } = crateContent?.value
  local shopIcon
  local seasonBpIcon = mkSeasonBpIcon(shopItem)
  let itemsList = extractItems(crateContent) ?? []
  if (itemsList.len() == 1) {
    let { itemtype = null, itemsubtype = null } = itemTemplates.value?[armyId][itemsList[0]]
    shopIcon = itemTypeIcon(itemtype, itemsubtype)
  }

  let soldierClasses = extractClasses(crateContent) ?? []
  if (soldierClasses.len() == 1)
    shopIcon = kindIcon(soldierClasses[0], hdpx(22))

  let titleLoc = shopItem?.nameLocId ?? ""
  let titleText = loc(titleLoc)
  let subtitleText = loc($"{titleLoc}/subtitle", "")
  let itemMinAmount = content?.itemsAmount.x ?? 0
  let itemMaxAmount = content?.itemsAmount.y ?? 0
  let isBundle = (shopItem?.crates ?? []).len() > 1
  let maxCount = getMaxCount(shopItem)
  return {
    rendObj = ROBJ_SOLID
    size = [flex(), SIZE_TO_CONTENT]
    gap = midPadding
    padding = [0, fsh(2)]
    vplace = ALIGN_BOTTOM
    color = defBgColor
    children = [
      !showDiscount ? null
        : mkDiscountWidget(shopItem.discountInPercent, { pos = [hdpx(20), -hdpx(20)] })
      {
        size = [flex(), SIZE_TO_CONTENT]
        minHeight = fsh(6)
        flow = FLOW_HORIZONTAL
        gap = midPadding
        valign = ALIGN_CENTER
        vplace = ALIGN_BOTTOM
        children = [
          shopIcon
          seasonBpIcon
          {
            size = [flex(), SIZE_TO_CONTENT]
            flow = FLOW_VERTICAL
            children = [
              mkTitle(titleText, itemMinAmount, itemMaxAmount, isBundle)
              mkSubtitle(subtitleText)
            ]
          }
          maxCount <= 1 || countWatched == null ? null : mkCounter(maxCount, countWatched)
        ]
      }
    ]
  }
}

function mkTimeAvailable(shopItem) {
  let { showIntervalTs = [] } = shopItem
  let toTs = showIntervalTs?[1] ?? 0
  if (toTs < serverTime.value)
    return null

  return function() {
    let res = { watch = serverTime }
    let timeLeft = toTs - serverTime.value
    if (timeLeft <= 0)
      return res

    return res.__update({
      children = mkRightHeaderFlag(
        {
          flow = FLOW_HORIZONTAL
          valign = ALIGN_BOTTOM
          gap = hdpx(2)
          padding = midPadding
          children = [
            mkTimerIcon(timerSize, { color = TextNormal })
            {
              rendObj = ROBJ_TEXT
              text = secondsToHoursLoc(timeLeft)
              color = TextNormal
            }.__update(fontSub)
          ]
        },
        primeFlagStyle.__merge({ offset = 0 })
      )
    })
  }
}

let debugTag = {
  rendObj = ROBJ_SOLID
  color = 0xFFCC0000
  padding = midPadding
  children = {
    rendObj = ROBJ_TEXT
    text = "DEBUG ONLY"
  }.__update(fontSub)
}

let mkShopItemView = kwarg(@(
  shopItem, purchasingItem = null, unseenSignalObj = null, onCrateViewCb = null,
  onInfoCb = null, isLocked = false, containerIcon = null, crateContent = null,
  itemTemplates = null, showVideo = null, showDiscount = false) {
    size = flex()
    halign = ALIGN_RIGHT
    children = [
      mkShopItemImg(shopItem?.image ?? "", {
          keepAspect = KEEP_ASPECT_FILL
          imageHalign = ALIGN_CENTER
          imageValign = ALIGN_TOP
          picSaturate = isLocked ? 0.1 : 1
        }
      ),
      showVideo ? mkShopItemVideo(shopItem.video) : null,
      mkShopItemTitle(shopItem, crateContent, itemTemplates, showDiscount),
      containerIcon,
      purchasingItem == null ? null : mkPurchaseSpinner(shopItem, purchasingItem),
      {
        valign = ALIGN_CENTER
        hplace = ALIGN_RIGHT
        flow = FLOW_HORIZONTAL
        children = [
          unseenSignalObj
          mkTimeAvailable(shopItem)
        ]
      },
      onInfoCb != null ? mkInfoBtn(onInfoCb) : mkViewCrateBtn(crateContent, onCrateViewCb),
      (shopItem?.isShowDebugOnly ?? false) ? debugTag : null,
      itemHighlight(shopItem.guid)
    ]
  })

let mkProductView = @(shopItem, itemTemplates, crateContent = null) {
  rendObj = ROBJ_SOLID
  size = shopItem?.squads[0] != null ? cardSquadPreviewSize : cardPreviewSize
  padding = hdpx(1)
  color = idleBgColor
  clipChildren = true
  children = mkShopItemView({ shopItem, crateContent, itemTemplates })
}

let tiersStars = @(minTier, maxTier) maxTier <= 0 ? null : {
  hplace = ALIGN_RIGHT
  vplace = ALIGN_TOP
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  margin = fsh(1)
  children = maxTier <= minTier
    ? mkIconBar(minTier, soldierLvlColor, "star", { fontSize = hdpx(20) })
    : [
        mkIconBar(minTier, soldierLvlColor, "star", { fontSize = hdpx(20) })
        faComp("ellipsis-h", {fontSize = hdpx(20), margin = [0, fsh(1)], color = disabledTxtColor})
        mkIconBar(maxTier, soldierLvlColor, "star", { fontSize = hdpx(20) })
      ]
}

// TODO: Need to remove this method after all MsgBox view in shopPackage.nut finished
let mkMsgBoxView = @(shopItem, crateContent, countWatched, showDiscount = false)
  crateContent == null ? null
    : function() {
        let { armyId = null, content = {} } = crateContent.value
        let templates = allItemTemplates.value?[armyId]
        let { minTier, maxTier } = getTierInterval(content?.items, templates)
        let sizeBlock = shopItem?.squads[0] != null ? cardSquadPreviewSize : cardPreviewSize
        return {
          rendObj = ROBJ_SOLID
          watch = [crateContent, allItemTemplates]
          size = sizeBlock
          padding = hdpx(1)
          color = idleBgColor
          children = {
            size = flex()
            halign = ALIGN_RIGHT
            children = [
              mkShopItemImg(shopItem.image, {
                keepAspect = KEEP_ASPECT_FILL
                imageHalign = ALIGN_CENTER
                imageValign = ALIGN_TOP
              }),
              mkShopItemTitle(shopItem, crateContent, allItemTemplates, showDiscount, countWatched),
              (shopItem?.isShowDebugOnly ?? false) ? debugTag : null,
              itemHighlight(shopItem.guid),
              tiersStars(minTier, maxTier),
              mkShopItemInfoTier(minTier, maxTier, {
                size = [hdpx(200), SIZE_TO_CONTENT]
                pos = [hdpx(215), 0]
                color = defTxtColor
              })
            ]
          }
        }
      }


let getGrStatus = @(growths, growthId) growths?[growthId].status ?? GrowthStatus.UNAVAILABLE

function getCantBuyData(army, req, growths, growthCfg, grTiers, grTierCfg, templates) {
  let { guid = "", level = 0 } = army
  let { armyLevel = 0, growthId = "", growthTierId = "" } = req

  if (armyLevel > level) {
    let lockTxt = loc("levelInfo", { level = armyLevel })
    return {
      levelRequired = armyLevel
      lockTxt
      lockFull = lockTxt
    }
  }

  if (growthId != "" && getGrStatus(growths, growthId) != GrowthStatus.REWARDED) {
    let { itemTemplate = null } = growthCfg?[growthId].reward
    local lockTxt = ""
    local lockFull = ""
    if (itemTemplate != null) {
      let item = templates?[guid][itemTemplate]
      if (item != null) {
        lockTxt = loc("growth/reqToCompleteGrowth")
        lockFull = loc("growth/reqToResearchGrowth", { reqText = getItemName(item) })
      }
    }
    return {
      growthRequired = growthId
      lockTxt
      lockFull
    }
  }

  if (growthTierId != "" && getGrStatus(grTiers, growthTierId) < GrowthStatus.COMPLETED) {
    let growthTierIdx = grTierCfg.findindex(@(t) t.id == growthTierId)
    local lockTxt = ""
    local lockFull = ""
    if (growthTierIdx != null) {
      let reqText = getRomanNumeral(growthTierIdx + 1)
      lockTxt = loc("growth/reqToCompleteTier", { reqText })
      lockFull = loc("growth/reqToBuyTier", { reqText })
    }
    return {
      growthTierRequired = growthTierIdx
      lockTxt
      lockFull
    }
  }

  return null
}


function shopItemLockedMsgBox(lockData, cb = @() null) {
  let { levelRequired = null, growthRequired = null, growthTierRequired = null } = lockData

  let buttons = [{ text = loc("Ok"), isCancel = true }]
  if (levelRequired != null)
    buttons.append({ text = loc("GoToCampaign"), action = function() {
      scrollToCampaignLvl(levelRequired)
      jumpToArmyProgress()
      cb()
    }})

  if (growthRequired != null || growthTierRequired != null)
    buttons.append({ text = loc("GoToGrowth"), action = function() {
      if (growthRequired != null)
        jumpToArmyGrowth(growthRequired)
      else
        jumpToArmyGrowthTier(growthTierRequired)
      cb()
    }})

  msgbox.show({
    text = "\n\n".join([loc("shop/lockItemHeader"), lockData.lockFull])
    buttons
  })
}

let viewShopInfoBtnStyle = {
  textCtor = @(textField, params, handler, group, sf) textButtonTextCtor({
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    margin = textMargin
    children = [
      faComp("question-circle", {color = sf & S_HOVER ? TextHover : TextNormal})
      textField.__merge({ margin = [0,0,0,midPadding] })
    ]
  }, params, handler, group, sf)
}

return {
  PRICE_HEIGHT
  DISCOUNT_WARN_TIME
  mkShopItemImg
  mkShopItemView
  mkProductView
  mkMsgBoxView
  mkShopItemInfoBlock
  shopItemLockedMsgBox
  viewShopInfoBtnStyle
  mkLevelLockLine
  mkShopItemPriceLine
  mkClassCanUse
  mkClassCanUseCenter
  getCantBuyData
  cardSquadPreviewSize
}
