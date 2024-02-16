let USA_ICONS = [
  null
  "ui/skin#ranks/usa_rank_1_icon.svg"
  "ui/skin#ranks/usa_rank_2_icon.svg"
  "ui/skin#ranks/usa_rank_3_icon.svg"
  "ui/skin#ranks/usa_rank_4_icon.svg"
  "ui/skin#ranks/usa_rank_5_icon.svg"
]

let USSR_ICONS = [
  null
  "ui/skin#ranks/ussr_rank_1_icon.svg"
  "ui/skin#ranks/ussr_rank_2_icon.svg"
  "ui/skin#ranks/ussr_rank_3_icon.svg"
  "ui/skin#ranks/ussr_rank_4_icon.svg"
  "ui/skin#ranks/ussr_rank_5_icon.svg"
]

let GERMANY_ICONS = [
  null
  "ui/skin#ranks/ger_rank_1_icon.svg"
  "ui/skin#ranks/ger_rank_2_icon.svg"
  "ui/skin#ranks/ger_rank_3_icon.svg"
  "ui/skin#ranks/ger_rank_4_icon.svg"
  "ui/skin#ranks/ger_rank_5_icon.svg"
]

let JAP_ICONS = [
  null
  "ui/skin#ranks/jap_rank_1_icon.svg"
  "ui/skin#ranks/jap_rank_2_icon.svg"
  "ui/skin#ranks/jap_rank_3_icon.svg"
  "ui/skin#ranks/jap_rank_4_icon.svg"
  "ui/skin#ranks/jap_rank_5_icon.svg"
]

let rankIcons = {
  normandy_allies   = USA_ICONS
  normandy_axis     = GERMANY_ICONS
  moscow_allies     = USSR_ICONS
  moscow_axis       = GERMANY_ICONS
  berlin_allies     = USSR_ICONS
  berlin_axis       = GERMANY_ICONS
  tunisia_allies    = USA_ICONS
  tunisia_axis      = GERMANY_ICONS
  stalingrad_allies = USSR_ICONS
  stalingrad_axis   = GERMANY_ICONS
  pacific_allies    = USA_ICONS
  pacific_axis      = JAP_ICONS
  ussr              = USSR_ICONS
  usa               = USA_ICONS
  ger               = GERMANY_ICONS
  jap               = JAP_ICONS
}

// ■□▢▣▤
let USSR_GLYPHS = [
  null, "\xE2\x96\xA0", "\xE2\x96\xA1", "\xE2\x96\xA2", "\xE2\x96\xA3", "\xE2\x96\xA4"
]

// ▥▦▧▨▩
let USA_GLYPHS = [
  null, "\xE2\x96\xA5", "\xE2\x96\xA6", "\xE2\x96\xA7", "\xE2\x96\xA8", "\xE2\x96\xA9"
]

// ▪▫▬▭▮
let GERMANY_GLYPHS = [
  null, "\xE2\x96\xAA", "\xE2\x96\xAB", "\xE2\x96\xAC", "\xE2\x96\xAD", "\xE2\x96\xAE"
]

// ▼▽▾▿◀
let JAP_GLYPHS = [
  null, "\xE2\x96\xBC", "\xE2\x96\xBD", "\xE2\x96\xBE", "\xE2\x96\xBF", "\xE2\x97\x80"
]

let rankGlyphs = {
  normandy_allies = USA_GLYPHS
  normandy_axis   = GERMANY_GLYPHS
  moscow_allies   = USSR_GLYPHS
  moscow_axis     = GERMANY_GLYPHS
  berlin_allies   = USSR_GLYPHS
  berlin_axis     = GERMANY_GLYPHS
  tunisia_allies  = USA_GLYPHS
  tunisia_axis    = GERMANY_GLYPHS
  stalingrad_allies   = USSR_GLYPHS
  stalingrad_axis     = GERMANY_GLYPHS
  pacific_allies   = USA_GLYPHS
  pacific_axis     = JAP_GLYPHS
  ussr              = USSR_GLYPHS
  usa               = USA_GLYPHS
  ger               = GERMANY_GLYPHS
  jap               = JAP_GLYPHS
}

return {
  rankIcons
  rankGlyphs
}
