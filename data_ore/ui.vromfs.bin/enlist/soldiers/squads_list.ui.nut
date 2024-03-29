from "%enlSqGlob/ui/ui_library.nut" import *

let { fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let mkCurSquadsList = require("%enlSqGlob/ui/mkSquadsList.nut")
let { multySquadPanelSize, listCtors, smallPadding
} = require("%enlSqGlob/ui/designConst.nut")
let { txtColor } = listCtors
let { curArmy, curSquadId, setCurSquadId, curChoosenSquads, curUnlockedSquads,
  soldiersBySquad
} = require("model/state.nut")
let squadsParams = require("%enlist/soldiers/model/squadsParams.nut")
let { allSquadsLevels } = require("%enlist/researches/researchesState.nut")
let { notChoosenPerkSquads } = require("model/soldierPerks.nut")
let { unseenSquadsVehicle } = require("%enlist/vehicles/unseenVehicles.nut")
let { unseenSquads } = require("model/unseenSquads.nut")
let { openChooseSquadsWnd } = require("model/chooseSquadsState.nut")
let { squadBgColor } = require("%enlSqGlob/ui/squadsUiComps.nut")
let { blinkUnseenIcon } = require("%ui/components/unseenSignal.nut")
let { armySlotDiscount } = require("%enlist/shop/armySlotDiscount.nut")
let { mkNotifierBlink } = require("%enlist/components/mkNotifier.nut")
let {
  mkAlertIcon, PERK_ALERT_SIGN, ITEM_ALERT_SIGN
} = require("%enlSqGlob/ui/soldiersUiComps.nut")
let { soundDefault } = require("%ui/components/textButton.nut")
let { getLiveSquadBR, BRInfoBySquads } = require("%enlist/soldiers/armySquadTier.nut")


let unseenIcon = blinkUnseenIcon(0.7)

let mkUnseenAlert = @(guid) mkAlertIcon(ITEM_ALERT_SIGN, Computed(@()
  (unseenSquadsVehicle.value?[guid].len() ?? 0) > 0
))

let mkPerksAlert = @(squadId) mkAlertIcon(PERK_ALERT_SIGN, Computed(@()
  (notChoosenPerkSquads.value?[curArmy.value][squadId] ?? 0) > 0))

let managementIcon = @(sf, sizeArr = [hdpxi(40), hdpxi(20)]) {
  rendObj = ROBJ_IMAGE
  size = sizeArr
  keepAspect = KEEP_ASPECT_FIT
  image = Picture("!ui/squads/squad_manage.svg:{0}:{1}:K".subst(sizeArr[0], sizeArr[1]))
  color = txtColor(sf)
}

function mkSlotAlertsComponent(squad){
  return @() {
    flow = FLOW_HORIZONTAL
    hplace = ALIGN_RIGHT
    valign = ALIGN_CENTER
    children = [
      mkUnseenAlert(squad.guid)
      mkPerksAlert(squad.squadId)
    ]
  }
}

let unseenSquadsIcon = @() {
  watch = [unseenSquads, curArmy]
  hplace = ALIGN_RIGHT
  children = (unseenSquads.value?[curArmy.value] ?? {}).findindex(@(v) v)
    ? unseenIcon
    : null
}


function mkSquadManagementBtn(restSquadsCount = null, size = null,
  margin = null, flow = FLOW_HORIZONTAL
){
  let squadManageButtonStateFlags = Watched(0)
  let discount = @() {
    watch = armySlotDiscount
    vplace = ALIGN_BOTTOM
    hplace = ALIGN_CENTER
    pos = [0, smallPadding]
    children = armySlotDiscount.value <= 0 ? null : mkNotifierBlink(loc("shop/discount",
          { percents = armySlotDiscount.value }), {}, { color = 0xffff313b })
  }
  let notifier = @() { hplace = ALIGN_RIGHT children = unseenSquadsIcon}
  let squadManageButton = watchElemState(function(sf) {
    let rest = restSquadsCount?.value ?? 0
    return {
      watch = [restSquadsCount]
      rendObj = ROBJ_SOLID
      size = size ?? [multySquadPanelSize[0], SIZE_TO_CONTENT]
      minHeight = (multySquadPanelSize[1] * 0.5).tointeger()
      margin
      behavior = Behaviors.Button
      xmbNode = XmbNode()
      color = squadBgColor(sf, false)
      onClick = @() openChooseSquadsWnd(curArmy.value, curSquadId.value)
      onDetach = @() squadManageButtonStateFlags(0)
      sound = soundDefault
      children = [
        {
          flow
          halign = ALIGN_CENTER
          vplace = ALIGN_CENTER
          valign = ALIGN_CENTER
          gap = smallPadding
          size = flex()
          children = [
            managementIcon(sf, [hdpxi(45), hdpxi(30)])
            rest < 1 ? null : {
              rendObj = ROBJ_TEXT
              color = txtColor(sf)
              text = $"+{rest}"
            }.__update(fontSub)
          ]
        }
        notifier
        discount
      ]
    }
  }, {stateFlags = squadManageButtonStateFlags})
  return squadManageButton
}

function mkSquadsList() {
  let restSquadsCount = Computed(@()
    max(curUnlockedSquads.value.len() - curChoosenSquads.value.len(), 0))

  let squadManageButton = mkSquadManagementBtn(restSquadsCount)
  let curSquadsList = Computed(@() (curChoosenSquads.value ?? [])
    .map(function(squad) {
      let squadId = squad.squadId
      let { size = 0 } = squadsParams.value?[curArmy.value][squadId]
      let currentSize = soldiersBySquad.value?[squad.guid].len() ?? 0
      return squad.__merge({
        addChild = mkSlotAlertsComponent(squad)
        level = allSquadsLevels.value?[squadId] ?? 0
        battleRating = getLiveSquadBR(BRInfoBySquads.value, squadId)
        squadSize = currentSize < size ? $"{currentSize}/{size}" : currentSize
      })
    }))

  return mkCurSquadsList({
    curSquadsList
    curSquadId
    setCurSquadId
    addedObj = squadManageButton
  })
}

return {
  mkSquadsList
  mkSlotAlertsComponent
  mkSquadManagementBtn = kwarg(mkSquadManagementBtn)
}