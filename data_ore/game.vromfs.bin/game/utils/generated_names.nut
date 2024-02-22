let { get_setting_by_blk_path } = require("settings")
let { get_arg_value_by_name } = require("dagor.system")

let { nicknames } = ((get_setting_by_blk_path("isChineseVersion") ?? false) || get_arg_value_by_name("kongzhong"))
   ? require("%enlSqGlob/data/generated_nicknames_chinese.nut")
   : require("%enlSqGlob/data/generated_nicknames_eng.nut")

return {
  generatedNames = nicknames
  botSuffix = " "
}
