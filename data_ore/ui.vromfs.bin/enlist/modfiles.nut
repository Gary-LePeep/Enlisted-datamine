from "%enlSqGlob/ui/ui_library.nut" import *
let { HTTP_SUCCESS, HTTP_ABORTED, HTTP_FAILED, httpRequest } = require("dagor.http")
let { eventbus_subscribe } = require("eventbus")
let {scan_folder, file_exists} = require("dagor.fs")
let {file} = require("io")
let { send_counter } = require("statsd")
let { MOD_FILE_URL } = require("%enlSqGlob/game_mods_constant.nut")

const USER_MODS_FOLDER = "userGameMods"
const MODS_EXT =".vromfs.bin"
const RECEIVE_FILE_MOD = "RECEIVE_FILE_MOD"

const FILE_REQUESTED = 0
const FILE_ERROR = 1
let statusText = {
  [HTTP_SUCCESS] = "SUCCESS",
  [HTTP_FAILED] = "FAILED",
  [HTTP_ABORTED] = "ABORTED",
}

function checkModFileByHash(hash){
  if (!file_exists($"{USER_MODS_FOLDER}/{hash}{MODS_EXT}"))
    return false
  return true
}

let isStrHash = @(hash) hash.len()==64

function getFiles(){
  let res = {}
  let files = scan_folder({root=USER_MODS_FOLDER, vromfs = false, realfs = true, recursive = false, files_suffix=MODS_EXT})
  foreach (f in files){
    let hash = f.slice(USER_MODS_FOLDER.len()+1, -MODS_EXT.len())
    if (!isStrHash(hash))//sha3_256 len
      continue
    res[hash] <- true
  }
  return res
}
let receivedFiles = Watched(getFiles())

let requestedFiles = Watched({})
function setHashError(hash){
  requestedFiles.mutate(function(v) {
      v[hash] <- FILE_ERROR //exponential feedback for timeout
   })
}
eventbus_subscribe(RECEIVE_FILE_MOD, function(response){
  const ERROR_MSG  = "ERROR in file request"
  log("received headers:", response?.headers)
  let hash = response?.context
  if (hash == null) {
    log(ERROR_MSG, "unknown hash")
    return
  }

  let { status, http_code } = response
  if (status != HTTP_SUCCESS) {
    log(ERROR_MSG, "request status =", status, statusText?[status])
    setHashError(hash)
    return
  }

  if (http_code == null || http_code < 200 || 300 >= http_code) {
    send_counter("file_mod_receive_errors", 1, { http_code })
    log(ERROR_MSG, "http_code =", http_code)
    setHashError(hash)
    return
  }
  try {
    //save to disk
    let body = response?.body
    let resultFile = file($"{USER_MODS_FOLDER}/{hash}.vromfs.bin", "wb+")
    resultFile.writeblob(body)
    resultFile.close()
    receivedFiles(receivedFiles.value.__merge({ [hash] = true }))
    requestedFiles.mutate(function(v) {
      if (hash in v)
        v.$rawdelete(hash)
     })
  }
  catch(e){
    log(ERROR_MSG, e)
    setHashError(hash)
  }
})

function requestFilesByHashes(hashes){
  foreach (hash_ in hashes){
    let hash = hash_
    if (hash in receivedFiles.value)
      continue
    else {
      let v = clone receivedFiles.value
      if (hash in v)
        v.$rawdelete(hash)
      receivedFiles(v)
    }
    if (checkModFileByHash(hash))
      receivedFiles(receivedFiles.value.__merge({ [hash] = true }))
    let url = MOD_FILE_URL.subst(hash)
    if (requestedFiles.value ?[hash] == FILE_REQUESTED)
      continue
    requestedFiles.mutate(@(v) v[hash]<-FILE_REQUESTED)
    httpRequest({
      method = "GET"
      url
      respEventId = RECEIVE_FILE_MOD
      context = hash
    })
  }
}


return {
  USER_MODS_FOLDER
  MODS_EXT
  checkModFileByHash
  receivedFiles
  requestedFiles
  requestFilesByHashes
  statusText
  isStrHash
}