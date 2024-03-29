import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui/ui_library.nut" import *

let { RequestSquadBehaviour, sendNetEvent } = require("dasevents")
let { controlledHeroEid } = require("%ui/hud/state/controlled_hero.nut")
let { save_settings, get_setting_by_blk_path, set_setting_by_blk_path } = require("settings")
let { SquadBehaviour } = require("%enlSqGlob/dasenums.nut")
let { find_local_player } = require("%dngscripts/common_queries.nut")

let savedSquadBehaviours = get_setting_by_blk_path("ai/squadBehaviour") ?? {}
let DEFAULT_BEHAVIOUR = SquadBehaviour.ESB_AGGRESSIVE
let squadBehaviour = Watched(DEFAULT_BEHAVIOUR)


function applyNewBehaviour(squadEid, behaviour) {
  sendNetEvent(squadEid, RequestSquadBehaviour({behaviour}))
  squadBehaviour(behaviour)
}

function saveSquadBehaviour(squadProfileId, behaviour) {
  savedSquadBehaviours[squadProfileId] <- behaviour
  set_setting_by_blk_path("ai/squadBehaviour", savedSquadBehaviours)
  save_settings()
}


let heroSquadEidQuery = ecs.SqQuery("heroSquadEidQuery", {
  comps_ro=[["squad_member__squad", ecs.TYPE_EID]]
})

let squadProfileIdQuery = ecs.SqQuery("squadProfileIdQuery", {
  comps_ro=[["squad__squadProfileId", ecs.TYPE_STRING]]
})

function setSquadBehaviour(behaviour) {
  heroSquadEidQuery(controlledHeroEid.value, function(_, comp) {
    let squadEid = comp.squad_member__squad
    applyNewBehaviour(squadEid, behaviour)
    squadProfileIdQuery(squadEid, @(_, sqComp)
      saveSquadBehaviour(sqComp.squad__squadProfileId, behaviour))
  })
}


function applyBehaviourOnSpawnSquad(eid, comp) {
  if (comp.squad__ownerPlayer == ecs.INVALID_ENTITY_ID || comp.squad__ownerPlayer != find_local_player())
    return
  let squadProfileId = comp.squad__squadProfileId

  if (squadProfileId in savedSquadBehaviours)
    applyNewBehaviour(eid, savedSquadBehaviours[squadProfileId])
  else
    squadBehaviour(DEFAULT_BEHAVIOUR)
}

ecs.register_es("apply_squad_behaviour_on_spawn_es", {
    [[ecs.EventEntityCreated, ecs.EventComponentsAppear]] = applyBehaviourOnSpawnSquad
  },
  { comps_ro = [["squad__squadProfileId", ecs.TYPE_STRING], ["squad__ownerPlayer", ecs.TYPE_EID]] },
  { tags = "gameClient" }
)

return {
  setSquadBehaviour
  squadBehaviour
}
