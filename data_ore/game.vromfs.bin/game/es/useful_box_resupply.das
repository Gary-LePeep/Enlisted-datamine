require ecs
require DngNet
require enlisted.events_enlisted
require danetlibs.native_dasevents.main.native_events
require game.es.cannon_resupply_common
require DagorMath
require math.base

[es(tag=server, before=fortification_repair_start_es, after=before_fortification_repair_start_es)]
def useful_box_resupply_start_es(evt : EventRepairFortificationStart;
                                 stockOfBuilderCapabilities : float;
                                 var fortification_repair__canRepair : bool&;
                                 var fortification_repair__repairCost : float&)
  if !fortification_repair__canRepair
    return

  query(evt.target) <| $ [es] (useful_box__maxUseCount : int; useful_box__useCount : int; buildingCost : float; fortification_repair__costPercent : float)
    fortification_repair__canRepair = useful_box__maxUseCount > useful_box__useCount
    let costPerUse = safediv(buildingCost * fortification_repair__costPercent, float(useful_box__maxUseCount))
    var availableUsesRestoreCount = safediv(stockOfBuilderCapabilities, costPerUse)
    if availableUsesRestoreCount < 1.
      fortification_repair__canRepair = false
      return
    availableUsesRestoreCount = min(availableUsesRestoreCount, float(useful_box__maxUseCount - useful_box__useCount))
    fortification_repair__repairCost = availableUsesRestoreCount * costPerUse

[es(tag=server, before=fortification_repair_finish_es)]
def useful_box_resupply_finish_es(evt : EventRepairFortificationFinish;
                                  eid : EntityId;
                                  fortification_repair__target : EntityId;
                                  var stockOfBuilderCapabilities : float&)
  query(fortification_repair__target) <| $ [es] (useful_box__maxUseCount : int;
                                                 buildingCost : float;
                                                 fortification_repair__costPercent : float;
                                                 var useful_box__useCount : int&)
    if useful_box__maxUseCount == useful_box__useCount
      sendEvent(eid, [[CmdHeroLogEvent event="resupply_ammo_full", text="resupply/ammo_full"]])
      return

    let costPerUse = safediv(buildingCost * fortification_repair__costPercent, float(useful_box__maxUseCount))
    var availableUsesRestoreCount = safediv(stockOfBuilderCapabilities, costPerUse)
    availableUsesRestoreCount = min(availableUsesRestoreCount, float(useful_box__maxUseCount - useful_box__useCount))

    if availableUsesRestoreCount < 1.
      sendEvent(eid, [[CmdHeroLogEvent event="building_blocked_no_require_resources", text="building_blocked_no_require_resources"]])
      return

    let totalCost = availableUsesRestoreCount * costPerUse
    stockOfBuilderCapabilities -= totalCost
    useful_box__useCount = useful_box__maxUseCount
