from "%enlSqGlob/ui/ui_library.nut" import *

let auth_kz_token = require("%enlist/login/stages/kz_token.nut")
let auth_result = require("%enlist/login/stages/auth_result.nut")
let char_stage = require("%enlist/login/stages/char.nut")
let online_settings = require("%enlist/login/stages/online_settings.nut")
let eula = require("%enlist/login/stages/eula.nut")
let matching = require("%enlist/login/stages/matching.nut")
let { get_setting_by_blk_path } = require("settings")
let circuitConf = require("app").get_circuit_conf()
let { get_arg_value_by_name } = require("dagor.system")
let wegame  = require("wegame")


let loginStagesPass = [
  auth_result
  char_stage
  online_settings
  eula
  matching
]

let loginStagesToken = [
  auth_kz_token
  auth_result
  char_stage
  online_settings
  eula
  matching
]


return {
  isKZVersion = (get_arg_value_by_name("kongzhong")) || (((get_setting_by_blk_path("isChineseVersion") ?? false) &&
    (circuitConf?.webLoginUrl ?? "") != "") &&
    !wegame.is_running())

  KZLoginStages = get_arg_value_by_name("wf-token") ? loginStagesToken : loginStagesPass
}
