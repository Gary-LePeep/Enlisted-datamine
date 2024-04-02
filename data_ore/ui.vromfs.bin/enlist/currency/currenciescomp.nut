from "%enlSqGlob/ui/ui_library.nut" import *

let { fontSub, fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let textButtonTextCtor = require("%ui/components/textButtonTextCtor.nut")
let { TextHover, TextNormal } = require("%ui/components/textButton.style.nut")
let { Purchase } = require("%ui/components/textButton.nut")
let { currenciesExpiring, currenciesById, currenciesBalance
} = require("%enlist/currency/currencies.nut")
let tooltipBox = require("%ui/style/tooltipBox.nut")
let serverTime = require("%enlSqGlob/userstats/serverTime.nut")
let { secondsToHoursLoc } = require("%ui/helpers/time.nut")
let mkTextRow = require("%darg/helpers/mkTextRow.nut")
let {
  mkCurrencyTooltipContainer, mkDefaultTooltipText, mkCurrencyCardsTooltip
} = require("%enlist/shop/currencyComp.nut")
let {
  smallPadding, midPadding, defTxtColor, titleTxtColor, positiveTxtColor
} = require("%enlSqGlob/ui/designConst.nut")
let { abbreviateAmount } = require("%enlist/shop/numberUtils.nut")
let { currencyPresentation } = require("%enlist/shop/currencyPresentation.nut")


let CURRENCY_PARAMS = {
  iconSize = hdpxi(16)
  txtStyle = { color = titleTxtColor }
  dimStyle = { color = defTxtColor }.__update(fontSub)
  discountStyle = { color = positiveTxtColor }
}


let currencyById = @(currencyId) currenciesById.value?[currencyId]

let oldPriceLine = {
  size = flex()
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = hdpx(1)
  commands = [[ VECTOR_LINE, -5, 50, 105, 50 ]]
}

let mkCurrencyImg = @(currency, iconSize) {
  size = [iconSize, iconSize]
  rendObj = ROBJ_IMAGE
  image = Picture(currency.image(iconSize))
}

let mkCurrencyCount = @(count, txtStyle = null) {
  rendObj = ROBJ_TEXT
  text = abbreviateAmount(count)
}.__update(fontBody, txtStyle ?? CURRENCY_PARAMS.txtStyle)

let mkCurrencyStroke = @(count, txtStyle = null) {
  children = [
    mkCurrencyCount(count, txtStyle)
    oldPriceLine.__merge(txtStyle ?? CURRENCY_PARAMS.txtStyle)
  ]
}

let mkCurrency = kwarg(
  function(currency, price, fullPrice = null, iconSize = null,
    txtStyle = null, discountStyle = null, dimStyle = null,
    objectsGap = smallPadding
  ) {
    let hasPrice = price != null
    let hasDiscount = (fullPrice ?? 0) > price && (price ?? 0) >= 0
    let countStyle = hasDiscount
      ? (discountStyle ?? CURRENCY_PARAMS.discountStyle)
      : (txtStyle ?? CURRENCY_PARAMS.txtStyle)
    return {
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      gap = midPadding
      children = [
        {
          flow = FLOW_HORIZONTAL
          valign = ALIGN_CENTER
          gap = objectsGap
          children = [
            mkCurrencyImg(currency, iconSize ?? CURRENCY_PARAMS.iconSize)
            hasPrice
              ? mkCurrencyCount(price, countStyle)
              : mkDefaultTooltipText(loc("currency/notAvailable"))
          ]
        }
        hasPrice && hasDiscount
          ? mkCurrencyStroke(fullPrice, dimStyle ?? CURRENCY_PARAMS.dimStyle)
          : null
      ]
    }

  })

function currencyBtn(
  btnText, currencyId, price = null, priceFull = null, cb = @() null,
  style = {}, txtColor = TextNormal, txtHoverColor = TextHover,
  discountStyle = null
) {
  let hasPrice = !("" == (price ?? ""))
  let hasPriceFull = !("" == (priceFull ?? ""))
  return Purchase(btnText, cb, style.__merge({
    textCtor = @(textField, params, handler, group, sf) textButtonTextCtor({
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      margin = textField?.margin
      gap = smallPadding
      children = [
        textField.__merge({
          margin = [0, hdpx(10), 0, 0]
          color = sf & S_HOVER ? txtHoverColor : txtColor
        })
        mkCurrencyImg(currencyById(currencyId), hdpxi(30))
        hasPrice
          ? mkCurrencyCount(price, hasPriceFull
              ? discountStyle ?? CURRENCY_PARAMS.discountStyle
              : { color = sf & S_HOVER ? txtHoverColor : txtColor })
          : null
        hasPrice && hasPriceFull
          ? mkCurrencyStroke(priceFull, { color = sf & S_HOVER ? txtHoverColor : txtColor })
          : null
      ]
    }, params, handler, group, sf)
  }))
}

function mkExpireRow(expData, currency) {
  let { expireAt, amount } = expData
  let timeText = Computed(function() {
    let timeLeft = expireAt - serverTime.value
    return timeLeft > 0 ? secondsToHoursLoc(timeLeft) : loc("expired")
  })

  let replaceList = {
    ["{amount}"] = [ //warning disable: -forgot-subst
      mkCurrencyImg(currency, hdpxi(20))
      mkDefaultTooltipText(amount)
    ],
    ["{time}"] = @() mkDefaultTooltipText(timeText.value).__update({watch = timeText}) //warning disable: -forgot-subst
  }
  return {
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    children = mkTextRow(loc("currency/expireAt"), mkDefaultTooltipText, replaceList)
  }
}

let mkCurrencyTooltip = @(currency) function() {
  let exp = currenciesExpiring.value?[currency.id]
  if (exp == null) {
    let presentation = currencyPresentation?[currency.id]
    if (presentation)
      return mkCurrencyCardsTooltip(currency.id,
        [{
          amount = currenciesBalance.value?[currency.id]
          icon = presentation.icon
        }]
      )

    return mkCurrencyTooltipContainer(
      loc(currency?.locId),
      loc(currency?.descLocId)
    )
  }

  return tooltipBox({
    flow = FLOW_VERTICAL
    children = exp.sort(@(a, b) a.expireAt <=> b.expireAt)
      .map(@(e) mkExpireRow(e, currency))
  })
}

return {
  mkCurrency
  currencyBtn = kwarg(currencyBtn)
  mkCurrencyImg
  mkCurrencyCount
  mkCurrencyTooltip
  oldPriceLine
}
