from "%enlSqGlob/ui/ui_library.nut" import *
from "%darg/laconic.nut" import *
import "%dngscripts/ecs.nut" as ecs

let fa = require("%ui/components/fontawesome.map.nut")
let {fontawesome} = require("%enlSqGlob/ui/fontsStyle.nut")
let cursors = require("%daeditor/components/cursors.nut")
let textButton = require("%daeditor/components/textButton.nut")
let makeToolBox = require("%daeditor/components/toolBox.nut")
let {slider} = require("%daeditor/components/slider.nut")
let {round_by_value} = require("%sqstd/math.nut")

let {showPointAction, namePointAction, propPanelVisible} = require("%daeditor/state.nut")

let {terraformParams, beginTerraforming, isTerraforming, isTerraformingMode,
  POINTACTION_MODE_TERRAFORMING, POINTACTION_MODE_CLEAR_ELEVATIONS,
  POINTACTION_MODE_ERASE_GRASS,  POINTACTION_MODE_DELETE_GRASS_ERASERS } = require("editorTerraforming.nut")

let {isRIToolMode, beginRIToolMode, clearRIToolSelected, riToolSelected, getRIToolRemovedCount,
     unbakeRIToolSelected, enbakeRIToolSelected, rebakeRIToolSelected,
     removeRIToolSelected, instanceRIToolSelected, selectRIToolInside,
     restoreRemovedByRITool, spawnNewRIEntity} = require("editorToolRendInsts.nut")

let {groupsList, updateGroupsList, mkGroupListItemName, mkGroupListItemTooltip,
     toggleGroupListItem} = require("%daeditor/extensions/toolboxShooterGroups.nut")

let {getEditMode=null, DE4_MODE_POINT_ACTION=null} = require_optional("daEditorEmbedded")

let {EventNavMeshRebuildStarted, EventNavMeshRebuildProgress,
     EventNavMeshRebuildComplete, EventNavMeshRebuildCancelled} = require("dasevents")

let {get_scene_filepath = null} = require_optional("entity_editor")
let {system = null} = require_optional("system")


local toolboxShowMsgbox = @(_) null
function setToolboxShowMsgbox(fn) {
  toolboxShowMsgbox = fn
}

let toolboxShown = Watched(false)
let toolboxModes = Watched({
  dev = false
  coll = false
  nav = false
  polyAreas = false
  capZones = false
  capZonesPoly = false
  respawns = 0
  showGroups = false
  showCommands = false
  rebuildNavMeshState = ""
  rebuildingNavMesh = false
})

function resetToolbox() {
  // keep toolboxShown
  toolboxModes.value.dev = false
  toolboxModes.value.coll = false
  // keep .nav (still shown after new level load)
  toolboxModes.value.polyAreas = false
  toolboxModes.value.capZones = false
  toolboxModes.value.capZonesPoly = false
  toolboxModes.value.respawns = 0
  // keep .showGroups
  // keep .showCommands
  toolboxModes.value.rebuildNavMeshState = ""
  toolboxModes.value.rebuildingNavMesh = false
  toolboxModes.trigger()
}

function setToolboxMode(mode, val) {
  toolboxModes.value[mode] = val
  toolboxModes.trigger()
}

function toolboxRunCmd(cmd, cmd2 = null, mode = null, val = null) {
  if (cmd == "dev_mode_restart") {
    toolboxShowMsgbox({text="Restart required to disable DevMode"})
    return
  }
  if (cmd2 == "close")
    toolboxShown(false)
  console_command(cmd)
  if (cmd2 != null && cmd2 != "close")
    console_command(cmd2)
  if (mode != null)
    setToolboxMode(mode, val)
}

function toolboxCmd_playTest() {
  toolboxRunCmd("editor.test_mode", "close")
}

function toolboxCmd_toggleDevMode() {
  if (!toolboxModes.value.dev)
    toolboxRunCmd("sandbox.enable_devmode", null, "dev", true)
  else
    toolboxRunCmd("dev_mode_restart", null)
}

function toolboxCmd_toggleCollGeom() {
  if (!toolboxModes.value.coll)
    toolboxRunCmd("app.debug_collision", null, "coll", true)
  else
    toolboxRunCmd("app.debug_collision", null, "coll", false)
}

function toolboxCmd_toggleNavMesh() {
  if (!toolboxModes.value.nav)
    toolboxRunCmd("app.debug_navmesh 1", null, "nav", true)
  else
    toolboxRunCmd("app.debug_navmesh 0", null, "nav", false)
}

function toolboxCmd_togglePolyBattleAreas() {
  if (!toolboxModes.value.polyAreas)
    toolboxRunCmd("battleAreas.draw_active_poly_areas 1", null, "polyAreas", true)
  else
    toolboxRunCmd("battleAreas.draw_active_poly_areas 0", null, "polyAreas", false)
}

function toolboxCmd_toggleCapZonesPoly() {
  if (!toolboxModes.value.capZonesPoly)
    toolboxRunCmd("capzone.draw_active_poly_areas 1", null, "capZonesPoly", true)
  else
    toolboxRunCmd("capzone.draw_active_poly_areas 0", null, "capZonesPoly", false)
}

function toolboxCmd_toggleCapZones() {
  if (!toolboxModes.value.capZones)
    toolboxRunCmd("capzone.debug", null, "capZones", true)
  else
    toolboxRunCmd("capzone.debug", null, "capZones", false)
}

function toolboxCmd_toggleRespawns() {
  let mode = toolboxModes.value.respawns
  if (mode == 1)
    toolboxRunCmd("respbase.respbase_debug 1", "respbase.respbase_only_active_debug 0", "respawns", 2)
  else if (mode == 2)
    toolboxRunCmd("respbase.respbase_debug 0", "respbase.respbase_only_active_debug 0", "respawns", 0)
  else
    toolboxRunCmd("respbase.respbase_debug 0", "respbase.respbase_only_active_debug 1", "respawns", 1)
}

function toolboxCmd_toggleGroups() {
  if (!toolboxModes.value.showGroups)
    updateGroupsList()
  setToolboxMode("showGroups", !toolboxModes.value.showGroups)
}

function toolboxCmd_toggleBuildCommands() {
  setToolboxMode("showCommands", !toolboxModes.value.showCommands)
}

function toolboxCmd_rebuildNavMesh() {
  if (toolboxModes.value.rebuildingNavMesh)
    console_command("navmesh.rebuild_cancel")
  else if (toolboxModes.value.rebuildNavMeshState != "") {
    toolboxModes.value.rebuildNavMeshState = ""
    toolboxModes.trigger()
  }
  else
    console_command("navmesh.rebuild_start")
}

ecs.register_es("sandbox_navmesh_rebuild_es",
  {
    [EventNavMeshRebuildStarted] = function(_evt, _eid, _c){
      toolboxModes.value.rebuildNavMeshState = ""
      toolboxModes.value.rebuildingNavMesh = true
      toolboxModes.trigger()
    },

    [EventNavMeshRebuildProgress] = function(evt, _eid, _c){
      toolboxModes.value.rebuildNavMeshState = $"{evt?["progress"]}%"
      toolboxModes.value.rebuildingNavMesh = true
      toolboxModes.trigger()
    },

    [EventNavMeshRebuildComplete] = function(evt, _eid, _c){
      let numErrors = evt?["numErrors"]
      if (!numErrors || numErrors <= 0)
        toolboxModes.value.rebuildNavMeshState = "OK"
      else
        toolboxModes.value.rebuildNavMeshState = "ERR"
      toolboxModes.value.rebuildingNavMesh = false
      toolboxModes.trigger()
    },

    [EventNavMeshRebuildCancelled] = function(_evt, _eid, _c){
      toolboxModes.value.rebuildNavMeshState = ""
      toolboxModes.value.rebuildingNavMesh = false
      toolboxModes.trigger()
    }
  }
)

const MODS_TO_EDIT_FOLDER = "userGameMods"
const DEF_SCENE_FILENAME = "scene.blk"

function toolboxCmd_buildModVROM() {
  let scenePath = get_scene_filepath?()
  let modName = scenePath?.replace($"{MODS_TO_EDIT_FOLDER}/", "").replace($"/{DEF_SCENE_FILENAME}", "")
  if (!modName) {
    console_print("buildModVROM: Failed to retrieve mod name")
    return
  }
  console_print($"Building mod VROM... {MODS_TO_EDIT_FOLDER}/{modName}.vromfs.bin")
  system?($"@start modsPacker.bat \"{modName}\"")
}

const TOOLTIP_PLAYTEST  = "Teleports hero to camera position and resumes gameplay"
const TOOLTIP_DEVMODE   = "Disables different gameplay cooldowns and limitations for easier testing, but to exit DevMode you will have to Restart scene"
const TOOLTIP_COLLGEOM  = "Toggles visibility of collision geometry"
const TOOLTIP_NAVMESH   = "Toggles visibility of AI Navigation Mesh, which is vital for bots AI navigation across level and requires correctly defined Battle Areas to specify where NavMesh will be loaded. You will have to Restart scene after Battle Areas redefined"
const TOOLTIP_TERRAFORM = "Toggles Terraforming mode which allows to setup terraforming brush parameters, raise/lower landscape, and delete grass and trees"
const TOOLTIP_RENDINSTS = "Toggles RendInsts mode which allows to select level scenery models and move (Unbake), delete (Remove) and copy (Instance) them"
const TOOLTIP_POLYBA    = "Toggles visibility of active polygonal Battle Areas"
const TOOLTIP_REFRESHBA = "Updates displayed polygonal Battle Areas from polygon points (battle_area_polygon_point)"
const TOOLTIP_POLYCZ    = "Toggles visibility of active polygonal Capture Zones"
const TOOLTIP_REFRESHCZ = "Updates displayed polygonal Capture Zones from polygon points (capzone_area_polygon_point)"
const TOOLTIP_CAPZONES  = "Toggles visibility of all active Capture Zones"
const TOOLTIP_RESPAWNS  = "Toggles visibility of active / all Respawns"
const TOOLTIP_GROUPS    = "Toggles list to activate and deactivate Groups for testing purposes"
const TOOLTIP_REFRESHGR = "Updates list of displayed Groups"
//const TOOLTIP_COMMANDS  = "Toggles list of build commands"

const TOOLTIP_REBUILD_NAVMESH = "Generates NavMesh for modified terrain and placed RI, which then saved to patch_nav_mesh.bin file in mod directory"
const TOOLTIP_BUILD_MOD_ZIP   = "Packages contents of mod directory to <mod_name>.zip file placed to userGameMods/ folder, which then could be uploaded to mods portal"

const TOOLTIP_CREATE_RI_ENTITY    = "Creates new 'game_rendinst' entity"
const TOOLTIP_CREATE_RI_DECOR     = "Creates new 'game_rendinst_decor' entity"
const TOOLTIP_ADD_SCENERY_REMOVER = "Creates new 'scenery_remover' entity"
const TOOLTIP_RESTORE_REMOVED     = "Restores removed baked RI one by one"

const TOOLTIP_RI_UNBAKE   = "Converts selected baked RI to unbaked RI entities, and enbaked RI entities to normal RI entities (show their boxes)"
const TOOLTIP_RI_ENBAKE   = "Converts selected RI entities to enbaked RI entities (hide their boxes)"
const TOOLTIP_RI_REBAKE   = "Converts selected unbaked RI entities (shown in violet) to baked RI at their original positions"
const TOOLTIP_RI_REMOVE   = "Deletes selected baked RI or RI entities, and you can Restore removed baked RI later (doors/windows will require Restart)"
const TOOLTIP_RI_INSTANCE = "Clones RI or RI entities as new game RI entities (detects decor RI entities, but properties like ri_extra__overrideHitPoitns not copied here)"
const TOOLTIP_RI_WITHIN   = "Selects all other RI within (inside) selected RI"

//                               Unbake                                          Enbake                    Rebake                                Remove                    Instance
// baked RI/rebaked_rendinst     => riunb + unbaked_rendinst                     ---                       ---                                   ~rirmv + del_entity       => game_rendinst
// game_rendinst/decor           ---                                             add enbaked_ri            ---                                   del_entity                => game_rendinst/decor
// unbaked_rendinst              ---                                             add enbaked_ri            ~riunb + rebaked_rendinst             del_entity                => game_rendinst
// if not clonedRIDoorTag        create clone+unbaked_door_ri + riunb + delgen   ---                       ---                                   ~rirmv + del_entity       => create clone with clonedRIDoorTag
// if has unbaked_door_ri        ---                                             add enbaked_ri            ~riunb+rebaked_rendinst(need restart) del_entity                => create clone with clonedRIDoorTag
// if has enbaked_ri             remove enbaked_ri

let toolBoxComponent = makeToolBox(toolboxShown)

let toolboxButtonStyle    = toolBoxComponent.buttonStyle
let toolboxButtonStyleOn  = toolBoxComponent.buttonStyleOn
let toolboxButtonStyleOff = toolBoxComponent.buttonStyleOff

let terraformingContent = @() {
  pos = [hdpx(5), 0]
  flow = FLOW_VERTICAL
  watch = [showPointAction, namePointAction, terraformParams.radius, terraformParams.depth]
  children = [
    toolBoxComponent.rowDiv
    { vplace = ALIGN_CENTER, children = txt($"Mode: {terraformParams.lastInfo}") }
    toolBoxComponent.rowDiv
    {
      pos = [hdpx(-7), 0]
      flow = FLOW_HORIZONTAL
      children = [
        textButton("EV",  @() beginTerraforming("EV", POINTACTION_MODE_TERRAFORMING),         isTerraformingMode(POINTACTION_MODE_TERRAFORMING)         ? toolboxButtonStyleOn : toolboxButtonStyle)
        textButton("CE",  @() beginTerraforming("CE", POINTACTION_MODE_CLEAR_ELEVATIONS),     isTerraformingMode(POINTACTION_MODE_CLEAR_ELEVATIONS)     ? toolboxButtonStyleOn : toolboxButtonStyle)
        textButton("GE",  @() beginTerraforming("GE", POINTACTION_MODE_ERASE_GRASS),          isTerraformingMode(POINTACTION_MODE_ERASE_GRASS)          ? toolboxButtonStyleOn : toolboxButtonStyle)
        textButton("XG",  @() beginTerraforming("XG", POINTACTION_MODE_DELETE_GRASS_ERASERS), isTerraformingMode(POINTACTION_MODE_DELETE_GRASS_ERASERS) ? toolboxButtonStyleOn : toolboxButtonStyle)
      ]
    }
    toolBoxComponent.rowDiv
    { vplace = ALIGN_CENTER, children = txt($"Brush radius: {round_by_value(terraformParams.radius.value, terraformParams.radiusStep)}") }
    { size = [hdpx(200), hdpx(32)], children = slider(O_HORIZONTAL, terraformParams.radius, { min = terraformParams.radiusMin, max = terraformParams.radiusMax, step = terraformParams.radiusStep }) }

    terraformParams.lastName != "EV" ? null : toolBoxComponent.rowDiv
    terraformParams.lastName != "EV" ? null : { vplace = ALIGN_CENTER, children = txt($"{terraformParams.depth.value <= -terraformParams.depthStep*0.9 ? "Lowering depth" : "Elevation hght"}: {round_by_value(terraformParams.depth.value, terraformParams.depthStep)}") }
    terraformParams.lastName != "EV" ? null : { size = [hdpx(200), hdpx(32)], children = slider(O_HORIZONTAL, terraformParams.depth, { min = terraformParams.depthMin, max = terraformParams.depthMax, step = terraformParams.depthStep }) }
    terraformParams.lastName != "EV" ? null : { vplace = ALIGN_CENTER, children = txt("Hold Alt to invert") }
    terraformParams.lastName != "EV" ? null : { vplace = ALIGN_CENTER, children = txt("Hold Shift for 5x finer") }
    terraformParams.lastName != "EV" ? null : { vplace = ALIGN_CENTER, children = txt("Hold Ctrl for 5x coarser") }
    { vplace = ALIGN_CENTER, children = txt("Ctrl+Z for undo") }
    { vplace = ALIGN_CENTER, children = txt("Ctrl+Y for redo") }
    toolBoxComponent.rowDiv
  ]
}

function rendInstsContent() {
  let riLen = riToolSelected.value.len()
  let riHas = riLen > 0
  let ttDX = -hdpx(45)

  let unbakeBtn = riHas ? toolBoxComponent.mkButton("Unbake",   @() unbakeRIToolSelected()) : null
  let removeBtn = riHas ? toolBoxComponent.mkButton("Remove",   @() removeRIToolSelected()) : null
  let enbakeBtn = riHas ? toolBoxComponent.mkButton("Enbake"  , @() enbakeRIToolSelected()) : null
  let instanBtn = riHas ? toolBoxComponent.mkButton("Instance", @() instanceRIToolSelected()) : null
  let rebakeBtn = riHas ? toolBoxComponent.mkButton("Rebake",   @() rebakeRIToolSelected()) : null
  let withinBtn = riHas ? toolBoxComponent.mkButton("Within..", @() selectRIToolInside()) : null

  return {
    watch = [showPointAction, namePointAction, riToolSelected]
    pos = [hdpx(5), 0]
    flow = FLOW_VERTICAL
    children = [
      { size = [0, hdpx(5)] }
      { pos = [hdpx(16), 0], vplace = ALIGN_CENTER, children = txt($"Click to select baked RI") }
      { pos = [hdpx(16), 0], vplace = ALIGN_CENTER, children = txt($"Hold Ctrl to multiselect") }
      { size = [0, hdpx(5)] }
      { pos = [hdpx(16), 0], flow = FLOW_HORIZONTAL, children = [
        { vplace = ALIGN_CENTER, children = txt($"{riLen} selected") }
        textButton("Deselect", @() clearRIToolSelected(), riHas ? toolboxButtonStyle : toolboxButtonStyleOff)
      ]}
      { size = [0, hdpx(5)] }
      riHas ? function() {
        local childs = []
        foreach (item in riToolSelected.value) {
          if (childs.len() >= 15) {
            childs.append({ vplace = ALIGN_CENTER, children = txt($"... ({riLen-15} more)") })
            break
          }
          childs.append({ vplace = ALIGN_CENTER, children = txt($"{item.name}", item.kind == 1 ? {color=Color(255,64,255)} :
                                                                                item.kind == 2 ? {color=Color(230,230,64)} :
                                                                                item.kind == 3 ? {color=Color(64,230,230)} :
                                                                                {}) })
        }
        return { flow = FLOW_VERTICAL, children = childs }
      } : null
      riHas ? { size = [0, hdpx(10)] } : { size = [0, hdpx(5)] }
      riHas ? { pos = [hdpx(16), 0], flow = FLOW_HORIZONTAL, children = [
        toolBoxComponent.mkTooltip(unbakeBtn, TOOLTIP_RI_UNBAKE, ttDX)
        toolBoxComponent.mkTooltip(removeBtn, TOOLTIP_RI_REMOVE, ttDX)
        unbakeBtn
        removeBtn
      ]} : null
      riHas ? { size = [0, hdpx(5)] } : null
      riHas ? { pos = [hdpx(16), 0], flow = FLOW_HORIZONTAL, children = [
        toolBoxComponent.mkTooltip(enbakeBtn, TOOLTIP_RI_ENBAKE, ttDX)
        toolBoxComponent.mkTooltip(instanBtn, TOOLTIP_RI_INSTANCE, ttDX)
        enbakeBtn
        instanBtn
      ]} : null
      riHas ? { size = [0, hdpx(5)] } : null
      riHas ? { pos = [hdpx(16), 0], flow = FLOW_HORIZONTAL, children = [
        toolBoxComponent.mkTooltip(rebakeBtn, TOOLTIP_RI_REBAKE, ttDX)
        toolBoxComponent.mkTooltip(withinBtn, TOOLTIP_RI_WITHIN, ttDX)
        rebakeBtn
        withinBtn
      ]} : null
      !riHas ? { pos = [hdpx(7), 0], flow = FLOW_VERTICAL, children = [
        textButton($"Create new RendInst", @() spawnNewRIEntity("game_rendinst"),       toolboxButtonStyle.__merge({ onHover = @(on) cursors.setTooltip(on ? TOOLTIP_CREATE_RI_ENTITY    : null) }))
        textButton($"Create new RI decor", @() spawnNewRIEntity("game_rendinst_decor"), toolboxButtonStyle.__merge({ onHover = @(on) cursors.setTooltip(on ? TOOLTIP_CREATE_RI_DECOR     : null) }))
        textButton($"Add scenery remover", @() spawnNewRIEntity("scenery_remover"),     toolboxButtonStyle.__merge({ onHover = @(on) cursors.setTooltip(on ? TOOLTIP_ADD_SCENERY_REMOVER : null) }))
      ]} : null
      !riHas ? { size = [0, hdpx(5)] } : null
      !riHas ? { pos = [hdpx(4), 0], flow = FLOW_HORIZONTAL, children = [
        textButton($"Restore removed ({getRIToolRemovedCount()})", @() restoreRemovedByRITool(),
                  ((getRIToolRemovedCount() > 0) ? toolboxButtonStyle : toolboxButtonStyleOff).__merge({ onHover = @(on) cursors.setTooltip(on ? TOOLTIP_RESTORE_REMOVED : null) }))
      ]} : null
      toolBoxComponent.rowDiv
    ]
  }
}

let faStyle = {textStyle = {normal = fontawesome}, boxStyle = {normal = {fillColor = Color(0,0,0,80)}}}
let faRefresh = { text = fa["refresh"], style = faStyle }

let respawnsBtnText = function() {
  let mode = toolboxModes.value.respawns
  return mode == 1 ? "Respawns +" : mode == 2 ? "Respawns..." : "Respawns"
}

function groupsContent() {
  local childs = []
  childs.append(toolBoxComponent.rowDiv)
  foreach (item in groupsList.value) {
    let itemParam = clone item
    childs.append({
      children = textButton(
        mkGroupListItemName(itemParam),
        function() {
          toggleGroupListItem(itemParam)

          if (toolboxModes.value.polyAreas) {
            toolboxRunCmd("battleAreas.draw_active_poly_areas 0")
            gui_scene.resetTimeout(0.01, @() toolboxRunCmd("battleAreas.draw_active_poly_areas 1"))
          }
        },
        ((itemParam.active > 0) ? toolboxButtonStyleOn : toolboxButtonStyle).__merge({
          onHover = @(on) cursors.setTooltip(on ? mkGroupListItemTooltip(itemParam) : null)
        })
      )
    })
  }
  childs.append(toolBoxComponent.rowDiv)
  return {
    flow = FLOW_VERTICAL
    pos = [hdpx(16), 0]
    gap = hdpx(5)
    watch = [groupsList]
    children = childs
  }
}

let commandsContent = @() {
  watch = [toolboxModes]
  flow = FLOW_VERTICAL
  children = [
    toolBoxComponent.rowDiv
    { pos = [hdpx(27), 0], flow = FLOW_HORIZONTAL, children = [
      textButton(toolboxModes.value.rebuildingNavMesh ? $"Rebuilding... {toolboxModes.value.rebuildNavMeshState}" : $"Rebuild NavMesh {toolboxModes.value.rebuildNavMeshState}",
        @() toolboxCmd_rebuildNavMesh(), toolboxButtonStyle.__merge({ onHover = @(on) cursors.setTooltip(on ? TOOLTIP_REBUILD_NAVMESH : null) }))
    ]}
    { size = [0, hdpx(5)] }
    { pos = [hdpx(27), 0], flow = FLOW_HORIZONTAL, children = [
      textButton("Build Mod ZIP", @() toolboxCmd_buildModVROM(), toolboxButtonStyle.__merge({
        onHover = @(on) cursors.setTooltip(on ? TOOLTIP_BUILD_MOD_ZIP : null)
      }))
    ]}
  ]
}

toolBoxComponent.setPos(hdpx(-210), hdpx(42))

toolBoxComponent.addOption(@() false,                           "Playtest",        @(_) toolboxCmd_playTest(),       null, TOOLTIP_PLAYTEST)
toolBoxComponent.addOption(@() toolboxModes.value.dev,          "DevMode",         @(_) toolboxCmd_toggleDevMode(),  null, TOOLTIP_DEVMODE)
toolBoxComponent.addOption(@() toolboxModes.value.coll,         "CollGeom",        @(_) toolboxCmd_toggleCollGeom(), null, TOOLTIP_COLLGEOM)
toolBoxComponent.addOption(@() toolboxModes.value.nav,          "NavMesh",         @(_) toolboxCmd_toggleNavMesh(),  null, TOOLTIP_NAVMESH)
toolBoxComponent.addOption(@() isTerraforming.value,            "Terraform",       @(_) beginTerraforming(terraformParams.lastName, terraformParams.lastMode, true), terraformingContent, TOOLTIP_TERRAFORM)
toolBoxComponent.addOption(@() isRIToolMode(),                  "RendInsts",       @(_) beginRIToolMode(true), rendInstsContent, TOOLTIP_RENDINSTS)
toolBoxComponent.addOption(@() toolboxModes.value.polyAreas,    "PolyBattleAreas", @(_) toolboxCmd_togglePolyBattleAreas(), null, TOOLTIP_POLYBA)
toolBoxComponent.addOption(@() false,                           faRefresh,         @(_) toolboxRunCmd("battleAreas.reinit_active_poly_areas"), null, TOOLTIP_REFRESHBA)
toolBoxComponent.addOption(@() toolboxModes.value.capZonesPoly, "CapZonesPoly",    @(_) toolboxCmd_toggleCapZonesPoly(), null, TOOLTIP_POLYCZ)
toolBoxComponent.addOption(@() false,                           faRefresh,         @(_) toolboxRunCmd("capzone.reinit_active_poly_areas"), null, TOOLTIP_REFRESHCZ)
toolBoxComponent.addOption(@() toolboxModes.value.capZones,     "CapZones",        @(_) toolboxCmd_toggleCapZones(), null, TOOLTIP_CAPZONES)
toolBoxComponent.addOption(@() toolboxModes.value.respawns > 0, respawnsBtnText,   @(_) toolboxCmd_toggleRespawns(), null, TOOLTIP_RESPAWNS)
toolBoxComponent.addOption(@() toolboxModes.value.showGroups,   "Groups Override", @(_) toolboxCmd_toggleGroups(), groupsContent, TOOLTIP_GROUPS)
toolBoxComponent.addOption(@() false,                           faRefresh,         @(_) updateGroupsList(), null, TOOLTIP_REFRESHGR)
toolBoxComponent.addOption(@() toolboxModes.value.showCommands, "Build commands",  @(_) toolboxCmd_toggleBuildCommands(), commandsContent, null)

showPointAction.subscribe(@(_) toolBoxComponent.redraw())
namePointAction.subscribe(@(_) toolBoxComponent.redraw())

propPanelVisible.subscribe(function(v) {
  if (v && getEditMode?() != DE4_MODE_POINT_ACTION)
    toolboxShown(false)
})

riToolSelected.subscribe(function(v) {
  toolBoxComponent.redraw()
  if (v.len() > 0 && !toolboxShown.value) {
    toolboxShown(true)
    propPanelVisible(false)
  }
})

return {
  setToolboxShowMsgbox
  resetToolbox
  toolboxShown
  toolboxPopup = toolBoxComponent.panel
}
