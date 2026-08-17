import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_final_ground_species import run
run("hippo", {"LICENSE.txt": "8116c382c8bfb11f800e11f466836436dd28af9cb6bffe6d5c820f3e6decdb52", "SOURCE.md": "0e1db3d2b6654cd148a3dba35f70a30da5dd790c7bbcb50bc59b39074158c03e"})
