import json
from pathlib import Path


def delistify(old_json):
    if isinstance(old_json, list):
        new_json = {}
        for item in old_json:
            if list(item.keys())[0] not in new_json:
                new_json[list(item.keys())[0]] = list(item.values())[0]
        old_json = new_json
    return old_json


def translation_items():
    english_json = json.load(open("../Enlisted-remastered/static/translations/English.json", encoding='utf-8'))
    russian_json = json.load(open("../Enlisted-remastered/static/translations/Russian.json", encoding='utf-8'))

    translations1_csv = open("./data_ore/enlisted-lang.vromfs.bin/lang/common/common.csv", encoding='utf-8').read()
    #translations2_csv = open("./data_ore/enlisted-lang.vromfs.bin/lang/enlisted/enlisted.csv", encoding='utf-8').read()
    translations_list = translations1_csv.split('\n')# + translations2_csv.split('\n')

    english_offset = -1
    russian_offset = -1

    languages = translations_list[0].split(';')
    i = 0
    for language in languages:
        if language == "\"<English>\"":
            english_offset = i
        if language == "\"<Russian>\"":
            russian_offset = i
        i += 1

    # Soldier classes
    for translation in translations_list:
        if translation.startswith('"soldierClass/'):
            class_name = translation.split('"soldierClass/')[1].split('";"')[0]
            if '/desc' not in class_name and ('_' not in class_name or class_name == 'anti_tank' or class_name == 'pilot_fighter' or class_name == 'pilot_assaulter'):
                english_json['class.' + class_name] = translation.split(';')[english_offset].replace('"', '')
                russian_json['class.' + class_name] = translation.split(';')[russian_offset].replace('"', '')

    # Perk names
    for translation in translations_list:
        if translation.split('";"')[0].count('/') == 2 and translation.startswith('"stat/') and '/desc' in translation.split('";"')[0]:
            perk_name = translation.split('/')[1].split('/')[0]
            english_json['perk.' + perk_name] = translation.split(';')[english_offset].replace('"', '')
            russian_json['perk.' + perk_name] = translation.split(';')[russian_offset].replace('"', '')

    # Item names
    for translation in translations_list:
        if translation.split('";"')[0].count('/') == 1 and translation.startswith('"items/') and translation.count(';') >= 2:
            item_name = translation.split('/')[1].split('";"')[0]
            # Translation exceptions
            if 'mp_717r' == item_name:
                item_name = 'stl_' + item_name
            if 'uk_valentine_mk_1' == item_name:
                item_name = 'ussr_valentine_i'
            if 'germ_pzkpfw_iii_ausf_j' == item_name:
                item_name = 'germ_pzkpfw_iii_ausf_j1_l60'
            if 'us_m4_sherman_calliope' == item_name:
                item_name = 'us_m4_calliope'
            if 'uk_a_22b_mk_3_churchill_1942' == item_name:
                item_name = 'churchill_3'
            if 'germ_pz_iv_l70' == item_name:
                item_name = 'germ_panzerjager_iv_l_70'
            if 'ussr_t_34_85e' == item_name:
                item_name = 'ussr_t_34_85_e'
            if 'germ_panzerjager_panther' == item_name:
                item_name = 'germ_jagdpanther'
            if 'germ_pz_iv_l70_a' == item_name:
                item_name = 'germ_panzerjager_iv_l_70_a'
            if 'uk_a_13_mk2' == item_name:
                item_name = 'uk_a13_mk_2_1939'
            if 'ussr_a_12_mk_2_matilda_2' == item_name:
                item_name = 'ussr_matilda_iii'
            if 'ussr_t_70_1942' == item_name:
                item_name = 'ussr_t_70'
            if 'us_m3_stuart' == item_name:
                item_name = 'us_m3a1_stuart'
            english_json['item.' + item_name] = translation.split(';')[english_offset].replace('"', '')
            if russian_offset >= len(translation.split(';')):
                russian_json['item.' + item_name] = translation.split(';')[english_offset].replace('"', '')
            else:
                russian_json['item.' + item_name] = translation.split(';')[russian_offset].replace('"', '')

    # Firing modes
    for translation in translations1_csv.split('\n'):
        if translation.split('";"')[0].count('/') == 1 and translation.startswith('"firing_mode/'):
            firing_mode = translation.split('/')[1].split('";"')[0]
            english_json['firingMode.' + firing_mode] = translation.split(';')[english_offset].replace('"', '')
            russian_json['firingMode.' + firing_mode] = translation.split(';')[russian_offset].replace('"', '')

    # Remove apostrophes
    for (k, v) in english_json.items():
        if "'" in v:
            english_json[k] = v.replace("'", '~')

    # Sort and save
    english_json = dict(sorted(english_json.items()))
    russian_json = dict(sorted(russian_json.items()))
    with open('../Enlisted-remastered/static/translations/English.json', 'w', encoding='utf-8') as f:
        json.dump(english_json, f, ensure_ascii=False, indent=4)
    with open('../Enlisted-remastered/static/translations/Russian.json', 'w', encoding='utf-8') as f:
        json.dump(russian_json, f, ensure_ascii=False, indent=4)


def soldier_damage():
    soldier_damage_json = json.load(open("./data_ore/enlisted-game.vromfs.bin/gamedata/templates/enlisted_shooter_humans.blkx", encoding='utf-8'))
    soldier_damage_list = []
    for (k, v) in soldier_damage_json['human']['dm_parts__parts:object'].items():
        soldier_damage_list.append({
            k.split('Bip01 ')[1].split(':object')[0]: v['dmgMult']
        })
    soldier_damage_list_neck_last = sorted(soldier_damage_list, key=lambda d: -abs(ord(list(d.keys())[0][0]) - ord('N')))
    with open('../Enlisted-remastered/static/soldierStats/soldierDamage.json', 'w', encoding='utf-8') as f:
        json.dump(soldier_damage_list_neck_last, f, ensure_ascii=False, indent=4, sort_keys=True)


def get_weapons():
    # Get all weapons
    weapons_ww2 = json.load(open("./data_ore/enlisted-game.vromfs.bin/gamedata/templates/e_ww2_common/ww2_guns.blkx", encoding='utf-8'))
    weapons_tun = json.load(open("./data_ore/enlisted-game.vromfs.bin/gamedata/templates/tunisia/tunisia_guns.blkx", encoding='utf-8'))
    weapons_stl = json.load(open("./data_ore/enlisted-game.vromfs.bin/gamedata/templates/stalingrad_guns.blkx", encoding='utf-8'))
    weapons = {**weapons_ww2, **weapons_tun, **weapons_stl}

    valid_guns = []
    for (k, v) in weapons.items():
        if not isinstance(v, list):
            new_v = []
            for (a, b) in v.items():
                new_v.append({
                    a: b
                })
            v = new_v
        new_gun = {
            'name': k
        }
        for param in v:
            if 'gun__blk' == list(param.keys())[0]:
                valid_guns.append(new_gun)

    # Get all items
    items_common = json.load(open("./data_ore/enlisted-game.vromfs.bin/gamedata/templates/e_ww2_common/ww2_items.blkx", encoding='utf-8'))
    tunisia_common = json.load(open("./data_ore/enlisted-game.vromfs.bin/gamedata/templates/tunisia/tunisia_items.blkx", encoding='utf-8'))
    stalingrad_common = json.load(open("./data_ore/enlisted-game.vromfs.bin/gamedata/templates/stalingrad_items.blkx", encoding='utf-8'))
    items = {**items_common, **tunisia_common, **stalingrad_common}

    for gun in valid_guns:
        starting_extensions = [str(gun['name']) + '_gun', gun['name']]
        gun['rps'] = find_property(weapons, 'gun__shotFreq', starting_extensions.copy())
        gun['dispersion'] = find_property(weapons, 'gun_spread__maxDeltaAngle', starting_extensions.copy())
        gun['stat'] = find_property(weapons, 'gun__statName', starting_extensions.copy())
        gun['type'] = find_property(weapons, 'item__weapType', starting_extensions.copy())
        gun['weight'] = find_property(weapons, 'item__weight', starting_extensions.copy())
        gun['locName'] = find_property(weapons, 'gun__locName', starting_extensions.copy())
        gun['locName'] = None if gun['locName'] is None else gun['locName'].replace("'", '~')
        mag_name = find_property(weapons, 'gun__ammoHolders:array', starting_extensions.copy())
        gun['magazineName'] = mag_name
        if mag_name is None:
            gun['magazineSize'] = None
        elif isinstance(mag_name, list):
            magazine_item = items[mag_name[0]['ammoHolders']] if 'ammoHolders' in mag_name[0] else items[mag_name[0]['ammoHolder']]
            gun['magazineSize'] = magazine_item['ammo_holder__ammoCount'] if 'ammo_holder__ammoCount' in magazine_item else None
        elif 'smle_2_5_inch_rifle_grenade.blk' not in str(mag_name):  # Why is this even?
            magazine_item = items[mag_name['ammoHolders']] if 'ammoHolders' in mag_name else items[mag_name['ammoHolder']]
            gun['magazineSize'] = magazine_item['ammo_holder__ammoCount'] if 'ammo_holder__ammoCount' in magazine_item else None
        gun['bullets'] = find_property(weapons, 'gun__shells:array', starting_extensions.copy())
        gun['firingModes'] = find_property(weapons, 'gun__firingModeNames:array', starting_extensions.copy())
        gun['singleReloadPrep'] = find_property(weapons, 'single_reload__prepareTime', starting_extensions.copy())
        gun['singleReloadLoop'] = find_property(weapons, 'single_reload__loopTime', starting_extensions.copy())
        gun['singleReloadPost'] = find_property(weapons, 'single_reload__postTime', starting_extensions.copy())
        gun['reload'] = find_property(weapons, 'gun__reloadTime', starting_extensions.copy())
        gun['altReload'] = find_property(weapons, 'gun__altReloadTime', starting_extensions.copy())
        gun['dualMagReload'] = find_property(weapons, 'gun__dualMagReloadTime', starting_extensions.copy())
        gun['proneRecoilMult'] = find_property(weapons, 'gun__crawlRecoilMult', starting_extensions.copy())
        gun['zeroDist'] = find_property(weapons, 'gun__sightsDistance', starting_extensions.copy())
        gun['reloadSingle'] = find_reload_single_bullet(weapons, starting_extensions.copy())
        gun['recoilAmount'] = find_property(weapons, 'gun__recoilAmount', starting_extensions.copy())
        gun['recoilDir'] = find_property(weapons, 'gun__recoilDir', starting_extensions.copy())
        gun['recoilDirAmount'] = find_property(weapons, 'gun__recoilDirAmount', starting_extensions.copy())
        gun['visualRecoilMult'] = find_property(weapons, 'gun__visualRecoilMult', starting_extensions.copy())
        gun['recoilControlMult'] = find_property(weapons, 'gun__recoilControlMult', starting_extensions.copy())
        gun['recoilOffsetMult'] = find_property(weapons, 'gun__recoilOffsMult', starting_extensions.copy())
        gun['mods'] = find_property(weapons, 'gun_mods__slots:object', starting_extensions.copy())
        gun['adsSpeedMult'] = find_property(weapons, 'gun__adsSpeedMult', starting_extensions.copy())
        gun['damageMult'] = find_property(weapons, 'gun__kineticDamageMult', starting_extensions.copy())
        gun['sightsMag'] = find_property(weapons, 'gun__magnification', starting_extensions.copy())
        gun['flamethrowerDPS'] = find_property(weapons, 'flamethrower__streamDamagePerSecond', starting_extensions.copy())
        gun['flamethrowerMaxLength'] = find_property(weapons, 'flamethrower__maxFlameLength', starting_extensions.copy())
    # Get basic grenades
    json_paths = [
        {'name': 'explosion_pack', 'path': Path('./data_ore/enlisted-game.vromfs.bin/gamedata/weapons/grenades/explosion_pack.blkx')},
        {'name': 'grenade', 'path': Path('./data_ore/enlisted-game.vromfs.bin/gamedata/weapons/grenades/f1.blkx')},
        {'name': 'molotov_grenade', 'path': Path('./data_ore/enlisted-game.vromfs.bin/gamedata/weapons/grenades/molotov_base.blkx')},
        {'name': 'incendiary_grenade', 'path': Path('./data_ore/enlisted-game.vromfs.bin/gamedata/weapons/grenades/m_15_incendiary_grenade.blkx')},
        {'name': 'impact_grenade', 'path': Path('./data_ore/enlisted-game.vromfs.bin/gamedata/weapons/grenades/no_69_impact_grenade.blkx')},
        {'name': 'antipersonnel_mine', 'path': Path('./data_ore/enlisted-game.vromfs.bin/gamedata/weapons/antipersonnel_mine.blkx')},
        {'name': 'antitank_mine', 'path': Path('./data_ore/enlisted-game.vromfs.bin/gamedata/weapons/antitank_mine.blkx')},
        {'name': 'tnt_block', 'path': Path('./data_ore/enlisted-game.vromfs.bin/gamedata/weapons/tnt_block.blkx')}
    ]
    for json_item in json_paths:
        grenade_json = delistify(json.load(open(json_item['path'], encoding='utf-8')))
        valid_guns.append({
            'name': json_item['name'],
            'explosive': 'explosive',
            'type': 'explosive',
            'weight': grenade_json['mass'] if 'mass' in grenade_json else None,
            'bullets': {
                'shells': json_item['name']
            },
        })
    with open('../Enlisted-remastered/static/datamine/weapons.json', 'w', encoding='utf-8') as f:
        json.dump(valid_guns, f, ensure_ascii=False, indent=4)


def find_reload_single_bullet(json_data, extensions):
    if not extensions:
        return False
    for (k, v) in json_data.items():
        if k != extensions[0]:
            continue
        if not isinstance(v, list):
            new_v = []
            for (a, b) in v.items():
                new_v.append({
                    a: b
                })
            v = new_v
        # Add all extensions and search for RSB
        for param in v:
            if '_extends' == list(param.keys())[0]:
                extensions.append(param['_extends'])
                if "reload_single_bullet" == list(param.values())[0]:
                    return True
    # This one failed
    extensions.pop(0)
    # Look for property in extensions
    return find_reload_single_bullet(json_data, extensions)


def find_property(json_data, property_name, extensions):
    if not extensions:
        return None
    for (k, v) in json_data.items():
        if k != extensions[0]:
            continue
        if not isinstance(v, list):
            new_v = []
            for (a, b) in v.items():
                new_v.append({
                    a: b
                })
            v = new_v
        # Add all extensions
        for param in v:
            if '_extends' == list(param.keys())[0]:
                extensions.append(param['_extends'])
            if '_use' == list(param.keys())[0]:
                extensions.append(param['_use'])
        # Search for property
        for param in v:
            if property_name == list(param.keys())[0]:
                return param[property_name]
    # This one failed
    extensions.pop(0)
    # Look for property in extensions
    return find_property(json_data, property_name, extensions)


def get_bullets():
    # Get all bullets
    bullets = {}
    json_paths = list(Path('./data_ore/enlisted-game.vromfs.bin/gamedata/weapons/bullets').rglob('*.blkx')) + list(Path('./data_ore/enlisted-game.vromfs.bin/gamedata/weapons/shells').rglob('*.blkx'))
    for path in json_paths:
        bullet_json = delistify(json.load(open(path, encoding='utf-8')))
        # If already exists, override unless override is null
        old_name = '.'.join(path.name.split('.')[:-1])
        if old_name in bullets:
            bullets[old_name] = {
                'maxDistance': bullet_json['maxDistance'] if 'maxDistance' in bullet_json else bullets[old_name]['maxDistance'],
                'effectiveDistance': bullet_json['effectiveDistance'] if 'effectiveDistance' in bullet_json else bullets[old_name]['effectiveDistance'],
                'hitPowerMult': bullet_json['hitPowerMult'] if 'hitPowerMult' in bullet_json else bullets[old_name]['hitPowerMult'],
                'hitpower': bullet_json['hitpower'] if 'hitpower' in bullet_json else bullets[old_name]['hitpower'],
                'armorpower': bullet_json['armorpower'] if 'armorpower' in bullet_json else bullets[old_name]['armorpower'],
                'speed': bullet_json['speed'] if 'speed' in bullet_json else bullets[old_name]['speed'],
                'spawn': bullet_json['spawn'] if 'spawn' in bullet_json else bullets[old_name]['spawn'],
                'cumulativeDamage': bullet_json['cumulativeDamage'] if 'cumulativeDamage' in bullet_json else bullets[old_name]['cumulativeDamage'],
                'explodeHitPower': bullet_json['explodeHitPower'] if 'explodeHitPower' in bullet_json else bullets[old_name]['explodeHitPower'],
                'explodeRadius': bullet_json['explodeRadius'] if 'explodeRadius' in bullet_json else bullets[old_name]['explodeRadius'],
                'splashDamage': bullet_json['splashDamage'] if 'splashDamage' in bullet_json else bullets[old_name]['splashDamage'],
                'detonation': bullet_json['detonation'] if 'detonation' in bullet_json else bullets[old_name]['detonation'],
            }
        else:
            bullets[old_name] = {
                'maxDistance': bullet_json['maxDistance'] if 'maxDistance' in bullet_json else None,
                'effectiveDistance': bullet_json['effectiveDistance'] if 'effectiveDistance' in bullet_json else None,
                'hitPowerMult': bullet_json['hitPowerMult'] if 'hitPowerMult' in bullet_json else None,
                'hitpower': bullet_json['hitpower'] if 'hitpower' in bullet_json else None,
                'armorpower': bullet_json['armorpower'] if 'armorpower' in bullet_json else None,
                'speed': bullet_json['speed'] if 'speed' in bullet_json else None,
                'spawn': bullet_json['spawn'] if 'spawn' in bullet_json else None,
                'cumulativeDamage': bullet_json['cumulativeDamage'] if 'cumulativeDamage' in bullet_json else None,
                'explodeHitPower': bullet_json['explodeHitPower'] if 'explodeHitPower' in bullet_json else None,
                'explodeRadius': bullet_json['explodeRadius'] if 'explodeRadius' in bullet_json else None,
                'splashDamage': bullet_json['splashDamage'] if 'splashDamage' in bullet_json else None,
                'detonation': bullet_json['detonation'] if 'detonation' in bullet_json else None,
            }

    # Get basic grenades
    json_paths = [
        {'name': 'explosion_pack', 'path': Path('./data_ore/enlisted-game.vromfs.bin/gamedata/weapons/grenades/explosion_pack.blkx')},
        {'name': 'grenade', 'path': Path('./data_ore/enlisted-game.vromfs.bin/gamedata/weapons/grenades/f1.blkx')},
        {'name': 'molotov_grenade', 'path': Path('./data_ore/enlisted-game.vromfs.bin/gamedata/weapons/grenades/molotov_base.blkx')},
        {'name': 'incendiary_grenade', 'path': Path('./data_ore/enlisted-game.vromfs.bin/gamedata/weapons/grenades/m_15_incendiary_grenade.blkx')},
        {'name': 'impact_grenade', 'path': Path('./data_ore/enlisted-game.vromfs.bin/gamedata/weapons/grenades/no_69_impact_grenade.blkx')},
        {'name': 'antipersonnel_mine', 'path': Path('./data_ore/enlisted-game.vromfs.bin/gamedata/weapons/antipersonnel_mine.blkx')},
        {'name': 'antitank_mine', 'path': Path('./data_ore/enlisted-game.vromfs.bin/gamedata/weapons/antitank_mine.blkx')},
        {'name': 'tnt_block', 'path': Path('./data_ore/enlisted-game.vromfs.bin/gamedata/weapons/tnt_block.blkx')}
    ]
    for json_item in json_paths:
        grenade_json = delistify(json.load(open(json_item['path'], encoding='utf-8')))
        bullets[json_item['name']] = {
            'explodeHitPower': grenade_json['explodeHitPower'] if 'explodeHitPower' in grenade_json else None,
            'explodeRadius': grenade_json['explodeRadius'] if 'explodeRadius' in grenade_json else None,
            'explodeArmorPower': grenade_json['explodeArmorPower'] if 'explodeArmorPower' in grenade_json else None,
            'splashDamage': grenade_json['splashDamage'] if 'splashDamage' in grenade_json else None,
            'detonation': grenade_json['detonation'] if 'detonation' in grenade_json else None,
            'speed': grenade_json['speed'] if 'speed' in grenade_json else None,
            'hitpower': None
        }
    with open('../Enlisted-remastered/static/datamine/bullets.json', 'w', encoding='utf-8') as f:
        json.dump(bullets, f, ensure_ascii=False, indent=4)


def get_tanks():
    # Get all tanks
    tanks = []
    json_paths = list(Path('./data_ore/tanks.vromfs.bin/gamedata/templates/tanks').rglob('*.blkx')) + list(Path('./data_ore/tanks.vromfs.bin/gamedata/templates/apc').rglob('*.blkx'))

    combined_tanks_json = {}
    for path in json_paths:
        tank_json = delistify(json.load(open(path, encoding='utf-8')))
        for (k, v) in tank_json.items():
            combined_tanks_json[k] = v

    for path in json_paths:
        tank_json = delistify(json.load(open(path, encoding='utf-8')))
        name_game = '.'.join(path.name.split('.')[:-1])
        name = list(tank_json)[0]

        file_json_name = name_game.replace('germ_', '').replace('it_', '').replace('jp_', '').replace('uk_', '').replace('us_', '').replace('ussr_', '')
        # Fix some tank names
        file_json_name = file_json_name.replace('flakpanzer', 'flpz').replace('jagdpanther', 'panzerjager_panther').replace('pzkpfw_iii_ausf_j', 'pzkpfw_iii_ausf_j_l42').replace('pzkpfw_iii_ausf_j_l421', 'pzkpfw_iii_ausf_j_l42').replace('_movable', '').replace('cromwel_5', 'cromwell_5').replace('is_2_1943', 'is_2').replace('su_100_1945', 'su_100').replace('m4_calliope', 'm4_sherman_calliope')
        #if 'jgdpz_38t' in file_json_name:
        #    continue

        try:
            turret_json = delistify(json.load(open(Path(f'./data_ore/tanks.vromfs.bin/gamedata/gen/templates/tanks/{file_json_name}.blkx'), encoding='utf-8')))
        except Exception as e:
            print(e)
        try:
            armor_json = delistify(json.load(open(Path(f'./data_ore/tanks.vromfs.bin/gamedata/gen/units/tanks/{file_json_name}.blkx'), encoding='utf-8')))
        except Exception as e:
            print(e)
        distrib_json = delistify(json.load(open(Path(f'{path.parent}/{name_game}.blkx'), encoding='utf-8')))

        ammo_distrib_json = find_property(distrib_json, 'turrets__initAmmoDistribution:array', [list(distrib_json)[0]])
        ammo_distrib = []
        if ammo_distrib_json != None:
            ammo_distrib_json = ammo_distrib_json if isinstance(ammo_distrib_json, list) else [ammo_distrib_json]
            for ammo_slot in ammo_distrib_json:
                if 'slot' in ammo_slot['ammo:object']:
                    ammo_distrib.append(ammo_slot['ammo:object']['slot'])
                else:
                    ammo_distrib = [0, 1]
        else:
            ammo_distrib = [0, 1]

        turrets = []
        for (k, v) in turret_json.items():
            if '_turret_' in k:
                ammo_count = 0
                if 'gun__shellsAmmo:array' in v and isinstance(v['gun__shellsAmmo:array'], list):
                    for ammo in v['gun__shellsAmmo:array']:
                        ammo_count += ammo['ammo']
                else:
                    ammos = find_property(turret_json, 'gun__shellsAmmo:array', [k])
                    ammos = ammos if isinstance(ammos, list) else [ammos]
                    for ammo in ammos:
                        ammo_count += ammo['ammo']

                gun = {}
                if isinstance(v, list):
                    v = delistify(v)
                if k == 'ht_130_turret_01_ato_41' or 'flammenwerfer_anlagen' in k:
                    # Flamethrower tanks are stupid. Just hardcode it.
                    gun['name'] = 'ht_130_turret_01_ato_41'
                    gun_json = delistify(json.load(open(Path('./data_ore/tanks.vromfs.bin/gamedata/gen/templates/tanks/ht_130.blkx'), encoding='utf-8'))[gun['name']])
                elif 'tankgun_' in v['_use']:
                    gun['name'] = v['_use'].replace('tankgun_', '')
                    gun_json = delistify(json.load(open(Path('./data_ore/tanks.vromfs.bin/gamedata/gen/templates/weapons/' + gun['name'] + '.blkx'), encoding='utf-8')))
                    gun_json = gun_json[list(gun_json)[0]]
                else:
                    print('gun not found for turret: ' + k)
                    continue
                gun['rps'] = gun_json['gun__shotFreq']
                gun['reload'] = (None if gun_json['gun__reloadTime'] < 0 else gun_json['gun__reloadTime']) if 'gun__reloadTime' in gun_json else None
                gun['ammoBelt'] = gun_json['gun__maxAmmo'] if 'gun__maxAmmo' in gun_json else None
                gun['shells'] = []
                i = 0
                for (l, w) in gun_json['gun__ammoSetsInfo:shared:array'].items():
                    if i in ammo_distrib:
                        shell_object = {}
                        shell_object_blk = None
                        if isinstance(w, list):
                            shell_object_blk = w[0]['shell:object']['blk']
                        else:
                            shell_object_blk = w['shell:object']['blk']
                        if 'flamethrower_dummy.blk' in shell_object_blk:
                            break
                        shell_object_json = delistify(json.load(open(Path('./data_ore/tanks.vromfs.bin/' + shell_object_blk.replace('content/tanks/', '') + 'x'), encoding='utf-8')))
                        shell_object['name'] = shell_object_json['bulletName'] if 'bulletName' in shell_object_json else shell_object_blk.split('/')[-1].split('.blk')[0]
                        shell_object['type'] = shell_object_json['bulletType']
                        shell_object['mass'] = shell_object_json['mass']
                        shell_object['caliber'] = shell_object_json['caliber']
                        shell_object['speed'] = shell_object_json['speed'] if 'speed' in shell_object_json else None
                        shell_object['Cx'] = shell_object_json['Cx'] if 'Cx' in shell_object_json else None
                        shell_object['explosionPatchRadius'] = shell_object_json['explosionPatchRadius'] if 'explosionPatchRadius' in shell_object_json else None
                        shell_object['explosiveMass'] = shell_object_json['explosiveMass'] if 'explosiveMass' in shell_object_json else None
                        shell_object['normalizationPreset'] = shell_object_json['normalizationPreset'] if 'normalizationPreset' in shell_object_json else None
                        shell_object['stucking'] = shell_object_json['stucking'] if 'stucking' in shell_object_json else None
                        shell_object['stuckingAngle'] = shell_object_json['stuckingAngle'] if 'stuckingAngle' in shell_object_json else None
                        shell_object['fresnel'] = shell_object_json['fresnel'] if 'fresnel' in shell_object_json else None
                        if 'damage' in shell_object_json and 'kinetic' in shell_object_json['damage']:
                            shell_object['demarrePenetrationK'] = shell_object_json['damage']['kinetic']['demarrePenetrationK'] if 'demarrePenetrationK' in shell_object_json['damage']['kinetic'] else None
                            shell_object['demarreSpeedPow'] = shell_object_json['damage']['kinetic']['demarreSpeedPow'] if 'demarreSpeedPow' in shell_object_json['damage']['kinetic'] else None
                            shell_object['demarreMassPow'] = shell_object_json['damage']['kinetic']['demarreMassPow'] if 'demarreMassPow' in shell_object_json['damage']['kinetic'] else None
                            shell_object['demarreCaliberPow'] = shell_object_json['damage']['kinetic']['demarreCaliberPow'] if 'demarreCaliberPow' in shell_object_json['damage']['kinetic'] else None
                            shell_object['damageType'] = shell_object_json['damage']['kinetic']['damageType'] if 'damageType' in shell_object_json['damage']['kinetic'] else None
                            shell_object['damage'] = shell_object_json['damage']['kinetic']['damage'] if 'damage' in shell_object_json['damage']['kinetic'] else None
                        shell_object['cumulativeArmorPower'] = shell_object_json['cumulativeDamage']['armorPower'] if 'cumulativeDamage' in shell_object_json else None
                        # Remove duplicates
                        existing = False
                        for shell_object_existing in gun['shells']:
                            if shell_object_existing == shell_object:
                                existing = True
                        if not existing:
                            gun['shells'].append(shell_object)
                    i += 1

                turrets.append({
                    'yaw': find_property(turret_json, 'turret__yawSpeed', [k]),
                    'pitch': find_property(turret_json, 'turret__pitchSpeed', [k]),
                    'depression': find_property(turret_json, 'turret__limit', [k])[2] if find_property(turret_json, 'turret__limit', [k]) else None,
                    'elevation': find_property(turret_json, 'turret__limit', [k])[3] if find_property(turret_json, 'turret__limit', [k]) else None,
                    'rotation': find_property(turret_json, 'turret__limit', [k])[1] - find_property(turret_json, 'turret__limit', [k])[0] if find_property(turret_json, 'turret__limit', [k]) else None,
                    'gun': gun,
                    'ammo': ammo_count
                })


        tanks.append({
            'name': name,
            'nameGame': name_game,
            'crew': len(find_property(combined_tanks_json, 'vehicle_seats__seats:shared:array', [name])),
            'mass': armor_json['VehiclePhys']['Mass']['TakeOff'],
            'horsepower': armor_json['VehiclePhys']['engine']['horsePowers'],
            'engineRPM': armor_json['VehiclePhys']['engine']['maxRPM'],
            'brake': armor_json['VehiclePhys']['mechanics']['maxBrakeForce'],
            'turrets': turrets,
            'ammoDistrib': ammo_distrib
        })
    with open('../Enlisted-remastered/static/tanks/tanks.json', 'w', encoding='utf-8') as f:
        json.dump(tanks, f, ensure_ascii=False, indent=4)


if __name__ == "__main__":
    translation_items()
    soldier_damage()
    get_weapons()
    get_bullets()
    get_tanks()
