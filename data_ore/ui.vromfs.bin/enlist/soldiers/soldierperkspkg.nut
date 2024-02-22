from "%enlSqGlob/ui/ui_library.nut" import *

let msgbox = require("%enlist/components/msgbox.nut")
let { getLinkedArmyName } = require("%enlSqGlob/ui/metalink.nut")
let { focusResearch, findResearchTrainClass, hasResearchSquad
} = require("%enlist/researches/researchesFocus.nut")
let { soldierClasses } = require("%enlSqGlob/ui/soldierClasses.nut")
let JB = require("%ui/control/gui_buttons.nut")

function showTrainResearchMsg(soldier, cb = null) {
  let { sClass = "unknown" } = soldier
  let armyId = getLinkedArmyName(soldier)
  let research = findResearchTrainClass(soldier)
  if (research == null)
    msgbox.show({ text = loc("msg/cantTrainClassHigher") })
  else if (!hasResearchSquad(armyId, research))
    msgbox.show({ text = loc("msg/needUnlockSquadToTrain",
      { sClass = loc(soldierClasses?[sClass].locId ?? "unknown") }) })
  else
    msgbox.show({
      text = loc("msg/needResearchToTrainHigher")
      buttons = [
        { text = loc("GoToResearch")
          action = function() {
            cb?()
            focusResearch(research)
          }
          customStyle = { hotkeys = [[ "^J:Y | Enter" ]] }
        }
        { text = loc("Cancel")
          isCurrent = true
          customStyle = { hotkeys = [[ $"^{JB.B} | Esc" ]]}
        }
      ]
    })
}

return {
  showTrainResearchMsg
}
