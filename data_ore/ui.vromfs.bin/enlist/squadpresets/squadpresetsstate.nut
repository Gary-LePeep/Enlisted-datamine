from "%enlSqGlob/ui/ui_library.nut" import *

let { mkOnlineSaveData } = require("%enlSqGlob/mkOnlineSaveData.nut")
let { hasPremium } = require("%enlist/currency/premium.nut")

const FREE_SLOTS_COUNT = 6
const PREMIUM_SLOTS_COUNT = 4
let MAX_PRESETS_COUNT = FREE_SLOTS_COUNT + PREMIUM_SLOTS_COUNT
let availablePresetsCount = Computed(@() hasPremium.value ? MAX_PRESETS_COUNT : FREE_SLOTS_COUNT)

let squadsPresetsStorage = mkOnlineSaveData("presetSquads", @() {})
let setSquadsPreset = squadsPresetsStorage.setValue
let squadsPresetWatch = squadsPresetsStorage.watch

return {
  setSquadsPreset
  squadsPresetWatch
  availablePresetsCount
  MAX_PRESETS_COUNT
  PREMIUM_SLOTS_COUNT
}
