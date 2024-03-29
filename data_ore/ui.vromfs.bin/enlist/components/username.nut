from "%enlSqGlob/ui/ui_library.nut" import *

let { fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let faComp = require("%ui/components/faComp.nut")
let { defTxtColor, panelBgColor }= require("%enlSqGlob/ui/designConst.nut")
let userInfo = require("%enlSqGlob/userInfo.nut")
let { is_xbox } = require("%dngscripts/platform.nut")

let userName = @() {
  rendObj = ROBJ_TEXT
  text = userInfo.value?.nameorig ?? ""
  watch = userInfo
  color = defTxtColor
}.__update(fontBody)

let userIcon = faComp("user", {
  hplace = ALIGN_RIGHT
  vplace = ALIGN_BOTTOM
  margin = hdpx(2)
  color = defTxtColor
})

let widgetUserName = is_xbox ? {
  rendObj = ROBJ_SOLID
  hplace = ALIGN_RIGHT
  vplace = ALIGN_BOTTOM
  padding = [fsh(1), fsh(2)]
  gap = fsh(1)
  color = panelBgColor
  flow = FLOW_HORIZONTAL
  children = [
    userIcon
    userName
  ]
} : null

return {
  userName
  widgetUserName
}
