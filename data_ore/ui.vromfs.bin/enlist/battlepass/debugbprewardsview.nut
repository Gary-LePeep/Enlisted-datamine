from "%enlSqGlob/ui_library.nut" import *

let {addModalWindow, removeModalWindow} = require("%ui/components/modalWindows.nut")
let { mkRewardImages, mkRewardTooltip } = require("rewardsPkg.nut")
let { rewardBgSizePx } = require("%enlist/items/itemsPresentation.nut")
let itemsMapping = require("%enlist/items/itemsMapping.nut")
let { arrayByRows } = require("%sqstd/underscore.nut")
let { makeVertScroll } = require("%ui/components/scrollbar.nut")
let { withTooltip } = require("%ui/style/cursors.nut")

const WND_UID = "debugRewardsView"
let isOpened = mkWatched(persist, "isOpened", false)
let gap = 20

let function rewardsContent() {
  let all = itemsMapping.value.reduce(@(res, reward, id) res.append({ id, reward }), [])
  all.sort(@(a, b) a.id <=> b.id)
  let columns = (sw(95) / (rewardBgSizePx[0] + gap)).tointeger()
  return makeVertScroll({
    watch = itemsMapping
    padding = gap
    gap
    flow = FLOW_VERTICAL
    hplace = ALIGN_CENTER
    children = arrayByRows(all, columns).map(@(row) {
      gap
      flow = FLOW_HORIZONTAL
      children = row.map(@(data) {
        children = [
          withTooltip(mkRewardImages(data.reward, rewardBgSizePx), @() mkRewardTooltip(data.reward))
          {
            rendObj = ROBJ_TEXT
            text = data.id
            vplace = ALIGN_BOTTOM
          }
        ]
      })
    })
  },
  {
    size = [flex(), SIZE_TO_CONTENT]
    maxHeight = sh(100)
  })
}

let open = @() addModalWindow({
  key = WND_UID
  rendObj = ROBJ_SOLID
  color = 0xFF000000
  valign = ALIGN_CENTER
  children = rewardsContent
  onClick = @() isOpened(false)
})

if (isOpened.value)
  open()
isOpened.subscribe(@(v) v ? open() : removeModalWindow(WND_UID))

console_register_command(@() isOpened(!isOpened.value), "debug.unlockRewardsView")
