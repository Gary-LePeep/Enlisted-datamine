from "%enlSqGlob/ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let JB = require("%ui/control/gui_buttons.nut")
let colorize = require("%ui/components/colorize.nut")
let checkbox = require("%ui/components/checkbox.nut")
let spinner = require("%ui/components/spinner.nut")
let { startswith } = require("string")
let { showMsgbox } = require("%enlist/components/msgbox.nut")
let { fontSub, fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let { txt, noteTextArea } = require("%enlSqGlob/ui/defcomps.nut")
let { SaveVehicleDecals } = require("vehicle_decals")
let { ceil } = require("%sqstd/math.nut")
let { safeAreaBorders } = require("%enlist/options/safeAreaState.nut")
let { selectVehParams, viewVehicle } = require("vehiclesListState.nut")
let { hasPremium } = require("%enlist/currency/premium.nut")
let { Bordered } = require("%ui/components/textButton.nut")
let { currenciesList } = require("%enlist/currency/currencies.nut")
let { currencyBtn } = require("%enlist/currency/currenciesComp.nut")
let { purchaseMsgBox } = require("%enlist/currency/purchaseMsgBox.nut")
let { makeVertScroll, thinStyle } = require("%ui/components/scrollbar.nut")
let {
  mkDecorSlot, mkDecorIcon, mkBlockHeader, mkCustGroup, slotSize, mkSkinIcon,
  mkFlipBtn, mkSelectBox, mkButton, closeActionIcon, mkDecorHints, decorScaleHint,
  decorRotationHint, slotNormalColor, slotBigSize, mkDecalImage, mkDecorImage
} = require("customizePkg.nut")
let {
  sceneWithCameraAdd, sceneWithCameraRemove
} = require("%enlist/sceneWithCamera.nut")
let {
  customizationParams, lastOpenedGroupName, getDecorBelongText,
  curDecorCfgByType, viewVehCustSchemes, customizationSort,
  selectedCamouflage, applyDecorator, availVehDecorByTypeId,
  buyDecorator, curCamouflageId, getOwnedCamouflage, viewVehCamouflage,
  selectedDecorator, startUsingDecor, stopUsingDecal, vehDecorLimits,
  mirrorDecal, twoSideDecal, viewVehDecorByType, viewVehCustLimits,
  cropSkinName, closeDecoratorsList, isPurchasing, notPurchased,
  buyApplyDecorators
} = require("customizeState.nut")
let {
  getBaseVehicleSkin, getVehSkins, decalToString
} = require("%enlSqGlob/vehDecorUtils.nut")
let {
  midPadding, tinyOffset, smallOffset, smallPadding, accentTitleTxtColor,
  defBgColor
} = require("%enlSqGlob/ui/designConst.nut")
let {
  onDecalMouseMove, onDecalMouseWheel, applyUsingDecal, applyUsingDecor
} = require("decorViewer.nut")
let { closeDmViewerMode } = require("dmViewer.nut")
let { SaveVehicleDecor } = require("dasevents")
let { getFirstLinkByType } = require("%enlSqGlob/ui/metalink.nut")
let { isSquadRented } = require("%enlist/soldiers/model/squadInfoState.nut")
let { squads } = require("%enlist/meta/profile.nut")
let { showRentedSquadLimitsBox } = require("%enlist/soldiers/components/squadsComps.nut")
let popupsState = require("%enlSqGlob/ui/popup/popupsState.nut")
let { hasMassVehDecorPaste } = require("%enlist/featureFlags.nut")


enum SIDE_PARAMS {
  ONE_SIDE = "DecalSingleSide"
  TWO_SIDE = "DecalTwoSided"
  TWO_SIDE_MIRRORED = "DecalTwoSidedMirr"
}

let sideParams = [
  SIDE_PARAMS.ONE_SIDE,
  SIDE_PARAMS.TWO_SIDE,
  SIDE_PARAMS.TWO_SIDE_MIRRORED
]

let isMirrorMode = mkWatched(persist, "isMirrorMode", false)
let twoSideIdx = mkWatched(persist, "twoSideIdx", 0)

const SLOTS_IN_ROW = 4

let iconSpaceWidth = SLOTS_IN_ROW * slotSize[0] + (SLOTS_IN_ROW - 1) * midPadding
let waitingSpinner = spinner()

function mkCamouflage(cParams, gametemplate, camouflage, skinToBuy, currencies) {
  let id = skinToBuy?.id ?? camouflage?.id
  let { curCustType = "", curSlotIdx = -1 } = cParams
  let isSelected = curCustType == "vehCamouflage" && curSlotIdx == 0
  let skin = getVehSkins(gametemplate).findvalue(@(s) s.id == id)
  let {
    locId = null, objTexReplace = (getBaseVehicleSkin(gametemplate) ?? {})
  } = skin
  local skinId = cropSkinName((objTexReplace).values()?[0])
  let skinLocId = locId ?? ($"skin/{skinId ?? "baseSkinName"}")
  let decorator = skinId == null ? null : { cfg = { guid = skinId }}
  let { buyData = null } = skinToBuy
  return {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = midPadding
    padding = midPadding
    children = [
      {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_VERTICAL
        children = [
          mkBlockHeader(loc("vehCamouflageHeader"))
          noteTextArea(loc(skinLocId)).__update({
            size = [flex(), SIZE_TO_CONTENT]
            margin = [0, smallPadding]
            color = accentTitleTxtColor
          }.__update(fontSub))
        ]
      }
      mkDecorSlot(decorator, isSelected, false, function() {
        if (!isPurchasing.value)
          customizationParams({
            curCustType = "vehCamouflage"
            curSlotIdx = 0
          })
      }, null, buyData, currencies)
    ]
  }
}

let mkNotPurchasedDecorator = @(decorator) decorator == null ? null
  : {
      slotIdx = decorator.slotIdx
      cType = decorator.cType
      cfg = {
        cType = decorator.cType
        guid = decorator.id
      }
    }

let mkCustomize = kwarg(
  function(decorators, scheme, slotParams, decoratorsCfg, hasPrem, decoratorsToBuy, currencies) {
    let { curCustType = "", curSlotIdx = -1 } = slotParams
    let { custType = "", slotsNum = 0, premSlotsNum = 0 } = scheme
    let total = slotsNum + premSlotsNum
    let available = hasPrem ? total : slotsNum
    let rows = ceil(total.tofloat() / SLOTS_IN_ROW)
    return total == 0 ? null
      : {
          flow = FLOW_VERTICAL
          gap = midPadding
          padding = midPadding
          children = [mkBlockHeader(loc($"{custType}Header"))]
            .extend(array(rows).map(@(_row, rowIdx) {
              flow = FLOW_HORIZONTAL
              gap = midPadding
              children = array(SLOTS_IN_ROW).map(function(_column, columnIdx) {
                let sIdx = rowIdx * SLOTS_IN_ROW + columnIdx
                let isSelected = curCustType == custType && curSlotIdx == sIdx
                let hasLocked = sIdx >= available
                let notPurchasedDecorator = decoratorsToBuy.findvalue(@(d) d.slotIdx == sIdx)
                let decorator = mkNotPurchasedDecorator(notPurchasedDecorator)
                  ?? decorators.findvalue(@(d) d.slotIdx == sIdx)
                let { buyData = null } = notPurchasedDecorator

                let onClick = function() {
                  if (!isPurchasing.value)
                    customizationParams({
                      curCustType = custType
                      curSlotIdx = sIdx
                    })
                }
                local onRemove = null
                if (decorator != null) {
                  let { cType, slotIdx, guid = null, vehGuid = null } = decorator
                  onRemove = function() {
                    if (guid == null) {
                      notPurchased.mutate(function(cust) {
                        let decoratorsList = clone (cust?[cType] ?? [])
                        let idxToDelete = decoratorsList.findindex(@(v) v.slotIdx == sIdx)
                        if (idxToDelete != null)
                          decoratorsList.remove(idxToDelete)
                        cust[cType] <- decoratorsList
                      })
                      return
                    }

                    if (decorator.cfg.guid in decoratorsCfg)
                      return applyDecorator("", vehGuid, cType, "", slotIdx)

                    showMsgbox({
                      text = "{0}\n\n{1}".subst(
                        getDecorBelongText(decorator.cfg.belongId),
                        loc("decorator/removeWarning")
                      )
                      buttons = [
                        {
                          text = loc("Yes"), isCurrent = true,
                          action = @() applyDecorator("", vehGuid, cType, "", slotIdx)
                        }
                        {
                          text = loc("Cancel"), isCancel = true,
                          customStyle = { hotkeys = [[$"^{JB.B} | Esc"]] }
                        }
                      ]
                    })
                  }
                }

                return sIdx >= total ? null
                  : mkDecorSlot(decorator, isSelected, hasLocked, onClick,
                      onRemove, buyData, currencies)
              })
            }))
        }
  })

let curAvailCamouflages = Computed(function() {
  let { gametemplate = null, sign = 0 } = viewVehicle.value
  if (gametemplate == null)
    return []

  let availCamouflage = availVehDecorByTypeId.value?.vehCamouflage ?? {}
  let tplWithoutCountry = gametemplate.slice((gametemplate.indexof("_") ?? -1) + 1)
  let vehSkins = getVehSkins(gametemplate)
  return sign == 0 ? vehSkins
    : vehSkins.filter(@(skinData) skinData.id in availCamouflage
        || startswith(skinData.id, tplWithoutCountry))
})

function clearNotPurchased() {
  notPurchased.mutate(function(cust) { cust.clear() })
}

function actionsOnClose() {
  selectVehParams.mutate(@(v) v.isCustomMode = false)
  clearNotPurchased()
  selectedCamouflage(null)
}

function close() {
  if (notPurchased.value.len() > 0) {
    showMsgbox({
      text = loc("msg/leaveCustomizationConfirm")
      buttons = [
        { text = loc("Yes"),
          action = actionsOnClose,
          isCurrent = true }
        { text = loc("Cancel"), isCancel = true, customStyle = { hotkeys = [[$"^{JB.B} | Esc"]] } }
      ]
    })
    return
  }
  actionsOnClose()
}

let backBtn = Bordered(loc("BackBtn"), close,
  {
    margin = midPadding
    hotkeys = [[ $"^{JB.B} | Esc", { description = loc("BackBtn") }]]
  })


function removeNotPurchasedCamouflage() {
  if ("vehCamouflage" in notPurchased.value)
    notPurchased.mutate(function(cust) { cust.$rawdelete("vehCamouflage") })
}

function addNotPurchasedCamouflage(id, buyData) {
  notPurchased.mutate(function(cust) {
    cust.vehCamouflage <- { id, buyData, details = "", cType = "vehCamouflage", slotIdx = 0 }
  })
}

let buyProductBorderColor = Color(80,80,80,200)
let buyProductColor = Color(20,20,20,200)
let buyProductSlotWidth = hdpx(300)
let buyProductWndWidth = 3 * buyProductSlotWidth + 2 * midPadding
let buyProductParams = {
  flow = FLOW_HORIZONTAL
  gap = midPadding
}

let mkBuyProduct = @(icon, header, name) {
  size = [buyProductSlotWidth, SIZE_TO_CONTENT]
  flow = FLOW_HORIZONTAL
  gap = midPadding
  rendObj = ROBJ_SOLID
  color = buyProductColor
  children = [
    {
      size = slotSize
      padding = smallPadding
      rendObj = ROBJ_BOX
      borderWidth = hdpx(1)
      borderColor = buyProductBorderColor
      children = icon
    }
    {
      size = flex()
      flow = FLOW_VERTICAL
      margin = [midPadding, 0]
      gap = smallPadding
      children = [
        mkBlockHeader(header)
        noteTextArea(name).__update({
          size = [flex(), SIZE_TO_CONTENT]
          margin = [0, smallPadding]
          color = accentTitleTxtColor
        }.__update(fontSub))
      ]
    }
  ]
}

let massBuyProductViewUi = function() {
  let res = {
    watch = [viewVehicle, notPurchased]
  }

  let { gametemplate = null } = viewVehicle.value
  if (gametemplate == null)
    return res

  let decalHeader = loc("vehDecalChooseHeader")
  let skinHeader  = loc("vehCamouflageChooseHeader")
  let decorHeader = loc("vehDecoratorChooseHeader")
  let { vehCamouflage = null, vehDecorator = [], vehDecal = [] } = notPurchased.value

  let children = []
  if (vehCamouflage != null) {
    let skin = getVehSkins(gametemplate).findvalue(@(s) s.id == vehCamouflage.id)
    let {
      locId = null, objTexReplace = (getBaseVehicleSkin(gametemplate) ?? {})
    } = skin
    let skinId = cropSkinName((objTexReplace).values()?[0])
    let skinTxt = loc(locId ?? ($"skin/{skinId ?? "baseSkinName"}"))
    let icon = mkDecalImage({ guid = skinId })
    children.append(mkBuyProduct(icon, skinHeader, skinTxt))
  }

  if (vehDecal.len() > 0)
    children.extend(vehDecal.map(@(d)
      mkBuyProduct(mkDecalImage({ guid = d.id }), decalHeader, loc($"decals/{d.id}"))
    ))

  if (vehDecorator.len() > 0)
    children.extend(vehDecorator.map(@(d)
      mkBuyProduct(mkDecorImage({ guid = d.id }), decorHeader, loc($"decorators/{d.id}"))
    ))

  let hasWrap = children.len() > 3
  return res.__update({
    children = hasWrap
      ? wrap(children, {
          width = buyProductWndWidth
          hGap = midPadding
          vGap = midPadding
        })
      : children
  }, hasWrap ? {} : buyProductParams)
}

function mkPurchaceBtn(notPurchasedVal) {
  let { vehCamouflage = null, vehDecorator = [], vehDecal = [] } = notPurchasedVal
  let vehCamouflageList = vehCamouflage == null ? [] : [vehCamouflage]
  let decoratorsList = [].extend(vehCamouflageList, vehDecorator, vehDecal)
  let price = decoratorsList.reduce(@(r, v) r + v.buyData.price, 0)
  return price <= 0 ? null
    : currencyBtn({
        btnText = loc("btn/buy")
        currencyId = "EnlistedGold"
        price
        cb = function() {
          purchaseMsgBox({
            title = loc("buyVehDecorConfirm")
            productView = massBuyProductViewUi
            price
            currencyId = "EnlistedGold"
            purchase = function() {
              let vehGuid = viewVehicle.value?.guid
              let decoratorsCfgList = decoratorsList.map(@(d) {
                cType = d.cType
                id = d.id
                details = d?.details ?? ""
                slotIdx = d.slotIdx
                price = d.buyData.price
              })
              buyApplyDecorators(decoratorsCfgList, vehGuid, price)
              clearNotPurchased()
            }
            alwaysShowCancel = true
            srcComponent = "mass_buy_decor"
          })
        }
        style = ({
          margin = midPadding
          hotkeys = [["^J:Y", { description = { skip = true }}]]
        })
      })
}

function customizeSlotsUi() {
  let decorCfgByType = curDecorCfgByType.value
  let { gametemplate = null } = viewVehicle.value
  let { vehDecal = null, vehDecorator = null } = viewVehCustSchemes.value
  let slotParams = customizationParams.value
  let decorators = viewVehDecorByType.value
  let camouflage = viewVehCamouflage.value
  let availVehSkins = curAvailCamouflages.value
  let currencies = currenciesList.value

  let notPurchasedVal = notPurchased.value
  let skinToBuy = notPurchasedVal?.vehCamouflage
  let camouflageSlot = availVehSkins.len() > 0 && gametemplate != null
    ? mkCamouflage(slotParams, gametemplate, camouflage, skinToBuy, currencies)
    : null

  return {
    watch = [
      viewVehCustSchemes, customizationParams, viewVehDecorByType,
      viewVehCamouflage, viewVehicle, hasPremium, curAvailCamouflages,
      curDecorCfgByType, notPurchased, currenciesList
    ]
    size = [SIZE_TO_CONTENT, flex()]
    flow = FLOW_VERTICAL
    gap = tinyOffset
    children = [
      { size = flex() }
      camouflageSlot
      mkCustomize({
        decorators = decorators?.vehDecorator ?? {}
        scheme = vehDecorator
        slotParams
        decoratorsCfg = decorCfgByType?.vehDecorator ?? {}
        hasPrem = hasPremium.value
        decoratorsToBuy = notPurchasedVal?.vehDecorator ?? []
        currencies
      })
      mkCustomize({
        decorators = decorators?.vehDecal ?? {}
        scheme = vehDecal
        slotParams
        decoratorsCfg = decorCfgByType?.vehDecal ?? {}
        hasPrem = hasPremium.value
        decoratorsToBuy = notPurchasedVal?.vehDecal ?? []
        currencies
      })
      {
        size = [SIZE_TO_CONTENT, flex()]
        flow = FLOW_HORIZONTAL
        valign = ALIGN_BOTTOM
        children = [
          backBtn
          mkPurchaceBtn(notPurchasedVal)
        ]
      }
    ]
  }
}

let wrapParams = {
  width = iconSpaceWidth
  hGap = midPadding
  vGap = midPadding
}

let emptyList = {
  rendObj = ROBJ_WORLD_BLUR_PANEL
  size = [flex(), SIZE_TO_CONTENT]
  padding = midPadding
  halign = ALIGN_CENTER
  color = defBgColor
  children = txt(loc("msg/listIsEmpty")).__update(fontSub)
}

function mkGroupIcons(groupIconsList, vehGuid, curCustType,
  curSlotIdx, currencies, ownDecorators, isOnlyOwned
) {
  let children = []
  foreach (iconCfg in groupIconsList) {
    let cfg = clone iconCfg
    let { guid } = cfg
    let freeDecorators = (ownDecorators?[guid] ?? {})
      .filter(@(d) d.id == guid
        && (d.vehGuid == "" || d.vehGuid == vehGuid )
        && (d.slotIdx == -1 || d.slotIdx == curSlotIdx))

    let isAbsent = freeDecorators.len() == 0
    let isUnavailable = (cfg?.buyData.price ?? 0) == 0
    if (isAbsent && (isUnavailable || isOnlyOwned))
      continue

    let onClick = curCustType != ""
      ? function() {
          let { cType, subType } = cfg
          let limit = vehDecorLimits.value?[cType][subType] ?? 0
          if (limit > 0) {
            let count = (viewVehCustLimits.value?[cType] ?? {})
              .filter(@(id, slot) id == subType && slot != curSlotIdx).len()
            let notPurchasedCount = (notPurchased.value?[cType] ?? [])
              .reduce(@(res, val) val.subType == subType ? res + 1 : res, 0)
            if (count + notPurchasedCount >= limit) {
              showMsgbox({ text = loc("msg/vehDecorOverlimits", {
                limit = colorize(accentTitleTxtColor, limit)
                id = colorize(accentTitleTxtColor, loc($"decals/category/{subType}"))
              }) })
              return
            }
          }
          startUsingDecor(curSlotIdx, cfg)
        }
      : @() null
    children.append(mkDecorIcon({
      cfg, currencies, onClick, availableCount = freeDecorators.len()
    }))
  }

  return children.len() == 0 ? emptyList
    : {
        size = [flex(), SIZE_TO_CONTENT]
        children = wrap(children, wrapParams)
      }
}

let mkCustomizeList = @(groupName, hasOpened, onClick, availCount, limit, count, groupIcons = null) {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  gap = midPadding
  children = [
    mkCustGroup(groupName, hasOpened, onClick, availCount, limit, count)
    groupIcons
  ]
}

let mkCustomizationList = @(curCustType, content, onlyOwned = null) {
  size = [SIZE_TO_CONTENT, flex()]
  padding = [smallOffset,midPadding,0,midPadding]
  children = {
    key = $"{curCustType}_customization"
    size = [SIZE_TO_CONTENT, flex()]
    flow = FLOW_VERTICAL
    gap = midPadding
    children = [
      {
        rendObj = ROBJ_SOLID
        size = [iconSpaceWidth, SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        gap = smallOffset
        padding = smallPadding
        valign = ALIGN_CENTER
        color = slotNormalColor
        children = [
          mkBlockHeader(loc($"{curCustType}ChooseHeader"))
          { size = flex() }
          onlyOwned == null ? null
            : checkbox(onlyOwned, { text = loc("onlyAvailable") }.__update(fontSub), {
                setValue = @(_) onlyOwned(!onlyOwned.value)
                textOnTheLeft = true
              })
          mkButton({
            icon = closeActionIcon
            onClick = function() {
              selectedCamouflage(null)
              closeDecoratorsList()
            }
            descLocId = "Close"
            hotkey = "Esc"
            gpadHotkey = JB.B
            override = {
              size = [hdpx(36), hdpx(36)]
              padding = smallPadding
            }
          })
        ]
      }
    ].append(makeVertScroll(content, { styling = thinStyle }))
    transform = {}
    animations = [{
      prop = AnimProp.translate, from = [iconSpaceWidth, 0], to = [0, 0],
      play = true, duration = 0.5, easing = OutCubic
    }]
  }
}

let mkDecoratorsList = @(curCustType, curSlotIdx, onlyOwned) function() {
  let res = {
    watch = [
      curDecorCfgByType, lastOpenedGroupName, viewVehicle, vehDecorLimits,
      currenciesList, availVehDecorByTypeId, onlyOwned, viewVehCustLimits
    ]
  }

  let vehGuid = viewVehicle.value?.guid
  let ownDecorators = availVehDecorByTypeId.value?[curCustType] ?? {}
  let currencies = currenciesList.value
  let custCfg = curDecorCfgByType.value?[curCustType] ?? {}
  if (custCfg.len() == 0)
    return res

  let cfgLimits = vehDecorLimits.value?[curCustType] ?? {}
  let vehLimits = viewVehCustLimits.value?[curCustType] ?? {}
  let groupsList = custCfg
    .reduce(@(r, v) v.subType == "" ? r : r.__merge({ [v.subType] = true }), {})
    .keys()
    .sort(@(a, b) a <=> b)

  let openedGroup = lastOpenedGroupName.value
  let groupIconsList = custCfg.values()
    .filter(@(cfg) cfg.subType == openedGroup)
    .sort(customizationSort)

  let onlyOwnedVal = onlyOwned.value
  let content = groupsList.len() == 0 ? null
    : {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_VERTICAL
        gap = midPadding
        children = groupsList.map(function(groupName) {
          let hasOpened = openedGroup == groupName
          let groupIcons = hasOpened
            ? mkGroupIcons(groupIconsList, vehGuid, curCustType, curSlotIdx,
                currencies, ownDecorators, onlyOwnedVal)
            : null
          let onGroupClick = @() lastOpenedGroupName(hasOpened ? "" : groupName)
          let availCount = custCfg
            .filter(@(v) v.subType == groupName).values()
            .reduce(function(r, v) {
              let list = (ownDecorators?[v.guid] ?? {})
                .filter(@(d) (d.vehGuid == "" || d.vehGuid == vehGuid)
                  && (d.slotIdx == -1 || d.slotIdx == curSlotIdx))
              return r + list.len()
            }, 0)

          let limit = cfgLimits?[groupName] ?? 0
          let count = vehLimits.reduce(@(acc, id, slot)
            id == groupName && slot != curSlotIdx ? acc + 1 : acc, 0)
          return mkCustomizeList(groupName, hasOpened, onGroupClick,
            availCount, limit, count, groupIcons)
        })
      }
  return res.__update(mkCustomizationList(curCustType, content, onlyOwned))
}

function applyCamouflageImpl(guid, vehGuid, cType, slot) {
  applyDecorator(guid, vehGuid, cType, "", slot, function(res) {
    if (res?.error == null)
      selectedCamouflage(null)
  })
}

function chooseSkin(skinData, vehGuid, ownCamouflages = {}) {
  if (skinData == null) {
    removeNotPurchasedCamouflage()
    applyCamouflageImpl("", vehGuid, "vehCamouflage", 0)
    return
  }

  let ownCamouflage = getOwnedCamouflage(ownCamouflages, skinData.id, vehGuid)
  selectedCamouflage(skinData.__merge({ hasOwned = ownCamouflage != null }))
  if (ownCamouflage != null) {
    removeNotPurchasedCamouflage()
    applyCamouflageImpl(ownCamouflage.guid, vehGuid, "vehCamouflage", 0)
  }
  else if (hasMassVehDecorPaste.value) {
    if ((skinData?.cfg.buyData.price ?? 0) > 0)
      addNotPurchasedCamouflage(skinData.id, skinData.cfg.buyData)
    else
      removeNotPurchasedCamouflage()
  }
}

let camouflageListUi = function() {
  let res = { watch = [
    viewVehicle, curCamouflageId, curDecorCfgByType, availVehDecorByTypeId,
    currenciesList, curAvailCamouflages
  ]}

  let currencies = currenciesList.value
  let custCfg = curDecorCfgByType.value?.vehCamouflage ?? {}
  if (custCfg.len() == 0)
    return res

  let camouflageId = curCamouflageId.value
  let ownCamouflages = availVehDecorByTypeId.value?.vehCamouflage ?? {}
  let { guid, gametemplate } = viewVehicle.value
  let availVehSkins = curAvailCamouflages.value

  let skinsList = []
  foreach (skinData in availVehSkins) {
    let { id = null } = skinData
    let cfg = custCfg?[id]
    if (cfg == null)
      continue

    let hasOwned = getOwnedCamouflage(ownCamouflages, id, guid) != null
    skinsList.append(skinData.__merge({ cfg, hasOwned }))
  }

  let skinsObjects = skinsList
    .sort(@(a, b) (a?.cfg.buyData.price ?? 0) <= 0 <=> (b?.cfg.buyData.price ?? 0) <= 0
      || (a?.cfg.buyData.price ?? 0) <=> (b?.cfg.buyData.price ?? 0)
      || a.id <=> b.id)
    .map(function(skinData) {
      let { id, hasOwned } = skinData
      let isSelected = camouflageId == id
      return mkSkinIcon(skinData, isSelected, hasOwned, currencies,
        @() chooseSkin(skinData, guid, ownCamouflages))
    })

  let baseSkinData = {
    objTexReplace = getBaseVehicleSkin(gametemplate)
  }
  let skinsBlock = {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = midPadding
    children = skinsObjects.len() == 0 ? null
      : [
          mkSkinIcon(baseSkinData, camouflageId == null, true, currencies,
            @() chooseSkin(null, guid))
        ].extend(skinsObjects)
  }
  return res.__update(mkCustomizationList("vehCamouflage", skinsBlock))
}

function purchaseBtnUi() {
  let res = {
    watch = [viewVehicle, selectedCamouflage, hasMassVehDecorPaste]
  }
  if (hasMassVehDecorPaste.value)
    return res

  let {
    cfg = null, hasOwned = false, objTexReplace = {}, locId = null
  } = selectedCamouflage.value
  if (cfg == null || hasOwned)
    return res

  let { cType, guid, buyData } = cfg
  let { price = 0, currencyId = "" } = buyData
  let skinId = cropSkinName((objTexReplace).values()?[0])
  let skinTxt = loc(locId ?? ($"skin/{skinId ?? "baseSkinName"}"))
  let hasAlternativeTxt = price == 0 || currencyId == ""
  return res.__update({
    hplace = ALIGN_RIGHT
    children = hasAlternativeTxt
      ? {
          rendObj = ROBJ_SOLID
          padding = midPadding
          color = defBgColor
          children = noteTextArea(loc("alternativeCamouflageReceivingWay"))
            .__update({
              size = [hdpx(560), SIZE_TO_CONTENT]
              halign = ALIGN_CENTER
              color = accentTitleTxtColor
            }.__update(fontBody))
        }
      : currencyBtn({
          btnText = loc("btn/buy")
          currencyId
          price
          cb = @() purchaseMsgBox({
            price
            currencyId
            description = "{0}\n{1}".subst(
              loc("buyCamouflageConfirm"),
              colorize(accentTitleTxtColor, skinTxt)
            )
            purchase = @() buyDecorator(cType, guid, price, function(r) {
              if (r?.error == null) {
                let vehGuid = viewVehicle.value?.guid
                let camouflageGuid = (r?.vehDecorators ?? {}).keys()?[0]
                if (vehGuid != null && camouflageGuid != null)
                  applyCamouflageImpl(camouflageGuid, vehGuid, cType, 0)
              }
            })
            alwaysShowCancel = true
            srcComponent = "buy_camouflage"
          })
          style = ({
            margin = midPadding
            hotkeys = [["^J:Y", { description = { skip = true }}]]
          })
        })
  })
}

let filterOnlyOwned = Watched(false)
function customizeListUi() {
  let { curCustType = "", curSlotIdx = -1 } = customizationParams.value
  return {
    watch = customizationParams
    size = [SIZE_TO_CONTENT, flex()]
    flow = FLOW_VERTICAL
    halign = ALIGN_RIGHT
    hplace = ALIGN_RIGHT
    children = [
      curCustType == "" ? null
        : curCustType == "vehCamouflage" ? camouflageListUi
        : mkDecoratorsList(curCustType, curSlotIdx, filterOnlyOwned)
      purchaseBtnUi
    ]
  }
}

function isVehicleOwnedByRentedSquad(vehicle) {
  let squadGuid = getFirstLinkByType(vehicle, "curVehicle")
  return squadGuid != null && isSquadRented(squads.value?[squadGuid])
}

let mkUseDecalBlock = @(applyCb, cancelModeCb, padding) {
  size = flex()
  flow = FLOW_HORIZONTAL
  gap = smallOffset
  padding
  margin = midPadding
  behavior = [Behaviors.MenuCameraControl, Behaviors.Button]
  onClick = function() {
    if (isVehicleOwnedByRentedSquad(viewVehicle.value)) {
      showRentedSquadLimitsBox()
      cancelModeCb()
      return
    }
    applyCb()
  }
  eventPassThrough = true
  halign = ALIGN_CENTER
  valign = ALIGN_BOTTOM
  children = [
    {
      hotkeys = [[
        $"^J:LB", @() onDecalMouseWheel({ shiftKey = true, button = -2 })
      ]]
    }
    {
      hotkeys = [[
        $"^J:RB", @() onDecalMouseWheel({ shiftKey = true, button = 2 })
      ]]
    }
    {
      hotkeys = [[
        $"^J:LT", @() onDecalMouseWheel({ altKey = true, button = -2 })
      ]]
    }
    {
      hotkeys = [[
        $"^J:RT", @() onDecalMouseWheel({ altKey = true, button = 2 })
      ]]
    }
    mkDecorHints([decorScaleHint, decorRotationHint])
    mkFlipBtn(isMirrorMode)
    mkSelectBox(sideParams, twoSideIdx, ["S", "T", "M"], "J:X")
    mkButton({
      icon = closeActionIcon
      onClick = cancelModeCb
      descLocId = "Close"
      hotkey = "Esc"
      gpadHotkey = JB.B
      hasHotkeyHint = true
    })
  ]
}

let mkUseDecorBlock = @(applyCb, cancelModeCb, padding) {
  size = flex()
  flow = FLOW_HORIZONTAL
  gap = smallOffset
  padding
  margin = midPadding
  behavior = [Behaviors.MenuCameraControl, Behaviors.Button]
  onClick = function() {
    if (isVehicleOwnedByRentedSquad(viewVehicle.value)) {
      showRentedSquadLimitsBox()
      cancelModeCb()
      return
    }
    applyCb()
  }
  eventPassThrough = true
  halign = ALIGN_CENTER
  valign = ALIGN_BOTTOM
  children = [
    {
      hotkeys = [[
        $"^J:LT", @() onDecalMouseWheel({ altKey = true, button = -2 })
      ]]
    }
    {
      hotkeys = [[
        $"^J:RT", @() onDecalMouseWheel({ altKey = true, button = 2 })
      ]]
    }
    mkDecorHints([decorRotationHint])
    mkButton({
      icon = closeActionIcon
      onClick = cancelModeCb
      descLocId = "Close"
      hotkey = "Esc"
      gpadHotkey = JB.B
      hasHotkeyHint = true
    })
  ]
}

isMirrorMode.subscribe(@(v) mirrorDecal(v))
twoSideIdx.subscribe(function(v) {
  if (sideParams[v] == SIDE_PARAMS.ONE_SIDE)
    twoSideDecal(false, false)
  else if (sideParams[v] == SIDE_PARAMS.TWO_SIDE)
    twoSideDecal(true, false)
  else if (sideParams[v] == SIDE_PARAMS.TWO_SIDE_MIRRORED)
    twoSideDecal(true, true)
})

let customizeScene = function() {
  let mouseMoveCb = selectedDecorator.value != null
    ? onDecalMouseMove
    : null
  let mouseWheelCb = selectedDecorator.value != null
    ? onDecalMouseWheel
    : null
  let isDecoration = mouseMoveCb != null
  return {
    watch = [safeAreaBorders, selectedDecorator, isPurchasing]
    size = flex()
    padding = isDecoration ? null : safeAreaBorders.value
    margin = [0, 0, smallOffset, 0]
    behavior = isDecoration
      ? Behaviors.TrackMouse
      : Behaviors.MenuCameraControl
    onMouseMove = mouseMoveCb
    onMouseWheel = mouseWheelCb
    children = selectedDecorator.value == null
      ? [
          customizeSlotsUi
          isPurchasing.value ? waitingSpinner : null
          customizeListUi
        ]
      : selectedDecorator.value.cType == "vehDecorator" ? mkUseDecorBlock(
          applyUsingDecor,
          stopUsingDecal,
          safeAreaBorders.value
        )
      : mkUseDecalBlock(
          applyUsingDecal,
          stopUsingDecal,
          safeAreaBorders.value
        )
  }
}

function openPurchaseDecoratorBox(decoratorCfg, applyCb) {
  let { guid, buyData, cType } = decoratorCfg
  let { price, currencyId } = buyData
  if (price == null || currencyId == "")
    return

  let locTypeId = cType == "vehDecorator" ? "decorators" : "decals"
  purchaseMsgBox({
    price
    currencyId
    description = "{0}\n{1}".subst(
      loc($"{cType}BuyConfirm"),
      colorize(accentTitleTxtColor, loc($"{locTypeId}/{guid}"))
    )
    productView = mkDecorIcon({
      cfg = decoratorCfg, override = { size = slotBigSize }
    })
    purchase = @() buyDecorator(cType, guid, price, function(res) {
      if (res?.error != null)
        return

      let decals = (res?.vehDecorators ?? {})
      let decal = decals.findvalue(@(d) d.id == guid && d.vehGuid == "")
      if (decal != null)
        applyCb(decal.guid)
    })
    alwaysShowCancel = true
    srcComponent = $"buy_{cType}"
  })
}

function onSaveVehicleDecals(decors_info) {
  let vehGuid = viewVehicle.value?.guid
  let decoratorCfg = selectedDecorator.value
  let { guid = null, cType = null, buyData = null, subType = null } = decoratorCfg
  let { curSlotIdx = -1 } = customizationParams.value

  stopUsingDecal()
  if (guid == null || curSlotIdx == -1)
    return

  let decalsData = decors_info.findvalue(@(d) d.slot == curSlotIdx)
  if (decalsData == null)
    return

  let freeDecorators = (availVehDecorByTypeId.value?[cType][guid] ?? {})
    .filter(@(d) d.id == guid
      && (d.vehGuid == "" || d.vehGuid == vehGuid )
      && (d.slotIdx == -1 || d.slotIdx == curSlotIdx))

  let freeDecorator = freeDecorators
    .findvalue(@(d) d.vehGuid == vehGuid) ?? freeDecorators.values()?[0]

  let applyCb = function(decGuid) {
    closeDecoratorsList()
    let decalString = decalToString(decalsData, cType)
    if (decalString != null)
      applyDecorator(decGuid, vehGuid, cType, decalString, curSlotIdx)
  }
  if (freeDecorator != null)
    return applyCb(freeDecorator.guid)

  let { price = 0 } = buyData
  if (price <= 0)
    return showMsgbox({ text = loc("alternativeDecalReceivingWay") })

  if (!hasMassVehDecorPaste.value) {
    openPurchaseDecoratorBox(decoratorCfg, applyCb)
    return
  }

  notPurchased.mutate(function(cust) {
    if (cType==null)
      return
    let decorators = clone (cust?[cType] ?? [])
    let idxToDelete = decorators.findindex(@(v) v.slotIdx == curSlotIdx)
    if (idxToDelete != null)
      decorators.remove(idxToDelete)
    decorators.append({
      cType
      subType
      buyData
      id = guid
      slotIdx = curSlotIdx
      details = decalToString(decalsData, cType)
    })
    cust[cType] <- decorators
  })
  closeDecoratorsList()
}

ecs.register_es("decal_es", {
  [SaveVehicleDecals] = @(evt, _eid, _comp) onSaveVehicleDecals(evt?[0]?.getAll() ?? [])
}, {}, {tags = "server"})

ecs.register_es("decor_save_es", {
  [SaveVehicleDecor] = function(_eid, comp) {
    if (!comp.decor__canAttach) {
      popupsState.addPopup({
        id = "vehicle_decor_place_error"
        text = loc("msg/vehDecorCantPlaceHere")
        styleName = "error"
      })
      return
    }

    onSaveVehicleDecals([{
      template = comp.node_attached__template
      nodeName = comp.node_attached__nodeName
      relativeTm = comp.node_attached__localTm
      slot = comp.decor__id
    }])
  }
},
{
  comps_ro = [
    ["node_attached__localTm", ecs.TYPE_MATRIX],
    ["node_attached__template", ecs.TYPE_STRING],
    ["node_attached__nodeName", ecs.TYPE_STRING],
    ["decor__id", ecs.TYPE_INT],
    ["decor__canAttach", ecs.TYPE_BOOL]
  ],
}, {tags = "server"})

function open() {
  clearNotPurchased()
  closeDmViewerMode()
  customizationParams(null)
  selectedCamouflage(null)
  sceneWithCameraAdd(customizeScene, "vehicles")
}


if (selectVehParams.value?.isCustomMode ?? false)
  open()

selectVehParams.subscribe(function(v) {
  if (v?.isCustomMode ?? false)
    open()
  else
    sceneWithCameraRemove(customizeScene)
})
