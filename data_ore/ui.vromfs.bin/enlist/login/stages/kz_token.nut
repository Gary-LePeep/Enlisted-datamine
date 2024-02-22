from "%enlSqGlob/ui/ui_library.nut" import *

let auth  = require("auth")
let ah = require("auth_helpers.nut")
let { eventbus_subscribe } = require("eventbus")
let { get_circuit } = require("app")
let { get_arg_value_by_name } = require("dagor.system")

const id = "auth_kz_token"

return {
  id

  function action(_state, cb) {
    eventbus_subscribe(id, ah.status_cb(cb))
    auth.login_kongzhong({
      kz_token = get_arg_value_by_name("wf-token"),
      circuit = get_circuit()
    }, id)
  }
}
