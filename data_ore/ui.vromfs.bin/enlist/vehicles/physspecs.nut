import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui_library.nut" import *

let { logerr } = require("dagor.debug")
let upgrades = require("%enlist/soldiers/model/config/upgradesConfig.nut")

let DB = ecs.g_entity_mgr.getTemplateDB()
let specsCache = Watched({}) // {}[gametemplate][upgradeIdx]
let specsQueue = [] // [{ gametemplate, upgradesId, upgradeIdx }]
local specsCur = null

let function getVehicleSpecBlkPath(template, name) {
  let path = template.getCompValNullable(name)
  if (path == null)
    return null
  let idx = path.indexof(":")
  return idx == null ? path : path.slice(0, idx)
}

let mkModificationsBlk = @(curUpgrades)
  curUpgrades.reduce(@(res, value, name) $"{res}{name}:r={value / 100.0 + 1.0};", "")

let getItemUpgrade = @(upgradesValue, upgradesId, upgradeIdx)
  upgradesValue?[upgradesId][upgradeIdx] ?? {}

let function setItemSpec(specs, data) {
  let { gametemplate, upgradeIdx } = specs
  specsCache.mutate(function(v) {
    local upgradesList = v?[gametemplate]
    if (upgradesList == null) {
      upgradesList = []
      v[gametemplate] <- upgradesList
    }
    if (upgradesList.len() <= upgradeIdx)
      upgradesList.resize(upgradeIdx + 1, null)
    let curData = upgradesList?[upgradeIdx] ?? {}
    upgradesList[upgradeIdx] = curData.__merge(data)
  })
}

local requireVehicleSpec

let function processSpecs() {
  if (specsCur != null)
    return

  while (specsQueue.len() > 0) {
    let specs = specsQueue.remove(0)
    let { gametemplate, upgradesId, upgradeIdx } = specs
    if (specsCache.value?[gametemplate][upgradeIdx] == null) {
      let curUpgrades = getItemUpgrade(upgrades.value, upgradesId, upgradeIdx)
      let isDelayed = requireVehicleSpec(gametemplate, curUpgrades)
      if (isDelayed) {
        specsCur = specs
        return
      }
    }
  }
}

let function requireSpecsUpdate(gametemplate, upgradesId, upgradeIdx) {
  specsQueue.append({ gametemplate, upgradesId, upgradeIdx })
  processSpecs()
}

requireVehicleSpec = function(templateName, curUpgrades = {}) {
  let template = DB.getTemplateByName(templateName)
  if (template == null) {
    logerr($"Template '{templateName}' was not found")
    return false
  }

  let physModificationsBlk = mkModificationsBlk(curUpgrades)

  let tankSpecBlkPath = getVehicleSpecBlkPath(template, "vehicle_net_phys__blk")
  if (tankSpecBlkPath != null) {
    ecs.g_entity_mgr.createEntity("tank_phys_spec", {
      "tankTemplateName"     : [templateName,         ecs.TYPE_STRING]
      "tank_phys_spec__blk"  : [tankSpecBlkPath,      ecs.TYPE_STRING]
      "physModificationsBlk" : [physModificationsBlk, ecs.TYPE_STRING]
    })
    return true
  }

  let planeSpecBlkPath = getVehicleSpecBlkPath(template, "plane_net_phys__blk")
  if (planeSpecBlkPath != null) {
    let collresName = template.getCompValNullable("collres__res")
    if (collresName == null) {
      logerr($"Component 'collres__res' was not found for template '{templateName}'")
      return false
    }
    ecs.g_entity_mgr.createEntity("plane_phys_spec", {
      "planeTemplateName"    : [templateName,         ecs.TYPE_STRING]
      "plane_phys_spec__blk" : [planeSpecBlkPath,     ecs.TYPE_STRING]
      "collresName"          : [collresName,          ecs.TYPE_STRING]
      "physModificationsBlk" : [physModificationsBlk, ecs.TYPE_STRING]
    })
    return true
  }

  return false
}

ecs.register_es("tank_phys_spec_calculated_es",
  {
    function onChange(_evt, eid, comp) {
      setItemSpec(specsCur, {
        maxSpeed = comp["tank_phys_spec_result__maxSpeed"]
      })
      ecs.g_entity_mgr.destroyEntity(eid)
      specsCur = null
      processSpecs()
    }
  },
  {
    comps_ro = [
      ["tankTemplateName", ecs.TYPE_STRING],
    ],
    comps_track = [
      ["tank_phys_spec_result__maxSpeed", ecs.TYPE_FLOAT],
    ],
  }
)

ecs.register_es("plane_phys_spec_calculated_es",
  {
    function onChange(_evt, eid, comp) {
      setItemSpec(specsCur, {
        maxSpeed = comp["plane_phys_spec_result__maxSpeed"]
        maxClimb = comp["plane_phys_spec_result__maxClimb"]
        bestTurnTime = comp["plane_phys_spec_result__bestTurnTime"]
      })
      ecs.g_entity_mgr.destroyEntity(eid)
      specsCur = null
      processSpecs()
    }
  },
  {
    comps_ro = [
      ["planeTemplateName", ecs.TYPE_STRING],
    ],
    comps_track = [
      ["plane_phys_spec_result__maxSpeed",     ecs.TYPE_FLOAT],
      ["plane_phys_spec_result__maxClimb",     ecs.TYPE_FLOAT],
      ["plane_phys_spec_result__bestTurnTime", ecs.TYPE_FLOAT],
    ],
  }
)

let function getItemSpec(specsValue, item) {
  let { gametemplate = null, itemtype = null, upgradeIdx = 0 } = item
  if (itemtype != "vehicle")
    return {}

  return specsValue?[gametemplate][upgradeIdx] ?? {}
}

let function requireItemSpec(item) {
  let { gametemplate = null, itemtype = null, upgradesId = null, upgradeIdx = 0 } = item
  if (itemtype == "vehicle")
    requireSpecsUpdate(gametemplate, upgradesId ?? "", upgradeIdx)
}

return {
  specsCache
  requireVehicleSpec
  getItemUpgrade
  getItemSpec
  requireItemSpec
}