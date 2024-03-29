require ecs
require app

def artillery_start(tpl_name : string; offender, ownerPlayer : EntityId; sourcePos, targetPos, targetPosEnd : float3)
  createEntity(tpl_name) <| $(var init : ComponentsInitializer)
    set(init, "artillery__offender", offender)
    set(init, "artillery__callerEid", ownerPlayer)
    set(init, "artillery__sourcePos", sourcePos)
    set(init, "artillery__targetPos", targetPos)
    set(init, "artillery__targetPosEnd", targetPosEnd)


[es(tag=server, on_appear, REQUIRE=artilleryStrikeRequester)]
def artillery_strike_requester_on_appear(evt : Event;
                                         artillery__baseInterval : float;
                                         artillery__lastShotInTime : float;
                                         artillery__baseSpawnDelay : float;
                                         artillery__missionStartDelay : float;
                                         var artillery__spawnDelay : float&;
                                         var artillery__availableAtTime : float&;
                                         var artillery__interval : float&)
  var missionStartCooldownEndTime = -1.0
  query() <| $ [es] (level__loadedAtTime : float)
    missionStartCooldownEndTime = level__loadedAtTime + artillery__missionStartDelay

  artillery__interval   = artillery__baseInterval
  artillery__spawnDelay = artillery__baseSpawnDelay
  let spawnCooldownEndTime = get_sync_time() + artillery__spawnDelay
  let cooldownEndTime = max(missionStartCooldownEndTime, spawnCooldownEndTime)
  artillery__availableAtTime = (artillery__lastShotInTime < 0.0
                                ? cooldownEndTime
                                : max(cooldownEndTime, artillery__lastShotInTime + artillery__interval))


[es(tag=server, no_order, REQUIRE=artilleryStrikeRequester)]
def artillery_strike_requester_update(info : UpdateStageInfoAct;
                                      eid : EntityId;
                                      transform : float3x4;
                                      artilleryStrikeTemplate : string;
                                      artilleryStrikeSpawnPeriod : float;
                                      artilleryStrikeHeightOffset : float;
                                      var artilleryStrikeSpawnTime : float&)
  if artilleryStrikeSpawnTime < 0.0
    var sourcePos = transform[3]
    sourcePos.y += artilleryStrikeHeightOffset
    artillery_start(artilleryStrikeTemplate, eid, eid, sourcePos, transform[3], transform[3])
    artilleryStrikeSpawnTime = artilleryStrikeSpawnPeriod
  else
    artilleryStrikeSpawnTime -= info.dt
