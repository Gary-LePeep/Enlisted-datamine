let { get_setting_by_blk_path } = require("settings")
let { Watched } = require("frp")

let vehicleGroupLimit = Watched(get_setting_by_blk_path("gameplay/limit_vehicle_by_group") ?? false)

return vehicleGroupLimit
