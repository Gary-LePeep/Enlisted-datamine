from "%enlSqGlob/ui/ui_library.nut" import *

let hoverHoldAction = require("%darg/helpers/hoverHoldAction.nut")
let { fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let { txt } = require("%enlSqGlob/ui/defcomps.nut")
let { gameProfile } = require("%enlist/soldiers/model/config/gameProfile.nut")
let { unlockedCampaigns } = require("%enlist/meta/campaigns.nut")
let { medalsByCampaign } = require("medalsState.nut")
let { setTooltip } = require("%ui/style/cursors.nut")
let { mkMedalCard, mkDisabledMedalCard, mkMedalTooltip } = require("medalsPkg.nut")
let { PROFILE_WIDTH } = require("profilePkg.nut")
let { smallPadding, midPadding } = require("%enlSqGlob/ui/designConst.nut")
let { makeVertScroll, thinStyle } = require("%ui/components/scrollbar.nut")
let { seenMedals, markSeenMedal, markMedalsOpened } = require("unseenProfileState.nut")
let { smallUnseenNoBlink } = require("%ui/components/unseenComps.nut")
let { getCampaignTitle } = require("%enlSqGlob/ui/itemsInfo.nut")


const MAX_COLUMNS = 6

let mCardWidth = ((PROFILE_WIDTH - (MAX_COLUMNS - 1) * midPadding) / MAX_COLUMNS).tointeger()
let mIconSize = hdpx(160)

function mkMedalBlock(medal, isUnseen) {
  let { id, received = [], bgImage = null, stackImages = [] } = medal
  return {
    size = [mCardWidth, mCardWidth]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    behavior = Behaviors.Button
    onHover = function(on) {
      setTooltip(on ? mkMedalTooltip(medal) : null)
      if (isUnseen)
        hoverHoldAction("merkSeenDecorator", id, @(v) markSeenMedal(v))(on)
    }
    xmbNode = XmbNode({
      canFocus = true
      wrap = false
      isGridLine=true
      scrollToEdge = [false, true]
    })
    children = received.len() > 0
      ? mkMedalCard(bgImage, stackImages, mIconSize)
      : mkDisabledMedalCard(bgImage, stackImages, mIconSize)
  }
}

function mkCampaignMedals(campaignId, medalsByCamp, unseen) {
  let campaignMedals = medalsByCamp?[campaignId] ?? []
  if (campaignMedals.len() == 0)
    return null

  return {
    size = [PROFILE_WIDTH, SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    children = [
      txt({
        text = getCampaignTitle(campaignId)
        margin = midPadding
      }).__update(fontBody)
      wrap(campaignMedals.map(function(medal) {
        let isUnseen = medal.id in unseen
        return {
          children = [
            mkMedalBlock(medal, isUnseen)
            isUnseen ? smallUnseenNoBlink : null
          ]
        }
      }), {
        width = PROFILE_WIDTH
        hGap = midPadding
        vGap = midPadding
      })
    ]
  }
}

function medalsListUi() {
  let medalsByCamp = medalsByCampaign.value
  let { unseen = {}, unopened = {} } = seenMedals.value
  return {
    xmbNode = XmbContainer({
      isGridLine = true
      canFocus = false
      wrap = false
      scrollSpeed = [0, 2.0]
    })
    watch = [medalsByCampaign, unlockedCampaigns, gameProfile, seenMedals]
    size = flex()
    padding = smallPadding
    onDetach = @() markMedalsOpened(unopened.keys())
    children = makeVertScroll({
      size = [PROFILE_WIDTH, SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      gap = midPadding
      children = unlockedCampaigns.value.map(@(c) mkCampaignMedals(c, medalsByCamp, unseen))
    }, {
      styling = thinStyle
    })
  }
}

return {
  size = flex()
  children = medalsListUi
}
