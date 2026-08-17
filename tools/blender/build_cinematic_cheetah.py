import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_final_ground_species import run
run("cheetah", {"LICENSE.txt": "578df25fe0376f0384749bc51f2a1be45af0383558a623d51e8a924ddee084ae", "SOURCE.md": "e6d3716e12fe5f9464c719cd1c0737c452df08b67148886b361e09531cfbc19d"})
