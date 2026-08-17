import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_final_ground_species import run
run("rhino", {"LICENSE.txt": "384c506f1411a52cd78cb5dfa697d59298bae4d2a671374c1b0cedd72bd6149b", "SOURCE.md": "003e0f4fa4c12e5c988feffbdfd53e1c6f0d81ec53684aaa408f7e225febc9ad"})
