from "%enlSqGlob/ui/ui_library.nut" import *

let { defTxtColor, brightAccentColor } = require("%enlSqGlob/ui/designConst.nut")
let { getRomanNumeral } = require("%sqstd/math.nut")
let colorize = require("%ui/components/colorize.nut")

let mkBattleRating = @(tier, override = {}) tier < 1 ? null : {
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  color = defTxtColor
  text = loc("battleRating", { tier = colorize(brightAccentColor, getRomanNumeral(tier)) })
}.__update(override)

let mkBattleRatingShort = @(tier) {
  rendObj = ROBJ_TEXT
  color = brightAccentColor
  text = loc("battleRating/short", { tier = getRomanNumeral(tier) })
}

return {
  mkBattleRating
  mkBattleRatingShort
}
