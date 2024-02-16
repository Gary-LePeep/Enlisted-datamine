from "%enlSqGlob/ui_library.nut" import *
let { scan_folder, file_exists } = require("dagor.fs")
let { flatten } = require("%sqstd/underscore.nut")
let { showReplayTabInProfile } = require("%enlist/featureFlags.nut")
let { load_replay_meta_info, replay_play } = require("app")
let { NET_PROTO_VERSION, get_replay_proto_version } = require("net")
let {get_setting_by_blk_path } = require("settings")
let msgbox = require("%enlist/components/msgbox.nut")
let { remove } = require("system")
let datacache = require("datacache")
let { requestModManifest } = require("%enlist/gameModes/sandbox/customMissionState.nut")
let { getModStartInfo } = require("%enlSqGlob/modsDownloadManager.nut")
let { MOD_BY_VERSION_URL } = require("%enlSqGlob/game_mods_constant.nut")
let { currentReplayInfo, currentReplayInfoUpdate } = require("%enlSqGlob/replay_state.nut")
let JB = require("%ui/control/gui_buttons.nut")

let allowProtoMismatch = get_setting_by_blk_path("replay/allowProtoMismatch") ?? false
let storageLimitMB = get_setting_by_blk_path("replay/storageLimitMB") ?? 300

let replayStorageInited = Watched(false)
let initReplayStorage = function() {
  if (replayStorageInited.value)
    return

  datacache.init_cache("records",
  {
    mountPath = "records"
    maxSize = storageLimitMB << 20
    manualEviction = true
    timeoutSec = -1
  })
  replayStorageInited(true)
}

let defaultRecordFolder = "replays/"
let recordsFolders = [
  defaultRecordFolder,
]

let currentRecord = Watched(null)
let records = Watched([])
let isReplayTabHidden = Computed(@() !showReplayTabInProfile.value)


let isReplayProtocolValid = @(meta) meta?.replay_version == get_replay_proto_version(NET_PROTO_VERSION)

let function getFiles() {
  initReplayStorage()
  let recordFiles = datacache.get_all_entries("records").map(function(v) {
    let fname = v.path.split("/").top()
    let recordInfo = load_replay_meta_info(v.path ?? "")
    let isValid = isReplayProtocolValid(recordInfo)
    return { title = fname, id = v.path, key = v.key, isValid, recordInfo }
  })

  recordFiles.extend(recordsFolders.map(@(root) scan_folder({
      root
      vromfs = false
      realfs = true
      recursive = true
      files_suffix = "*.erpl"
    }).map(function(v) {
      let fname = v.split("/").top()
      let recordInfo = load_replay_meta_info(v ?? "")
      let isValid = isReplayProtocolValid(recordInfo)
      return { title = fname, id = v, isValid, recordInfo }
    })
  ))

  return flatten(recordFiles)
}


let updateReplays = @() records(getFiles())

let function deleteReplay(replayPath){
  initReplayStorage()
  let record = records.value.findvalue(@(v) v.id == replayPath)
  if (record == null)
    return
  if (record?.key != null)
    datacache.del_entry("records", record.key)
  else if (file_exists(replayPath))
    remove(replayPath)
  currentRecord(null)
  updateReplays()
}

let function replayPlayWithMod(meta, path, start_time) {
  let modId = meta?.modId
  if (modId == null) {
    currentReplayInfoUpdate({
      path
      mod_info = null
    })
    replay_play(path, start_time, null)
    return
  }
  requestModManifest(MOD_BY_VERSION_URL.subst(modId, meta?.modVersion ?? 1), function(manifest, contents) {
    currentReplayInfoUpdate({
      path
      mod_info = { modId }.__merge(getModStartInfo(manifest, contents))
    })
    replay_play(path, start_time, currentReplayInfo.value["mod_info"])
  })
}

let function replayPlay(path) {
  let buttons = [{
    text = loc("Ok")
    isCancel = true
    customStyle = { hotkeys = [[$"^{JB.B} | Esc"]] }
  }]
  let replayInfo = load_replay_meta_info(path)
  if (!replayInfo) {
    msgbox.show({
      text = loc("replay/InvalidMeta"),
      buttons
    })
    return
  }

  if (isReplayProtocolValid(replayInfo)) {
    replayPlayWithMod(replayInfo, path, 0)
    return
  }

  if (allowProtoMismatch)
    buttons.append({
      text = loc("replay/playAnyway")
      action = @() replayPlayWithMod(replayInfo, path, replayInfo?.first_human_spawn_time ?? 0)
      isCurrent = true
    })

  msgbox.show({
    text = loc("replay/protocolMisMatchDoYouWantStart"),
    buttons
  })
}

return {
  currentRecord
  defaultRecordFolder
  isReplayTabHidden
  replayPlay
  deleteReplay
  records
  updateReplays
  isReplayProtocolValid
  initReplayStorage
}