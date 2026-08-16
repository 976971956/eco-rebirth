#!/bin/sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BLENDER_BIN=${BLENDER_BIN:-/Applications/Blender.app/Contents/MacOS/Blender}

if [ ! -x "$BLENDER_BIN" ]; then
	printf '%s\n' "Blender executable not found: $BLENDER_BIN" >&2
	exit 1
fi

"$BLENDER_BIN" --background --factory-startup --disable-autoexec --python-exit-code 1 --python "$PROJECT_ROOT/tools/blender/build_cinematic_rabbit.py" -- \
	--source-dir "$PROJECT_ROOT/assets/source/animals/rabbit/cc0_cdmir" \
	--output-root "$PROJECT_ROOT/assets/models_v2/animals"

"$BLENDER_BIN" --background --factory-startup --python-exit-code 1 --python "$PROJECT_ROOT/tools/blender/build_cinematic_wolf.py" -- \
	--source-dir "$PROJECT_ROOT/assets/source/animals/wolf/cc0_newdlc" \
	--output-root "$PROJECT_ROOT/assets/models_v2/animals"

"$BLENDER_BIN" --background --factory-startup --python-exit-code 1 --python "$PROJECT_ROOT/tools/blender/build_remaining_species.py" -- \
	--output-root "$PROJECT_ROOT/assets/models_v2/animals"

"$BLENDER_BIN" --background --factory-startup --python-exit-code 1 --python "$PROJECT_ROOT/tools/blender/build_forest_vertical_slice.py" -- \
	--output-root "$PROJECT_ROOT/assets/models_v2/biomes/forest"
