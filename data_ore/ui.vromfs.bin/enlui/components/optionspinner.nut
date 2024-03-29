from "%enlSqGlob/ui/ui_library.nut" import *

let spinnerList = require("spinnerList.nut")

let locOn = loc($"option/on")
let locOff = loc($"option/off")
function optionSpinner(opt, group, xmbNode) {
  let stateFlags = Watched(0)
  let available = opt?.available instanceof Watched
    ? opt.available
    : Watched(opt?.available)
  let spinnerElem = @(){
    size = flex()
    watch = available
    children = spinnerList({
      isEqual = opt?.isEqual
      setValue = opt?.setValue
      curValue = opt.var
      valToString = opt?.valToString ?? @(val) val ? locOn : locOff
      allValues = available.value
      xmbNode
      group
      stateFlags
    })
  }
  return spinnerElem
}

return optionSpinner