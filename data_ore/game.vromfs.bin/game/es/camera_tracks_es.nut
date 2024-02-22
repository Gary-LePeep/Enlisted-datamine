import "%dngscripts/ecs.nut" as ecs
let demo_track_player = require("demo_track_player.nut")


ecs.register_es("camera_track_active_es",
  {
    onInit = @(eid, comp) demo_track_player.trackPlayerStart(eid, comp.camera_tracks?.getAll(), 0.1, 0.15),
    onDestroy = @(_eid, _comp) demo_track_player.trackPlayerStop()
  },
  {
    comps_ro = [["camera_tracks", ecs.TYPE_ARRAY]],
    comps_no = ["benchmark_name"]
  },
  {tags="gameClient"}
)
