require app
require ecs
require ecs.common
require soundSystem


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=(animchar_before_render_es, sound_begin_update_es), before=sound_end_update_es)]
def manage_sound_control(evt : Event;
                         sound_control_group_idx : int;
                         manage_sound_control__maxInstances : int;
                         manage_sound_control__cooldown : float;
                         var manage_sound_control__entities : EidList&;
                         var manage_sound_control__positions : Point3List&)

  let listener = get_listener_pos()
  let curTime = get_sync_time()
  let curGroupIdx = sound_control_group_idx

  query() <| $ [es] (eid : EntityId;
                     sound_control_group_idx : int;
                     var sound_control__allowSound : bool&;
                     manageable_sound_control__nextTimeToAllow : float;
                     transform : float3x4)

    if sound_control_group_idx != curGroupIdx
      return

    let pos = transform[3]
    let idx = find_index(manage_sound_control__entities, eid)

    if idx >= 0
      sound_control__allowSound = true
      manage_sound_control__positions[idx] = pos
      return

    if curTime < manageable_sound_control__nextTimeToAllow
      return

    if length(manage_sound_control__entities) < manage_sound_control__maxInstances
      sound_control__allowSound = true
      manage_sound_control__entities |> push(eid)
      manage_sound_control__positions |> push(pos)
      return

    let raceAvoidAndTemporalDesyncFixDistMul = 1.1
    let distSq = length_sq((pos - listener) * raceAvoidAndTemporalDesyncFixDistMul)

    var furthestIdx = -1
    var furthestDistSq = 0.

    for i in range(length(manage_sound_control__entities))
      let otherPos = manage_sound_control__positions[i]
      let otherDistSq = distance_sq(otherPos, listener)

      if otherDistSq > furthestDistSq && distSq < otherDistSq
        furthestDistSq = otherDistSq;
        furthestIdx = i

    if furthestIdx >= 0
      query(manage_sound_control__entities[furthestIdx]) <| $ [es] (var sound_control__allowSound : bool&;
                                                                    var manageable_sound_control__nextTimeToAllow : float&)
        sound_control__allowSound = false
        manageable_sound_control__nextTimeToAllow = curTime + manage_sound_control__cooldown

      sound_control__allowSound = true
      manage_sound_control__entities[furthestIdx] = eid
      manage_sound_control__positions[furthestIdx] = pos
    else
      sound_control__allowSound = false
