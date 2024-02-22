import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui/ui_library.nut" import *

let { json_to_string } = require("json")
let io = require("io")
let { decode } = require("jwt")
let { eventbus_subscribe, eventbus_send } = require("eventbus")
let { mkCmdProfileJwtData } = require("%enlSqGlob/sqevents.nut")
let { playerSelectedSquads, allAvailableArmies, curArmy } = require("%enlist/soldiers/model/state.nut")
let { curCampaign } = require("%enlist/meta/curCampaign.nut")
let { isEventRoom } = require("%enlist/mpRoom/enlRoomState.nut")
let { myArmy } = require("%enlist/mpRoom/myRoomMemberParams.nut")
let {debug, logerr} = require("dagor.debug")
let { get_profile_data_jwt, debug_apply_booster_in_battle
} = require("%enlist/meta/clientApi.nut")
let {profilePublicKey} = require("%enlSqGlob/data/profile_pubkey.nut")
let { getMissionOutfit } = require("%enlSqGlob/missionOutfit.nut")

let nextBattleData = Watched(null)

function decodeJwtAndHandleErrors(data) {
  let jwt        = data?.jwt ?? ""
  let jwtDecoded = decode(jwt, profilePublicKey)

  let jwtArmies = jwtDecoded?.payload.armies
  let jwtError = jwtDecoded?.error
  if (jwtArmies != null && jwtError == null)
    return {jwt, jwtArmies}

  log(data)

  logerr($"Error '{jwtError}' during jwt profile decoding. See log for more details.")

  return null
}

function requestProfileDataJwt(armies, outfitId, cb, triesCount = 0) {
  if (armies.len() <= 0)
    return

  let armiesToCurSquad = {}
  foreach (armyId in armies)
    armiesToCurSquad[armyId] <- playerSelectedSquads.value?[armyId] ?? ""

  local triesLeft = triesCount
  let cbWrapper = function(data) {
    let res = decodeJwtAndHandleErrors(data)
    if (res != null) {
      let {jwt, jwtArmies} = res
      cb(jwt, jwtArmies)
      return
    }

    if (--triesLeft >= 0) {
      debug($"Try again to get profile jwt. Tries left: {triesLeft}.")
      get_profile_data_jwt(armiesToCurSquad, outfitId, callee())
    }
    else // Fail
      cb("", {})
  }

  get_profile_data_jwt(armiesToCurSquad, outfitId, cbWrapper)
}

function requestProfileDataMission(armies, cb, triesCount = 0) {
  let outfitId = getMissionOutfit()
  requestProfileDataJwt(armies, outfitId, cb, triesCount)
}

function splitStringBySize(str, maxSize) {
  assert(maxSize > 0)
  let result = []
  local start = 0
  let len = str.len()
  while (start < len) {
    let pieceSize = min(len - start, maxSize)
    result.append(str.slice(start, start + pieceSize))
    start += pieceSize
  }
  return result
}

const TRIES_TO_REQUEST_PROFILE = 1

function send(playerEid, jwt, data) {
  ecs.client_send_event(playerEid, mkCmdProfileJwtData({ jwt = splitStringBySize(jwt, 4096) }))
  eventbus_send("updateArmiesData", data)
}

function requestAndSend(playerEid, teamArmy) {
  requestProfileDataMission([teamArmy], @(jwt, data) send(playerEid, jwt, data),
    TRIES_TO_REQUEST_PROFILE)
}

function saveJwtResultToJson(jwt, data, fileName, pretty = true) {
  fileName = $"{fileName}.json"
  local file = io.file(fileName, "wt+")
  file.writestring(json_to_string(data, pretty))
  file.close()
  console_print($"Saved json payload to {fileName}")
  fileName = $"{fileName}.jwt"
  file = io.file(fileName, "wt+")
  file.writestring(jwt)
  file.close()
  console_print($"Saved jwt to {fileName}")
}

function saveToFile(teamArmy = null, pretty = true) {
  let cb = @(jwt, data) saveJwtResultToJson(jwt, data, "sendArmiesData", pretty)
  if (teamArmy == null) {
    let requestArmies = []
    foreach (armies in allAvailableArmies.value)
      requestArmies.extend(armies)
    requestProfileDataMission(requestArmies, cb)
  }
  else
    requestProfileDataMission([teamArmy], cb)
}

let mkJwtArmiesCbNoRetries = @(cb) function(data) {
  let res = decodeJwtAndHandleErrors(data)
  if (res == null) {// Fail
    cb("", {})
    return
  }
  let {jwt, jwtArmies} = res
  cb(jwt, jwtArmies)
}

let findArmy = @(armies, allArmies) armies.findvalue(@(a) allArmies.contains(a))

eventbus_subscribe("requestArmiesData", function(msg) {
  let { armies, playerEid } = msg
  if (armies.contains(nextBattleData.value?.armyId))
    send(playerEid, nextBattleData.value.jwt, nextBattleData.value.data)
  else {
    let selArmyId = isEventRoom.value ? myArmy.value : curArmy.value
    local armyId = armies.findvalue(@(a) a == curArmy.value)
      ?? findArmy(armies, allAvailableArmies.value?[curCampaign.value] ?? [])
    log($"[ARMY_DATA] request army data for army {armyId} (selArmy = {selArmyId})")
    if (armyId == null)
      foreach (list in allAvailableArmies.value) {
        armyId = findArmy(armies, list)
        if (armyId != null)
          break
      }
    if (armyId == null)
      logerr("requestArmiesData: no available armies in requested armies. armies = [{0}]".subst(", ".join(armies)))

    requestAndSend(playerEid, armyId ?? curArmy.value ?? armies[0])
  }
  nextBattleData(null)
})

function debugApplyBoosterInBattle() {
  let armyId = curArmy.value
  requestProfileDataMission([armyId], function(_jwt, data) {
    let boosters = (data?[armyId].boosters ?? []).map(@(b) b.guid)
    console_print($"Boosters applied in army {armyId}: ", ", ".join(boosters))
    debug_apply_booster_in_battle(boosters)
  })
}

console_register_command(@(armyId) requestProfileDataMission([armyId], @(_jwt, data)
  log.debugTableData(data, { recursionLevel = 7, printFn = debug }) ?? log("Done")),
  "profileData.debugArmyData")

console_register_command(@(pretty) saveToFile(null/*teamArmy*/, !!pretty),
  "profileData.profileToJson",
  "[pretty] If set to true, then you will get a beautiful json output")

console_register_command(debugApplyBoosterInBattle, "profileData.debugApplyBoosterInBattle")

console_register_command(function(outfitId) {
  let armyId = curArmy.value
  let cb = @(jwt, data) saveJwtResultToJson(jwt, data, $"army_{armyId}_{outfitId}")
  requestProfileDataJwt([armyId], outfitId, cb)
}, "meta.dumpGameProfile")

return {
  saveJwtResultToJson
  mkJwtArmiesCbNoRetries
  setNextBattleData = @(armyId, jwt, data) nextBattleData({ armyId, jwt, data })
}