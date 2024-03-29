from "%enlSqGlob/ui/ui_library.nut" import *

let { fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let faComp = require("%ui/components/faComp.nut")
let { defTxtColor, smallPadding, bigPadding, panelBgColor,
  gap, noteTxtColor, disabledTxtColor
} = require("%enlSqGlob/ui/designConst.nut")
let { autoscrollText, txt, note } = require("%enlSqGlob/ui/defcomps.nut")
let tooltipBox = require("%ui/style/tooltipBox.nut")
let { setTooltip } = require("%ui/style/cursors.nut")
let { READY } = require("%enlSqGlob/readyStatus.nut")
let { mkSquadSpecIcon } = require("%enlSqGlob/ui/squadsUiComps.nut")
let { kindIcon, kindName } = require("%enlSqGlob/ui/soldiersUiComps.nut")
let mkSClassLimitsComp = require("%enlist/soldiers/model/squadClassLimits.nut")
let { utf8ToUpper } = require("%sqstd/string.nut")
let { getLiveSquadBR, BRInfoBySquads } = require("%enlist/soldiers/armySquadTier.nut")
let { mkBattleRating } = require("%enlSqGlob/ui/battleRatingPkg.nut")

let mkMaxSquadSizeComp = @(curSquadParams, vehicleCapacity) Computed(function() {
  let size = curSquadParams.value?.size ?? 1
  let vCapacity = vehicleCapacity.value
  return vCapacity > 0 ? min(size, vCapacity) : size
})

let mkClassLimitsHint = @(classLimits) {
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  gap = gap
  children = [
    {
      rendObj = ROBJ_TEXT
      size = [hdpx(30), SIZE_TO_CONTENT]
      text = $"{classLimits.used}/{classLimits.total}"
    }
    kindIcon(classLimits.sKind, hdpx(30))
    kindName(classLimits.sKind).__update(fontSub, { color = defTxtColor })
  ]
}

let classAmountHint = @(sClassLimits, battleRating) {
  flow = FLOW_VERTICAL
  gap
  children = [
    {
      rendObj = ROBJ_TEXTAREA
      behavior = Behaviors.TextArea
      maxWidth = hdpx(400)
      text = loc("hint/squadClassLimits")
    }
  ]
    .extend(sClassLimits.map(mkClassLimitsHint))
    .append(mkBattleRating(battleRating))
}

let mkClassAmount = @(sKind, total, used) {
  size = SIZE_TO_CONTENT
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  children = [
    kindIcon(sKind, hdpx(24))
    note({ text = $"{used}/{total}" })
  ]
}

let squadClassesUi = @(sClassLimits) @() {
  watch = sClassLimits
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_HORIZONTAL
  margin = [0, bigPadding]
  halign = ALIGN_RIGHT
  gap = {
    rendObj = ROBJ_SOLID
    size = [hdpx(1), flex()]
    color = disabledTxtColor
    margin = [0, bigPadding]
  }
  children = sClassLimits.value
    .filter(@(c) c.total > 0)
    .map(@(c) mkClassAmount(c.sKind, c.total, c.used))
}

let sizeHint = @(battleAmount, maxAmount) @() {
  watch = [battleAmount, maxAmount]
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  maxWidth = hdpx(500)
  color = defTxtColor
  text = loc("hint/maxSquadSize", {
    battle = battleAmount.value
    max = maxAmount.value
  })
}

let squadSizeUi = @(battleAmount, maxSquadSize) function() {
  let res = { watch = [battleAmount, maxSquadSize] }
  let size = maxSquadSize.value
  if (size <= 0)
    return res

  return res.__update({
    flow = FLOW_HORIZONTAL
    margin = [smallPadding, bigPadding]
    valign = ALIGN_CENTER
    vplace = ALIGN_BOTTOM
    behavior = Behaviors.Button
    gap
    onHover = @(on) setTooltip(!on ? null : tooltipBox(sizeHint(battleAmount, maxSquadSize)))
    skipDirPadNav = true
    children = [
      faComp("user-o", {
        fontSize = hdpx(12)
        color = noteTxtColor
      })
      txt({ text = $"{battleAmount.value}/{size}", color = noteTxtColor})
    ]
  })
}

function squadHeader(curSquad, curSquadParams, soldiersList, vehicleCapacity, soldiersStatuses) {
  let maxSquadSize = mkMaxSquadSizeComp(curSquadParams, vehicleCapacity)
  let battleAmount = Computed(@()
    soldiersList.value.reduce(@(res, s) soldiersStatuses.value?[s.guid] == READY ? res + 1 : res, 0))
  let sClassLimits = mkSClassLimitsComp(curSquad, curSquadParams, soldiersList, soldiersStatuses)

  return function() {
    let res = { watch = [ curSquad, sClassLimits, BRInfoBySquads ] }
    let squad = curSquad.value
    if (!squad)
      return res

    let group = ElemGroup()
    let battleRating = getLiveSquadBR(BRInfoBySquads.value, curSquad.value.squadId)
    return res.__update({
      size = [flex(), hdpx(70)]
      flow = FLOW_VERTICAL
      behavior = Behaviors.Button
      group
      onHover = @(on) setTooltip(on
        ? tooltipBox(classAmountHint(sClassLimits.value, battleRating))
        : null)
      skipDirPadNav = true
      rendObj = ROBJ_SOLID
      color = panelBgColor
      children = [
        {
          size = [flex(), hdpx(26)]
          flow = FLOW_HORIZONTAL
          gap
          children = [
            mkSquadSpecIcon(squad)
            {
              size = [flex(), SIZE_TO_CONTENT]
              margin = [smallPadding, bigPadding]
              children = autoscrollText({
                vplace = ALIGN_CENTER
                group
                text = utf8ToUpper(loc(squad?.titleLocId))
                color = noteTxtColor
                textParams = fontSub
              })
            }
          ]
        }
        {
          size = flex()
          flow = FLOW_HORIZONTAL
          children = [
            squadSizeUi(battleAmount, maxSquadSize)
            squadClassesUi(sClassLimits)
          ]
        }
      ]
    })
  }
}

return kwarg(squadHeader)