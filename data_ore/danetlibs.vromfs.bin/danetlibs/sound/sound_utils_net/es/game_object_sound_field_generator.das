require ecs
require ecs.safe
require ecs.extra_set
require DagorMath
require DagorSystem
require gameObject
require environment_sounds.modules.sound_field_common
require strings


struct Biome
  transforms : array<float3x4>
  alpha2Value : float2
  extent : float


def get(x, y : int; field : array<float>; num_cells : int2)
  return field[x + y * num_cells.x]


def set(f : float; x, y : int; var field : array<float>&; num_cells : int2)
  field[x + y * num_cells.x] = f


def max_radius(tm : float3x4; extent : float) : float2
  let x = max(tm[0].x, tm[0].z) + extent
  return float2(x, x)


def init_field(var field : array<float>&; val : float)
  for f in field
    f = val


/*
def distance_field(num_cells : int2;
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
  while --z > 0
    var x = num_cells.x - 1
    while --x > 0
      let c = get(x, z, field, num_cells)
      let cx = get(x + 1, z, field, num_cells)
      let cz = get(x, z + 1, field, num_cells)
      let cxz = get(x + 1, z + 1, field, num_cells)
      set(min(min(min(c, cx + 1.), cz + 1.), cxz + d2), x, z, field, num_cells)

def make_field(var biome : Biome&;
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

def ease_in_out(t : float)
  return t * t * (3. - 2. * t)

def make_field(var biome : Biome&;
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
        set(max(get(x, z, field, num_cells), val), x, z, field, num_cells)


[es(tag=server, on_appear, on_event=EventGameObjectsCreated)]
def game_object_sound_field_generator(evt : Event;
                                      game_object_sound_field_generator__entityTemplate : string;
                                      game_object_sound_field_generator__biomeTypes : Array;
                                      game_object_sound_field_generator__cellSize : float;
                                      var game_object_sound_field_generator__entityEid : EntityId&)

  destroyEntity(game_object_sound_field_generator__entityEid)
  game_object_sound_field_generator__entityEid = INVALID_ENTITY_ID

  var biomes : array<Biome>

  resize(biomes, length(game_object_sound_field_generator__biomeTypes))

  var aa = float2(FLT_MAX, FLT_MAX)
  var bb = float2(-FLT_MIN, -FLT_MIN)

  var numGameObjects = 0
  var allTransformsDebug : array<float3x4>

  find_query() <| $ [es] (game_objects : GameObjects)

    for it, biome in game_object_sound_field_generator__biomeTypes, biomes
      let gameObjectType = it as Object
      let gameObject = gameObjectType?.gameObject ?? ""
      biome.extent = gameObjectType?.extent ?? 0.
      biome.alpha2Value = gameObjectType?.alpha2Value ?? float2(0., 1.)

      let scene = game_objects |> get_scene_game_objects_by_name(gameObject)
      if scene != null
        scene |> find_scene_game_objects() <| $ [unused_argument(ni)] (ni : uint; tm : float3x4#)
          let t : float3x4 := tm

          biome.transforms |> push(t)
          allTransformsDebug |> push(t)

          let r = max_radius(t, biome.extent)
          aa = min(aa, t[3].xz - r)
          bb = max(bb, t[3].xz + r)
          ++numGameObjects
          return false

    return true


  if numGameObjects != 0
    assume cellSize = game_object_sound_field_generator__cellSize

    let numCells = int2(ceil((bb - aa) / cellSize)) + int2(1, 1)
    let offset = floor(aa / cellSize) * cellSize

    var field : array<float>
    resize(field, numCells.x * numCells.y)

    var cells : array<uint>
    resize(cells, numCells.x * numCells.y)

    let defValuePacked = empty_cell()
    for c in cells
      c = defValuePacked

    for biome, biomeIdx in biomes, range(length(biomes))
      make_field(biome, cellSize, numCells, offset, field)

      for f, c in field, cells

        if f > 0.
          let val = clamp(uint(f * 255.), 0u, 0xff)

          var idx0, idx1, val0, val1 : uint
          unpack(c, idx0, idx1, val0, val1)

          let idx = uint(biomeIdx)
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


    let eid = createEntity(game_object_sound_field_generator__entityTemplate) <| $(var init)
      init |> set("sound_field__cells", cells)
      init |> set("sound_field__offset", offset)
      init |> set("sound_field__numCells", numCells)
      init |> set("sound_field__cellSize", cellSize)
      init |> set("sound_field__tmsDebug", allTransformsDebug)

    game_object_sound_field_generator__entityEid = eid
