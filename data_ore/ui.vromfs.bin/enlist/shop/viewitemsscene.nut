from "%enlSqGlob/ui_library.nut" import *

let mkHeader = require("%enlist/components/mkHeader.nut")
let closeBtnBase = require("%ui/components/closeBtn.nut")
let { getItemName } = require("%enlSqGlob/ui/itemsInfo.nut")
let { safeAreaBorders } = require("%enlist/options/safeAreaState.nut")
let { sceneWithCameraAdd, sceneWithCameraRemove } = require("%enlist/sceneWithCamera.nut")
let { curSelectedItem, changeCameraFov } = require("%enlist/showState.nut")
let { mkViewItemWatchDetails } = require("%enlist/soldiers/components/itemDetailsComp.nut")


const ADD_CAMERA_FOV_MIN = -20
const ADD_CAMERA_FOV_MAX = 5


let viewItem = mkWatched(persist, "viewItem", null)

let itemsScene = @() {
  watch = [safeAreaBorders, viewItem]
  size = [sw(100), sh(100)]
  flow = FLOW_VERTICAL
  padding = safeAreaBorders.value
  behavior = [Behaviors.MenuCameraControl, Behaviors.TrackMouse]
  children = [
    mkHeader({
      textLocId = getItemName(viewItem.value.gametemplate)
      closeButton = closeBtnBase({ onClick = @() viewItem(null) })
    })
    {
      size = flex()
      valign = ALIGN_CENTER
      children = mkViewItemWatchDetails(curSelectedItem)
    }
  ]
  onAttach = @() curSelectedItem(viewItem.value)
  onDetach = @() curSelectedItem(null)
  onMouseWheel = function(mouseEvent) {
    changeCameraFov(mouseEvent.button * 5, ADD_CAMERA_FOV_MIN, ADD_CAMERA_FOV_MAX)
  }
}

viewItem.subscribe(function(val) {
  if (val == null) {
    sceneWithCameraRemove(itemsScene)
    return
  }
  sceneWithCameraAdd(itemsScene, "shop_items")
})

if (viewItem.value != null)
  sceneWithCameraAdd(itemsScene, "shop_items")

return @(val) viewItem(val)
