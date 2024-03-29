from "%enlSqGlob/ui/ui_library.nut" import *

let { loadJson, saveJson, json_to_string } = require("%sqstd/json.nut")
let debriefingState = require("debriefingStateInMenu.nut") //can be overrided by game
let { dbgShow, dbgData } = require("debriefingDbgState.nut")

local cfg = {
  state = debriefingState
  savePath = "debriefing.json"
  samplePath = ["debriefing_sample.json"]
  loadPostProcess = function(_debriefingData) {} //for difference in json saving format, as integer keys in table
}

let saveDebriefing = @(path = null)
  saveJson(path ?? cfg.savePath, cfg.state.data.value, {logger = log_for_user})

function loadDebriefing(path = null) {
  path = path ?? cfg.savePath
  let data = loadJson(path, { logger = log_for_user })
  if (data == null)
    return false

  cfg.loadPostProcess(data)
  data.isDebug <- true
  dbgData(data)
  dbgShow(true)
  return true
}

function mkSessionPath(sessionId, path = null) {
  path = path ?? cfg.savePath
  let parts = path.split("/")
  local filename = parts.pop()
  let idx = filename.indexof(".")
  if (idx == null)
    return $"{path}_{sessionId}"
  path = "/".join(parts)
  filename = "{0}_{1}{2}".subst(filename.slice(0, idx), sessionId, filename.slice(idx))
  return path == "" ? filename : $"{path}/{filename}"
}
let saveDebriefingBySession = @()
  saveDebriefing(mkSessionPath(cfg.state.data.value?.sessionId ?? "0"))

let loadSample = @(idx) loadDebriefing(cfg.samplePath[idx])

console_register_command(@() saveDebriefing(), "ui.debriefing_save")
console_register_command(@() loadDebriefing(), "ui.debriefing_load")
console_register_command(@() saveDebriefingBySession(), "ui.debriefing_save_by_session")
console_register_command(@(sessionId) loadDebriefing(mkSessionPath(sessionId)), "ui.debriefing_load_by_session")
console_register_command(@() dbgData(clone dbgData.value), "ui.debriefing_dbg_trigger")

function saveToLog(dData) {
  if (dData?.isDebug)
    return
  let { sessionId = "0" } = dData
  let jsonstr = json_to_string(dData, true)
  log($"Debriefing for session {sessionId } json:\n======\n{jsonstr}======")
}

function saveToFile(dData, path) {
  if (dData?.isDebug)
    return
  let { sessionId = "0" } = dData
  let sessionPath = mkSessionPath(sessionId, path)
  saveDebriefing(sessionPath)
  log($"Debriefing for session {sessionId } saved as {sessionPath}")
}

return {
  init = function(params) {
    cfg = cfg.__merge(params.filter(@(_value, key) key in cfg))
    for(local i = 0; i < cfg.samplePath.len(); i++) {
      let idx = i // to capture i value
      let cmd = i > 0 ? $"{i + 1}" : ""
      console_register_command(@() loadSample(idx), $"ui.debriefing_sample{cmd}")
    }
  }
  saveDebriefingToFile = saveToFile
  saveDebriefingToLog = saveToLog
}
