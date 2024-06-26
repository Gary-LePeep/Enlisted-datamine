from "%enlSqGlob/ui/ui_library.nut" import *

let mkHeader = require("%enlist/components/mkHeader.nut")
let closeBtnBase = require("%ui/components/closeBtn.nut")
let mkItemWithMods = require("%enlist/soldiers/mkItemWithMods.nut")
let { Flat } = require("%ui/components/textButton.nut")
let { makeVertScroll } = require("%ui/components/scrollbar.nut")
let { allItemTemplates } = require("%enlist/soldiers/model/all_items_templates.nut")
let { safeAreaBorders } = require("%enlist/options/safeAreaState.nut")
let { curArmy } = require("%enlist/soldiers/model/state.nut")
let { mkViewDetailsFull } = require("%enlist/soldiers/components/itemDetailsComp.nut")
let {
  sceneWithCameraAdd, sceneWithCameraRemove
} = require("%enlist/sceneWithCamera.nut")
let {
  midPadding, smallPadding, blurBgColor, blurBgFillColor, unitSize
} = require("%enlSqGlob/ui/designConst.nut")
let { isGamepad } = require("%ui/control/active_controls.nut")
let { curSelectedItem, changeCameraFov } = require("%enlist/showState.nut")
let { mkClassCanUse } = require("%enlist/shop/shopPkg.nut")
let { getItemOrigin } = require("%enlSqGlob/ui/itemsInfo.nut")

const ADD_CAMERA_FOV_MIN = -10
const ADD_CAMERA_FOV_MAX = 35

let itemToShow = mkWatched(persist, "itemToShow", null)
let selectedKey = Watched(null)
itemToShow.subscribe(@(item) curSelectedItem(item))

let shopItemWidth = 9.0 * unitSize

let mkItemContent = @(item) item == null ? null : @(){
  watch = [allItemTemplates, curArmy, selectedKey]
  size = [SIZE_TO_CONTENT, flex()]
  padding = midPadding
  rendObj = ROBJ_WORLD_BLUR_PANEL
  color = blurBgColor
  fillColor = blurBgFillColor
  xmbNode = XmbContainer({
    canFocus = false
    scrollSpeed = 5.0
    isViewport = true
  })
  children =
    makeVertScroll(
      mkItemWithMods({
        item
        selectedKey
        selectKey = item?.basetpl
        isXmb = true
        canDrag = false
        itemSize = [shopItemWidth, 2.0 * unitSize]
        hideStatus = true
        isAvailable = true
      }),
      {
        size = [SIZE_TO_CONTENT, flex()]
        needReservePlace = false
      })
}

let backBtn = @() {
  watch = isGamepad
  size = [flex(), SIZE_TO_CONTENT]
  children = isGamepad.value ? null : Flat(loc("BackBtn"), @() itemToShow(null),
        { margin = hdpx(1), size = [flex(), hdpx(50)] })
}

function viewItemScene() {
  let { itemtype, basetpl, sign = 0 } = itemToShow.value
  return {
    watch = [safeAreaBorders, itemToShow, curArmy]
    size = [sw(100), sh(100)]
    flow = FLOW_VERTICAL
    padding = safeAreaBorders.value
    behavior = [Behaviors.MenuCameraControl, Behaviors.TrackMouse]
    onMouseWheel = function(mouseEvent) {
      changeCameraFov(mouseEvent.button * 5, ADD_CAMERA_FOV_MIN, ADD_CAMERA_FOV_MAX)
    }
    children = [
      mkHeader({
        textLocId = getItemOrigin(itemToShow.value)
        closeButton = closeBtnBase({ onClick = @() itemToShow(null) })
      })
      {
        size = flex()
        children = [
          {
            rendObj = ROBJ_SOLID
            opacity = 0
            size = flex()
            animations = [
              { prop = AnimProp.opacity, from = 1, to = 0,
                duration = 0.5, play = true }
              { prop = AnimProp.color, from = Color(0,0,0), to = Color(0,0,0),
                duration = 0.5, play = true }
            ]
          }
          {
            size = [SIZE_TO_CONTENT, flex()]
            flow = FLOW_VERTICAL
            gap = smallPadding
            children = [
              sign == 0 ? mkClassCanUse(itemtype, curArmy.value, basetpl) : null
              mkItemContent(itemToShow.value)
              backBtn
            ]
          }
          {
            hplace = ALIGN_RIGHT
            vplace = ALIGN_BOTTOM
            children = mkViewDetailsFull(itemToShow.value, fsh(95))
          }
        ]
      }
    ]
  }
}


itemToShow.subscribe(function(val) {
  if (val == null) {
    sceneWithCameraRemove(viewItemScene)
    return
  }
  sceneWithCameraAdd(viewItemScene, "new_items")
})

if (itemToShow.value != null)
  sceneWithCameraAdd(viewItemScene, "new_items")

return @(val) itemToShow(val)
