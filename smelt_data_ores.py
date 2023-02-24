import json
from pathlib import Path


def delistify(old_json):
    if isinstance(old_json, list):
        new_json = {}
        for item in old_json:
            new_json[list(item.keys())[0]] = list(item.values())[0]
        old_json = new_json
    return old_json


def translation_items():
    english_json = json.load(open("../Enlisted-remastered/static/translations/English.json", encoding='utf-8'))
    russian_json = json.load(open("../Enlisted-remastered/static/translations/Russian.json", encoding='utf-8'))

    translations1_csv = open("./data_ore/enlisted-lang.vromfs.bin/lang/common/common.csv", encoding='utf-8').read()
    translations2_csv = open("./data_ore/enlisted-lang.vromfs.bin/lang/enlisted/enlisted.csv", encoding='utf-8').read()
    translations_list = translations1_csv.split('\n') + translations2_csv.split('\n')

    # Soldier classes
    for translation in translations_list:
        if translation.startswith('"soldierClass/'):
            class_name = translation.split('"soldierClass/')[1].split('";"')[0]
            if '/desc' not in class_name and ('_' not in class_name or class_name == 'anti_tank' or class_name == 'pilot_fighter' or class_name == 'pilot_assaulter'):
                english_json['class.' + class_name] = translation.split(';')[1].replace('"', '')
                russian_json['class.' + class_name] = translation.split(';')[2].replace('"', '')

    # Perk names
    for translation in translations_list:
        if translation.split('";"')[0].count('/') == 2 and translation.startswith('"stat/') and '/desc' in translation.split('";"')[0]:
            perk_name = translation.split('/')[1].split('/')[0]
            english_json['perk.' + perk_name] = translation.split(';')[1].replace('"', '')
            russian_json['perk.' + perk_name] = translation.split(';')[2].replace('"', '')

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
            english_json['item.' + item_name] = translation.split(';')[1].replace('"', '')
            russian_json['item.' + item_name] = translation.split(';')[2].replace('"', '')

    # Firing modes
    for translation in translations1_csv.split('\n'):
        if translation.split('";"')[0].count('/') == 1 and translation.startswith('"firing_mode/'):
            firing_mode = translation.split('/')[1].split('";"')[0]
            english_json['firingMode.' + firing_mode] = translation.split(';')[1].replace('"', '')
            russian_json['firingMode.' + firing_mode] = translation.split(';')[2].replace('"', '')

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
    weapons_ww2 = json.load(open("./data_ore/enlisted-content.vromfs.bin/content/e_ww2_common/gamedata/templates/ww2_guns.blkx", encoding='utf-8'))
    weapons_tun = json.load(open("./data_ore/enlisted-content.vromfs.bin/content/e_tunisia/gamedata/templates/tunisia_guns.blkx", encoding='utf-8'))
    weapons_stl = json.load(open("./data_ore/enlisted-content.vromfs.bin/content/e_stalingrad/gamedata/templates/stalingrad_guns.blkx", encoding='utf-8'))
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
    items_common = json.load(open("./data_ore/enlisted-content.vromfs.bin/content/e_ww2_common/gamedata/templates/ww2_items.blkx", encoding='utf-8'))
    tunisia_common = json.load(open("./data_ore/enlisted-content.vromfs.bin/content/e_tunisia/gamedata/templates/tunisia_items.blkx", encoding='utf-8'))
    stalingrad_common = json.load(open("./data_ore/enlisted-content.vromfs.bin/content/e_stalingrad/gamedata/templates/stalingrad_items.blkx", encoding='utf-8'))
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
        {'name': 'explosion_pack', 'path': Path('./data_ore/enlisted-content.vromfs.bin/content/e_ww2_common/gamedata/weapons/grenades/explosion_pack.blkx')},
        {'name': 'grenade', 'path': Path('./data_ore/enlisted-content.vromfs.bin/content/e_ww2_common/gamedata/weapons/grenades/f1.blkx')},
        {'name': 'molotov_grenade', 'path': Path('./data_ore/enlisted-content.vromfs.bin/content/e_ww2_common/gamedata/weapons/grenades/molotov_base.blkx')},
        {'name': 'incendiary_grenade', 'path': Path('./data_ore/enlisted-content.vromfs.bin/content/e_ww2_common/gamedata/weapons/grenades/m_15_incendiary_grenade.blkx')},
        {'name': 'impact_grenade', 'path': Path('./data_ore/enlisted-content.vromfs.bin/content/e_ww2_common/gamedata/weapons/grenades/no_69_impact_grenade.blkx')},
        {'name': 'antipersonnel_mine', 'path': Path('./data_ore/enlisted-content.vromfs.bin/content/e_ww2_common/gamedata/weapons/antipersonnel_mine.blkx')},
        {'name': 'antitank_mine', 'path': Path('./data_ore/enlisted-content.vromfs.bin/content/e_ww2_common/gamedata/weapons/antitank_mine.blkx')},
        {'name': 'tnt_block', 'path': Path('./data_ore/enlisted-content.vromfs.bin/content/e_ww2_common/gamedata/weapons/tnt_block.blkx')}
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
    json_paths = list(Path('./data_ore/enlisted-content.vromfs.bin/content/e_ww2_common/gamedata/weapons/bullets').rglob('*.blkx')) + list(Path('./data_ore/enlisted-content.vromfs.bin/content/e_tunisia/gamedata/weapons/bullets').rglob('*.blkx')) + list(Path('./data_ore/enlisted-game.vromfs.bin/gamedata/weapons_enlisted/bullets').rglob('*.blkx')) + list(Path('./data_ore/enlisted-content.vromfs.bin/content/e_ww2_common/gamedata/weapons/shells').rglob('*.blkx')) + list(Path('./data_ore/enlisted-game.vromfs.bin/gamedata/weapons_enlisted/shells').rglob('*.blkx'))
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
        {'name': 'explosion_pack', 'path': Path('./data_ore/enlisted-content.vromfs.bin/content/e_ww2_common/gamedata/weapons/grenades/explosion_pack.blkx')},
        {'name': 'grenade', 'path': Path('./data_ore/enlisted-content.vromfs.bin/content/e_ww2_common/gamedata/weapons/grenades/f1.blkx')},
        {'name': 'molotov_grenade', 'path': Path('./data_ore/enlisted-content.vromfs.bin/content/e_ww2_common/gamedata/weapons/grenades/molotov_base.blkx')},
        {'name': 'incendiary_grenade', 'path': Path('./data_ore/enlisted-content.vromfs.bin/content/e_ww2_common/gamedata/weapons/grenades/m_15_incendiary_grenade.blkx')},
        {'name': 'impact_grenade', 'path': Path('./data_ore/enlisted-content.vromfs.bin/content/e_ww2_common/gamedata/weapons/grenades/no_69_impact_grenade.blkx')},
        {'name': 'antipersonnel_mine', 'path': Path('./data_ore/enlisted-content.vromfs.bin/content/e_ww2_common/gamedata/weapons/antipersonnel_mine.blkx')},
        {'name': 'antitank_mine', 'path': Path('./data_ore/enlisted-content.vromfs.bin/content/e_ww2_common/gamedata/weapons/antitank_mine.blkx')},
        {'name': 'tnt_block', 'path': Path('./data_ore/enlisted-content.vromfs.bin/content/e_ww2_common/gamedata/weapons/tnt_block.blkx')}
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
    json_paths = list(Path('./data_ore/tanks.vromfs.bin/gamedata/templates/tanks').rglob('*.blkx'))

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
        if 'jgdpz_38t' in file_json_name:
            continue

        turret_json = delistify(json.load(open(Path('./data_ore/tanks.vromfs.bin/gamedata/gen/templates/tanks/' + file_json_name + '.blkx'), encoding='utf-8')))
        armor_json = delistify(json.load(open(Path('./data_ore/tanks.vromfs.bin/gamedata/gen/units/tanks/' + file_json_name + '.blkx'), encoding='utf-8')))

        tanks.append({
            'name': name,
            'nameGame': name_game,
            'crew': len(find_property(combined_tanks_json, 'vehicle_seats__seats:shared:array', [name])),
            'mass': armor_json['VehiclePhys']['Mass']['TakeOff'],
            'horsepower': armor_json['VehiclePhys']['engine']['horsePowers'],
            'engineRPM': armor_json['VehiclePhys']['engine']['maxRPM'],
            'brake': armor_json['VehiclePhys']['mechanics']['maxBrakeForce']
        })
    with open('../Enlisted-remastered/static/tanks/tanks.json', 'w', encoding='utf-8') as f:
        json.dump(tanks, f, ensure_ascii=False, indent=4)


if __name__ == "__main__":
    translation_items()
    soldier_damage()
    get_weapons()
    get_bullets()
    get_tanks()
