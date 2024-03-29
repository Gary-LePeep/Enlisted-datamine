from "%enlSqGlob/ui/ui_library.nut" import *

let codes_by_countries = {
  RU = {
    Russia="RU",
    Belarus="BY",
    ["Kazakhstan"]="KZ",
    ["Kyrgyzstan"]="KG",
    ["Turkmenistan"]="TM",
    ["Uzbekistan"]="UZ",
    ["Armenia"]="AM",
    ["Azerbaijan"]="AZ",
    ["Georgia"]="GE",
    Poland="PL",
    Estonia="EE",
    Finland="FI",
    Latvia="LV",
    Lithuania="LT",
    Hungary="HU",
    Sweden="SE",
    Bulgaria="BG",
    Croatia="HR",
    Serbia="RS",
    Slovakia="SK",
    Slovenia="SI",
    Moldova="MD",
  },

  EU={
    Albania="AL",
    Andorra="AD",
    Austria="AT",
    Belgium="BE",
    Bosnia="and",
    Cyprus="CY",
    ["Czech Republic"]="CZ",
    Denmark="DK",
    ["Faroe Islands"]="FO",
    France="FR",
    Germany="DE",
    Gibraltar="GI",
    Greece="GR",
    Iceland="IS",
    Ireland="IE",
    ["Isle of Man"]="IM",
    Italy="IT",
    Liechtenstein="LI",
    Luxembourg="LU",
    Macedonia="MK",
    Malta="MT",
    Monaco="MC",
    Montenegro="ME",
    Netherlands="NL",
    Norway="NO",
    Portugal="PT",
    Romania="RO",
    ["San Marino"]="SM",
    Spain="ES",
    Switzerland="CH",
    Ukraine="UA",
    ["United Kingdom"]="GB",
    ["Vatican city"]="VA",
  }
  SOUTHAMERICA={
  //south america
    Argentina="AR",
    Bolivia="BO",
    Brazil="BR",
    Chile="CL",
    Colombia="CO",
    Ecuador="EC",
    ["Falkland Islands"]="FK",
    ["French Guiana"]="GF",
    Guiana="GY",
    Guyana="GY",
    Paraguay="PY",
    Peru="PE",
    Suriname="SR",
    Uruguay="UY",
    Venezuela="V",
  }
  NORTHAMERICA={
    ["Anguilla"]="AI",
    ["Antigua and Barbuda"]="AG",
    ["Aruba"]="AW",
    ["Bahamas"]="BS",
    ["Barbados"]="BB",
    ["Belize"]="BZ",
    ["Bermuda"]="BM",
    ["Bonaire"]="BQ",
    ["British Virgin Islands"]="VG",
    ["Canada"]="CA",
    ["Cayman Islands"]="KY",
    ["Costa Rica"]="CR",
    ["Cuba"]="CU",
    ["Curacao"]="CW",
    ["Dominica"]="DM",
    ["Dominican Republic"]="DO",
    ["El Salvador"]="SV",
    ["Greenland"]="GL",
    ["Grenada and Carriacuou"]="GD",
    ["Guadeloupe"]="GP",
    ["Guatemala"]="GT",
    ["Haiti"]="HT",
    ["Honduras"]="HN",
    ["Jamaica"]="JM",
    ["Martinique"]="MQ",
    ["Mexico"]="MX",
    ["Miquelon"]="PM",
    ["Montserrat"]="MS",
    ["Netherlands Antilles"]="CW",
    ["Nevis"]="KN",
    ["Nicaragua"]="NI",
    ["Panama"]="PA",
    ["Puerto Rico"]="PR",
    ["Saba"]="BQ",
    ["Sint Eustatius"]="BQ",
    ["Sint Maarten"]="SX",
    ["St. Kitts"]="KN",
    ["St. Lucia"]="LC",
    ["St. Pierre and Miquelon"]="PM",
    ["St. Vincent"]="VC",
    ["Trinidad and Tobago"]="TT",
    ["Turks and Caicos Islands"]="TC",
    ["United States"]="US",
    ["US Virgin Islands"]="VI",
  },
  ASIA = {
    ["Afghanistan"]="AF",
    ["Bahrain"]="BH",
    ["Bangladesh"]="BD",
    ["Bhutan"]="BT",
    ["Brunei"]="BN",
    ["Cambodia"]="KH",
    ["Christmas Island"]="CX",
    ["Cocos Islands"]="CC",
    ["Diego Garcia"]="IO",
    ["Hong Kong"]="HK",
    ["Indonesia"]="ID",
    ["Iran"]="IR",
    ["Iraq"]="IQ",
    ["Israel"]="IL",
    ["Jordan"]="JO",
    ["Kuwait"]="KW",
    ["Lebanon"]="LB",
    ["Maldives"]="MV",
    ["Oman"]="OM",
    ["Pakistan"]="PK",
    ["Palestine"]="PS",
    ["Qatar"]="QA",
    ["Saudi Arabia"]="SA",
    ["Syria"]="SY",
    ["Tajikistan"]="TJ",
    ["Turkey"]="TR",
    ["United Arab Emirates"]="AE",
    ["Yemen"]="YE",
  },
  EAST_ASIA = {
    ["China"]="CN",
    ["India"]="IN",
    ["Japan"]="JP",
    ["Laos"]="LA",
    ["Macau"]="MO",
    ["Malaysia"]="MY",
    ["Mongolia"]="MN",
    ["Myanmar"]="MM",
    ["Nepal"]="NP",
    ["North Korea"]="KP",
    ["Philippines"]="PH",
    ["Singapore"]="SG",
    ["South Korea"]="KR",
    ["Sri Lanka"]="LK",
    ["Taiwan"]="TW",
    ["Thailand"]="TH",
    ["Vietnam"]="VN",
  },
  OCEANIA={
    ["American Samoa"]="AS",
    ["Australia"]="AU",
    ["Chatham Island, NZ"]="NZ",
    ["Cook Islands"]="CK",
    ["East Timor"]="TL",
    ["Federated States of Micronesia"]="FM",
    ["Fiji Islands"]="FJ",
    ["French Polynesia"]="PF",
    ["Guam"]="GU",
    ["Kiribati"]="KI",
    ["Mariana Islands"]="MP",
    ["Marshall Islands"]="MH",
    ["Midway Islands"]="UM",
    ["Nauru"]="NR",
    ["New Caledonia"]="NC",
    ["New Zealand"]="NZ",
    ["Niue"]="NU",
    ["Norfolk Island"]="NF",
    ["Palau"]="PW",
    ["Papua New Guinea"]="PG",
    ["Saipan"]="MP",
    ["Samoa"]="WS",
    ["Solomon Islands"]="SB",
    ["Tokelau"]="TK",
    ["Tonga"]="TO",
    ["Tuvalu"]="TV",
    ["Vanuatu"]="VU",
    ["Wake Island"]="UM",
    ["Wallis and Futuna Islands"]="WF",
  }
}
let clusterByRegionMap = {EU="EU", NORTHAMERICA="US", SOUTHAMERICA="US", OCEANIA="US", ASIA="RU", EAST_ASIA="JP", RU="RU"}

function getClusterByCode(params = { code = null }){
  let clusterByRegion = params?.clusterByRegionMap ?? clusterByRegionMap
  let codesByCountries = params?.codes_by_countries ?? codes_by_countries
  let curcode = params.code
  local foundCountry = "unlisted"
  local foundRegion="EU"
  local haveFound=false
  foreach (region, codes in codesByCountries){
    foreach (country, code in codes){
      if (curcode==code){
        foundRegion=region
        foundCountry=country
        haveFound = true
        break
      }
    }
    if (haveFound)
      break
  }
  return {region=foundRegion, cluster=clusterByRegion?[foundRegion] ?? "EU", country=foundCountry}
}

return {
  getClusterByCode
  clusterByRegionMap
  codes_by_countries
}
