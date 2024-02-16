from "%enlSqGlob/ui_library.nut" import *

let { fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let { defTxtColor, titleTxtColor, accentColor, miniPadding, smallPadding, midPadding, bigPadding,
  brightAccentColor
} = require("%enlSqGlob/ui/designConst.nut")
let { FAButton } = require("%ui/components/txtButton.nut")
let { buttonSound } = require("%ui/style/sounds.nut")
let { squadMembers, isInvitedToSquad, enabledSquad, squadId
} = require("%enlist/squad/squadState.nut")
let { getContactNick, contacts } = require("contact.nut")
let { friendsUids } = require("%enlist/contacts/contactsWatchLists.nut")
let { mkContactOnlineStatus } = require("contactPresence.nut")
let contactContextMenu = require("contactContextMenu.nut")
let { isGamepad } = require("%ui/control/active_controls.nut")
let locByPlatform = require("%enlSqGlob/locByPlatform.nut")
let spinner = require("%ui/components/spinner.nut")
let faComp = require("%ui/components/faComp.nut")
let { mkArmyIcon } = require("%enlist/soldiers/components/armyPackage.nut")
let { curArmiesList } = require("%enlist/soldiers/model/state.nut")
let { roomIsLobby } = require("%enlist/state/roomState.nut")


let defNickStyle = { color = defTxtColor }.__update(fontBody)
let statusCommonStyle = fontBody
let iconHeight = hdpxi(26)
let iconHeightSmall = hdpxi(23)
let iconHeightBig = hdpxi(32)
let waitingSpinner = spinner(hdpxi(14))


let playerStatusesIcons = freeze({
  online = {
    icon = "circle"
    color = 0xFF65FE7A
  }
  offline = {
    icon = "circle"
    color = 0xFFD9281D
  }
  unknown = {
    icon = "circle-o"
    color = defTxtColor
  }
})

let playerSquadStatuses = freeze({
  inBattle = {
    text = loc("contact/inBattle")
    color = titleTxtColor
    icon = "gamepad"
  }
  leader = {
    text = loc("squad/Chief")
    color = accentColor
    icon = "star"
  }
  offlineInSquad = {
    text = loc("contact/Offline")
    color = titleTxtColor
    icon = "times"
  }
  ready = {
    text = loc("contact/Ready")
    color = brightAccentColor
    icon = "check"
  }
  unready = {
    text = loc("contact/notReady")
    color = 0xFFC0C0C0
    icon = "times"
  }
  invited = {
    text = loc("contact/Invited")
    color = defTxtColor
  }
  unknown = {
    text = loc("contact/Unknown")
    color = defTxtColor
  }
  online = {
    text = loc("contact/Online")
    color = titleTxtColor
  }
  offline = {
    text = loc("contact/Offline")
    color = defTxtColor
  }
})

let armyIconSizes = freeze({
  normandy_axis = iconHeightSmall
  moscow_axis = iconHeightSmall
  berlin_axis = iconHeightSmall
  tunisia_axis = iconHeightSmall
  stalingrad_axis = iconHeightSmall
  pacific_axis = iconHeightSmall
  ger = iconHeightSmall
  jap = iconHeightSmall
})

let userNickname = @(contact, override) {
  size = [flex(), SIZE_TO_CONTENT]
  behavior = Behaviors.Marquee
  clipChildren = true
  rendObj = ROBJ_TEXT
  text = getContactNick(contact)
}.__update(override)


let function statusIcon(isPlayerOnline) {
  let iconToShow = isPlayerOnline == null ? playerStatusesIcons.unknown
    : isPlayerOnline ? playerStatusesIcons.online
    : playerStatusesIcons.offline
  let { icon, color } = iconToShow
  return faComp(icon, { fontSize = hdpxi(12), color })
}


let statusBlock = @(isPlayerOnline, contact) function() {
  let watch = [enabledSquad, squadMembers, isInvitedToSquad, friendsUids]
  let squadMember = enabledSquad.value && squadMembers.value?[contact.uid]
  let isInvited = isInvitedToSquad.value?[contact.uid]
  local squadStatusText = null

  if (squadMember != null) {
    squadStatusText = squadMember.state?.inBattle ? playerSquadStatuses.inBattle
      : squadMember.isLeader ? playerSquadStatuses.leader
      : !isPlayerOnline ? playerSquadStatuses.offlineInSquad
      : squadMember.state?.ready ? playerSquadStatuses.ready
      : playerSquadStatuses.unready
  }
  else if (isInvited)
    squadStatusText = playerSquadStatuses.invited
  else if (contact.userId in friendsUids.value)
    squadStatusText = isPlayerOnline == null ? playerSquadStatuses.unknown
      : isPlayerOnline ? playerSquadStatuses.online
      : playerSquadStatuses.offline

  if (squadStatusText == null)
    return null

  let { color, text, icon = null } = squadStatusText
  return {
    watch
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    gap = smallPadding
    valign = ALIGN_CENTER
    children = [
      isInvited ? waitingSpinner
        : icon != null ? faComp(icon, {
          fontSize = statusCommonStyle.fontSize
          color
        })
        : null
      {
        rendObj = ROBJ_TEXT
        text
        color
      }.__update(statusCommonStyle)
    ]
  }
}


let contactActionButton = @(action, userId) FAButton(action.icon, @() action.action(userId),
  {
    size = [hdpx(36), hdpx(36)]
    key = userId
    skipDirPadNav = true
    btnWidth = hdpx(36)
    hint = {
      rendObj = ROBJ_TEXT
      text = locByPlatform(action.locId)
    }.__update(statusCommonStyle)
  })


let function onContactClick(event, contact, contextMenuActions) {
  if (event.button >= 0 && event.button <= 2)
    contactContextMenu.open(contact, event, contextMenuActions)
}

let mkChildrenIcon = @(arr) arr.map(@(armyId) {
  size = [iconHeight, SIZE_TO_CONTENT]
  halign = ALIGN_CENTER
  children = mkArmyIcon(
    armyId,
    armyIconSizes?[armyId] ?? iconHeight,
    {
      margin = 0
    })
})


let memberAvatarCtor = @(userId) function() {
  let watch = [enabledSquad, squadMembers, squadId, roomIsLobby]
  let res = { watch }
  if (roomIsLobby.value)
    return res
  let squadLeader = enabledSquad.value && squadId.value == userId
    ? squadMembers.value?[userId]
    : null
  if (squadLeader == null)
    return res
  let randomTeam = squadLeader.state?.isTeamRandom ?? false
  let curArmy = squadLeader.state?.curArmy
  if (!randomTeam && curArmy)
    return res.__update({
      size = [iconHeight * 1.5, SIZE_TO_CONTENT]
      halign = ALIGN_CENTER
      children = mkArmyIcon(curArmy, iconHeightBig, {margin = 0})
    })

  let armiesList = curArmiesList.value
  let children = []
  for(local i = 0; i < armiesList.len(); i += 2)
    children.append({
      flow = FLOW_HORIZONTAL
      gap = miniPadding
      children = mkChildrenIcon(armiesList.slice(i, i + 2))
    })

  return res.__update({
    flow = FLOW_VERTICAL
    padding = smallPadding
    gap = miniPadding
    size = [iconHeight * 2.5, flex()]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children
  })
}

let gapFlex = freeze({ size = flex() })
let mkContactBlock = @(contact, contextMenuActions = [], inContactActions = []) function() {
  let group = ElemGroup()
  let { userId } = contact

  let actionsButtons = inContactActions.map(function(action) {
    let isVisible = action.mkIsVisible(userId)
    return @() {
      watch = isVisible
      children = !isVisible.value ? null : contactActionButton(action, userId)
    }
  })

  let isPlayerOnline = mkContactOnlineStatus(userId)
  let player = @() {
    watch = isPlayerOnline
    size = flex()
    flow = FLOW_VERTICAL
    gap = gapFlex
    valign = ALIGN_CENTER
    children = [
      {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        gap = smallPadding
        valign = ALIGN_CENTER
        children = [
          statusIcon(isPlayerOnline.value)
          userNickname(contact, defNickStyle)
        ]
      }
      statusBlock(isPlayerOnline.value, contact)
    ]
  }

  let avatar = memberAvatarCtor(userId.tointeger())
  let onClick = @(event) onContactClick(event, contact, contextMenuActions)

  return {
    watch = contacts
    size = flex()
    children = watchElemState(@(sf) {
      watch = isGamepad
      rendObj = ROBJ_WORLD_BLUR_PANEL
      size = flex()
      fillColor = sf & S_HOVER ? Color(120,120,120) : 0
      padding = [midPadding, bigPadding]
      gap = bigPadding
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      behavior = Behaviors.Button
      xmbNode = XmbNode({
        canFocus = true
        scrollToEdge = true
        wrap = false
      })
      onClick
      stopHover = true
      group
      sound = buttonSound
      children = [ player, avatar ]
        .extend(!isGamepad.value && (sf & S_HOVER) ? actionsButtons : [])
    })
  }
}

return mkContactBlock
