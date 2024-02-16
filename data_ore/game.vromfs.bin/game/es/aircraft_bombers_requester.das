require ecs
require enlisted.events_enlisted


[es(tag=server, on_appear)]
def aircraft_bombers_requester_on_appear(evt : Event;
                                         aircraft_bombers_requester__firstRequestDelay : float;
                                         var aircraft_bombers_requester__timeToRequest : float&)
  aircraft_bombers_requester__timeToRequest = aircraft_bombers_requester__firstRequestDelay


[es(tag=server, on_appear, no_order)]
def aircraft_bombers_requester_update(info : UpdateStageInfoAct;
                                      eid : EntityId;
                                      transform : float3x4;
                                      aircraft_bombers_requester__requestPeriod : float;
                                      var aircraft_bombers_requester__timeToRequest : float&)
  if aircraft_bombers_requester__timeToRequest > 0.0
    aircraft_bombers_requester__timeToRequest -= info.dt
    return

  aircraft_bombers_requester__timeToRequest = aircraft_bombers_requester__requestPeriod

  sendEvent(eid, [[CmdStartArtilleryStrikeAtPos owner=eid, pos=transform[3], typeIndex = 0, posEnd = transform[3]]])
