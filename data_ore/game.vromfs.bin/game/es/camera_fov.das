require ecs
require DagorSystem
require DagorDataBlock


[es(tag=gameClient, on_appear)]
def camera_fov_es(evt : Event; fovLimits : float2; camera__fovSettingsPath : string; var fovSettings : float&)
  var fovFromSettings = fovSettings
  dgs_get_settings() |> datablock_get_block("gameplay") <| $(blk)
    fovFromSettings = blk |> datablock_getReal(camera__fovSettingsPath, fovFromSettings)
  fovSettings = clamp(fovFromSettings, fovLimits.x, fovLimits.y)
