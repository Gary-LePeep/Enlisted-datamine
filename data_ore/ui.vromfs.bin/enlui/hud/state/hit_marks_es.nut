import "%dngscripts/ecs.nut" as ecs
from "%enlSqGlob/ui/ui_library.nut" import *

let { TEAM_UNASSIGNED } = require("team")
let {DmProjectileHitNotification, DM_PROJECTILE, DM_MELEE, DM_BACKSTAB } = require("dm")
let {HitResult} = require("%enlSqGlob/dasenums.nut")
let {get_time_msec} = require("dagor.time")
let {EventHeroChanged} = require("gameevents")
let {EventAnyEntityDied,EventOnEntityHit} = require("dasevents")
let {watchedHeroEid} = require("%ui/hud/state/watched_hero.nut")

let hitTtl = Watched(1.2)//animation is tripple less in duration
let killTtl = Watched(1.8)//animation is tripple less in duration
let worldKillTtl = Watched(4.0)
let showWorldKillMark = Watched(true)
/*
 TODO:
   EventOnEntityHit should be split to several other events
     EventOnKilledHit - means this hit killed (for killMarks)
     EventOnAliveHit - means this hit wasn't on dead.
       currently we can skip hits on if event will be received later than replication of isAlive of victim
*/
let hitMarks = mkWatched(persist, "hits", [])
let killMarks = mkWatched(persist, "killMarks", [])

function mkRemoveHitMarkById(state, id){
  return function(){
    state.update(state.value.filter((@(mark) mark.id!=id)))
  }
}

function removePreviousHitmarksByVictimEid(state, eid) {
  state(state.value.filter((@(mark) mark.victimEid != eid)))
}

function addMark(hitMark, state, ttl){
  state.mutate(function(v){
    return v.append(hitMark.__merge({ttl=ttl})) // warning disable: -unwanted-modification
  })
  gui_scene.setTimeout(ttl, mkRemoveHitMarkById(state, hitMark.id))
}

local counter = 0

let cachedHitTtl = max(hitTtl.value, killTtl.value)
foreach (w in [hitTtl,killTtl])
  w.subscribe(@(_) max(hitTtl.value, killTtl.value))

local cachedWorldKillTtl = worldKillTtl.value
worldKillTtl.subscribe(@(v) cachedWorldKillTtl = v)
local cachedShowWorldKillMark = showWorldKillMark.value
showWorldKillMark.subscribe(@(v) cachedShowWorldKillMark = v)

function addHitMark(hitMark){
  addMark(hitMark, hitMarks, cachedHitTtl)
}

function addKillMark(hitMark){
  let victim = hitMark?.victimEid
  if (hitMark?.killPos == null || victim == null)
    return
  killMarks(killMarks.value.filter(@(v) v.victimEid != victim))
  addMark(hitMark, killMarks, cachedWorldKillTtl)
}

let getVictimTeamQuery = ecs.SqQuery("getVictimTeamQuery", {
  comps_ro=[
    ["team", ecs.TYPE_INT]
  ],
  comps_no=["stationary_gun", "noHitMark"]
})

let getVictimImmunityTimerQuery = ecs.SqQuery("getVictimImmunityTimerQuery", {
  comps_ro=[
    ["spawn_immunity__timer", ecs.TYPE_FLOAT]
  ]
})

const DM_DIED = "DM_DIED"
function onHit(victimEid, _offender, extHitPos, damageType, hitRes) {
  counter++
  let time = get_time_msec()

  local hitPos = null
  let isDownedHit = hitRes == HitResult.HIT_RES_DOWNED
  let isKillHit = hitRes == HitResult.HIT_RES_KILLED
  let independentKill = damageType == DM_DIED
  let isMelee = [DM_BACKSTAB, DM_MELEE].indexof(damageType)!=null
  if (isMelee)
    hitPos = [extHitPos.x, extHitPos.y, extHitPos.z]
  local killPos = null
  if (isKillHit || isDownedHit || independentKill) {
    killPos = ecs.obsolete_dbg_get_comp_val(victimEid, "transform", null)
    killPos = killPos!=null ? killPos.getcol(3) : hitPos
    hitPos = [extHitPos.x, extHitPos.y, extHitPos.z]
    killPos = [killPos.x, killPos.y+0.6, killPos.z]
  }
  local immunityTimer = -1.;
  getVictimImmunityTimerQuery.perform(victimEid, function(_eid, comp) {
    immunityTimer = comp["spawn_immunity__timer"]
  })
  let hitMark = {id=counter, victimEid = victimEid, time = time,
    hitPos = hitPos, hitRes = hitRes, killPos = cachedShowWorldKillMark ? killPos : null, isKillHit=isKillHit,
    isDownedHit=isDownedHit, isMelee = isMelee, isImmunityHit = immunityTimer > 0.}
  if (!independentKill) {
    removePreviousHitmarksByVictimEid(hitMarks, victimEid)
    addHitMark(hitMark)
  }
  if (cachedShowWorldKillMark && (isKillHit || isDownedHit))
    addKillMark(hitMark)
}

let getVictimShowHits = ecs.SqQuery("getVictimShowHits", {comps_ro=[
  ["hitmarks_victim__groupId", ecs.TYPE_INT],
  ["deadEntity", ecs.TYPE_TAG, null],
]})

let getHitmarksGroupsId = ecs.SqQuery("getHitmarksGroupsId", {comps_ro=[
  ["hitmarks__groupsIds", ecs.TYPE_INT_LIST]
]})

function onProjectileHit(evt, eid, comp) {
  let victimEid = evt[0]
  let hitPos = evt[1]
  let hitmarksGroupsId = getHitmarksGroupsId(comp.human_anim__vehicleSelected, @(_, vehComp) vehComp.hitmarks__groupsIds.getAll()) ?? []
  let shouldShowHitMarks = getVictimShowHits(victimEid, @(_, victimComp) victimComp.deadEntity == null && hitmarksGroupsId.contains(victimComp.hitmarks_victim__groupId)) ?? false
  if (!shouldShowHitMarks || victimEid == eid)
    return
  onHit(victimEid, eid, hitPos, DM_PROJECTILE, HitResult.HIT_RES_NORMAL)
}

function onEntityHit(evt, _eid, _comp) {
  let victimEid = evt.victim
  let offender = evt.offender
  local victimTeam = TEAM_UNASSIGNED
  getVictimTeamQuery.perform(victimEid, @(_eid, comp) victimTeam = comp["team"])

  if (offender != watchedHeroEid.value || victimEid == offender ||
      victimTeam == TEAM_UNASSIGNED || evt.deltaHp <= 0)
    return

  let hitRes = evt.hitResult
  if (hitRes != HitResult.HIT_RES_NONE)
    onHit(victimEid, offender, evt.hitPos, evt.damageType, hitRes)
}

function onEntityDied(evt, _eid, _comp) {
  let { victim, offender } = evt
  local victimTeam = TEAM_UNASSIGNED
  getVictimTeamQuery.perform(victim, @(_eid, comp) victimTeam = comp["team"])

  if (offender != watchedHeroEid.value || victim == offender || victimTeam == TEAM_UNASSIGNED)
    return

  let tm = ecs.obsolete_dbg_get_comp_val(victim, "transform", null)
  onHit(victim, offender, tm.getcol(3), DM_DIED, HitResult.HIT_RES_KILLED)
}


ecs.register_es("script_hit_marks_es", {
    [EventOnEntityHit] = onEntityHit,
    [EventAnyEntityDied] = onEntityDied,
    [EventHeroChanged] = @() hitMarks.update([])
  }, {}
)

ecs.register_es("script_hit_marks_dm_es", {
    [DmProjectileHitNotification] = onProjectileHit,
  },
  { comps_ro = [["human_anim__vehicleSelected", ecs.TYPE_EID]],
    comps_rq = ["watchedByPlr"]
  }
)

return {
  hitMarks
  killMarks
  //settings
  hitColor = Watched(Color(200, 200, 200, 200))
  downedColor = Watched(Color(200, 20, 0, 200))
  killColor = Watched(Color(200, 0, 0, 200))
  worldKillMarkColor = Watched(Color(180, 20, 20, 170))
  worldDownedMarkColor = Watched(Color(230, 120, 30, 170))
  hitSize = Watched([fsh(3),fsh(3)])
  killSize = Watched([fsh(3.5),fsh(3.5)])
  worldKillMarkSize = Watched([fsh(2.5),fsh(2.5)])
  showWorldKillMark
  hitTtl
  killTtl
  worldKillTtl
}
