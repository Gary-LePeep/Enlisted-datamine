from "%enlSqGlob/ui/ui_library.nut" import *

let { mkSquadCard } = require("%enlSqGlob/ui/squadsUiComps.nut")
let { bigPadding } = require("%enlSqGlob/ui/viewConst.nut")
let { makeVertScroll, thinStyle } = require("%ui/components/scrollbar.nut")

let defSquadCardCtor = @(squad, idx) mkSquadCard({idx}.__update(squad), KWARG_NON_STRICT)

let mkSquadsVert = @(squads) {
  flow = FLOW_VERTICAL
  gap = bigPadding
  children = squads.map(defSquadCardCtor)
}

let mkSquadsList = kwarg(@(
  curSquadsList, curSquadId, setCurSquadId, addedObj = null,
  createHandlers = null, topElement = null, hasOffset = true
) function() {
  let squadsList = curSquadsList.value ?? []
  function defCreateHandlers(squads){
    squads.each(@(squad)
      squad.__update({
        onClick = @() setCurSquadId(squad.squadId)
        isSelected = Computed(@() curSquadId.value == squad.squadId)
      })
    )
  }
  createHandlers = createHandlers ?? defCreateHandlers
  createHandlers(squadsList)
  local children = []
  if (squadsList.len() > 0) {
    let listComp = mkSquadsVert(squadsList)
    let maxHeight = hasOffset ? null : calc_comp_size(listComp)[1]
    children = [
      topElement
      makeVertScroll(listComp, {
        size = [SIZE_TO_CONTENT, flex()]
        styling = thinStyle
        maxHeight
      })
      addedObj
    ]
  }
  return {
    watch = [curSquadsList, curSquadId]
    size = [SIZE_TO_CONTENT, flex()]
    flow = FLOW_VERTICAL
    gap = bigPadding
    clipChildren = true
    xmbNode = XmbContainer({ wrap = false })
    children
  }
})

return mkSquadsList
