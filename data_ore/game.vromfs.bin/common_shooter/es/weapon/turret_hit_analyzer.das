require ecs
require app
require game.utils.hero
require DaWeaponProps
require enlisted.events_enlisted
require common_shooter.es.weapon.turret_hit_analyzer_common

[es(tag=gameClient, after=(turret_weap_updater_es, turret_update_visual_shoot_tm_es))]
def turret_hit_analyzer_es(info : ParallelUpdateFrameDelayed;
                           turret_control__gunEids : EidList;
                           turret_current_visual_shoot_tm : float3x4;
                           turretCheckHitInterval : float;
                           isAlive : bool;
                           isExploded : bool;
                           isSimpleTurretCrosshair : bool = false;
                           var turretCheckHitAtTime : float&;
                           var turretHitPosThreadCalc : float3&;
                           var turretCheckHitResultThreadCalc : int&;
                           var turretCheckHitTeamThreadCalc : int&;
                           turret_hit_analyzer__maxDistance = 1000.f)
  if isAlive && !isExploded && !isSimpleTurretCrosshair
    for gunEid in turret_control__gunEids
      query(gunEid) <| $ [es(REQUIRE=(resolvedTurret, firstTurretInput, gun))] (turret_aim__shootDirWithCorrection : float3;
                                                                                gun__curShellId : ShellPropIds)
        if int(gun__curShellId.shellId) < 0
          return

        let curTime = get_sync_time()
        let mode = turretCheckHitAtTime > curTime ? SimulateMode FIND_HIT_POS_ONLY : SimulateMode FULL
        if mode == SimulateMode FULL
          turretCheckHitAtTime = curTime + turretCheckHitInterval

        var shootTm = turret_current_visual_shoot_tm
        shootTm[0] = turret_aim__shootDirWithCorrection

        simulate_shot(get_controlled_hero(), gun__curShellId,
                      shootTm, mode, turretCheckHitTeamThreadCalc, turretHitPosThreadCalc, turretCheckHitResultThreadCalc, turret_hit_analyzer__maxDistance)

[es(tag=gameClient, no_order, REQUIRE=vehicleWithWatched)]
def turret_hit_analyzer_applyer_es(info : UpdateStageInfoAct;
                                   turretCheckHitResultThreadCalc : int;
                                   turretHitPosThreadCalc : float3;
                                   turretCheckHitTeamThreadCalc : int;
                                   var turretCheckHitTeam : int&;
                                   var turretHitPos : float3&;
                                   var turretCheckHitResult : int&)
  turretCheckHitResult = turretCheckHitResultThreadCalc
  turretHitPos = turretHitPosThreadCalc
  turretCheckHitTeam = turretCheckHitTeamThreadCalc

[es(tag=gameClient, no_order, REQUIRE=hero)]
def gun_hit_analyzer_applyer_es(info : UpdateStageInfoAct;
                                gunCheckHitResultThreadCalc : int;
                                var gunCheckHitResult : int&)
  gunCheckHitResult = gunCheckHitResultThreadCalc;

[es(tag=gameClient, after=after_guns_update_sync)]
def gun_hit_analyzer_es(info : ParallelUpdateFrameDelayed;
                        gun__owner : EntityId;
                        gun__curShellId : ShellPropIds;
                        gunCheckHitInterval : float;
                        var gunCheckHitAtTime : float&;
                        var gunCheckHitResultThreadCalc : int&;
                        turret_hit_analyzer__maxDistance = 1000.f)
  let hero = get_controlled_hero()
  if gun__owner != hero
    return

  if int(gun__curShellId.shellId) >= 0
    query(hero) <| $ [es] (human__aimTm : float3x4)
      let curTime = get_sync_time()
      let mode = gunCheckHitAtTime > curTime ? SimulateMode FIND_HIT_POS_ONLY : SimulateMode FULL
      if mode == SimulateMode FULL
        gunCheckHitAtTime = curTime + gunCheckHitInterval

      var gunHitPos = float3()
      var gunCheckHitTeam = -1
      simulate_shot(hero, gun__curShellId, human__aimTm, mode, gunCheckHitTeam, gunHitPos, gunCheckHitResultThreadCalc, turret_hit_analyzer__maxDistance)
