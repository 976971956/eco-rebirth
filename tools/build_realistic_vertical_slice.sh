#!/bin/sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BLENDER_BIN=${BLENDER_BIN:-/Applications/Blender.app/Contents/MacOS/Blender}

if [ ! -x "$BLENDER_BIN" ]; then
	printf '%s\n' "Blender executable not found: $BLENDER_BIN" >&2
	exit 1
fi

"$BLENDER_BIN" --background --factory-startup --python "$PROJECT_ROOT/tools/blender/build_vertical_slice.py" -- \
	--output-root "$PROJECT_ROOT/assets/models_v2/animals"

"$BLENDER_BIN" --background --factory-startup --python "$PROJECT_ROOT/tools/blender/build_forest_vertical_slice.py" -- \
	--output-root "$PROJECT_ROOT/assets/models_v2/biomes/forest"
