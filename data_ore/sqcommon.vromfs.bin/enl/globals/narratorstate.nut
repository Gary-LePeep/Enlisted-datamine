let { get_setting_by_blk_path } = require("settings")
let { Watched } = require("frp")

let narratorNativeLang = Watched(get_setting_by_blk_path("gameplay/narrator_nativeLanguage") ?? false)

return narratorNativeLang