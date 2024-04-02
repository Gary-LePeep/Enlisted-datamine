from "%enlSqGlob/ui/ui_library.nut" import *

let JB = require("%ui/control/gui_buttons.nut")
let buySquadWindow = require("%enlist/shop/buySquadWindow.nut")
let buyShopItem = require("buyShopItem.nut")

let { fontSub, fontBody } = require("%enlSqGlob/ui/fontsStyle.nut")
let { utf8ToUpper } = require("%sqstd/string.nut")
let { sceneWithCameraAdd, sceneWithCameraRemove } = require("%enlist/sceneWithCamera.nut")
let { squadsCfgById } = require("%enlist/soldiers/model/config/squadsConfig.nut")
let { campaignsByArmy } = require("%enlist/meta/profile.nut")
let { mkProductView } = require("%enlist/shop/shopPkg.nut")
let { allItemTemplates } = require("%enlist/soldiers/model/all_items_templates.nut")
let { premiumImage } = require("%enlist/currency/premiumComp.nut")
let { mkPortraitIcon, mkNickFrame } = require("%enlist/profile/decoratorPkg.nut")
let { mkCurrency } = require("%enlist/currency/currenciesComp.nut")
let { enlistedGold } = require("%enlist/currency/currenciesList.nut")
let { shopSquadsCompensations, shopDecorsCompensations } = require("shopItems.nut")
let { Bordered, Purchase } = require("%ui/components/textButton.nut")
let { squadsByArmy } = require("%enlist/soldiers/model/state.nut")
let { availPortraits, availNickFrames } = require("%enlist/profile/decoratorState.nut")
let { openUnlockSquadScene } = require("%enlist/soldiers/unlockSquadScene.nut")
let {
  isPortrait, isFrameNick, getPortrait, decoratorsPresentation
} = require("%enlSqGlob/ui/decoratorsPresentation.nut")
let {
  smallPadding, midPadding, activeTxtColor, textBgBlurColor, accentTitleTxtColor
} = require("%enlSqGlob/ui/designConst.nut")


let goodNameTxtStyle = { color = activeTxtColor }.__update(fontBody)
let goodValueTxtStyle = { color = accentTitleTxtColor }.__update(fontBody)


let compositeParams = mkWatched(persist, "compositeParams")

let open = @(params) compositeParams(params)
let close = @() compositeParams(null)


let verticalRightGradient = {
  rendObj = ROBJ_IMAGE
  hplace = ALIGN_RIGHT
  size = [pw(45), flex()]
  color = Color(0,0,0)
  image = Picture("!ui/uiskin/R_BG_gradient_vert.svg:{500}:{4}:K?Ac")
}


let mkText = @(text, override = {}) {
  rendObj = ROBJ_TEXT
  text
}.__update(fontSub, override)


let mkTextArea = @(text, override = {}) {
  rendObj = ROBJ_TEXTAREA
  size = [flex(), SIZE_TO_CONTENT]
  behavior = Behaviors.TextArea
  text = text
}.__update(fontSub, override)


let crossOutLine = {
  size = flex()
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = hdpx(2)
  commands = [[ VECTOR_LINE, 1, 60, 99, 60 ]]
}


let mkGoldCompensation = @(count, override = {}) count == 0 ? null
  : {
      flow = FLOW_HORIZONTAL
      gap = midPadding
      valign = ALIGN_CENTER
      children = mkCurrency({
        currency = enlistedGold
        price = count
        txtStyle = { color = accentTitleTxtColor }.__update(fontSub)
      })
    }.__update(override)

function mkSquadsBlockUi(squads, shopItem) {
  return function() {
    let campaigns = campaignsByArmy.value
    let squadsCfg = squadsCfgById.value
    let compensations = shopSquadsCompensations.value
    let armySquads = squadsByArmy.value
    let squadsObjList = squads.map(function(squad) {
      let { armyId, id } = squad
      let squadCfg = squadsCfg?[armyId][id]
      if (squadCfg == null)
        return null

      let campaign = loc(campaigns?[armyId].title ?? "")
      let name = loc(squadCfg.nameLocId)
      let isOwned = (armySquads?[armyId] ?? []).findvalue(@(s) s.squadId == id) != null
      return watchElemState(@(sf) {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        gap = midPadding
        padding = smallPadding
        valign = ALIGN_CENTER
        behavior = Behaviors.Button
        function onClick() {
          if (isOwned)
            openUnlockSquadScene({ armyId, squad, squadCfg, unlockInfo = null })
          else
            buySquadWindow({
              shopItem
              productView = mkProductView(shopItem, allItemTemplates)
              armyId
              squadId = id
              isBuyDisabled = true
            })
        }
        children = [
          {
            children = [
              mkText(loc("listWithDot", { text = $"{campaign} {name}" }), goodNameTxtStyle)
              isOwned ? crossOutLine : null
            ]
          }
          isOwned ? mkGoldCompensation(compensations?[id]) : null
          mkText(loc("btn/view"), sf & S_HOVER ? goodValueTxtStyle : goodNameTxtStyle)
        ]
      })
    })

    let headerText = utf8ToUpper(loc("shop/receiveSquadsHeader", { count = squads.len() }))
    return {
      watch = [campaignsByArmy, squadsByArmy, squadsCfgById, shopSquadsCompensations]
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      padding = smallPadding
      children = [mkText(headerText, goodNameTxtStyle)]
        .extend(squadsObjList)
    }
  }
}


function mkAnnouncement(announcement) {
  if (announcement.announcementId == "EnlistedGold")
    return mkCurrency({
      currency = enlistedGold
      price = announcement.count
      txtStyle = { color = accentTitleTxtColor }
      iconSize = hdpxi(36)
      objectsGap = midPadding
    })
  return null
}


function mkAnnouncementsBlockUi(announcements) {
  if (announcements.len() == 0)
    return null

  return {
    flow = FLOW_VERTICAL
    gap = midPadding
    margin = midPadding
    children = announcements.map(mkAnnouncement)
  }
}


function mkPremiumBlockUi(premiumDays) {
  if (premiumDays == 0)
    return null

  return {
    flow = FLOW_HORIZONTAL
    gap = midPadding
    valign = ALIGN_CENTER
    children = [
      premiumImage(hdpxi(60), { color = textBgBlurColor })
      {
        flow = FLOW_VERTICAL
        children = [
          mkText(utf8ToUpper(loc("premium/title")), goodNameTxtStyle)
          mkText(loc("shop/addGoodWithCount", {
            count = premiumDays
            goodText = loc("premiumDays", { days = premiumDays })
          }), goodValueTxtStyle)
        ]
      }
    ]
  }
}


let receivedTextObj = {
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  children = mkText(loc("squads/received"), { color = activeTxtColor })
}

function mkDecoratorsBlockUi(decorators) {
  if (decorators.len() == 0)
    return null

  return function() {
    let compensations = shopDecorsCompensations.value
    let portraits = availPortraits.value
    let nickFrames = availNickFrames.value
    let children = decorators.map(function(decorator) {
      let { guid } = decorator
      let { nickFrame = {} } = decoratorsPresentation
      if (isPortrait(guid)) {
        let isOwned = guid in portraits
        return {
          children = [
            {
              children = mkPortraitIcon(getPortrait(guid), hdpx(140))
              opacity = isOwned ? 0.3 : 1
            }
            isOwned
              ? {
                  size = flex()
                  halign = ALIGN_CENTER
                  valign = ALIGN_BOTTOM
                  children = [
                    receivedTextObj
                    mkGoldCompensation(compensations?[guid] ?? 0, { margin = midPadding })
                  ]
                }
              : null
          ]
        }
      }
      else if (isFrameNick(guid)) {
        let isOwned = guid in nickFrames
        return {
          children = [
            {
              children = mkNickFrame(nickFrame[guid])
              opacity = isOwned ? 0.3 : 1
            }
            isOwned
              ? {
                  size = flex()
                  halign = ALIGN_CENTER
                  valign = ALIGN_BOTTOM
                  children = [
                    receivedTextObj
                    mkGoldCompensation(compensations?[guid] ?? 0, { margin = midPadding })
                  ]
                }
              : null
          ]
        }
      }
      return null
    })
    return {
      watch = [shopDecorsCompensations, availPortraits, availNickFrames]
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      gap = smallPadding
      children = [
        mkText(loc("shop/receiveDecoratorsHeader"), goodNameTxtStyle)
        {
          size = [flex(), SIZE_TO_CONTENT]
          children = wrap(children, {
            width = sh(50)
            hGap = midPadding
            vGap = midPadding
          })
        }
      ]
    }
  }
}


let mkPurchaseBtn = @(shopItem) Purchase(loc("shop/purchase"),
  @() buyShopItem({
    shopItem
    productView = mkProductView(shopItem, allItemTemplates)
  }),
  { margin = 0, hotkeys = [[ "^J:Y", { description = { skip = true }} ]] }
)


function mkCompensationText(shopItem) {
  let { squads = [], decorators = [] } = shopItem
  return function() {
    let squadCompensations = shopSquadsCompensations.value
    let decorCompensations = shopDecorsCompensations.value
    let armySquads = squadsByArmy.value
    let portraits = availPortraits.value
    let nickFrames = availNickFrames.value

    local hasText = squads.findvalue(function(squad) {
      let { armyId, id } = squad
      return (armySquads?[armyId] ?? []).findvalue(@(s) s.squadId == id) != null
        && (squadCompensations?[id] ?? 0) > 0
    }) != null
    if (!hasText)
      hasText = hasText || decorators.findvalue(function(decorator) {
        let { guid } = decorator
        if (isPortrait(guid))
          return guid in portraits && (decorCompensations?[guid] ?? 0) > 0
        else if (isFrameNick(guid))
          return guid in nickFrames && (decorCompensations?[guid] ?? 0) > 0
        return false
      }) != null

    return {
      watch = [
        shopSquadsCompensations, shopDecorsCompensations, squadsByArmy,
        availPortraits, availNickFrames
      ]
      size = [flex(), SIZE_TO_CONTENT]
      children = hasText
        ? mkTextArea(loc("shop/goodCompensationText"), {
            margin = [midPadding, smallPadding]
          }.__update(goodNameTxtStyle))
        : null
    }
  }
}


function mkRightBlockUi(shopItem) {
  let { squads = [], decorators = [], announcements = [], premiumDays = 0 } = shopItem
  let announcementsBlockUi = mkAnnouncementsBlockUi(announcements)
  let premiumBlockUi = mkPremiumBlockUi(premiumDays)
  let decoratorsBlockUi = mkDecoratorsBlockUi(decorators)
  let squadsBlockUi = mkSquadsBlockUi(squads, shopItem)
  return {
    size = [sh(55), flex()]
    padding = midPadding
    hplace = ALIGN_RIGHT
    children = [
      {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_VERTICAL
        gap = sh(2)
        vplace = ALIGN_CENTER
        children = [
          mkText(loc("shop/receiveHeader"), goodNameTxtStyle)
          announcementsBlockUi
          premiumBlockUi
          decoratorsBlockUi
          squadsBlockUi
          mkCompensationText(shopItem)
        ]
      }
      {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        gap = midPadding
        padding = [sh(3), sh(1)]
        vplace = ALIGN_BOTTOM
        children = [
          mkPurchaseBtn(shopItem)
          Bordered(loc("mainmenu/btnBack"), close,
            { margin = 0, hotkeys = [[$"^{JB.B} | Esc", { description = { skip = true }}]] })
        ]
      }
    ]
  }
}


function buySquadWnd() {
  let { shopItem } = compositeParams.value
  return {
    watch = compositeParams
    size = flex()
    children = [
      {
        rendObj = ROBJ_IMAGE
        size = flex()
        keepAspect = KEEP_ASPECT_FILL
        imageHalign = ALIGN_RIGHT
        imageValign = ALIGN_TOP
        image = Picture(shopItem.image)
      }
      verticalRightGradient
      mkRightBlockUi(shopItem)
    ]
  }
}


compositeParams.subscribe(@(val) val != null
  ? sceneWithCameraAdd(buySquadWnd, "battle_pass")
  : sceneWithCameraRemove(buySquadWnd))

if (compositeParams.value != null)
  sceneWithCameraAdd(buySquadWnd, "battle_pass")


return open
