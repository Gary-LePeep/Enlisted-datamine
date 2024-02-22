import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui/ui_library.nut" import *

let {localPlayerEid} = require("%ui/hud/state/local_player.nut")
let {CmdCreateMapPoint, CmdCreateParatroopersSpawn, sendNetEvent} = require("dasevents")
let { Point2 } = require("dagor.math")

function mapCoordsToReal(event, minimapState){
  let rect = event.targetRect
  let elemW = rect.r - rect.l
  let elemH = rect.b - rect.t
  let relX = (event.screenX - rect.l - elemW*0.5) * 2 / elemW
  let relY = (event.screenY - rect.t - elemH*0.5) * 2 / elemH
  let worldPos = minimapState.mapToWorld(relY, relX) // take care of rotation
  return worldPos
}

function command(event, minimapState){
  let worldPos = mapCoordsToReal(event, minimapState)
  ecs.g_entity_mgr.sendEvent(localPlayerEid.value, CmdCreateMapPoint({x = worldPos.x, z = worldPos.z}))
}

function troopersSpawnCoords(event, minimapState){
  let worldPos = mapCoordsToReal(event, minimapState)
  sendNetEvent(localPlayerEid.value, CmdCreateParatroopersSpawn({point = Point2(worldPos.x, worldPos.z)}))
}

return {
  command
  troopersSpawnCoords
}