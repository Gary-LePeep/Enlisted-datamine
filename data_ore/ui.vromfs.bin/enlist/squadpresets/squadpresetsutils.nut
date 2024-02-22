from "%enlSqGlob/ui/ui_library.nut" import *

let { register_command } = require("console")
let { setSquadsPreset, squadsPresetWatch, MAX_PRESETS_COUNT
} = require("%enlist/squadPresets/squadPresetsState.nut")
let { getRomanNumeral } = require("%sqstd/math.nut")
let { unlockedSquads, reserveSquads, chosenSquads, previewSquads, slotsCount,
  getCantTakeSquadReasonData
} = require("%enlist/soldiers/model/chooseSquadsState.nut")
let { addPopup } = require("%enlSqGlob/ui/popup/popupsState.nut")
let { campaignsByArmy } = require("%enlist/meta/profile.nut")
let { renameCommonArmies } = require("%enlSqGlob/renameCommonArmies.nut")
let { onlineSettingUpdated, settings } = require("%enlist/options/onlineSettings.nut")
let { armies } = require("%enlist/meta/servProfile.nut")
let { isUnited } = require("%enlist/meta/campaigns.nut")
let logP = require("%enlSqGlob/library_logs.nut").with_prefix("[Soldiers Presets] ")
let oldUnlockedSquads = require("%enlist/meta/servProfile.nut").unlockedSquads
let { isChangesBlocked, showBlockedChangesMessage } = require("%enlist/quickMatchQueue.nut")

function savePresets(armyId, idx, preset) {
  let squadsPreset = clone squadsPresetWatch.value
  local newPresetsList = clone squadsPreset?[armyId] ?? []
  if (newPresetsList.len() <= idx)
    newPresetsList.resize(idx + 1, null)

  if (preset == null)
    if (idx >= MAX_PRESETS_COUNT)
      newPresetsList.remove(idx)
    else
      newPresetsList[idx] = null
  else {
    let currentPreset = newPresetsList?[idx] ?? {}
    newPresetsList[idx] = currentPreset.__merge(preset)
  }

  local lastPresetIndex = null
  for (local i = newPresetsList.len() - 1; i >= 0; i--) {
    if (newPresetsList[i] != null) {
      lastPresetIndex = i
      break
    }
  }

  if (lastPresetIndex != null) { // Save data with presets
    newPresetsList.resize(lastPresetIndex + 1)
    squadsPreset[armyId] <- newPresetsList
  }
  else if (armyId in squadsPreset) //Try to save empty data. Remove whole block
    squadsPreset.$rawdelete(armyId)

  setSquadsPreset(squadsPreset)
}

let getPreset = function(armyId, idx) {
  let armyPresets = squadsPresetWatch.value?[armyId] ?? []
  if (idx >= armyPresets.len()) {
    logP($"try to accept not existing preset index {idx}", armyPresets)
    return null
  }

  return armyPresets[idx]
}

function createSquadsPreset(armyId, idx, squadIds) {
  if (squadIds.len() == 0) {
    logP("Create: empty squad data.")
    return
  }

  savePresets(armyId, idx, {
    name = loc("squads/presets/new", { name = getRomanNumeral(idx) })
    preset = squadIds
  })
}

function changePresetInfo(armyId, idx, updateInfo) {
  let preset = getPreset(armyId, idx)
  if (!preset)
    return

  if (("name" in updateInfo) && ("campaign" in preset))
    preset.$rawdelete("campaign")

  savePresets(armyId, idx, preset.__merge(updateInfo))
}

let updateSquadsPreset = @(armyId, idx, preset) changePresetInfo(armyId, idx, { preset })
let renameSquadsPreset = @(armyId, idx, name) changePresetInfo(armyId, idx, { name })
let deleteSquadsPreset = @(armyId, idx) savePresets(armyId, idx, null)

function applySquadsPreset(armyId, idx) {
  if (isChangesBlocked.value) {
    showBlockedChangesMessage()
    return
  }
  let preset = clone getPreset(armyId, idx)?.preset
  if (!preset || !previewSquads.value)
    return

  let squadPlaceErrors = {}
  let newChosenSquads = []

  //Filter by actual requirements
  previewSquads.value.each(function(squad) {
    if (!squad?.squadId) //Empty Slot
      return

    let reasonData = getCantTakeSquadReasonData(squad, newChosenSquads, newChosenSquads.len())
    if (reasonData != null) {
      if (reasonData.type not in squadPlaceErrors)
        squadPlaceErrors[reasonData.type] <- reasonData.getErrorText()
      return
    }

    newChosenSquads.append(squad)
  })

  if (squadPlaceErrors.len())
    foreach (errorType, errorText in squadPlaceErrors)
      addPopup({
        id = $"{errorType}_squad_preset_error"
        text = errorText
        needPopup = true
        styleName = "error"
      })

  if (newChosenSquads.len() == 0)
    return

  //Resize for current slotbar size
  newChosenSquads.resize(slotsCount.value, null)

  //Collect final squads with squadId for fast filter
  let previewSquadIds = {}
  newChosenSquads.each(function(squad) {
    if (squad?.squadId)
      previewSquadIds[squad.squadId] <- true
  })

  //Filter all squads list, making new reserve list
  let newReserveSquads = unlockedSquads.value.filter(@(squad) squad != null && squad.squadId not in previewSquadIds)

  chosenSquads(newChosenSquads)
  reserveSquads(newReserveSquads)
}

function moveSquadPresetsToUnited() {
  if (settings.value?.wereSquadPresetsGenerated)
    return

  let campaigns = campaignsByArmy.value
  let presets = {}

  // Save current squads as presets
  foreach (armyId, squads in oldUnlockedSquads.value) {
    let unitedArmy = renameCommonArmies?[armyId]
    if (!unitedArmy)
      continue

    let armyPresets = presets?[unitedArmy] ?? array(MAX_PRESETS_COUNT)
    let campaignId = campaigns?[armyId].id ?? armyId
    if (squads.len() > 0) {
      armyPresets.append({
        name = loc(armyId)
        preset = squads
        campaign = campaignId
      })
      presets[unitedArmy] <- armyPresets
    }
  }

  // Save player's presets
  foreach (armyId, oldPresets in squadsPresetWatch.get()) {
    let unitedArmy = renameCommonArmies?[armyId]
    if (!unitedArmy)
      continue

    let armyPresets = presets?[unitedArmy] ?? array(MAX_PRESETS_COUNT)
    presets[unitedArmy] <- armyPresets
    let campaignId = campaigns?[armyId].id ?? armyId
    foreach (preset in oldPresets) {
      if (preset)
        armyPresets.append({
          name = preset.name
          preset = clone preset.preset
          campaign = campaignId
        })
    }
  }

  if (presets.len() > 0) {
    setSquadsPreset(presets)
    settings.mutate(@(v) v.wereSquadPresetsGenerated <- true)
  }
}

let isProfileDataReady = keepref(Computed(@() onlineSettingUpdated.value
  && oldUnlockedSquads.value.len() > 0 && armies.value.len() > 0))

isProfileDataReady.subscribe(function(v) {
  if (!v)
    return

  isProfileDataReady.unsubscribe(callee())

  if (isUnited())
    moveSquadPresetsToUnited()
})

register_command(createSquadsPreset, "debug.preset.squads.create")
register_command(updateSquadsPreset, "debug.preset.squads.update")
register_command(deleteSquadsPreset, "debug.preset.squads.delete")
register_command(renameSquadsPreset, "debug.preset.squads.rename")
register_command(applySquadsPreset, "debug.preset.squads.accept")

register_command(moveSquadPresetsToUnited, "presets.squads.move_to_united")
register_command(@() console_print("Squad presets: ", squadsPresetWatch.value),
  "presets.squads.list")
register_command(@() setSquadsPreset(null), "presets.squads.clear")
register_command(@() settings.mutate(@(v) v.wereSquadPresetsGenerated <- false),
  "presets.squads.reset_generation_flag")


return {
  createSquadsPreset
  updateSquadsPreset
  deleteSquadsPreset
  renameSquadsPreset
  applySquadsPreset
}