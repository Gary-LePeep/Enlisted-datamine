from "%enlSqGlob/ui/ui_library.nut" import *

function textarea(text) {
  return {
    rendObj = ROBJ_TEXTAREA
    size = [sw(35), SIZE_TO_CONTENT]
    behavior = Behaviors.TextArea
    text
    margin = [0,0,fsh(2),0]
  }
}



return {
  textarea
}