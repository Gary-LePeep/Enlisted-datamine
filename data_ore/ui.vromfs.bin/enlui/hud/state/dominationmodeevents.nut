from "%enlSqGlob/ui/ui_library.nut" import *

let { myScore, myScoreBleed, myScoreBleedFast } = require("%ui/hud/state/team_scores.nut")
let {playerEvents} = require("%ui/hud/state/eventlog.nut")
let {sound_play} = require("%dngscripts/sound_system.nut")
let { missionType } = require("%enlSqGlob/missionParams.nut")

let defEvent = {text=loc("The enemy's almost won!"), myTeamScores=false}
let defSound = ""
//let defSound = "vo/ui/enlisted/narrator/loosing_scores_ally_domination"
// Should NOT play narrator as some sound!
// Narrator is made with single sound event with cooldown and phrase queue daNetGameLibs\sound\team_narrator\modules\team_narrator_common.das
// Should ONLY play narrator through team_narrator_common, e.g. with CmdNetTeamNarrator, see enlisted\prog\scripts\game\es\sound\team_narrator.das
// Do not hardcode FMOD paths except gui events maybe

let events = {
  showFailWarning = {
    watch = Computed(@() missionType.value == "domination" && (myScore.value < 0.2) && (myScoreBleed.value || myScoreBleedFast.value))
  }
  showFailFastWarning = {
    watch = Computed(@() missionType.value == "domination" && (myScore.value < 0.1) && (myScoreBleed.value || myScoreBleedFast.value))
  }
  showLowScore = {
    watch = Computed(@() missionType.value == "domination" && (myScore.value < 0.05))
  }
}

foreach (e in events) {
  let {event=defEvent, sound = defSound, watch} = e
  keepref(watch)
  watch.subscribe(function(val) {
    if (val) {
      if (sound != "")
        sound_play(sound)
      playerEvents.pushEvent(event)
    }
  })
}
