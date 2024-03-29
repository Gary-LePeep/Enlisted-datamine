import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui/ui_library.nut" import *

let {fontBody} = require("%enlSqGlob/ui/fontsStyle.nut")
let {tipCmp} = require("%ui/hud/huds/tips/tipComponent.nut")
let {EventEntityDied} = require("dasevents")
let {get_shell_template_by_shell_id, DM_EXPLOSION} = require("dm")

let showTip = Watched(false)

const TIP_SHOW_TIME = 5

let hideTip = @() showTip(false)

ecs.register_es(
  "show_bomb_tip_es",
  {
    [EventEntityDied] = function(evt, _eid, _comp) {
      let { shellId, damageType } = evt

      let shellTemplateName = get_shell_template_by_shell_id(shellId) ?? ""
      if (shellTemplateName == "")
        return

      let shellTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(shellTemplateName)
      let isBomb = shellTemplate?.getCompValNullable("projectile__isBomb") != null

      if (damageType != DM_EXPLOSION || !isBomb)
        return

      if (!showTip.value) {
        showTip(true)
        gui_scene.resetTimeout(TIP_SHOW_TIME, hideTip)
      }
    }
  },
  {
    comps_rq = ["watchedByPlr"]
  }
)

let explTip = tipCmp({
  text = loc("hint/lieDownToSaveFromExplosion")
  style = {
    onAttach = @() gui_scene.resetTimeout(TIP_SHOW_TIME, hideTip)
    onDetach = hideTip
  }
}.__update(fontBody))

let lie_down_to_save_from_expl_tip = @() {
  watch = showTip
  children = showTip.value ? explTip : null
}

return lie_down_to_save_from_expl_tip