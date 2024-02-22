from "%enlSqGlob/ui/ui_library.nut" import *

let squadsPresentation = require("%enlSqGlob/ui/squadsPresentation.nut")
let serverConfigs = require("%enlist/meta/configs.nut").configs

let ordered = Computed(@() (serverConfigs.value?.squads_config ?? {})
  .map(@(list, armyId) list.map(function(squad, sIdx) {
        let squadPres = squadsPresentation?[armyId][squad?.id] ?? {}
        return squad.__merge(squadPres, { index = sIdx })
      }
    )
  )
)

let allSquadTypes = Computed(function() {
  let res = []
  let squadTypeTracker = {}
  let squadsConfig = serverConfigs.value?.squads_config ?? {}
  foreach(army in squadsConfig)
    foreach(squad in army) {
      let { squadType } = squad
      if (squadType not in squadTypeTracker) {
        res.append({
          squadType
          nameText = loc($"squadType/{squadType}")
        })
        squadTypeTracker[squadType] <- true
      }
    }
  return res.sort(@(a, b) a.nameText <=> b.nameText)
})

let byId = Computed(@() ordered.value.map(function(list) {
  let res = {}
  foreach (squad in list)
    res[squad.id] <- squad
  return res
}))

return {
  squadsCfgOrdered = ordered
  squadsCfgById = byId
  allSquadTypes
}