options no_aot
require ecs
require ecs.safe
require DagorConsole
require DagorDebug3D
require strings
require game.es.net_console_macro

[console_cmd(name="player.findByName")]
def console_player_find(playerName : string)
  createEntity("player_with_name_debug") <| $(var init : ComponentsInitializer)
    set(init, "name", playerName)

[net_console_cmd(name="player.rearm", hint="Restore soldier gun's ammo")]
def player_rearm_cmd(ammo_count : int = 10; [[net_hero]] hero_eid : EntityId)
  query(hero_eid) <| $ [es] (human_weap__gunEids : EidList)
    for gunEid in human_weap__gunEids
      query(gunEid) <| $ [es] (gun__ammoHolders : Array)
        for ammoHolder in gun__ammoHolders
          let ammoTemplate = ammoHolder ?? ""
          if ammoTemplate == ""
            continue

          for _i in range(0, ammo_count)
            createEntity(ammoTemplate) <| $(var init : ComponentsInitializer)
              set(init, "item__ownerEid", hero_eid)

[es(tag=(render, dev), no_order, REQUIRE=player_with_name_debug)]
def draw_founded_player(evt : UpdateStageInfoRenderDebug;
                        name aka found_name : string)
  query() <| $ [es(REQUIRE=player)] (name : string;
                                     possessed : EntityId)
    if found_name == name
      query(possessed) <| $ [es] (transform : float3x4)
        add_debug_text_mark(transform[3], name, -1, 0f, E3DCOLOR(0xFFFFFFFF))