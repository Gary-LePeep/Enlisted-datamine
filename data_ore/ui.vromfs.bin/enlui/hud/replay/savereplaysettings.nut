from "%enlSqGlob/ui/ui_library.nut" import *

let { mkOnlineSaveData } = require("%enlSqGlob/mkOnlineSaveData.nut")
let { levelTimeOfDay, changeDayTime, changeCameraFov, cameraFov, isRain, isSnow,
  isCinematicModeActive, changeBloom, changeAbberation, changeFilmGrain, changeMotionBlur,
  changeVignette, motionBlur, bloomEffect, filmGrain, abberation, vigneteEffect, weatherPreset,
  changeWeatherPreset, isDofCameraEnabled, isDofFilmic, isDofFocalActive, dofFocusDist,
  dofFocalLength, dofStop, dofBokeCount, dofBokeSize, changeBoke, changeBokeSize, changeStop,
  changeFocalLength, changeFocusDist, isLightning, lenseFlareIntensity, changeLenseFlareIntensity,
  changeRain,changeSnow, changeLightning, enablePostBloom, changePostBloom,
  isHudSettingsEnable } = require("%ui/hud/replay/replayCinematicState.nut")
let { get_local_unixtime } = require("dagor.time")
let msgbox = require("%ui/components/msgbox.nut")
let {
  showSelfAwards, showTeammateName, showTeammateMarkers, showCrosshairHints,
  showTips, showGameModeHints, showPlayerUI
} = require("%ui/hud/state/hudOptionsState.nut")
let { isReplay } = require("%ui/hud/state/replay_state.nut")

let savedReplayPresets = mkOnlineSaveData("savedReplayPresets", @() {})
let savedReplayPresetsStored = savedReplayPresets.watch

let savedReplaysCount = mkOnlineSaveData("savedReplaysCount", @() 0)
let savedReplaysCountStored = savedReplaysCount.watch

const MSG_UID = "preset_delete_confirm"
const MAX_PRESETS = 6
let lastChoosenPreset = Watched(null)
local cachedSettings = {}

let replaySettings = {
  levelTimeOfDay = {
    watch = levelTimeOfDay
    action = changeDayTime
  }
  cameraFov = {
    watch = cameraFov
    action = changeCameraFov
  }
  weatherPreset = {
    watch = weatherPreset
    action = changeWeatherPreset
  }
  isRain = {
    watch = isRain
    action = changeRain
  }
  isLightning = {
    watch = isLightning
    action = changeLightning
  }
  isSnow = {
    watch = isSnow
    action = changeSnow
  }
  isCinematicModeActive = {
    watch = isCinematicModeActive
    action = @(v) isCinematicModeActive(v)
  }
  motionBlur = {
    watch = motionBlur
    action = changeMotionBlur
  }
  bloomEffect = {
    watch = bloomEffect
    action = changeBloom
  }
  filmGrain = {
    watch = filmGrain
    action = changeFilmGrain
  }
  abberation = {
    watch = abberation
    action = changeAbberation
  }
  vigneteEffect = {
    watch = vigneteEffect
    action = changeVignette
  }
  lenseFlareIntensity = {
    watch = lenseFlareIntensity
    action = changeLenseFlareIntensity
  }
  enablePostBloom = {
    watch = enablePostBloom
    action = changePostBloom
  }
  isDofCameraEnabled = {
    watch = isDofCameraEnabled
    action = @(v) isDofCameraEnabled(v)
  }
  isDofFilmic = {
    watch = isDofFilmic
    action = @(v) isDofFilmic(v)
  }
  isDofFocalActive = {
    watch = isDofFocalActive
    action = @(v) isDofFocalActive(v)
  }
  dofFocusDist = {
    watch = dofFocusDist
    action = changeFocusDist
  }
  dofFocalLength = {
    watch = dofFocalLength
    action = changeFocalLength
  }
  dofStop = {
    watch = dofStop
    action = changeStop
  }
  dofBokeCount = {
    watch = dofBokeCount
    action = changeBoke
  }
  dofBokeSize = {
    watch = dofBokeSize
    action = changeBokeSize
  }
  showSelfAwards = {
    watch = showSelfAwards
    action = @(v) showSelfAwards(v)
  }
  showTeammateName = {
    watch = showTeammateName
    action = @(v) showTeammateName(v)
  }
  showTeammateMarkers = {
    watch = showTeammateMarkers
    action = @(v) showTeammateMarkers(v)
  }
  showCrosshairHints = {
    watch = showCrosshairHints
    action = @(v) showCrosshairHints(v)
  }
  showTips = {
    watch = showTips
    action = @(v) showTips(v)
  }
  showGameModeHints = {
    watch = showGameModeHints
    action = @(v) showGameModeHints(v)
  }
  showPlayerUI = {
    watch = showPlayerUI
    action = @(v) showPlayerUI(v)
  }
  isHudSettingsEnable = {
    watch = isHudSettingsEnable
    action = @(v) isHudSettingsEnable(v)
  }
}

let replayPresets = Computed(function() {
  let res = []
  savedReplayPresetsStored.value.each(@(val) res.append({
    val = val
    loc = loc("replay/preset", { preset = val.name })
    setValue = @(idx) lastChoosenPreset(idx)
  }))
  return res.sort(@(a, b) a.val.creationTime <=> b.val.creationTime)
})


function savePreset() {
  let saved = clone savedReplayPresetsStored.value
  let data = {}
  let presetNumber = savedReplaysCountStored.value + 1
  let creationTime = get_local_unixtime()
  let curPreset = $"preset{presetNumber}"
  savedReplaysCount.setValue(presetNumber)
  foreach (key, val in replaySettings)
    data[key] <- val.watch.value
  data.__update({
    pNumber = presetNumber
    name = presetNumber.tostring()
    creationTime
  })
  saved[curPreset] <- data
  savedReplayPresets.setValue(saved)
}


function loadPreset(presetIdx) {
  cachedSettings = {}
  let presetValues = replayPresets.value?[presetIdx].val ?? {}
  presetValues.each(function(v, key){
    replaySettings?[key].action(v)
    cachedSettings[key] <- v
  })
}


function saveToCurrentPreset(presetIdx) {
  if (lastChoosenPreset.value == null)
    return
  let { pNumber = -1 } = replayPresets.value?[presetIdx].val
  let presetKey = $"preset{pNumber}"
  let settingsToUpdate = replaySettings.map(@(val) val.watch.value)
  let creationTime = get_local_unixtime()
  settingsToUpdate.__update({
    pNumber
    name = pNumber.tostring()
    creationTime
  })
  let saved = clone savedReplayPresetsStored.value
  saved[presetKey] <- settingsToUpdate
  savedReplayPresets.setValue(saved)
}

function deletePreset(presetIdx) {
  msgbox.show({
    uid = MSG_UID
    text = loc("replay/deletePresetConfirm", { preset = replayPresets.value[presetIdx].loc })
    buttons = [
      { text = loc("Yes"),
        action = function() {
          let saved = clone savedReplayPresetsStored.value
          let presetToDelete = $"preset{replayPresets.value[presetIdx].val.pNumber}"
          saved.$rawdelete(presetToDelete)
          savedReplayPresets.setValue(saved)
          lastChoosenPreset(null)
        }
        isCurrent = true
      }
      { text = loc("No")
        isCancel = true
      }
    ]
  })
}

lastChoosenPreset.subscribe(@(v) loadPreset(v))

function resetHudSettings() {
  showSelfAwards(true)
  showTeammateName(true)
  showTeammateMarkers(true)
  showCrosshairHints(true)
  showTips(true)
  showGameModeHints(true)
  showPlayerUI(true)
}

let needResetHudSettings = Computed(@() isHudSettingsEnable.value && isReplay.value)
needResetHudSettings.subscribe(@(v) v ? resetHudSettings() : null)
if (isReplay.value && !isHudSettingsEnable.value)
  resetHudSettings()

local defaultSettings = {}
function saveDefaultSettings() {
  if (defaultSettings.len() <= 0)
    defaultSettings = replaySettings.map(@(v) v.watch.value)
}

function restoreDefaultSettings() {
  isCinematicModeActive(false)
  replaySettings.each(@(setup, key) key in defaultSettings
    ? setup.action(defaultSettings[key])
    : null)
}


return {
  savePreset
  deletePreset
  loadPreset
  lastChoosenPreset
  replayPresets
  MAX_PRESETS
  saveToCurrentPreset
  saveDefaultSettings
  restoreDefaultSettings
}