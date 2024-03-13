require ecs
require app
require strings
require sandbox.es.navmesh_rebuild_events
require DagorMath
require DagorConsole
require DagorEditor
require pathfinder
require RendInst

let
  MIN_NAVMESH_INVALIDATE_HEIGHT = -10000.0
  MAX_NAVMESH_INVALIDATE_HEIGHT =  10000.0

def navmesh_rebuild_add_rirmv(tm, name)
  let poolsCount = rendinst_getRiGenExtraResCount()
  for pool_id in range(poolsCount)
    let riName = riex_getRIGenExtraName(uint(pool_id))
    if riName == name
      let bsph = getRIGenExtraBSphereByTM(uint(pool_id), tm)
      let pt1 = float3(bsph.x - bsph.w, MIN_NAVMESH_INVALIDATE_HEIGHT, bsph.z - bsph.w)
      let pt2 = float3(bsph.x + bsph.w, MAX_NAVMESH_INVALIDATE_HEIGHT, bsph.z + bsph.w)
      let bbox = BBox3(pt1, pt2)
      rebuildNavMesh_addBBox(bbox)
      return

def navmesh_rebuild_add_rirmvs(ri_list : Array)
  for ri in ri_list
    let obj = get_ecs_object(ri)
    if obj == null
      continue
    let tm = get_TMatrix(*obj, "tm")
    if tm == null
      continue
    let name = get_string(*obj, "name", "")
    navmesh_rebuild_add_rirmv(*tm, name)

def navmesh_rebuild_add_riextra(ri_extra : RiExtraComponent)
  let bsph = getRIGenExtraBSphere(ri_extra.handle)
  let pt1 = float3(bsph.x - bsph.w, MIN_NAVMESH_INVALIDATE_HEIGHT, bsph.z - bsph.w)
  let pt2 = float3(bsph.x + bsph.w, MAX_NAVMESH_INVALIDATE_HEIGHT, bsph.z + bsph.w)
  let bbox = BBox3(pt1, pt2)
  rebuildNavMesh_addBBox(bbox)

def navmesh_rebuild_add_ladder(transform : float3x4; ladder__thickness : float; ladder__width : float; ladder__height : float)
  let pt1 = transform[3]
  let pt2 = pt1 + (transform[0] * ladder__thickness + transform[1] * ladder__height + transform[2] * ladder__width)
  var bbox = BBox3(pt1, pt2)
  let extendDist = 1.2f
  bbox |> bbox3_inflateXZ(extendDist)
  rebuildNavMesh_addBBox(bbox)

def navmesh_rebuild_setup_Point2(eid : EntityId; name : string)
  let paramName = "nav_rebuild__{name}"
  let value = get_Point2(eid, paramName, ecs_hash(paramName))
  if value != null
    rebuildNavMesh_setup(name, *value)

def navmesh_rebuild_setup_float(eid : EntityId; name : string; compName = "")
  let paramName = length(compName) == 0 ? "nav_rebuild__{name}" : compName;
  let value = get_float(eid, paramName, ecs_hash(paramName))
  if value != null
    rebuildNavMesh_setup(name, *value)

def navmesh_rebuild_setup_int_to_float(eid : EntityId; name : string)
  let paramName = "nav_rebuild__{name}"
  let value = get_int(eid, paramName, ecs_hash(paramName))
  if value != null
    rebuildNavMesh_setup(name, float(*value))

def navmesh_rebuild_setup_bool_to_float(eid : EntityId; name : string)
  let paramName = "nav_rebuild__{name}"
  let value = get_bool(eid, paramName, ecs_hash(paramName))
  if value != null
    rebuildNavMesh_setup(name, *value ? 1.0f : 0.0f)

def navmesh_rebuild_setup_params()
  var levelEid = INVALID_ENTITY_ID
  find_query() <| $ [es(REQUIRE=level__loadNavMesh)] (eid : EntityId)
    levelEid = eid
    return true
  var waterEid = INVALID_ENTITY_ID
  find_query() <| $ [es(REQUIRE=water__level)] (eid : EntityId)
    waterEid = eid
    return true

  // navmesh setup
  navmesh_rebuild_setup_float(levelEid, "agentMaxSlope")
  navmesh_rebuild_setup_int_to_float(levelEid, "vertsPerPoly")
  navmesh_rebuild_setup_float(levelEid, "regionMinSize")
  navmesh_rebuild_setup_float(levelEid, "regionMergeSize")
  navmesh_rebuild_setup_int_to_float(levelEid, "minBorderSize")
  navmesh_rebuild_setup_float(levelEid, "detailSampleDist")
  navmesh_rebuild_setup_float(levelEid, "detailSampleMaxError")
  navmesh_rebuild_setup_float(levelEid, "edgeMaxLen")
  navmesh_rebuild_setup_float(waterEid, "waterLevel", "water__level")

  // jumplinks setup
  navmesh_rebuild_setup_bool_to_float(levelEid, "jlkEnabled")
  navmesh_rebuild_setup_int_to_float(levelEid, "jlkCovExtraCells")
  navmesh_rebuild_setup_float(levelEid, "jlkJumpHeight")
  navmesh_rebuild_setup_float(levelEid, "jlkJumpLength")
  navmesh_rebuild_setup_float(levelEid, "jlkWidth")
  navmesh_rebuild_setup_float(levelEid, "jlkAgentHeight")
  navmesh_rebuild_setup_float(levelEid, "jlkAgentMinSpace")
  navmesh_rebuild_setup_float(levelEid, "jlkDeltaHeightThreshold")
  navmesh_rebuild_setup_float(levelEid, "jlkComplexJumpTheshold")
  navmesh_rebuild_setup_float(levelEid, "jlkLinkDegAngle")
  navmesh_rebuild_setup_float(levelEid, "jlkLinkDegDist")
  navmesh_rebuild_setup_float(levelEid, "jlkAgentRadius")
  navmesh_rebuild_setup_bool_to_float(levelEid, "jlkCrossObstaclesWithJumplinks")
  navmesh_rebuild_setup_bool_to_float(levelEid, "jlkEnableCustomJumplinks")

  // merge contour edges setup
  navmesh_rebuild_setup_bool_to_float(levelEid, "edgMergeEdgesEnabled")
  navmesh_rebuild_setup_float(levelEid, "edgMaxExtrudeErrorSq")
  navmesh_rebuild_setup_float(levelEid, "edgExtrudeLimitSq")
  navmesh_rebuild_setup_Point2(levelEid, "edgWalkPrecision")
  navmesh_rebuild_setup_float(levelEid, "edgSafeCutLimitSq")
  navmesh_rebuild_setup_float(levelEid, "edgUnsafeCutLimitSq")
  navmesh_rebuild_setup_float(levelEid, "edgUnsafeMaxCutSpace")

[es(tag=server)]
def navmesh_rebuild_cancel_es(evt : CmdNavMeshRebuildCancel)
  var rebuildingEid = INVALID_ENTITY_ID
  find_query() <| $ [es, unused_argument(navmesh_rebuilding__startTime)] (eid : EntityId; navmesh_rebuilding__startTime : int64)
    rebuildingEid = eid
    return true
  if rebuildingEid == INVALID_ENTITY_ID
    console_print("navmesh_rebuild: not running")
    return
  broadcastEvent([[EventNavMeshRebuildCancelled]])
  destroyEntity(rebuildingEid)
  rebuildNavMesh_close()
  console_print("navmesh_rebuild: cancelled")

[es(tag=server)]
def navmesh_rebuild_start_es(evt : CmdNavMeshRebuildStart)
  var rebuildingEid = INVALID_ENTITY_ID
  find_query() <| $ [es, unused_argument(navmesh_rebuilding__startTime)] (eid : EntityId; navmesh_rebuilding__startTime : int64)
    rebuildingEid = eid
    return true
  if rebuildingEid != INVALID_ENTITY_ID
    broadcastEvent([[EventNavMeshRebuildCancelled]])
    destroyEntity(rebuildingEid)
    rebuildNavMesh_close()
    console_print("navmesh_rebuild: was running, cancelled")

  rebuildNavMesh_init()
  navmesh_rebuild_setup_params()

  query() <| $ [es] (elevs : Array)
    for elev in elevs
      let data = get_Point4(elev) ?? float4(0.0, 0.0, 0.0, 0.0)
      let pos = float3(data.x, 0.0, data.y)
      let rad = data.z
      var bbox = BBox3(pos, 2.0 * rad)
      bbox.boxMin.y = MIN_NAVMESH_INVALIDATE_HEIGHT
      bbox.boxMax.y = MAX_NAVMESH_INVALIDATE_HEIGHT
      rebuildNavMesh_addBBox(bbox)

  query() <| $ [es] (rirmv : Array; riunb : Array)
    navmesh_rebuild_add_rirmvs(rirmv)
    navmesh_rebuild_add_rirmvs(riunb)

  query() <| $ [es(REQUIRE=unbakedRendInstTag)] (ri_extra : RiExtraComponent)
    navmesh_rebuild_add_riextra(ri_extra)

  query() <| $ [es(REQUIRE=gameRendInstTag)] (ri_extra : RiExtraComponent)
    navmesh_rebuild_add_riextra(ri_extra)

  query() <| $ [es] (transform : float3x4; ladder__thickness : float; ladder__width : float; ladder__height : float)
    navmesh_rebuild_add_ladder(transform, ladder__thickness, ladder__width, ladder__height)

  createEntitySync("navmesh_rebuilding")
  console_print("navmesh_rebuild: started")
  broadcastEvent([[EventNavMeshRebuildStarted]])


[es(tag=server, on_appear)]
def navmesh_rebuild_begin_es(evt : Event; var navmesh_rebuilding__startTime : int64&)
  navmesh_rebuilding__startTime = ref_time_ticks()

[es(tag=server, no_order)]
def navmesh_rebuild_step_es(info : UpdateStageInfoAct;
                            eid : EntityId;
                            navmesh_rebuilding__startTime : int64;
                            var navmesh_rebuilding__progress : int&;
                            var navmesh_rebuilding__errors : int&)
  if rebuildNavMesh_getProgress() >= 100
    let totalTime = float(get_time_usec(navmesh_rebuilding__startTime)) * 0.001
    let totalTiles = rebuildNavMesh_getTotalTiles()
    console_print("navmesh_rebuild: complete, {totalTiles} tiles in {format("%.2f", totalTime)}ms")
    broadcastEvent([[EventNavMeshRebuildComplete totalTime=totalTime, totalTiles=totalTiles, numErrors=navmesh_rebuilding__errors]])
    destroyEntity(eid)

    let sceneFilePath = entity_obj_editor_getSceneFilePath()
    if starts_with(sceneFilePath, "userGameMods/") && ends_with(sceneFilePath, "/scene.blk")
      let navMeshFileName = "patch_nav_mesh.bin"
      let navMeshFilePath = "{slice(sceneFilePath, 0, length(sceneFilePath)-10)}/{navMeshFileName}"
      if rebuildNavMesh_saveToFile(navMeshFilePath)
        console_print("navmesh_rebuild: saved to file {navMeshFilePath}")
        query() <| $ [es] (eid : EntityId; var level__patchNavMeshPath : das_string&)
          let levelPatchNavMeshPath = "%ugm/{navMeshFileName}"
          if level__patchNavMeshPath != levelPatchNavMeshPath
            level__patchNavMeshPath := levelPatchNavMeshPath
            entity_obj_editor_saveComponent(eid, "level__patchNavMeshPath")
            console_print("navmesh_rebuild: set to level entity component level__patchNavMeshPath <- '{level__patchNavMeshPath}'")
            console_print("navmesh_rebuild: please, save scene to use generated navmesh patch in future")
      else
        console_print("navmesh_rebuild: failed save to file {navMeshFilePath}")
    else
      console_print("navmesh_rebuild: not user mod scene, don't save to file")

    rebuildNavMesh_close()
    return

  let result = rebuildNavMesh_update(true)

  if !result
    navmesh_rebuilding__errors += 1

  let progress = rebuildNavMesh_getProgress()

  if navmesh_rebuilding__progress < progress
    navmesh_rebuilding__progress = progress
    let totalTime = float(get_time_usec(navmesh_rebuilding__startTime)) * 0.001
    let totalTiles = rebuildNavMesh_getTotalTiles()
    console_print("navmesh_rebuild: {format("%.2f", totalTime)}ms, {progress}%")
    broadcastEvent([[EventNavMeshRebuildProgress progress=float(progress), totalTime=totalTime, totalTiles=totalTiles, numErrors=navmesh_rebuilding__errors]])
