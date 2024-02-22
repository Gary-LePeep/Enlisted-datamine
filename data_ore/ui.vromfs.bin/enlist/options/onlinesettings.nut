from "%enlSqGlob/ui/ui_library.nut" import *
from "modules" import on_module_unload

let { eventbus_subscribe } = require("eventbus")
let userInfo = require("%enlSqGlob/userInfo.nut")
let { save_table_to_online_storage, get_table_from_online_storage, send_to_server, load_from_cloud } = require("onlineStorage")
let { debounce } = require("%sqstd/timers.nut")
let logOS = require("%enlSqGlob/library_logs.nut").with_prefix("[ONLINE_SETTINGS] ")
let onlineSettingUpdated = mkWatched(persist, "onlineSettingUpdated", false)
let onlineSettingsInited = mkWatched(persist, "onlineSettingsInited", false)

let cacheForModuleUnload = {value = null}
let getOnlineTbl = @() get_table_from_online_storage("GBT_GENERAL_SETTINGS") ?? cacheForModuleUnload.value ?? {}
let settings = Watched(getOnlineTbl())

const SEND_PENDING_TIMEOUT_SEC = 600 //10 minutes should be ok

function onUpdateSettings(_userId) {
  settings.update(getOnlineTbl())
  onlineSettingUpdated(true)
  onlineSettingsInited(true)
}

if (userInfo.value?.chardToken!=null && userInfo.value?.userId!=null && !onlineSettingsInited.value){ //hard reload support
  onUpdateSettings(userInfo.value?.userId)
}

local isSendToSrvTimerStarted = false

function sendToServer(forced = false) {
  if (!isSendToSrvTimerStarted && !forced)
    return //when timer not started, than settings already sent

  logOS("Send to server")
  gui_scene.clearTimer(callee())
  isSendToSrvTimerStarted = false
  send_to_server()
}

function startSendToSrvTimer() {
  if (isSendToSrvTimerStarted) {
    logOS("Timer to send is already on")
    return
  }

  isSendToSrvTimerStarted = true
  logOS("Start timer to send")
  gui_scene.resetTimeout(SEND_PENDING_TIMEOUT_SEC, sendToServer)
}

userInfo.subscribe(function (new_val) {
  if (new_val != null)
    return
  sendToServer()
  onlineSettingUpdated(false)
})

function save() {
  logOS("Save settings")
  let v = settings.value ?? cacheForModuleUnload.value
  if ( v != null)
    save_table_to_online_storage(v, "GBT_GENERAL_SETTINGS")
}

let lazySave = debounce(save, 15)

settings.subscribe(function(new_val) {
  if (new_val != null)
    cacheForModuleUnload.value = new_val

  logOS("Queue setting to save")
  lazySave()
  startSendToSrvTimer()
})

function loadFromCloud(userId, cb) {
  load_from_cloud(userId, cb)
}

local isExiting = false
eventbus_subscribe("app.shutdown", function(_) {
  isExiting = true
})

eventbus_subscribe("onlineSettings.sendToServer", @(_) sendToServer())

on_module_unload(function(...){
  if (!isExiting && cacheForModuleUnload.value != null){
    save_table_to_online_storage(cacheForModuleUnload.value, "GBT_GENERAL_SETTINGS")
    send_to_server()
  }
})

return {
  onUpdateSettings
  onlineSettingUpdated
  settings
  loadFromCloud
  startSendToSrvTimer
  sendToServer
  save
}
