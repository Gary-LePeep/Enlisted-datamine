from "%sqstd/functools.nut" import *
//from "%sqstd/frp.nut" import Watched
let Log = require("%sqstd/log.nut")
//local json = require("json")
//local http = require("dagor.http")
let {downloadStatus, getDownloadedFile, requestCachedFiles, HTTP_READY, HTTP_FAILED, HTTP_ABORTED} = require("download_manager.nut")
local log = Log()
//local dlog = log.dlog
log = log.with_prefix("[GAME LOAD] ")

let {startswith} = require("string")

//local statusText = {
//  [HTTP_SUCCESS] = "SUCCESS",
//  [HTTP_FAILED] = "FAILED",
//  [HTTP_ABORTED] = "ABORTED",
//}

//function httpGet(url, callback){
//  httpRequest({ url, method = "GET", callback})
//}


function getBaseFromManifestUrl(url){
  const https = "https://"
  if (!startswith(url,https))
    return null
  url = url.replace(https, "").split("/")[0]
  return $"{https}{url}"
}

function getHashesFromManifest(manifest){
  return manifest.content.map(@(v) v.hash).slice(0,1) //currently we support only one file in mod
}

function getNotReadyHashes(hashes){
  let notReady = []
  let failed = []
  let curStatus = downloadStatus.value
  foreach ( hash in hashes){
    if (curStatus?[hash] != HTTP_READY)
      notReady.append(hash)
    if (curStatus?[hash] == HTTP_FAILED || curStatus?[hash] == HTTP_ABORTED)
      failed.append(hash)
  }
  return {notReady, failed}
}

let getAllFiles = @(hashes) hashes.map(@(v) getDownloadedFile(v))

function requestModFiles(hashes, baseUrl, callbackOnSuccess, callbackOnFailure=null){
  log($"request for modfiles for {hashes}, {baseUrl}")
  if (typeof hashes == "string")
    hashes = hashes.split(";")
  let cb = function(...){
    log("downloadStatus", downloadStatus.value.map(@(v) v==HTTP_READY ? "ready" :"not ready"))
    let {notReady, failed} = getNotReadyHashes(hashes)
    log("notReady files:", notReady, ", failed files:", failed)
    if (failed.len()>0){
      if (callbackOnFailure!=null)
        callbackOnFailure(failed)
      else
        throw($"error downloading files, {";".join(failed)}")
    }
    if (notReady.len()==0){
      callbackOnSuccess(getAllFiles(hashes))
    }
    return notReady
  }
  let notReady = cb()
  if (notReady.len()>0) {
    let filesToDownload = notReady.map(@(v) {cache_key = v, url = $"{baseUrl}/file/{v}"})
    requestCachedFiles(filesToDownload)
    log("prepare to download files for", filesToDownload)
  }
  downloadStatus.subscribe(cb)
}

return {
  //requestModByManifestUrl
  requestModFiles
  getBaseFromManifestUrl
  getHashesFromManifest
  getModFileByHash = getDownloadedFile
}