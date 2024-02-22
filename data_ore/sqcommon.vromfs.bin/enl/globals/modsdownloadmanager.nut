from "frp" import *

let { httpRequest, HTTP_SUCCESS, HTTP_FAILED, HTTP_ABORTED } = require("dagor.http")
let datacache = require("datacache")
let { eventbus_subscribe_onehit } = require("eventbus")
let { file } = require("io")
let { logerr } = require("dagor.debug")
let { mkdir, file_exists, scan_folder } = require("dagor.fs")
let { parse_json } = require("json")
let { loadJson, saveJson } = require("%sqstd/json.nut")
let { remove = null } = require_optional("system")
let { get_setting_by_blk_path } = require("settings")
let { MOD_FILE_URL, USER_MODS_FOLDER, USER_MOD_MANIFEST_EXT } = require("%enlSqGlob/game_mods_constant.nut")
let logGM = require("%enlSqGlob/library_logs.nut").with_prefix("[ModsDownloadManager] ")
let { is_pc } = require("%dngscripts/platform.nut")
let USER_MOD_MANIFEST = "".concat(USER_MODS_FOLDER, "/{0}", USER_MOD_MANIFEST_EXT)

let statusText = {
  [HTTP_SUCCESS] = "SUCCESS",
  [HTTP_FAILED] = "FAILED",
  [HTTP_ABORTED] = "ABORTED",
}

let DATACACHE_ERROR_TO_TEXT = {
  [datacache.ERR_MEMORY_LIMIT] = "mods/memoryLimit",
  [datacache.ERR_ABORTED] = "mods/userAborted",
}

let storageLimitMB = get_setting_by_blk_path("mods/storageLimitMB") ?? 300

let isModsDatacacheInited = Watched(false)
let initModsDatacache = function() {
  if (isModsDatacacheInited.value)
    return
  datacache.init_cache("mods",
  {
    mountPath = "mods"
    maxSize = storageLimitMB << 20
    manualEviction = true
    timeoutSec = -1
  })
  isModsDatacacheInited(true)
}


local pendingFilesCount = 0
let modsCache = Watched({})
let modsContents = Watched({})


function jsonSafeParse(v) {
  try
    return parse_json(v ?? "")
  catch(e)
    return null
}


function readFile(filename) {
  let input = file(filename, "rt")
  let text = input.readblob(input.len()).as_string()
  input.close()
  return text
}


function loadManifest(filename) {
  if (filename in modsCache.value)
    return modsCache.value[filename]

  let manifest = loadJson(filename, {load_text_file=readFile})
  if (typeof manifest.title != "string")
    manifest.title = $"{manifest?.title}" // due web set title as digits sometimes we have problem with compare int and string
  modsCache.mutate(@(v) v[filename] <- manifest)
  return manifest
}


function onReceiveFile(response) {
  logGM("onReceiveFile headers:", response?.headers)
  let { status, http_code, context = {} } = response
  let { cbOnSuccess, cbOnFailed } = context

  pendingFilesCount -= 1
  if (status != HTTP_SUCCESS || http_code == null || http_code >= 300 || http_code < 200) {
    logGM("onReceiveFile status =", status, statusText?[status], http_code)
    cbOnFailed(response)
    return
  }
  cbOnSuccess(response)
}


function downloadFile(url, cbOnSuccess, cbOnFailed, context = {}) {
  httpRequest({
    method = "GET"
    callback = onReceiveFile
    url
    context = context.__merge({
      url
      cbOnSuccess
      cbOnFailed
    })
  })
  pendingFilesCount += 1
}


function abortDownload() {
  initModsDatacache()
  datacache.abort_requests("mods")
  pendingFilesCount = 0
}


function removeMod(mode_id) {
  initModsDatacache()
  if (remove == null) {
    logerr("Can't remove mod function remove doesn't exist for this VM!")
    return
  }

  let manifest_file_path = USER_MOD_MANIFEST.subst(mode_id)
  let manifest = loadManifest(manifest_file_path)
  if (file_exists(manifest_file_path))
    remove(manifest_file_path)
  if (manifest_file_path in modsCache)
    modsCache.mutate(@(v) v.$rawdelete(manifest_file_path))
  if (manifest == null)
    return
  foreach(content in manifest?.content ?? {}) {
    let url = MOD_FILE_URL.subst(content.hash)
    datacache.del_entry("mods", url)
  }
}

function parseVromName(filename) {
  //name format: main/grp/dxp/...[-client/shared/server[-pack/addon]].vromfs.bin
  let filenameSplited = filename.replace(".vromfs.bin", "").split("-")
  return {
    name = filenameSplited?[0]
    tag = filenameSplited?[1] ?? "shared"
    mount_type = filenameSplited?[2] ?? "vrom"
  }
}

function downloadMod(url, cbOnSuccess=null, cbOnFailed=null, tags = ["shared", "client", "server"]) {
  logGM($"Request download mod '{url}'")
  mkdir(USER_MODS_FOLDER)
  initModsDatacache()
  let onManifestSuccessDownload = function(response) {
    local manifest = jsonSafeParse(response?.body?.as_string())
    if (manifest == null) {
      cbOnFailed?("mods/InvalidManifest", 200)
      return
    }
    let manifest_file_path = USER_MOD_MANIFEST.subst(manifest.id)
    if (is_pc)
      if (!saveJson(manifest_file_path, manifest)) {
        cbOnFailed?("mods/FailedSaveManifest", 200)
        return
      }
    else
      logGM("Skip save manifest for not PC platform")
    modsContents.mutate(@(v) v[manifest_file_path] <- {})
    let contentToDownload = {}
    foreach(content in manifest?.content ?? {}) {
      let parsedVromName = parseVromName(content.file)
      if (tags.findindex(@(v) v == parsedVromName.tag) == null) {
        logGM($"Skip download '{content.file}' due tag is '{parsedVromName.tag}' when required", tags)
        continue;
      }
      logGM($"Add '{content.file}' to download queue with hash {content.hash}")
      contentToDownload[content.hash] <- MOD_FILE_URL.subst(content.hash)
      pendingFilesCount += 1
    }

    if (pendingFilesCount == 0) {
      logGM($"Nothing to download, all files skiped")
      cbOnSuccess?(manifest, modsContents.value[manifest_file_path])
      modsCache.mutate(@(v) v[manifest_file_path] <- manifest)
      return
    }

    foreach(hash in contentToDownload.keys()) {
      let contentHash = hash
      let contentUrl = contentToDownload[contentHash]
      eventbus_subscribe_onehit($"datacache.{contentUrl}", function(result) {
        logGM("Finish download mod file: ", result, contentHash)
        if (result?.error) {
          if (pendingFilesCount > 0) {
            abortDownload()
            removeMod(manifest.id)
            modsContents.mutate(@(v) v.$rawdelete(manifest_file_path))
            cbOnFailed?(DATACACHE_ERROR_TO_TEXT?[result?.error_code] ?? "mods/HttpError", 0)
          }
          return
        }
        pendingFilesCount -= 1
        modsContents.mutate(@(v) v[manifest_file_path][contentHash] <- result.path)
        if (pendingFilesCount == 0) {
          cbOnSuccess?(manifest, modsContents.value[manifest_file_path])
          modsCache.mutate(@(v) v[manifest_file_path] <- manifest)
        }
      })
      datacache.request_entry("mods", contentUrl)
    }
  }

  let onManifsetFailedDownload = function(response) {
    cbOnFailed?("mods/failedDownload", response.http_code)
  }

  downloadFile(url, onManifestSuccessDownload, onManifsetFailedDownload)
}


function loadModList() {
  let mod_files = scan_folder({root = USER_MODS_FOLDER,
                               vromfs = false,
                               realfs = true,
                               recursive = false
                               files_suffix = USER_MOD_MANIFEST_EXT})
  let mods = {}
  foreach(mod_file in mod_files) {
    let manifest = loadManifest(mod_file)
    if (manifest && manifest?.id != null)
      mods[manifest.id] <- manifest.__merge({
        filename = mod_file
      })
  }
  return mods
}

function getModManifest(mod_id) {
  let manifest_file_path = USER_MOD_MANIFEST.subst(mod_id)
  return loadManifest(manifest_file_path)
}

function getModStartInfo(manifest, contents) {
  let mainVrom = manifest?.mainVrom ?? "";
  let modsVroms = []
  let modsPackVroms = []
  let modsAddons = []
  local scene = ""
  logGM("contents = ", contents)
  foreach (content in manifest.content) {
    let filename = content?.file ?? ""
    let path = contents?[content?.hash]
    if (path == null) {
      logGM($"Can't find mod content '{content?.hash}' in contents, skip mount")
      continue
    }
    let isVrom = filename.endswith(".vromfs.bin")
    if (isVrom) {
      let parsedVromName = parseVromName(filename)
      if (parsedVromName.mount_type == "vrom") {
        modsVroms.append(path)
      } else if (parsedVromName.mount_type == "pack") {
        modsPackVroms.append(path)
      } else if (parsedVromName.mount_type == "addon") {
        modsAddons.append(path)
      } else {
        logerr($"Undefined mount type {parsedVromName.mount_type} for file {filename}")
        continue;
      }
    }
    if (filename == mainVrom) {
      scene = isVrom ? "%ugm/scene.blk" : path
    }
  }

  return {
    scene
    modsVroms
    modsPackVroms
    modsAddons
  }
}


return {
  downloadMod
  removeMod
  loadModList
  getModManifest
  getModStartInfo
}
