require ecs

[es(on_event=OnCameraTrackFinishCycle, tag=gameClient)]
def destroy_camera_track_on_cycles_finished_es(evt : Event; eid : EntityId; var camera_tracks__cycles : int&)
  camera_tracks__cycles -= 1
  if camera_tracks__cycles <= 0
    destroyEntity(eid)
