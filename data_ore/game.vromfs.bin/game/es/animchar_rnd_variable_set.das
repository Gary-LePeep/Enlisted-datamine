require ecs
require AnimV20
require DagorSystem
require DagorRandom

[es(on_appear)]
def animchar_set_rnd_var_on_appear(evt : Event;
                                   eid : EntityId;
                                   random_animchar_vars__varNames : StringList;
                                   random_animchar_vars__varLimits : Point2List;
                                   var animchar : AnimcharBaseComponent&)
  if length(random_animchar_vars__varNames) != length(random_animchar_vars__varLimits)
    logerr("incorrect vars in random_animchar_vars__varNames for entity <{eid}> with template '{getEntityTemplateName(eid)}'");
  var seed = int(uint(eid))
  for name, rng in random_animchar_vars__varNames, random_animchar_vars__varLimits
    if rng.x > rng.y
      logerr("[Animchar] {name} rng <{rng.x}>..<{rng.y}> is wrong for entity <{eid}> with template '{getEntityTemplateName(eid)}'")
      continue
    let value = _rnd_float(seed, rng.x, rng.y)

    let paramId = *animchar.animGraph |> anim_graph_getParamId(string(name), int(PT_ScalarParam))
    if paramId < 0
      logerr("[Animchar] name <{name}> not exist for entity <{eid}> with template '{getEntityTemplateName(eid)}'")
      continue
    *animchar.animState |> anim_state_holder_setParam(paramId, value)