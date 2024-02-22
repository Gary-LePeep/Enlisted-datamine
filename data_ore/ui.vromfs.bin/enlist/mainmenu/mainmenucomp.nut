from "%enlSqGlob/ui/ui_library.nut" import *

let mainMenuComp = {value = null}
let getMainMenuComp = @() mainMenuComp.value
let mainMenuVersion = Watched(0)

function setMainMenuComp(comp) {
  mainMenuComp.value <- comp
  mainMenuVersion(mainMenuVersion.value+1)
}
return {
  getMainMenuComp, setMainMenuComp, mainMenuVersion
}