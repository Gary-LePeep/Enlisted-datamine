import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui/ui_library.nut" import *

let is_teams_friendly = require("%enlSqGlob/is_teams_friendly.nut")
let {localPlayerTeam} = require("%ui/hud/state/local_player.nut")

let usefulBoxHintFull = Watched(null)
let usefulBoxHintCost = Watched(null)
let usefulBoxHintEmpty = Watched(null)
let isUsefulBoxEmpty = Watched(false)
let usefulBoxPrice = Watched(0)
let selectedUsefulBox = Watched(ecs.INVALID_ENTITY_ID)

let usefulBoxQuery = ecs.SqQuery("usefulBoxQuery", {
  comps_ro = [
    ["useful_box__hintEmpty", ecs.TYPE_STRING],
    ["useful_box__hintFull", ecs.TYPE_STRING],
    ["useful_box__hintCost", ecs.TYPE_STRING],
    ["useful_box__useCount", ecs.TYPE_INT],
    ["useful_box__anyTeam", ecs.TYPE_TAG, null],
    ["team", ecs.TYPE_INT],
    ["useful_box__uiPrice", ecs.TYPE_INT, 0]
  ]
})

ecs.register_es("ui_useful_box_hint_es",
  {
    [["onChange", "onInit"]] = function (_eid, comp) {
      let selectedObject = comp["human_use_object__selectedObject"]
      local hintFull = null
      local hintEmpty = null
      local hintCost = null
      local isBoxEmpty = false
      local usefulBox = ecs.INVALID_ENTITY_ID
      local price = 0
      usefulBoxQuery(selectedObject, function(eid, boxComp) {
        if (!boxComp.useful_box__anyTeam && !is_teams_friendly(localPlayerTeam.value, boxComp.team))
          return

        usefulBox = eid
        hintFull = boxComp["useful_box__hintFull"]
        hintEmpty = boxComp["useful_box__hintEmpty"]
        hintCost = boxComp["useful_box__hintCost"]
        isBoxEmpty = (boxComp["useful_box__useCount"] == 0)
        price = boxComp["useful_box__uiPrice"]
      })
      usefulBoxHintFull(hintFull)
      usefulBoxHintEmpty(hintEmpty)
      usefulBoxHintCost(hintCost)
      isUsefulBoxEmpty(isBoxEmpty)
      selectedUsefulBox(usefulBox)
      usefulBoxPrice(price)
    },
  },
  {
    comps_track = [["human_use_object__selectedObject", ecs.TYPE_EID]],
    comps_rq = ["hero"]
  },
  { before="ui_useful_box_ammo_count_changed_es" }
)

ecs.register_es("ui_useful_box_ammo_count_changed_es",
  {
    [["onChange", "onInit"]] = function (eid, comp) {
      if (selectedUsefulBox.value == eid) {
        isUsefulBoxEmpty(comp["useful_box__useCount"] == 0)
        usefulBoxPrice(comp["useful_box__uiPrice"])
      }
    },
  },
  {
    comps_track = [
      ["useful_box__useCount", ecs.TYPE_INT],
      ["useful_box__uiPrice", ecs.TYPE_INT, 0]
    ]
  }
)

return {
  usefulBoxHintFull
  usefulBoxHintEmpty
  usefulBoxHintCost
  isUsefulBoxEmpty
  usefulBoxPrice
}