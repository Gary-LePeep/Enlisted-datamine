import "%dngscripts/ecs.nut" as ecs

let {get_setting_by_blk_path} = require("settings")

let function setFlightSenseSettings(_evt, _eid, comp) {
  let optionValue = get_setting_by_blk_path("gameplay/plane_flight_sense")
  if (optionValue != null)
    comp.plane_inertial_cam__flightSense = optionValue / 100
}

ecs.register_es("flight_sense_settings_ui_es",
  {onInit = setFlightSenseSettings},
  {comps_rw = [["plane_inertial_cam__flightSense", ecs.TYPE_FLOAT]]},
  {tags = "gameClient"}
)
