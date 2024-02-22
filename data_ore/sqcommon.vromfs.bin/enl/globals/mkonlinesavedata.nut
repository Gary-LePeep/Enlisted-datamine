let { Watched } = require("frp")
let { defer } = require("dagor.workcycle")
let { eventbus_subscribe, eventbus_send } = require("eventbus")
let { ndbWrite, ndbRead, ndbExists } = require("nestdb")

let mkSaveDataKey = @(saveId) ["onlineSaveData", saveId]

let onlineSaveDataCache = persist("onlineSaveDataCache", @() {})

function getOrMkSaveData(saveId, defValueFunc = @() null, validate=@(v) v){
  if (saveId in onlineSaveDataCache)
    return onlineSaveDataCache[saveId]
  let key = mkSaveDataKey(saveId)
  let val = validate(ndbExists(key) ? ndbRead(key) : defValueFunc())
  if (!ndbExists(key)) {
//    log("mkOnlineSaveData: no key found", key)
    ndbWrite(key, val)
  }
//  else
//    log("mkOnlineSaveData: key found", key, ndbRead(key))

  let watch = Watched(val)
  onlineSaveDataCache[saveId] <- watch
  watch.subscribe(function(v) {
//    log("mkOnlineSaveData: ndbWrite", key, v)
    ndbWrite(key, validate(v))
  })
  return watch
}

function mkOnlineSaveData(saveId, defValueFunc = @() null, validateFunc = @(v) v) {
  let watch = getOrMkSaveData(saveId, defValueFunc)
//  log("mkOnlineSaveData: init", saveId, watch.value)
  let update = function(value) {
    let v = validateFunc(value ?? defValueFunc())
//    dlog("mkOnlineSaveData: update", saveId, v)
    watch(v)
  }
  watch.whiteListMutatorClosure(update)
  eventbus_subscribe($"onlineData.changed.{saveId}", function(msg) {
//    dlog($"mkOnlineSaveData: onlineData.changed.{saveId}", msg.value)
    defer(@() update(msg.value))
  })

  return {
    watch
    setValue = function(value) {
//      log("mkOnlineSaveData: setValue", saveId, value)
      eventbus_send("onlineData.setValue", {saveId, value})
    }
  }
}

return {
  mkOnlineSaveData
  getOrMkSaveData
}