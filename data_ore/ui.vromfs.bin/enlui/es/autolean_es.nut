import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui/ui_library.nut" import *

let autoleanSettingState = require("%enlSqGlob/ui/autoleanState.nut")


let setAutoleanSettingQuery = ecs.SqQuery("setAutoleanSettingQuery", {
  comps_rw = [["autolean_settings__autolean", ecs.TYPE_BOOL]]
})

let setAutoleanSettingComponent = @(autoleanValue) setAutoleanSettingQuery(@(_eid, comp) comp.autolean_settings__autolean = autoleanValue)

autoleanSettingState.subscribe(@(autoleanValue) setAutoleanSettingComponent(autoleanValue))

ecs.register_es("autolean_settings",
  { onInit = @(_evt, _eid, comp) comp.autolean_settings__autolean = autoleanSettingState.value },
  { comps_rw = [["autolean_settings__autolean", ecs.TYPE_BOOL]] },
  { tags="gameClient" }
)
