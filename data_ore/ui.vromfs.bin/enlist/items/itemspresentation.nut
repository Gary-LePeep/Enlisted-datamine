from "%enlSqGlob/ui/ui_library.nut" import *

let { endswith } = require("string")
let colorize = require("%ui/components/colorize.nut")
let icon3dByGameTemplate = require("%enlSqGlob/ui/icon3dByGameTemplate.nut")
let { portraits, nickFrames } = require("%enlSqGlob/ui/decoratorsPresentation.nut")
let { medalsPresentation } = require("%enlist/profile/medalsPresentation.nut")
let { accentTitleTxtColor, darkTxtColor } = require("%enlSqGlob/ui/designConst.nut")
let { secondsToHoursLoc } = require("%ui/helpers/time.nut")
let { mkRadialGradientImg } = require("%darg/helpers/mkGradientImg.nut")
let { mkColoredGradientY } = require("%enlSqGlob/ui/gradients.nut")

let rewardBgSizePx = [hdpx(170), hdpx(210)]
let rewardWidthToHeight = rewardBgSizePx[0].tofloat() / rewardBgSizePx[1]

let calcSize = @(sizeBg, pxSize) [
  hdpxi(sizeBg[0] * pxSize[0].tofloat() / rewardBgSizePx[0]),
  hdpxi(sizeBg[1] * pxSize[1].tofloat() / rewardBgSizePx[1])
]

let mkImageParams = @(pxSize, pxOffset = [0, 12]) @(sizeBg) {
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  size = calcSize(sizeBg, pxSize)
  pos = calcSize(sizeBg, pxOffset)
}

let mkImageCtor = @(pxSize, pxOffset = [0, 12]) function(sizeBg, image) {
  let size = calcSize(sizeBg, pxSize)
  let img = endswith(image,".svg")
    ? $"{image}:{size[0]}:{size[1]}:F"
    : image
  return {
    size
    pos = calcSize(sizeBg, pxOffset)
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    rendObj = ROBJ_IMAGE
    image = Picture(img)
  }
}

let mkTemplateImageCtor = @(pxSize, pxOffset, gametemplate, genOverride = {}) function(sizeBg, _) {
  let size = calcSize(sizeBg, pxSize)
  return icon3dByGameTemplate(gametemplate, {
    width = size[0]
    height = size[1]
    pos = calcSize(sizeBg, pxOffset)
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    genOverride
  })
}


function mkReward(reward, pName = "") {
  let { decorators = [] } = reward
  if (decorators.len() > 0) {
    let viewDecorator = decorators[0]
    let { guid, lifeTime = 0 } = viewDecorator
    let isTemporary = lifeTime > 0
    let lifeTimeText = !isTemporary ? ""
      : colorize(accentTitleTxtColor, loc("issuedFor", {
          timeTxt = secondsToHoursLoc(lifeTime)
        }))

    if (guid in portraits) {
      let { icon, name = null, bgimg = ""} = portraits[guid]
      return {
        bgImage = bgimg
        isTemporary
        name = loc(name ?? "portrait/baseName")
        description = "\n".join([ loc("decorator/baseDesc"), lifeTimeText ], true)
        stackImages = [
          {
            img = icon
            params = {
              size = flex()
              hplace = ALIGN_CENTER
              vplace = ALIGN_CENTER
            }
          }
        ]
        gametemplate = guid
      }
    }
    if (guid in nickFrames){
      let cfg = nickFrames[guid]
      return {
        name = loc("nickFrames/baseName", { nick = cfg(pName) })
        isTemporary
        description = "\n".join([ loc("decorator/baseDesc"), lifeTimeText ], true)
        cardText = cfg("")
      }
    }
  }

  let { medals = [] } = reward
  if (medals.len() > 0) {
    let medal = medalsPresentation?[medals[0]]
    return medal == null ? null
      : {
          name = loc(medal.name)
          bgImage = medal.bgImage
          stackImages = medal.stackImages
        }
  }
  return null
}

let goldRadialGradient = {
  rendObj = ROBJ_IMAGE
  size = flex()
  image = mkRadialGradientImg({
    width = 16
    height = 16
    points = [
      { color = [0xFA, 0xD9, 0x7A] }
      { color = [0xC3, 0xAA, 0x5C] }
    ]
  })
}

let goldVerticalGradient = freeze({
  rendObj = ROBJ_IMAGE
  size = flex()
  image = mkColoredGradientY({colorTop=0xFFFAD97A, colorBottom=0xFF7D6D3D})
})

let defRewardPresentation = {
  cardImage = "ui/skin#rewards/crate_small_1.avif"
  cardImageParams = mkImageParams([240, 240])
  cardImageOpen = "ui/skin#rewards/crate_small_1_open.avif"
}

let rewardsPresentation = {
  ["9"] = {
    name = loc("currency/silver_currency")
    description = loc("currency/silver_currency_desc")
    icon = "!ui/uiskin/currency/enlisted_silver.svg"
    gametemplate = "item_silver_coin"
    worth = 0.5
    bgImage = "ui/skin#battlepass/bg_other.avif"
    cardImage = "ui/skin#battlepass/silver_coins.avif"
    cardImageParams = mkImageParams([166, 136], [0, -4])
  },
  ["10"] = {
    name = loc("currency/silver_currency")
    description = loc("currency/silver_currency_desc")
    icon = "!ui/uiskin/currency/enlisted_silver.svg"
    gametemplate = "item_silver_coin"
    worth = 0.5
    bgImage = "ui/skin#battlepass/bg_other.avif"
    cardImage = "ui/skin#battlepass/silver_coins.avif"
    cardImageParams = mkImageParams([166, 136], [0, -4])
  },
  ["11"] = {
    name = loc("currency/silver_currency")
    description = loc("currency/silver_currency_desc")
    icon = "!ui/uiskin/currency/enlisted_silver.svg"
    gametemplate = "item_silver_coin"
    worth = 1
    bgImage = "ui/skin#battlepass/bg_silver.avif"
    cardImage = "ui/skin#battlepass/silver_coins.avif"
    cardImageParams = mkImageParams([166, 136], [0, -4])
  },
  ["12"] = {
    name = loc("currency/silver_currency")
    description = loc("currency/silver_currency_desc")
    icon = "!ui/uiskin/currency/enlisted_silver.svg"
    gametemplate = "item_silver_coin"
    worth = 1
    bgImage = "ui/skin#battlepass/bg_silver.avif"
    cardImage = "ui/skin#battlepass/silver_coins.avif"
    cardImageParams = mkImageParams([166, 136], [0, -4])
  },
  ["13"] = {
    name = loc("items/weapon_order_gold")
    description = loc("items/weapon_order_gold/battlepass_desc")
    icon = "ui/skin#currency/weapon_order_gold.svg"
    gametemplate = "weapons_supply_ticket_gold"
    worth = 3
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "ui/skin#battlepass/gold_weapons.avif"
    cardImageParams = mkImageParams([144, 170], [0, 17])
    specialRewards = {
      [13] = {
        ussr = "bezruchko_vysotsky_smg"
        ger = "wz_39_mors"
        usa = "owen_45_acp_1941"
        jap = "sig_1930"
      }
    }
  },
  ["14"] = {
    name = loc("items/soldier_order_gold")
    description = loc("items/soldier_order_gold/battlepass_desc")
    icon = "ui/skin#currency/soldier_order_gold.svg"
    gametemplate = "soldiers_supply_ticket_gold"
    worth = 3
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "ui/skin#battlepass/gold_soldier.avif"
    cardImageParams = mkImageParams([162, 178])
  },
  ["23"] = {
    name = loc("items/random_battlepass_order_crate")
    description = loc("items/random_battlepass_order_crate/desc")
    icon = "ui/skin#currency/random_battlepass_order.svg"
    gametemplate = "random_battlepass_order"
    worth = 2
    bgImage = "ui/skin#battlepass/bg_other.avif"
    cardImage = "ui/skin#battlepass/random.avif"
    cardImageParams = mkImageParams([144, 122])
  },
  ["30"] = {
    name = loc("items/soldier_reward")
    icon = "ui/skin#events/soldier_reward_icon.svg"
    worth = 3
    bgImage = "ui/skin#battlepass/bg_other.avif"
    cardImage = "ui/skin#battlepass/gold_soldier.avif"
    cardImageParams = mkImageParams([162, 178])
  },
  ["EnlistedGold"] = {
    name = loc("currency/code/EnlistedGold")
    icon = "ui/skin#currency/enlisted_gold.svg"
    gametemplate = "item_ecoin"
    worth = 10
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "ui/skin#battlepass/gold_coins.avif"
    cardImageParams = mkImageParams([166, 136], [0, -4])
  },
  ["31"] = {
    name = loc("items/vehicle_with_skin_order_gold")
    description = loc("items/vehicle_with_skin_order_gold/desc")
    icon = "ui/skin#currency/vehicle_with_skin.svg"
    gametemplate = "vehicle_with_skin_supply_ticket_gold"
    worth = 3
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "ui/skin#battlepass/gold_vehicles.avif"
    cardImageParams = mkImageParams([170, 174], [0, -2])
  },
  ["33"] = {
    name = loc("items/research_change_order")
    description = loc("items/research_change_order/desc")
    icon = "ui/skin#currency/squad_respec.svg"
    gametemplate = "research_change_ticket"
    worth = 2
    bgImage = "ui/skin#battlepass/bg_other.avif"
    cardImage = "ui/skin#battlepass/reset_xp.avif"
    cardImageParams = mkImageParams([146, 148])
  },
  ["34"] = {
    name = loc("items/item_upgrade_order")
    description = loc("items/item_upgrade_order/desc")
    icon = "ui/skin#currency/item_upgrade.svg"
    gametemplate = "item_upgrade_ticket"
    worth = 2
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "ui/skin#battlepass/up_weapons.avif"
    cardImageParams = mkImageParams([170, 124], [3, 1])
  },
  ["35"] = {
    name = loc("items/soldier_levelup_order")
    description = loc("items/soldier_levelup_order/desc")
    icon = "!ui/uiskin/currency/soldier_levelup.svg"
    gametemplate = "soldier_level_ticket"
    worth = 2
    bgImage = "ui/skin#battlepass/bg_other.avif"
    cardImage = "ui/skin#battlepass/up_soldier.avif"
    cardImageParams = mkImageParams([170, 142], [-2, 4])
  },
  ["36"] = {
    name = loc("items/wallposter_battlepass_order")
    description = loc("items/wallposter_battlepass_order/desc")
    gametemplate = "poster_ticket"
    worth = 2
    bgImage = "ui/skin#battlepass/bg_poster.avif"
    cardImage = "ui/skin#battlepass/posters.avif"
    cardImageParams = mkImageParams([154, 174], [0, 13])
  },
  ["37"] = {
    name = loc("items/callname_change_order")
    description = loc("items/callname_change_order/desc")
    icon = "ui/skin#currency/soldier_name_change.svg"
    gametemplate = "callname_change_ticket"
    worth = 2
    bgImage = "ui/skin#battlepass/bg_other.avif"
    cardImage = "ui/skin#battlepass/rename.avif"
    cardImageParams = mkImageParams([154, 144], [0, 15])
  },
  ["38"] = {
    name = loc("items/appearance_change_order")
    description = loc("items/appearance_change_order/desc")
    icon = "ui/skin#currency/soldier_appearance.svg"
    gametemplate = "appearance_change_ticket"
    worth = 2
    bgImage = "ui/skin#battlepass/bg_other.avif"
    cardImage = "ui/skin#battlepass/makeup.avif"
    cardImageParams = mkImageParams([162, 148], [0, 18])
  },
  ["40"] = {
    name = loc("items/marathon_2021_summer_order")
    description = loc("items/marathon_2021_summer_order/desc")
    icon = "ui/skin#currency/event_order.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/skin#currency/event_order.svg"
    mkImage = mkImageCtor([72, 100]) //432 * 600
  },
  ["41"] = {
    name = loc("vehicleDetails/fw_189a_1")
    description = loc("items/fw_189a_1/desc")
    icon = "ui/skin#aircraft_icon.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    mkImage = mkTemplateImageCtor([190, 190], [0, 18], "fw_189a1", { iconRoll = 50, iconYaw = -35 })
  },
  ["42"] = {
    name = loc("vehicleDetails/us_m5a1_stuart_rhino_event_premium")
    description = loc("items/us_m5a1_stuart_rhino_event_premium/desc")
    icon = "ui/skin#tank_icon.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    mkImage = mkTemplateImageCtor([170, 150], [0, 12], "us_m5a1_stuart_rhino_event_premium")
  },
  ["43"] = {
    name = loc("squad/ussr_berlin_event_assault_1")
    description = loc("squadannounce/ussr_berlin_event_assault_1")
    icon = "ui/skin#research/squad_points_icon.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/soldiers/ussr/ussr_berlin_event_assault_1_icon.svg"
    mkImage = mkImageCtor([120, 111], [-4, 28]) //600 * 555
  },
  ["45"] = defRewardPresentation.__merge({
    name = loc("smallTrophyTitle_1")
  }),
  ["49"] = {
    icon = "ui/skin#battlepass/base_booster_icon.svg"
    worth = 2
    bgImage = "ui/skin#battlepass/bg_boost.avif"
    cardImage = "ui/skin#battlepass/boost_global.avif"
    cardImageParams = mkImageParams([154, 144], [0, 15])
  },
  ["50"] = {
    icon = "ui/skin#battlepass/base_booster_icon.svg"
    worth = 2
    bgImage = "ui/skin#battlepass/bg_boost.avif"
    cardImage = "ui/skin#battlepass/boost_global.avif"
    cardImageParams = mkImageParams([154, 144], [0, 15])
  },
  ["186"] = {
    name = loc("items/wallposter_battlepass_order")
    description = loc("items/wallposter_battlepass_order/desc")
    gametemplate = "poster_ticket_4"
    worth = 2
    bgImage = "ui/skin#battlepass/bg_poster.avif"
    cardImage = "ui/skin#battlepass/posters.avif"
    cardImageParams = mkImageParams([154, 174], [0, 13])
  },
  ["187"] = {
    name = loc("items/battlepass_buster_soldier_3")
    description = loc("items/battlepass_buster_soldier_3/desc")
    icon = "ui/skin#battlepass/base_booster_icon.svg"
    gametemplate = "battlepass_buster_soldier_3_template"
    worth = 2
    bgImage = "ui/skin#battlepass/bg_boost.avif"
    cardImage = "ui/skin#battlepass/boost_soldier.avif"
    cardImageParams = mkImageParams([154, 144], [0, 15])
  },
  ["188"] = {
    name = loc("items/battlepass_buster_squad_5")
    description = loc("items/battlepass_buster_squad_5/desc")
    icon = "ui/skin#battlepass/base_booster_icon.svg"
    gametemplate = "battlepass_buster_squad_5_template"
    worth = 2
    bgImage = "ui/skin#battlepass/bg_boost.avif"
    cardImage = "ui/skin#battlepass/boost_squad.avif"
    cardImageParams = mkImageParams([154, 144], [0, 15])
  },
  ["179"] = {
    name = loc("squad/allies_tunisia_event_mgun_1")
    description = loc("squadannounce/allies_tunisia_event_mgun_1")
    icon = "ui/skin#research/squad_points_icon.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/soldiers/usa/allies_tunisia_event_mgun_1_icon.svg"
    mkImage = mkImageCtor([120, 111], [-4, 28]) //600 * 555
  },
  ["180"] = {
    name = loc("items/tunisia_axis_hero_marathon_2021_autumn")
    description = loc("items/tunisia_axis_hero_marathon_2021_autumn/desc")
    icon = "ui/squads/germany/italy_hero_medal_1_icon.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/squads/germany/italy_hero_medal_1_icon.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["181"] = {
    name = loc("items/p_47d_22_re")
    description = loc("items/p_47d_22_re/desc")
    icon = "ui/skin#aircraft_icon.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    mkImage = mkTemplateImageCtor([190, 190], [0, 18], "p_47d_22_re_joan_premium", { iconRoll = 50, iconYaw = -35 })
  },
  ["182"] = {
    name = loc("items/germ_jgdpz_iv_l48")
    description = loc("items/germ_jgdpz_iv_l48/desc")
    icon = "ui/skin#tank_icon.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    mkImage = mkTemplateImageCtor([170, 150], [0, 12], "germ_panzerjager_IV_L_48_berlin_premium")
  },
  ["189"] = {
    name = loc("items/marathon_2021_summer_order")
    description = loc("items/marathon_2021_summer_order/desc")
    icon = "ui/skin#currency/event_order.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/skin#currency/event_order.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["190"] = {
    name = loc("items/marathon_2021_summer_order")
    description = loc("items/marathon_2021_summer_order/desc")
    icon = "ui/skin#currency/event_order.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/skin#currency/event_order.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["191"] = {
    name = loc("items/marathon_2021_summer_order")
    description = loc("items/marathon_2021_summer_order/desc")
    icon = "ui/skin#currency/event_order.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/skin#currency/event_order.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["192"] = {
    name = loc("items/marathon_2021_summer_order")
    description = loc("items/marathon_2021_summer_order/desc")
    icon = "ui/skin#currency/event_order.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/skin#currency/event_order.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["209"] = {
    name = loc("wp/agit_poster_china_a_preview/name")
    description = loc("wp/agit_poster_china_a_preview/desc")
    gametemplate = "poster_ticket_4"
    worth = 2
    icon = "ui/skin#currency/poster_icon.svg"
    bgImage = "ui/skin#battlepass/bg_poster.avif"
    cardImage = "ui/skin#battlepass/posters.avif"
    cardImageParams = mkImageParams([154, 174], [0, 13])
  },
  ["210"] = {
    icon = "ui/skin#battlepass/base_booster_icon.svg"
    worth = 2
    bgImage = "ui/skin#battlepass/bg_boost.avif"
    cardImage = "ui/skin#battlepass/boost_global.avif"
    cardImageParams = mkImageParams([154, 144], [0, 15])
  },
  ["211"] = {
    name = loc("items/wallposter_battlepass_order")
    description = loc("items/wallposter_battlepass_order/desc")
    gametemplate = "poster_ticket_5"
    worth = 2
    bgImage = "ui/skin#battlepass/bg_poster.avif"
    cardImage = "ui/skin#battlepass/posters.avif"
    cardImageParams = mkImageParams([154, 174], [0, 13])
  },
  ["212"] = {
    icon = "ui/skin#battlepass/base_booster_icon.svg"
    worth = 2
    bgImage = "ui/skin#battlepass/bg_boost.avif"
    cardImage = "ui/skin#battlepass/boost_global.avif"
    cardImageParams = mkImageParams([154, 144], [0, 15])
  },
  ["213"] = {
    name = loc("items/engineer_event_reward_moscow_allies")
    description = loc("items/engineer_event_reward_moscow_allies/desc")
    icon = "ui/skin#currency/event_order.svg"
    cardImage = "!ui/shop/weapons/engineer_award_building_tool.avif"
    mkImage = mkImageCtor([350, 200], [0, 0])
  },
  ["214"] = {
    name = loc("items/engineer_event_reward_moscow_axis")
    description = loc("items/engineer_event_reward_moscow_axis/desc")
    icon = "ui/skin#currency/event_order.svg"
    cardImage = "!ui/shop/weapons/engineer_award_building_tool.avif"
    mkImage = mkImageCtor([350, 200], [0, 0])
  },
  ["215"] = {
    name = loc("items/engineer_event_reward_normandy_allies")
    description = loc("items/engineer_event_reward_normandy_allies/desc")
    icon = "ui/skin#currency/event_order.svg"
    cardImage = "!ui/shop/weapons/engineer_award_building_tool.avif"
    mkImage = mkImageCtor([350, 200], [0, 0])
  },
  ["216"] = {
    name = loc("items/engineer_event_reward_normandy_axis")
    description = loc("items/engineer_event_reward_normandy_axis/desc")
    icon = "ui/skin#currency/event_order.svg"
    cardImage = "!ui/shop/weapons/engineer_award_building_tool.avif"
    mkImage = mkImageCtor([350, 200], [0, 0])
  },
  ["217"] = {
    name = loc("items/engineer_event_reward_berlin_allies")
    description = loc("items/engineer_event_reward_berlin_allies/desc")
    icon = "ui/skin#currency/event_order.svg"
    cardImage = "!ui/shop/weapons/engineer_award_building_tool.avif"
    mkImage = mkImageCtor([350, 200], [0, 0])
  },
  ["218"] = {
    name = loc("items/engineer_event_reward_berlin_axis")
    description = loc("items/engineer_event_reward_berlin_axis/desc")
    icon = "ui/skin#currency/event_order.svg"
    cardImage = "!ui/shop/weapons/engineer_award_building_tool.avif"
    mkImage = mkImageCtor([350, 200], [0, 0])
  },
  ["219"] = {
    name = loc("items/engineer_event_reward_tunisia_allies")
    description = loc("items/engineer_event_reward_tunisia_allies/desc")
    icon = "ui/skin#currency/event_order.svg"
    cardImage = "!ui/shop/weapons/engineer_award_building_tool.avif"
    mkImage = mkImageCtor([350, 200], [0, 0])
  },
  ["220"] = {
    name = loc("items/engineer_event_reward_tunisia_axis")
    description = loc("items/engineer_event_reward_tunisia_axis/desc")
    icon = "ui/skin#currency/event_order.svg"
    cardImage = "!ui/shop/weapons/engineer_award_building_tool.avif"
    mkImage = mkImageCtor([350, 200], [0, 0])
  },
  ["241"] = {
    icon = "ui/skin#battlepass/base_booster_icon.svg"
    worth = 2
    bgImage = "ui/skin#battlepass/bg_boost.avif"
    cardImage = "ui/skin#battlepass/boost_global.avif"
    cardImageParams = mkImageParams([154, 144], [0, 15])
  },
  ["242"] = {
    name = loc("items/victory_day_event_order")
    description = loc("items/victory_day_event_order/desc")
    icon = "ui/skin#currency/event_order.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/skin#currency/event_order.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["243"] = {
    name = loc("items/soldier_exclusive")
    description = loc("items/soldier_exclusive/desc")
    icon = "ui/skin#currency/soldier_order_gold.svg"
    gametemplate = "soldiers_supply_ticket_gold"
    worth = 3
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "ui/skin#battlepass/gold_soldier.avif"
    cardImageParams = mkImageParams([162, 178])
  },
  ["244"] = {
    icon = "ui/skin#battlepass/base_booster_icon.svg"
    worth = 2
    bgImage = "ui/skin#battlepass/bg_boost.avif"
    cardImage = "ui/skin#battlepass/boost_global.avif"
    cardImageParams = mkImageParams([154, 144], [0, 15])
  },
  ["245"] = {
    icon = "ui/skin#battlepass/base_booster_icon.svg"
    worth = 2
    bgImage = "ui/skin#battlepass/bg_boost.avif"
    cardImage = "ui/skin#battlepass/boost_global.avif"
    cardImageParams = mkImageParams([154, 144], [0, 15])
  },
  ["246"] = {
    name = loc("items/wallposter_battlepass_order")
    description = loc("items/wallposter_battlepass_order/desc")
    gametemplate = "poster_ticket_6"
    worth = 2
    bgImage = "ui/skin#battlepass/bg_poster.avif"
    cardImage = "ui/skin#battlepass/posters.avif"
    cardImageParams = mkImageParams([154, 174], [0, 13])
  },
  ["247"] = {
    icon = "ui/skin#battlepass/base_booster_icon.svg"
    worth = 2
    bgImage = "ui/skin#battlepass/bg_boost.avif"
    cardImage = "ui/skin#battlepass/boost_global.avif"
    cardImageParams = mkImageParams([154, 144], [0, 15])
  },
  ["248"] = {
    icon = "ui/skin#battlepass/base_booster_icon.svg"
    worth = 2
    bgImage = "ui/skin#battlepass/bg_boost.avif"
    cardImage = "ui/skin#battlepass/boost_global.avif"
    cardImageParams = mkImageParams([154, 144], [0, 15])
  },
  ["249"] = {
    name = loc("items/vehicle_upgrade_order")
    description = loc("items/vehicle_upgrade_order/desc")
    icon = "ui/skin#currency/vehicle_upgrade.svg"
    gametemplate = "vehicle_upgrade_ticket"
    worth = 2
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "ui/skin#battlepass/up_vehicles.avif"
    cardImageParams = mkImageParams([170, 124], [3, 1])
  },
  ["250"] = {
    name = loc("squad/allies_tunisia_event_assault_1")
    description = loc("squadannounce/allies_tunisia_event_assault_1")
    icon = "ui/skin#research/squad_points_icon.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/soldiers/usa/allies_tunisia_event_assault_1_icon.svg"
    mkImage = mkImageCtor([120, 111], [-4, 28]) //600 * 555
  },
  ["251"] = {
    name = loc("squad/ger_normandy_event_assault_1")
    description = loc("squadannounce/ger_normandy_event_assault_1")
    icon = "ui/skin#research/squad_points_icon.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/soldiers/germany/ger_normandy_event_assault_1_icon.svg"
    mkImage = mkImageCtor([120, 111], [-4, 28]) //600 * 555
  },
  ["252"] = {
    name = loc("items/ussr_bt_7a_f32")
    description = loc("items/ussr_bt_7a_f32/desc")
    icon = "ui/skin#tank_icon.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    mkImage = mkTemplateImageCtor([170, 150], [0, 12], "ussr_bt_7a_f32_stalingrad_premium")
  },
  ["253"] = {
    name = loc("items/moscow_allies_hero_marathon_2022_summer")
    description = loc("items/moscow_allies_hero_marathon_2022_summer/desc")
    icon = "ui/squads/ussr/ussr_hero_medal_1_icon.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/squads/ussr/ussr_hero_medal_1_icon.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["254"] = {
    name = loc("items/normandy_axis_event_marathon_summer_2022_portrait")
    description = loc("items/normandy_axis_event_marathon_summer_2022_portrait/desc")
    icon = "ui/portraits/default_portrait.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/portraits/default_portrait.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["255"] = {
    name = loc("items/tunisia_allies_event_marathon_summer_2022_portrait")
    description = loc("items/tunisia_allies_event_marathon_summer_2022_portrait/desc")
    icon = "ui/portraits/default_portrait.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/portraits/default_portrait.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["256"] = {
    name = loc("items/marathon_2022_summer_event_order")
    description = loc("items/marathon_2022_summer_event_order/desc")
    icon = "ui/skin#currency/event_order.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/skin#currency/event_order.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["257"] = {
    icon = "ui/skin#battlepass/base_booster_icon.svg"
    worth = 2
    bgImage = "ui/skin#battlepass/bg_boost.avif"
    cardImage = "ui/skin#battlepass/boost_global.avif"
    cardImageParams = mkImageParams([154, 144], [0, 15])
  },
  ["259"] = {
    name = loc("wp/agit_poster_china_b_preview/name")
    description = loc("wp/agit_poster_china_b_preview/desc")
    gametemplate = "poster_ticket_4"
    worth = 2
    icon = "ui/skin#currency/poster_icon.svg"
    bgImage = "ui/skin#battlepass/bg_poster.avif"
    cardImage = "ui/skin#battlepass/posters.avif"
    cardImageParams = mkImageParams([154, 174], [0, 13])
  },
  ["260"] = {
    name = loc("wp/agit_poster_china_c_preview/name")
    description = loc("wp/agit_poster_china_c_preview/desc")
    gametemplate = "poster_ticket_4"
    worth = 2
    icon = "ui/skin#currency/poster_icon.svg"
    bgImage = "ui/skin#battlepass/bg_poster.avif"
    cardImage = "ui/skin#battlepass/posters.avif"
    cardImageParams = mkImageParams([154, 174], [0, 13])
  },
  ["261"] = {
    name = loc("wp/agit_poster_china_d_preview/name")
    description = loc("wp/agit_poster_china_d_preview/desc")
    gametemplate = "poster_ticket_4"
    worth = 2
    icon = "ui/skin#currency/poster_icon.svg"
    bgImage = "ui/skin#battlepass/bg_poster.avif"
    cardImage = "ui/skin#battlepass/posters.avif"
    cardImageParams = mkImageParams([154, 174], [0, 13])
  },
  ["262"] = {
    name = loc("wp/agit_poster_china_e_preview/name")
    description = loc("wp/agit_poster_china_e_preview/desc")
    gametemplate = "poster_ticket_4"
    worth = 2
    icon = "ui/skin#currency/poster_icon.svg"
    bgImage = "ui/skin#battlepass/bg_poster.avif"
    cardImage = "ui/skin#battlepass/posters.avif"
    cardImageParams = mkImageParams([154, 174], [0, 13])
  },
  ["263"] = {
    name = loc("wp/agit_poster_china_f_preview/name")
    description = loc("wp/agit_poster_china_f_preview/desc")
    gametemplate = "poster_ticket_4"
    worth = 2
    icon = "ui/skin#currency/poster_icon.svg"
    bgImage = "ui/skin#battlepass/bg_poster.avif"
    cardImage = "ui/skin#battlepass/posters.avif"
    cardImageParams = mkImageParams([154, 174], [0, 13])
  },
  ["265"] = {
    name = loc("items/normandy_allies_hero_airborne_day_2022")
    description = loc("items/normandy_allies_hero_airborne_day_2022/desc")
    icon = "ui/squads/usa/usa_hero_medal_1_icon.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/squads/usa/usa_hero_medal_1_icon.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["324"] = {
    name = loc("items/nickFrame")
    description = loc("items/nickFrame/desc")
    icon = "ui/skin#currency/nickframe_order_event.svg"
    bgImage = "ui/skin#battlepass/bg_other.avif"
    cardImage = "ui/skin#battlepass/nickframe_bp.avif"
    cardImageParams = mkImageParams([160, 178])
  },
  ["344"] = {
    name = loc("items/pacific_event_2022_order")
    description = loc("items/pacific_event_2022_order/desc")
    icon = "ui/skin#currency/event_order.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/skin#currency/event_order.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["348"] = {
    name = loc("items/wallposter_battlepass_order")
    description = loc("items/wallposter_battlepass_order/desc")
    gametemplate = "poster_ticket_7"
    worth = 2
    bgImage = "ui/skin#battlepass/bg_poster.avif"
    cardImage = "ui/skin#battlepass/posters.avif"
    cardImageParams = mkImageParams([154, 174], [0, 13])
  },
  ["353"] = {
    name = loc("wp/agit_poster_china_g_preview/name")
    description = loc("wp/agit_poster_china_g_preview/desc")
    gametemplate = "poster_ticket_4"
    worth = 2
    icon = "ui/skin#currency/poster_icon.svg"
    bgImage = "ui/skin#battlepass/bg_poster.avif"
    cardImage = "ui/skin#battlepass/posters.avif"
    cardImageParams = mkImageParams([154, 174], [0, 13])
  },
  ["354"] = {
    name = loc("wp/agit_poster_china_h_preview/name")
    description = loc("wp/agit_poster_china_h_preview/desc")
    gametemplate = "poster_ticket_4"
    worth = 2
    icon = "ui/skin#currency/poster_icon.svg"
    bgImage = "ui/skin#battlepass/bg_poster.avif"
    cardImage = "ui/skin#battlepass/posters.avif"
    cardImageParams = mkImageParams([154, 174], [0, 13])
  },
  ["356"] = {
    name = loc("items/sea_predator_reward_order")
    description = loc("items/sea_predator_reward_order/desc")
    icon = "ui/skin#currency/random_reward_order.svg"
    bgImage = "ui/skin#battlepass/bg_other.avif"
    cardImage = "ui/skin#battlepass/random_reward.avif"
    cardImageParams = mkImageParams([102, 146], [0, -10])
  },
  ["357"] = {
    name = loc("items/sea_predator_decal_order")
    description = loc("items/sea_predator_decal_order/desc")
    icon = "ui/skin#currency/decal_order_event.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/skin#currency/decal_order_event.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["359"] = {
    name = loc("items/armory_event_crate")
    description = loc("items/armory_event_crate/desc")
    icon = "ui/skin#currency/random_reward_order.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/skin#currency/random_reward_order.svg"
    mkImage = mkImageCtor([72, 100]) //432 * 600
  },
  ["360"] = {
    name = loc("items/armory_event_portrait_usa")
    description = loc("decorator/armory_event_portrait_usa/tip")
    icon = "ui/portraits/default_portrait.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/portraits/default_portrait.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["361"] = {
    name = loc("items/armory_event_portrait_ger")
    description = loc("decorator/armory_event_portrait_ger/tip")
    icon = "ui/portraits/default_portrait.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/portraits/default_portrait.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["364"] = {
    name = loc("wp/agit_poster_china_i_preview/name")
    description = loc("wp/agit_poster_china_i_preview/desc")
    gametemplate = "poster_ticket_4"
    worth = 2
    icon = "ui/skin#currency/poster_icon.svg"
    bgImage = "ui/skin#battlepass/bg_poster.avif"
    cardImage = "ui/skin#battlepass/posters.avif"
    cardImageParams = mkImageParams([154, 174], [0, 13])
  },
  ["365"] = {
    name = loc("wp/agit_poster_china_j_preview/name")
    description = loc("wp/agit_poster_china_j_preview/desc")
    gametemplate = "poster_ticket_4"
    worth = 2
    icon = "ui/skin#currency/poster_icon.svg"
    bgImage = "ui/skin#battlepass/bg_poster.avif"
    cardImage = "ui/skin#battlepass/posters.avif"
    cardImageParams = mkImageParams([154, 174], [0, 13])
  },
  ["368"] = {
    name = loc("items/enlisted2years_portrait_ussr")
    description = loc("decorator/enlisted2years_portrait/tip")
    icon = "ui/uiskin/currency/portrait_order_event.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/portraits/default_portrait.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["369"] = {
    name = loc("items/enlisted2years_portrait_britain")
    description = loc("decorator/enlisted2years_portrait/tip")
    icon = "ui/uiskin/currency/portrait_order_event.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/portraits/default_portrait.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["370"] = {
    name = loc("items/enlisted2years_portrait_usa")
    description = loc("decorator/enlisted2years_portrait/tip")
    icon = "ui/uiskin/currency/portrait_order_event.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/portraits/default_portrait.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["371"] = {
    name = loc("decals/su_ulan_ude_bear")
    description = loc("decals/su_ulan_ude_bear/desc")
    icon = "ui/uiskin/currency/decal_order_event.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/skin#battlepass/silver_weapons.avif"
    mkImage = mkImageCtor([144, 170], [0, 17])
  },
  ["372"] = {
    name = loc("decals/uk_britannia_defiant")
    description = loc("decals/uk_britannia_defiant/desc")
    icon = "ui/uiskin/currency/decal_order_event.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/skin#battlepass/silver_weapons.avif"
    mkImage = mkImageCtor([144, 170], [0, 17])
  },
  ["373"] = {
    name = loc("decals/su_guards_emblem")
    description = loc("decals/su_guards_emblem/desc")
    icon = "ui/uiskin/currency/decal_order_event.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/skin#battlepass/silver_weapons.avif"
    mkImage = mkImageCtor([144, 170], [0, 17])
  },
  ["374"] = {
    name = loc("decals/us_836_bmb_sqn_liberty_belle")
    description = loc("decals/us_836_bmb_sqn_liberty_belle/desc")
    icon = "ui/uiskin/currency/decal_order_event.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/skin#battlepass/silver_weapons.avif"
    mkImage = mkImageCtor([144, 170], [0, 17])
  },
  ["375"] = {
    name = loc("decals/de_jg26_sqn_4_who_tiger")
    description = loc("decals/de_jg26_sqn_4_who_tiger/desc")
    icon = "ui/uiskin/currency/decal_order_event.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/skin#battlepass/silver_weapons.avif"
    mkImage = mkImageCtor([144, 170], [0, 17])
  },
  ["377"] = {
    name = loc("wp/agit_poster_china_k_preview/name")
    description = loc("wp/agit_poster_china_k_preview/desc")
    gametemplate = "poster_ticket_4"
    worth = 2
    icon = "ui/skin#currency/poster_icon.svg"
    bgImage = "ui/skin#battlepass/bg_poster.avif"
    cardImage = "ui/skin#battlepass/posters.avif"
    cardImageParams = mkImageParams([154, 174], [0, 13])
  },
  ["378"] = {
    name = loc("items/xmas_event_order")
    description = loc("items/xmas_event_order/desc")
    icon = "ui/skin#currency/event_order.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/skin#currency/event_order.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["379"] = {
    name = loc("items/xmas_event_ussr_portrait")
    description = loc("decorator/xmas_event_portrait/tip")
    icon = "ui/uiskin/currency/portrait_order_event.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/portraits/default_portrait.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["380"] = {
    name = loc("items/xmas_event_ger_portrait")
    description = loc("decorator/xmas_event_portrait/tip")
    icon = "ui/uiskin/currency/portrait_order_event.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/portraits/default_portrait.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["382"] = {
    name = loc("items/wallposter_battlepass_order")
    description = loc("items/wallposter_battlepass_order/desc")
    gametemplate = "poster_ticket_8"
    worth = 2
    bgImage = "ui/skin#battlepass/bg_poster.avif"
    cardImage = "ui/skin#battlepass/posters.avif"
    cardImageParams = mkImageParams([154, 174], [0, 13])
  },
  ["384"] = {
    name = loc("items/stalingrad_event_portrait_ussr")
    description = loc("decorator/stalingrad_event_portrait_ussr/tip")
    icon = "ui/portraits/default_portrait.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/portraits/default_portrait.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["385"] = {
    name = loc("items/heavy_weapons_event_order")
    description = loc("items/heavy_weapons_event_order/desc")
    icon = "ui/skin#currency/event_order.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/skin#currency/event_order.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["386"] = {
    name = loc("vehicleDetails/jp_type_97_kai")
    description = loc("items/jp_type_97_kai/desc")
    icon = "ui/skin#tank_icon.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    mkImage = mkTemplateImageCtor([170, 150], [0, 12], "jp_type_97_kai_pacific_premium")
  },
  ["412"] = {
    name = loc("wp/agit_poster_china_l_preview/name")
    description = loc("wp/agit_poster_china_l_preview/desc")
    gametemplate = "poster_ticket_4"
    worth = 2
    icon = "ui/skin#currency/poster_icon.svg"
    bgImage = "ui/skin#battlepass/bg_poster.avif"
    cardImage = "ui/skin#battlepass/posters.avif"
    cardImageParams = mkImageParams([154, 174], [0, 13])
  },
  ["413"] = {
    name = loc("wp/agit_poster_china_m_preview/name")
    description = loc("wp/agit_poster_china_m_preview/desc")
    gametemplate = "poster_ticket_4"
    worth = 2
    icon = "ui/skin#currency/poster_icon.svg"
    bgImage = "ui/skin#battlepass/bg_poster.avif"
    cardImage = "ui/skin#battlepass/posters.avif"
    cardImageParams = mkImageParams([154, 174], [0, 13])
  },
  ["414"] = {
    icon = "ui/skin#battlepass/deserter_penalty_icon.svg"
    worth = 2
    bgImage = "ui/skin#battlepass/bg_penalty.avif"
    cardImage = "ui/skin#battlepass/boost_global.avif"
    cardImageParams = mkImageParams([154, 144], [0, 15])
  },
  ["415"] = {
    name = loc("items/engineerDay23_event_portrait")
    description = loc("decorator/engineerDay23_event_portrait/tip")
    icon = "ui/portraits/default_portrait.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/portraits/default_portrait.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["316"] = {
    name = loc("items/nickFrame")
    description = loc("items/nickFrame/desc")
    icon = "ui/skin#currency/nickframe_order_event.svg"
    bgImage = "ui/skin#battlepass/bg_other.avif"
    cardImage = "ui/skin#battlepass/nickframe_bp.avif"
    cardImageParams = mkImageParams([160, 178])
  },
  ["416"] = {
    name = loc("items/engineer_event_reward_stalingrad_allies")
    description = loc("items/engineer_event_reward_stalingrad_allies/desc")
    icon = "ui/skin#currency/event_order.svg"
    cardImage = "!ui/shop/weapons/engineer_award_building_tool.avif"
    mkImage = mkImageCtor([350, 200], [0, 0])
  },
  ["417"] = {
    name = loc("items/engineer_event_reward_stalingrad_axis")
    description = loc("items/engineer_event_reward_stalingrad_axis/desc")
    icon = "ui/skin#currency/event_order.svg"
    cardImage = "!ui/shop/weapons/engineer_award_building_tool.avif"
    mkImage = mkImageCtor([350, 200], [0, 0])
  },
  ["418"] = {
    name = loc("items/engineer_event_reward_pacific_allies")
    description = loc("items/engineer_event_reward_pacific_allies/desc")
    icon = "ui/skin#currency/event_order.svg"
    cardImage = "!ui/shop/weapons/engineer_award_building_tool.avif"
    mkImage = mkImageCtor([350, 200], [0, 0])
  },
  ["419"] = {
    name = loc("items/engineer_event_reward_pacific_axis")
    description = loc("items/engineer_event_reward_pacific_axis/desc")
    icon = "ui/skin#currency/event_order.svg"
    cardImage = "!ui/shop/weapons/engineer_award_building_tool.avif"
    mkImage = mkImageCtor([350, 200], [0, 0])
  },
  ["420"] = {
    name = loc("items/m2_mortar")
    description = loc("items/m2_mortar/desc")
    icon = "ui/skin#currency/event_order.svg"
    cardImage = "!ui/shop/weapons/m2_mortar.avif"
    mkImage = mkImageCtor([350, 200], [0, 0])
  },
  ["421"] = {
    name = loc("squad/ussr_moscow_event_antitank_1")
    description = loc("squadannounce/ussr_moscow_event_antitank_1")
    icon = "ui/skin#research/squad_points_icon.svg"
    cardImage = "!ui/soldiers/ussr/ussr_moscow_event_antitank_1_image.avif"
    mkImage = mkImageCtor([400, 300], [0, 0])
  },
  ["422"] = {
    name = loc("squad/ger_moscow_event_antitank_1")
    description = loc("squadannounce/ger_moscow_event_antitank_1")
    icon = "ui/skin#research/squad_points_icon.svg"
    cardImage = "!ui/soldiers/germany/ger_moscow_event_antitank_1_image.avif"
    mkImage = mkImageCtor([400, 300], [0, 0])
  },
  ["423"] = {
    name = loc("items/mech_event_crate")
    description = loc("items/mech_event_crate/desc")
    cardImage = "!ui/skin#random_reward_chest.avif"
    mkImage = mkImageCtor([200, 200], [0, 0]) //432 * 600
  },
  ["436"] = {
    name = loc("squad/usa_normandy_event_paratrooper_1")
    description = loc("squadannounce/usa_normandy_event_paratrooper_1")
    icon = "ui/skin#research/squad_points_icon.svg"
    cardImage = "!ui/soldiers/usa/usa_normandy_event_paratrooper_1_image.avif"
    mkImage = mkImageCtor([400, 300], [0, 0])
  },
  ["437"] = {
    name = loc("squad/ger_normandy_event_paratrooper_1")
    description = loc("squadannounce/ger_normandy_event_paratrooper_1")
    icon = "ui/skin#research/squad_points_icon.svg"
    cardImage = "!ui/soldiers/germany/ger_normandy_event_paratrooper_1_image.avif"
    mkImage = mkImageCtor([400, 300], [0, 0])
  },
  ["438"] = {
    name = loc("squad/allies_pacific_event_paratrooper_1")
    description = loc("squadannounce/allies_pacific_event_paratrooper_1")
    icon = "ui/skin#research/squad_points_icon.svg"
    cardImage = "!ui/soldiers/usa/allies_pacific_event_paratrooper_1_image.avif"
    mkImage = mkImageCtor([400, 300], [0, 0])
  },
  ["439"] = {
    name = loc("squad/axis_pacific_event_paratrooper_1")
    description = loc("squadannounce/axis_pacific_event_paratrooper_1")
    icon = "ui/skin#research/squad_points_icon.svg"
    cardImage = "!ui/soldiers/japan/axis_pacific_event_paratrooper_1_image.avif"
    mkImage = mkImageCtor([400, 300], [0, 0])
  },
  ["440"] = {
    name = loc("items/wallposter_battlepass_order")
    description = loc("items/wallposter_battlepass_order/desc")
    gametemplate = "poster_ticket_9"
    worth = 2
    bgImage = "ui/skin#battlepass/bg_poster.avif"
    cardImage = "ui/skin#battlepass/posters.avif"
    cardImageParams = mkImageParams([154, 174], [0, 13])
  },
  ["441"] = {
    name = loc("items/berlin_operation_medic_portrait")
    description = loc("decorator/berlin_operation_medic_portrait/tip")
    icon = "ui/portraits/default_portrait.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/portraits/default_portrait.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["442"] = {
    name = loc("squad/ussr_moscow_event_tank_1")
    description = loc("squadannounce/ussr_moscow_event_tank_1")
    icon = "ui/skin#research/squad_points_icon.svg"
    cardImage = "!ui/soldiers/ussr/ussr_moscow_event_tank_1_image.avif"
    mkImage = mkImageCtor([400, 300], [0, 0])
  },
  ["443"] = {
    name = loc("squad/ger_moscow_event_tank_1")
    description = loc("squadannounce/ger_moscow_event_tank_1")
    icon = "ui/skin#research/squad_points_icon.svg"
    cardImage = "!ui/soldiers/germany/ger_moscow_event_tank_1_image.avif"
    mkImage = mkImageCtor([400, 300], [0, 0])
  },
  ["444"] = {
    name = loc("items/victory_day_2023_event_order")
    description = loc("items/victory_day_2023_event_order/desc")
    icon = "ui/skin#currency/event_order.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/skin#currency/event_order.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["445"] = {
    name = loc("items/victory_day_2023_event_crate")
    description = loc("items/victory_day_2023_event_crate/desc")
    icon = "ui/skin#currency/random_reward_order.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/skin#currency/random_reward_order.svg"
    mkImage = mkImageCtor([72, 100]) //432 * 600
  },
  ["446"] = {
    name = loc("items/armedForces_day_2023_event_order")
    description = loc("items/armedForces_day_2023_event_order/desc")
    icon = "ui/skin#currency/event_order.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/skin#currency/event_order.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["448"] = {
    name = loc("decals/summer_ops_girl_usa")
    description = loc("decals/summer_ops_girl_usa/desc")
    icon = "ui/uiskin/currency/decal_order_event.svg"
    cardImage = "https://static-ggc.gaijin.net/chronicle/item_summer_ops_girl_usa.png"
    mkImage = mkImageCtor([170, 170], [0, 17])
  },
  ["449"] = {
    name = loc("items/stalingrad_2023_event_order")
    description = loc("items/stalingrad_2023_event_order/desc")
    icon = "ui/skin#currency/event_order.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/skin#currency/event_order.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["450"] = {
    name = loc("items/wallposter_battlepass_order")
    description = loc("items/wallposter_battlepass_order/desc")
    gametemplate = "poster_ticket_10"
    worth = 2
    bgImage = "ui/skin#battlepass/bg_poster.avif"
    cardImage = "ui/skin#battlepass/posters.avif"
    cardImageParams = mkImageParams([154, 174], [0, 13])
  },
  ["451"] = {
    name = loc("items/armory2_bonus_portrait_ussr")
    description = loc("items/armory2_bonus_portrait_ussr/desc")
    icon = "ui/portraits/default_portrait.svg"
    cardImage = "!ui/portraits/event/armory2_bonus_portrait_ussr.avif"
    mkImage = mkImageCtor([150, 150])
  },
  ["452"] = {
    name = loc("items/armory2_bonus_portrait_ger")
    description = loc("items/armory2_bonus_portrait_ger/desc")
    icon = "ui/portraits/default_portrait.svg"
    cardImage = "!ui/portraits/event/armory2_bonus_portrait_ger.avif"
    mkImage = mkImageCtor([150, 150])
  },
  ["453"] = {
    name = loc("items/armory2_event_order")
    description = loc("items/armory2_event_order/desc")
    icon = "ui/skin#currency/event_order.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/skin#currency/event_order.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["454"] = {
    name = loc("items/luftfaust_b")
    description = loc("items/luftfaust_b/desc")
    icon = "ui/skin#currency/event_order.svg"
    cardImage = "!ui/shop/weapons/luftfaust_b.avif"
    mkImage = mkImageCtor([350, 200], [0, 0])
  },
  ["455"] = {
    name = loc("squad/axis_pacific_event_pilot_fighter_1")
    description = loc("squadannounce/axis_pacific_event_pilot_fighter_1")
    icon = "ui/skin#research/squad_points_icon.svg"
    cardImage = "!ui/soldiers/japan/axis_pacific_event_pilot_fighter_1_image.avif"
    mkImage = mkImageCtor([300, 225], [0, 0])
  },
  ["456"] = {
    name = loc("squad/allies_pacific_event_pilot_fighter_1")
    description = loc("squadannounce/allies_pacific_event_pilot_fighter_1")
    icon = "ui/skin#research/squad_points_icon.svg"
    cardImage = "!ui/soldiers/usa/allies_pacific_event_pilot_fighter_1_image.avif"
    mkImage = mkImageCtor([300, 225], [0, 0])
  },
  ["457"] = {
    name = loc("decals/uk_no_2_sqn_fox_head")
    description = loc("decals/uk_no_2_sqn_fox_head/desc")
    icon = "ui/uiskin/currency/decal_order_event.svg"
    cardImage = "!ui/skin#battlepass/silver_weapons.avif"
    mkImage = mkImageCtor([170, 170], [0, 17])
  },
  ["458"] = {
    name = loc("squad/squad_uk_paratrooper_2_event_2")
    description = loc("squadannounce/squad_uk_paratrooper_2_event_2")
    icon = "ui/skin#research/squad_points_icon.svg"
    cardImage = "!ui/soldiers/usa/squad_uk_paratrooper_2_event_2_image.avif"
    mkImage = mkImageCtor([300, 225], [0, 0])
  },
  ["459"] = {
    name = loc("squad/squad_it_paratrooper_2_event_2")
    description = loc("squadannounce/squad_it_paratrooper_2_event_2")
    icon = "ui/skin#research/squad_points_icon.svg"
    cardImage = "!ui/soldiers/germany/squad_it_paratrooper_2_event_2_image.avif"
    mkImage = mkImageCtor([300, 225], [0, 0])
  },
  ["460"] = {
    name = loc("items/italyParatroopers_event_order")
    description = loc("items/italyParatroopers_event_order/desc")
    icon = "ui/skin#currency/event_order.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/skin#currency/event_order.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["461"] = {
    name = loc("currency/silver_currency")
    description = loc("currency/silver_currency_desc")
    icon = "!ui/uiskin/currency/enlisted_silver.svg"
    gametemplate = "item_silver_coin"
    worth = 0.5
    bgImage = "ui/skin#battlepass/bg_other.avif"
    cardImage = "ui/skin#battlepass/silver_coins.avif"
    cardImageParams = mkImageParams([166, 136], [0, -4])
  },
  ["476"] = {
    name = loc("items/armory3_event_order")
    description = loc("items/armory3_event_order/desc")
    icon = "ui/skin#currency/event_order.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/skin#currency/event_order.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["477"] = {
    name = loc("items/armory3_bonus_portrait_italy")
    description = loc("items/armory3_bonus_portrait_italy/desc")
    icon = "ui/portraits/default_portrait.svg"
    cardImage = "!ui/portraits/event/armory3_bonus_portrait_italy.avif"
    mkImage = mkImageCtor([150, 150])
  },
  ["478"] = {
    name = loc("items/armory3_bonus_portrait_britain")
    description = loc("items/armory3_bonus_portrait_britain/desc")
    icon = "ui/portraits/default_portrait.svg"
    cardImage = "!ui/portraits/event/armory3_bonus_portrait_britain.avif"
    mkImage = mkImageCtor([150, 150])
  },
  ["479"] = {
    name = loc("squad/squad_ussr_paratrooper_2_event_1")
    description = loc("squadannounce/squad_ussr_paratrooper_2_event_1")
    icon = "ui/skin#research/squad_points_icon.svg"
    cardImage = "!ui/soldiers/ussr/squad_ussr_paratrooper_2_event_1_image.avif"
    mkImage = mkImageCtor([300, 225], [0, 0])
  },
  ["481"] = {
    name = loc("items/battlepass_11_portrait")
    icon = "ui/portraits/default_portrait.svg"
    cardImage = "!ui/portraits/event/battlepass_11_portrait.avif"
    mkImage = mkImageCtor([150, 150])
  },
  ["482"] = {
    name = loc("items/nickFrame")
    description = loc("items/nickFrame/desc")
    icon = "ui/skin#currency/nickframe_order_event.svg"
    bgImage = "ui/skin#battlepass/bg_other.avif"
    cardImage = "ui/skin#battlepass/nickframe_bp.avif"
    cardImageParams = mkImageParams([160, 178])
  },
  ["484"] = {
    name = loc("decorator/birthday2_bonus_portrait_tanker")
    description = loc("decorator/birthday2_bonus_portrait_tanker/desc")
    icon = "ui/portraits/default_portrait.svg"
    cardImage = "!ui/portraits/event/birthday2_bonus_portrait_tanker.avif"
    mkImage = mkImageCtor([150, 150])
  },
  ["485"] = {
    name = loc("decorator/birthday2_bonus_portrait_pilot")
    description = loc("decorator/birthday2_bonus_portrait_pilot/desc")
    icon = "ui/portraits/default_portrait.svg"
    cardImage = "!ui/portraits/event/birthday2_bonus_portrait_pilot.avif"
    mkImage = mkImageCtor([150, 150])
  },
  ["486"] = {
    name = loc("items/ussr_hero_birthday_2023")
    description = loc("items/ussr_hero_birthday_2023/desc")
    icon = "ui/squads/ussr/ussr_hero_medal_1_icon.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/squads/ussr/ussr_hero_medal_1_icon.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["487"] = {
    name = loc("items/birthday2_event_order")
    description = loc("items/birthday2_event_order/desc")
    icon = "ui/skin#currency/event_order.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/skin#currency/event_order.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["490"] = {
    name = loc("squad/ussr_berlin_event_assault_2")
    description = loc("squadannounce/ussr_berlin_event_assault_2")
    icon = "ui/skin#research/squad_points_icon.svg"
    cardImage = "ui/skin#research/squad_points_icon.svg"
    mkImage = mkImageCtor([150, 150], [0, 0])
  },
  ["491"] = {
    name = loc("squad/ger_berlin_event_assault_1")
    description = loc("squadannounce/ger_berlin_event_assault_1")
    icon = "ui/skin#research/squad_points_icon.svg"
    cardImage = "ui/skin#research/squad_points_icon.svg"
    mkImage = mkImageCtor([150, 150], [0, 0])
  },
  ["492"] = {
    name = loc("decorator/usentry_bonus_portrait")
    description = loc("decorator/usentry_bonus_portrait/desc")
    icon = "ui/portraits/default_portrait.svg"
    cardImage = "!ui/portraits/event/usentry_bonus_portrait.avif"
    mkImage = mkImageCtor([150, 150])
  },
  ["493"] = {
    name = loc("decals/new_year24_event_decal")
    description = loc("decals/new_year24_event_decal/desc")
    icon = "ui/skin#currency/decal_order_event.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/skin#currency/decal_order_event.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["494"] = {
    name = loc("items/nickFrame")
    description = loc("items/nickFrame/desc")
    icon = "ui/skin#currency/nickframe_order_event.svg"
    bgImage = "ui/skin#battlepass/bg_other.avif"
    cardImage = "ui/skin#battlepass/nickframe_bp.avif"
    cardImageParams = mkImageParams([160, 178])
  },
  ["495"] = {
    name = loc("decorator/snowshoes")
    description = loc("decorator/snowshoes/desc")
    icon = "ui/skin#currency/decal_order_event.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/skin#currency/decal_order_event.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["496"] = {
    name = loc("decorator/ski")
    description = loc("decorator/ski/desc")
    icon = "ui/skin#currency/decal_order_event.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/skin#currency/decal_order_event.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["497"] = {
    name = loc("items/wallposter_battlepass_order")
    description = loc("items/wallposter_battlepass_order/desc")
    gametemplate = "poster_ticket_12"
    worth = 2
    bgImage = "ui/skin#battlepass/bg_poster.avif"
    cardImage = "ui/skin#battlepass/posters.avif"
    cardImageParams = mkImageParams([154, 174], [0, 13])
  },
  ["498"] = {
    name = loc("items/battlepass_12_portrait")
    icon = "!ui/portraits/default_portrait.svg"
    cardImage = "!ui/portraits/event/battlepass_12_portrait.avif"
    mkImage = mkImageCtor([150, 150])
  },
  ["499"] = {
    name = loc("squad/squad_uk_apc_driver_2_event_1")
    description = loc("squadannounce/squad_uk_apc_driver_2_event_1")
    icon = "ui/skin#research/squad_points_icon.svg"
    cardImage = "!ui/soldiers/usa/squad_uk_apc_driver_2_event_1_image.avif"
    mkImage = mkImageCtor([300, 225], [0, 0])
  },
  ["500"] = {
    name = loc("squad/squad_ger_apc_driver_2_event_1")
    description = loc("squadannounce/squad_ger_apc_driver_2_event_1")
    icon = "ui/skin#research/squad_points_icon.svg"
    cardImage = "!ui/soldiers/germany/squad_ger_apc_driver_2_event_1_image.avif"
    mkImage = mkImageCtor([300, 225], [0, 0])
  },
  ["501"] = {
    name = loc("items/ger_pelzmutze_m43_closed_1")
    description = loc("items/ger_pelzmutze_m43_closed_1/desc")
    icon = "!ui/portraits/default_portrait.svg"
    gametemplate = "pelzmutze_m43_close_01_ger_winter_item"
    worth = 2
    cardImage = "ui/skin#battlepass/battle_pass_ger_outfit_1.avif"
    bgImage = "ui/skin#battlepass/bg_other.avif"
    mkImage = mkImageCtor([180, 180], [0, -5])
  },
  ["504"] = {
    name = loc("items/lunarNewyear24_bonus_portrait")
    icon = "!ui/portraits/default_portrait.svg"
    cardImage = "!ui/portraits/event/lunarNewyear24_bonus_portrait.avif"
    mkImage = mkImageCtor([150, 150])
  },
  ["505"] = {
    name = loc("items/nickFrame")
    description = loc("items/nickFrame/desc")
    icon = "ui/skin#currency/nickframe_order_event.svg"
    bgImage = "ui/skin#battlepass/bg_other.avif"
    cardImage = "ui/skin#battlepass/nickframe_bp.avif"
    cardImageParams = mkImageParams([160, 178])
  },
  ["506"] = {
    name = loc("decals/usa_1st_armoured_division")
    description = loc("decals/usa_1st_armoured_division/desc")
    icon = "ui/skin#currency/decal_order_event.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/skin#currency/decal_order_event.svg"
    mkImage = mkImageCtor([72, 100])
  },
  ["507"] = {
    name = loc("items/engineerDay24_bonus_portrait")
    icon = "!ui/portraits/default_portrait.svg"
    cardImage = "!ui/portraits/event/engineerDay24_bonus_portrait.avif"
    mkImage = mkImageCtor([150, 150])
  },
  ["508"] = {
    name = loc("squad/squad_ger_engineer_2_event_1")
    description = loc("squadannounce/squad_ger_engineer_2_event_1")
    icon = "ui/skin#research/squad_points_icon.svg"
    cardImage = "!ui/soldiers/germany/squad_ger_engineer_2_event_1_image.avif"
    mkImage = mkImageCtor([210, 157], [0, 0])
  },
  ["509"] = {
    name = loc("squad/squad_ussr_engineer_2_event_1")
    description = loc("squadannounce/squad_ussr_engineer_2_event_1")
    icon = "ui/skin#research/squad_points_icon.svg"
    cardImage = "!ui/soldiers/ussr/squad_ussr_engineer_2_event_1_image.avif"
    mkImage = mkImageCtor([210, 157], [0, 0])
  },
  ["510"] = {
    name = loc("items/m1911a1_colt_nickel")
    description = loc("items/m1911a1_colt_nickel/desc")
    icon = "ui/skin#currency/event_order.svg"
    cardImage = "!ui/shop/weapons/m1911a1_colt_nickel.avif"
    mkImage = mkImageCtor([350, 200], [0, 0])
  },
  ["511"] = {
    icon = "ui/skin#battlepass/base_booster_icon.svg"
    worth = 2
    bgImage = "ui/skin#battlepass/bg_boost.avif"
    cardImage = "ui/skin#battlepass/boost_global.avif"
    cardImageParams = mkImageParams([154, 144], [0, 15])
  },
  ["514"] = {
    name = loc("decorator/zombie_bonus_portrait_A")
    icon = "!ui/portraits/default_portrait.svg"
    cardImage = "!ui/portraits/event/zombie_bonus_portrait_A.avif"
    mkImage = mkImageCtor([150, 150])
  },
  ["515"] = {
    name = loc("decorator/zombie_bonus_portrait_B")
    icon = "!ui/portraits/default_portrait.svg"
    cardImage = "!ui/portraits/event/zombie_bonus_portrait_B.avif"
    mkImage = mkImageCtor([150, 150])
  },
  ["516"] = {
    name = loc("items/nickFrame")
    description = loc("items/nickFrame/desc")
    icon = "ui/skin#currency/nickframe_order_event.svg"
    bgImage = "ui/skin#battlepass/bg_other.avif"
    cardImage = "ui/skin#battlepass/nickframe_bp.avif"
    cardImageParams = mkImageParams([160, 178])
  },



  // boosters presentation
  ["mech_event_weapon_prize"] = defRewardPresentation.__merge({
    name = loc("items/mech_event_crate")
    description = loc("items/mech_event_crate/desc")
    icon = "ui/skin#currency/random_reward_order.svg"
    bgImage = "ui/skin#battlepass/bg_gold.avif"
    cardImage = "!ui/skin#currency/random_reward_order.svg"
    mkImage = mkImageCtor([72, 100]) //432 * 600
  }),
  ["every_day_award_small_pack"] = defRewardPresentation.__merge({
    name = loc("smallTrophyTitle_2")
    cardImage = "ui/skin#rewards/crate_small_2.avif"
    cardImageOpen = "ui/skin#rewards/crate_small_2_open.avif"
  }),
  ["every_day_award_medium_pack"] = defRewardPresentation.__merge({
    name = loc("mediumTrophyTitle_1")
    cardImage = "ui/skin#rewards/crate_medium_1.avif"
    cardImageOpen = "ui/skin#rewards/crate_medium_1_open.avif"
  }),
  ["every_day_award_big_pack"] = defRewardPresentation.__merge({
    name = loc("bigTrophyTitle_1")
    cardImage = "ui/skin#rewards/crate_big_1.avif"
    cardImageOpen = "ui/skin#rewards/crate_big_1_open.avif"
    background = goldRadialGradient
    rewardGlow = "!ui/gameImage/enlisted_box_glow_dark_small.avif"
    progressConfig = {
      textColor = darkTxtColor
      background = goldVerticalGradient
    }
  })
}

return freeze({
  rewardWidthToHeight
  rewardsPresentation
  rewardBgSizePx
  mkReward
})
