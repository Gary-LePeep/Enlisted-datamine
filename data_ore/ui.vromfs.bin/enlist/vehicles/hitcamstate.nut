import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui/ui_library.nut" import *

let mkBulletTypeIcon = require("%enlSqGlob/ui/mkBulletTypeIcon.nut")

let { getItemName } = require("%enlSqGlob/ui/itemsInfo.nut")
let { unlockedCampaigns } = require("%enlist/meta/campaigns.nut")
let { curArmy, allAvailableArmies } = require("%enlist/soldiers/model/state.nut")
let { allItemTemplates } = require("%enlist/soldiers/model/all_items_templates.nut")
let { get_weapons_for_hangar_hitcam } = require("das.hitcam")


let weaponsTable = {}
let selWeaponEid = Watched(ecs.INVALID_ENTITY_ID)

function initWeaponList() {
  if (weaponsTable.len() == 0)
    foreach (weapon in get_weapons_for_hangar_hitcam())
      weaponsTable[weapon] <- true
}

let db = ecs.g_entity_mgr.getTemplateDB()

function mkHitcamData() {
  let hitcamArmyId = Watched(curArmy.value)
  let hitcamVehicleId = Watched(null)
  let weaponId = Watched(null)
  let ammoIndex = Watched(0)
  let shotDistance = Watched(50)
  let hitcamAmmoList = Watched([])

  let hitcamArmiesList = Computed(function() {
    let armiesByCampaign = allAvailableArmies.value
    let res = []
    foreach (campaignId in unlockedCampaigns.value)
      foreach (armyId in armiesByCampaign?[campaignId] ?? [])
        res.append(armyId)

    return res.map(@(v) [v, loc($"{v}/full")])
  })

  let hitcamVehiclesList = Computed(function() {
    let armyId = hitcamArmyId.value
    if (armyId == null)
      return []

    let templates = (allItemTemplates.value?[armyId] ?? {})
      .filter(@(tpl) tpl.itemtype == "vehicle" && tpl.itemsubtype == "tank")

    let res = {}
    foreach (template in templates)
      res[template.gametemplate] <- getItemName(template)

    return res.keys().map(@(tlp) [tlp, res[tlp]])
  })

  let setVehicleId = @(_v = null) hitcamVehicleId(hitcamVehiclesList.value?[0][0])
  hitcamVehiclesList.subscribe(setVehicleId)
  setVehicleId()

  let turretsList = Computed(function() {
    let templateId = hitcamVehicleId.value
    if (templateId == null)
      return []

    let template = db.getTemplateByName(templateId)
    if (template == null)
      return []

    let turrets = template?.getCompValNullable("turret_control__turretInfo").getAll() ?? []
    let ammoDistribution = template?.getCompValNullable("turrets__initAmmoDistribution").getAll() ?? []
    let mgAmmoDistribution = template?.getCompValNullable("turrets__initAmmoDistributionMachineguns").getAll() ?? []

    let turretsListRes = []
    foreach (turret in turrets) {
      let { gun = "" } = turret
      let gunTemplates = gun.split("+")
      let isMain = gunTemplates.contains("main_turret")
      let isTurret = gunTemplates.contains("turret_with_several_types_of_shells")
      turretsListRes.append({
        gunTemplateId = gunTemplates?[0] ?? ""
        isMain
        isTurret
        slots = (isTurret ? ammoDistribution : mgAmmoDistribution).map(@(v) v.slot)
      })
    }

    return turretsListRes
  })

  function setAmmoData(_v = null) {
    let ammoListByTurret = []
    foreach (turret in turretsList.value) {
      let { gunTemplateId, isTurret, slots } = turret
      if (gunTemplateId not in weaponsTable)
        return

      let gunTemplate = db.getTemplateByName(gunTemplateId)
      let gunName = loc(gunTemplate?.getCompValNullable("item__name") ?? "guns/noName")
      let ammoBlocksList = gunTemplate?.getCompValNullable("gun__ammoSetsInfo").getAll() ?? []

      let turretAmmo = { gunTemplateId, gunName, ammoData = [] }
      foreach (slot in slots) {
        let ammo = ammoBlocksList?[slot][0]
        if (ammo == null)
          continue

        let aType = isTurret ? ammo?.type : null
        turretAmmo.ammoData.append({
          slot
          aType
          icon = mkBulletTypeIcon({ bulletType = aType }, [100, 100])
        })
      }
      ammoListByTurret.append(turretAmmo)
    }
    hitcamAmmoList(ammoListByTurret)
  }

  function setWeaponId(_v = null) {
    weaponId(hitcamAmmoList.value?[0].gunTemplateId)
    ammoIndex(hitcamAmmoList.value?[0].ammoData[0].slot)
  }

  function createWeaponEntity(_v = null) {
    ecs.g_entity_mgr.destroyEntity(selWeaponEid.value)
    selWeaponEid(ecs.g_entity_mgr.createEntity(weaponId.value, {}))
  }

  turretsList.subscribe(setAmmoData)
  hitcamAmmoList.subscribe(setWeaponId)
  weaponId.subscribe(createWeaponEntity)

  setAmmoData()
  setWeaponId()
  createWeaponEntity()

  return {
    hitcamArmyId, hitcamVehicleId, weaponId, ammoIndex, shotDistance,
    hitcamArmiesList, hitcamVehiclesList, hitcamAmmoList, turretsList
  }
}

return {
  mkHitcamData
  initWeaponList
  selWeaponEid
}
