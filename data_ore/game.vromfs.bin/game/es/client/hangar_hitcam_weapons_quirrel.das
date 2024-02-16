require ecs
require ecs.safe
require ecs.ecs_quirrel
require daslib/quirrel_boost
require EcsUtils
require DngCamera
require BallisticsDm
require DaWeaponProps
require common_shooter.es.weapon.turret_hit_analyzer_common
require game.es.hangar_hitcam_common
require dm

let requiredComps = [[string[] "gun__owner";
                               "gun__maxAmmo";
                               "gun__salt";
                               "gun__propsId";
                               "gun__curShellId";
                               "gun__ammo";
                               "gun";
                               "gun_deviation"
                    ]]

[quirrel_bind(module_name="das.hitcam")]
def get_weapons_for_hangar_hitcam()
  var gunTemplates : array<string>
  getTemplateDB() |> find_templateDB() <| $(name; tmpl)
    for compName in requiredComps
      if !templateHasComponent(tmpl, compName, ecs_hash(compName))
        return false
    let gunBlk = getTemplateComponent(tmpl, "gun__blk") ?? ""
    if empty(gunBlk)
      return false
    let gunShells = getTemplateComponent(tmpl, "gun__shells") ?as Array
    let ammoSets = getTemplateComponent(tmpl, "gun__ammoSetsInfo")
    if (gunShells == null || empty(*gunShells)) && ammoSets.isNull
      return false
    gunTemplates |> push(slice(name, 0, length(name)))
    return false
  sort(gunTemplates) <| $(a, b)
    return a < b
  return <- gunTemplates

def convertResult(result : int)
  if result == int(TestResult RICOCHET)
    return HitcamResult RICOCHET
  if result == int(TestResult NOT_PENETRATE)
    return HitcamResult NOT_PENETRATE
  if result == int(TestResult INEFFECTIVE)
    return HitcamResult INEFFECTIVE
  if result == int(TestResult POSSIBLE_EFFECTIVE)
    return HitcamResult POSSIBLE_EFFECTIVE
  if result == int(TestResult EFFECTIVE)
    return HitcamResult EFFECTIVE
  return HitcamResult EMPTY

[quirrel_bind(module_name="das.hitcam")]
def gun_get_shell_types_count(gun_eid : EntityId)
  var res = 0
  query(gun_eid) <| $ [es] (gun__shell_prop_ids : GunShellPropIds)
    res = length(gun__shell_prop_ids)
  return res

[quirrel_bind(module_name="das.hitcam")]
def hangar_simulate_shot(target_eid : EntityId; gun_eid : EntityId; shell_index : int; distance : float; screen_pos : float2)
  var worldPoint : float3
  var worldDir : float3
  screen_to_world(screen_pos, worldPoint, worldDir)
  var res = HitcamResult EMPTY
  query(target_eid) <| $ [es] (transform : float3x4)
    let vecToTarget = worldPoint - transform[3]
    let distToTarget = abs(dot(worldDir, vecToTarget))
    query(gun_eid) <| $ [es] (gun__curShellId : ShellPropIds;
                              gun__shell_prop_ids : GunShellPropIds;
                              gun__projectileVelocityMult : float = 1.0)
      assume shell = shell_index < length(gun__shell_prop_ids) ? gun__shell_prop_ids[shell_index] : gun__curShellId
      let shellId = int(shell.shellId)
      if shellId < 0
        return
      shell_start_get_props(shellId) <| $(shellStartProps : ShellStartProps)
        let velocity = shellStartProps.speed * gun__projectileVelocityMult
        let testResult = turret_hit_analyzer_common::simulate_shot_entity(target_eid, shell, velocity, distance, Ray3(worldPoint, worldDir, distToTarget * 2.0), true, true)
        res = convertResult(testResult)
  return int(res)
