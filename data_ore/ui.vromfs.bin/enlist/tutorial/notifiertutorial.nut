from "%enlSqGlob/ui/ui_library.nut" import *
let {
  PERK_ALERT_SIGN, ITEM_ALERT_SIGN, UPGRADE_ALERT_SIGN
} = require("%enlSqGlob/ui/soldiersUiComps.nut")
let { curArmy } = require("%enlist/soldiers/model/state.nut")
let { notChoosenPerkArmies, clearPerkNotifiersArmy
} = require("%enlist/soldiers/model/soldierPerks.nut")
let { unseenArmiesVehicle, markArmyVehiclesSeen
} = require("%enlist/vehicles/unseenVehicles.nut")
let { settings } = require("%enlist/options/onlineSettings.nut")
let { fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let { blinkingIcon } = require("%enlSqGlob/ui/blinkingIcon.nut")
let { smallPadding, bigPadding, defTxtColor, titleTxtColor
} = require("%enlSqGlob/ui/designConst.nut")
let { markInventorySlotsSeen, armyUpgradeAlerts
} = require("%enlist/soldiers/model/unseenWeaponry.nut")
let faComp = require("%ui/components/faComp.nut")
let { soundActive } = require("%ui/components/textButton.nut")
let { withTooltip } = require("%ui/style/cursors.nut")
let tooltipCtor = require("%ui/style/tooltipCtor.nut")

const SEEN_ID = "seen/notifierTutorials"
let seenData = Computed(@() settings.value?[SEEN_ID] ?? {})

function markNotifierSeen(notifierId) {
  settings.mutate(function(set) {
    let saved = (clone set?[SEEN_ID] ?? {}).rawset(notifierId, true) //warning disable: -unwanted-modification
    set[SEEN_ID] <- saved
  })
}

function resetSeen() {
  if (SEEN_ID not in settings.value)
    return

  settings.mutate(@(v) v.$rawdelete(SEEN_ID))
}

enum Notifiers {
  PERK
  VEHICLE
  WEAPON
}

let notifierConfig = {
  [Notifiers.PERK] = {
    icon = PERK_ALERT_SIGN
    order = 1
    locId = "hint/perkNotifier"
    removeFn = clearPerkNotifiersArmy
  },
  [Notifiers.VEHICLE] = {
    icon = ITEM_ALERT_SIGN
    order = 2
    locId = "hint/newVehicleNotifier"
    removeFn = markArmyVehiclesSeen
  },
  [Notifiers.WEAPON] = {
    icon = UPGRADE_ALERT_SIGN
    order = 3
    locId = "hint/newWeaponNotifier"
    removeFn = markInventorySlotsSeen
  }
}

let order = @(notifierId) notifierConfig?[notifierId].order ?? -1

let needShowAlert = Computed(function() {
  let activeNotifiers = []
  if ((notChoosenPerkArmies.value?[curArmy.value] ?? 0) > 0)
    activeNotifiers.append(Notifiers.PERK)
  if ((unseenArmiesVehicle.value?[curArmy.value] ?? 0) > 0)
    activeNotifiers.append(Notifiers.VEHICLE)
  if (armyUpgradeAlerts.value?[curArmy.value] ?? false)
    activeNotifiers.append(Notifiers.WEAPON)

  let seen = seenData.value
  activeNotifiers.sort(@(a, b) a in seen <=> b in seen || order(a) <=> order(b))
  return activeNotifiers?[0]
})

let animatedParams = {
  transform = {}
  animations = [
    {
      prop = AnimProp.opacity, from = 0.5, to = 1, duration = 1.5,
      play = true, loop = true, easing = Blink
    }
    {
      prop = AnimProp.opacity, from = 1, to = 1, delay = 6,
      play = true, loop = true, easing = Blink
    }
  ]
}

let disableCmp = watchElemState(@(sf) {
  behavior = Behaviors.Button
  sound = soundActive
  gap = smallPadding
  onClick = @(_) notifierConfig?[needShowAlert.value].removeFn?(curArmy.value)
  children = withTooltip(
    faComp("times-rectangle", {
        color = sf & S_HOVER ? titleTxtColor : defTxtColor
      }),
    @() tooltipCtor({
        rendObj = ROBJ_TEXT
        padding = bigPadding
        text = loc("btn/removeNotifiers")
      }.__update(fontSub))
  )
})

let notifierHint = function() {
  if (needShowAlert.value == null)
    return { watch = needShowAlert }
  let notifierId = needShowAlert.value
  let params = notifierId not in seenData.value ? animatedParams : {}
  let { icon, locId } = notifierConfig[notifierId]
  return {
    watch = [needShowAlert, seenData]
    halign = ALIGN_CENTER
    gap = smallPadding
    flow = FLOW_HORIZONTAL
    children = [
      {
        flow = FLOW_HORIZONTAL
        children = [
          blinkingIcon(icon).__update({ animations = null })
          {
            rendObj = ROBJ_TEXTAREA
            behavior = Behaviors.TextArea
            text = loc(locId)
          }.__update(fontSub)
        ]
      }.__update(params)
      {
        vplace = ALIGN_TOP
        children = disableCmp
      }
    ]
  }
}

console_register_command(resetSeen, "meta.resetSeenNotifiers")

return {
  Notifiers
  markNotifierSeen
  notifierHint
}
