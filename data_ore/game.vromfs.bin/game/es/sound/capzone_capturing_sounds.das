require ecs
require ecs.common
require soundEvent
require enlisted.events_enlisted
require game.events_game
require game.utils.team
require DagorDataBlock
require DagorSystem


[es(tag=sound, on_appear)]
def capzone_capturing_sound_enabled_init(evt : Event; var human__capzoneCapturingSoundEnabled : bool&)
  human__capzoneCapturingSoundEnabled = dgs_get_settings() |> datablock_get_block_by_name("sound") |> datablock_getBool("human_capzone_capturing_sound_enabled", true)


[es(tag=sound)]
def capzone_capturing_sounds_on_captured(evt : EventZoneCaptured;
                                         eid aka capzone_eid : EntityId;
                                         capzone__alwaysHide : bool)
  if evt.zone == capzone_eid && !capzone__alwaysHide
    find_query() <| $ [es(REQUIRE=hero)] (team aka hero_team : int;
                                          capturer__capZonesIn : EidList;
                                          human__capzoneCapturedSoundPath : string)
      if is_teams_friendly(hero_team, evt.team) && find_index(capturer__capZonesIn, capzone_eid) >= 0
        oneshot(human__capzoneCapturedSoundPath)
      return true


def is_hero_capturing_something(capturer__capZonesIn : EidList; hero_team : int; is_downed, is_in_vehicle : bool) : bool
  var isCapturing = false
  for zoneEid in capturer__capZonesIn
    // query(eid) is better than find_query() here because capturer__capZonesIn.length <= 1 in most cases
    query(zoneEid) <| $ [es(REQUIRE_NOT=(trainZone, trainTriggerable))] (capzone__captureStatus : int; capzone__capTeam : int; zone__excludeDowned : ecs::Tag const?; capzone__canCaptureOnVehicle : bool)
      isCapturing ||= (capzone__captureStatus != 0 &&
                       is_teams_friendly(hero_team, capzone__capTeam) &&
                       (!is_downed || zone__excludeDowned == null) &&
                       (!is_in_vehicle || capzone__canCaptureOnVehicle))
  return isCapturing


[es(tag=sound, REQUIRE=hero, track=(capturer__capZonesIn, isAlive, isDowned, isInVehicle, human__capzoneCapturingSoundEnabled), on_appear)]
def capzone_capturing_sounds_track_hero_zones_in(evt : Event;
                                                 capturer__capZonesIn : EidList;
                                                 team aka hero_team : int;
                                                 isAlive, isDowned : bool;
                                                 isInVehicle : bool = false;
                                                 human__capzoneCapturingSoundPath : string;
                                                 human__capzoneCapturingSoundEnabled : bool;
                                                 var human__capzoneCapturingSoundEvent : SoundEvent&)
  let isCapturing = isAlive && human__capzoneCapturingSoundEnabled && is_hero_capturing_something(capturer__capZonesIn, hero_team, isDowned, isInVehicle)
  if human__capzoneCapturingSoundEvent.enabled != isCapturing
    human__capzoneCapturingSoundEvent.enabled = isCapturing
    release(human__capzoneCapturingSoundEvent.handle)
    if isCapturing
      human__capzoneCapturingSoundEvent |> play(human__capzoneCapturingSoundPath)


[es(tag=sound, track=(capzone__captureStatus, capzone__capTeam), REQUIRE=(capzone__captureStatus, capzone__capTeam), REQUIRE_NOT=(trainZone, trainTriggerable))]
def capzone_capturing_sounds_track_capture_status(evt : Event)
  query() <| $ [es(REQUIRE=hero)] (capturer__capZonesIn : EidList;
                                   team aka hero_team : int;
                                   isAlive, isDowned : bool;
                                   isInVehicle : bool = false;
                                   human__capzoneCapturingSoundPath : string;
                                   human__capzoneCapturingSoundEnabled : bool;
                                   var human__capzoneCapturingSoundEvent : SoundEvent&)
    let isCapturing = isAlive && human__capzoneCapturingSoundEnabled && is_hero_capturing_something(capturer__capZonesIn, hero_team, isDowned, isInVehicle)
    if human__capzoneCapturingSoundEvent.enabled != isCapturing
      human__capzoneCapturingSoundEvent.enabled = isCapturing
      release(human__capzoneCapturingSoundEvent.handle)
      if isCapturing
        human__capzoneCapturingSoundEvent |> play(human__capzoneCapturingSoundPath)


[es(tag=sound, REQUIRE=hero, track=isAlive)]
def capzone_capturing_sounds_track_is_alive(evt : Event;
                                            isAlive : bool;
                                            var human__capzoneCapturingSoundEvent : SoundEvent&)
  if !isAlive
    release(human__capzoneCapturingSoundEvent.handle)


[es(tag=sound, REQUIRE=hero, on_disappear)]
def capzone_capturing_sounds_disappear(evt : Event;
                                       var human__capzoneCapturingSoundEvent : SoundEvent&)
  release(human__capzoneCapturingSoundEvent.handle)
