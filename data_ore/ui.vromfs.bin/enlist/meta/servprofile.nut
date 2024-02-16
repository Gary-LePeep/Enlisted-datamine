from "%enlSqGlob/ui_library.nut" import *
let { sourceProfileData, profileStructure } = require("sourceServProfile.nut")

return profileStructure.map(@(_, k) Computed(@() sourceProfileData.value[k]))
