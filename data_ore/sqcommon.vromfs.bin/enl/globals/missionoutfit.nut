import "%dngscripts/ecs.nut" as ecs

let missionOutfitQuery = ecs.SqQuery("missionOutfitQuery", {comps_ro=[["mission_outfit", ecs.TYPE_STRING]]})
let getMissionOutfit = @() missionOutfitQuery.perform(@(_, comp) comp.mission_outfit)

return {
  getMissionOutfit
}