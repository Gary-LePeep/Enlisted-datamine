from "%enlSqGlob/ui/ui_library.nut" import *

let {nestWatched} = require("%dngscripts/globalState.nut")
let { send_error_log } = require("clientlog")
let { send_counter } = require("statsd")
let { mkVersionFromString, versionToInt } = require("%sqstd/version.nut")
let { gameLanguage } = require("%enlSqGlob/clientState.nut")
let { eventbus_subscribe } = require("eventbus")
let { httpRequest, HTTP_SUCCESS } = require("dagor.http")
let { parse_json } = require("json")
let { exe_version } = require("%dngscripts/appInfo.nut")
let { onlineSettingUpdated, settings } = require("%enlist/options/onlineSettings.nut")
let { getPlatformId, getLanguageId } = require("%enlSqGlob/httpPkg.nut")
let { get_setting_by_blk_path } = require("settings")
let { maxVersionInt } = require("%enlSqGlob/client_version.nut")
let { isStringInteger } = require("%sqstd/string.nut")
let isNewbie = require("%enlist/unlocks/isNewbie.nut")

let changelogDisabled = get_setting_by_blk_path("disableChangelog") ?? false

local extNewsUrl = get_setting_by_blk_path("newsUrl") ?? ""
if (extNewsUrl == "")
  extNewsUrl = "https://enlisted.net/news/#!/"

local URL_VERSIONS = get_setting_by_blk_path("versionUrl") ?? ""
if (URL_VERSIONS == "")
  URL_VERSIONS = "https://newsfeed.gap.gaijin.net/api/patchnotes/enlisted/{0}/?platform={1}"

local URL_PATCHNOTE = get_setting_by_blk_path("patchnoteUrl") ?? ""
if (URL_PATCHNOTE == "")
  URL_PATCHNOTE = "https://newsfeed.gap.gaijin.net/api/patchnotes/enlisted/{0}/{2}?platform={1}"

function logError(event, params = {}) {
  log(event, params)
  send_error_log(event, {
    attach_game_log = true
    collection = "events"
    meta = {
      hint = "error"
      exe_version = exe_version.value
      language = gameLanguage
    }.__update(params)
  })
}

const UseEventBus = true

const SAVE_ID = "ui/lastSeenVersionId"
const PatchnoteIds = "PatchnoteIds"

let lastSeenVersionIdState = Computed(function() {
  if (!onlineSettingUpdated.value)
    return -1
  let val = settings.value?[SAVE_ID]
  return isStringInteger(val) ? val.tointeger() : 0
})

let chosenPatchnote = Watched(null)
let chosenPatchnoteLoaded = nestWatched("chosenPatchnoteLoaded", false)
let chosenPatchnoteContent = nestWatched("chosenPatchnoteContent", "")
let chosenPatchnoteTitle = nestWatched("chosenPatchnoteTitle", "")
let patchnotesReceived = nestWatched("patchnotesReceived", false)
let versions = nestWatched("versions", [])

const MAX_TAB_INDEX = 7

// FIXME legacy block should be removed after next major update
// >>> LEGACY

const LEGACY_ID = "ui/lastSeenVersionInfoNum"

let shouldUpdateLegacyData = keepref(Computed(@() onlineSettingUpdated.value
  && LEGACY_ID in settings.value
  && versions.value.len() > 0))

shouldUpdateLegacyData.subscribe(function(v) {
  if (!v)
    return
  let iVersion = settings.value[LEGACY_ID]
  let id = versions.value.findvalue(@(ver) versionToInt(ver.version) == iVersion)?.id ?? 0
  defer(@() settings.mutate(function(value) {
    value[SAVE_ID] <- id
    value.$rawdelete(LEGACY_ID)
  }))
})

// <<< LEGACY

function mkVersion(v){
  local tVersion = v?.version ?? ""
  let versionl = tVersion.split(".").len()
  local versionType = v?.type
  if (versionl!=4) {
    log($"incorrect patchnote version {tVersion}")
    if (versionl==3) {
      tVersion = $"{tVersion}.0"
      if (versionType==null)
        versionType = "major"
    }
    else
      throw null
  }
  let version = mkVersionFromString(tVersion)
  local titleshort = v?.titleshort ?? "undefined"
  if (titleshort == "undefined" || titleshort.len() > 50 )
    titleshort = null
  return {
    version
    title = v?.title ?? tVersion
    tVersion
    versionType
    titleshort
    iVersion = versionToInt(version)
    id = v.id
    date = v?.date ?? ""
    alwaysShowPopup = v?.alwaysShowPopup ?? false
  }
}

function filterVersions(vers) {
  let res = []
  local foundMajor = false
  foreach (idx, version in vers) {
    if (idx >= MAX_TAB_INDEX && foundMajor)
      break
    else if (maxVersionInt.value > 0 && maxVersionInt.value < version.iVersion) {
      continue
    }
    else if (version.versionType=="major"){
      res.append(version)
      foundMajor = true
    }
    else if (idx < MAX_TAB_INDEX && !foundMajor){
      res.append(version)
    }
  }
  return res
}

function processPatchnotesList(response) {
  let { status = -1, http_code = 0, body = null } = response
  if (status != HTTP_SUCCESS || http_code < 200 || 300 <= http_code) {
    send_counter("changelog_receive_errors", 1, { http_code, stage = "get_versions" })
    return
  }

  local result
  try {
    result = parse_json(body?.as_string())?.result
  } catch(e) {
  }

  if (result == null) {
    logError("changelog_parse_errors", { stage = "get_versions" })
    send_counter("changelog_parse_errors", 1, { stage = "get_versions" })
    versions([])
    patchnotesReceived(false)
    return
  }

  log("changelog_success_versions", result)
  versions(filterVersions(result.map(mkVersion)))
  patchnotesReceived(true)
}

function requestPatchnotes(){
  let request = {
    method = "GET"
    url = URL_VERSIONS.subst(getLanguageId(), getPlatformId())
  }
  if (UseEventBus)
    request.respEventId <- PatchnoteIds
  else
    request.callback <- processPatchnotesList
  patchnotesReceived(false)
  httpRequest(request)
}

let isVersion = @(version) type(version?.version) == "array"
  && type(version?.iVersion) == "integer"
  && type(version?.tVersion) == "string"

function findBestVersionToshow(versionsList = versions, lastSeenVersionNum = 0) {
  //here we want to find first unseen Major version or last unseed hotfix version.
  lastSeenVersionNum = lastSeenVersionNum ?? 0
  versionsList = versionsList ?? []
  local res = null
  foreach (version in versionsList) {
    if (version.alwaysShowPopup && res == null)
      return version
    if (lastSeenVersionNum < version.id) {
      if (version.versionType == "major")
        return version
      res = version
    }
    else
      break
  }
  return res
}

let unseenPatchnote = Computed(@() !onlineSettingUpdated.value ? null
  : findBestVersionToshow(versions.value, lastSeenVersionIdState.value))

let curPatchnote = Computed(@()
  chosenPatchnote.value ?? unseenPatchnote.value ?? versions.value?[0])

function markSeenVersion(v) {
  if (v == null)
    return
  if (v.id > lastSeenVersionIdState.value)
    settings.mutate(@(value) value[SAVE_ID] <- v.id)
}

function markLastSeen() {
  let v = versions.value?[0]
  markSeenVersion(v)
}

let updateVersion = @() markSeenVersion(curPatchnote.value)

const PatchnoteReceived = "PatchnoteReceived"

let patchnotesCache = persist("patchnotesCache", @() {})

function setPatchnoteResult(result){
  chosenPatchnoteContent(result?.content ?? [])
  chosenPatchnoteTitle(result?.title ?? "")
  log("show patchnote:",result?.content)
  chosenPatchnoteLoaded(true)
  updateVersion()
}

function cachePatchnote(response) {
  let { status = -1, http_code = 0, body = null } = response
  if (status != HTTP_SUCCESS || http_code < 200 || 300 <= http_code) {
    send_counter("changelog_receive_errors", 1, { http_code, stage = "get_patchnote" })
  }

  local result
  try {
    result = parse_json(body?.as_string())?.result
  } catch(e) {
  }

  if (result == null) {
    logError("changelog_parse_errors", { stage = "get_patchnote" })
    send_counter("changelog_parse_errors", 1, { stage = "get_patchnote" })
    return
  }

  log("changelog_success_patchnote")
  setPatchnoteResult(result)
  if (result?.id)
    patchnotesCache[result.id] <- result
}

function requestPatchnote(v){
  if (v.id in patchnotesCache) {
    return setPatchnoteResult(patchnotesCache[v.id])
  }
  let request = {
    method = "GET"
    url = URL_PATCHNOTE.subst(getLanguageId(), getPlatformId(), v.id)
  }
  if (UseEventBus)
    request.respEventId <- PatchnoteReceived
  else
    request.callback <- cachePatchnote
  chosenPatchnoteLoaded(false)
  httpRequest(request)
}

if (UseEventBus) {
  eventbus_subscribe(PatchnoteIds, processPatchnotesList)
  eventbus_subscribe(PatchnoteReceived, cachePatchnote)
}

let curPatchnoteIdx = Computed( @() versions.value.indexof(curPatchnote.value) ?? 0)

function haveUnseenMajorVersions(){
  let bestUnseenVersion = findBestVersionToshow(versions.value, lastSeenVersionIdState.value)
  return (bestUnseenVersion != null && bestUnseenVersion.versionType == "major")
}

function haveUnseenHotfixVersions(){
  let bestUnseenVersion = findBestVersionToshow(versions.value, lastSeenVersionIdState.value)
  return (bestUnseenVersion != null && bestUnseenVersion.versionType != "major")
}

let haveUnseenVersions = Computed(@() unseenPatchnote.value != null)

function selectPatchnote(v) {
  chosenPatchnote(v)
  requestPatchnote(v)
}

let mkChangePatchNote = @(delta=1) function() {
  if (versions.value.len() == 0)
    return
  let nextIdx = clamp(curPatchnoteIdx.value-delta, 0, versions.value.len()-1)
  let patchnote = versions.value[nextIdx]
  selectPatchnote(patchnote)
}

let nextPatchNote = mkChangePatchNote()
let prevPatchNote = mkChangePatchNote(-1)

patchnotesReceived.subscribe(function(v){
  if (isNewbie.value) {
    markLastSeen()
    return
  }
  if (!v || !haveUnseenVersions.value || curPatchnote.value == null)
    return

  selectPatchnote(curPatchnote.value)
})

console_register_command(function() {
  if (SAVE_ID in settings.value)
    settings.mutate(@(v) v.$rawdelete(SAVE_ID))
}, "changelog.reset")

console_register_command(requestPatchnotes, "changelog.requestVersions")

return {
  extNewsUrl
  changelogDisabled
  curPatchnote
  versions
  patchnotesReceived
  isVersion
  findBestVersionToshow
  haveUnseenHotfixVersions
  haveUnseenVersions
  haveUnseenMajorVersions
  curPatchnoteIdx
  nextPatchNote
  prevPatchNote
  updateVersion
  requestPatchnote
  chosenPatchnote
  chosenPatchnoteContent
  chosenPatchnoteTitle
  chosenPatchnoteLoaded
  requestPatchnotes
  maxVersionInt
  markLastSeen
  selectPatchnote
}