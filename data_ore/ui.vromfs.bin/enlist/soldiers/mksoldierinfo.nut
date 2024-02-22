from "%enlSqGlob/ui/ui_library.nut" import *

let { smallPadding, bigPadding, soldierWndWidth } = require("%enlSqGlob/ui/designConst.nut")
let soldierEquipUi = require("soldierEquip.ui.nut")
let soldierLookUi = require("soldierLook.ui.nut")
let mkNameBlock = require("%enlist/components/mkNameBlock.nut")
let { closeEquipPresets } = require("%enlist/preset/presetEquipUi.nut")
let { hasClientPermission } = require("%enlSqGlob/client_user_rights.nut")
let { Bordered, FAButton } = require("%ui/components/txtButton.nut")
let { isCustomizationWndOpened } = require("%enlist/soldiers/soldierCustomizationState.nut")
let { openPerkTree, openPerkList } = require("%enlist/meta/perks/perkTree.nut")
let { getLinkedSquadGuid } = require("%enlSqGlob/ui/metalink.nut")
let { notChoosenPerkSoldiers } = require("model/soldierPerks.nut")
let { mkAlertIcon, PERK_ALERT_SIGN } = require("%enlSqGlob/ui/soldiersUiComps.nut")
let { isDebugBuild } = require("%dngscripts/appInfo.nut")

let hasDebugSoldierLook = hasClientPermission("debug_soldier_look")
let canSwitchSoldierLook = Computed(@() hasDebugSoldierLook.value || isDebugBuild)

let soldierLookOpened = Watched(false)
soldierLookOpened.subscribe(@(_) closeEquipPresets())

let btnStyle = { btnWidth = flex() }

let mkAnimations = @(isMoveRight) [
  { prop = AnimProp.opacity, from = 0, to = 1, duration = 0.5, play = true, easing = OutCubic }
  { prop = AnimProp.translate, from =[hdpx(150) * (isMoveRight ? -1 : 1), 0], play = true, to = [0, 0], duration = 0.2, easing = OutQuad }
  { prop = AnimProp.opacity, from = 1, to = 0, duration = 0.2, playFadeOut = true, easing = OutCubic }
  { prop = AnimProp.translate, from =[0, 0], playFadeOut = true, to = [hdpx(150) * (isMoveRight ? 1 : -1), 0], duration = 0.2, easing = OutQuad }
]

let mkCustomButtons = function(curSoldierInfo) {
  let needPerkNotifier = Computed(@()
    (notChoosenPerkSoldiers.value?[curSoldierInfo.value?.guid] ?? 0) > 0)
  return @() {
    watch = [canSwitchSoldierLook, curSoldierInfo]
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    halign = ALIGN_CENTER
    vplace = ALIGN_BOTTOM
    gap = bigPadding
    children = [
      Bordered(loc("soldierAppearance"), @() isCustomizationWndOpened(true), btnStyle.__merge({
        isEnabled = getLinkedSquadGuid(curSoldierInfo.value) != null
      }))
      Bordered(loc("perks/tree"), @() openPerkTree(curSoldierInfo), btnStyle.__merge({
        fgChild = {
          vplace = ALIGN_TOP
          hplace = ALIGN_RIGHT
          children = mkAlertIcon(PERK_ALERT_SIGN, needPerkNotifier)
          padding = smallPadding
        }
      }))
      FAButton("angle-right", @(event) openPerkList(event, curSoldierInfo))
      canSwitchSoldierLook.value
        ? FAButton("address-card", @() soldierLookOpened(!soldierLookOpened.value))
        : null
    ]
  }
}

let content = kwarg(@(
  soldier, canManage, animations, selectedKeyWatch, mkDismissBtn,
  onDoubleClickCb = null, onResearchClickCb = null, dropExceptionCb = null, buttons = null
) {
  size = [soldierWndWidth, flex()]
  flow = FLOW_VERTICAL
  gap = bigPadding
  children = [
    {
      size = [flex(), SIZE_TO_CONTENT]
      animations
      transform = {}
      children = mkNameBlock(soldier)
    }
    @() {
      watch = soldierLookOpened
      size = flex()
      children = (soldierLookOpened.value ? soldierLookUi : soldierEquipUi)({
        soldier
        canManage
        selectedKeyWatch
        onDoubleClickCb
        dropExceptionCb
        onResearchClickCb
      }, KWARG_NON_STRICT)
    }
    function() {
      let children = mkDismissBtn(soldier.value)
      return {
        watch = soldier
        size = [flex(), SIZE_TO_CONTENT]
        margin = children == null ? null : [bigPadding,0,0,0]
        children
      }
    }
    buttons
  ]
})

let mkSoldierInfo = kwarg(function(
  soldierInfoWatch, isMoveRight = true, selectedKeyWatch = Watched(null),
  onDoubleClickCb = null, onResearchClickCb = null, mkDismissBtn = @(_) null,
  dropExceptionCb = null, buttons = null
) {
  let animations = mkAnimations(isMoveRight)
  local lastSoldierGuid = soldierInfoWatch.value?.guid

  let children = content({
    soldier = soldierInfoWatch
    canManage = true
    animations
    selectedKeyWatch
    onDoubleClickCb
    dropExceptionCb
    onResearchClickCb
    mkDismissBtn
    buttons
  })

  return function() {
    let newSoldierGuid = soldierInfoWatch.value?.guid
    if (lastSoldierGuid != null && newSoldierGuid != lastSoldierGuid)
      anim_start("hdrAnim") //no need change content anim when window appear anim playing
    lastSoldierGuid = newSoldierGuid

    return {
      watch = soldierInfoWatch
      size = soldierInfoWatch.value != null ? [soldierWndWidth, flex()] : null
      children = soldierInfoWatch.value != null ? children : null
    }
  }
})

return {
  mkSoldierInfo
  mkCustomButtons
}