import json

# Get translation items
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

# Sort and save
english_json = dict(sorted(english_json.items()))
russian_json = dict(sorted(russian_json.items()))
with open('../Enlisted-remastered/static/translations/English.json', 'w', encoding='utf-8') as f:
    json.dump(english_json, f, ensure_ascii=False, indent=4)
with open('../Enlisted-remastered/static/translations/Russian.json', 'w', encoding='utf-8') as f:
    json.dump(russian_json, f, ensure_ascii=False, indent=4)


# Soldier damage body parts finder
soldier_damage = json.load(open("./data_ore/enlisted-game.vromfs.bin/gamedata/templates/enlisted_shooter_humans.blkx", encoding='utf-8'))
soldier_damage_list = []
for (k, v) in soldier_damage['human']['dm_parts__parts:object'].items():
    soldier_damage_list.append({
        k.split('Bip01 ')[1].split(':object')[0]: v['dmgMult']
    })
with open('../Enlisted-remastered/static/soldierStats/soldierDamage.json', 'w', encoding='utf-8') as f:
    json.dump(soldier_damage_list, f, ensure_ascii=False, indent=4)




