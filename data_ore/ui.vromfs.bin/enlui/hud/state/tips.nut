from "%enlSqGlob/ui/ui_library.nut" import *

let tips = {value = null}

let tipsGen = Watched(0)
let getTips = @() tips.value
function setTips(newTips){
  tips.value = newTips
  tipsGen(tipsGen.value+1)
}
return {
  setTips,getTips, tipsGen
}