from "%enlSqGlob/ui/ui_library.nut" import *

let { json_to_string } = require("json")
let { file } = require("io")
let { dir_exists } = require("dagor.fs")
let { gen_default_profile, gen_tutorial_profiles } = require("%enlist/meta/clientApi.nut")
let { logerr } = require("dagor.debug")

function prepareProfileData(profile) {
  let deleteSoldierKeys = [
    "bodyScale", // used in menu only
    "perkPoints", // used in menu only
    "heroTpl", // used in menu only
    "appearance__rndSeed", // if appearance__rndSeed is not set, a random one will be used. we don't need persistent looks for non player profiles
  ]
  foreach (armyData in profile) {
    if (armyData?["armyProgress"] != null)
      armyData?.$rawdelete("armyProgress")
    foreach (squad in armyData?.squads ?? [])
      foreach (soldier in squad?.squad ?? [])
        foreach (key in deleteSoldierKeys)
          if (soldier?[key] != null)
            soldier.$rawdelete(key)
  }

  local isSuccess = true
  foreach (armyId, armyData in profile) {
    foreach (squad in armyData.squads) {
      if ((squad?.squad ?? []).len() == 0) {
        isSuccess = false
        logerr($"Squad '{squad.squadId}' in army '{armyId}' is empty! Please fix the squad in profileServer configs.")
      }
    }
  }
  return isSuccess
}

function saveProfileImpl(profile, fileName, folderName = "sq_globals", pretty = true) {
  local filePath = $"../prog/{folderName}/data"
  filePath = dir_exists(filePath) ? $"{filePath}/{fileName}" : fileName
  let output = file(filePath, "wt+")
  if (fileName.endswith(".nut"))
    output.writestring("return ");
  output.writestring(json_to_string(profile, pretty))
  output.close()
  console_print($"Saved to {filePath}")
}

function saveOneProfile(profile, fileName, pretty = true, folderName = "sq_globals") {
  if (profile == null)
    return
  if (prepareProfileData(profile))
    saveProfileImpl(profile, fileName, folderName, pretty)
}

function saveProfilePack(profiles, to_file) {
  if (profiles == null)
    return
  let isSuccess = profiles.findvalue(@(p) !prepareProfileData(p)) == null
  if (isSuccess)
    saveProfileImpl(profiles, to_file)
}

let defUnitedArmies = ["usa", "ussr", "ger", "jap"]

let defLegacyArmies = ["moscow", "berlin", "normandy", "tunisia", "stalingrad", "pacific"]
  .reduce(@(res, campId) res.append($"{campId}_allies", $"{campId}_axis"), [])

let getArmyList = @(isUnitedCampaign) isUnitedCampaign ? defUnitedArmies : defLegacyArmies

local consoleProgressId = 0
function startProgress(title) {
  console_command("console.progress_indicator {0} \"{1}\"".subst(++consoleProgressId, title))
  return consoleProgressId
}
let stopProgress = @(id) console_command($"console.progress_indicator {id}")

console_register_command(function(isUnitedCampaign, isPretty) {
  let prgId = startProgress("meta.genDefaultProfile")
  let isUnited = !!isUnitedCampaign
  gen_default_profile("default", getArmyList(isUnited), isUnited, function(res) {
    stopProgress(prgId)
    let { defaultProfile = null } = res
    if (defaultProfile == null)
      return
    foreach(armyId, armyData in defaultProfile) {
      let profile = { [armyId] = armyData }
      saveOneProfile(profile, $"{armyId}.json", !!isPretty, "enlisted_pkg_dev/default")
    }
  })
}, "meta.genDefaultProfile")

console_register_command(function(isUnitedCampaign, isPretty) {
  let prgId = startProgress("meta.genDevProfile")
  let isUnited = !!isUnitedCampaign
  gen_default_profile("dev", getArmyList(isUnited), isUnited, function(res) {
    stopProgress(prgId)
    let { defaultProfile = null } = res
    if (defaultProfile == null)
      return
    foreach(armyId, armyData in defaultProfile) {
      let profile = { [armyId] = armyData }
      saveOneProfile(profile, $"{armyId}.json", !!isPretty, "enlisted_pkg_dev/game")
    }
  })
}, "meta.genDevProfile")

console_register_command(function(isUnitedCampaign, isPretty) {
  let prgId = startProgress("meta.genBotsProfile")
  let isUnited = !!isUnitedCampaign
  gen_default_profile("bots", getArmyList(isUnited), isUnited, function(res) {
    stopProgress(prgId)
    saveOneProfile(res?.defaultProfile, "bots_profile.nut", !!isPretty)
  })
}, "meta.genBotsProfile")

console_register_command(function() {
  let prgId = startProgress("meta.genTutorialProfiles")
  gen_tutorial_profiles(function(res) {
    stopProgress(prgId)
    saveProfilePack(res, "all_tutorial_profiles.nut")
  })
}, "meta.genTutorialProfiles")
