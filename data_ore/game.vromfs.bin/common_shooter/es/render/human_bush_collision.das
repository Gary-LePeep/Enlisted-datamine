require ecs
require ecs.safe
require game.es.events
require DngHuman
require DngPhys
require DagorMath
require DagorRandom
require PhysMat
require math.base
require DagorSystem
require fx

def spawn_effect_aux(pos : float3; fx_name : string; rendinst_pool : int)
  var tm = IDENT_TM
  tm[3] = pos

  createEntity(fx_name) <| $(init)
    init |> set("transform", tm)
    init |> set("effect__riPoolUsedForColoring", rendinst_pool)


[es(tag=render, REQUIRE=hero)]
def human_bush_collision_effects(evt : CmdPostPhysUpdate;
                                 human_net_phys : HumanActor;
                                 [[shared_comp]] human_bush_collision__effects : Object;
                                 human_bush_collision__torsoContactVelocityMinMax : float2;
                                 human_bush_collision__updateInterval : float;
                                 transform : float3x4;
                                 var human_bush_collision__nextUpdateAt : float&)
  assume currentState = human_net_phys.phys.currentState
  assume matId = currentState.torsoContactMatId

  if matId == PHYSMAT_INVALID
    return

  let curTime = float(evt.tick) * evt.dt
  if curTime < human_bush_collision__nextUpdateAt
    return
  human_bush_collision__nextUpdateAt = curTime + human_bush_collision__updateInterval

  if int(get_fx_target()) <= int(FxQuality FX_QUALITY_LOW)
    return

  let matName = get_material_name(get_material(matId))
  let fxName = human_bush_collision__effects[matName] ?? ""
  if empty(fxName)
    return
  let probability = cvt(length(currentState.velocity), human_bush_collision__torsoContactVelocityMinMax.x, human_bush_collision__torsoContactVelocityMinMax.y, 0., 1.)
  var seed = phys_time_to_seed(curTime)
  if _frnd(seed) < probability
    spawn_effect_aux(transform[3], fxName, currentState.torsoContactRendinstPool)
