from "%enlSqGlob/ui/ui_library.nut" import *

let {startLogin} = require("%enlist/login/login_chain.nut")

function loginRoot() {
  startLogin({})
  return {}
}

return {
  size = flex()
  children = loginRoot
}
