require app
require ecs

[es(tag=server, REQUIRE=(squad_member__squad), on_appear, track=(possessedByPlr, ai_enabled))]
def switch_ai_on_possess_unpossess(evt : Event;
                                   possessedByPlr : EntityId;
                                   human_weap__gunEids : EidList;
                                   human_weap__reloadFinishTime : float;
                                   var beh_tree__enabled : bool&;
                                   var human_weap__infiniteAmmoHolders : bool?;
                                   var human_weap__lastTimeInfiniteAmmoEnabled : float?;
                                   ai_enabled : bool = true)
  let needsAI = !possessedByPlr || has(possessedByPlr, "botAiEnabler")

  beh_tree__enabled = needsAI && ai_enabled

  if human_weap__infiniteAmmoHolders != null
    *human_weap__infiniteAmmoHolders = needsAI
    if needsAI && human_weap__lastTimeInfiniteAmmoEnabled != null
      *human_weap__lastTimeInfiniteAmmoEnabled = get_sync_time()

  if needsAI
    for i in iter_range(human_weap__gunEids)
      query(human_weap__gunEids[i]) <| $ [es] (gun__ammo : int; var gun__ammoOnSwitch : int&; gun__ammoToReloadCount : int)
        // Ammo on switch is remembered, so that bot consumes a magazine, if he reloads an empty gun.
        // So that the player can't easily make a bot reload a gun without consuming a magazine.
        if human_weap__reloadFinishTime < get_sync_time()
          gun__ammoOnSwitch = gun__ammo
        else
          gun__ammoOnSwitch = gun__ammoToReloadCount
