require ecs


def make_wave_id(next_wave_at_time : float; cur_wave_id : int)
  return next_wave_at_time < 0. ? cur_wave_id : -1


[es(tag=sound, track=(entity_spawner__nextWaveAtTime, entity_spawner__curWaveId))]
def entity_spawner_battle_music(evt : Event;
                                entity_spawner__nextWaveAtTime : float;
                                entity_spawner__curWaveId : int)
  query() <| $ [es] (var battle_music__waveId : int&)
    battle_music__waveId = make_wave_id(entity_spawner__nextWaveAtTime, entity_spawner__curWaveId)
