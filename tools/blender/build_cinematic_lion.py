import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_final_ground_species import run
run("lion", {"LICENSE.txt": "8d6c395021c44e48ef9b13a337303324cec57e110ec0783e5f04f1e1518fcaad", "SOURCE.md": "4a676ba5591bc99aa5ef2e1fc48c6b923cfdee683c2ad2a582fc51bf343c4f9d"})
