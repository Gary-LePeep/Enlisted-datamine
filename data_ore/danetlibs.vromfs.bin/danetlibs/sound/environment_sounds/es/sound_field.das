require ecs
require app
require math.base
require DagorMath
require soundEvent
require soundSystem
require sound_utils_net.modules.sound_utils_net_events
require environment_sounds.modules.sound_field_common


def sample_cell(wpos : float2;
                cells : UInt32List;
                offset : float2;
                num_cells : int2;
                cell_size : float)

  assert(num_cells.x * num_cells.y == length(cells))

  if !empty(cells)

    let cam = float2(safediv((wpos.x - offset.x), cell_size), safediv((wpos.y - offset.y), cell_size))

    let cx = int(floor(cam.x))
    let cz = int(floor(cam.y))

    if cx >= 0 && cx < num_cells.x && cz >= 0 && cz < num_cells.y
      return cells[cx + cz * num_cells.x]

  return empty_cell()



[es(tag=sound, after=sound_begin_update_es, before=sound_end_update_es)]
def sound_field_update(info : ParallelUpdateFrameDelayed;
                       sound_field__vars : StringList;
                       sound_field__cells : UInt32List;
                       sound_field__offset : float2;
                       sound_field__numCells : int2;
                       sound_field__cellSize : float)

  let cell = sample_cell(get_listener_pos().xz, sound_field__cells, sound_field__offset, sound_field__numCells, sound_field__cellSize)

  var idx0, idx1, val0, val1 : uint
  unpack(cell, idx0, idx1, val0, val1)

  for name, idx in sound_field__vars, range(length(sound_field__vars))
    let v = uint(idx) == idx0 ? float(val0) / 255. : uint(idx) == idx1 ? float(val1) / 255. : 0.
    set_var_global(string(name), v)


[es(tag=sound, on_disappear)]
def sound_field_disappear(evt : Event;
                          sound_field__vars : StringList)

  for name in sound_field__vars
    set_var_global(string(name), 0.)
