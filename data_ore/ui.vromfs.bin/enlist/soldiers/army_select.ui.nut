from "%enlSqGlob/ui/ui_library.nut" import *

let { isGamepad } = require("%ui/control/active_controls.nut")
let { mkHotkey } = require("%ui/components/uiHotkeysHint.nut")
let { bigPadding, hoverSlotBgColor, miniPadding, panelBgColor, accentColor, selectedPanelBgColor,
  defTxtColor, smallPadding
} = require("%enlSqGlob/ui/designConst.nut")
let { mkArmyIcon, mkArmySimpleIcon } = require("components/armyPackage.nut")
let { getLiveArmyBR, BRByArmies } = require("%enlist/soldiers/armySquadTier.nut")
let { mkBattleRating, mkBattleRatingShort } = require("%enlSqGlob/ui/battleRatingPkg.nut")
let { allArmiesInfo } = require("model/config/gameProfile.nut")
let { curArmy, selectArmy, curArmiesList } = require("model/state.nut")
let { fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let { utf8ToUpper } = require("%sqstd/string.nut")
let { setTooltip } = require("%ui/style/cursors.nut")
let tooltipCtor = require("%ui/style/tooltipCtor.nut")

let colorGray = Color(30, 44, 52)
let sizeIcon = hdpx(26)
let showNameArmy =  Computed(@() curArmiesList.value.len() > 2)

let sound = freeze({
  hover = "ui/enlist/button_highlight"
  click = "ui/enlist/button_click"
})

function mkArmyBtn(armyId, action = @(a) selectArmy(a)) {
  let isSelected = Computed(@() armyId == curArmy.value)
  let icon = mkArmyIcon(armyId, sizeIcon, {margin = 0})
  function builder(sf) {
    let colorIcon = (sf & S_HOVER) && !isSelected.value
      ? colorGray
      : hoverSlotBgColor

    return {
      watch = [isSelected, showNameArmy, BRByArmies]
      rendObj = ROBJ_BOX
      borderWidth = isSelected.value ? [0, 0, hdpx(2), 0] : 0
      borderColor = accentColor
      fillColor = sf & S_HOVER ? hoverSlotBgColor
        : isSelected.value ? selectedPanelBgColor
        : panelBgColor
      behavior = Behaviors.Button
      skipDirPadNav = true
      sound
      onClick = @() action(armyId)
      onHover = @(on) setTooltip( !on ? null
        : tooltipCtor(
            {
              flow = FLOW_VERTICAL
              gap = smallPadding
              children = [
                mkBattleRating(getLiveArmyBR(BRByArmies.value, armyId))
                {
                  rendObj = ROBJ_TEXTAREA
                  behavior = Behaviors.TextArea
                  maxWidth = hdpx(650)
                  color = defTxtColor
                  text = loc("battleRating/desc")
                }.__update(fontSub)
              ]
            }
          )
      )
      children = {
        flow = FLOW_HORIZONTAL
        gap = bigPadding
        padding = showNameArmy.value ? [hdpx(8), hdpx(14)] : [hdpx(8), hdpx(23)]
        vplace = ALIGN_BOTTOM
        children = isSelected.value
          ? icon
          : mkArmySimpleIcon(armyId, sizeIcon, {
              color = colorIcon
              margin = 0
            })
      }
    }
  }
  return watchElemState(builder)
}

function switchArmy(delta) {
  let armies = curArmiesList.value ?? []
  let curArmyIdx = armies.indexof(curArmy.value) ?? 0
  let newArmyId = armies?[curArmyIdx + delta]
  if (newArmyId != null)
    selectArmy(newArmyId)
}

let tb = @(key, val, params) @() {
  watch = [isGamepad, curArmiesList]
  isHidden = !isGamepad.value
  children = mkHotkey(key, @() switchArmy(val))
}.__update(params)

let armySelectButtons = {
  valign = ALIGN_CENTER
  vplace = ALIGN_BOTTOM
  children = [
    function() {
      let children = curArmiesList.value.map(@(armyId) mkArmyBtn(armyId))
      return {
        watch = curArmiesList
        flow = FLOW_HORIZONTAL
        children = children.len() > 1 ? children : null
      }
    }
    tb("^J:LT", -1, { pos = [-hdpx(15), 0] })
    tb("^J:RT", 1, { hplace = ALIGN_RIGHT, pos = [hdpx(15), 0] })
  ]
}

let mkUpperText = @(text, override = {}) {
  rendObj = ROBJ_TEXT
  color = Color(179, 189, 193)
  text = utf8ToUpper(text)
}.__update(override)

let armySelectText = @() {
  watch = [curArmy, showNameArmy, allArmiesInfo, BRByArmies]
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_HORIZONTAL
  gap = smallPadding
  halign = ALIGN_CENTER
  rendObj = ROBJ_BOX
  children = [
    showNameArmy.value
      ? mkUpperText(loc($"country/{allArmiesInfo.value[curArmy.value].country}"), fontSub)
      : mkUpperText(loc("select_army"), fontSub)
    mkBattleRatingShort(getLiveArmyBR(BRByArmies.value, curArmy.value))
  ]
}

let armySelectUi = {
  flow = FLOW_VERTICAL
  vplace = ALIGN_BOTTOM
  gap = miniPadding
  children = [
    armySelectText
    armySelectButtons
  ]
}

return {
  armySelectText
  armySelectUi
  mkArmyBtn
}
