import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui/ui_library.nut" import *

let { fontHeading2, fontSub } = require("%enlSqGlob/ui/fontsStyle.nut")
let { smallPadding, activeBgColor } = require("%enlSqGlob/ui/designConst.nut")
let { txt } = require("%enlSqGlob/ui/defcomps.nut")
let { remap_nick } = require("%enlSqGlob/remap_nick.nut")
let { frameNick, getPortrait } = require("%enlSqGlob/ui/decoratorsPresentation.nut")
let { withTooltip } = require("%ui/style/cursors.nut")
let { soldierNameSlicer } = require("%enlSqGlob/ui/itemsInfo.nut")
let mkBattleHeroAwardIcon = require("%enlSqGlob/ui/battleHeroAwardIcon.nut")
let { BattleHeroesAward, combineMultispecialistAward, awardPriority, isSoldierKindAward
} = require("%enlSqGlob/ui/battleHeroesAwards.nut")
let { partition } = require("%sqstd/underscore.nut")
let mkAwardsTooltip = require("%ui/hud/components/mkAwardsTooltip.nut")
let { getIdleAnimState } = require("%enlSqGlob/animation_utils.nut")
let { mkSoldierPhotoName, mkSoldierPhoto } = require("%enlSqGlob/ui/soldierPhoto.nut")
let { mkRankIcon, getRankConfig } = require("%enlSqGlob/ui/rankPresentation.nut")
let { mkPortraitIcon } = require("%enlist/profile/decoratorPkg.nut")
let userInfo = require("%enlSqGlob/userInfo.nut")


let awardMultTxtColor = Color(252, 186, 3, 255)
let battleHeroNameColor = Color(120,120,120, 50)
let localBattleHeroNameColor = Color(252, 186, 3, 255)

let PORTRAIT_SIZE = hdpxi(140)
let maxNameBlockWidth = hdpx(184)
let awardIconSize = [hdpxi(70), hdpxi(70)]
let photoSize = [hdpxi(92), hdpxi(136)]

let notActiveStyle = {
  tint = Color(40, 40, 40, 120)
  picSaturate = 0.0
}

let mkBattleHeroPlayerNameText = @(playerName, isLocalPlayer) {
  rendObj = ROBJ_TEXT
  maxWidth = maxNameBlockWidth
  behavior = Behaviors.Marquee
  clipChildren = true
  color = isLocalPlayer ? localBattleHeroNameColor : battleHeroNameColor
  text = playerName
}.__update(fontHeading2)

function mkBattleHeroAwards(awards, isActive) {
  local sortedAwards = [].extend(awards).sort(@(a,b) awardPriority[b] <=> awardPriority[a])
  let combinedAwards = combineMultispecialistAward(sortedAwards).reverse()

  let [kindAwards, otherAwards] = partition(sortedAwards, isSoldierKindAward)
  if (kindAwards.len() > 1)
    sortedAwards = otherAwards
      .append({icon=BattleHeroesAward.MULTISPECIALIST, text="debriefing/tooltipScoreTableMultispecialist"})
      .extend(kindAwards)

  let offset = hdpx(25)
  let firstOffset = (max(0, combinedAwards.len() - 1)) * offset * 0.5
  return {
    children = combinedAwards.map(@(award, index) withTooltip(
      mkBattleHeroAwardIcon(award, awardIconSize, isActive).__merge({ pos = [firstOffset - index * offset, 0] }),
      @() mkAwardsTooltip(sortedAwards, awardIconSize)))
  }
}

function rankBlock(playerRank) {
  if (playerRank == 0)
    return null

  let { imageBack } = getRankConfig(playerRank)
  return {
    rendObj = ROBJ_IMAGE
    vplace = ALIGN_BOTTOM
    hplace = ALIGN_RIGHT
    image = Picture(imageBack)
    margin = hdpx(1)
    size = [hdpx(28), hdpx(28)]
    children = mkRankIcon(playerRank, {
      vplace = ALIGN_CENTER
      hplace = ALIGN_CENTER
    })
  }
}

let mkBattleHeroPortrait = @(portrait, playerRank) {
  rendObj = ROBJ_BOX
  borderColor = activeBgColor
  borderWidth = hdpx(1)
  children = [
    mkPortraitIcon(getPortrait(portrait), PORTRAIT_SIZE).__update({ padding = hdpx(1) })
    rankBlock(playerRank)
  ]
}

function mkBattleHeroPhoto(soldier, isActive, playerRank) {
  let db = ecs.g_entity_mgr.getTemplateDB()
  let { guid, equipment = null, weapTemplates = null, gametemplate = null } = soldier
  let equipmentInfo = []
  let itemTemplates = []
  if (equipment != null) {
    foreach (slot, equip in equipment) {
      equipmentInfo.append({
        slot = slot,
        tpl = equip.gametemplate
      })
      let itemTemplate = db.getTemplateByName(equip.gametemplate)
      if (itemTemplate != null)
        itemTemplates.append(itemTemplate)
    }
  }
  let soldierTemplate = db.getTemplateByName(gametemplate)
  let overridedIdleAnims = soldierTemplate?.getCompValNullable("animation__overridedIdleAnims")
  let overridedSlotsOrder = soldierTemplate?.getCompValNullable("animation__overridedSlotsOrder").getAll()
  let animation = getIdleAnimState({
    weapTemplates
    itemTemplates
    overridedIdleAnims
    overridedSlotsOrder
    seed = guid.hash()
  })
  let photo = mkSoldierPhotoName(gametemplate, equipmentInfo, animation, true)
  return mkSoldierPhoto(photo, photoSize, rankBlock(playerRank), isActive ? {} : notActiveStyle)
}

let mkSoldierName = @(soldier, isLocalPlayer) isLocalPlayer && (soldier?.callname ?? "") != ""
  ? {
      rendObj = ROBJ_TEXT
      text = soldier.callname
      maxWidth = SIZE_TO_CONTENT
      size = [PORTRAIT_SIZE, SIZE_TO_CONTENT]
      behavior = Behaviors.Marquee
    }.__update(fontSub)
  : {
      rendObj = ROBJ_TEXTAREA
      behavior = Behaviors.TextArea
      text = soldierNameSlicer(soldier, isLocalPlayer)
    }.__update(fontSub)

let mkBattleHeroArmyMult = @(mult) txt({text=$"x{mult}", color=awardMultTxtColor})

let mkHeroes = @(heroes, isExpReceived, localPlayerGroupMembers) {
  flow = FLOW_HORIZONTAL
  size = SIZE_TO_CONTENT
  gap = hdpx(18)
  children = heroes.map(function(hero) {
    let {
      isFinished = true, awards = [], playerName = "", nickFrame = "", playerEid = null,
      portrait = "", isLocalPlayer = false, soldier = null, expMult = 1.0, playerRank = 0
    } = hero
    let name = isLocalPlayer
      ? userInfo.value?.nameorig
      : remap_nick(playerName, (playerEid ?? 0).tostring() not in localPlayerGroupMembers)
    let heroesObjects = [
      mkBattleHeroPlayerNameText(frameNick(name, nickFrame), isLocalPlayer)
      portrait == ""
        ? mkBattleHeroPhoto(soldier, isFinished, playerRank)
        : mkBattleHeroPortrait(portrait, playerRank)
      mkSoldierName(soldier, isLocalPlayer)
    ]
    let children = isFinished
      ? heroesObjects
      : heroesObjects.map(@(c) withTooltip(c,
          @() loc($"debriefing/battleHeroDeserter")))
    children.append(
      mkBattleHeroAwards(awards, isFinished),
      isFinished && isExpReceived ? mkBattleHeroArmyMult(expMult) : null
    )

    return {
      flow = FLOW_VERTICAL
      vplace = ALIGN_TOP
      halign = ALIGN_CENTER
      gap = smallPadding
      children
    }

  })
}

return mkHeroes
