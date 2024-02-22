from "%enlSqGlob/ui/ui_library.nut" import *

let {get_setting_by_blk_path} = require("settings")
let autoleanSettingState = mkWatched(persist, "autoleanSetting", get_setting_by_blk_path("gameplay/autolean_setting") ?? false)

return autoleanSettingState
