import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui/ui_library.nut" import *
from "math" import min

let { fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let { isGamepad } = require("%ui/control/active_controls.nut")
let style = require("%ui/hud/style.nut")
let {inPlane} = require("%ui/hud/state/vehicle_state.nut")
let {planeSeatNext} = require("%ui/hud/state/plane_hud_state.nut")
let { watchedHeroSquadMembers } = require("%ui/hud/state/squad_members.nut")
let vehicleSeatsState = require("%ui/hud/state/vehicle_seats.nut")
let { watchedHeroEid } = require("%ui/hud/state/watched_hero.nut")
let {controlHudHint} = require("%ui/components/controlHudHint.nut")
let getFramedNickByEid = require("%ui/hud/state/getFramedNickByEid.nut")

let NORMAL_HINT_SIZE = [hdpx(20), fontH(100)]
let GAMEPAD_HINT_SIZE = [hdpx(36), fontH(120)]

let colorBlue = Color(150, 160, 255, 180)
let maxSeatsCountToShow = 10

let memberTextColor = @(member) (member.eid == watchedHeroEid.value) ? style.SUCCESS_TEXT_COLOR
  : member.isAlive ? style.DEFAULT_TEXT_COLOR
  : style.DEAD_TEXT_COLOR

function seatMember(seatDesc) {
  let { owner, seat, order } = seatDesc
  let locName = seat?.locName ?? (seat?.name ? $"vehicle_seats/{seat.name}" : null)
  let member = watchedHeroSquadMembers.value.findvalue(@(v) v.eid == owner.eid)
  local name = member?.name
  local color = member?.eid ? memberTextColor(member) : style.DEFAULT_TEXT_COLOR
  if (member == null) {
    if (owner.isPlayer)
      name = getFramedNickByEid(owner.player) ?? getFramedNickByEid(owner.eid)
    else if (owner.eid != ecs.INVALID_ENTITY_ID)
      name = ecs.obsolete_dbg_get_comp_val(owner.eid, "name") ?? "<Unknown>"
    if (name != null)
      color = colorBlue
  }
  let place = locName ? $"[{loc(locName)}]: " : ""
  name = name ?? (order.canPlaceManually ? loc("vehicle_seats/free_seat") : "...")
  return {
    rendObj = ROBJ_TEXT
    text = $"{place}{name}"
    color
  }.__update(fontSub)
}

let seatHint = function(seat, isGpad) {
  let size = isGpad ? GAMEPAD_HINT_SIZE : NORMAL_HINT_SIZE
  return seat.order.canPlaceManually
    ? controlHudHint({
        id = (inPlane.value && isGpad) ?
              planeSeatNext.value == seat.order.seatNo ?
              $"Plane.SeatNext" : "" : seat.order.seatNo < 9 ?
              $"Human.Seat0{seat.order.seatNo + 1}" : $"Human.Seat{seat.order.seatNo + 1}"
        size
        hplace = ALIGN_RIGHT
        text_params = fontSub
      })
    : {
        size = [size[0], SIZE_TO_CONTENT]
      }
}

let mkSeat = @(seat, isGpad) {
    rendObj = ROBJ_WORLD_BLUR
    flow = FLOW_HORIZONTAL
    padding = [hdpx(5), hdpx(2)]
    gap = hdpx(5)
    children = [
      seatHint(seat, isGpad)
      seatMember(seat)
    ]
    color = Color(220, 220, 220, 220)
  }
let hasVehicleSeats = Computed(@() vehicleSeatsState.value.data.len() > 0)

function vehicleSeats() {
  let res = {
    watch = [hasVehicleSeats, watchedHeroSquadMembers, vehicleSeatsState, watchedHeroEid, isGamepad, inPlane, planeSeatNext]
  }
  if (!hasVehicleSeats.value)
    return res

  let seatsToShow = min(vehicleSeatsState.value.data.len(), maxSeatsCountToShow)
    return res.__update({
    flow = FLOW_VERTICAL
    size = [flex(), SIZE_TO_CONTENT]
    hplace = ALIGN_RIGHT
    padding = fsh(1)
    gap = hdpx(2)
    children = vehicleSeatsState.value.data.slice(0, seatsToShow).map(@(seat) mkSeat(seat, isGamepad.value))
  })
}

return vehicleSeats