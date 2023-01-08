import subprocess
import time
from pathlib import Path
import os
import shutil

enlisted_dir = 'C:/Users/Arthur/AppData/Local/Enlisted/'


if __name__ == "__main__":
    # Clean Data Ore directory
    shutil.rmtree('../data_ore')
    time.sleep(1)
    os.makedirs('../data_ore')

    # Unpack all vromfs into Data Ore
    for path in Path(enlisted_dir).rglob('**/*.vromfs.bin'):
        print(path.name)
        subprocess.call('./WT_tools/vromfs_unpacker.exe ' + str(path) + ' --output ../data_ore', shell=False)

    # Unpack all blk files and remove them afterwards
    subprocess.call('./WT_tools/blk_unpack_ng.exe ../data_ore', shell=False)
    for path in Path('../data_ore').rglob('**/*.blk'):
        os.remove(path)

    # Remove files that make project exceed 50MB
    shutil.rmtree('../data_ore/loading.vromfs.bin')
    shutil.rmtree('../data_ore/enlisted-game.vromfs.bin/gamedata/scenes')
    shutil.rmtree('../data_ore/ui.vromfs.bin')
    shutil.rmtree('../data_ore/uiskin.vromfs.bin')
    shutil.rmtree('../data_ore/uiskin_update.vromfs.bin')
    shutil.rmtree('../data_ore/sqcommon.vromfs.bin')
    shutil.rmtree('../data_ore/fonts.vromfs.bin')
    shutil.rmtree('../data_ore/grp_hdr.vromfs.bin')
    shutil.rmtree('../data_ore/tanks.vromfs.bin')
    shutil.rmtree('../data_ore/enlisted-lang.vromfs.bin')
