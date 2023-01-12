import json
import os
from pathlib import Path


def translation_items():
    english_json = json.load(open("../Enlisted-remastered/static/translations/English.json", encoding='utf-8'))
    russian_json = json.load(open("../Enlisted-remastered/static/translations/Russian.json", encoding='utf-8'))

    translations1_csv = open("./data_ore/enlisted-lang.vromfs.bin/lang/common/common.csv", encoding='utf-8').read()
    translations2_csv = open("./data_ore/enlisted-lang.vromfs.bin/lang/enlisted/enlisted.csv", encoding='utf-8').read()
    translations_list = translations1_csv.split('\n') + translations2_csv.split('\n')
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
    with open('../Enlisted-remastered/static/soldierStats/soldierDamage.json', 'w', encoding='utf-8') as f:
        json.dump(soldier_damage_list, f, ensure_ascii=False, indent=4)


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

    for gun in valid_guns:
        starting_extensions = [gun['name']] if gun['name'].endswith('gun') else [gun['name'] + '_gun', gun['name']]
        gun['rps'] = find_property(weapons, 'gun__shotFreq', starting_extensions.copy())
        gun['dispersion'] = find_property(weapons, 'gun_spread__maxDeltaAngle', starting_extensions.copy())
        gun['stat'] = find_property(weapons, 'gun__statName', starting_extensions.copy())
        gun['type'] = find_property(weapons, 'item__weapType', starting_extensions.copy())
        gun['weight'] = find_property(weapons, 'item__weight', starting_extensions.copy())
        gun['locName'] = find_property(weapons, 'gun__locName', starting_extensions.copy())
        gun['magazineName'] = find_property(weapons, 'gun__ammoHolders:array', starting_extensions.copy())
        gun['bullets'] = find_property(weapons, 'gun__shells:array', starting_extensions.copy())
        gun['firingModes'] = find_property(weapons, 'gun__firingModeNames:array', starting_extensions.copy())
        gun['singleReloadPrep'] = find_property(weapons, 'single_reload__prepareTime', starting_extensions.copy())
        gun['singleReloadLoop'] = find_property(weapons, 'single_reload__loopTime', starting_extensions.copy())
        gun['singleReloadPost'] = find_property(weapons, 'single_reload__postTime', starting_extensions.copy())
        gun['reload'] = find_property(weapons, 'gun__reloadTime', starting_extensions.copy())
        gun['altReload'] = find_property(weapons, 'gun__altReloadTime', starting_extensions.copy())
        gun['dualMagReload'] = find_property(weapons, 'gun__dualMagReloadTime', starting_extensions.copy())
        gun['proneRecoilMult'] = find_property(weapons, 'gun__crawlRecoilMult', starting_extensions.copy())

    print(valid_guns)


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


if __name__ == "__main__":
    translation_items()
    soldier_damage()
    get_weapons()