import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_final_ground_species import run
run("hyena", {"LICENSE.txt": "0db73c9c4993d1df77c4a8593f206d1c2832a51aa50730aef034cb07808573de", "SOURCE.md": "1f848665d94664a34be319e00acdd332266f6547f95ceae1c8d1a2af576ac4e8"})
