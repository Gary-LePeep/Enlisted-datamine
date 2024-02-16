options always_export_initializer = true

require ecs
require app
require math.base
require game.es.ai.walker_common
require DagorDataBlock
require math
require math.random
require DagorMathUtils
require DagorMath
require DagorRandom
require BehNodes
require Dacoll
require walkerai
require DngWalkerai
require HumanPhys
require DngHuman
require DagorSystem
require ecs.ecs_template
require enlisted.game.es.enlisted_squad_common


[beh_node(name="findNamedAIPoint")]
class FindNamedAIPoint : BehNodeAdapter
  pointName : string
  pointNameParam = -1
  posOutParam = -1

  def override loadFromBlk(data : DataBlock) : void
    pointName = datablock_getStr(data, "pointName", "")
    if datablock_find_param(data, "pointNameParam") >= 0
      pointNameParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "pointNameParam", ""), "")
    posOutParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posOutParam", ""), float3())

  def override update(dt : float) : EBehResult
    if pointNameParam >= 0
      pointName = owner.blackBoard |> datablock_getStr(pointNameParam)
    let found = find_query() <| $ [es] (ai_point__name : string; transform : float3x4)
      if pointName != ai_point__name
        return false
      owner.blackBoard |> set(posOutParam, transform[3])
      return true
    return found ? EBehResult ER_SUCCESS : EBehResult ER_FAILED

[beh_node(name="findNamedAITarget")]
class FindNamedAITarget : BehNodeAdapter
  targetName : string
  targetNameParam = -1
  targetEidOutParam = -1

  def override loadFromBlk(data : DataBlock) : void
    targetName = datablock_getStr(data, "targetName", "")
    if datablock_find_param(data, "targetNameParam") >= 0
      targetNameParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetNameParam", ""), "")
    targetEidOutParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetEidOutParam", ""), 0)

  def override update(dt : float) : EBehResult
    if targetNameParam >= 0
      targetName = owner.blackBoard |> datablock_getStr(targetNameParam)
    var eids : array<EntityId>
    query() <| $ [es] (eid : EntityId; ai_target__name : string)
      if targetName != ai_target__name
        return
      eids |> push(eid)
    let count = length(eids)
    if count == 0
      return EBehResult ER_FAILED
    let eid = (count == 1) ? eids[0] : eids[rnd_int(0, count - 1)]
    owner.blackBoard |> set(targetEidOutParam, int(uint(eid)))
    return EBehResult ER_SUCCESS


[ecs_template]
struct switch_ai_behavior
  nonCreatableObj : bool = true
  switch_ai_behavior__agentEid : EntityId = INVALID_ENTITY_ID
  switch_ai_behavior__addTemplate : string
  switch_ai_behavior__delTemplate : string

def reset_to_default_beh_tree_node(eid : EntityId)
  let templateName = getEntityFutureTemplateName(eid)
  let templ = getTemplateByName(templateName)
  if templ != null
    let behTreeNode = get_ecs_string(getTemplateComponent(*templ, "beh_tree__node"))
    if behTreeNode != null && *behTreeNode != ""
      query(eid) <| $ [es] (var beh_tree__node : das_string&)
        beh_tree__node := *behTreeNode

[es(tag=server, on_appear)]
def switch_ai_behavior_es(evt : Event;
                          eid : EntityId;
                          switch_ai_behavior__agentEid : EntityId;
                          switch_ai_behavior__addTemplate : string;
                          switch_ai_behavior__delTemplate : string)
  let agentEid = switch_ai_behavior__agentEid

  if switch_ai_behavior__delTemplate == ""
    if switch_ai_behavior__addTemplate == ""
      reset_to_default_beh_tree_node(agentEid)
      reload_squad_mate_beh_tree(agentEid)
    else
      var templateName1 = getEntityTemplateName(agentEid)
      templateName1 = add_sub_template_name(templateName1, switch_ai_behavior__addTemplate)
      let cb1 <- @ <| (reid : EntityId)
        reset_to_default_beh_tree_node(reid)
        reload_squad_mate_beh_tree(reid)
      reCreateEntityFrom(agentEid, templateName1, cb1) <| $ [unused_argument(init)] (var init) {}
  else
    var templateName1 = getEntityTemplateName(agentEid)
    templateName1 = remove_sub_template_name(templateName1, switch_ai_behavior__delTemplate)
    let cb1 <- @ <| (reid : EntityId)
      if switch_ai_behavior__addTemplate == ""
        reset_to_default_beh_tree_node(reid)
        reload_squad_mate_beh_tree(reid)
      else
        var templateName2 = getEntityFutureTemplateName(reid)
        templateName2 = add_sub_template_name(templateName2, switch_ai_behavior__addTemplate)
        let cb2 <- @ <| (reid aka next_reid : EntityId)
          reset_to_default_beh_tree_node(next_reid)
          reload_squad_mate_beh_tree(next_reid)
        reCreateEntityFrom(reid, templateName2, cb2) <| $ [unused_argument(init)] (var init) {}
    reCreateEntityFrom(agentEid, templateName1, cb1) <| $ [unused_argument(init)] (var init) {}

  destroyEntity(eid)

def private switch_ai_behavior(eid : EntityId; add_template : string; del_template : string)
  return createEntity("switch_ai_behavior") <| $(var init : ComponentsInitializer)
    set(init, "switch_ai_behavior__agentEid", eid)
    set(init, "switch_ai_behavior__addTemplate", add_template)
    set(init, "switch_ai_behavior__delTemplate", del_template)

[beh_node(name="switchAIBehavior")]
class SwitchAIBehavior : BehNodeAdapter
  addTemplate : string
  addTemplateParam = -1
  delTemplate : string
  delTemplateParam = -1

  def override loadFromBlk(data : DataBlock) : void
    addTemplate = datablock_getStr(data, "addTemplate", "")
    if datablock_find_param(data, "addTemplateParam") >= 0
      addTemplateParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "addTemplateParam", ""), "")

    delTemplate = datablock_getStr(data, "delTemplate", "")
    if datablock_find_param(data, "delTemplateParam") >= 0
      delTemplateParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "delTemplateParam", ""), "")

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)

    if addTemplateParam >= 0
      addTemplate = owner.blackBoard |> datablock_getStr(addTemplateParam)
    if delTemplateParam >= 0
      delTemplate = owner.blackBoard |> datablock_getStr(delTemplateParam)

    let switchEid = switch_ai_behavior(agentEid, addTemplate, delTemplate)
    return switchEid != INVALID_ENTITY_ID ? EBehResult ER_SUCCESS : EBehResult ER_FAILED
