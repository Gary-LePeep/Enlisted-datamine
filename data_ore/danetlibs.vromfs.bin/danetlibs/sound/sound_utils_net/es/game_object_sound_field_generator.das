require ecs
require ecs.safe
require ecs.extra_set
require DagorMath
require DagorSystem
require gameObject
require environment_sounds.modules.sound_field_common
require environment_sounds.modules.sound_field_generator_common
require strings


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
          return false

    return true

  assume cellSize = game_object_sound_field_generator__cellSize

  var cells : array<uint>
  var numCells : int2
  var offset : float2

  if generate_field(biomes, cellSize, cells, numCells, offset)

    var allTransformsDebug : array<float3x4>
    for biome in biomes
      for tm in biome.transforms
        allTransformsDebug |> push(tm)

    let eid = createEntity(game_object_sound_field_generator__entityTemplate) <| $(var init)
      init |> set("sound_field__cells", cells)
      init |> set("sound_field__offset", offset)
      init |> set("sound_field__numCells", numCells)
      init |> set("sound_field__cellSize", cellSize)
      init |> set("sound_field__tmsDebug", allTransformsDebug)

    game_object_sound_field_generator__entityEid = eid
