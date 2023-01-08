import subprocess
import time
from pathlib import Path
import os
import shutil

enlisted_dir = 'C:/Users/Arthur/AppData/Local/Enlisted/'


if __name__ == "__main__":
    # Clean Data Ore directory
    shutil.rmtree('./data_ore')
    time.sleep(1)
    os.makedirs('./data_ore')

    # Unpack all vromfs into Data Ore
    for path in Path(enlisted_dir).rglob('**/*.vromfs.bin'):
        print(path.name)
        subprocess.call('./WT_tools/vromfs_unpacker.exe ' + str(path) + ' --output ./data_ore', shell=False)

    # Unpack all blk files and remove them afterwards
    subprocess.call('./WT_tools/blk_unpack_ng.exe ./data_ore', shell=False)
    for path in Path('./data_ore').rglob('**/*.blk'):
        os.remove(path)
