import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui/ui_library.nut" import *

let isZombieMode = Watched(false)
let zombieModeCurWave = Watched(0)
let zombiesAliveCount = Watched(0)
let zombiesNextWaveAtTime = Watched(0)
let zombieCurWaveCount = Watched(0)
let zombieCurWaveAlreadySpawn = Watched(0)
let zombieModeHeroPoints = Watched(0)

let {mkCountdownTimerPerSec} = require("%ui/helpers/timers.nut")
let zombiesNextWaveTime = mkCountdownTimerPerSec(zombiesNextWaveAtTime)

ecs.register_es("capzone_capture_mode_state",
  {
    [["onInit","onChange"]] = function(_eid,comp) {
      isZombieMode(true)
      zombieModeCurWave(comp["entity_spawner__curWaveId"])
      zombiesAliveCount(comp["entity_spawner__aliveZombiesCount"])
      zombiesNextWaveAtTime(comp["entity_spawner__nextWaveAtTime"])
      zombieCurWaveCount(comp["entity_spawner__counstSpawnInWave"])
      zombieCurWaveAlreadySpawn(comp["entity_spawner__alreadySpawnInWave"])
    },
  },
  {
    comps_track = [
      ["entity_spawner__aliveZombiesCount", ecs.TYPE_INT],
      ["entity_spawner__counstSpawnInWave", ecs.TYPE_INT],
      ["entity_spawner__alreadySpawnInWave", ecs.TYPE_INT],
      ["entity_spawner__nextWaveAtTime", ecs.TYPE_FLOAT],
      ["entity_spawner__curWaveId", ecs.TYPE_INT],
    ]
  }
)

ecs.register_es("zombie_mode_shop_points",
  {
    [["onInit","onChange"]] = function(_eid,comp) {
      zombieModeHeroPoints(comp["paid_loot__points"])
    },
  },
  {
    comps_rq = ["watchedByPlr"]
    comps_track = [["paid_loot__points", ecs.TYPE_INT]]
  }
)


return {
  isZombieMode
  zombieModeCurWave
  zombieCurWaveCount
  zombieCurWaveAlreadySpawn
  zombieModeHeroPoints
  zombiesAliveCount
  zombiesNextWaveTime
}
