import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_final_ground_species import run
run("turtle", {"LICENSE.txt": "c07e522622a5649c46447f3f558878b07fcb592a72cf119b8412da574a952b70", "SOURCE.md": "7fb3d7aaac4eaa266412199d83e6d0c7a2f0eddc0fd33c18f642a679faaf8fc0"})
