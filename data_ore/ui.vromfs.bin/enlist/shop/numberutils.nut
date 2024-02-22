from "%enlSqGlob/ui/ui_library.nut" import *
let { splitThousands } = require("%sqstd/math.nut")

let separator = loc("amount/separator")

function abbreviateAmount(amount) {
  if (type(amount) != "integer")
    return amount

  if (amount >= 100_000_000)
    return loc("amount/short/m", { number = splitThousands(amount / 1_000_000, separator) })
  else if (amount >= 100_000)
    return loc("amount/short/k", { number = splitThousands(amount / 1_000, separator) })
  else
    return splitThousands(amount, separator)
}

return {
    abbreviateAmount
}
