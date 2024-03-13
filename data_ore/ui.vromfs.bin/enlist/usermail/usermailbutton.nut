from "%enlSqGlob/ui/ui_library.nut" import *

let { fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let { defTxtColor, unseenColor } = require("%enlSqGlob/ui/designConst.nut")
let { isUsermailWndOpened, unseenLettersCount } = require("%enlist/usermail/usermailState.nut")
let { hasUsermail } = require("%enlist/featureFlags.nut")
let { FAFlatButton } = require("%ui/components/txtButton.nut")
let { navBottomBarHeight } = require("%enlist/mainMenu/mainmenu.style.nut")

let numUnseenCmp = @(count) count == 0 ? null : {
  rendObj = ROBJ_TEXT
  text = count
  hplace = ALIGN_RIGHT
  vplace = ALIGN_TOP
  pos = [-hdpx(3), hdpx(4)]
  fontFx = FFT_GLOW
  fontFxColor = Color(0, 0, 0, 255)
  color = unseenColor
}.__update(fontSub)

let hintTxtStyle = { color = defTxtColor }.__update(fontSub)

let hoverHint = {
  rendObj = ROBJ_TEXT
  text = loc("mail/mailTab")
}.__update(hintTxtStyle)


return @() {
  watch = [hasUsermail, unseenLettersCount]
  children = !hasUsermail.value ? null
    : [
        FAFlatButton("envelope", @() isUsermailWndOpened(true), {
          hint = hoverHint
          btnWidth = navBottomBarHeight
          btnHeight = navBottomBarHeight
        })
        numUnseenCmp(unseenLettersCount.value)
      ]
}