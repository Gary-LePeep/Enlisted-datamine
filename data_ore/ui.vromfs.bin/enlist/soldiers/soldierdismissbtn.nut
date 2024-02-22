from "%enlSqGlob/ui/ui_library.nut" import *

let { fontHeading2, fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let { ceil } = require("%sqstd/math.nut")
let spinner = require("%ui/components/spinner.nut")
let { showMessageWithContent, showMsgbox } = require("%enlist/components/msgbox.nut")
let { bigPadding, msgHighlightedTxtColor } = require("%enlSqGlob/ui/viewConst.nut")
let { txt } = require("%enlSqGlob/ui/defcomps.nut")
let { mkItemCurrency } = require("%enlist/shop/currencyComp.nut")
let { Bordered } = require("%ui/components/txtButton.nut")
let colorize = require("%ui/components/colorize.nut")
let { reserveSoldiers, applySoldierManage, dismissSoldiers, isDismissInProgress
} = require("model/chooseSoldiersState.nut")
let { getLinkedArmyName, getLinkedSquadGuid } = require("%enlSqGlob/ui/metalink.nut")
let { curArmyReserve, curArmyReserveCapacity } = require("model/reserve.nut")
let { RETIRE_ORDER, retireReturn } = require("model/config/soldierRetireConfig.nut")
let { curUpgradeDiscount } = require("%enlist/campaigns/campaignConfig.nut")
let JB = require("%ui/control/gui_buttons.nut")

let waitingSpinner = spinner(hdpx(25))

let mkDismissWarning = @(armyId, guids, count, cb) showMessageWithContent({
  content = {
    flow = FLOW_VERTICAL
    size = [flex(), SIZE_TO_CONTENT]
    halign = ALIGN_CENTER
    gap = hdpx(40)
    children = [
      {
        size = [sw(35), SIZE_TO_CONTENT]
        halign = ALIGN_CENTER
        rendObj = ROBJ_TEXTAREA
        behavior = Behaviors.TextArea
        text = loc("retireSoldier/title")
      }.__update(fontHeading2)
      {
        size = [sw(50), SIZE_TO_CONTENT]
        halign = ALIGN_CENTER
        rendObj = ROBJ_TEXTAREA
        behavior = Behaviors.TextArea
        text = loc("retireSoldier/desc", {
          count = guids.len()
          number = colorize(msgHighlightedTxtColor, guids.len())
        })
      }.__update(fontBody)
      {
        flow = FLOW_HORIZONTAL
        gap = bigPadding
        children = [
          txt(loc("retireSoldier/currencyWillReturn", { count = guids.len() })).__update(fontBody)
          mkItemCurrency({ currencyTpl = RETIRE_ORDER, count })
        ]
      }
    ]
  }
  buttons = [
    {
      text = loc("Yes")
      action = function() {
        dismissSoldiers(armyId, guids)
        cb()
      }
      isCurrent = true
    }
    {
      text = loc("Cancel"), isCancel = true,
      customStyle = { hotkeys = [[$"^{JB.B} | Esc"]] }
    }
  ]
})

let mkApplyChangesWarning = @(cb = null) showMsgbox({
  text = loc("msg/applySoldiersChangesRequired")
  buttons = [
    { text = loc("Apply"),
      action = function() {
        applySoldierManage()
        cb?()
      }
      isCurrent = true
    }
    { text = loc("Cancel")
      isCancel = true
      customStyle = { hotkeys = [[$"^{JB.B} | Esc"]] }
    }
  ]
})

let retireReturnCost = function(reserveSoldiersVal, retireReturnVal, curArmyReserveCapacityV,
    curArmyReserveV, guid, sClass, tier, heroTpl, isHero) {
  if (reserveSoldiersVal.findindex(@(s) s.guid == guid ) == null)
    return null

  let retireCount = retireReturnVal?[sClass][tier] ?? 0
  if (retireCount == 0
      || curArmyReserveCapacityV == 0
      || curArmyReserveV.len() == 0
      || heroTpl != "" || isHero)
    return null

  return retireCount
}

function mkDismissBtn(soldier, override = {}, btnOverride = {}, cb = @() null) {
  if (soldier == null)
    return null

  let { guid, sClass, tier, heroTpl, isHero } = soldier
  let armyId = getLinkedArmyName(soldier)
  return function() {
    let res = { watch = [
      curArmyReserve, curArmyReserveCapacity, isDismissInProgress,
      retireReturn, reserveSoldiers
    ]}

    local retireCount = retireReturnCost(reserveSoldiers.value, retireReturn.value,
      curArmyReserveCapacity.value, curArmyReserve.value,
      guid, sClass, tier, heroTpl, isHero)
    if (retireCount == null)
      return res

    let retireCountMult = 1.0 - curUpgradeDiscount.value
    retireCount = ceil(retireCount * retireCountMult).tointeger()
    return res.__update({
      hplace = ALIGN_RIGHT
      children = [
        isDismissInProgress.value
          ? waitingSpinner
          : Bordered(loc("btn/removeSoldier"),
              @() getLinkedSquadGuid(soldier) != null
                ? mkApplyChangesWarning(cb)
                : mkDismissWarning(armyId, [guid], retireCount, cb),
              { margin = 0 }.__update(btnOverride))
      ]
    }, override)
  }
}


let bigDismissBtn = @(soldier) mkDismissBtn(soldier,
  { size = [flex(), SIZE_TO_CONTENT] }, { btnWidth = flex() })

let dismissBtn = @(soldier, cb = @() null) mkDismissBtn(soldier, {}, {}, cb)

return {
  retireReturnCost
  mkDismissWarning
  mkApplyChangesWarning
  bigDismissBtn
  dismissBtn
}
