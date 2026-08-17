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

"$BLENDER_BIN" --background --factory-startup --disable-autoexec --python-exit-code 1 --python "$PROJECT_ROOT/tools/blender/build_cinematic_wolf.py" -- \
	--source-dir "$PROJECT_ROOT/assets/source/animals/wolf/cc0_newdlc" \
	--output-root "$PROJECT_ROOT/assets/models_v2/animals"

"$BLENDER_BIN" --background --factory-startup --disable-autoexec --python-exit-code 1 --python "$PROJECT_ROOT/tools/blender/build_cinematic_fox.py" -- \
	--source-dir "$PROJECT_ROOT/assets/source/animals/fox/cc0_br_n518" \
	--output-root "$PROJECT_ROOT/assets/models_v2/animals"

"$BLENDER_BIN" --background --factory-startup --disable-autoexec --python-exit-code 1 --python "$PROJECT_ROOT/tools/blender/build_cinematic_deer.py" -- \
	--source-dir "$PROJECT_ROOT/assets/source/animals/deer/cc0_cdmir" \
	--output-root "$PROJECT_ROOT/assets/models_v2/animals"

"$BLENDER_BIN" --background --factory-startup --disable-autoexec --python-exit-code 1 --python "$PROJECT_ROOT/tools/blender/build_cinematic_snake.py" -- \
	--source-dir "$PROJECT_ROOT/assets/source/animals/snake/cc0_methodical_pixel" \
	--output-root "$PROJECT_ROOT/assets/models_v2/animals"

"$BLENDER_BIN" --background --factory-startup --disable-autoexec --python-exit-code 1 --python "$PROJECT_ROOT/tools/blender/build_cinematic_bear.py" -- \
	--source-dir "$PROJECT_ROOT/assets/source/animals/bear/cc0_nephthys" \
	--output-root "$PROJECT_ROOT/assets/models_v2/animals"

"$BLENDER_BIN" --background --factory-startup --disable-autoexec --python-exit-code 1 --python "$PROJECT_ROOT/tools/blender/build_cinematic_boar.py" -- \
	--source-dir "$PROJECT_ROOT/assets/source/animals/boar/cc0_teh_bucket" \
	--output-root "$PROJECT_ROOT/assets/models_v2/animals"

"$BLENDER_BIN" --background --factory-startup --disable-autoexec --python-exit-code 1 --python "$PROJECT_ROOT/tools/blender/build_cinematic_raccoon.py" -- \
	--source-dir "$PROJECT_ROOT/assets/source/animals/raccoon/cc0_quaternius" \
	--output-root "$PROJECT_ROOT/assets/models_v2/animals"

"$BLENDER_BIN" --background --factory-startup --disable-autoexec --python-exit-code 1 --python "$PROJECT_ROOT/tools/blender/build_cinematic_porcupine.py" -- \
	--source-dir "$PROJECT_ROOT/assets/source/animals/porcupine/cc_by_google_poly" \
	--output-root "$PROJECT_ROOT/assets/models_v2/animals"

"$BLENDER_BIN" --background --factory-startup --disable-autoexec --python-exit-code 1 --python "$PROJECT_ROOT/tools/blender/build_cinematic_crocodile.py" -- \
	--source-dir "$PROJECT_ROOT/assets/source/animals/crocodile/cc0_br_n518" \
	--output-root "$PROJECT_ROOT/assets/models_v2/animals"

"$BLENDER_BIN" --background --factory-startup --disable-autoexec --python-exit-code 1 --python "$PROJECT_ROOT/tools/blender/build_cinematic_capybara.py" -- \
	--source-dir "$PROJECT_ROOT/assets/source/animals/capybara/cc_by_google_poly" \
	--output-root "$PROJECT_ROOT/assets/models_v2/animals"

"$BLENDER_BIN" --background --factory-startup --disable-autoexec --python-exit-code 1 --python "$PROJECT_ROOT/tools/blender/build_cinematic_otter.py" -- \
	--source-dir "$PROJECT_ROOT/assets/source/animals/otter/cc_by_google_poly" \
	--output-root "$PROJECT_ROOT/assets/models_v2/animals"

"$BLENDER_BIN" --background --factory-startup --disable-autoexec --python-exit-code 1 --python "$PROJECT_ROOT/tools/blender/build_remaining_species.py" -- \
	--output-root "$PROJECT_ROOT/assets/models_v2/animals"

"$BLENDER_BIN" --background --factory-startup --disable-autoexec --python-exit-code 1 --python "$PROJECT_ROOT/tools/blender/build_forest_vertical_slice.py" -- \
	--output-root "$PROJECT_ROOT/assets/models_v2/biomes/forest"
