from "%enlSqGlob/ui/ui_library.nut" import *

let { fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let { abbreviateAmount } = require("%enlist/shop/numberUtils.nut")
let { mkCurrencyOverall, mkCurrencyImage } = require("currencyComp.nut")
let { setCurSection, curSection } = require("%enlist/mainMenu/sectionsState.nut")
let { txt } = require("%enlSqGlob/ui/defcomps.nut")
let { viewArmyCurrency, realCurrencies, viewCurrencies, isItemsShopOpened
} = require("armyShopState.nut")
let { currencyPresentation, ticketGroups, getCurrencyPresentation
} = require("currencyPresentation.nut")
let { setAutoGroup } = require("%enlist/shop/shopState.nut")
let { curGrowthFreeExp } = require("%enlist/growth/growthState.nut")
let { bigPadding, warningColor, bonusColor, defTxtColor } = require("%enlSqGlob/ui/viewConst.nut")


let isInShop = Computed(@() curSection.value == "SHOP" || isItemsShopOpened.value)
let isInGrowth = Computed(@() curSection.value == "GROWTH")

let ADDING_ORDER_SIZE = [hdpx(20), hdpx(20)]
let SILVER_KEY = "enlisted_silver"

let freeExpIconSize = [hdpxi(30), hdpxi(30)]

let mkExpIcon = @(size) {
  rendObj = ROBJ_IMAGE
  size = size
  image = Picture("!ui/uiskin/research/experience_points_icon.svg:{0}:{1}:K"
    .subst(size[0], size[1]))
}


function filterCurrencies(tbl) {
  let res = clone tbl
  res.$rawdelete(SILVER_KEY)
  return res
}

let filterCurrenciesSilver = @(tbl) { [SILVER_KEY] = tbl[SILVER_KEY] }

local diffAnimCounter = 0
function mkDiffCurrency(curr, idx, onFinish) {
  let delay = idx * 0.6
  let duration = 1
  let isPositive = curr.count > 0
  return {
    key = $"{curr.currTpl}_{diffAnimCounter}"
    pos = [pw(curr.offset), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    opacity = 0
    children = [
      txt({
        text = isPositive ? $"+{curr.count}" : $"{curr.count}"
        color = isPositive ? bonusColor : warningColor
      })
      mkCurrencyImage(getCurrencyPresentation(curr.currTpl).icon, ADDING_ORDER_SIZE)
    ]
    transform = {}
    animations = [
      { prop = AnimProp.opacity, from = 0.2, to = 1, duration = 0.4,
        play = true, easing = InOutCubic, delay }
      { prop = AnimProp.opacity, from = 1, to = 1, duration = 0.4,
        play = true, easing = InOutCubic, delay = delay + 0.4, onFinish }
      { prop = AnimProp.opacity, from = 1, to = 0.2, duration = 0.2,
        play = true, easing = InOutCubic, delay = delay + 0.8 }
      { prop = AnimProp.translate, from = [0,hdpx(60)], to = [0,0],
        play = true, easing = OutQuart, duration, delay }
    ]
  }
}

function getSortedCards(armyCurrency, currencyPresentationList) {
  let sortedCards = []
  ticketGroups.map(function(groupContent, groupName) {
    let showInCurrentSection = groupContent?.showInSection.contains(curSection.value) ?? true
    if (showInCurrentSection){
      let cardsTable = {
        groupOrder = groupContent.order
        cards = {}
        type = groupName
        showIfZero = groupContent.isShownIfEmpty
        isInteractive = groupContent.isInteractive
      }
      currencyPresentationList.each(function(value, key) {
        let { group = null } = value
        if (group == groupContent) {
          armyCurrency.each(function(val, k) {
            if (key == k)
              cardsTable.cards[k] <- val
          })
          if (key not in cardsTable.cards && !(value?.hideIfZero ?? false))
            cardsTable.cards[key] <- 0
        }
      })
      if (cardsTable.cards.findindex(@(v) v > 0) != null || cardsTable.showIfZero)
        sortedCards.append(cardsTable)
    }
  })

  return sortedCards.sort(@(a,b) a.groupOrder <=> b.groupOrder)
}

function mkCurrenciesDiffAnim(realCurr, sectionCurr, viewCurrWatch, currencyPresentationList) {
  let viewCurr = viewCurrWatch.value ?? {}
  if (isEqual(realCurr, viewCurr))
    return null

  let sortedCards = getSortedCards(sectionCurr, currencyPresentationList)
  let diff = []
  foreach (currTpl, count in realCurr) {
    if (currTpl in currencyPresentationList) {
      let viewCount = viewCurr?[currTpl] ?? 0
      if (currTpl not in sectionCurr)
        viewCurr[currTpl] <- count
      else if (viewCount != count) {
        let orderNumber = sortedCards.findindex(@(v) currTpl in v.cards) ?? 0
        diff.append({
          currTpl
          count = count - viewCount
          offset = sortedCards.len() == 0 ? 0 : 100 * orderNumber / sortedCards.len() + 10
        })
      }
    }
  }
  viewCurrWatch(viewCurr)

  if (diff.len() == 0)
    return null

  diff.sort(@(a, b) a.offset <=> b.offset)
  diffAnimCounter++
  return diff.map(@(curr, idx) mkDiffCurrency(curr, idx, @()
    viewCurrWatch.mutate(@(v) v[curr.currTpl] <- realCurr?[curr.currTpl] ?? 0)
  ))
}

function addClickAutoShop(value, isShop) {
  function openShop() {
    setAutoGroup(value.type)
    setCurSection("SHOP")
  }
  return mkCurrencyOverall(
    value.type,
    value.cards,
    value.isInteractive && !isShop ? openShop : null,
    value,
    isShop)
}

let mkArmyCurrency = @(armyCurrency, currencyPresentationList, isShop)
  getSortedCards(armyCurrency, currencyPresentationList).map(@(v) addClickAutoShop(v, isShop))

let sectionCurrency = Computed(function() {
  let currencies = viewCurrencies.value
  let armyCurrency = viewArmyCurrency.value
  let curSectionId = curSection.value
  return armyCurrency.__merge(currencyPresentation
    .filter(@(c, key) ((c?.isAlwaysVisible ?? false) || curSectionId in c?.sections)
      && key not in armyCurrency)
    .map(@(_, key) currencies?[key] ?? 0))
})

let mkCurrencyUi = @(currencyWatch, filter = @(v) v) {
  size = [SIZE_TO_CONTENT, flex()]
  minHeight = SIZE_TO_CONTENT
  children = [
    @() {
      watch = [currencyWatch, isInShop]
      size = [SIZE_TO_CONTENT, flex()]
      minHeight = SIZE_TO_CONTENT
      flow = FLOW_HORIZONTAL
      halign = ALIGN_RIGHT
      gap = bigPadding
      children = mkArmyCurrency(
        currencyWatch.value,
        filter(currencyPresentation),
        isInShop.value
      )
    }
    @() {
      // I deliberately didn't subscribe to <sectionCurrency> and <viewCurrencies>
      // this block should be updated only after <realCurrencies> change
      watch = realCurrencies
      size = flex()
      valign = ALIGN_CENTER
      children = mkCurrenciesDiffAnim(
        realCurrencies.value,
        currencyWatch.value,
        viewCurrencies,
        filter(currencyPresentation)
      )
    }
  ]
}

let freeExpUi = @() {
  watch = [isInGrowth, curGrowthFreeExp]
  children = !isInGrowth.value ? null
    : {
        flow = FLOW_HORIZONTAL
        valign = ALIGN_CENTER
        gap = bigPadding
        children = [
          mkExpIcon(freeExpIconSize)
          {
            rendObj = ROBJ_TEXT
            color = defTxtColor
            text = abbreviateAmount(curGrowthFreeExp.value)
          }.__update(fontBody)
        ]
      }
}

return {
  currencyUi = mkCurrencyUi(sectionCurrency, filterCurrencies)
  currencySilverUi = mkCurrencyUi(sectionCurrency, filterCurrenciesSilver)
  freeExpUi
  mkExpIcon
}
