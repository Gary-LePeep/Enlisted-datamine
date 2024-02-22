module sound_field_generator_common shared

require ecs
require DagorMath
require environment_sounds.modules.sound_field_common


struct Biome
  transforms : array<float3x4>
  alpha2Value : float2
  extent : float


def private get(x, y : int; field : array<float>; num_cells : int2)
  return field[x + y * num_cells.x]


def private set(f : float; x, y : int; var field : array<float>&; num_cells : int2)
  field[x + y * num_cells.x] = f


def private replace(f : float; x, y : int; var field : array<float>&; num_cells : int2)
  let idx = x + y * num_cells.x
  field[idx] = max(f, field[idx])


def private append(f : float; x, y : int; var field : array<float>&; num_cells : int2)
  field[x + y * num_cells.x] += f


def private max_radius(tm : float3x4; extent : float) : float2
  let x = max(tm[0].x, tm[0].z) + extent
  return float2(x, x)


def private init_field(var field : array<float>&; val : float)
  for f in field
    f = val

def private neighbor_blend(num_cells : int2;
                           var field : array<float>&)

  for z in range(0, num_cells.y - 1)
    for x in range(0, num_cells.x - 1)
      let c = get(x, z, field, num_cells)
      let cx = (get(x + 1, z, field, num_cells) + c) * 0.5
      let cz = (get(x, z + 1, field, num_cells) + c) * 0.5
      let cxz = (get(x + 1, z + 1, field, num_cells) + c) * 0.5
      set(max(max(max(c, cx), cz), cxz), x, z, field, num_cells)

  var z = num_cells.y
  while --z > 0
    var x = num_cells.x
    while --x > 0
      let c = get(x, z, field, num_cells)
      let cx = (get(x - 1, z, field, num_cells) + c) * 0.5
      let cz = (get(x, z - 1, field, num_cells) + c) * 0.5
      let cxz = (get(x - 1, z - 1, field, num_cells) + c) * 0.5
      set(max(max(max(c, cx), cz), cxz), x, z, field, num_cells)


/*
def private distance_field(num_cells : int2;
                           var field : array<float>&)

  let d2 = sqrt(2.)
  for z in range(1, num_cells.y)
    for x in range(1, num_cells.x)
      let c = get(x, z, field, num_cells)
      let cx = get(x - 1, z, field, num_cells)
      let cz = get(x, z - 1, field, num_cells)
      let cxz = get(x - 1, z - 1, field, num_cells)
      set(min(min(min(c, cx + 1.), cz + 1.), cxz + d2), x, z, field, num_cells)

  var z = num_cells.y - 1
  while --z >= 0
    var x = num_cells.x - 1
    while --x >= 0
      let c = get(x, z, field, num_cells)
      let cx = get(x + 1, z, field, num_cells)
      let cz = get(x, z + 1, field, num_cells)
      let cxz = get(x + 1, z + 1, field, num_cells)
      set(min(min(min(c, cx + 1.), cz + 1.), cxz + d2), x, z, field, num_cells)

def private make_field(biome : Biome&;
                       cell_size : float;
                       num_cells : int2;
                       offset : float2;
                       var field : array<float>&)

  let max_dist = 255.
  init_field(field, max_dist)

  for tm in biome.transforms
    let p = tm[3].xz - offset
    let r = max_radius(tm, biome.extent)
    let a = max(int2(0, 0), int2(floor((p - r) / cell_size)))
    let b = min(int2(floor((p + r) / cell_size)), num_cells - int2(1))

    let ca = int2((a.x + b.x) / 2, (a.y + b.y) / 2)
    let cr2 = int(ceil(square(r.x / cell_size)))

    for z in range(a.y, b.y)
      for x in range(a.x, b.x)
        if square(x - ca.x) + square(z - ca.y) < cr2
          set(0., x, z, field, num_cells)

  distance_field(num_cells, field)

  for f in field
    f = 1. - saturate(safediv(f, biome.radius))
*/


def private ease_in_out(t : float)
  return t * t * (3. - 2. * t)


def private make_field(biome : Biome&;
                       cell_size : float;
                       num_cells : int2;
                       offset : float2;
                       var field : array<float>&)

  init_field(field, 0.)

  for tm in biome.transforms
    let p = tm[3].xz - offset
    let r = max_radius(tm, biome.extent)
    let a = max(int2(0, 0), int2(floor((p - r) / cell_size)) - int2(8))
    let b = min(int2(floor((p + r) / cell_size)) + int2(8), num_cells)

    for z in range(a.y, b.y)
      for x in range(a.x, b.x)
        let alpha = safediv(distance(float2((float(x) + 0.5) * cell_size, (float(z) + 0.5) * cell_size), p), r.x)
        let val = ease_in_out(cvt(alpha, biome.alpha2Value.x, biome.alpha2Value.y, 1., 0.))
        replace(val, x, z, field, num_cells)


def private make_bounds(biomes : array<Biome>; var aa : float2&; var bb : float2&) : bool
  aa = float2(FLT_MAX, FLT_MAX)
  bb = float2(-FLT_MIN, -FLT_MIN)
  for biome in biomes
    for tm in biome.transforms
      let r = max_radius(tm, biome.extent)
      aa = min(aa, tm[3].xz - r)
      bb = max(bb, tm[3].xz + r)
  return bb.x >= aa.x


def private resize_field(var arr &; num_cells : int2)
  resize(arr, num_cells.x * num_cells.y)


def private init_cells(var cells &)
  let defValuePacked = empty_cell()
  for c in cells
    c = defValuePacked


def private write_field(field : array<float>;
                        biome_idx : uint;
                        var cells &)

  for f, c in field, cells

    if f > 0.
      let val = clamp(uint(f * 255.), 0u, 0xff)

      var idx0, idx1, val0, val1 : uint
      unpack(c, idx0, idx1, val0, val1)

      let idx = biome_idx
      if idx0 == idx
        val0 = max(val0, val)
      elif idx1 == idx
        val1 = max(val1, val)
      elif idx0 == invalid_biome_index()
        idx0 = idx
        val0 = val
      elif idx1 == invalid_biome_index()
        idx1 = idx
        val1 = val
      elif val > val0 && val0 < val1
        idx0 = idx
        val0 = val
      elif val > val1 && val1 < val0
        idx1 = idx
        val1 = val

      c = pack(idx0, idx1, val0, val1)



def generate_field(biomes : array<Biome>;
                   cell_size : float;
                   var cells : array<uint>&;
                   var num_cells : int2&;
                   var offset : float2&) : bool

  var aa, bb : float2
  if !make_bounds(biomes, aa, bb)
    return false

  num_cells = int2(ceil((bb - aa) / cell_size)) + int2(1, 1)
  offset = floor(aa / cell_size) * cell_size

  resize_field(cells, num_cells)

  var field : array<float>
  resize_field(field, num_cells)

  init_cells(cells)

  for biome, biomeIdx in biomes, range(length(biomes))
    make_field(biome, cell_size, num_cells, offset, field)
    write_field(field, uint(biomeIdx), cells)

  return true
