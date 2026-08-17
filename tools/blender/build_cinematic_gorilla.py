import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_final_ground_species import run
run("gorilla", {"LICENSE.txt": "e287426220c356bf14edf17d4777bb2f00a802422a42d3cb801ed0cfedc9a4a6", "SOURCE.md": "21633a2ace6fb3db78e10f749dfe53e7bf45640b93dfc83731db82c9b8dd6bf1"})
