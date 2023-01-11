import json

# Soldier damage body parts finder
soldier_damage = json.load(open("./data_ore/enlisted-game.vromfs.bin/gamedata/templates/enlisted_shooter_humans.blkx", encoding='utf-8'))
soldier_damage_list = []
for (k, v) in soldier_damage['human']['dm_parts__parts:object'].items():
    soldier_damage_list.append({
        k.split('Bip01 ')[1].split(':object')[0]: v['dmgMult']
    })
with open('../Enlisted-remastered/static/soldierStats/soldierDamage.json', 'w', encoding='utf-8') as f:
    json.dump(soldier_damage_list, f, ensure_ascii=False, indent=4)




