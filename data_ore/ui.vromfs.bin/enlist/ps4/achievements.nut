from "%enlSqGlob/ui/ui_library.nut" import *

let {unlockPsnTrophy, isPsnTrophyUnlocked} = require("sony.trophies")
let {unlockProgress, unlocksSorted, getUnlockProgress} = require("%enlSqGlob/userstats/unlocksState.nut")

function updatePS4Achievements(_) {
  if (unlockProgress.value.len() == 0)
    return

  foreach (unlockDesc in unlocksSorted.value) {
    local trophy_id = unlockDesc.ps4Id.tointeger()
    if (trophy_id > 0) {// valid gaijin <-> psn mapping

      trophy_id -= 1 // psn trophies ids begin from 0, adjust
      let progress = getUnlockProgress(unlockDesc, unlockProgress.value)
      let completed = progress.current >= progress.required
      let unlocked = isPsnTrophyUnlocked(trophy_id)
      if (completed && !unlocked)
        unlockPsnTrophy(trophy_id)
    }
  }
}

unlockProgress.subscribe(updatePS4Achievements)
unlocksSorted.subscribe(updatePS4Achievements)
