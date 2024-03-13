from "%enlSqGlob/ui/ui_library.nut" import *

let { midPadding, isWide } = require("%enlSqGlob/ui/designConst.nut")

return {
  verticalGap = hdpx(54)
  localPadding = hdpx(36)
  rowHeight = hdpx(50)
  localGap = midPadding * 2
  armieChooseBlockWidth = hdpx(144)
  eventBlockWidth = isWide ? hdpx(280) : hdpx(230)
  lockIconSize = hdpxi(16)
  armiesGap = hdpx(8)
}