from "%enlSqGlob/ui/ui_library.nut" import *

let { fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let { defTxtColor, midPadding, smallPadding, panelBgColor, hoverPanelBgColor, darkTxtColor,
  darkPanelBgColor, commonBtnHeight, titleTxtColor
} = require("%enlSqGlob/ui/designConst.nut")
let { canChangeQueueParams, isInQueue } = require("%enlist/state/queueState.nut")
let { availableClusters, clusters, clusterLoc, countryLoc, isAutoCluster, ownCountry
} = require("%enlist/clusterState.nut")
let { isInSquad, isSquadLeader, squadSharedData } = require("%enlist/squad/squadState.nut")
let squadClustersWatched = squadSharedData.clusters
let squadAutoClusterWatched = squadSharedData.isAutoCluster
let { addPopup, removePopup } = require("%enlSqGlob/ui/popup/popupsState.nut")
let { Bordered } = require("%ui/components/txtButton.nut")
let modalPopupWnd = require("%ui/components/modalPopupWnd.nut")
let mkCheckbox = require("%ui/components/mkCheckbox.nut")
let { hasAutoCluster } = require("%enlist/featureFlags.nut")


const CLUSTER_PANEL_UID = "clustersSelector"
const SELECTION_ERROR_UID = "groupSizePopup"
const NO_SERVER_ERROR = "noServerPopup"


let fillBgColor = @(sf) (sf & S_ACTIVE) || (sf & S_HOVER)
  ? hoverPanelBgColor
  : panelBgColor
let isLocalClusters = Computed(@() !isInSquad.value || isSquadLeader.value)
let squadClusters = Computed(@() squadClustersWatched.value ?? {})
let squadAutoCluster = Computed(@() squadAutoClusterWatched.value ?? false)


function toggleServerSelection(server) {
  if (server in clusters.value) {
    if (clusters.value.len() <= 1)
      addPopup({
        id = NO_SERVER_ERROR
        text = loc("quickMatch/noServer")
        styleName = "error"
      })
    else
      clusters.mutate(@(v) v.$rawdelete(server))
  }
  else
    clusters.mutate(@(v) v[server] <- true)
}


function mkServerBtn(server, txt, isAutoSelected = false) {
  let isSelected = Computed(@() server in clusters.value)
  return watchElemState(@(sf) {
    watch = isSelected
    rendObj = ROBJ_SOLID
    size = [flex(), SIZE_TO_CONTENT]
    padding = [smallPadding, midPadding]
    color = fillBgColor(sf)
    children = mkCheckbox(isSelected, txt,
      {
        isActive = !isAutoSelected
        size = [flex(), SIZE_TO_CONTENT]
        onClick = @() toggleServerSelection(server)
      })
  })
}


let optimalServerButton = watchElemState(@(sf) {
  watch = [isAutoCluster, ownCountry]
  rendObj = ROBJ_SOLID
  size = [flex(), SIZE_TO_CONTENT]
  color = fillBgColor(sf)
  padding = [smallPadding, midPadding]
  children = mkCheckbox(isAutoCluster,
    loc("quickMatch/Server/Optimal", { code = countryLoc(ownCountry.value) }),
    {
      size = [flex(), SIZE_TO_CONTENT]
      onClick = @() isAutoCluster(!isAutoCluster.value)
    })
})

let clusterSelector = @() {
  watch = [availableClusters, isAutoCluster, clusters, hasAutoCluster]
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  gap = hdpx(2)
  children = [
    hasAutoCluster.value ? optimalServerButton : null
  ].extend(availableClusters.value.map(@(val)
    mkServerBtn(val, clusterLoc(val), isAutoCluster.value)))
}

let showCantChangeInQueue = @() addPopup({
  id = SELECTION_ERROR_UID
  text = loc("quickMatch/paramsInQue")
  styleName = "error"
})

function showCantChangeMessage() {
  if (isInQueue.value) {
    showCantChangeInQueue()
    return
  }
  addPopup({
    id = SELECTION_ERROR_UID
    text = loc("quickMatch/squadLeaderParams")
    styleName = "error"
  })
}

function openClustersMenu(event) {
  if (isInQueue.value) {
    showCantChangeInQueue()
    return
  }
  removePopup(SELECTION_ERROR_UID)
  modalPopupWnd.add(event.targetRect, {
    rendObj = ROBJ_SOLID
    color = darkPanelBgColor
    uid = CLUSTER_PANEL_UID
    size = [fsh(27.5), SIZE_TO_CONTENT]
    popupOffset = 0
    padding = 0
    margin = [0, 0, midPadding, 0]
    popupHalign = ALIGN_CENTER
    popupBg = { rendObj = null }
    children = clusterSelector
  })
}

isInQueue.subscribe(@(_) modalPopupWnd.remove(CLUSTER_PANEL_UID))

let mkServersRow = @(locFn = @(v) v) Computed(function(){
  if (isLocalClusters.value)
    return isAutoCluster.value
      ? loc("quickMatch/Server/Optimal", { code = countryLoc(ownCountry.value) })
      : availableClusters.value.len() == clusters.value.len() ? loc("quickMatch/Server/Any")
      : ", ".join(clusters.value.keys().map(locFn))
  return squadAutoCluster.value
    ? loc("quickMatch/Server/OptimalSquad")
    : ", ".join(squadClusters.value.keys().map(locFn))
})

let mkServerClusterBtn = @(serversRow, params = {}) function() {
  let text = loc("quickMatch/curServers", { server = serversRow.value })
  let btn = Bordered(text, isLocalClusters.value ? openClustersMenu : showCantChangeMessage,
    {
      size = [SIZE_TO_CONTENT, commonBtnHeight]
      sEnables = canChangeQueueParams.value
      hotkeys = [["^J:X", { description = loc("server/change") }]]
    }.__update(params))
  return {
    size = [flex(), commonBtnHeight]
    halign = ALIGN_CENTER
    watch = [isLocalClusters, canChangeQueueParams, serversRow]
    children = btn
  }
}


let txtColor = @(sf) sf & S_ACTIVE
  ? titleTxtColor
  : sf & S_HOVER ? darkTxtColor : defTxtColor

function serversToShow(group = null, onClick = null) {
  let serversRow = mkServersRow()
  return watchElemState(function(sf) {
    return {
      watch = [serversRow]
      size = [flex(), SIZE_TO_CONTENT]
      rendObj = ROBJ_TEXT
      behavior = Behaviors.Marquee
      skipDirPadNav = true
      group
      onClick
      margin = [0, hdpx(15), 0, hdpx(15)]
      scrollOnHover = true
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      text = loc("quickMatch/curServers", { server = serversRow.value })
      color = txtColor(sf)
    }.__update(fontSub)
  })
}



return {
  serverClusterBtnAbbrev = mkServerClusterBtn(mkServersRow(), {size = flex()})
  serverClusterBtn = mkServerClusterBtn(mkServersRow(clusterLoc))
  serversToShow
}
