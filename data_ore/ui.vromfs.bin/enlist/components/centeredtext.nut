from "%enlSqGlob/ui/ui_library.nut" import *

let {fontHeading2} = require("%enlSqGlob/ui/fontsStyle.nut")
function centeredText(text, options={}) {
  return {
    rendObj = ROBJ_TEXT
    text
    key = options?.key ?? text

    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
  }.__update(fontHeading2)
}


return centeredText
