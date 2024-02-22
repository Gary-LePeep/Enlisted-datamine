from "%enlSqGlob/ui/ui_library.nut" import *

let { midPadding, defItemBlur } = require("%enlSqGlob/ui/designConst.nut")
let canDisplayOffers = require("%enlist/canDisplayOffers.nut")
let { nestWatched } = require("%dngscripts/globalState.nut")
let { get_setting_by_blk_path } = require("settings")
let { getPromoUrl } = require("%ui/networkedUrls.nut")
let { openUrl, AuthenticationMode } = require("%ui/components/openUrl.nut")
let { eventbus_subscribe } = require("eventbus")
let { httpRequest, HTTP_SUCCESS } = require("dagor.http")
let { parse_json } = require("json")
let { send_counter } = require("statsd")
let { isBrowserClosed } = require("%ui/components/browserWidget.nut")
let { addModalWindow, removeModalWindow } = require("%ui/components/modalWindows.nut")
let closeBtnBase = require("%ui/components/closeBtn.nut")
let { isLoggedIn } = require("%enlSqGlob/ui/login_state.nut")

const WEB_PROMO_RECEIVED = "WEB_PROMO_RECEIVED"
const WND_UID = "WEB_PROMO_WND"

let promoUrl = getPromoUrl() ?? get_setting_by_blk_path("promoUrl")
let hasSeen = nestWatched("hasSeenWebPromo", false)
let webPromoBody = Watched(null)

let needRequestWebPromo = keepref(Computed(@() isLoggedIn.value
  && promoUrl != null
  && !hasSeen.value))

let canShowWebPromo = keepref(Computed(@() needRequestWebPromo.value
  && canDisplayOffers.value
  && webPromoBody.value != null))

function closeWnd() {
  hasSeen(true)
  removeModalWindow(WND_UID)
}

let closeButton = closeBtnBase({
  hplace = ALIGN_RIGHT
  margin = [midPadding, midPadding, 0,0]
  onClick = closeWnd
})

function requestWebPromo() {
  let request = {
    method = "GET"
    url = promoUrl
    respEventId = WEB_PROMO_RECEIVED
  }
  httpRequest(request)
}

eventbus_subscribe(WEB_PROMO_RECEIVED, tryCatch(
  function(response) {
    let { status, http_code } = response
    if (status != HTTP_SUCCESS || http_code == null
        || http_code < 200 || http_code >= 300) {
      send_counter("webpromo_request_receive_errors", 1, { http_code })
      log($"haven't received web promos. status = {status} http_code = {http_code}")
      return
    }
    let body = parse_json(response.body.as_string())
    webPromoBody(body[0])
  }, function(e) {
    log(e)
  }
))

function showWebPromo() {
  let { picUrl = null, jumpUrl = null } = webPromoBody.value
  if (picUrl == null)
    return

  addModalWindow({
    key = WND_UID
    rendObj = ROBJ_WORLD_BLUR
    color = defItemBlur
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    onClick = closeWnd
    children = {
      size = [fsh(106), fsh(65)]
      children = [
        {
          size = flex()
          rendObj = ROBJ_IMAGE
          image = Picture(picUrl)
          keepAspect = KEEP_ASPECT_FILL
          imageHalign = ALIGN_CENTER
          imageValign = ALIGN_CENTER
          behavior = Behaviors.Button
          onClick = function() {
            closeWnd()
            if (jumpUrl != null)
              openUrl(jumpUrl, AuthenticationMode.WEGAME_AUTH)
          }
        }
        closeButton
      ]
    }
  })
}

isBrowserClosed.subscribe(@(v) v ? hasSeen(true) : null)

canShowWebPromo.subscribe(function(v) {
  if (v)
    showWebPromo()
})
needRequestWebPromo.subscribe(function(v) {
  if (v)
    requestWebPromo()
})