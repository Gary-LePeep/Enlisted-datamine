let { get_app_id } = require("app")
let { getCurrentLanguage } = require("dagor.localize")

let appId = get_app_id()
let gameLanguage = getCurrentLanguage()

return {
  appId
  gameLanguage
}
