from "%enlSqGlob/ui/ui_library.nut" import *

let { startsWith } = require("%sqstd/string.nut")
let mkHeader = require("%enlist/components/mkHeader.nut")
let closeBtnBase = require("%ui/components/closeBtn.nut")
let mkItemWithMods = require("%enlist/soldiers/mkItemWithMods.nut")
let buyShopItem = require("buyShopItem.nut")
let activatePremiumBttn = require("activatePremiumBtn.nut")
let { PrimaryFlat, Flat } = require("%ui/components/textButton.nut")
let {
  mkShopItemView, shopItemLockedMsgBox, mkShopItemImg, mkLevelLockLine,
  mkShopItemPriceLine, mkShopItemInfoBlock, getCantBuyData
} = require("shopPkg.nut")
let { mkShopMsgBoxView, mkCanUseShopItemInfo } = require("shopPackage.nut")
let { makeVertScroll } = require("%ui/components/scrollbar.nut")
let { allItemTemplates, itemTypesInSlots
} = require("%enlist/soldiers/model/all_items_templates.nut")
let { safeAreaBorders } = require("%enlist/options/safeAreaState.nut")
let { curArmyData } = require("%enlist/soldiers/model/state.nut")
let { shopItemContentCtor, purchaseIsPossible, needGoodManage
} = require("armyShopState.nut")
let { mkShopItem } = require("%enlist/soldiers/model/items_list_lib.nut")
let { mkViewItemWatchDetails } = require("%enlist/soldiers/components/itemDetailsComp.nut")
let { sceneWithCameraAdd, sceneWithCameraRemove } = require("%enlist/sceneWithCamera.nut")
let {
  midPadding, smallPadding, blurBgColor, blurBgFillColor, unitSize
} = require("%enlSqGlob/ui/designConst.nut")
let { curSelectedItem, changeCameraFov } = require("%enlist/showState.nut")
let { makeCrateToolTip } = require("%enlist/items/crateInfo.nut")
let checkLootRestriction = require("hasLootRestriction.nut")
let {
  curGrowthState, curGrowthConfig, curGrowthProgress, curGrowthTiers, GrowthStatus
} = require("%enlist/growth/growthState.nut")


const ADD_CAMERA_FOV_MIN = -20
const ADD_CAMERA_FOV_MAX = 5


let shopItem = mkWatched(persist, "shopItem", null)
let selectedKey = Computed(@() curSelectedItem.value?.basetpl)

let shopItemWidth = 9.0 * unitSize
let shopItemHeight = 6.0 * unitSize

function mkShopItemContent(sItem) {
  let crateContentWatch = shopItemContentCtor(sItem)
  return crateContentWatch.value == null ? null
    : function() {
        let { armyId, content } = crateContentWatch.value
        let templates = allItemTemplates.value?[armyId]

        let crateItems = (content?.items ?? {}).keys()
          .map(function(templateId) {
            let template = templates?[templateId]
            return template == null ? null : mkShopItem(templateId, template, armyId)
          })
          .filter(@(item) item != null)
          .sort(@(a,b) (a?.tier ?? 0) <=> (b?.tier ?? 0))

        let res = { watch = [crateContentWatch, allItemTemplates, itemTypesInSlots] }
        if (crateItems.len() == 0)
          return res

        return res.__update({
          size = [SIZE_TO_CONTENT, flex()]
          padding = [midPadding, midPadding]
          rendObj = ROBJ_WORLD_BLUR_PANEL
          color = blurBgColor
          fillColor = blurBgFillColor
          onAttach = @() curSelectedItem(crateItems[0])
          onDetach = @() curSelectedItem(null)
          xmbNode = XmbContainer({
            canFocus = false
            scrollSpeed = 5.0
            isViewport = true
          })
          children = makeVertScroll(
            wrap(crateItems
              .map(@(item) mkItemWithMods({
                item
                selectedKey
                selectKey = item?.basetpl
                isXmb = true
                canDrag = false
                itemSize = [shopItemWidth, 2.2 * unitSize]
                onClickCb = @(_) curSelectedItem(item)
                hideStatus = true
                isAvailable = true
              })),
              {
                width = shopItemWidth
                hGap = smallPadding
                vGap = smallPadding
                hplace = ALIGN_CENTER
              }
            ),
            {
              size = [SIZE_TO_CONTENT, flex()]
              needReservePlace = false
            })
        })
      }
}

function purchaseBtnUi() {
  let shopItemData = shopItem.value
  let { offerContainer = "", requirements = {} } = shopItemData
  if (offerContainer.len() > 0)
    return null

  let army = curArmyData.value
  let growths = curGrowthState.value
  let growthCfg = curGrowthConfig.value
  let grTiers = curGrowthProgress.value
  let grTierCfg = curGrowthTiers.value
  let templates = allItemTemplates.value

  let lockData = getCantBuyData(army, requirements, growths, growthCfg,
    grTiers, grTierCfg, templates)

  let btnCtor = lockData != null ? Flat : PrimaryFlat
  let crateContent = shopItemContentCtor(shopItemData)
  let countWatched = Watched(1)
  let description = mkCanUseShopItemInfo(crateContent)

  return {
    watch = [
      curArmyData, curGrowthState, curGrowthConfig, curGrowthProgress,
      curGrowthTiers, allItemTemplates, shopItem, purchaseIsPossible
    ]
    rendObj = ROBJ_BOX
    borderWidth = hdpx(1)
    size = [flex(), SIZE_TO_CONTENT]
    children = !purchaseIsPossible.value ? null
      : btnCtor(loc("btn/buy"),
          function() {
            if (lockData != null)
              return shopItemLockedMsgBox(lockData, @() shopItem(null))

            shopItem(null)
            checkLootRestriction(
              function() {
                buyShopItem({
                  shopItem = shopItemData
                  activatePremiumBttn
                  productView = mkShopMsgBoxView(shopItemData, crateContent, countWatched)
                  description
                  countWatched
                })
                needGoodManage(true)
              },
              {
                itemView = mkShopItemImg(shopItemData.image, {
                  size = [fsh(40), fsh(24)]
                })
                description
              },
              crateContent
            )
          },
          {
            margin = 0
            hotkeys = [["^J:Y"]]
            minWidth = pw(100)
          }
      )
  }
}

function mkShopItemInfo(item) {
  let crateContent = shopItemContentCtor(item)
  return makeCrateToolTip(crateContent, "", [flex(), SIZE_TO_CONTENT])
}

let mkCrateContent = @(sItem) function() {
  let crateContentWatch = shopItemContentCtor(sItem)
  return {
    watch = [crateContentWatch, curSelectedItem]
    size = [flex(), SIZE_TO_CONTENT]
    rendObj = ROBJ_WORLD_BLUR_PANEL
    color = blurBgColor
    fillColor = blurBgFillColor
    padding = midPadding
    children = mkShopItemInfoBlock(crateContentWatch)
  }
}

let shopItemsScene = @() {
  watch = [safeAreaBorders, shopItem]
  size = [sw(100), sh(100)]
  flow = FLOW_VERTICAL
  padding = safeAreaBorders.value
  behavior = [Behaviors.MenuCameraControl, Behaviors.TrackMouse]
  onMouseWheel = function(mouseEvent) {
    changeCameraFov(mouseEvent.button * 5, ADD_CAMERA_FOV_MIN, ADD_CAMERA_FOV_MAX)
  }
  children = [
    mkHeader({
      // FIXME: Need to add some parameter to shop item to determine starter pack
      textLocId = startsWith(shopItem.value?.guid, "starter_pack")
        ? "shop/content"
        : "shop/possibleContent"
      closeButton = closeBtnBase({ onClick = @() shopItem(null) })
    })
    {
      size = flex()
      children = [
        {
          size = [SIZE_TO_CONTENT, flex()]
          flow = FLOW_VERTICAL
          gap = smallPadding
          children = [
            function() {
              let res = { watch = [shopItem, curArmyData, curGrowthState, curGrowthProgress] }
              if (shopItem.value == null)
                return res
              let { armyLevel = 0, growthId = "", growthTierId = "" } = shopItem.value?.requirements
              let { level = 0 } = curArmyData.value

              let gr = curGrowthState.value
              let isGrowthAllowed = growthId == ""
                || (gr?[growthId].status ?? GrowthStatus.UNAVAILABLE) == GrowthStatus.REWARDED

              let tr = curGrowthProgress.value
              let isGrTierAllowed = growthTierId == ""
                || (tr?[growthTierId].status ?? GrowthStatus.UNAVAILABLE) == GrowthStatus.COMPLETED

              let isLocked = armyLevel > level || !isGrowthAllowed || !isGrTierAllowed
              return res.__update({
                size = [flex(), shopItemHeight]
                flow = FLOW_VERTICAL
                children = [
                  mkShopItemView({ shopItem = shopItem.value, isLocked })
                  armyLevel > level ? mkLevelLockLine(armyLevel)
                    : mkShopItemPriceLine(shopItem.value, null, false, false)
                ]
              })
            }
            mkCrateContent(shopItem.value)
            mkShopItemContent(shopItem.value)
            mkShopItemInfo(shopItem.value)
            purchaseBtnUi
          ]
        }
        {
          size = flex()
          halign = ALIGN_RIGHT
          valign = ALIGN_BOTTOM
          children = mkViewItemWatchDetails(curSelectedItem)
        }
      ]
    }
  ]
}

shopItem.subscribe(function(val) {
  if (val == null) {
    sceneWithCameraRemove(shopItemsScene)
    return
  }
  sceneWithCameraAdd(shopItemsScene, "shop_items")
})

if (shopItem.value != null)
  sceneWithCameraAdd(shopItemsScene, "shop_items")

return @(val) shopItem(val)
