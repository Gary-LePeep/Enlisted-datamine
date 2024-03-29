require ecs
require DngNet
require enlisted.events_enlisted
require danetlibs.native_dasevents.main.native_events
require game.es.cannon_resupply_common


[es(tag=server, before=fortification_repair_finish_es)]
def cannon_resupply_finish_es(evt : EventRepairFortificationFinish;
                              human_weap__currentGunEid : EntityId;
                              fortification_repair__target : EntityId;
                              var stockOfBuilderCapabilities : float&)
  query(human_weap__currentGunEid) <| $ [es(REQUIRE=previewTemplate)] ()
    query(fortification_repair__target) <| $ [es] (eid : EntityId;
                                                   turret_control__gunEids : EidList;
                                                   buildingCost : float;
                                                   fortification_repair__costPercent : float = 0.5)
      let shellInfo = get_turrets_shell_info(turret_control__gunEids)
      if shellInfo.current == shellInfo.max
        sendEvent(eid, [[CmdHeroLogEvent event="resupply_ammo_full", text="resupply/ammo_full"]])
        return

      let repairCost = calculate_resupply_cost(shellInfo, buildingCost, fortification_repair__costPercent)
      if repairCost > stockOfBuilderCapabilities
        sendEvent(eid, [[CmdHeroLogEvent event="building_blocked_no_require_resources", text="building_blocked_no_require_resources"]])
        return
      stockOfBuilderCapabilities -= repairCost
      send_net_event(eid, [[CmdResupplyVehicle]])

[es(tag=server, before=fortification_repair_start_es, after=before_fortification_repair_start_es)]
def cannon_resupply_start_es(evt : EventRepairFortificationStart;
                             eid : EntityId;
                             human_weap__currentGunEid : EntityId;
                             var fortification_repair__canRepair : bool&;
                             var fortification_repair__repairCost : float&)
  if !fortification_repair__canRepair
    return

  query(human_weap__currentGunEid) <| $ [es(REQUIRE=previewTemplate)] ()
    query(evt.target) <| $ [es] (turret_control__gunEids : EidList;
                                 buildingCost : float;
                                 isAlive : bool = true;
                                 fortification_repair__costPercent : float = 0.5)
      fortification_repair__canRepair &&= isAlive
      if !fortification_repair__canRepair
        return

      let shellInfo = get_turrets_shell_info(turret_control__gunEids)
      if shellInfo.current == shellInfo.max
        sendEvent(eid, [[CmdHeroLogEvent event="resupply_ammo_full", text="resupply/ammo_full"]])
        fortification_repair__canRepair = false
        return

      let repairCost = calculate_resupply_cost(shellInfo, buildingCost, fortification_repair__costPercent)
      fortification_repair__repairCost += repairCost
