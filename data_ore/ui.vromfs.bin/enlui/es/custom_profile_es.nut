import "%dngscripts/ecs.nut" as ecs
let { loadJson } = require("%sqstd/json.nut")
let { eventbus_send } = require("eventbus")

ecs.register_es("update_custom_profile_es",
  {
    onInit = function(_eid, comp) {
      let tutorialProfile = loadJson(comp["customProfile"])
      eventbus_send("updateArmiesData", tutorialProfile)
    }
  },
  { comps_ro=[["customProfile", ecs.TYPE_STRING]] },
  { tags="gameClient" }
)
