from "%enlSqGlob/ui/ui_library.nut" import *

let { mkSquadCard } = require("%enlSqGlob/ui/squadsUiComps.nut")
let { midPadding } = require("%enlSqGlob/ui/designConst.nut")
let { makeVertScroll, thinStyle } = require("%ui/components/scrollbar.nut")

let defSquadCardCtor = @(squad, idx) mkSquadCard({idx}.__update(squad), KWARG_NON_STRICT)

let mkSquadsVert = @(squads) {
  flow = FLOW_VERTICAL
  gap = midPadding
  children = squads.map(defSquadCardCtor)
}

let mkSquadsList = kwarg(@(
  curSquadsList, curSquadId, setCurSquadId, addedObj = null,
  createHandlers = null, topElement = null, hasOffset = true, onDoubleClick = null
) function() {
  let squadsList = curSquadsList.value ?? []
  function defCreateHandlers(squads){
    squads.each(@(squad)
      squad.__update({
        onClick = @() setCurSquadId(squad.squadId)
        onDoubleClick
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
    gap = midPadding
    clipChildren = true
    xmbNode = XmbContainer({ wrap = false })
    children
  }
})

return mkSquadsList
