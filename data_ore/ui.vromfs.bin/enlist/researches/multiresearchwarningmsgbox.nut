from "%enlSqGlob/ui/ui_library.nut" import *

let { fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let { defTxtColor, titleTxtColor } = require("%enlSqGlob/ui/designConst.nut")
let { MsgMarkedText } = require("%ui/style/colors.nut")
let { showMessageWithContent } = require("%enlist/components/msgbox.nut")
let colorize = require("%ui/components/colorize.nut")
let checkbox = require("%ui/components/checkbox.nut")
let { settings } = require("%enlist/options/onlineSettings.nut")
let JB = require("%ui/control/gui_buttons.nut")

const SAVE_ID = "seen/multiresearchWarning"

let dontShowAgain = Computed(@() settings.value?[SAVE_ID] ?? false)
let setDontShowAgain = @(val) settings.mutate(@(v) v[SAVE_ID] <- val)

let textarea = @(text, color) {
  size = [flex(), SIZE_TO_CONTENT]
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  halign = ALIGN_CENTER
  color
  text
}.__update(fontBody)

function multiresearchWarningMsgbox(research, pageResearches, unlockAction) {
  let { multiresearchGroup = 0, research_id, name = "", params = {} } = research
  if (dontShowAgain.value || multiresearchGroup <= 0) {
    unlockAction()
    return
  }
  let group = pageResearches.filter(@(r) r?.multiresearchGroup == multiresearchGroup && r.research_id != research_id)
  if (group.len() == 0) {
    unlockAction()
    return
  }

  showMessageWithContent({
    uid = "multiresearch_confirm"
    content = {
      flow = FLOW_VERTICAL
      size = [sw(50), SIZE_TO_CONTENT]
      margin = [fsh(5), 0]
      gap = fsh(3)
      halign = ALIGN_CENTER
      children = [
        textarea(loc("research/groupCanResearch"), titleTxtColor)
        textarea(
          loc("research/groupCanResearch/desc",
            {
              research = colorize(MsgMarkedText, loc(name, params))
              otherInGroup = ", ".join(group.values().map(@(r) colorize(MsgMarkedText, loc(r.name, r?.params))))
            }),
          defTxtColor)
        checkbox(dontShowAgain,
          {
            text = loc("msgbox/dontShowAgain")
            color = titleTxtColor
          }.__update(fontBody),
          {
            setValue = setDontShowAgain
            textOnTheLeft = true
          })
      ]
    }
    buttons = [
      { text = loc("Yes"),
        action = unlockAction
        isCurrent = true
      }
      { text = loc("Cancel")
        isCancel = true
        customStyle = { hotkeys = [[$"^{JB.B} | Esc"]] }
      }
    ]
  })
}

console_register_command(function() {
  if (SAVE_ID in settings.value)
    settings.mutate(@(v) v.$rawdelete(SAVE_ID))
}, "dontShowAgain.multiresearch.reset")

return multiresearchWarningMsgbox