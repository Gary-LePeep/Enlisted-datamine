let { file_exists } = require("dagor.fs")
let { get_arg_value_by_name } = require("dagor.system")

return file_exists("dmm") || get_arg_value_by_name("dmmdistr")