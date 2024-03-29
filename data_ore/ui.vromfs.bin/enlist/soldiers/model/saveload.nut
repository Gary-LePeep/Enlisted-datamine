from "%enlSqGlob/ui/ui_library.nut" import *

let { loadJson, saveJson } = require("%sqstd/json.nut")
let { file_exists } = require("dagor.fs")
let { DBGLEVEL } = require("dagor.system")

let logg = DBGLEVEL !=0 ? log_for_user : log

function save(filename, data, pretty_print=true){
  saveJson(filename, data, {pretty_print = pretty_print, logger = logg})
}

function load(filename, initializer){
  assert(type(initializer)=="function")
  assert(type(filename)=="string")
  if (!file_exists(filename))
    save(filename, initializer())
  return loadJson(filename, {logger = logg})
}

return {
  load = load
  save = save
}
