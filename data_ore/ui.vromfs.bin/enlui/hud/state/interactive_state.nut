from "%enlSqGlob/ui/ui_library.nut" import *

let interactiveElements = mkWatched(persist, "interactiveElements", {})

function addInteractiveElement(id) {
  if (!(id in interactiveElements.value))
    interactiveElements.mutate(@(v) v[id] <- true)
}

function removeInteractiveElement(id) {
  if (id in interactiveElements.value)
    interactiveElements.mutate(@(v) v.$rawdelete(id))
}

function setInteractiveElement(id, val){
  if (val)
    addInteractiveElement(id)
  else
    removeInteractiveElement(id)
}

function switchInteractiveElement(id) {
  interactiveElements.mutate(function(v) {
    if (id in v)
      v.$rawdelete(id)
    else
      v[id] <- true
  })
}

let hudIsInteractive = Computed(@() interactiveElements.get().len() > 0)

return {
  interactiveElements
  removeInteractiveElement
  addInteractiveElement
  switchInteractiveElement
  setInteractiveElement
  hudIsInteractive
}

