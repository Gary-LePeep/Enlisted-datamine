from "%enlSqGlob/ui/ui_library.nut" import *

let {
  sceneWithCameraAdd, sceneWithCameraRemove
} = require("%enlist/sceneWithCamera.nut")
let { viewTemplates } = require("itemCollageState.nut")


let isOpened = mkWatched(persist, "isOpened", false)

let itemCollage = {
  size = flex()
}

function open() {
  sceneWithCameraAdd(itemCollage, "inv_items")
}

function close() {
  sceneWithCameraRemove(itemCollage)
}

isOpened.subscribe(@(v) v ? open() : close())
if (isOpened.value)
  open()

viewTemplates.subscribe(function(tplList) {
  if (tplList.findvalue(@(v) v != "") == null)
    isOpened(false)
  else
    isOpened(true)
})
