module spectator_common shared
require ecs
require ecs.common
require DngNet
require DagorMath
require strings
require DngCamera
require player
require game.events_game
require game.es.camera_common


def set_spectated(cam_eid : EntityId; var spectatedEid : EntityId&; new_eid : EntityId; initial : bool = false) : void
  if initial == false
    if spectatedEid == new_eid
      return
    if spectatedEid != INVALID_ENTITY_ID
      removeSubTemplate(spectatedEid, "observed_local")
  spectatedEid = new_eid
  if new_eid == INVALID_ENTITY_ID
    return

  let newWatchedByPlr = get_Eid(new_eid, "watchedByPlr") ?? INVALID_ENTITY_ID
  if newWatchedByPlr != INVALID_ENTITY_ID || find(getEntityTemplateName(new_eid), "+observed_local") == -1
    addSubTemplate(new_eid, "observed_local") <| $(var init : ComponentsInitializer)
      init |> set("watchedByPlr", get_local_player_eid())
      init |> set("bindedCamera", cam_eid)
  bind_camera_to_entity(cam_eid, new_eid)

  send_net_event(get_local_player_eid(), [[EventSpectateTarget target_eid=new_eid, initial=initial]])
