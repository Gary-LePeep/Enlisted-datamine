import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui/ui_library.nut" import *

let {get_setting_by_blk_path} = require("settings")
let {getOnlineSaveData, mkSliderWithText, optionCtor} = require("options_lib.nut")

let setPlaneCameraPhysQuery = ecs.SqQuery("setPlaneCameraPhysQuery", {
  comps_rw = [ ["plane_inertial_cam__flightSense", ecs.TYPE_FLOAT] ]
})

function optionCameraPhysTextSliderCtor(opt, group, xmbNode, field) {
  let optSetValue = opt.setValue
  function setValue(val) {
    optSetValue(val)
    setPlaneCameraPhysQuery(function(_eid, comp) {
      comp[field] = val / 100
    })
  }
  opt = opt.__merge({setValue})
  return mkSliderWithText(opt, group, xmbNode)
}

function mkPlaneCameraPhysOption(option, field, settings={}) {
  let blkPath = $"gameplay/{option}"
  let title = loc(blkPath)
  let { watch, setValue } = getOnlineSaveData(blkPath,
    @() get_setting_by_blk_path(blkPath) ?? settings?.defVal ?? 0.0)
  return optionCtor({
    name = title
    tab = "Game"
    widgetCtor = @(opt, group, xmbNode) optionCameraPhysTextSliderCtor(opt, group, xmbNode, field)
    var = watch
    setValue = setValue
    defVal = settings?.defVal ?? 0.0
    min = settings?.minVal ?? 0.0
    max = settings?.maxVal ?? 100.0
    unit = 0.01
    pageScroll = 1
    restart = false
    blkPath = blkPath
  })
}

return {
  planeFlightSenseOption = mkPlaneCameraPhysOption("plane_flight_sense", "plane_inertial_cam__flightSense")
}