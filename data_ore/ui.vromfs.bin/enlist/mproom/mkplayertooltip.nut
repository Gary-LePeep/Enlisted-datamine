from "%enlSqGlob/ui/ui_library.nut" import *
let { fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let { smallPadding, bigPadding, activeBgColor, defTxtColor
} = require("%enlSqGlob/ui/viewConst.nut")
let tooltipBox = require("%ui/style/tooltipBox.nut")
let { getPortrait } = require("%enlSqGlob/ui/decoratorsPresentation.nut")
let roomMemberStatuses = require("roomMemberStatuses.nut")
let { mkArmySimpleIcon } = require("%enlist/soldiers/components/armyPackage.nut")
let { memberName, mkStatusImg } = require("components/memberComps.nut")
let { allArmiesInfo } = require("%enlist/soldiers/model/config/gameProfile.nut")

let portraitSize = hdpxi(132)

let mkText = @(text, color = defTxtColor) {
  rendObj = ROBJ_TEXT, color, text
}.__update(fontSub)

let mkTextWithIcon = @(icon, text) {
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  children = [
    {
      size = [hdpx(35), SIZE_TO_CONTENT]
      children = icon
    }
    mkText(text)
  ]
}

function mkPortrait(portrait) {
  let { icon } = getPortrait(portrait)
  return {
    padding = smallPadding
    rendObj = ROBJ_BOX
    borderColor = activeBgColor
    borderWidth = hdpx(1)
    children = {
      size = [portraitSize, portraitSize]
      rendObj = ROBJ_IMAGE
      image = Picture("!{0}:{1}:{1}:K".subst(icon, portraitSize))
    }
  }
}

let mkStatusRow = @(statusCfg) mkTextWithIcon(
  mkStatusImg(statusCfg.icon, statusCfg?.iconColor)
  loc(statusCfg.locId))

function mkPlayerTooltip(player) {
  let { public, nameText } = player
  let { army = null, status = null, portrait = "", nickFrame = "" } = public
  let statusCfg = roomMemberStatuses?[status]
  if (army == "")
    log($"army is an empty string in mkPlayerTooltip in {player}")
  return tooltipBox({
    flow = FLOW_HORIZONTAL
    gap = bigPadding
    children = [
      mkPortrait(portrait)
      @() {
        watch = allArmiesInfo
        flow = FLOW_VERTICAL
        gap = bigPadding
        children = [
          memberName(nameText, nickFrame)
          statusCfg == null ? null : mkStatusRow(statusCfg)
          army == null || army == "" ? null
            : mkTextWithIcon(mkArmySimpleIcon(army, hdpx(20), { margin = 0 }),
              loc($"country/{allArmiesInfo.value[army].country}"))
        ]
      }
    ]
})
}

return mkPlayerTooltip